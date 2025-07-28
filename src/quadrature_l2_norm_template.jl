# quadrature_l2_norm_template.jl
# Template for the quadrature-based L2 norm implementation
# Copy this to quadrature_l2_norm.jl and implement the functions

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

    # Step 1: Create orthogonal polynomials for each dimension
    ops = create_orthogonal_polys(n_points, basis)

    # Step 2: Extract nodes and weights
    nodes_1d = [op.quad.nodes for op in ops]
    weights_1d = [op.quad.weights for op in ops]

    # Step 3: Compute tensor product quadrature
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
function create_orthogonal_polys(n_points::Vector{Int}, basis::Symbol)
    ops = []

    for n in n_points
        if basis == :chebyshev
            push!(ops, ChebyshevOrthoPoly(n - 1))
        elseif basis == :legendre
            push!(ops, LegendreOrthoPoly(n - 1))
        elseif basis == :uniform
            push!(ops, Uniform_11OrthoPoly(n - 1))
        else
            error("Unknown basis: $basis. Supported: :chebyshev, :legendre, :uniform")
        end
    end

    return ops
end

# Export the main function
export compute_l2_norm_quadrature
