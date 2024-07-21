# Optim library for construction of the notebook# 
# General version of the algorithm running on arbitrary number of variables # 

using LinearAlgebra, LinearSolve, Statistics

function zeta(x)
    return x + (1 - x) * log(1 - x)
end 


# Function to calculate the required number of samples
function calculate_samples(m, delta, alph)
    K = 1
    condition = m^(log(3) / log(2)) / zeta(delta)
    while condition > K / (log(K) + log(6 * alph^(-1)))
        K += m
    end
    return K
end

# Function to compute the support of polynomial of total degree at most $d$. 
function support_gen(n, d)
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

# Function to generate the sampling grid
function generate_grid(n::Int, GN::Int)
    ChebyshevNodes = [cos((2i + 1) * π / (2 * GN + 2)) for i in 0:GN]
    cart_cheb = [ChebyshevNodes for _ in 1:n]
    grid = Iterators.product(cart_cheb...)
    return collect(grid)
end

function chebyshev_poly(d::Int, x)
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

function lambda_vandermonde(Lambda, S)
    # Generate Vandermonde like matrix in Chebyshev tensored basis. 
    m, N = Lambda.size
    n, N = size(S)
   
    V = zeros(n, m)
    for i in 1:n # Number of samples
        for j in 1:m # Dimension of vector space of polynomials
            P = 1.0
            for k in 1:N # Dimension of each sample
                P *= chebyshev_poly(Lambda.data[j, k], S[i, k])
            end
            V[i, j] = P
        end
    end
    return V
end

# Geneate the approximants in the new optim file, more parameters are added to the function.
function main_gen(f, n::Int, d1::Int, d2::Int, ds::Int, delta::Float64, alph::Float64, C::Float64, scl::Float64)::Vector{Vector{Float64}}
    # slc is a scaling factor to reduce the number of points in the grid.
    symb_approx = []
    for d in d1:ds:d2
        m = binomial(n + d, d)  # Dimension of vector space
        K = calculate_samples(m, delta, alph)
        # GN = Int(round(K^(1 / n)) + 1)
        GN = Int(round(K^(1 / n)*scl) + 1) # need fewe points for high degre stuff # 
        Lambda = support_gen(n, d)
        grid = generate_grid(n, GN)
        matrix_from_grid = reduce(hcat, map(t -> collect(t), grid))'
        # println("dimension Vector space: ", m)
        # println("sample size: ", size(matrix_from_grid)[1])
        VL = lambda_vandermonde(Lambda, matrix_from_grid)
        G_original = VL' * VL
        # F = [f(C * matrix_from_grid[Int(i), 1], C * matrix_from_grid[Int(i), 2]) for i in 1:(GN+1)^2]
        F = [f([C * matrix_from_grid[Int(i), :]...]) for i in 1:(GN+1)^n]
        RHS = VL' * F

        # Solve linear system using an appropriate LinearSolve function
        linear_prob = LinearProblem(G_original, RHS) # Define a linear problem
        # Now solve the problem with proper choice of compute method. 

        sol = LinearSolve.solve(linear_prob, method=:gmres, verbose=true)
        cheb_coeffs = sol.u

        push!(symb_approx, cheb_coeffs)
    end
    return symb_approx
end

# Geneate the approximants in the new optim file, more parameters are added to the function.
# Solve the linear algebra problem over BigFloats instead of Float64
## Tested ##
function precise_gen(f, n::Int, d1::Int, d2::Int, ds::Int, delta::Float64, alph::Float64, C::Float64, scl::Float64)::Vector{Vector{BigFloat}}
    # slc is a scaling factor to reduce the number of points in the grid.
    symb_approx = []
    for d in d1:ds:d2
        m = binomial(n + d, d)  # Dimension of vector space
        K = calculate_samples(m, delta, alph)
        GN = Int(round(K^(1 / n) * scl) + 1) # need fewe points for high degre stuff # 
        Lambda = support_gen(n, d)
        grid = generate_grid(n, GN)
        matrix_from_grid = reduce(hcat, map(t -> collect(t), grid))'
        println("dimension Vector space: ", m)
        println("sample size: ", size(matrix_from_grid)[1])
        VL = lambda_vandermonde(Lambda, matrix_from_grid)
        G_original = BigFloat.(VL') * BigFloat.(VL)
        F = [f([C * matrix_from_grid[Int(i), :]...]) for i in 1:(GN+1)^n]
        RHS = BigFloat.(VL') * BigFloat.(F)

        # Solve linear system using an appropriate LinearSolve function
        linear_prob = LinearProblem(G_original, RHS) # Define a linear problem
        # Now solve the problem with proper choice of compute method. 

        sol = LinearSolve.solve(linear_prob, method=:gmres, verbose=true)
        cheb_coeffs = sol.u

        push!(symb_approx, cheb_coeffs)
    end
    return symb_approx
end

## Process the crtitcal points ##

# Compute the smallest distances between the minima of the function and the critical points of the approximant.
function compute_closest_distances(extrema_points, given_points)
    closest_distances = []
    for extremum in extrema_points
        min_distance = Inf
        for point in given_points
            dist = norm(extremum .- point)
            if dist < min_distance
                min_distance = dist
            end
        end
        push!(closest_distances, min_distance)
    end
    return closest_distances
end