# scaling_utils.jl
# Type-stable scaling functions for ApproxPoly

using StaticArrays
using LinearAlgebra

# Load quadrature weight computation
include("quadrature_weights.jl")

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
    compute_norm(scale_factor, VL, sol, F, basis, GN, n)

Compute L2-norm of approximation error using proper quadrature weights.

This function computes the discrete L2-norm approximation of ||f - p||_L2 where:
- f are the function values at grid points (F)
- p are the polynomial approximation values (VL * sol.u)
- The norm is computed using appropriate quadrature weights for the grid type

# Arguments
- `scale_factor`: Domain scaling factor (scalar or vector, unused for norm computation)
- `VL`: Vandermonde-like matrix evaluated at grid points
- `sol`: Solution object containing polynomial coefficients (sol.u)
- `F`: Function values at grid points
- `basis::Symbol`: Basis type (:chebyshev or :legendre)
- `GN::Int`: Grid parameter (grid has GN+1 points per dimension)
- `n::Int`: Number of dimensions

# Returns
- `Float64`: Approximate L2-norm using quadrature

# Notes
- Grid points are REUSED (not re-evaluated) - only weights are computed
- For Chebyshev grids: Uses Clenshaw-Curtis quadrature weights
- For Legendre (uniform) grids: Uses trapezoidal rule weights
- Guarantees monotonic decrease with polynomial degree (by containment)
"""
function compute_norm(scale_factor::Float64, VL, sol, F, basis::Symbol, GN::Int, n::Int)
    # Compute residuals at grid points (no re-evaluation of function)
    residuals = VL * sol.u - F

    # Compute quadrature weights for the grid
    weights = compute_quadrature_weights(basis, GN, n)

    # Handle non-tensor-product grids with mismatched dimensions
    if length(residuals) != length(weights)
        @warn "Grid dimensions mismatch (residuals=$(length(residuals)), weights=$(length(weights))). " *
              "Using uniform weights for non-tensor-product grid."
        # Use uniform weights: each point gets equal weight, normalized to integrate to domain volume
        # For [-1,1]^n, volume = 2^n
        weights = fill(2.0^n / length(residuals), length(residuals))
    end

    # Compute weighted L2-norm
    return sqrt(sum(abs2.(residuals) .* weights))
end

function compute_norm(scale_factor::Vector{Float64}, VL, sol, F, basis::Symbol, GN::Int, n::Int)
    # Compute residuals at grid points (no re-evaluation of function)
    residuals = VL * sol.u - F

    # Compute quadrature weights for the grid
    weights = compute_quadrature_weights(basis, GN, n)

    # Handle non-tensor-product grids with mismatched dimensions
    if length(residuals) != length(weights)
        @warn "Grid dimensions mismatch (residuals=$(length(residuals)), weights=$(length(weights))). " *
              "Using uniform weights for non-tensor-product grid."
        # Use uniform weights: each point gets equal weight, normalized to domain volume
        # For [-1,1]^n with anisotropic scaling, volume = prod(2 .* scale_factor)
        volume = prod(2.0 .* scale_factor)
        weights = fill(volume / length(residuals), length(residuals))
    end

    # Compute weighted L2-norm
    return sqrt(sum(abs2.(residuals) .* weights))
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
