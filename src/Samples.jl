# ======================================================= Functions =======================================================
# using IterTools

"""
    chebyshev_nodes_exact(n::Int, ::Type{T}) where T

Compute Chebyshev nodes of the first kind with exact arithmetic for type T.

The Chebyshev nodes are defined as: cos((2k-1)π/(2n)) for k = 1:n

For rational types, this function computes the nodes using high-precision
arithmetic and converts to the requested type to maintain maximum accuracy.

# Arguments
- `n::Int`: Number of nodes to generate (will generate n+1 nodes: 0:n)
- `T::Type`: Numeric type for the nodes (e.g., Float64, Rational{BigInt}, BigFloat)

# Returns
- `Vector{T}`: Vector of n+1 Chebyshev nodes in descending order

# Examples
```julia
# Float64 nodes (standard behavior)
nodes = chebyshev_nodes_exact(4, Float64)

# Exact rational nodes
nodes = chebyshev_nodes_exact(4, Rational{BigInt})

# High-precision floating point
nodes = chebyshev_nodes_exact(4, BigFloat)
```
"""
function chebyshev_nodes_exact(n::Int, ::Type{T}) where T
    # For rational types, we need to compute cos of rational multiples of π
    # Since cos(π·r) for rational r is generally irrational, we use high-precision
    # approximation and convert to the target type

    if T <: AbstractFloat
        # For floating point types, compute directly with appropriate precision
        nodes = T[cos(T(π) * T(2i + 1) / T(2n + 2)) for i in 0:n]
    elseif T <: Rational
        # For rational types, compute using BigFloat and rationalize
        # Use precision high enough to capture the rational approximation accurately
        setprecision(BigFloat, 1024) do
            nodes_bf = [cos(BigFloat(π) * BigFloat(2i + 1) / BigFloat(2n + 2)) for i in 0:n]
            # rationalize for Rational types uses (Int_type, value, tolerance) format
            Int_T = typeof(T(1).num)
            return [Rational{Int_T}(rationalize(Int_T, x, eps(Float64)^2)) for x in nodes_bf]
        end
    else
        # Generic fallback: compute with BigFloat and convert
        setprecision(BigFloat, 1024) do
            return T[cos(BigFloat(π) * BigFloat(2i + 1) / BigFloat(2n + 2)) for i in 0:n]
        end
    end
end

"""
    legendre_nodes_exact(n::Int, ::Type{T}) where T

Compute equally-spaced nodes (Legendre-style) with exact arithmetic for type T.

The nodes are defined as: -1 + 2k/n for k = 0:n

These are exact rational values that can be represented perfectly in rational arithmetic.

# Arguments
- `n::Int`: Number of grid points minus 1 (will generate n+1 nodes: 0:n)
- `T::Type`: Numeric type for the nodes (e.g., Float64, Rational{BigInt})

# Returns
- `Vector{T}`: Vector of n+1 equally-spaced nodes

# Examples
```julia
# Float64 nodes (standard behavior)
nodes = legendre_nodes_exact(4, Float64)

# Exact rational nodes
nodes = legendre_nodes_exact(4, Rational{BigInt})
```
"""
function legendre_nodes_exact(n::Int, ::Type{T}) where T
    # These are exact rational values: -1 + 2i/n for i = 0:n
    if T <: Rational
        # Compute exactly as rationals
        return T[T(-1) + T(2) * T(i) // T(n) for i in 0:n]
    else
        # For other types, compute directly
        return T[T(-1) + T(2) * T(i) / T(n) for i in 0:n]
    end
end

"""
    tensor_grid_exact(nodes::Vector{Vector{T}}) where T

Construct a tensor product grid from vectors of nodes in each dimension.

# Arguments
- `nodes::Vector{Vector{T}}`: Vector of node vectors, one per dimension

# Returns
- `Array{SVector{N,T}, N}`: N-dimensional array of grid points as SVectors

# Examples
```julia
# 2D grid with different nodes in each dimension
nodes_x = chebyshev_nodes_exact(3, Float64)
nodes_y = legendre_nodes_exact(4, Float64)
grid = tensor_grid_exact([nodes_x, nodes_y])

# Isotropic 3D grid
nodes = chebyshev_nodes_exact(5, Rational{BigInt})
grid = tensor_grid_exact([nodes, nodes, nodes])
```
"""
function tensor_grid_exact(nodes::Vector{Vector{T}}) where T
    n = length(nodes)
    grid_sizes = length.(nodes)

    # Create the tensor product grid
    [
        SVector{n, T}(ntuple(d -> nodes[d][idx[d]], n)) for
        idx in Iterators.product([1:sz for sz in grid_sizes]...)
    ]
end

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
   generate_grid(n::Int, GN::Int; basis=:chebyshev, T=Float64)::Array{SVector{N,T}} where {N,T}

Generate a grid of points using either Chebyshev or Legendre nodes in n dimensions.

# Arguments
- n::Int: Number of dimensions for the grid.
- GN::Int: Number of points in each dimension (will generate GN + 1 points).
- basis::Symbol=:chebyshev: Choice of basis for node generation. Options are:
   - :chebyshev: Uses Chebyshev nodes of the first kind: cos((2i + 1)π/(2GN + 2))
   - :legendre: Uses equally spaced points: -1 + 2i/GN
- T::Type=Float64: Numeric type for grid coordinates (e.g., Float64, Rational{BigInt}, BigFloat)

# Returns
- Array{SVector{n,T}, n}: An n-dimensional array containing SVectors of dimension n and type T.
   The size in each dimension is GN + 1.

# Examples
```julia
# Generate a 2D grid with 3 points in each dimension using Chebyshev nodes (Float64)
grid = generate_grid(2, 2)  # Creates a 3×3 array of SVector{2,Float64}

# Generate a 3D grid with 4 points in each dimension using Legendre nodes
grid = generate_grid(3, 3, basis=:legendre)  # Creates a 4×4×4 array of SVector{3,Float64}

# Generate a 2D grid with exact rational coordinates
grid = generate_grid(2, 2, T=Rational{BigInt})  # Creates a 3×3 array of SVector{2,Rational{BigInt}}

# Generate a 2D grid with high-precision coordinates
grid = generate_grid(2, 2, T=BigFloat)  # Creates a 3×3 array of SVector{2,BigFloat}
```
# Notes
- The returned grid points are always in the domain [-1, 1]^n
- For Chebyshev nodes, the points are concentrated near the boundaries
- For Legendre nodes, the points are equally spaced
- Type parameter T allows for arbitrary precision arithmetic
"""

TimerOutputs.@timeit _TO function generate_grid(
    n::Int,
    GN::Int;
    basis::Symbol = :chebyshev,
    T::Type{<:Real} = Float64
)
    # Use exact node computation functions
    nodes_vec = if basis == :chebyshev
        chebyshev_nodes_exact(GN, T)
    elseif basis == :legendre
        legendre_nodes_exact(GN, T)
    else
        error("Unsupported basis: $basis")
    end

    # Use array comprehension with direct SVector construction
    [
        SVector{n}(ntuple(d -> nodes_vec[idx[d]], n)) for
        idx in Iterators.product(fill(1:(GN + 1), n)...)
    ]
end

"""
    generate_grid_small_n(N::Int, GN::Int; basis=:chebyshev, T=Float64)::Array{SVector{N,T}, N} where {N,T}

Generate a grid of points using either Chebyshev or Legendre nodes in N dimensions.
Optimized version for small dimensions (N ≤ 4) using compile-time unrolling.

# Arguments
- N::Int: Number of dimensions
- GN::Int: Number of points in each dimension (will generate GN + 1 points)
- basis::Symbol=:chebyshev: Choice of basis for node generation. Options are:
    - :chebyshev: Uses Chebyshev nodes of the first kind: cos((2i + 1)π/(2GN + 2))
    - :legendre: Uses equally spaced points: -1 + 2i/GN
- T::Type=Float64: Numeric type for grid coordinates (e.g., Float64, Rational{BigInt}, BigFloat)

# Returns
- Array{SVector{N,T}, N}: An N-dimensional array containing SVectors of dimension N and type T.
    The size in each dimension is GN + 1.

# Examples
```julia
# Generate a 2D grid with 3 points in each dimension using Chebyshev nodes
grid = generate_grid_small_n(2, 2)  # Creates a 3×3 array of SVector{2,Float64}

# Generate a 2D grid with exact rational coordinates
grid = generate_grid_small_n(2, 2, T=Rational{BigInt})  # Creates a 3×3 array of SVector{2,Rational{BigInt}}
```
# Notes
- The returned grid points are always in the domain [-1, 1]^N
- For Chebyshev nodes, the points are concentrated near the boundaries
- For Legendre nodes, the points are equally spaced
- This version is optimized for small N (typically N ≤ 4) using compile-time unrolling
- Type parameter T allows for arbitrary precision arithmetic
"""
TimerOutputs.@timeit _TO function generate_grid_small_n(
    N::Int,
    GN::Int;
    basis::Symbol = :chebyshev,
    T::Type{<:Real} = Float64
)
    # Use exact node computation functions
    nodes = if basis == :chebyshev
        chebyshev_nodes_exact(GN, T)
    elseif basis == :legendre
        legendre_nodes_exact(GN, T)
    else
        error("Unsupported basis: $basis")
    end

    reshape(
        [
            SVector{N}(ntuple(d -> nodes[idx[d]], N)) for
            idx in Iterators.product(fill(1:(GN + 1), N)...)
        ],
        fill(GN + 1, N)...
    )
end
