# Functions for homotopy continuation, to call when the HomotopyContinuation package is already loaded#

# return the symbolic approxiamnt with expanded chebyshev polynomials in variables 1 through n 
function generateApproximant(Lambda, rat_sol_cheb, coeff_type::Symbol)
    ## Important note, the @polyvar variables should not be defined inside the function but in the main execution file.
    m, n = size(Lambda)
    # m: dimension of polynomial vector space we project onto. 
    # n: number of variables

    ## Validate input sizes and consistency
    if isempty(Lambda)
        error("Lambda must not be empty")
    end

    ## Ensure the number of coefficients matches the number of polynomial terms
    if length(rat_sol_cheb) != m
        print("\n")
        error("The length of rat_sol_cheb must match the dimension of the space we project onto")
    end

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
        if coeff_type == :RationalBigInt
            S_rat += rationalize(BigInt, rat_sol_cheb[i]) * prd
        elseif coeff_type == :BigFloat
            S_rat += BigFloat(rat_sol_cheb[i]) * prd
        else
            error("Unsupported coefficient type. Use :RationalBigInt or :BigFloat.")
        end
    end
    return S_rat
end


# # Homotopy continuation solves the polynomial system over the reals.
# function RRsolve(n, p1, p2, p3)
#     p1_str = string(p1)
#     p2_str = string(p2)
#     p3_str = string(p3)
#     @var(x[1:n])
#     p1_converted = eval(Meta.parse(p1_str))
#     p2_converted = eval(Meta.parse(p2_str))
#     p3_converted = eval(Meta.parse(p3_str))
#     Z = System([p1_converted, p2_converted, p3_converted])
#     Real_sol_lstsq = HomotopyContinuation.solve(Z)
#     real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)
#     return real_pts
# end

# Generalized Homotopy continuation solver for polynomial systems over the reals
function RRsolve(n, polys)
    # Convert polynomial strings to symbolic expressions
    polys_converted = [eval(Meta.parse(string(p))) for p in polys]

    # Define the variables
    @polyvar x[1:n]

    # Construct the system
    Z = System(polys_converted)

    # Solve the system
    Real_sol_lstsq = HomotopyContinuation.solve(Z)

    # Extract the real solutions
    real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)

    return real_pts
end