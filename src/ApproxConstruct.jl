
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
        if sum(exp .^ 2 .* (1 ./ es.coeffs .^2)) <= es.radius
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
        throw(ArgumentError("Invalid degree format. Use :one_d_for_all or :one_d_per_dim or :fully_custom."))
    end

    if D == 0
        return (data = zeros(Int, 1, n), size = (1, n))
    end

    lambda_vectors = get_lambda_exponent_vectors(d, n)
    # @info "" lambda_vectors

    lambda_matrix = length(lambda_vectors) > 0 ? reduce(hcat, lambda_vectors)' : zeros(Int, 0, n)

    return (data = lambda_matrix, size = size(lambda_matrix))
end

TimerOutputs.@timeit _TO function lambda_vandermonde_original(Lambda::NamedTuple, S; basis=:chebyshev)
    T = eltype(S)  # Infer type from input
    m, N = Lambda.size
    n, N = size(S)
    V = zeros(T, n, m)  # Use inferred type instead of Float64

    # Get unique points (they're the same for each dimension)
    unique_points = unique(S[:, 1])

    # Find max degree needed
    max_degree = maximum(Lambda.data)

    # Create point index lookup once
    point_indices = Dict(point => i for (i, point) in enumerate(unique_points))

    if basis == :legendre
        # Precompute Legendre polynomial evaluations for all degrees at unique points
        eval_cache = Dict{Int,Vector{T}}()  # Use type T instead of Float64

        # Compute polynomials and evaluations
        @views for degree = 0:max_degree
            # For now, keep using Float64 precision for polynomial generation
            # but convert results to type T
            poly = symbolic_legendre(degree, precision=Float64Precision, normalized=true)
            
            # Convert evaluation results to type T
            eval_cache[degree] = map(point -> T(evaluate_legendre(poly, Float64(point))), unique_points)
        end

        # Compute Vandermonde matrix using cached values
        @views for i = 1:n, j = 1:m
            P = one(T)  # Use one(T) instead of 1.0
            for k = 1:N
                degree = Int(Lambda.data[j, k])
                point = S[i, k]
                point_idx = point_indices[point]
                P *= eval_cache[degree][point_idx]
            end
            V[i, j] = P
        end

    elseif basis == :chebyshev
        # Precompute Chebyshev polynomial evaluations
        eval_cache = Dict{Int,Vector{T}}()

        # Special handling for exact types vs floating point
        if T <: Rational || T <: Integer
            # Use recurrence relation for exact computation
            for degree = 0:max_degree
                eval_cache[degree] = T[]
                for point in unique_points
                    push!(eval_cache[degree], chebyshev_value_exact(degree, T(point)))
                end
            end
        else
            # Use cosine formula for floating point types
            @views for point in unique_points
                point_idx = point_indices[point]
                theta = acos(clamp(T(point), T(-1), T(1)))
                for degree = 0:max_degree
                    if !haskey(eval_cache, degree)
                        eval_cache[degree] = Vector{T}(undef, length(unique_points))
                    end
                    eval_cache[degree][point_idx] = cos(degree * theta)
                end
            end
        end

        # Compute Vandermonde matrix using cached values
        @views for i = 1:n, j = 1:m
            P = one(T)
            for k = 1:N
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
                "Unsupported basis: $basis. Supported bases are :legendre and :chebyshev",
            ),
        )
    end

    return V
end

# Helper function for exact Chebyshev evaluation
function chebyshev_value_exact(n::Int, x::T) where T
    if n == 0
        return one(T)
    elseif n == 1
        return x
    else
        # T_n(x) = 2x*T_{n-1}(x) - T_{n-2}(x)
        T_prev2 = one(T)
        T_prev1 = x
        for k = 2:n
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
                      force_anisotropic::Bool=false)

Enhanced lambda_vandermonde that automatically detects and handles anisotropic grids.

This is a wrapper that maintains backward compatibility while adding anisotropic support.
It automatically detects grid type and calls the appropriate implementation.

# Arguments
- `Lambda::NamedTuple`: Multi-index set
- `S`: Grid matrix (or vector for compatibility)
- `basis::Symbol=:chebyshev`: Polynomial basis
- `force_anisotropic::Bool=false`: Force use of anisotropic algorithm

# Returns
- Vandermonde matrix

# Notes
- Automatically detects anisotropic grids and uses appropriate algorithm
- Falls back to original implementation for isotropic grids (better performance)
- Use `force_anisotropic=true` to test anisotropic algorithm on isotropic grids
"""
function lambda_vandermonde(Lambda::NamedTuple, S; 
                           basis::Symbol=:chebyshev,
                           force_anisotropic::Bool=false)
    # Convert to matrix if needed for analysis
    S_matrix = isa(S, Matrix) ? S : S
    
    # Quick dimension check
    if size(S_matrix, 2) == 1
        # 1D case - always use original implementation
        return lambda_vandermonde_original(Lambda, S, basis=basis)
    end
    
    # Check if grid is anisotropic (only for matrix inputs)
    if force_anisotropic || (isa(S, Matrix) && is_grid_anisotropic(S))
        # Use anisotropic implementation
        return lambda_vandermonde_anisotropic(Lambda, S, basis=basis)
    else
        # Use original (optimized for isotropic case)
        return lambda_vandermonde_original(Lambda, S, basis=basis)
    end
end

"""
    subdivide_domain(T::test_input)::Vector{test_input}

Subdivide a test input domain into 2ⁿ smaller subdomains, where n is the dimension of the input space.

# Arguments
- `T::test_input`: The original test input domain to be subdivided.

# Returns
- `Vector{test_input}`: A vector containing 2ⁿ new test_input objects, each representing a subdomain.

# Details
The function performs the following operations:
1. Splits the original domain into 2ⁿ subdomains by dividing the sample range by 2
2. For each subdomain:
   - Creates a new center point by shifting the original center along each dimension
   - Preserves all other parameters from the original test_input
   - Maintains precision parameters (alpha, delta) if they exist

# Properties
- The sample range of each subdomain is half of the original sample range
- The new center points are positioned at ±sample_range from the original center in each dimension
- All other parameters (GN, tolerance, reduce_samples, degree_max) are inherited from the original test_input

# Example
```julia
# Create an original test input for a 2D domain
original = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)

# Subdivide the domain
subdomains = subdivide_domain(original)
# Returns 4 test_input objects (2² = 4) with centers at:
# [-1.0, -1.0], [-1.0, 1.0], [1.0, -1.0], [1.0, 1.0]
# and sample_range = 0.5
```
"""
function subdivide_domain(T::test_input)::Vector{test_input}
    n = T.dim
    subdivided_inputs = Vector{test_input}()
    new_scale = isnothing(T.sample_range) ? nothing : T.sample_range / 2

    for i = 0:(2^n-1)
        new_center = copy(T.center)
        if !isnothing(T.sample_range)
            for j = 0:(n-1)
                if (i >> j) & 1 == 1
                    new_center[j+1] += T.sample_range
                else
                    new_center[j+1] -= T.sample_range
                end
            end
        end

        # Handle optional precision parameters
        alpha = isnothing(T.prec) ? nothing : T.prec[1]
        delta = isnothing(T.prec) ? nothing : T.prec[2]

        # Create new test_input using keyword arguments
        push!(
            subdivided_inputs,
            test_input(
                T.objective;  # first positional argument is the function
                dim = n,
                center = new_center,
                GN = T.GN,
                alpha = alpha,
                delta = delta,
                tolerance = T.tolerance,
                sample_range = new_scale,
                reduce_samples = T.reduce_samples,
                degree_max = T.degree_max,  # Added degree_max parameter
            ),
        )
    end

    return subdivided_inputs
end

