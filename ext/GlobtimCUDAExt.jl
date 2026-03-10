# GlobtimCUDAExt.jl
# GPU acceleration extension for Globtim using CUDA.jl
#
# This extension provides:
# - Batched Vandermonde matrix construction on GPU
# - Batched least squares solving using cuBLAS/cuSOLVER
# - GPU memory management and availability checking

module GlobtimCUDAExt

using Globtim
using CUDA
using CUDA.CUBLAS
using CUDA.CUSOLVER
using LinearAlgebra

#==============================================================================#
#                           GPU AVAILABILITY                                    #
#==============================================================================#

"""
    Globtim.gpu_available() -> Bool

Check if GPU acceleration is available (CUDA.jl loaded and functional GPU present).
"""
function Globtim.gpu_available()::Bool
    return CUDA.functional()
end

"""
    Globtim.gpu_memory_info() -> NamedTuple

Return GPU memory information (total, free, used) in bytes.
"""
function Globtim.gpu_memory_info()
    if !CUDA.functional()
        return (total=0, free=0, used=0)
    end
    total = CUDA.totalmem(CUDA.device())
    free = CUDA.available_memory()
    return (total=total, free=free, used=total - free)
end

#==============================================================================#
#                      CHEBYSHEV POLYNOMIAL CACHE                               #
#==============================================================================#

"""
    precompute_chebyshev_cache(unique_points_per_dim, max_degree, basis)

Pre-compute polynomial values at unique grid points using recurrence relations.
Returns vector of matrices, one per dimension: cache[d][point_idx, degree+1].
"""
function precompute_chebyshev_cache(
    unique_points_per_dim::Vector{Vector{Float64}},
    max_degree::Int,
    basis::Symbol
)
    n_dim = length(unique_points_per_dim)
    eval_cache = Vector{Matrix{Float64}}(undef, n_dim)

    for d in 1:n_dim
        pts = unique_points_per_dim[d]
        n_pts = length(pts)
        cache = zeros(Float64, n_pts, max_degree + 1)

        if basis == :chebyshev
            # Chebyshev recurrence: T_0=1, T_1=x, T_n = 2x*T_{n-1} - T_{n-2}
            for (i, x) in enumerate(pts)
                cache[i, 1] = 1.0  # T_0
                if max_degree >= 1
                    cache[i, 2] = x  # T_1
                end
                for deg in 2:max_degree
                    cache[i, deg+1] = 2.0 * x * cache[i, deg] - cache[i, deg-1]
                end
            end
        elseif basis == :legendre
            # Bonnet's recurrence: (n+1)P_{n+1} = (2n+1)xP_n - nP_{n-1}
            for (i, x) in enumerate(pts)
                cache[i, 1] = 1.0  # P_0
                if max_degree >= 1
                    cache[i, 2] = x  # P_1
                end
                for n in 1:max_degree-1
                    cache[i, n+2] = ((2n + 1) * x * cache[i, n+1] - n * cache[i, n]) / (n + 1)
                end
            end
        else
            error("Unsupported basis: $basis. Use :chebyshev or :legendre.")
        end

        eval_cache[d] = cache
    end

    return eval_cache
end

"""
    build_point_indices(grid_matrix, unique_points_per_dim)

Build lookup table mapping each grid point to its index in the unique points array.
Returns matrix of indices: (n_points, n_dim).
"""
function build_point_indices(
    grid_matrix::Matrix{Float64},
    unique_points_per_dim::Vector{Vector{Float64}}
)
    n_points, n_dim = size(grid_matrix)
    point_indices = zeros(Int32, n_points, n_dim)

    for d in 1:n_dim
        unique_pts = unique_points_per_dim[d]
        for i in 1:n_points
            x = grid_matrix[i, d]
            # Find index in unique points (they're sorted)
            idx = searchsortedfirst(unique_pts, x - 1e-12)
            if idx <= length(unique_pts) && abs(unique_pts[idx] - x) < 1e-10
                point_indices[i, d] = idx
            else
                # Try exact match
                for (j, u) in enumerate(unique_pts)
                    if abs(u - x) < 1e-10
                        point_indices[i, d] = j
                        break
                    end
                end
            end
        end
    end

    return point_indices
end

#==============================================================================#
#                      BATCHED VANDERMONDE CONSTRUCTION                        #
#==============================================================================#

"""
    Globtim.batched_vandermonde_gpu(Lambda, grids, basis) -> CuArray{Float64,3}

Build B Vandermonde matrices on GPU for subdomains with identical grid structure.

# Arguments
- `Lambda::NamedTuple`: Multi-index set from SupportGen (shared across all batches)
- `grids::Vector{Matrix{Float64}}`: B grids, each (n_points, n_dim) in normalized [-1,1] coords
- `basis::Symbol`: Polynomial basis (:chebyshev or :legendre)

# Returns
- `CuArray{Float64,3}`: Batched Vandermonde matrices (n_points, m_terms, B)
"""
function Globtim.batched_vandermonde_gpu(
    Lambda::NamedTuple,
    grids::Vector{Matrix{Float64}},
    basis::Symbol
)::CuArray{Float64,3}

    B = length(grids)
    B == 0 && error("Empty grids vector")

    n_points, n_dim = size(grids[1])
    m = Lambda.size[1]  # Number of polynomial terms

    # Validate all grids have same shape
    for (i, g) in enumerate(grids)
        if size(g) != (n_points, n_dim)
            error("Grid $i has shape $(size(g)), expected ($n_points, $n_dim)")
        end
    end

    # Find maximum degree needed
    max_degree = maximum(Lambda.data)

    # Extract unique points from first grid (all grids use same normalized Chebyshev nodes)
    unique_points_per_dim = Vector{Vector{Float64}}(undef, n_dim)
    for d in 1:n_dim
        unique_points_per_dim[d] = sort(unique(grids[1][:, d]))
    end

    # Pre-compute polynomial values using recurrence relation
    eval_cache = precompute_chebyshev_cache(unique_points_per_dim, max_degree, basis)

    # Build point index lookup
    point_indices = build_point_indices(grids[1], unique_points_per_dim)

    # Transfer to GPU
    Lambda_gpu = CuArray(Int32.(Lambda.data))  # (m, n_dim)
    point_indices_gpu = CuArray(point_indices)  # (n_points, n_dim)

    # Stack evaluation caches - need max size across dimensions
    max_unique_pts = maximum(length(u) for u in unique_points_per_dim)
    eval_cache_padded = zeros(Float64, n_dim, max_unique_pts, max_degree + 1)
    for d in 1:n_dim
        n_unique = size(eval_cache[d], 1)
        eval_cache_padded[d, 1:n_unique, :] .= eval_cache[d]
    end
    eval_cache_gpu = CuArray(eval_cache_padded)

    # Allocate output on GPU
    V_batch = CUDA.zeros(Float64, n_points, m, B)

    # Build Vandermonde matrices using GPU kernel
    # Each thread computes one element V[i, j, b]
    function vandermonde_kernel!(V, point_idx, Lambda_data, eval_cache, n_pts, n_terms, n_batch, n_d)
        idx = (blockIdx().x - 1) * blockDim().x + threadIdx().x

        total_elements = n_pts * n_terms * n_batch
        if idx <= total_elements
            # Decompose linear index to (i, j, b)
            b = (idx - 1) ÷ (n_pts * n_terms) + 1
            remainder = (idx - 1) % (n_pts * n_terms)
            j = remainder ÷ n_pts + 1
            i = remainder % n_pts + 1

            # Compute product of polynomial values
            P = 1.0
            for k in 1:n_d
                deg = Lambda_data[j, k]
                pt_idx = point_idx[i, k]
                P *= eval_cache[k, pt_idx, deg+1]
            end

            V[i, j, b] = P
        end

        return nothing
    end

    # Launch kernel
    total_elements = n_points * m * B
    threads = 256
    blocks = cld(total_elements, threads)

    @cuda threads=threads blocks=blocks vandermonde_kernel!(
        V_batch, point_indices_gpu, Lambda_gpu, eval_cache_gpu,
        Int32(n_points), Int32(m), Int32(B), Int32(n_dim)
    )

    CUDA.synchronize()

    return V_batch
end

#==============================================================================#
#                      BATCHED LEAST SQUARES SOLVE                             #
#==============================================================================#

"""
    Globtim.batched_ls_solve_gpu(V_batch, f_batch) -> CuArray{Float64,2}

Solve B least squares problems min ||V*c - f||^2 on GPU using normal equations.

Uses batched operations: G = V'V, rhs = V'f, then solve G*c = rhs via batched LU.

# Arguments
- `V_batch::CuArray{Float64,3}`: Vandermonde matrices (n_points, m, B)
- `f_batch::CuArray{Float64,2}`: Function values (n_points, B)

# Returns
- `CuArray{Float64,2}`: Coefficients (m, B)
"""
function Globtim.batched_ls_solve_gpu(
    V_batch::CuArray{Float64,3},
    f_batch::CuArray{Float64,2}
)::CuArray{Float64,2}

    n_points, m, B = size(V_batch)

    # Verify dimensions
    size(f_batch) == (n_points, B) ||
        error("f_batch shape $(size(f_batch)) doesn't match V_batch ($n_points, $m, $B)")

    # Form Gram matrices: G[b] = V[b]' * V[b]  using batched GEMM
    # G = alpha * V' * V + beta * G
    G_batch = CUDA.zeros(Float64, m, m, B)

    CUBLAS.gemm_strided_batched!(
        'T', 'N',           # transA='T' (transpose V), transB='N' (don't transpose V)
        1.0,                # alpha
        V_batch,            # A: (n_points, m, B) - will be transposed to (m, n_points)
        V_batch,            # B: (n_points, m, B)
        0.0,                # beta
        G_batch             # C: (m, m, B)
    )

    # Form RHS: rhs[b] = V[b]' * f[b]  using batched GEMV (via GEMM with 1 column)
    f_3d = reshape(f_batch, n_points, 1, B)
    rhs_3d = CUDA.zeros(Float64, m, 1, B)

    CUBLAS.gemm_strided_batched!(
        'T', 'N',           # transA='T', transB='N'
        1.0,                # alpha
        V_batch,            # A: (n_points, m, B)
        f_3d,               # B: (n_points, 1, B)
        0.0,                # beta
        rhs_3d              # C: (m, 1, B)
    )

    rhs_batch = dropdims(rhs_3d, dims=2)  # (m, B)

    # Solve G * c = rhs using batched LU factorization
    coeffs_batch = batched_lu_solve!(G_batch, rhs_batch)

    return coeffs_batch
end

"""
    batched_lu_solve!(A_batch, b_batch) -> CuArray{Float64,2}

Solve batched linear systems A*x = b using LU factorization.
A_batch is overwritten with LU factors, b_batch is overwritten with solution.
"""
function batched_lu_solve!(
    A_batch::CuArray{Float64,3},  # (m, m, B) - overwritten with LU factors
    b_batch::CuArray{Float64,2}   # (m, B) - overwritten with solution
)::CuArray{Float64,2}

    m, _, B = size(A_batch)

    # CUSOLVER batched LU requires array of pointers
    # Use getrf_batched! which handles this internally in CUDA.jl 5.x

    # Pivot arrays and info
    pivot = CUDA.zeros(Int32, m, B)
    info = CUDA.zeros(Int32, B)

    # Batched LU factorization: A = P * L * U
    # CUDA.jl 5.x provides a higher-level interface
    for b in 1:B
        A_view = @view A_batch[:, :, b]
        pivot_view = @view pivot[:, b]
        CUSOLVER.getrf!(A_view, pivot_view)
    end

    # Solve using the LU factors
    for b in 1:B
        A_view = @view A_batch[:, :, b]
        b_view = @view b_batch[:, b]
        pivot_view = @view pivot[:, b]
        # Reshape b_view to matrix for getrs!
        b_mat = reshape(b_view, m, 1)
        CUSOLVER.getrs!('N', A_view, pivot_view, b_mat)
    end

    return b_batch
end

#==============================================================================#
#                      ALTERNATIVE: DIRECT QR SOLVE                            #
#==============================================================================#

"""
    batched_qr_solve_gpu(V_batch, f_batch) -> CuArray{Float64,2}

Alternative: Solve batched LS using QR factorization (more numerically stable).
Currently uses per-batch QR; batched QR would require cuSOLVER 11.x features.
"""
function batched_qr_solve_gpu(
    V_batch::CuArray{Float64,3},
    f_batch::CuArray{Float64,2}
)::CuArray{Float64,2}

    n_points, m, B = size(V_batch)
    coeffs_batch = CUDA.zeros(Float64, m, B)

    # Process each batch element (QR is less efficient for batching)
    for b in 1:B
        V = @view V_batch[:, :, b]
        f = @view f_batch[:, b]

        # QR factorization and solve
        # V = Q * R, solve R * c = Q' * f
        V_copy = copy(V)  # geqrf! overwrites
        tau = CUDA.zeros(Float64, min(n_points, m))

        CUSOLVER.geqrf!(V_copy, tau)

        # Apply Q' to f
        f_copy = copy(f)
        CUSOLVER.ormqr!('L', 'T', V_copy, tau, reshape(f_copy, n_points, 1))

        # Solve R * c = Q'f (upper triangular solve)
        R = @view V_copy[1:m, 1:m]
        rhs = @view f_copy[1:m]
        CUBLAS.trsv!('U', 'N', 'N', R, rhs)

        coeffs_batch[:, b] .= rhs
    end

    return coeffs_batch
end

end  # module GlobtimCUDAExt
