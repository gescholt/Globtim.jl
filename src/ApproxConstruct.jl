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