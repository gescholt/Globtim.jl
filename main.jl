# main.jl
include("construct_lib.jl")
using LinearSolve

# Parameters
const d1 = 2  # start degree
const d2 = 3  # end degree
const ds = 1  # degree step
const n  = 2  # dimension
const a  = 1
const b  = 3
const C  = a / b  # Scaling constant

# Sampling Parameters
const delta = 1 / 2
const alph = 9 / 10

# Main loop
symb_approx = []

for d in d1:ds:d2
    m = binomial(n + d, d)  # dimension of vector space
    K = 1  # initialize number of samples to consider
    ineq = m^(log(3) / log(2)) / zeta(delta) <= K / (log(K) + log(6 * alph^(-1)))

    while !eval(ineq)  # loop to get enough samples for good conditioning of Gram matrix
        K += m
        ineq = m^(log(3) / log(2)) / zeta(delta) <= K / (log(K) + log(6 * alph^(-1)))
    end
    # Loop increasing sample size
    GN = round(sqrt(K)) + 1  # Approx Number of samples in each dimension
    # Support of polynomial vector space. 
    Lambda = support_gen(n, d)
    m  = length(Lambda)  # Dimension of vector space
    L2 = []
    ET = []

    # Generate the grid
    ChebyshevNodes = [cos((2i + 1) * π / (2*GN + 2)) for i in 0:GN]
    cart_cheb = [ChebyshevNodes for _ in 1:n]
    grid = Iterators.product(cart_cheb...) #cartesian product
   
    Pairs_chebyshev = collect(grid)
    matrix_from_grid = reduce(hcat, map(t -> collect(t), Pairs_chebyshev))' # Transpose the result of horizontal concatenation
    # print("size sample set:", size(matrix_from_grid))
    # print("\n")
    # print("pairs: ", matrix_from_grid[1:4, :])
    # print("\n")
    # Convert the collected tuples into a K x 2 matrix, each tuple becomes a row in the matrix
    # hcat([[ChebyshevNodes[i], ChebyshevNodes[j]] for i in 1:GN, j in 1:GN]...)

    # Generate the Vandermonde matrix
    VL = lambda_vandermonde(Lambda, matrix_from_grid)

    print(size(matrix_from_grid))

    # Generate Gram matrix
    G_original = VL' * VL
    # F = [tref(C * matrix_from_grid[i][1], C * matrix_from_grid[i][2]) for i in 1:GN^2]
    F = [tref(C*matrix_from_grid[Int(i), 1], C * matrix_from_grid[Int(i), 2]) for i in 1:(GN+1)^2]
    print("\n")
    print(size(F))
    print("\n")
    print([i for i in 0:3])
    # Scaled down to account for f being tough
    RHS = VL' * F

    # # Solve linear system
    st = time()
    cheb_ori = G_original \ RHS
    et = time() - st
    push!(ET, et)
    print(cheb_ori)
    # # Convert solution to rational
    rat_sol_cheb = convert.(Rational, cheb_ori)
    push!(L2, norm(VL * cheb_ori - F) / k)

    # println("Number of samples used: ", K)
    # println("Condition number of Gram:", cond(G_original))
end
