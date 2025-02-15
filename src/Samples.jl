# ======================================================= Functions =======================================================
# using IterTools

"""
    zeta(x::Float64)::Float64

Relative tolerance function for the number of samples.

# Arguments
- `x::Float64`: Input value.

# Returns
- The relative tolerance value.

# Example
```julia
zeta(0.5)
```
"""
function zeta(x::Float64)::Float64
    return x + (1 - x) * log(1 - x)
end

"""
    calculate_samples(m::Int, delta::Float64, alph::Float64)::Int

Generate enough samples to satisfy the error bound with respect to the tensorized Chebyshev polynomial basis.

# Arguments
- `m::Int`: Dimension of the polynomial space.
- `delta::Float64`: Relative error bound.
- `alph::Float64`: Probability, confidence level.

# Returns
- The required number of samples.

# Example
```julia
calculate_samples(10, 0.1, 0.05)
```
"""
function calculate_samples(m::Int, delta::Float64, alph::Float64)::Int
    K = 1
    condition = m^(log(3) / log(2)) / zeta(delta)
    while condition > K / (log(K) + log(6 * alph^(-1)))
        K += m
    end
    return K
end

"""
   generate_grid(n::Int, GN::Int; basis=:chebyshev)::Array{SVector{N,Float64}} where N

Generate a grid of points using either Chebyshev or Legendre nodes in n dimensions.

# Arguments
- n::Int: Number of dimensions for the grid.
- GN::Int: Number of points in each dimension (will generate GN + 1 points).
- basis::Symbol=:chebyshev: Choice of basis for node generation. Options are:
   - :chebyshev: Uses Chebyshev nodes of the first kind: cos((2i + 1)π/(2GN + 2))
   - :legendre: Uses equally spaced points: -1 + 2i/GN

# Returns
- Array{SVector{n,Float64}, n}: An n-dimensional array containing SVectors of dimension n.
   The size in each dimension is GN + 1.

# Examples
```julia
# Generate a 2D grid with 3 points in each dimension using Chebyshev nodes
grid = generate_grid(2, 2)  # Creates a 3×3 array of SVector{2,Float64}

# Generate a 3D grid with 4 points in each dimension using Legendre nodes
grid = generate_grid(3, 3, basis=:legendre)  # Creates a 4×4×4 array of SVector{3,Float64}
```
# Notes
- The returned grid points are always in the domain [-1, 1]^n
- For Chebyshev nodes, the points are concentrated near the boundaries
- For Legendre nodes, the points are equally spaced
"""

function generate_grid(
    n::Int,
    GN::Int;
    basis::Symbol = :chebyshev,
)::Array{SVector{n,Float64},n}
    nodes = if basis == :chebyshev
        (cos((2i + 1) * π / (2 * GN + 2)) for i = 0:GN)
    elseif basis == :legendre
        (-1 + 2 * i / GN for i = 0:GN)
    else
        error("Unsupported basis: $basis")
    end

    nodes_vec = collect(nodes)  # Only collect once

    # Use array comprehension with direct SVector construction
    [
        SVector{n,Float64}(ntuple(d -> nodes_vec[idx[d]], n)) for
        idx in Iterators.product(fill(1:GN+1, n)...)
    ]
end

"""
    generate_grid_small_n(::Val{N}, GN::Int; basis=:chebyshev)::Array{SVector{N,Float64}, N} where N

Generate a grid of points using either Chebyshev or Legendre nodes in N dimensions.
Optimized version for small dimensions (N ≤ 4) using compile-time unrolling.

# Arguments
- N: Number of dimensions (passed as Val{N})
- GN::Int: Number of points in each dimension (will generate GN + 1 points)
- basis::Symbol=:chebyshev: Choice of basis for node generation. Options are:
    - :chebyshev: Uses Chebyshev nodes of the first kind: cos((2i + 1)π/(2GN + 2))
    - :legendre: Uses equally spaced points: -1 + 2i/GN

# Returns
- Array{SVector{N,Float64}, N}: An N-dimensional array containing SVectors of dimension N.
    The size in each dimension is GN + 1.

# Examples
```julia
# Generate a 2D grid with 3 points in each dimension using Chebyshev nodes
grid = generate_grid_small_n(Val(2), 2)  # Creates a 3×3 array of SVector{2,Float64}
Notes

The returned grid points are always in the domain [-1, 1]^N
For Chebyshev nodes, the points are concentrated near the boundaries
For Legendre nodes, the points are equally spaced
This version is optimized for small N (typically N ≤ 4) using compile-time unrolling
"""
function generate_grid_small_n(
    N::Int,
    GN::Int;
    basis::Symbol = :chebyshev,
)::Array{SVector{N,Float64},N}
    nodes = if basis == :chebyshev
        [cos((2i + 1) * π / (2 * GN + 2)) for i = 0:GN]
    elseif basis == :legendre
        [-1 + 2 * i / GN for i = 0:GN]
    else
        error("Unsupported basis: $basis")
    end

    reshape(
        [
            SVector{N,Float64}(ntuple(d -> nodes[idx[d]], N)) for
            idx in Iterators.product(fill(1:GN+1, N)...)
        ],
        fill(GN + 1, N)...,
    )
end
