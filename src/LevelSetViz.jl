using GLMakie
using StaticArrays
# using Colors

# Note: LevelSetData and VisualizationParameters are now defined in the main Globtim module
# This file contains only the function implementations

# Core Functions
"""
    prepare_level_set_data(
        grid::Array{SVector{3,T}}, 
        values::Array{T}, 
        level::T;
        tolerance::T=convert(T, 1e-2)
    ) where {T<:AbstractFloat}

Prepare level set data by identifying points near the specified level.
"""
function Globtim.prepare_level_set_data(
    grid::Array{SVector{3, T}},
    values::Array{T},
    level::T;
    tolerance::T = convert(T, 1e-2)
) where {T <: AbstractFloat}
    size(grid) == size(values) ||
        throw(DimensionMismatch("Grid and values must have same dimensions"))
    tolerance > zero(T) || throw(ArgumentError("Tolerance must be positive"))

    # Flatten arrays for processing
    flat_grid = vec(grid)
    flat_values = vec(values)

    # Find points where function is close to the level value
    level_set_mask = @. abs(flat_values - level) < tolerance

    # Create LevelSetData structure
    LevelSetData(flat_grid[level_set_mask], flat_values[level_set_mask], level)
end

"""
    to_makie_format(level_set::LevelSetData{T}) where {T<:AbstractFloat}

Convert LevelSetData to a format suitable for Makie plotting.
"""
function Globtim.to_makie_format(level_set::LevelSetData{T}) where {T <: AbstractFloat}
    isempty(level_set.points) &&
        return (points = Matrix{T}(undef, 3, 0), values = T[], xyz = (T[], T[], T[]))

    points = reduce(hcat, level_set.points)
    return (
        points = points,
        values = level_set.values,
        xyz = (view(points, 1, :), view(points, 2, :), view(points, 3, :))
    )
end

"""
    plot_level_set(
        formatted_data;
        fig_size=(800, 600),
        marker_size=4,
        title="Level Set Visualization"
    )

Create a 3D scatter plot of level set points.
"""
function Globtim.plot_level_set(
    formatted_data;
    fig_size = (800, 600),
    marker_size = 4,
    title = "Level Set Visualization"
)

    fig = Figure(size = fig_size)
    ax = Axis3(fig[1, 1], title = title, xlabel = "x₁", ylabel = "x₂", zlabel = "x₃")

    scatter!(ax, formatted_data.xyz..., markersize = marker_size)

    display(fig)
    return fig
end

"""
    create_level_set_visualization(
        f, 
        grid::Array{SVector{3,T},3}, 
        df::DataFrame,
        z_range::Tuple{T,T},
        params::VisualizationParameters=VisualizationParameters()
    ) where {T<:AbstractFloat}
"""
function Globtim.create_level_set_visualization(
    f,
    grid::Array{SVector{3, T}, 3},
    df::Union{DataFrame, Nothing},
    z_range::Tuple{T, T},
    params::VisualizationParameters{T} = VisualizationParameters{T}()
) where {T <: AbstractFloat}
    grid_points = vec(grid)
    valid_points = filter(p -> !any(isnan, p), grid_points)
    isempty(valid_points) && throw(ArgumentError("Grid contains no valid points"))

    z_min, z_max = z_range
    (isnan(z_min) || isnan(z_max)) && throw(ArgumentError("Invalid z_range"))

    fig = Figure(size = params.fig_size)
    ax = Axis3(fig[1, 1], xlabel = "x₁", ylabel = "x₂", zlabel = "x₃")

    x_range = extrema(p[1] for p in valid_points)
    y_range = extrema(p[2] for p in valid_points)
    z_range_grid = extrema(p[3] for p in valid_points)

    limits!(ax, x_range..., y_range..., z_range_grid...)

    level_slider =
        Slider(fig[2, 1], range = range(z_min, z_max, length = 1000), startvalue = z_min)

    level_label = Label(
        fig[3, 1],
        @lift(string("Level: ", round($(level_slider.value), digits = 3))),
        tellwidth = false
    )

    level_points = Observable(Point3f[])
    data_points = Observable(Point3f[])

    # Pre-compute function values for the entire grid
    values = zeros(T, size(grid)...)
    @inbounds for i in eachindex(grid_points)
        point = grid_points[i]
        values[i] = any(isnan, point) ? NaN : f(point)
    end

    scatter!(
        ax,
        level_points,
        color = :blue,
        markersize = 6,
        alpha = 0.7,
        label = "Level Set"
    )

    if !isnothing(df)
        scatter!(
            ax,
            data_points,
            color = :darkorange,
            marker = :diamond,
            markersize = 30,
            label = "Data Points"
        )
    end

    function update_visualization(level::T) where {T <: AbstractFloat}
        try
            # Update level set points
            level_data = prepare_level_set_data(
                grid,
                values,
                level,
                tolerance = params.point_tolerance
            )

            formatted_data = to_makie_format(level_data)

            # Update points atomically
            new_points = Point3f[]
            if !isempty(formatted_data.xyz[1])
                for (x, y, z) in zip(formatted_data.xyz...)
                    if !any(isnan, (x, y, z))
                        push!(new_points, Point3f(x, y, z))
                    end
                end
            end
            level_points[] = new_points

            if !isnothing(df)
                visible_points = Point3f[]
                for row in eachrow(df)
                    if !any(isnan, [row["x1"], row["x2"], row["x3"], row["z"]]) &&
                       abs(row["z"] - level) ≤ params.point_tolerance
                        push!(visible_points, Point3f(row["x1"], row["x2"], row["x3"]))
                    end
                end
                data_points[] = visible_points
            end
        catch e
            @error "Error in visualization update" exception = e
            rethrow(e)
        end
    end

    on(level_slider.value) do level
        update_visualization(level)
    end

    update_visualization(z_min)
    axislegend(ax, position = :rt)

    return fig
end

function Globtim.plot_polyapprox_levelset_2D(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    x,
    wd_in_std_basis,
    p_true,
    plot_range,
    distance;
    xlabel = "Parameter 1",
    ylabel = "Parameter 2",
    colorbar = true,
    figure_size = (1200, 1000),
    chosen_colormap = :inferno,
    colorbar_label = "Loss Value",
    num_levels = 30
)
    @assert size(pol.grid, 2) == 2 "Grid must be 2D for this function"

    # Grid on [a, b] ± [c, d]
    fine_grid = Iterators.product(plot_range...) |> collect
    fine_grid = map(i -> TR.center + collect(i), fine_grid)

    # Grid on [-1, 1] x [-1, 1] ± eps
    pullback(x) = (1 / pol.scale_factor) * (x .- TR.center)
    pushforward(x) = pol.scale_factor * x .+ TR.center
    fine_grid_pullback = map(pullback, fine_grid)

    @info "" fine_grid fine_grid_pullback

    # f(x) on [a, b] ± [c, d]
    fine_values_f = map(TR.objective, fine_grid)

    # w_d(x) on [-1, 1] x [-1, 1] ± eps
    poly_func =
        p -> DynamicPolynomials.coefficients(
            DynamicPolynomials.subs(wd_in_std_basis, x => p)
        )[1]
    fine_values_wd = map(poly_func, fine_grid_pullback)

    @info "" fine_values_f fine_values_wd

    # ||f - w_d||_s 
    fine_values_f_minus_wd = log2.(abs.(fine_values_wd .- fine_values_f))

    z_limits_f = (minimum(fine_values_f), maximum(fine_values_f))
    z_limits_wd = (minimum(fine_values_wd), maximum(fine_values_wd))
    z_limits_f_minus_wd = (minimum(fine_values_f_minus_wd), maximum(fine_values_f_minus_wd))

    @info "" z_limits_f z_limits_wd z_limits_f_minus_wd

    # Combine z_limits
    # Option 1
    z_limits = (min(z_limits_f[1], z_limits_wd[1]), max(z_limits_f[2], z_limits_wd[2]))
    # Option 2
    z_limits = z_limits_f
    z_limits = (
        z_limits[1] - 0.1 * abs(z_limits[2] - z_limits[1]),
        z_limits[2] + 0.1 * abs(z_limits[2] - z_limits[1])
    )
    @info "" z_limits

    levels = range(z_limits[1], z_limits[2], length = num_levels)
    levels_f_wd = range(z_limits_f_minus_wd[1], z_limits_f_minus_wd[2], length = num_levels)

    fig = Figure(size = figure_size)

    ax = Axis(
        fig[1, 1],
        title = "Lotka Volterra 2D, f(x) = $distance",
        xlabel = xlabel,
        ylabel = ylabel
    )

    cf = contourf!(
        ax,
        map(first, fine_grid),
        map(last, fine_grid),
        fine_values_f,
        colormap = chosen_colormap,
        levels = levels
    )
    pt = scatter!(
        ax,
        p_true[1],
        p_true[2],
        markersize = 10,
        color = :green,
        marker = :diamond
    )
    # pt = arc!(
    #     ax,
    #     p_true,
    #     (maximum(plot_range[1]) - minimum(plot_range[1])) / 20,
    #     0,
    #     2π,
    #     color = :green,
    #     label = "p_true",
    # )
    cp = scatter!(ax, df.x1, df.x2, markersize = 10, color = :blue, marker = :diamond)

    ax = Axis(
        fig[1, 2],
        title = "w_d(x), d = $(pol.degree)",
        xlabel = xlabel,
        ylabel = ylabel
    )

    cf = contourf!(
        ax,
        map(first, fine_grid),
        map(last, fine_grid),
        fine_values_wd,
        colormap = chosen_colormap,
        levels = levels
    )
    cp = scatter!(ax, df.x1, df.x2, markersize = 10, color = :blue, marker = :diamond)
    rct = lines!(
        ax,
        [
            TR.center[1] - TR.sample_range,
            TR.center[1] - TR.sample_range,
            TR.center[1] + TR.sample_range,
            TR.center[1] + TR.sample_range,
            TR.center[1] - TR.sample_range
        ],
        [
            TR.center[2] - TR.sample_range,
            TR.center[2] + TR.sample_range,
            TR.center[2] + TR.sample_range,
            TR.center[2] - TR.sample_range,
            TR.center[2] - TR.sample_range
        ],
        color = :black,
        linewidth = 3,
        linestyle = :dash
    )

    Colorbar(fig[1, 3], cf, label = "")

    ax = Axis(
        fig[2, 1],
        title = "|f(x) - w_d(x)|, L2 norm = $(round(pol.nrm, digits=3))",
        xlabel = xlabel,
        ylabel = ylabel
    )

    @info "" levels_f_wd
    cf_f_minus_wd = contourf!(
        ax,
        map(first, fine_grid),
        map(last, fine_grid),
        fine_values_f_minus_wd,
        # colormap = chosen_colormap, 
        levels = levels_f_wd
    )

    sp = scatter!(
        ax,
        map(first, pushforward.(eachrow(pol.grid))),
        map(last, pushforward.(eachrow(pol.grid))),
        markersize = 2,
        color = :black,
        marker = :circle,
        alpha = 0.2
    )

    rct = lines!(
        ax,
        [
            TR.center[1] - TR.sample_range,
            TR.center[1] - TR.sample_range,
            TR.center[1] + TR.sample_range,
            TR.center[1] + TR.sample_range,
            TR.center[1] - TR.sample_range
        ],
        [
            TR.center[2] - TR.sample_range,
            TR.center[2] + TR.sample_range,
            TR.center[2] + TR.sample_range,
            TR.center[2] - TR.sample_range,
            TR.center[2] - TR.sample_range
        ],
        color = :black,
        linewidth = 3,
        linestyle = :dash
    )

    Colorbar(
        fig[2, 3],
        cf_f_minus_wd,
        ticks = (
            levels_f_wd[floor.(Int, range(1, length(levels_f_wd), length = 9))],
            string.(
                "2^" .*
                string.(
                    round.(
                        Int,
                        levels_f_wd[floor.(Int, range(1, length(levels_f_wd), length = 9))]
                    )
                )
            )
        )
    )

    # (fine grained: $(round(sqrt(sum((fine_values_f .- fine_values_wd).^2)), digits=3)))
    ax = Axis(
        fig[2, 2],
        title = "|f(x) - w_d(x)|, L2 norm = $(round(pol.nrm, digits=3))",
        xlabel = xlabel,
        ylabel = ylabel
    )

    rare_levels = levels_f_wd[floor.(Int, range(1, length(levels_f_wd), length = 9))]
    cf_f_minus_wd = contourf!(
        ax,
        map(first, fine_grid),
        map(last, fine_grid),
        fine_values_f_minus_wd,
        # colormap = chosen_colormap, 
        levels = rare_levels
    )

    Legend(
        fig[3, 1],
        [cp, pt, rct, sp],
        ["Critical Points of w_d", "True Parameter", "Sampling Range", "Sample Points"],
        orientation = :horizontal,  # Make legend horizontal for better space usage
        tellwidth = false,         # Don't have legend width affect layout
        tellheight = true,
        patchsize = (30, 20)
    )

    fig
end

function Globtim.plot_polyapprox_levelset(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    figure_size::Tuple{Int, Int} = (1000, 600),
    z_limits::Union{Nothing, Tuple{Float64, Float64}} = nothing,
    chebyshev_levels::Bool = false,
    num_levels::Int = 30
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size = figure_size)
        ax = Axis(fig[1, 1], title = "")

        # Calculate z_limits if not provided
        if isnothing(z_limits)
            z_values = Float64[]
            append!(z_values, df.z)
            z_limits = (minimum(z_values), maximum(z_values))
        end

        # Calculate levels
        levels = if chebyshev_levels
            k = collect(0:(num_levels - 1))
            cheb_nodes = -cos.((2k .+ 1) .* π ./ (2 * num_levels))
            z_min, z_max = z_limits
            (z_max - z_min) ./ 2 .* cheb_nodes .+ (z_max + z_min) ./ 2
        else
            num_levels
        end

        # Prepare contour data
        x_unique = sort(unique(coords[:, 1]))
        y_unique = sort(unique(coords[:, 2]))
        Z = fill(NaN, (length(y_unique), length(x_unique)))

        for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
            i = findlast(≈(y), y_unique)
            j = findlast(≈(x), x_unique)
            if !isnothing(i) && !isnothing(j)
                Z[j, i] = z
            end
        end

        # Create contour plot
        # chosen_colormap = :viridis  
        chosen_colormap = :inferno
        contourf!(ax, x_unique, y_unique, Z, colormap = chosen_colormap, levels = levels)

        # Initialize empty array for legend entries
        legend_entries = []

        # Plot and add legend entries for all point types
        if :close in propertynames(df)
            # Far points
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(
                    ax,
                    df.x1[not_close_idx],
                    df.x2[not_close_idx],
                    markersize = 10,
                    color = :white,
                    strokecolor = :black,
                    strokewidth = 1,
                    label = "Far"
                )
                push!(legend_entries, "Far")
            end

            # Near points
            close_idx = df.close
            if any(close_idx)
                scatter!(
                    ax,
                    df.x1[close_idx],
                    df.x2[close_idx],
                    markersize = 10,
                    color = :green,
                    strokecolor = :black,
                    strokewidth = 1,
                    label = "Near"
                )
                push!(legend_entries, "Near")
            end
        else
            # All points if no close/far distinction
            scatter!(
                ax,
                df.x1,
                df.x2,
                markersize = 2,
                color = :orange,
                label = "All points"
            )
            push!(legend_entries, "All points")
        end

        if !isempty(df)
            # Plot all points with z-values
            scatter!(
                ax,
                df.x1,
                df.x2,
                markersize = 15,
                marker = :diamond,
                color = :blue,
                label = "All found critical points"
            )
        end

        # Only create legend if we have entries
        # if !isempty(legend_entries)
        #     Legend(fig[1, 2], ax, "Critical Points",
        #         tellwidth=true)
        # end

        # Colorbar(fig[1, 3], limits=z_limits,
        #     colormap=chosen_colormap,
        #     label="")

        display(fig)
        return fig
    end
end

function Globtim.plot_polyapprox_rotate(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    df_min::DataFrame
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size = (1000, 600))
        ax = Axis3(
            fig[1, 1],
            title = "",
            xlabel = "X-axis",
            ylabel = "Y-axis",
            zlabel = "Z-axis"
        )

        # Create a regular grid for surface plotting
        x_unique = sort(unique(coords[:, 1]))
        y_unique = sort(unique(coords[:, 2]))

        Z = fill(NaN, (length(y_unique), length(x_unique)))

        for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
            i = findlast(≈(y), y_unique)
            j = findlast(≈(x), x_unique)
            if !isnothing(i) && !isnothing(j)
                Z[j, i] = z
            end
        end

        surface!(
            ax,
            x_unique,
            y_unique,
            Z,
            # colormap=:viridis,
            colormap = :inferno,
            transparency = true,
            alpha = 0.8
        )

        if :close in propertynames(df)
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(
                    ax,
                    df.x1[not_close_idx],
                    df.x2[not_close_idx],
                    df.z[not_close_idx],
                    markersize = 5,
                    color = :orange,
                    label = "Far"
                )
            end

            close_idx = df.close
            if any(close_idx)
                scatter!(
                    ax,
                    df.x1[close_idx],
                    df.x2[close_idx],
                    df.z[close_idx],
                    markersize = 10,
                    color = :green,
                    label = "Near"
                )
            end
        else
            scatter!(
                ax,
                df.x1,
                df.x2,
                df.z,
                markersize = 2,
                color = :orange,
                label = "All points"
            )
        end

        # Plot uncaptured minimizers from df_min in red
        uncaptured_idx = .!df_min.captured
        if any(uncaptured_idx)
            scatter!(
                ax,
                df_min.x1[uncaptured_idx],
                df_min.x2[uncaptured_idx],
                df_min.value[uncaptured_idx],
                markersize = 10,
                marker = :diamond,
                color = :red,
                label = "Uncaptured minima"
            )
        end

        # Add legend to the right of the plot
        # Legend(fig[1, 2], ax, "Critical Points",
        #     tellwidth=true)
        Legend(
            fig[2, 1],
            ax,
            "Critical Points",
            orientation = :horizontal,  # Make legend horizontal for better space usage
            tellwidth = false,         # Don't have legend width affect layout
            tellheight = true
        )

        # record(fig, "trefethern_rotation_d30.mp4", 1:240; framerate=30) do frame
        #     ax.azimuth[] = 1.7pi + 0.4 * sin(2pi * frame / 240)
        #     ax.elevation[] = pi / 4 + 0.3 * cos(2pi * frame / 240)
        # end

        display(fig)
        return fig
    end
end

function Globtim.plot_polyapprox_animate(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int, Int} = (1000, 600)
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size = figure_size)
        ax = Axis3(
            fig[1, 1],
            title = "",
            xlabel = "X-axis",
            ylabel = "Y-axis",
            zlabel = "Z-axis"
        )

        # Surface plotting (like in plot_polyapprox_rotate)
        x_unique = sort(unique(coords[:, 1]))
        y_unique = sort(unique(coords[:, 2]))
        Z = fill(NaN, (length(y_unique), length(x_unique)))

        for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
            i = findlast(≈(y), y_unique)
            j = findlast(≈(x), x_unique)
            if !isnothing(i) && !isnothing(j)
                Z[j, i] = z
            end
        end

        surface!(
            ax,
            x_unique,
            y_unique,
            Z,
            colormap = :viridis,
            transparency = true,
            alpha = 0.8
        )

        # Point plotting (like in your other functions)
        if :close in propertynames(df)
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(
                    ax,
                    df.x1[not_close_idx],
                    df.x2[not_close_idx],
                    df.z[not_close_idx],
                    markersize = 5,
                    color = :orange,
                    label = "Far"
                )
            end

            close_idx = df.close
            if any(close_idx)
                scatter!(
                    ax,
                    df.x1[close_idx],
                    df.x2[close_idx],
                    df.z[close_idx],
                    markersize = 10,
                    color = :green,
                    label = "Near"
                )
            end
        end

        # Add legend
        Legend(fig[1, 2], ax, "Critical Points", tellwidth = true)

        # Simple rotation animation (will play in window)
        for θ in range(0, 2π, length = 100)
            ax.azimuth[] = θ
            ax.elevation[] = π / 6
            sleep(0.03)  # Adjust speed
            display(fig)
        end

        return fig
    end
end


function Globtim.plot_polyapprox_flyover(
    pol::ApproxPoly,
    TR::test_input,
    df_lege::DataFrame,  # renamed to df_lege to be explicit
    df_min::DataFrame;
    figure_size::Tuple{Int, Int} = (1000, 600),
    surface_alpha::Float64 = 0.8,
    frames_per_point::Int = 60,
    camera_radius::Float64 = 2.0,
    camera_height::Float64 = 2.0,
    surface_point_size::Int = 2,
    close_point_size::Int = 10,
    far_point_size::Int = 5,
    min_point_size::Int = 10
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size = figure_size)
        ax = Axis3(
            fig[1, 1],
            title = "",
            xlabel = "X-axis",
            ylabel = "Y-axis",
            zlabel = "Z-axis",
            aspect = (1, 1, 1),
            viewmode = :fit
        )

        # Surface plotting
        x_unique = sort(unique(coords[:, 1]))
        y_unique = sort(unique(coords[:, 2]))
        Z = fill(NaN, (length(y_unique), length(x_unique)))

        for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
            i = findlast(≈(y), y_unique)
            j = findlast(≈(x), x_unique)
            if !isnothing(i) && !isnothing(j)
                Z[j, i] = z
            end
        end

        surface!(
            ax,
            x_unique,
            y_unique,
            Z,
            colormap = :viridis,
            transparency = true,
            alpha = surface_alpha
        )

        # Points plotting
        green_points = Point3f[]

        # Plot points where close != 1 (far points)
        far_idx = df_lege.close .!= 1
        if any(far_idx)
            scatter!(
                ax,
                df_lege.x1[far_idx],
                df_lege.x2[far_idx],
                df_lege.z[far_idx],
                markersize = far_point_size,
                color = :orange,
                label = "Far"
            )
        end

        # Plot points where close == 1 (near points)
        close_idx = df_lege.close .== 1
        if any(close_idx)
            green_points = [
                Point3f(x, y, z) for (x, y, z) in
                zip(df_lege.x1[close_idx], df_lege.x2[close_idx], df_lege.z[close_idx])
            ]

            scatter!(
                ax,
                df_lege.x1[close_idx],
                df_lege.x2[close_idx],
                df_lege.z[close_idx],
                markersize = close_point_size,
                color = :green,
                label = "Near"
            )
        end

        # Plot uncaptured minimizers
        uncaptured_idx = .!df_min.captured
        if any(uncaptured_idx)
            scatter!(
                ax,
                df_min.x1[uncaptured_idx],
                df_min.x2[uncaptured_idx],
                df_min.value[uncaptured_idx],
                markersize = min_point_size,
                marker = :diamond,
                color = :red,
                label = "Uncaptured minima"
            )
        end

        # Add legend
        Legend(fig[1, 2], ax, "Critical Points", tellwidth = true)

        # Create animation flying over points where close == 1
        if !isempty(green_points)
            frames = 1:(frames_per_point * length(green_points))

            record(fig, "trefethen_flyover.mp4", frames; framerate = 30) do frame
                point_idx = (frame ÷ frames_per_point) + 1
                point_idx = min(point_idx, length(green_points))
                current_point = green_points[point_idx]

                frame_in_point = (frame % frames_per_point) / frames_per_point

                # Update camera angles
                ax.azimuth[] = 2π * frame_in_point
                ax.elevation[] = π / 6

                # Center view on current point
                xlims!(
                    ax,
                    current_point[1] - camera_radius,
                    current_point[1] + camera_radius
                )
                ylims!(
                    ax,
                    current_point[2] - camera_radius,
                    current_point[2] + camera_radius
                )
                zlims!(ax, current_point[3], current_point[3] + camera_height)
            end
        end

        display(fig)
        return fig
    end
end


function Globtim.plot_polyapprox_animate2(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int, Int} = (1000, 600),
    filename::String = "crit_pts_animation.mp4",
    nframes::Int = 240,
    framerate::Int = 30
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size = figure_size)
        ax = Axis3(
            fig[1, 1],
            title = "",
            xlabel = "X-axis",
            ylabel = "Y-axis",
            zlabel = "Z-axis"
        )

        # Collect ALL z-values for limits
        z_values = Float64[]

        # Add surface z-values
        append!(z_values, z_coords)

        # Add z-values from main dataframe
        if :z in propertynames(df)
            append!(z_values, df.z)
        end

        # Add values from minimizers dataframe
        if :value in propertynames(df_min)
            append!(z_values, df_min.value)
        end

        # Set z limits using all values
        z_min, z_max = extrema(z_values)
        zlims!(ax, z_min, z_max)

        # Rest of plotting code remains the same...
        x_unique = sort(unique(coords[:, 1]))
        y_unique = sort(unique(coords[:, 2]))
        Z = fill(NaN, (length(y_unique), length(x_unique)))

        for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
            i = findlast(≈(y), y_unique)
            j = findlast(≈(x), x_unique)
            if !isnothing(i) && !isnothing(j)
                Z[j, i] = z
            end
        end

        surface!(
            ax,
            x_unique,
            y_unique,
            Z,
            colormap = :viridis,
            transparency = true,
            alpha = 0.8
        )

        if :close in propertynames(df)
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(
                    ax,
                    df.x1[not_close_idx],
                    df.x2[not_close_idx],
                    df.z[not_close_idx],
                    markersize = 5,
                    color = :orange,
                    label = "Far"
                )
            end

            close_idx = df.close
            if any(close_idx)
                scatter!(
                    ax,
                    df.x1[close_idx],
                    df.x2[close_idx],
                    df.z[close_idx],
                    markersize = 10,
                    color = :green,
                    label = "Near"
                )
            end
        end

        # Plot uncaptured minimizers
        uncaptured_idx = .!df_min.captured
        if any(uncaptured_idx)
            scatter!(
                ax,
                df_min.x1[uncaptured_idx],
                df_min.x2[uncaptured_idx],
                df_min.value[uncaptured_idx],
                markersize = 10,
                marker = :diamond,
                color = :red,
                label = "Uncaptured minima"
            )
        end

        Legend(fig[1, 2], ax, "Critical Points", tellwidth = true)

        record(fig, filename, 1:nframes; framerate = framerate) do frame
            ax.azimuth[] = 1.7pi + 0.4 * sin(2pi * frame / nframes)
            ax.elevation[] = pi / 4 + 0.3 * cos(2pi * frame / nframes)
        end

        display(fig)
        return fig
    end
end


function Globtim.create_level_set_animation(
    f,
    grid::Array{SVector{3, T}, 3},
    df::Union{DataFrame, Nothing},
    z_range::Tuple{T, T},
    params::VisualizationParameters{T} = VisualizationParameters{T}(),
    fps::Int = 30,
    duration::Int = 20  # seconds
) where {T <: AbstractFloat}
    grid_points = vec(grid)
    valid_points = filter(p -> !any(isnan, p), grid_points)

    z_min, z_max = z_range

    fig = Figure(size = params.fig_size)
    ax = Axis3(
        fig[1, 1],
        title = "Level Set Visualization",
        xlabel = "x₁",
        ylabel = "x₂",
        zlabel = "x₃"
    )

    # Set up initial ranges and limits
    x_range = extrema(p[1] for p in valid_points)
    y_range = extrema(p[2] for p in valid_points)
    z_range_grid = extrema(p[3] for p in valid_points)
    limits!(ax, x_range..., y_range..., z_range_grid...)

    # Pre-compute function values
    values = zeros(T, size(grid)...)
    @inbounds for i in eachindex(grid_points)
        point = grid_points[i]
        values[i] = any(isnan, point) ? NaN : f(point)
    end

    level_points = Observable(Point3f[])
    data_points = Observable(Point3f[])

    scatter!(ax, level_points, color = :blue, markersize = 2, label = "Level Set")

    if !isnothing(df)
        scatter!(
            ax,
            data_points,
            color = :darkorange,
            marker = :diamond,
            markersize = 20,
            label = "Data Points"
        )
    end

    function update_visualization(level::T) where {T <: AbstractFloat}
        level_data =
            prepare_level_set_data(grid, values, level, tolerance = params.point_tolerance)

        formatted_data = to_makie_format(level_data)

        new_points = Point3f[]
        if !isempty(formatted_data.xyz[1])
            for (x, y, z) in zip(formatted_data.xyz...)
                if !any(isnan, (x, y, z))
                    push!(new_points, Point3f(x, y, z))
                end
            end
        end
        level_points[] = new_points

        if !isnothing(df)
            visible_points = Point3f[]
            for row in eachrow(df)
                if !any(isnan, [row["x1"], row["x2"], row["x3"], row["z"]]) &&
                   abs(row["z"] - level) ≤ params.point_tolerance
                    push!(visible_points, Point3f(row["x1"], row["x2"], row["x3"]))
                end
            end
            data_points[] = visible_points
        end
    end

    axislegend(ax, position = :rt)

    # Animation parameters
    total_frames = fps * duration
    θ = range(0, π, length = total_frames)  # Two full rotations
    levels = range(z_min, z_max, length = total_frames)

    record(fig, "level_set_animation.mp4", 1:total_frames; framerate = fps) do frame
        # Update camera position
        ax.azimuth[] = θ[frame]

        # Update level set
        update_visualization(levels[frame])
    end

    return fig
end
