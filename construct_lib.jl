

using LinearAlgebra, LinearSolve, Statistics, HomotopyContinuation


tref(x, y) = exp(sin(50x)) + sin(60exp(y)) + sin(70sin(x)) + sin(sin(80y)) - sin(10(x + y)) + (x^2 + y^2) / 4
zeta(x) = x + (1 - x) * log(1 - x)

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

# Function to calculate the required number of samples
function calculate_samples(m, delta, alph)
    K = 1
    condition = m^(log(3) / log(2)) / zeta(delta)
    while condition > K / (log(K) + log(6 * alph^(-1)))
        K += m
    end
    return K
end

# Function to generate the sampling grid
function generate_grid(n, GN)
    ChebyshevNodes = [cos((2i + 1) * π / (2 * GN + 2)) for i in 0:GN]
    cart_cheb = [ChebyshevNodes for _ in 1:n]
    grid = Iterators.product(cart_cheb...)
    return collect(grid)
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

function lambda_vandermonde(Lambda, S)
    # Generate Vandermonde like matrix in Chebyshev tensored basis. 
    m, N = Lambda.size
    n, N = size(S)
    print("\n")
    print("dimension Vector space: ", m)
    print("\n")
    print("sample size: ", n)
    print("\n")
    print("Dimension samples: ", N)
    print("\n")
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

# Main computation function
function main_computation(n::Int, d1::Int, d2::Int, ds::Int)
    symb_approx = []
    for d in d1:ds:d2
        m = binomial(n + d, d)  # Dimension of vector space
        K = calculate_samples(m, delta, alph)
        GN = round(sqrt(K)) + 1
        Lambda = support_gen(n, d)
        grid = generate_grid(n, GN)
        matrix_from_grid = reduce(hcat, map(t -> collect(t), grid))'

        VL = lambda_vandermonde(Lambda, matrix_from_grid)
        G_original = VL' * VL
        F = [tref(C * matrix_from_grid[Int(i), 1], C * matrix_from_grid[Int(i), 2]) for i in 1:(GN+1)^2]
        RHS = VL' * F

        # Solve linear system using an appropriate LinearSolve function
        linear_prob = LinearProblem(G_original, RHS) # Define a linear problem
        # Now solve the problem with proper choice of compute method. 
        sol = LinearSolve.solve(linear_prob, method=:gmres, verbose=true)

        # Calculate execution time
        st = time()
        cheb_coeffs = sol.u
        et = time() - st
        print("\n")
        print("degree:", d)
        print("\n")
        print("compute time:", et)
        print("\n")
        push!(symb_approx, (cheb_coeffs, et))
    end
    return symb_approx
end

# return the symbolic approxiamnt with expanded chebyshev polynomials in variables 1 through n 
function generateApproximant(Lambda, rat_sol_cheb)
    m, n = size(Lambda)
    # m: dimension of polynomial vector space we project onto. 
    # n: number of variables

    ## Validate input sizes and consistency
    if isempty(Lambda)
        error("Lambda must not be empty")
    end

    # Ensure the number of coefficients matches the number of polynomial terms
    if length(rat_sol_cheb) != m
        print("\n")
        error("The length of rat_sol_cheb must match the dimension of the space we project onto")
    end

    # @polyvar(x[1:n])     # Dynamically create symbolic variables based on n
    S_rat = 0 * x[1]      # Initialize the sum S_rat

    # Iterate over each index of Lambda and rat_sol_cheb using only the length of rat_sol_cheb
    for i in 1:m # for each term of the orthonormal basis.        
        prd = 1 + 0 * x[1] # Initialize product prd for each i
        # Loop over each variable index in the row
        for j in 1:n
            # Multiply prd by the Chebyshev polynomial T evaluated at x[j]
            prd *= chebyshev_poly(Lambda[i, j], x[j])
        end

        # Add the product scaled by the corresponding rational solution coefficient to S_rat
        S_rat += rationalize(BigInt, rat_sol_cheb[i]) * prd
    end

    return S_rat
end


function rational_bigint_to_int(r::Rational{BigInt}, tol::Float64=1e-12)
    # Convert Rational{BigInt} to Float64
    float_approximation = Float64(r)
    # Use rationalize to convert Float64 to Rational{Int}
    rational_approx = rationalize(float_approximation)
    return Rational{Int}(numerator(rational_approx), denominator(rational_approx))

end

function RRsolve(n, p1, p2)
    p1_str = string(p1)
    p2_str = string(p2)
    @var(x[1:n])
    p1_converted = eval(Meta.parse(p1_str))
    p2_converted = eval(Meta.parse(p2_str))
    Z = System([p1_converted, p2_converted])
    Real_sol_lstsq = HomotopyContinuation.solve(Z)
    real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)
    return real_pts
end 