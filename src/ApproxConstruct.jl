
# All Structures are located in main_gen.jl # 

# using LegendrePolynomials

"""
    ChebyshevPoly(d::Int, x)

Generate the Chebyshev polynomial of degree `d` in the variable `x` with rational coefficients.

# Arguments
- `d::Int`: Degree of the Chebyshev polynomial.
- `x`: Variable for the polynomial.

# Returns
- The Chebyshev polynomial of degree `d` in the variable `x`.

# Example
```julia
ChebyshevPoly(3, x)
```
"""
function ChebyshevPoly(d::Int, x)
    if d == 0
        return rationalize(1.0)
    elseif d == 1
        return x
    else
        T_prev = rationalize(1.0)
        T_curr = x
        for n in 2:d
            T_next = rationalize(2.0) * x * T_curr - T_prev
            T_prev = T_curr
            T_curr = T_next
        end
        return T_curr
    end
end

# """
# Rodrigues formula implementation. 
# Should work with Dynamic Polynomials. Should not be raw evaluated, meaning that 
# this should be stored as an object, to then be evaluated. 
# """
# function LegendrePoly(d::Int, x)
#     p = (x^2 - 1)^d
#     coeff = 1 / (2^d * factorial(big(d)))
#     return coeff * differentiate(p, x, d)
# end


"""
    ChebyshevPolyExact(d::Int)::Vector{Int}

Generate a vector of integer coefficients of the Chebyshev polynomial of degree `d` in one variable.

# Arguments
- `d::Int`: Degree of the Chebyshev polynomial.

# Returns
- A vector of integer coefficients of the Chebyshev polynomial of degree `d`.

# Example
```julia
ChebyshevPolyExact(3)
```
"""
function ChebyshevPolyExact(d::Int)::Vector{Int}
    if d == 0
        return [1]
    elseif d == 1
        return [0, 1]
    else
        Tn_1 = ChebyshevPolyExact(d - 1)
        Tn_2 = ChebyshevPolyExact(d - 2)
        Tn = [0; 2 * Tn_1] - vcat(Tn_2, [0, 0])
        return Tn
    end
end


"""
    BigFloatChebyshevPoly(d::Int, x)

Generate the Chebyshev polynomial with `BigFloat` coefficients of degree `d` in the variable `x`.

# Arguments
- `d::Int`: Degree of the Chebyshev polynomial.
- `x`: Variable for the polynomial.

# Returns
- The Chebyshev polynomial of degree `d` in the variable `x` with `BigFloat` coefficients.

# Example
```julia
BigFloatChebyshevPoly(3, x)
```
"""
function BigFloatChebyshevPoly(d::Int, x)
    if d == 0
        return BigFloat(1.0)
    elseif d == 1
        return x
    else
        T_prev = BigFloat(1.0)
        T_curr = x
        for n in 2:d
            T_next = BigFloat(2.0) * x * T_curr - T_prev
            T_prev = T_curr
            T_curr = T_next
        end
        return T_curr
    end
end


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
    GN = length(unique_points) - 1  # Number of points - 1

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

# ======================================================= For Msolve =======================================================
"""
    process_output_file(file_path::String)

Parse the output file generated by `msolve`.

# Arguments
- `file_path::String`: Path to the output file.

# Returns
- Parsed content of the output file.
"""
function process_output_file(file_path)
    content = read(file_path, String)    # Read the file content
    array_start = findfirst(r"\[\[\[", content)[1] # Extract the array starting from line 2
    array_end = findfirst(r"\]\]\]", content)[end]
    if array_start === nothing
        error("No array found starting from line 2.")
    end
    array_content = content[array_start:array_end]
    replaced_expression = replace(array_content, r"(-?\d+) / (2\^(\d+))" => s -> "[" * match(r"(-?\d+)", s).match * ", " * match(r"(\d+)$", s).match * "]")
    parsed_expression = Meta.parse(replaced_expression)
    evaled = eval(parsed_expression)
    return evaled
end

"""
    parse_point(X::Vector{Vector{Vector{BigInt}}})::Vector{Rational{BigInt}}

Parse a nested vector of `BigInt` values and convert them into a vector of `Rational{BigInt}`.

# Arguments
- `X::Vector{Vector{Vector{BigInt}}}`: A nested vector where each element is a vector of two vectors, each containing two `BigInt` values. The first value in each inner vector represents the numerator, and the second value represents the exponent of the denominator (which is a power of 2).

# Returns
- `Vector{Rational{BigInt}}`: A vector of `Rational{BigInt}` values, where each value is the average of the two rational numbers represented by the input vectors.

# Example
```julia
X = [
    [[1, 1], [3, 1]],  # Represents 1/2 and 3/2
    [[2, 2], [6, 2]]   # Represents 2/4 and 6/4
]
result = parse_point(X)
# result is a vector of Rational{BigInt} values: [1, 1]

"""
function parse_point(X::Vector{Vector{Vector{BigInt}}})::Vector{Rational{BigInt}}
    pts = Vector{Rational{BigInt}}()
    for x in X
        numer_low = x[1][1]
        denom_low = BigInt(2)^x[1][2]
        numer_hig = x[2][1]
        denom_hig = BigInt(2)^x[2][2]
        LW = Rational{BigInt}(numer_low, denom_low)
        HG = Rational{BigInt}(numer_hig, denom_hig)
        AVG = (LW + HG) / 2
        push!(pts, AVG)
    end
    return (pts)
end

"""
    check_parameter(value, threshold; prompt=true)

Checks if the given `value` exceeds the specified `threshold`. If it does and `prompt` is `true`,
prompts the user with a yes/no question: "Are you sure you want to proceed?".

# Arguments
- `value::Number`: The value to be checked.
- `threshold::Number`: The threshold value to compare against.
- `prompt::Bool`: Optional keyword argument (default is `true`). If `false`, the function will not prompt the user.

# Returns
- `Bool`: Returns `true` if the user confirms to proceed or if the value does not exceed the threshold.
          Returns `false` if the user decides to abort.
"""
function check_parameter(value, threshold; prompt=true)
    if value > threshold && prompt
        while true
            println("Are you sure you want to proceed? (yes/no)")
            answer = readline()
            answer = lowercase(answer)
            if answer == "yes"
                return true
            elseif answer == "no"
                return false
            else
                println("Invalid input. Please type 'yes' or 'no'.")
            end
        end
    else
        return true
    end
end

"""
Function to solve the polynomial system using HomotopyContinuation.jl and the DynamicPolynomials.jl environment.
"""
function solve_polynomial_system(x, n, d, coeffs; basis=:chebyshev, bigint=true)
    pol = main_nd(x, n, d, coeffs, basis=basis, bigint=bigint)
    grad = differentiate.(pol, x)
    sys = System(grad)
    solutions = solve(sys, start_system=:total_degree)
    rl_sol = real_solutions(solutions; only_real=true, multiple_results=false)
    return rl_sol, sys
end

"""
2D function to process critical points and return a DataFrame with the results.
    Only keeps the points in [-1,1]^2.
"""
function process_critical_points(real_pts, f, scale_factor)
    solutions = real_pts[1]  # Extract solutions from tuple
    condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1
    filtered_points = filter(condition, solutions)

    h_x = Float64[point[1] for point in filtered_points]
    h_y = Float64[point[2] for point in filtered_points]
    h_z = map(p -> f([p[1], p[2]]), zip(scale_factor * h_x, scale_factor * h_y))

    DataFrame(x=scale_factor * h_x, y=scale_factor * h_y, z=h_z)
end
