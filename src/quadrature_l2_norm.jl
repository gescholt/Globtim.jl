# quadrature_l2_norm.jl
# Quadrature-based L2 norm implementation

using PolyChaos
using LinearAlgebra
using StaticArrays

"""
    compute_l2_norm_quadrature(f::Function, n_points::Vector{Int}, basis::Symbol=:chebyshev)

Compute the L2 norm of a function using Gaussian quadrature.

# Arguments
- `f`: Function to compute L2 norm for. Should accept a vector input.
- `n_points`: Number of quadrature points in each dimension
- `basis`: Type of polynomial basis (:chebyshev, :legendre, :uniform)

# Returns
- L2 norm value

# Example
```julia
f = x -> exp(-(x[1]^2 + x[2]^2))
l2_norm = compute_l2_norm_quadrature(f, [10, 10], :chebyshev)
```
"""
function compute_l2_norm_quadrature(
    f::Function,
    n_points::Vector{Int},
    basis::Symbol = :chebyshev
)
    n_dims = length(n_points)

    # Step 1: Get nodes and weights for each dimension
    nodes_1d, weights_1d = get_quadrature_rules(n_points, basis)

    # Step 2: Compute tensor product quadrature
    l2_norm_squared = 0.0

    # Iterate over all tensor product combinations
    for idx in Iterators.product([1:n for n in n_points]...)
        # Get the n-dimensional point
        x = [nodes_1d[i][idx[i]] for i in 1:n_dims]

        # Get the n-dimensional weight (product of 1D weights)
        w = prod(weights_1d[i][idx[i]] for i in 1:n_dims)

        # Evaluate function and accumulate
        l2_norm_squared += w * abs2(f(x))
    end

    return sqrt(l2_norm_squared)
end

"""
    create_orthogonal_polys(n_points::Vector{Int}, basis::Symbol)

Create orthogonal polynomial objects for each dimension.

# Arguments
- `n_points`: Number of points in each dimension
- `basis`: Polynomial basis type

# Returns
- Vector of orthogonal polynomial objects
"""
function get_quadrature_rules(n_points::Vector{Int}, basis::Symbol)
    nodes_1d = Vector{Vector{Float64}}()
    weights_1d = Vector{Vector{Float64}}()

    for n in n_points
        if basis == :chebyshev
            # For now, use Gauss-Legendre quadrature for Chebyshev basis
            # This gives exact results for polynomial integration
            op = LegendreOrthoPoly(n)
            push!(nodes_1d, op.quad.nodes)
            push!(weights_1d, op.quad.weights)
        elseif basis == :legendre
            # Gauss-Legendre quadrature on [-1,1]
            op = LegendreOrthoPoly(n)
            push!(nodes_1d, op.quad.nodes)
            push!(weights_1d, op.quad.weights)
        elseif basis == :uniform
            # Uniform measure quadrature on [-1,1]
            op = Uniform_11OrthoPoly(n)
            push!(nodes_1d, op.quad.nodes)
            # The weights are normalized to sum to 1, but for [-1,1] we need them to sum to 2
            push!(weights_1d, op.quad.weights .* 2.0)
        else
            error("Unknown basis: $basis. Supported: :chebyshev, :legendre, :uniform")
        end
    end

    return nodes_1d, weights_1d
end

# Export the main function
export compute_l2_norm_quadrature
