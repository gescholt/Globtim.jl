# quadrature_l2_norm.jl
# Quadrature-based L2 norm implementation

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
    basis::Symbol = :chebyshev,
)
    n_dims = length(n_points)

    # Step 1: Get nodes and weights for each dimension
    nodes_1d, weights_1d = get_quadrature_rules(n_points, basis)

    # Step 2: Compute tensor product quadrature
    l2_norm_squared = 0.0

    # Iterate over all tensor product combinations
    for idx in Iterators.product([1:n for n in n_points]...)
        # Get the n-dimensional point
        x = [nodes_1d[i][idx[i]] for i = 1:n_dims]

        # Get the n-dimensional weight (product of 1D weights)
        w = prod(weights_1d[i][idx[i]] for i = 1:n_dims)

        # Evaluate function and accumulate
        l2_norm_squared += w * abs2(f(x))
    end

    return sqrt(l2_norm_squared)
end

"""
    gauss_legendre(n::Int)

Gauss-Legendre quadrature nodes and weights on [-1,1] (weight function 1,
weights sum to 2), computed via Golub-Welsch: the nodes are the eigenvalues
of the symmetric tridiagonal Jacobi matrix of the Legendre recurrence, and
the weights are 2·(first eigenvector component)².
"""
function gauss_legendre(n::Int)
    n >= 1 || error("Number of quadrature points must be >= 1, got $n")
    n == 1 && return [0.0], [2.0]
    β = [k / sqrt(4.0 * k^2 - 1.0) for k = 1:(n-1)]
    E = eigen(SymTridiagonal(zeros(n), β))
    return E.values, 2.0 .* abs2.(@view E.vectors[1, :])
end

"""
    get_quadrature_rules(n_points::Vector{Int}, basis::Symbol)

Return per-dimension quadrature nodes and weights on [-1,1].

All supported bases (:chebyshev, :legendre, :uniform) use Gauss-Legendre
quadrature, which integrates polynomials exactly; :uniform differs from
:legendre only by measure normalization, which the returned weights already
absorb (they sum to 2 in every case).
"""
function get_quadrature_rules(n_points::Vector{Int}, basis::Symbol)
    basis in (:chebyshev, :legendre, :uniform) ||
        error("Unknown basis: $basis. Supported: :chebyshev, :legendre, :uniform")

    nodes_1d = Vector{Vector{Float64}}()
    weights_1d = Vector{Vector{Float64}}()
    for n in n_points
        nodes, weights = gauss_legendre(n)
        push!(nodes_1d, nodes)
        push!(weights_1d, weights)
    end
    return nodes_1d, weights_1d
end

# Export the main function
export compute_l2_norm_quadrature
