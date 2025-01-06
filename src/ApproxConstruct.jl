"""
    SupportGen(n::Int, d::Int)::NamedTuple

Compute the support of a dense polynomial of total degree at most d in n variables.

# Arguments
- `n::Int`: Number of variables.
- `d::Int`: Maximum degree of the polynomial.

# Returns
- A `NamedTuple` containing the matrix of support and its size attributes.

# Example
```julia
SupportGen(2, 3)
```
"""
function SupportGen(n::Int, d::Int)::NamedTuple
    ranges = [0:d for _ in 1:n]     # Generate ranges for each dimension
    iter = Iterators.product(ranges...) # Create the Cartesian product over the ranges
    # Initialize a list to hold valid tuples
    lambda_list = []
    # Loop through the Cartesian product, filtering valid tuples
    for tuple in iter
        if sum(tuple) <= d
            push!(lambda_list, collect(tuple))  # Convert each tuple to an array
        end
    end
    # Check if lambda_list is empty to handle edge cases
    if length(lambda_list) == 0
        lambda_matrix = zeros(0, n)  # Return an empty matrix with 0 rows and n columns
    else
        # Convert the list of arrays to an N x n matrix
        lambda_matrix = hcat(lambda_list...)'
    end
    # Return a NamedTuple containing the matrix and its size attributes
    return (data=lambda_matrix, size=size(lambda_matrix))
end

"""
    lambda_vandermonde(Lambda::NamedTuple, S; basis=:chebyshev)

Compute the Vandermonde matrix using precomputed basis polynomials.
Optimized for grids where sample points are the same along each dimension.
Lambda is generated from SupportGen(n,d) and contains integer degrees.
S is the sample points matrix where each column contains the same points.
"""
function lambda_vandermonde(Lambda::NamedTuple, S; basis=:chebyshev)
    m, N = Lambda.size
    n, N = size(S)
    V_big = zeros(BigFloat, n, m)

    # Get unique points (they're the same for each dimension)
    unique_points = unique(S[:, 1])
    # GN = length(unique_points) - 1  # Number of points - 1

    if basis == :legendre
        # Find max degree needed
        max_degree = maximum(Lambda.data)

        # Precompute Legendre polynomial evaluations for all degrees at unique points
        eval_cache = Dict{Int,Vector{BigFloat}}()
        for degree in 0:max_degree
            eval_cache[degree] = [evaluate_legendre(symbolic_legendre(degree), point) for point in unique_points]
        end

        # Create point index lookup
        point_indices = Dict(point => i for (i, point) in enumerate(unique_points))

        # Compute Vandermonde matrix using cached values
        for i in 1:n
            for j in 1:m
                P = one(BigFloat)
                for k in 1:N
                    degree = Int(Lambda.data[j, k])
                    point = S[i, k]
                    point_idx = point_indices[point]
                    P *= eval_cache[degree][point_idx]
                end
                V_big[i, j] = P
            end
        end

    elseif basis == :chebyshev
        # Precompute Chebyshev polynomial evaluations for all needed degrees
        max_degree = maximum(Lambda.data)
        eval_cache = Dict{Int,Vector{BigFloat}}()

        # For Chebyshev nodes, we can directly compute values
        # cos(k * arccos(x)) is the k-th Chebyshev polynomial
        for point_idx in 1:length(unique_points)
            x = unique_points[point_idx]
            theta = acos(x)
            for degree in 0:max_degree
                if !haskey(eval_cache, degree)
                    eval_cache[degree] = Vector{BigFloat}(undef, length(unique_points))
                end
                eval_cache[degree][point_idx] = cos(degree * theta)
            end
        end

        # Create point index lookup
        point_indices = Dict(point => i for (i, point) in enumerate(unique_points))

        # Compute Vandermonde matrix using cached values
        for i in 1:n
            for j in 1:m
                P = one(BigFloat)
                for k in 1:N
                    degree = Int(Lambda.data[j, k])
                    point = S[i, k]
                    point_idx = point_indices[point]
                    P *= eval_cache[degree][point_idx]
                end
                V_big[i, j] = P
            end
        end
    else
        error("Unsupported basis: $basis")
    end

    return Float64.(V_big)
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

    for i in 0:(2^n-1)
        new_center = copy(T.center)
        if !isnothing(T.sample_range)
            for j in 0:(n-1)
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
        push!(subdivided_inputs, test_input(
            T.objective;  # first positional argument is the function
            dim=n,
            center=new_center,
            GN=T.GN,
            alpha=alpha,
            delta=delta,
            tolerance=T.tolerance,
            sample_range=new_scale,
            reduce_samples=T.reduce_samples,
            degree_max=T.degree_max  # Added degree_max parameter
        ))
    end

    return subdivided_inputs
end