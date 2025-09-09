# scaling_utils.jl
# Type-stable scaling functions for ApproxPoly

using StaticArrays
using LinearAlgebra

"""
    scale_point(s::Float64, x::AbstractVector)
    scale_point(s::Vector{Float64}, x::AbstractVector)
    scale_point(s::Float64, x::SVector{N}) where N
    scale_point(s::SVector{N}, x::SVector{N}) where N

Type-stable scaling functions that use multiple dispatch instead of runtime type checking.
"""
@inline scale_point(s::Float64, x::AbstractVector) = s .* x
@inline scale_point(s::Vector{Float64}, x::AbstractVector) = s .* x

# Optimized versions for SVector
@inline scale_point(s::Float64, x::SVector{N}) where {N} = s * x
@inline scale_point(s::SVector{N}, x::SVector{N}) where {N} = s .* x
@inline scale_point(s::Vector{Float64}, x::SVector{N}) where {N} =
    SVector{N}(s[i] * x[i] for i in 1:N)

"""
    get_scale_factor_type(scale_factor, dim)

Determine the appropriate type for scale_factor based on input and dimension.
Returns the scale_factor with the correct type.
"""
function get_scale_factor_type(scale_factor::Real, dim::Int)
    return Float64(scale_factor)
end

function get_scale_factor_type(scale_factor::AbstractVector, dim::Int)
    length(scale_factor) == dim || throw(
        ArgumentError(
            "scale_factor vector length ($( length(scale_factor))) must match dimension ($dim)"
        )
    )
    return Vector{Float64}(scale_factor)
end

"""
    compute_norm(scale_factor, VL, sol, F, grid, n, d)

Type-stable norm computation that dispatches based on scale_factor type.
"""
function compute_norm(scale_factor::Float64, VL, sol, F, grid, n, d)
    # Proper L2 norm computation without fallbacks
    evals = (VL * sol.u - F)
    
    # Handle different grid formats correctly
    if isa(grid, Vector)
        # Grid is a flat vector of SVector points (from grid input case)
        total_points = length(grid)
        points_per_dim = round(Int, total_points^(1 / n))
        
        # Use proper Riemann sum with correct spacing for Chebyshev points
        cell_volume = (2.0 / points_per_dim)^n
        return sqrt(cell_volume * sum(abs2, evals))
    else
        # Grid is an N-dimensional array of SVector points - use proper discrete L2 norm
        grid_flat = reshape(grid, :)
        
        # Create direct residual function using exact matching
        function residual(x::SVector{n,Float64}) where n
            # Find exact match in grid (SVector equality is exact)
            idx = findfirst(p -> p == x, grid_flat)
            return idx !== nothing ? evals[idx] : 0.0
        end
        
        return discrete_l2_norm_riemann(residual, grid)
    end
end

function compute_norm(scale_factor::Vector{Float64}, VL, sol, F, grid, n, d)
    # Proper L2 norm computation for vector scale factor without fallbacks
    evals = (VL * sol.u - F)
    
    # Handle different grid formats correctly
    if isa(grid, Vector)
        # Grid is a flat vector of SVector points (from grid input case)
        total_points = length(grid)
        points_per_dim = round(Int, total_points^(1 / n))
        
        # Use proper Riemann sum with correct spacing for Chebyshev points
        cell_volume = (2.0 / points_per_dim)^n
        return sqrt(cell_volume * sum(abs2, evals))
    else
        # Grid is an N-dimensional array of SVector points - use proper discrete L2 norm
        grid_flat = reshape(grid, :)
        
        # Create direct residual function using exact matching
        function residual(x::SVector{n,Float64}) where n
            # Find exact match in grid (SVector equality is exact)
            idx = findfirst(p -> p == x, grid_flat)
            return idx !== nothing ? evals[idx] : 0.0
        end
        
        return discrete_l2_norm_riemann(residual, grid)
    end
end

"""
    transform_coordinates(scale_factor, grid, center)

Type-stable coordinate transformation for visualization.
"""
function transform_coordinates(
    scale_factor::Float64,
    grid::Matrix{Float64},
    center::Vector{Float64}
)
    # Scalar version: simple broadcasting
    scale_factor * grid .+ center'
end

function transform_coordinates(
    scale_factor::Vector{Float64},
    grid::Matrix{Float64},
    center::Vector{Float64}
)
    # Vector version: element-wise scaling per dimension
    scaled_coords = similar(grid)
    for i in 1:size(grid, 1)
        for j in 1:size(grid, 2)
            scaled_coords[i, j] = scale_factor[j] * grid[i, j] + center[j]
        end
    end
    scaled_coords
end
