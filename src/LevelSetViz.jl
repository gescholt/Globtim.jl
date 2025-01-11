using Parameters
using GLMakie

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

function plot_polyapprox_levelset(pol::ApproxPoly, TR::test_input, df::DataFrame, df_min::DataFrame)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size=(1000, 600))
        ax = Axis(fig[1, 1], title="Trefethen Function Level Sets",
            xlabel="X-axis", ylabel="Y-axis")

        # Create a regular grid for contour plotting
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
        contourf!(ax, x_unique, y_unique, Z,
            colormap=:viridis,
            levels=30)

        if :close in propertynames(df)
            not_close_idx = .!df.close
            if any(not_close_idx)
                scatter!(ax, df.x1[not_close_idx], df.x2[not_close_idx],
                    markersize=5,
                    color=:orange,
                    label="Far")
            end

            close_idx = df.close
            if any(close_idx)
                scatter!(ax, df.x1[close_idx], df.x2[close_idx],
                    markersize=10,
                    color=:green,
                    label="Near")
            end
        else
            scatter!(ax, df.x1, df.x2,
                markersize=2,
                color=:orange,
                label="All points")
        end

        # Plot uncaptured minimizers from df_min in red
        uncaptured_idx = .!df_min.captured
        if any(uncaptured_idx)
            scatter!(ax, df_min.x1[uncaptured_idx], df_min.x2[uncaptured_idx],
                markersize=10,
                marker=:diamond,
                color=:red,
                label="Uncaptured minima")
        end

        # Add legend to the right of the plot
        Legend(fig[1, 2], ax, "Critical Points",
            tellwidth=true)

        # Add colorbar
        Colorbar(fig[1, 3], limits=(minimum(z_coords), maximum(z_coords)),
            colormap=:viridis,
            label="Function value")

        display(fig)
        return fig
    end
end

function plot_polyapprox_rotate(pol::ApproxPoly, TR::test_input, df::DataFrame, df_min::DataFrame)
    coords = pol.scale_factor * pol.grid .+ TR.center'
    z_coords = pol.z

    if size(coords)[2] == 2
        fig = Figure(size=(1000, 600))
        ax = Axis3(fig[1, 1], title="Trefethen Function",
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
                markersize=20,
                marker=:diamond,
                color=:red,
                label="Uncaptured minima")
        end

        # Add legend to the right of the plot
        Legend(fig[1, 2], ax, "Critical Points",
            tellwidth=true)

        record(fig, "trefethern_rotation_d30.mp4", 1:240; framerate=30) do frame
            ax.azimuth[] = 1.7pi + 0.4 * sin(2pi * frame / 240)
            ax.elevation[] = pi / 4 + 0.3 * cos(2pi * frame / 240)
        end

        display(fig)
        return fig
    end
end