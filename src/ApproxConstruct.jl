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
# function SupportGen(n::Int, d::Int)::NamedTuple
#     ranges = [0:d for _ in 1:n]     # Generate ranges for each dimension
#     iter = Iterators.product(ranges...) # Create the Cartesian product over the ranges
#     # Initialize a list to hold valid tuples
#     lambda_list = []
#     # Loop through the Cartesian product, filtering valid tuples
#     for tuple in iter
#         if sum(tuple) <= d
#             push!(lambda_list, collect(tuple))  # Convert each tuple to an array
#         end
#     end
#     # Check if lambda_list is empty to handle edge cases
#     if length(lambda_list) == 0
#         lambda_matrix = zeros(0, n)  # Return an empty matrix with 0 rows and n columns
#     else
#         # Convert the list of arrays to an N x n matrix
#         lambda_matrix = hcat(lambda_list...)'
#     end
#     # Return a NamedTuple containing the matrix and its size attributes
#     return (data=lambda_matrix, size=size(lambda_matrix))
# end

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
support = SupportGen(2, 3)
# Returns a NamedTuple with monomial exponents for polynomials in 2 variables up to degree 3
"""

function SupportGen(n::Int, d::Int)::NamedTuple
    n ≥ 1 || throw(ArgumentError("Number of variables must be positive"))
    d ≥ 0 || throw(ArgumentError("Degree must be non-negative"))

    if d == 0
        return (data=zeros(Int, 1, n), size=(1, n))
    end

    estimated_size = binomial(n + d, d)
    lambda_vectors = Vector{Vector{Int}}(undef, estimated_size)
    count = 0

    ranges = fill(0:d, n)
    for idx in Iterators.product(ranges...)
        sum(idx) ≤ d || continue
        count += 1
        lambda_vectors[count] = collect(Int, idx)
    end

    resize!(lambda_vectors, count)

    lambda_matrix = count > 0 ? reduce(hcat, lambda_vectors)' : zeros(Int, 0, n)

    return (
        data=lambda_matrix,
        size=size(lambda_matrix)
    )
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

    # Find max degree needed
    max_degree = maximum(Lambda.data)
    use_bigint = max_degree > 30

    # Create point index lookup once
    point_indices = Dict(point => i for (i, point) in enumerate(unique_points))

    if basis == :legendre
        # Precompute Legendre polynomial evaluations for all degrees at unique points
        eval_cache = Dict{Int,Vector{BigFloat}}()

        # Compute polynomials and evaluations
        @views for degree in 0:max_degree
            poly = symbolic_legendre(degree, use_bigint=use_bigint)
            eval_cache[degree] = map(point -> evaluate_legendre(poly, big(point)), unique_points)
        end

        # Compute Vandermonde matrix using cached values
        @views for i in 1:n, j in 1:m
            P = one(BigFloat)
            for k in 1:N
                degree = Int(Lambda.data[j, k])
                point = S[i, k]
                point_idx = point_indices[point]
                P *= eval_cache[degree][point_idx]
            end
            V_big[i, j] = P
        end

    elseif basis == :chebyshev
        # Precompute Chebyshev polynomial evaluations
        eval_cache = Dict{Int,Vector{BigFloat}}()

        # Precompute all values using cosine formula
        @views for point in unique_points
            point_idx = point_indices[point]
            theta = acos(big(point))
            for degree in 0:max_degree
                if !haskey(eval_cache, degree)
                    eval_cache[degree] = Vector{BigFloat}(undef, length(unique_points))
                end
                eval_cache[degree][point_idx] = cos(degree * theta)
            end
        end

        # Compute Vandermonde matrix using cached values
        @views for i in 1:n, j in 1:m
            P = one(BigFloat)
            for k in 1:N
                degree = Int(Lambda.data[j, k])
                point = S[i, k]
                point_idx = point_indices[point]
                P *= eval_cache[degree][point_idx]
            end
            V_big[i, j] = P
        end
    else
        throw(ArgumentError("Unsupported basis: $basis. Supported bases are :legendre and :chebyshev"))
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

"""
    discrete_l2_norm_riemann(f, grid::Array{SVector{N,Float64},N}) where N -> Float64

Compute a discrete L² norm approximation using a Riemann sum over an N-dimensional grid of points.
This implementation is particularly suited for non-uniform grids such as Chebyshev points, where
it constructs appropriate cell volumes based on the spacing between points.

# Arguments
- `f`: Function to integrate. Should accept an `SVector{N,Float64}` and return a real number
- `grid::Array{SVector{N,Float64},N}`: N-dimensional array of grid points, where each point is 
   represented as an SVector{N,Float64}. Typically generated by `generate_grid` or 
   `generate_grid_small_n`

# Returns
- `Float64`: The approximate L² norm computed as sqrt(∫|f|² dx) using a Riemann sum approximation

# Method
The function constructs a Riemann sum approximation by:
1. Identifying unique coordinates in each dimension
2. Computing cell boundaries as midpoints between adjacent points
3. Using [-1,1] as domain boundaries
4. Computing cell volumes as products of distances between adjacent boundaries
5. Summing |f|² weighted by these cell volumes

# Example
```julia
# Create 2D Chebyshev grid
grid = generate_grid(2, 10, basis=:chebyshev)

# Define test function
f(x) = sum(x.^2)

# Compute norm
norm = discrete_l2_norm_riemann(f, grid)
Notes

For a uniform grid (e.g., Legendre points), this will approximate the standard L² norm
For Chebyshev points, this accounts for the non-uniform point distribution
The cell volumes are constructed to cover the entire [-1,1]ⁿ domain
No normalization of volumes is performed, so the sum of volumes might slightly deviate from 2ⁿ
(the volume of [-1,1]ⁿ)

For large sample grids, the function may be slow due to the nested product loop over grid points. 
"""

function discrete_l2_norm_riemann(f, grid::Array{SVector{N,Float64},N}) where {N}
    GN = size(grid, 1) - 1  # Number of intervals

    # Create vectors of the unique coordinates in each dimension
    coords = [sort(unique([p[i] for p in vec(grid)])) for i in 1:N]

    # Compute cell boundaries as midpoints between adjacent points
    # Add domain boundaries [-1,1] as endpoints
    cell_bounds = [vcat(-1.0,
        [(coords[d][i] + coords[d][i+1]) / 2 for i in 1:GN],
        1.0)
                   for d in 1:N]

    # Compute cell volumes
    cell_volumes = [SVector{N,Float64}(ntuple(d ->
            cell_bounds[d][idx[d]+1] - cell_bounds[d][idx[d]], N))
                    for idx in Iterators.product(fill(1:GN+1, N)...)]

    # Compute cell volumes as products of side lengths
    volumes = [prod(vol) for vol in cell_volumes]

    # Reshape to match grid structure
    volumes = reshape(volumes, fill(GN + 1, N)...)

    # Compute Riemann sum
    sum_squares = sum(abs2(f(x)) * v for (x, v) in zip(grid, volumes))

    return sqrt(sum_squares)
end