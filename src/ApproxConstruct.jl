
struct EllipseSupport{T}
    center::Vector{T}
    coeffs::Vector{T}
    radius::T
end

function get_lambda_vectors(es::EllipseSupport)
    n = length(es.center)
    @assert n > 0 "n must be a positive number"

    lambda_vectors = Vector{Vector{Int}}()

    exps = get_lambda_exponent_vectors((:one_d_for_all, es.radius), length(es.center))
    for exp in exps
        if sum(exp .^ 2 .* (1 ./ es.coeffs .^ 2)) <= es.radius
            push!(lambda_vectors, exp)
        end
    end

    lambda_vectors
end

function get_lambda_exponent_vectors(d, n)
    if d[1] == :one_d_for_all
        d = d[2]

        estimated_size = binomial(n + d, d)
        lambda_vectors = Vector{Vector{Int}}(undef, estimated_size)
        count = 0

        ranges = fill(0:d, n)
        for idx in Iterators.product(ranges...)
            if sum(idx) <= d
                count += 1
                lambda_vectors[count] = collect(Int, idx)
            end
        end

        resize!(lambda_vectors, count)
        return lambda_vectors
    elseif d[1] == :one_d_per_dim
        d = d[2]

        ranges = Iterators.product((0:di for di in d)...)
        lambda_vectors = Vector{Vector{Int}}(undef, length(ranges))
        count = 0
        for idx in ranges
            count += 1
            lambda_vectors[count] = collect(Int, idx)
        end
        resize!(lambda_vectors, count)
        return lambda_vectors
    elseif d[1] == :fully_custom
        lambda_vectors = get_lambda_vectors(d[2])
        @assert all(e -> length(e) == n, lambda_vectors) "All exponent vectors must have length n"
        return lambda_vectors
    else
        throw(ArgumentError("Invalid degree format. Use :one_d_for_all or :one_d_per_dim."))
    end

end

"""
    SupportGen(n::Int, d::Int)::NamedTuple

Compute the support of a dense polynomial of total degree at most d in n variables.

# Arguments
- `n::Int`: Number of variables
- `d::Int`: Maximum degree of the polynomial

# Returns
- `NamedTuple`: Contains the support matrix and its dimensions
    - `data::Matrix{Int}`: Matrix where each row represents a monomial exponent vector
    - `size::Tuple{Int,Int}`: Dimensions of the support matrix

# Throws
- `ArgumentError`: If n < 1 or d < 0

# Example
```julia
support = SupportGen(2, (:one_d_for_all, 3))
# Returns a NamedTuple with monomial exponents for polynomials in 2 variables up to degree 3
"""
function SupportGen(n::Int, d)::NamedTuple
    n ≥ 1 || throw(ArgumentError("Number of variables must be positive"))
    # minimum(d) ≥ 0 || throw(ArgumentError("Degree must be non-negative"))

    D = if d[1] == :one_d_for_all
        maximum(d[2])
    elseif d[1] == :one_d_per_dim
        maximum(d[2])
    elseif d[1] == :fully_custom
        Inf
    else
        throw(
            ArgumentError(
                "Invalid degree format. Use :one_d_for_all or :one_d_per_dim or :fully_custom."
            )
        )
    end

    if D == 0
        return (data = zeros(Int, 1, n), size = (1, n))
    end

    lambda_vectors = get_lambda_exponent_vectors(d, n)
    # @info "" lambda_vectors

    lambda_matrix =
        length(lambda_vectors) > 0 ? reduce(hcat, lambda_vectors)' : zeros(Int, 0, n)

    return (data = lambda_matrix, size = size(lambda_matrix))
end

TimerOutputs.@timeit _TO function lambda_vandermonde_original(
    Lambda::NamedTuple,
    S;
    basis = :chebyshev
)
    T = eltype(S)  # Infer type from input
    m, n_dim = Lambda.size  # m = number of multi-indices, n_dim = number of dimensions  
    n, N = size(S)          # n = number of dimensions, N = number of sample points
    V = zeros(T, n, m)  # Use inferred type instead of Float64

    # Get unique points from all columns to handle floating-point precision issues
    all_points = Set{T}()
    for i in 1:n, j in 1:N
        push!(all_points, S[i, j])
    end
    unique_points = sort(collect(all_points))

    # Find max degree needed
    max_degree = maximum(Lambda.data)

    # Create point index lookup with all unique points
    point_indices = Dict(point => i for (i, point) in enumerate(unique_points))

    if basis == :legendre
        # Precompute Legendre polynomial evaluations for all degrees at unique points
        eval_cache = Dict{Int, Vector{T}}()  # Use type T instead of Float64

        # Compute polynomials and evaluations
        @views for degree in 0:max_degree
            # For now, keep using Float64 precision for polynomial generation
            # but convert results to type T
            poly =
                symbolic_legendre(degree, precision = Float64Precision, normalized = true)

            # Convert evaluation results to type T
            eval_cache[degree] =
                map(point -> T(evaluate_legendre(poly, Float64(point))), unique_points)
        end

        # Compute Vandermonde matrix using cached values
        @views for i in 1:n, j in 1:m
            P = one(T)  # Use one(T) instead of 1.0
            for k in 1:n_dim
                degree = Int(Lambda.data[j, k])
                point = S[i, k]
                point_idx = point_indices[point]
                P *= eval_cache[degree][point_idx]
            end
            V[i, j] = P
        end

    elseif basis == :chebyshev
        # Precompute Chebyshev polynomial evaluations
        eval_cache = Dict{Int, Vector{T}}()

        # Special handling for exact types vs floating point
        if T <: Rational || T <: Integer
            # Use recurrence relation for exact computation
            @info "  🚀 lambda_vandermonde_original: Using EXACT recurrence (Rational/Integer)"
            for degree in 0:max_degree
                eval_cache[degree] = T[]
                for point in unique_points
                    push!(eval_cache[degree], chebyshev_value_exact(degree, T(point)))
                end
            end
        else
            # OPTIMIZATION: Use recurrence relation instead of trig functions
            # This matches the optimization in lambda_vandermonde_tensorized.jl
            @info "  🚀 lambda_vandermonde_original: Using OPTIMIZED recurrence (Float type)"

            # Pre-allocate all degree vectors
            for degree in 0:max_degree
                eval_cache[degree] = Vector{T}(undef, length(unique_points))
            end

            # Compute using recurrence for each point
            @views for (point_idx, point) in enumerate(unique_points)
                if max_degree >= 0
                    eval_cache[0][point_idx] = one(T)  # T_0(x) = 1
                end
                if max_degree >= 1
                    eval_cache[1][point_idx] = T(point)  # T_1(x) = x
                end
                for degree in 2:max_degree
                    eval_cache[degree][point_idx] =
                        2 * T(point) * eval_cache[degree - 1][point_idx] -
                        eval_cache[degree - 2][point_idx]
                end
            end
        end

        # Compute Vandermonde matrix using cached values
        @views for i in 1:n, j in 1:m
            P = one(T)
            for k in 1:n_dim
                degree = Int(Lambda.data[j, k])
                point = S[i, k]
                point_idx = point_indices[point]
                P *= eval_cache[degree][point_idx]
            end
            V[i, j] = P
        end
    else
        throw(
            ArgumentError(
                "Unsupported basis: $basis. Supported bases are :legendre and :chebyshev"
            )
        )
    end

    return V
end

# Helper function for exact Chebyshev evaluation
function chebyshev_value_exact(n::Int, x::T) where {T}
    if n == 0
        return one(T)
    elseif n == 1
        return x
    else
        # T_n(x) = 2x*T_{n-1}(x) - T_{n-2}(x)
        T_prev2 = one(T)
        T_prev1 = x
        for k in 2:n
            T_curr = 2 * x * T_prev1 - T_prev2
            T_prev2 = T_prev1
            T_prev1 = T_curr
        end
        return T_prev1
    end
end

"""
    lambda_vandermonde(Lambda::NamedTuple, S;
                      basis::Symbol=:chebyshev,
                      force_anisotropic::Bool=false,
                      force_tensorized::Bool=false)

Dispatching lambda_vandermonde that selects implementation based on grid structure.

This wrapper automatically detects grid structure and calls the appropriate implementation:
- Tensorized: For regular tensor-product grids (2x faster, eliminates dict lookup bottleneck)
- Anisotropic: For grids with different nodes per dimension
- Original: Fallback for irregular grids

# Arguments
- `Lambda::NamedTuple`: Multi-index set
- `S`: Grid matrix (or vector for compatibility)
- `basis::Symbol=:chebyshev`: Polynomial basis
- `force_anisotropic::Bool=false`: Force use of anisotropic algorithm
- `force_tensorized::Bool=false`: Force use of tensorized algorithm

# Returns
- Vandermonde matrix

# Performance
- Tensorized version: ~2x faster than original (5.8ms → 2.9ms for 4D, GN=6, degree=5)
- Reduces dictionary lookups by 126x (1.2M → 9.6K lookups)
"""
function lambda_vandermonde(
    Lambda::NamedTuple,
    S;
    basis::Symbol = :chebyshev,
    force_anisotropic::Bool = false,
    force_tensorized::Bool = false
)
    # Convert to matrix if needed for analysis
    S_matrix = isa(S, Matrix) ? S : S

    # Quick dimension check
    if size(S_matrix, 2) == 1
        # 1D case - always use original implementation
        @debug "Vandermonde: Using original implementation (1D case)"
        return lambda_vandermonde_original(Lambda, S, basis = basis)
    end

    # Force tensorized if requested
    if force_tensorized
        @debug "Vandermonde: Using tensorized implementation (forced)"
        return lambda_vandermonde_tensorized(Lambda, S, basis = basis)
    end

    # Check if grid is anisotropic (only for matrix inputs)
    if force_anisotropic || (isa(S, Matrix) && is_grid_anisotropic(S))
        # Use anisotropic implementation
        @debug "Vandermonde: Using anisotropic implementation"
        return lambda_vandermonde_anisotropic(Lambda, S, basis = basis)
    else
        # Use tensorized implementation for regular grids (2x faster!)
        @debug "Vandermonde: Using tensorized implementation (default for isotropic grids)"
        return lambda_vandermonde_tensorized(Lambda, S, basis = basis)
    end
end

"""
    subdivide_domain(T::TestInput)::Vector{TestInput}

Subdivide a test input domain into 2ⁿ smaller subdomains, where n is the dimension of the input space.

# Arguments
- `T::TestInput`: The original test input domain to be subdivided.

# Returns
- `Vector{TestInput}`: A vector containing 2ⁿ new TestInput objects, each representing a subdomain.

# Details
The function performs the following operations:
1. Splits the original domain into 2ⁿ subdomains by dividing the sample range by 2
2. For each subdomain:
   - Creates a new center point by shifting the original center along each dimension
   - Preserves all other parameters from the original TestInput
   - Maintains precision parameters (alpha, delta) if they exist

# Properties
- The sample range of each subdomain is half of the original sample range
- The new center points are positioned at ±sample_range from the original center in each dimension
- All other parameters (GN, tolerance, reduce_samples, degree_max) are inherited from the original TestInput

# Example
```julia
# Create an original test input for a 2D domain
original = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=1.0)

# Subdivide the domain
subdomains = subdivide_domain(original)
# Returns 4 TestInput objects (2² = 4) with centers at:
# [-1.0, -1.0], [-1.0, 1.0], [1.0, -1.0], [1.0, 1.0]
# and sample_range = 0.5
```
"""
function subdivide_domain(T::TestInput)::Vector{TestInput}
    n = T.dim
    subdivided_inputs = Vector{TestInput}()
    new_scale = isnothing(T.sample_range) ? nothing : T.sample_range / 2

    for i in 0:(2^n - 1)
        new_center = copy(T.center)
        if !isnothing(T.sample_range)
            for j in 0:(n - 1)
                if (i >> j) & 1 == 1
                    new_center[j + 1] += T.sample_range
                else
                    new_center[j + 1] -= T.sample_range
                end
            end
        end

        # Handle optional precision parameters
        alpha = isnothing(T.prec) ? nothing : T.prec[1]
        delta = isnothing(T.prec) ? nothing : T.prec[2]

        # Create new TestInput using keyword arguments
        push!(
            subdivided_inputs,
            TestInput(
                T.objective;  # first positional argument is the function
                dim = n,
                center = new_center,
                GN = T.GN,
                alpha = alpha,
                delta = delta,
                tolerance = T.tolerance,
                sample_range = new_scale,
                reduce_samples = T.reduce_samples,
                degree_max = T.degree_max  # Added degree_max parameter
            )
        )
    end

    return subdivided_inputs
end
