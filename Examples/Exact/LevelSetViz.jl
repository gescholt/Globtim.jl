module LevelSetViz

using StaticArrays, DataFrames
using GLMakie
using Parameters

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

# Arguments
- `grid::Array{SVector{3,T}}`: Array of 3D points
- `values::Array{T}`: Function values at grid points
- `level::T`: Target level value
- `tolerance::T`: Distance tolerance for point inclusion (default: 1e-2)

# Returns
- `LevelSetData{T}`: Structure containing points near the level set
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

# Arguments
- `level_set::LevelSetData{T}`: Level set data structure

# Returns
- `NamedTuple`: Contains points matrix and coordinate vectors for plotting
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

# Arguments
- `formatted_data`: Data in Makie format from to_makie_format
- `fig_size`: Tuple specifying figure dimensions (default: (800, 600))
- `marker_size`: Size of scatter points (default: 4)
- `title`: Plot title (default: "Level Set Visualization")

# Returns
- Makie Figure object
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

    # Extract coordinates using existing views
    scatter!(ax, formatted_data.xyz..., markersize=marker_size)

    display(fig)
    return fig
end

"""
    create_level_set_visualization(
        f, 
        grid::Array{SVector{3,T}}, 
        df::DataFrame,
        z_range::Tuple{T,T},
        params::VisualizationParameters=VisualizationParameters()
    ) where {T<:AbstractFloat}

Create an interactive visualization of level sets with a slider control.

# Arguments
- `f`: Function to visualize, must accept SVector{3,T} and return T
- `grid`: Array of 3D points for evaluation
- `df`: DataFrame with columns :x1, :x2, :x3, :z for data points
- `z_range`: Tuple of (min_z, max_z) for level set range
- `params`: Visualization parameters (see VisualizationParameters struct)

# Returns
- Figure object with interactive controls

# Example
```julia
using StaticArrays, DataFrames

# Define function and grid
f(p::SVector{3,Float64}) = p[1]^2 + p[2]^2 + p[3]^2
x_range = range(-2, 2, length=50)
grid = [SVector{3,Float64}(x,y,z) for x in x_range, y in x_range, z in x_range]

# Create sample data
df = DataFrame(
    x1 = randn(100),
    x2 = randn(100),
    x3 = randn(100)
)
df.z = map(row -> f(SVector{3,Float64}(row.x1, row.x2, row.x3)), eachrow(df))

# Create visualization
fig = create_level_set_visualization(f, grid, df, (1.0, 4.0))
```
"""
function create_level_set_visualization(
    f,
    grid::Array{SVector{3,T}},
    df::DataFrame,
    z_range::Tuple{T,T},
    params::VisualizationParameters{T}=VisualizationParameters{T}()
) where {T<:AbstractFloat}

    # Validate inputs
    @assert all(col -> col in names(df), [:x1, :x2, :x3, :z]) "DataFrame must have columns :x1, :x2, :x3, :z"
    @assert z_range[1] < z_range[2] "z_range must be ordered (min, max)"

    # Evaluate function on grid
    values = map(f, grid)

    # Create figure
    fig = Figure(size=params.fig_size)

    # Create main 3D axis
    ax = Axis3(fig[1, 1],
        title="Level Set Visualization",
        xlabel="x₁",
        ylabel="x₂",
        zlabel="x₃")

    # Set axis limits from grid bounds
    x_min, x_max = extrema(first.(vec(grid)))
    y_min, y_max = extrema(getindex.(vec(grid), 2))
    z_min_grid, z_max_grid = extrema(getindex.(vec(grid), 3))
    limits!(ax, x_min, x_max, y_min, y_max, z_min_grid, z_max_grid)

    # Create level selection slider
    z_min, z_max = z_range
    level_slider = Slider(fig[2, 1],
        range=range(z_min, z_max, length=1000),
        startvalue=z_min)

    # Add current level label
    level_label = Label(fig[3, 1], @lift(string("Level: ", round($(level_slider.value), digits=3))),
        tellwidth=false)

    # Create observables for dynamic updates
    level_points = Observable(Point3f[])
    data_points = Observable(Point3f[])
    point_alphas = Observable(Float32[])

    # Create visualization elements
    scatter!(ax, level_points,
        color=:blue,
        markersize=2,
        label="Level Set")

    data_scatter = scatter!(ax, data_points,
        color=:orange,
        marker=:diamond,
        markersize=6,
        label="Data Points")

    function calculate_point_alpha(z_value::T, level::T, window::T)::Float32 where {T<:AbstractFloat}
        dist = abs(z_value - level)
        return dist > window ? 0.0f0 : Float32(1.0 - (dist / window))
    end

    function update_visualization(level::T) where {T<:AbstractFloat}
        # Update level set points
        level_data = prepare_level_set_data(grid, values, level, tolerance=params.point_tolerance)
        formatted_data = to_makie_format(level_data)

        if !isempty(formatted_data.xyz[1])
            level_points[] = [Point3f(x, y, z) for (x, y, z) in zip(formatted_data.xyz...)]
        else
            level_points[] = Point3f[]
        end

        # Update data points
        visible_points = Point3f[]
        alphas = Float32[]

        for row in eachrow(df)
            alpha = calculate_point_alpha(row.z, level, params.point_window)
            if alpha > 0
                push!(visible_points, Point3f(row.x1, row.x2, row.x3))
                push!(alphas, alpha)
            end
        end

        data_points[] = visible_points
        data_scatter.alpha = alphas
    end

    # Connect slider to updates
    on(level_slider.value) do level
        update_visualization(level)
    end

    # Initialize visualization
    update_visualization(z_min)

    # Add legend
    axislegend(ax, position=:rt)

    return fig
end

# Export public interface
export LevelSetData, VisualizationParameters
export prepare_level_set_data, to_makie_format, plot_level_set
export create_level_set_visualization

end # module