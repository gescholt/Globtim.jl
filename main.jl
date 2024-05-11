# main.jl
include("construct_lib.jl")
using LinearSolve

# Constants and Parameters
const d1, d2, ds = 2, 3, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters



# Function to generate the sampling grid
function generate_grid(n, GN)
    ChebyshevNodes = [cos((2i + 1) * π / (2 * GN + 2)) for i in 0:GN]
    cart_cheb = [ChebyshevNodes for _ in 1:n]
    grid = Iterators.product(cart_cheb...)
    return collect(grid)
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
        sol = solve(linear_prob, method=:gmres, verbose=true)

        # Calculate execution time
        st = time()
        cheb_coeffs = sol.u
        et = time() - st

        push!(symb_approx, (cheb_coeffs, et))
    end
    return symb_approx
end

# Execute the computation
results = main_computation(n, d1, d2, ds)
print(results)
