# lambda_vandermonde_anisotropic.jl
# Enhanced Vandermonde matrix construction for anisotropic grids

using StaticArrays
using LinearAlgebra

"""
    AnisotropicGridInfo

Stores information about an anisotropic grid including unique nodes per dimension.

# Fields
- `unique_points_per_dim::Vector{Vector{T}}`: Unique nodes for each dimension
- `point_indices_per_dim::Vector{Dict{T,Int}}`: Lookup tables for node indices
- `n_dims::Int`: Number of dimensions
- `n_points::Int`: Total number of grid points
- `is_tensor_product::Bool`: Whether grid maintains tensor product structure
"""
struct AnisotropicGridInfo{T}
    unique_points_per_dim::Vector{Vector{T}}
    point_indices_per_dim::Vector{Dict{T,Int}}
    n_dims::Int
    n_points::Int
    is_tensor_product::Bool
end

"""
    analyze_grid_structure(S::Matrix{T}) -> AnisotropicGridInfo{T}

Analyze a grid matrix to extract anisotropic structure information.

# Arguments
- `S::Matrix{T}`: Grid matrix where each row is a point in n-dimensional space

# Returns
- `AnisotropicGridInfo{T}`: Structure containing grid analysis results

# Example
```julia
# 2D grid with different nodes per dimension
S = [
    -0.8660  -0.5000;
     0.0000  -0.5000;
     0.8660  -0.5000;
    -0.8660   0.5000;
     0.0000   0.5000;
     0.8660   0.5000
]
info = analyze_grid_structure(S)
# info.unique_points_per_dim[1] = [-0.8660, 0.0000, 0.8660]
# info.unique_points_per_dim[2] = [-0.5000, 0.5000]
```
"""
function analyze_grid_structure(S::Matrix{T}) where {T}
    n_points, n_dims = size(S)

    # Extract unique points for each dimension
    unique_points_per_dim = Vector{Vector{T}}(undef, n_dims)
    point_indices_per_dim = Vector{Dict{T,Int}}(undef, n_dims)

    for d = 1:n_dims
        unique_points = sort(unique(S[:, d]))
        unique_points_per_dim[d] = unique_points
        point_indices_per_dim[d] = Dict(pt => i for (i, pt) in enumerate(unique_points))
    end

    # Check if grid maintains tensor product structure
    # For tensor product: total points = product of unique points per dimension
    expected_tensor_points = prod(length(pts) for pts in unique_points_per_dim)
    is_tensor_product = (expected_tensor_points == n_points)

    # Additional check: verify all combinations exist
    if is_tensor_product
        # Create set of existing points for fast lookup
        existing_points = Set([SVector{n_dims}(S[i, :]) for i = 1:n_points])

        # Check all tensor product combinations
        for indices in
            Iterators.product((1:length(pts) for pts in unique_points_per_dim)...)
            point = SVector{n_dims}([unique_points_per_dim[d][indices[d]] for d = 1:n_dims])
            if !(point in existing_points)
                is_tensor_product = false
                break
            end
        end
    end

    return AnisotropicGridInfo(
        unique_points_per_dim,
        point_indices_per_dim,
        n_dims,
        n_points,
        is_tensor_product,
    )
end

"""
    lambda_vandermonde_anisotropic(Lambda::NamedTuple, S::Matrix{T};
                                  basis::Symbol=:chebyshev,
                                  grid_info::Union{Nothing,AnisotropicGridInfo}=nothing) -> Matrix{T}

Compute Vandermonde matrix for polynomial evaluation on anisotropic grids.

This function handles grids where each dimension may have different Chebyshev or Legendre nodes,
enabling true anisotropic polynomial approximation.

# Arguments
- `Lambda::NamedTuple`: Multi-index set with fields:
  - `data`: Matrix where each row is a multi-index
  - `size`: Tuple (m, n) where m is number of basis functions, n is dimension
- `S::Matrix{T}`: Grid matrix where each row is a point in n-dimensional space
- `basis::Symbol=:chebyshev`: Polynomial basis (:chebyshev or :legendre)
- `grid_info::Union{Nothing,AnisotropicGridInfo}=nothing`: Pre-computed grid structure (optional)

# Returns
- `Matrix{T}`: Vandermonde matrix V of size (n_points, m_basis_functions) where
  V[i,j] = ∏ₖ Pₖ(S[i,k]) for polynomial Pₖ of degree Lambda[j,k]

# Type Parameters
- `T`: Numeric type of grid coordinates and output matrix

# Algorithm
1. Analyzes grid to extract unique nodes per dimension
2. Pre-computes polynomial evaluations for each dimension separately
3. Constructs Vandermonde matrix using tensor products of 1D evaluations

# Example
```julia
# 2D anisotropic grid with 3 Chebyshev points in x, 2 in y
Lambda = (data = [0 0; 1 0; 0 1; 1 1], size = (4, 2))
S = [
    cos(π/6) cos(π/4);
    cos(π/2) cos(π/4);
    cos(5π/6) cos(π/4);
    cos(π/6) cos(3π/4);
    cos(π/2) cos(3π/4);
    cos(5π/6) cos(3π/4)
]
V = lambda_vandermonde_anisotropic(Lambda, S, basis=:chebyshev)
```

# Performance Notes
- Pre-computation of polynomial values reduces redundant calculations
- Caching strategy scales linearly with sum of unique points per dimension
- For isotropic grids, consider using standard `lambda_vandermonde` for better performance
"""
function lambda_vandermonde_anisotropic(
    Lambda::NamedTuple,
    S::Matrix{T};
    basis::Symbol = :chebyshev,
    grid_info::Union{Nothing,AnisotropicGridInfo} = nothing,
) where {T}
    # Analyze grid structure if not provided
    info = isnothing(grid_info) ? analyze_grid_structure(S) : grid_info

    m, N = Lambda.size
    n_points = info.n_points
    n_dims = info.n_dims

    @assert N == n_dims "Dimension mismatch: Lambda has $N dimensions but grid has $n_dims"
    @assert n_points == size(S, 1) "Grid info mismatch"

    # Initialize output matrix
    V = zeros(T, n_points, m)

    # Find maximum degree needed per dimension
    max_degrees = zeros(Int, n_dims)
    for j = 1:m
        for k = 1:n_dims
            max_degrees[k] = max(max_degrees[k], Lambda.data[j, k])
        end
    end

    # Pre-compute polynomial evaluations for each dimension
    eval_cache_per_dim = Vector{Dict{Int,Vector{T}}}(undef, n_dims)

    if basis == :chebyshev
        for d = 1:n_dims
            eval_cache_per_dim[d] = Dict{Int,Vector{T}}()
            unique_points = info.unique_points_per_dim[d]

            # Special handling for exact types vs floating point
            if T <: Rational || T <: Integer
                # Use recurrence relation for exact computation
                for degree = 0:max_degrees[d]
                    eval_cache_per_dim[d][degree] =
                        T[chebyshev_value_exact(degree, T(pt)) for pt in unique_points]
                end
            else
                # Use cosine formula for floating point
                for (idx, point) in enumerate(unique_points)
                    theta = acos(clamp(T(point), T(-1), T(1)))
                    for degree = 0:max_degrees[d]
                        if !haskey(eval_cache_per_dim[d], degree)
                            eval_cache_per_dim[d][degree] =
                                Vector{T}(undef, length(unique_points))
                        end
                        eval_cache_per_dim[d][degree][idx] = cos(degree * theta)
                    end
                end
            end
        end

    elseif basis == :legendre
        for d = 1:n_dims
            eval_cache_per_dim[d] = Dict{Int,Vector{T}}()
            unique_points = info.unique_points_per_dim[d]

            for degree = 0:max_degrees[d]
                # Generate Legendre polynomial symbolically
                poly = symbolic_legendre(
                    degree,
                    precision = Float64Precision,
                    normalized = true,
                )

                # Evaluate at unique points for this dimension
                eval_cache_per_dim[d][degree] =
                    T[evaluate_legendre(poly, Float64(pt)) for pt in unique_points]
            end
        end

    else
        throw(ArgumentError("Unsupported basis: $basis. Use :chebyshev or :legendre"))
    end

    # Construct Vandermonde matrix
    for i = 1:n_points
        for j = 1:m
            P = one(T)

            # Product over dimensions
            for k = 1:n_dims
                degree = Int(Lambda.data[j, k])
                point = S[i, k]

                # Find index of this point in the unique points for dimension k
                point_idx = info.point_indices_per_dim[k][point]

                # Multiply by cached polynomial value
                P *= eval_cache_per_dim[k][degree][point_idx]
            end

            V[i, j] = P
        end
    end

    return V
end

"""
    is_grid_anisotropic(S::Matrix{T}) -> Bool

Determine if a grid has different nodes per dimension (anisotropic).

# Arguments
- `S::Matrix{T}`: Grid matrix where each row is a point

# Returns
- `Bool`: true if grid is anisotropic, false if isotropic

# Example
```julia
# Isotropic grid (same nodes in all dimensions)
S_iso = [
    -0.5 -0.5;
     0.5 -0.5;
    -0.5  0.5;
     0.5  0.5
]
is_grid_anisotropic(S_iso)  # false

# Anisotropic grid (different nodes per dimension)
S_aniso = [
    -0.8  -0.5;
     0.0  -0.5;
     0.8  -0.5;
    -0.8   0.5;
     0.0   0.5;
     0.8   0.5
]
is_grid_anisotropic(S_aniso)  # true
```
"""
function is_grid_anisotropic(S::Matrix{T}) where {T}
    n_dims = size(S, 2)
    n_dims < 2 && return false  # 1D grids are by definition isotropic

    # Get unique points for first dimension
    unique_first = sort(unique(S[:, 1]))
    n_unique_first = length(unique_first)

    # Check if all other dimensions have same number of unique points
    for d = 2:n_dims
        unique_d = unique(S[:, d])
        if length(unique_d) != n_unique_first
            return true  # Different number of unique points → anisotropic
        end

        # Even with same count, check if the actual values differ
        # (accounting for potential reordering or scaling)
        if !isapprox(sort(unique_d), unique_first, rtol = 1e-14)
            return true
        end
    end

    return false
end

# Import functions needed from ApproxConstruct.jl
import .Globtim: chebyshev_value_exact, symbolic_legendre, evaluate_legendre

# Export functions
export lambda_vandermonde_anisotropic,
    analyze_grid_structure, is_grid_anisotropic, AnisotropicGridInfo
