# main.jl
include("construct_lib.jl")
using LinearSolve, DynamicPolynomials, MultivariatePolynomials


# Constants and Parameters
const d1, d2, ds = 2, 8, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters


function chebyshevMonomialExpansion(d, var)
    # Get the Chebyshev polynomial of the first kind of degree d
    T = ChebyshevT(d)

    # Convert the Chebyshev polynomial to a string expression in terms of 'var'
    # This involves substituting 'x' (default variable in SpecialPolynomials) with 'var'
    T_expanded = subs(T, x => var)

    return T_expanded
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

    @polyvar(x[1:n])     # Dynamically create symbolic variables based on n
    S_rat = 0 *x[1]      # Initialize the sum S_rat

    # Iterate over each index of Lambda and rat_sol_cheb using only the length of rat_sol_cheb
    for i in 1:m # for each term of the orthonormal basis.        
        prd = 1 + 0 * x[1] # Initialize product prd for each i
        # Loop over each variable index in the row
        for j in 1:n
            # Multiply prd by the Chebyshev polynomial T evaluated at vars[j]
            print("\n")
            print("variable:", x[j])
            print("\n")
            prd *= chebyshev_poly(Lambda[i, j], x[j])
        end

        # Add the product scaled by the corresponding rational solution coefficient to S_rat
        S_rat += rat_sol_cheb[i] * prd
    end

    return S_rat
end

# Execute the computation
results = main_computation(n, d1, d2, ds)
sol = results[1][1]
lambda = support_gen(n, d1)[1]
print(size(sol)[1])
print("\n")
print("Lambda:", lambda)
print("\n")
print(first(lambda))
print("\n")
R = generateApproximant(lambda, sol)

print(R)