"""
    LevelSetData{T<:Real}

Structure to hold level set computation results.

# Fields
- `points::Vector{SVector{3,T}}`: Points near the level set
- `values::Vector{T}`: Function values at the points
- `level::T`: The target level value
"""
struct LevelSetData{T<:Real}
    points::Vector{SVector{3,T}}
    values::Vector{T}
    level::T

    # Inner constructor for validation
    function LevelSetData{T}(points::Vector{SVector{3,T}}, values::Vector{T}, level::T) where {T<:Real}
        length(points) == length(values) || throw(ArgumentError("Points and values must have same length"))
        new{T}(points, values, level)
    end
end

# Outer constructor for type inference
LevelSetData(points::Vector{SVector{3,T}}, values::Vector{T}, level::T) where {T<:Real} =
    LevelSetData{T}(points, values, level)

"""
    evaluate_on_grid(f, grid::Array{SVector{3,T}}) where {T<:AbstractFloat}

Evaluate a function on a grid of points.

# Arguments
- `f`: Function or callable object to evaluate
- `grid::Array{SVector{3,T}}`: Array of 3D points

# Returns
- Array of function values at grid points
"""
function evaluate_on_grid(f, grid::Array{SVector{3,T}}) where {T<:AbstractFloat}
    wrapped_f = f isa Function ? Error_distance_wrapper(f) : f
    return map(wrapped_f, grid)
end

"""
    prepare_level_set_data(grid::Array{SVector{3,T}}, values::Array{T}, level::T; 
                          tolerance::T=convert(T, 1e-2)) where {T<:Real}

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
) where {T<:Real}
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
    to_makie_format(level_set::LevelSetData{T}) where {T<:Real}

Convert LevelSetData to a format suitable for Makie plotting.

# Arguments
- `level_set::LevelSetData{T}`: Level set data structure

# Returns
- `NamedTuple`: Contains points matrix and coordinate vectors for plotting
"""
function to_makie_format(level_set::LevelSetData{T}) where {T<:Real}
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
    plot_level_set(formatted_data; 
                   fig_size=(800, 600), 
                   marker_size=4, 
                   title="Level Set Visualization")

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
        xlabel="X-axis",
        ylabel="Y-axis",
        zlabel="Z-axis")

    # Extract coordinates using existing views
    scatter!(ax, formatted_data.xyz..., markersize=marker_size)

    display(fig)
    return fig
end