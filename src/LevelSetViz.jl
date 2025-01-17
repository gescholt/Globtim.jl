using Parameters
using GLMakie
using Colors

# Data Structures
"""
    LevelSetData{T<:AbstractFloat}

Structure to hold level set computation results.

# Fields
- `points::Vector{SVector{3,T}}`: Points near the level set
- `values::Vector{T}`: Function values at the points
- `level::T`: The target level value
"""
struct LevelSetData{T<:AbstractFloat}
    points::Vector{SVector{3,T}}
    values::Vector{T}
    level::T

    # Inner constructor for validation
    function LevelSetData{T}(points::Vector{SVector{3,T}}, values::Vector{T}, level::T) where {T<:AbstractFloat}
        length(points) == length(values) || throw(ArgumentError("Points and values must have same length"))
        new{T}(points, values, level)
    end
end

# Outer constructor for type inference
LevelSetData(points::Vector{SVector{3,T}}, values::Vector{T}, level::T) where {T<:AbstractFloat} =
    LevelSetData{T}(points, values, level)

# Parameters
@with_kw struct VisualizationParameters{T<:AbstractFloat}
    point_tolerance::T = 1e-1
    point_window::T = 2e-1
    fig_size::Tuple{Int,Int} = (1000, 800)
end

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
function prepare_level_set_data(
    grid::Array{SVector{3,T}},
    values::Array{T},
    level::T;
    tolerance::T=convert(T, 1e-2)
) where {T<:AbstractFloat}
    size(grid) == size(values) || throw(DimensionMismatch("Grid and values must have same dimensions"))
    tolerance > zero(T) || throw(ArgumentError("Tolerance must be positive"))

    # Flatten arrays for processing
    flat_grid = vec(grid)
    flat_values = vec(values)

    # Find points where function is close to the level value
    level_set_mask = @. abs(flat_values - level) < tolerance

    # Create LevelSetData structure
    LevelSetData(
        flat_grid[level_set_mask],
        flat_values[level_set_mask],
        level
    )
end

"""
    to_makie_format(level_set::LevelSetData{T}) where {T<:AbstractFloat}

Convert LevelSetData to a format suitable for Makie plotting.
"""
function to_makie_format(level_set::LevelSetData{T}) where {T<:AbstractFloat}
    isempty(level_set.points) && return (points=Matrix{T}(undef, 3, 0),
        values=T[],
        xyz=(T[], T[], T[]))

    points = reduce(hcat, level_set.points)
    return (
        points=points,
        values=level_set.values,
        xyz=(view(points, 1, :), view(points, 2, :), view(points, 3, :))
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
function plot_level_set(formatted_data;
    fig_size=(800, 600),
    marker_size=4,
    title="Level Set Visualization")

    fig = Figure(size=fig_size)
    ax = Axis3(fig[1, 1],
        title=title,
        xlabel="x₁",
        ylabel="x₂",
        zlabel="x₃")

    scatter!(ax, formatted_data.xyz..., markersize=marker_size)

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
function create_level_set_visualization(
    f,
    grid::Array{SVector{3,T},3},
    df::DataFrame,
    z_range::Tuple{T,T},
    params::VisualizationParameters{T}=VisualizationParameters{T}()
) where {T<:AbstractFloat}

    fig = Figure(size=params.fig_size)

    ax = Axis3(fig[1, 1],
        title="Level Set Visualization",
        xlabel="x₁",
        ylabel="x₂",
        zlabel="x₃")

    # Extract grid bounds correctly from 3D array of SVectors
    grid_points = vec(grid)  # Flatten the 3D array
    x_range = extrema(p[1] for p in grid_points)
    y_range = extrema(p[2] for p in grid_points)
    z_range_grid = extrema(p[3] for p in grid_points)

    limits!(ax, x_range..., y_range..., z_range_grid...)

    # Create level selection slider
    z_min, z_max = z_range
    level_slider = Slider(fig[2, 1],
        range=range(z_min, z_max, length=1000),
        startvalue=z_min)

    level_label = Label(fig[3, 1],
        @lift(string("Level: ", round($(level_slider.value), digits=3))),
        tellwidth=false)

    # Observables for points
    level_points = Observable(Point3f[])
    data_points = Observable(Point3f[])

    # Create visualization elements
    scatter!(ax, level_points,
        color=:blue,
        markersize=2,
        label="Level Set")

    scatter!(ax, data_points,
        color=:orange,
        marker=:diamond,
        markersize=20,
        label="Data Points")

    function update_visualization(level::T) where {T<:AbstractFloat}
        # Update level set points
        values = reshape(map(f, grid_points), size(grid))  # Preserve 3D structure
        level_data = prepare_level_set_data(grid, values, level, tolerance=params.point_tolerance)
        formatted_data = to_makie_format(level_data)

        # Update grid points
        if !isempty(formatted_data.xyz[1])
            level_points[] = [Point3f(x, y, z) for (x, y, z) in zip(formatted_data.xyz...)]
        else
            level_points[] = Point3f[]
        end

        # Update data points using same tolerance
        visible_points = Point3f[]
        for row in eachrow(df)
            if abs(row["z"] - level) ≤ params.point_tolerance
                push!(visible_points, Point3f(row["x1"], row["x2"], row["x3"]))
            end
        end
        data_points[] = visible_points
    end

    on(level_slider.value) do level
        update_visualization(level)
    end

    update_visualization(z_min)
    axislegend(ax, position=:rt)

    return fig
end

function plot_polyapprox_levelset(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int,Int}=(1000, 600),
    z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing,
    chebyshev_levels::Bool=false,  # New parameter to toggle Chebyshev distribution
    num_levels::Int=30            # Number of levels (default=30)
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size=figure_size)
        ax = Axis(fig[1, 1], title="")

        # Calculate z_limits if not provided - now only using dataframe points
        if isnothing(z_limits)
            z_values = Float64[]
            append!(z_values, df.z)          # Points from main dataframe
            append!(z_values, df_min.value)  # Values from minimizers
            z_limits = (minimum(z_values), maximum(z_values))
        end

        # Calculate levels using Chebyshev nodes if requested
        levels = if chebyshev_levels
            # Generate Chebyshev nodes in [-1, 1]
            k = collect(0:num_levels-1)
            cheb_nodes = -cos.((2k .+ 1) .* π ./ (2 * num_levels))

            # Map from [-1, 1] to [z_min, z_max]
            z_min, z_max = z_limits
            (z_max - z_min) ./ 2 .* cheb_nodes .+ (z_max + z_min) ./ 2
        else
            num_levels  # Default linear spacing
        end

        # Rest of plotting code same as before
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

        contourf!(ax, x_unique, y_unique, Z,
            colormap=:inferno,
            levels=levels)

        if :close in propertynames(df)
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(ax, df.x1[not_close_idx], df.x2[not_close_idx],
                    markersize=5,
                    color=:white,
                    strokecolor=:black,      # border color
                    strokewidth=1,
                    label="Far")
            end

            close_idx = df.close
            if any(close_idx)
                scatter!(ax, df.x1[close_idx], df.x2[close_idx],
                    markersize=10,
                    color=:green,
                    strokecolor=:black,      # border color
                    strokewidth=1,
                    label="Near")
            end
        else
            scatter!(ax, df.x1, df.x2,
                markersize=2,
                color=:orange,
                label="All points")
        end

        uncaptured_idx = .!df_min.captured
        if any(uncaptured_idx)
            scatter!(ax, df_min.x1[uncaptured_idx], df_min.x2[uncaptured_idx],
                markersize=15,
                marker=:diamond,
                color=:blue,
                label="Uncaptured")
        end

        Legend(fig[1, 2], ax, "Critical Points",
            tellwidth=true)

        Colorbar(fig[1, 3], limits=z_limits,
            colormap=:viridis,
            label="")

        display(fig)
        return fig
    end
end

function plot_polyapprox_rotate(pol::ApproxPoly, TR::test_input, df::DataFrame, df_min::DataFrame)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size=(1000, 600))
        ax = Axis3(fig[1, 1], title="",
            xlabel="X-axis", ylabel="Y-axis", zlabel="Z-axis")

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

        surface!(ax, x_unique, y_unique, Z,
            colormap=:viridis,
            transparency=true,
            alpha=0.8)

        if :close in propertynames(df)
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(ax, df.x1[not_close_idx], df.x2[not_close_idx],
                    df.z[not_close_idx],
                    markersize=5,
                    color=:orange,
                    label="Far")
            end

            close_idx = df.close
            if any(close_idx)
                scatter!(ax, df.x1[close_idx], df.x2[close_idx],
                    df.z[close_idx],
                    markersize=10,
                    color=:green,
                    label="Near")
            end
        else
            scatter!(ax, df.x1, df.x2,
                df.z,
                markersize=2,
                color=:orange,
                label="All points")
        end

        # Plot uncaptured minimizers from df_min in red
        uncaptured_idx = .!df_min.captured
        if any(uncaptured_idx)
            scatter!(ax, df_min.x1[uncaptured_idx], df_min.x2[uncaptured_idx],
                df_min.value[uncaptured_idx],
                markersize=10,
                marker=:diamond,
                color=:red,
                label="Uncaptured minima")
        end

        # Add legend to the right of the plot
        # Legend(fig[1, 2], ax, "Critical Points",
        #     tellwidth=true)
        Legend(fig[2, 1], ax, "Critical Points",
            orientation=:horizontal,  # Make legend horizontal for better space usage
            tellwidth=false,         # Don't have legend width affect layout
            tellheight=true)

        # record(fig, "trefethern_rotation_d30.mp4", 1:240; framerate=30) do frame
        #     ax.azimuth[] = 1.7pi + 0.4 * sin(2pi * frame / 240)
        #     ax.elevation[] = pi / 4 + 0.3 * cos(2pi * frame / 240)
        # end

        display(fig)
        return fig
    end
end

function plot_polyapprox_animate(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int,Int}=(1000, 600)
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size=figure_size)
        ax = Axis3(fig[1, 1],
            title="",
            xlabel="X-axis",
            ylabel="Y-axis",
            zlabel="Z-axis")

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

        surface!(ax, x_unique, y_unique, Z,
            colormap=:viridis,
            transparency=true,
            alpha=0.8)

        # Point plotting (like in your other functions)
        if :close in propertynames(df)
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(ax, df.x1[not_close_idx], df.x2[not_close_idx],
                    df.z[not_close_idx],
                    markersize=5,
                    color=:orange,
                    label="Far")
            end

            close_idx = df.close
            if any(close_idx)
                scatter!(ax, df.x1[close_idx], df.x2[close_idx],
                    df.z[close_idx],
                    markersize=10,
                    color=:green,
                    label="Near")
            end
        end

        # Add legend
        Legend(fig[1, 2], ax, "Critical Points", tellwidth=true)

        # Simple rotation animation (will play in window)
        for θ in range(0, 2π, length=100)
            ax.azimuth[] = θ
            ax.elevation[] = π / 6
            sleep(0.03)  # Adjust speed
            display(fig)
        end

        return fig
    end
end


function plot_polyapprox_flyover(
    pol::ApproxPoly,
    TR::test_input,
    df_lege::DataFrame,  # renamed to df_lege to be explicit
    df_min::DataFrame;
    figure_size::Tuple{Int,Int}=(1000, 600),
    surface_alpha::Float64=0.8,
    frames_per_point::Int=60,
    camera_radius::Float64=2.0,
    camera_height::Float64=2.0,
    surface_point_size::Int=2,
    close_point_size::Int=10,
    far_point_size::Int=5,
    min_point_size::Int=10
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size=figure_size)
        ax = Axis3(fig[1, 1],
            title="",
            xlabel="X-axis",
            ylabel="Y-axis",
            zlabel="Z-axis",
            aspect=(1, 1, 1),
            viewmode=:fit
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

        surface!(ax, x_unique, y_unique, Z,
            colormap=:viridis,
            transparency=true,
            alpha=surface_alpha)

        # Points plotting
        green_points = Point3f[]

        # Plot points where close != 1 (far points)
        far_idx = df_lege.close .!= 1
        if any(far_idx)
            scatter!(ax, df_lege.x1[far_idx], df_lege.x2[far_idx],
                df_lege.z[far_idx],
                markersize=far_point_size,
                color=:orange,
                label="Far")
        end

        # Plot points where close == 1 (near points)
        close_idx = df_lege.close .== 1
        if any(close_idx)
            green_points = [Point3f(x, y, z) for (x, y, z) in
                            zip(df_lege.x1[close_idx], df_lege.x2[close_idx], df_lege.z[close_idx])]

            scatter!(ax, df_lege.x1[close_idx], df_lege.x2[close_idx], df_lege.z[close_idx],
                markersize=close_point_size,
                color=:green,
                label="Near")
        end

        # Plot uncaptured minimizers
        uncaptured_idx = .!df_min.captured
        if any(uncaptured_idx)
            scatter!(ax, df_min.x1[uncaptured_idx], df_min.x2[uncaptured_idx],
                df_min.value[uncaptured_idx],
                markersize=min_point_size,
                marker=:diamond,
                color=:red,
                label="Uncaptured minima")
        end

        # Add legend
        Legend(fig[1, 2], ax, "Critical Points",
            tellwidth=true)

        # Create animation flying over points where close == 1
        if !isempty(green_points)
            frames = 1:frames_per_point*length(green_points)

            record(fig, "trefethen_flyover.mp4", frames; framerate=30) do frame
                point_idx = (frame ÷ frames_per_point) + 1
                point_idx = min(point_idx, length(green_points))
                current_point = green_points[point_idx]

                frame_in_point = (frame % frames_per_point) / frames_per_point

                # Update camera angles
                ax.azimuth[] = 2π * frame_in_point
                ax.elevation[] = π / 6

                # Center view on current point
                xlims!(ax, current_point[1] - camera_radius, current_point[1] + camera_radius)
                ylims!(ax, current_point[2] - camera_radius, current_point[2] + camera_radius)
                zlims!(ax, current_point[3], current_point[3] + camera_height)
            end
        end

        display(fig)
        return fig
    end
end


function plot_polyapprox_animate2(
    pol::ApproxPoly,
    TR::test_input,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int,Int}=(1000, 600),
    filename::String="crit_pts_animation.mp4",
    nframes::Int=240,
    framerate::Int=30
)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size=figure_size)
        ax = Axis3(fig[1, 1],
            title="",
            xlabel="X-axis",
            ylabel="Y-axis",
            zlabel="Z-axis")

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

        surface!(ax, x_unique, y_unique, Z,
            colormap=:viridis,
            transparency=true,
            alpha=0.8)

        if :close in propertynames(df)
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(ax, df.x1[not_close_idx], df.x2[not_close_idx],
                    df.z[not_close_idx],
                    markersize=5,
                    color=:orange,
                    label="Far")
            end

            close_idx = df.close
            if any(close_idx)
                scatter!(ax, df.x1[close_idx], df.x2[close_idx],
                    df.z[close_idx],
                    markersize=10,
                    color=:green,
                    label="Near")
            end
        end

        # Plot uncaptured minimizers
        uncaptured_idx = .!df_min.captured
        if any(uncaptured_idx)
            scatter!(ax, df_min.x1[uncaptured_idx], df_min.x2[uncaptured_idx],
                df_min.value[uncaptured_idx],
                markersize=10,
                marker=:diamond,
                color=:red,
                label="Uncaptured minima")
        end

        Legend(fig[1, 2], ax, "Critical Points", tellwidth=true)

        record(fig, filename, 1:nframes; framerate=framerate) do frame
            ax.azimuth[] = 1.7pi + 0.4 * sin(2pi * frame / nframes)
            ax.elevation[] = pi / 4 + 0.3 * cos(2pi * frame / nframes)
        end

        display(fig)
        return fig
    end
end