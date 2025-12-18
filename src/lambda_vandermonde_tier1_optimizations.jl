# lambda_vandermonde_tier1_optimizations.jl
# Tier 1 Performance Optimizations for Vandermonde Matrix Construction (Issue #202)
#
# This file contains progressive optimizations to the tensorized Vandermonde implementation:
# 1. Loop Reordering: Column-major traversal for better cache locality
# 2. Recurrence Relations: Avoid expensive trig functions
# 3. Multi-threading: Parallelize independent computations
#
# Each optimization is implemented separately for clarity and testing,
# then combined in the final version.

"""
    lambda_vandermonde_opt1_loop_reorder(Lambda::NamedTuple, S::Matrix{T};
                                         basis::Symbol=:chebyshev) -> Matrix{T}

Optimization 1: Loop Reordering for Cache Locality

Changes the matrix construction loop from row-major to column-major order
to match Julia's column-major memory layout. This improves cache locality
when writing to the output matrix.

Expected speedup: ~1.2x
"""
function lambda_vandermonde_opt1_loop_reorder(
    Lambda::NamedTuple,
    S::Matrix{T};
    basis::Symbol = :chebyshev
) where {T}
    m, n_dim = Lambda.size
    n_points, n_dim_check = size(S)

    @assert n_dim == n_dim_check "Dimension mismatch: Lambda has $n_dim dims but S has $n_dim_check"

    # Initialize output
    V = zeros(T, n_points, m)

    # Extract unique points per dimension (same as baseline)
    unique_points_per_dim = Vector{Vector{T}}(undef, n_dim)
    point_to_index_per_dim = Vector{Dict{T, Int}}(undef, n_dim)
    GN_per_dim = zeros(Int, n_dim)

    for d in 1:n_dim
        seen = Set{T}()
        unique_pts = T[]
        for i in 1:n_points
            pt = S[i, d]
            if !(pt in seen)
                push!(unique_pts, pt)
                push!(seen, pt)
            end
        end
        unique_points_per_dim[d] = unique_pts
        GN_per_dim[d] = length(unique_pts)
        point_to_index_per_dim[d] = Dict(pt => i for (i, pt) in enumerate(unique_pts))
    end

    # Verify tensor-product grid
    expected_points = prod(GN_per_dim)
    if expected_points != n_points
        error("Not a tensor-product grid. Use lambda_vandermonde_original instead.")
    end

    # Find maximum degree per dimension
    max_degrees = zeros(Int, n_dim)
    for j in 1:m
        for k in 1:n_dim
            max_degrees[k] = max(max_degrees[k], Lambda.data[j, k])
        end
    end

    # Pre-compute polynomial evaluations (same as baseline)
    eval_cache_per_dim = Vector{Dict{Int, Vector{T}}}(undef, n_dim)

    if basis == :chebyshev
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]
            GN = length(unique_points)

            if T <: Rational || T <: Integer
                for degree in 0:max_degrees[d]
                    eval_cache_per_dim[d][degree] =
                        T[chebyshev_value_exact(degree, T(pt)) for pt in unique_points]
                end
            else
                for (idx, point) in enumerate(unique_points)
                    theta = acos(clamp(T(point), T(-1), T(1)))
                    for degree in 0:max_degrees[d]
                        if !haskey(eval_cache_per_dim[d], degree)
                            eval_cache_per_dim[d][degree] = Vector{T}(undef, GN)
                        end
                        eval_cache_per_dim[d][degree][idx] = cos(degree * theta)
                    end
                end
            end
        end

    elseif basis == :legendre
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]

            for degree in 0:max_degrees[d]
                poly = symbolic_legendre(
                    degree,
                    precision = Float64Precision,
                    normalized = true
                )
                eval_cache_per_dim[d][degree] =
                    T[evaluate_legendre(poly, Float64(pt)) for pt in unique_points]
            end
        end
    else
        throw(ArgumentError("Unsupported basis: $basis. Use :chebyshev or :legendre"))
    end

    # Pre-compute point indices (same as baseline)
    point_indices_matrix = zeros(Int, n_points, n_dim)
    for i in 1:n_points
        for k in 1:n_dim
            point = S[i, k]
            point_indices_matrix[i, k] = point_to_index_per_dim[k][point]
        end
    end

    # OPTIMIZATION 1: Column-major loop order
    # Instead of iterating rows first (i, j), iterate columns first (j, i)
    # This matches Julia's column-major memory layout
    for j in 1:m                    # Outer loop: columns
        for i in 1:n_points         # Inner loop: rows
            P = one(T)
            for k in 1:n_dim
                degree = Int(Lambda.data[j, k])
                point_idx = point_indices_matrix[i, k]
                P *= eval_cache_per_dim[k][degree][point_idx]
            end
            V[i, j] = P
        end
    end

    return V
end

"""
    lambda_vandermonde_opt2_recurrence(Lambda::NamedTuple, S::Matrix{T};
                                       basis::Symbol=:chebyshev) -> Matrix{T}

Optimization 2: Polynomial Evaluation via Recurrence Relations

For Chebyshev polynomials, replaces expensive acos/cos calls with the
recurrence relation: T_n(x) = 2x·T_{n-1}(x) - T_{n-2}(x)

This computes all degrees in a single pass per point, avoiding repeated
trigonometric function evaluations.

Expected speedup: ~1.3x over baseline
"""
function lambda_vandermonde_opt2_recurrence(
    Lambda::NamedTuple,
    S::Matrix{T};
    basis::Symbol = :chebyshev
) where {T}
    m, n_dim = Lambda.size
    n_points, n_dim_check = size(S)

    @assert n_dim == n_dim_check "Dimension mismatch: Lambda has $n_dim dims but S has $n_dim_check"

    V = zeros(T, n_points, m)

    # Extract unique points per dimension
    unique_points_per_dim = Vector{Vector{T}}(undef, n_dim)
    point_to_index_per_dim = Vector{Dict{T, Int}}(undef, n_dim)
    GN_per_dim = zeros(Int, n_dim)

    for d in 1:n_dim
        seen = Set{T}()
        unique_pts = T[]
        for i in 1:n_points
            pt = S[i, d]
            if !(pt in seen)
                push!(unique_pts, pt)
                push!(seen, pt)
            end
        end
        unique_points_per_dim[d] = unique_pts
        GN_per_dim[d] = length(unique_pts)
        point_to_index_per_dim[d] = Dict(pt => i for (i, pt) in enumerate(unique_pts))
    end

    # Verify tensor-product grid
    expected_points = prod(GN_per_dim)
    if expected_points != n_points
        error("Not a tensor-product grid. Use lambda_vandermonde_original instead.")
    end

    # Find maximum degree per dimension
    max_degrees = zeros(Int, n_dim)
    for j in 1:m
        for k in 1:n_dim
            max_degrees[k] = max(max_degrees[k], Lambda.data[j, k])
        end
    end

    # OPTIMIZATION 2: Use recurrence relations for polynomial evaluation
    eval_cache_per_dim = Vector{Dict{Int, Vector{T}}}(undef, n_dim)

    if basis == :chebyshev
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]
            GN = length(unique_points)
            max_deg = max_degrees[d]

            # Use recurrence relation for all types
            # T_n(x) = 2x·T_{n-1}(x) - T_{n-2}(x)
            for (idx, point) in enumerate(unique_points)
                # Allocate storage for all degrees at this point
                for deg in 0:max_deg
                    if !haskey(eval_cache_per_dim[d], deg)
                        eval_cache_per_dim[d][deg] = Vector{T}(undef, GN)
                    end
                end

                # Compute using recurrence
                if max_deg >= 0
                    eval_cache_per_dim[d][0][idx] = one(T)  # T_0(x) = 1
                end
                if max_deg >= 1
                    eval_cache_per_dim[d][1][idx] = T(point)  # T_1(x) = x
                end
                for deg in 2:max_deg
                    eval_cache_per_dim[d][deg][idx] =
                        2 * T(point) * eval_cache_per_dim[d][deg - 1][idx] -
                        eval_cache_per_dim[d][deg - 2][idx]
                end
            end
        end

    elseif basis == :legendre
        # For Legendre, use symbolic_legendre for correct normalization
        # (The recurrence relation needs to account for the specific normalization used)
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]

            for degree in 0:max_degrees[d]
                poly = symbolic_legendre(
                    degree,
                    precision = Float64Precision,
                    normalized = true
                )
                eval_cache_per_dim[d][degree] =
                    T[evaluate_legendre(poly, Float64(pt)) for pt in unique_points]
            end
        end
    else
        throw(ArgumentError("Unsupported basis: $basis. Use :chebyshev or :legendre"))
    end

    # Pre-compute point indices
    point_indices_matrix = zeros(Int, n_points, n_dim)
    for i in 1:n_points
        for k in 1:n_dim
            point = S[i, k]
            point_indices_matrix[i, k] = point_to_index_per_dim[k][point]
        end
    end

    # Build matrix (baseline loop order)
    for i in 1:n_points
        for j in 1:m
            P = one(T)
            for k in 1:n_dim
                degree = Int(Lambda.data[j, k])
                point_idx = point_indices_matrix[i, k]
                P *= eval_cache_per_dim[k][degree][point_idx]
            end
            V[i, j] = P
        end
    end

    return V
end

"""
    lambda_vandermonde_opt3_multithreaded(Lambda::NamedTuple, S::Matrix{T};
                                          basis::Symbol=:chebyshev) -> Matrix{T}

Optimization 3: Multi-threading

Parallelizes the embarrassingly parallel matrix construction using `@threads`.
Each column can be computed independently.

Expected speedup: 4-8x (linear with number of cores)
"""
function lambda_vandermonde_opt3_multithreaded(
    Lambda::NamedTuple,
    S::Matrix{T};
    basis::Symbol = :chebyshev
) where {T}
    m, n_dim = Lambda.size
    n_points, n_dim_check = size(S)

    @assert n_dim == n_dim_check "Dimension mismatch: Lambda has $n_dim dims but S has $n_dim_check"

    V = zeros(T, n_points, m)

    # Extract unique points per dimension
    unique_points_per_dim = Vector{Vector{T}}(undef, n_dim)
    point_to_index_per_dim = Vector{Dict{T, Int}}(undef, n_dim)
    GN_per_dim = zeros(Int, n_dim)

    for d in 1:n_dim
        seen = Set{T}()
        unique_pts = T[]
        for i in 1:n_points
            pt = S[i, d]
            if !(pt in seen)
                push!(unique_pts, pt)
                push!(seen, pt)
            end
        end
        unique_points_per_dim[d] = unique_pts
        GN_per_dim[d] = length(unique_pts)
        point_to_index_per_dim[d] = Dict(pt => i for (i, pt) in enumerate(unique_pts))
    end

    # Verify tensor-product grid
    expected_points = prod(GN_per_dim)
    if expected_points != n_points
        error("Not a tensor-product grid. Use lambda_vandermonde_original instead.")
    end

    # Find maximum degree per dimension
    max_degrees = zeros(Int, n_dim)
    for j in 1:m
        for k in 1:n_dim
            max_degrees[k] = max(max_degrees[k], Lambda.data[j, k])
        end
    end

    # Pre-compute polynomial evaluations
    eval_cache_per_dim = Vector{Dict{Int, Vector{T}}}(undef, n_dim)

    if basis == :chebyshev
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]
            GN = length(unique_points)

            if T <: Rational || T <: Integer
                for degree in 0:max_degrees[d]
                    eval_cache_per_dim[d][degree] =
                        T[chebyshev_value_exact(degree, T(pt)) for pt in unique_points]
                end
            else
                for (idx, point) in enumerate(unique_points)
                    theta = acos(clamp(T(point), T(-1), T(1)))
                    for degree in 0:max_degrees[d]
                        if !haskey(eval_cache_per_dim[d], degree)
                            eval_cache_per_dim[d][degree] = Vector{T}(undef, GN)
                        end
                        eval_cache_per_dim[d][degree][idx] = cos(degree * theta)
                    end
                end
            end
        end

    elseif basis == :legendre
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]

            for degree in 0:max_degrees[d]
                poly = symbolic_legendre(
                    degree,
                    precision = Float64Precision,
                    normalized = true
                )
                eval_cache_per_dim[d][degree] =
                    T[evaluate_legendre(poly, Float64(pt)) for pt in unique_points]
            end
        end
    else
        throw(ArgumentError("Unsupported basis: $basis. Use :chebyshev or :legendre"))
    end

    # Pre-compute point indices
    point_indices_matrix = zeros(Int, n_points, n_dim)
    for i in 1:n_points
        for k in 1:n_dim
            point = S[i, k]
            point_indices_matrix[i, k] = point_to_index_per_dim[k][point]
        end
    end

    # OPTIMIZATION 3: Multi-threaded column computation
    Threads.@threads for j in 1:m
        for i in 1:n_points
            P = one(T)
            for k in 1:n_dim
                degree = Int(Lambda.data[j, k])
                point_idx = point_indices_matrix[i, k]
                P *= eval_cache_per_dim[k][degree][point_idx]
            end
            V[i, j] = P
        end
    end

    return V
end

"""
    lambda_vandermonde_opt12_combined(Lambda::NamedTuple, S::Matrix{T};
                                      basis::Symbol=:chebyshev) -> Matrix{T}

Combined Optimization: Loop Reordering + Recurrence Relations

Combines optimizations 1 and 2 for cumulative speedup.

Expected speedup: ~1.56x (1.2 × 1.3)
"""
function lambda_vandermonde_opt12_combined(
    Lambda::NamedTuple,
    S::Matrix{T};
    basis::Symbol = :chebyshev
) where {T}
    m, n_dim = Lambda.size
    n_points, n_dim_check = size(S)

    @assert n_dim == n_dim_check "Dimension mismatch: Lambda has $n_dim dims but S has $n_dim_check"

    V = zeros(T, n_points, m)

    # Extract unique points per dimension
    unique_points_per_dim = Vector{Vector{T}}(undef, n_dim)
    point_to_index_per_dim = Vector{Dict{T, Int}}(undef, n_dim)
    GN_per_dim = zeros(Int, n_dim)

    for d in 1:n_dim
        seen = Set{T}()
        unique_pts = T[]
        for i in 1:n_points
            pt = S[i, d]
            if !(pt in seen)
                push!(unique_pts, pt)
                push!(seen, pt)
            end
        end
        unique_points_per_dim[d] = unique_pts
        GN_per_dim[d] = length(unique_pts)
        point_to_index_per_dim[d] = Dict(pt => i for (i, pt) in enumerate(unique_pts))
    end

    expected_points = prod(GN_per_dim)
    if expected_points != n_points
        error("Not a tensor-product grid. Use lambda_vandermonde_original instead.")
    end

    max_degrees = zeros(Int, n_dim)
    for j in 1:m
        for k in 1:n_dim
            max_degrees[k] = max(max_degrees[k], Lambda.data[j, k])
        end
    end

    # OPT 2: Recurrence relations
    eval_cache_per_dim = Vector{Dict{Int, Vector{T}}}(undef, n_dim)

    if basis == :chebyshev
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]
            GN = length(unique_points)
            max_deg = max_degrees[d]

            for (idx, point) in enumerate(unique_points)
                for deg in 0:max_deg
                    if !haskey(eval_cache_per_dim[d], deg)
                        eval_cache_per_dim[d][deg] = Vector{T}(undef, GN)
                    end
                end

                if max_deg >= 0
                    eval_cache_per_dim[d][0][idx] = one(T)
                end
                if max_deg >= 1
                    eval_cache_per_dim[d][1][idx] = T(point)
                end
                for deg in 2:max_deg
                    eval_cache_per_dim[d][deg][idx] =
                        2 * T(point) * eval_cache_per_dim[d][deg - 1][idx] -
                        eval_cache_per_dim[d][deg - 2][idx]
                end
            end
        end

    elseif basis == :legendre
        # For Legendre, use symbolic_legendre for correct normalization
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]

            for degree in 0:max_degrees[d]
                poly = symbolic_legendre(
                    degree,
                    precision = Float64Precision,
                    normalized = true
                )
                eval_cache_per_dim[d][degree] =
                    T[evaluate_legendre(poly, Float64(pt)) for pt in unique_points]
            end
        end
    else
        throw(ArgumentError("Unsupported basis: $basis. Use :chebyshev or :legendre"))
    end

    point_indices_matrix = zeros(Int, n_points, n_dim)
    for i in 1:n_points
        for k in 1:n_dim
            point = S[i, k]
            point_indices_matrix[i, k] = point_to_index_per_dim[k][point]
        end
    end

    # OPT 1: Column-major loop order
    for j in 1:m
        for i in 1:n_points
            P = one(T)
            for k in 1:n_dim
                degree = Int(Lambda.data[j, k])
                point_idx = point_indices_matrix[i, k]
                P *= eval_cache_per_dim[k][degree][point_idx]
            end
            V[i, j] = P
        end
    end

    return V
end

"""
    lambda_vandermonde_opt123_all(Lambda::NamedTuple, S::Matrix{T};
                                   basis::Symbol=:chebyshev) -> Matrix{T}

All Tier 1 Optimizations Combined

Combines all three optimizations:
1. Loop reordering (column-major)
2. Recurrence relations
3. Multi-threading

Expected speedup: 6-15x over baseline tensorized implementation
Target performance: 0.2-0.5ms for 4D, GN=6, degree=5
"""
function lambda_vandermonde_opt123_all(
    Lambda::NamedTuple,
    S::Matrix{T};
    basis::Symbol = :chebyshev
) where {T}
    m, n_dim = Lambda.size
    n_points, n_dim_check = size(S)

    @assert n_dim == n_dim_check "Dimension mismatch: Lambda has $n_dim dims but S has $n_dim_check"

    V = zeros(T, n_points, m)

    # Extract unique points per dimension
    unique_points_per_dim = Vector{Vector{T}}(undef, n_dim)
    point_to_index_per_dim = Vector{Dict{T, Int}}(undef, n_dim)
    GN_per_dim = zeros(Int, n_dim)

    for d in 1:n_dim
        seen = Set{T}()
        unique_pts = T[]
        for i in 1:n_points
            pt = S[i, d]
            if !(pt in seen)
                push!(unique_pts, pt)
                push!(seen, pt)
            end
        end
        unique_points_per_dim[d] = unique_pts
        GN_per_dim[d] = length(unique_pts)
        point_to_index_per_dim[d] = Dict(pt => i for (i, pt) in enumerate(unique_pts))
    end

    expected_points = prod(GN_per_dim)
    if expected_points != n_points
        error("Not a tensor-product grid. Use lambda_vandermonde_original instead.")
    end

    max_degrees = zeros(Int, n_dim)
    for j in 1:m
        for k in 1:n_dim
            max_degrees[k] = max(max_degrees[k], Lambda.data[j, k])
        end
    end

    # OPT 2: Recurrence relations for polynomial evaluation
    eval_cache_per_dim = Vector{Dict{Int, Vector{T}}}(undef, n_dim)

    if basis == :chebyshev
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]
            GN = length(unique_points)
            max_deg = max_degrees[d]

            for (idx, point) in enumerate(unique_points)
                for deg in 0:max_deg
                    if !haskey(eval_cache_per_dim[d], deg)
                        eval_cache_per_dim[d][deg] = Vector{T}(undef, GN)
                    end
                end

                if max_deg >= 0
                    eval_cache_per_dim[d][0][idx] = one(T)
                end
                if max_deg >= 1
                    eval_cache_per_dim[d][1][idx] = T(point)
                end
                for deg in 2:max_deg
                    eval_cache_per_dim[d][deg][idx] =
                        2 * T(point) * eval_cache_per_dim[d][deg - 1][idx] -
                        eval_cache_per_dim[d][deg - 2][idx]
                end
            end
        end

    elseif basis == :legendre
        # For Legendre, use symbolic_legendre for correct normalization
        for d in 1:n_dim
            eval_cache_per_dim[d] = Dict{Int, Vector{T}}()
            unique_points = unique_points_per_dim[d]

            for degree in 0:max_degrees[d]
                poly = symbolic_legendre(
                    degree,
                    precision = Float64Precision,
                    normalized = true
                )
                eval_cache_per_dim[d][degree] =
                    T[evaluate_legendre(poly, Float64(pt)) for pt in unique_points]
            end
        end
    else
        throw(ArgumentError("Unsupported basis: $basis. Use :chebyshev or :legendre"))
    end

    point_indices_matrix = zeros(Int, n_points, n_dim)
    for i in 1:n_points
        for k in 1:n_dim
            point = S[i, k]
            point_indices_matrix[i, k] = point_to_index_per_dim[k][point]
        end
    end

    # OPT 1 + 3: Column-major multi-threaded computation
    Threads.@threads for j in 1:m
        for i in 1:n_points
            P = one(T)
            for k in 1:n_dim
                degree = Int(Lambda.data[j, k])
                point_idx = point_indices_matrix[i, k]
                P *= eval_cache_per_dim[k][degree][point_idx]
            end
            V[i, j] = P
        end
    end

    return V
end

export lambda_vandermonde_opt1_loop_reorder
export lambda_vandermonde_opt2_recurrence
export lambda_vandermonde_opt3_multithreaded
export lambda_vandermonde_opt12_combined
export lambda_vandermonde_opt123_all
