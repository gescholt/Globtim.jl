# grid_utils.jl
# Utility functions for handling different grid formats in Globtim

using StaticArrays

"""
    grid_to_matrix(grid::Array{SVector{N,T},N}) where {N,T}

Convert a grid from Array{SVector} format to Matrix format required by Vandermonde operations.

# Arguments
- `grid`: N-dimensional array of SVectors, typically from `generate_grid`

# Returns
- `Matrix{T}`: Matrix where each row is a point and columns are dimensions

# Example
```julia
grid = generate_grid(2, 10, basis=:chebyshev)  # 11×11 Array{SVector{2,Float64},2}
matrix = grid_to_matrix(grid)                   # 121×2 Matrix{Float64}
```
"""
function grid_to_matrix(grid::Array{SVector{N, T}, N}) where {N, T}
    # Reshape to 1D array of SVectors, transpose each to row, then concatenate
    return reduce(vcat, map(x -> x', reshape(grid, :)))
end

"""
    ensure_matrix_format(grid)

Ensure grid is in matrix format, converting if necessary.

# Arguments
- `grid`: Either Array{SVector} or Matrix format

# Returns
- `Matrix`: Grid in matrix format suitable for Vandermonde operations

# Details
This function checks the input type and:
- Returns Matrix inputs unchanged
- Converts Array{SVector} inputs using `grid_to_matrix`
- Provides a unified interface for functions that need matrix format
"""
function ensure_matrix_format(grid)
    if isa(grid, Matrix)
        return grid
    elseif isa(grid, Array{<:SVector})
        return grid_to_matrix(grid)
    else
        error("Unsupported grid format: $(typeof(grid))")
    end
end

"""
    matrix_to_grid(matrix::Matrix{T}, dim::Int) where T

Convert a matrix format grid back to Array{SVector} format.

# Arguments
- `matrix`: Matrix where each row is a point
- `dim`: Dimension of the space

# Returns
- Array{SVector{dim,T},dim}: Grid in SVector array format

# Example
```julia
matrix = rand(121, 2)  # 121 points in 2D
grid = matrix_to_grid(matrix, 2)  # 11×11 Array{SVector{2,Float64},2}
```
"""
function matrix_to_grid(matrix::Matrix{T}, dim::Int) where {T}
    n_points = size(matrix, 1)
    points_per_dim = round(Int, n_points^(1 / dim))

    # Verify we have the right number of points for a regular grid
    if points_per_dim^dim != n_points
        error(
            "Matrix has $n_points points, which is not a perfect power for dimension $dim"
        )
    end

    # Convert each row to an SVector
    svectors = [SVector{dim, T}(matrix[i, :]) for i in 1:n_points]

    # Reshape into the appropriate dimensional array
    return reshape(svectors, ntuple(_ -> points_per_dim, dim))
end

"""
    get_grid_info(grid)

Get information about a grid regardless of its format.

# Returns
NamedTuple with:
- `format`: :matrix or :svector_array
- `n_points`: Total number of points
- `dim`: Dimension of the space
- `is_regular`: Whether it appears to be a regular grid
"""
function get_grid_info(grid)
    if isa(grid, Matrix)
        return (
            format = :matrix,
            n_points = size(grid, 1),
            dim = size(grid, 2),
            is_regular = true  # Assume regular for matrix format
        )
    elseif isa(grid, Array{<:SVector})
        N = ndims(grid)
        return (
            format = :svector_array,
            n_points = length(grid),
            dim = N,
            is_regular = all(size(grid, i) == size(grid, 1) for i in 1:N)
        )
    else
        error("Unknown grid format: $(typeof(grid))")
    end
end

"""
    generate_random_interior_point(
        center::Vector{Float64},
        domain_size::Union{Float64, Vector{Float64}},
        dim::Int;
        margin::Float64 = 0.1
    )::Vector{Float64}

Generate a random point in the interior of a domain defined by center and size.

The domain is defined as a hypercube centered at `center` with half-widths given by
`domain_size`. The function generates a point that is guaranteed to be in the interior
by applying a safety margin from the boundaries.

# Arguments
- `center::Vector{Float64}`: Center point of the domain (n-dimensional)
- `domain_size::Union{Float64, Vector{Float64}}`: Half-width of domain. If scalar,
  same size is used for all dimensions. If vector, per-dimension sizes.
- `dim::Int`: Dimension of the space
- `margin::Float64`: Safety margin from boundaries (default 0.1 = stay within 90% of domain)

# Returns
- `Vector{Float64}`: Random point safely interior to the domain

# Details
The function first generates a random point in the standard hypercube [-1, 1]^n,
applies the safety margin, then transforms to the actual domain using:
`point = center + domain_size * scaled_random`

The margin ensures the point is not too close to the boundary. A margin of 0.1 means
the point will be within 90% of the domain extent from the center.

# Examples
```julia
# 4D domain centered at [1, 1, 1, 1] with uniform half-width 0.8
center = [1.0, 1.0, 1.0, 1.0]
p_true = generate_random_interior_point(center, 0.8, 4)

# 4D domain with per-dimension sizes
center = [1.0, 1.0, 1.0, 1.0]
sizes = [0.8, 0.6, 0.9, 0.7]
p_true = generate_random_interior_point(center, sizes, 4)

# With custom safety margin (stay within 80% of domain)
p_true = generate_random_interior_point(center, 0.8, 4, margin=0.2)
```
"""
function generate_random_interior_point(
    center::Vector{Float64},
    domain_size::Union{Float64, Vector{Float64}},
    dim::Int;
    margin::Float64 = 0.1
)::Vector{Float64}
    # Validate inputs
    if length(center) != dim
        error("center dimension ($(length(center))) must match dim ($dim)")
    end

    if margin < 0.0 || margin >= 1.0
        error("margin must be in [0, 1), got $margin")
    end

    # Convert scalar domain_size to vector if needed
    ds = if isa(domain_size, Number)
        fill(Float64(domain_size), dim)
    else
        if length(domain_size) != dim
            error("domain_size vector length ($(length(domain_size))) must match dim ($dim)")
        end
        domain_size
    end

    # Generate random point in [-1, 1]^n with margin
    # interior_factor scales the range to stay away from boundaries
    interior_factor = 1.0 - margin
    random_unit = interior_factor .* (2.0 .* rand(dim) .- 1.0)

    # Transform to actual domain: center + domain_size * random_unit
    return center .+ ds .* random_unit
end

# Export the utility functions
export grid_to_matrix, ensure_matrix_format, matrix_to_grid, get_grid_info, generate_random_interior_point
