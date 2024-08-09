# Functions for homotopy continuation, to call when the HomotopyContinuation package is already loaded#
# The variables x[1], x[2], ... must be defined in the main execution file.


# return the symbolic approxiamnt with expanded chebyshev polynomials in variables x[1], ...,  x[n] 
function generateApproximant(vars, Lambda, rat_sol_cheb, coeff_type::Symbol)
    m, n = size(Lambda)
    # m: dimension of polynomial vector space we project onto. 
    # n: number of variables
    if isempty(Lambda)  ## Validate input sizes and consistency
        error("Lambda must not be empty")
    end

    ## Ensure the number of coefficients matches the number of polynomial terms
    if length(rat_sol_cheb) != m
        print("\n")
        error("The length of rat_sol_cheb must match the dimension of the space we project onto")
    end

    S_rat = zero(x[1])
    # Initialize the sum S_rat, this is hacky and should be fixed ... 
    # Iterate over each index of Lambda and rat_sol_cheb using only the length of rat_sol_cheb
    for i in 1:m # for each term of the orthonormal basis.        
        prd = zero(x[1]) # Initialize product prd for each i
        # Loop over each variable index in the row
        for j in 1:n
            # Multiply prd by the Chebyshev polynomial T evaluated at x[j]
            prd *= chebyshev_poly(Lambda[i, j], vars[j])
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

# Generalized Homotopy continuation solver for polynomial systems over the reals
function RRsolve(polys)
    @polyvar(x[1:2])
    # Convert polynomial strings to symbolic expressions
    polys_converted = [eval(Meta.parse(string(p))) for p in polys]
    # Construct the system
    # Z = System(polys, variables=[x[1:2]])
    Z = System(polys_converted, variables=x)
    # Solve the system
    Real_sol_lstsq = HomotopyContinuation.solve(Z)
    # Extract the real solutions
    real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)

    return real_pts
end


# The type of coefficients has changed, now it is a NamedTuple
function main_2d(d1::Int, d2::Int, ds::Int, coeffs_poly_approx::Vector{Vector{Float64}}, coeff_type=:BigFloat)
    @var(x[1:2])
    vars = x[1:2]
    h_x = Float64[]
    h_y = Float64[]
    col = Int[]  # Initialize the color vector

    for (i, d) in enumerate(d1:ds:d2)
        lambda = support_gen(2, d)[1] # Take support
        m, n = size(lambda)
        # m: dimension of polynomial vector space we project onto. 
        # n: number of variables
        coeffs = convert.(BigFloat, coeffs_poly_approx[i])
        ## Ensure the number of coefficients matches the number of polynomial terms
        if length(coeffs) != m
            println(coeffs)
            print("\n")
            error("The length of coeffs_poly_approx must match the dimension of the space we project onto")
        end

        S_rat = zero(x[1])
        # Initialize the sum S_rat, this is hacky and should be fixed ... 
        # Iterate over each index of Lambda and coeffs_poly_approx using only the length of coeffs_poly_approx
        for j in 1:m # for each term of the orthonormal basis.        
            prd = one(x[1]) # Initialize product prd for each i
            # Loop over each variable index in the row
            for k in 1:n
                # Multiply prd by the Chebyshev polynomial T evaluated at x[j]
                prd *= Bf_chebyshev_poly(lambda[j, k], vars[k]) # Now the coefficients of the Chebyshev poly are also BigFloats
            end
            # Add the product scaled by the corresponding rational solution coefficient to S_rat
            if coeff_type == :RationalBigInt
                S_rat += rationalize(BigInt, coeffs[j]) * prd
            elseif coeff_type == :BigFloat
                S_rat += coeffs[j] * prd
            else
                error("Unsupported coefficient type. Use :RationalBigInt or :BigFloat.")
            end
        end
        S_rat = expand(S_rat) 
        grad_p = collect(differentiate.(S_rat, (x[1], x[2])))
        println(typeof(grad_p))
        # real_pts = RRsolve(grad_p)
        # Z = System(grad_p)         # Generate the system for HomotopyContinuation
        # println(typeof(Z))
        # # Solve the system
        Real_sol_lstsq = HomotopyContinuation.solve([grad_p])
        # # Extract the real solutions
        real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)

        # real_pts = RRsolve(grad_p)
        
        condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1
        filtered_points = filter(condition, real_pts) # Filter points using the filter function

        append!(h_x, [point[1] for point in filtered_points]) # For plotting
        append!(h_y, [point[2] for point in filtered_points])
        append!(col, fill(d, length(filtered_points)))
    end

    return h_x, h_y, col
end


# function main_3d(n::Int, d1::Int, d2::Int, ds::Int, coeffs_poly_approx::Vector{Vector{Float64}})

#     h_x = Float64[]
#     h_y = Float64[]
#     h_z = Float64[]
#     col = Int[]  # Initialize the color vector

#     for (i, d) in enumerate(d1:ds:d2)
#         lambda = support_gen(n, d)[1] # Take support
#         R = generateApproximant(lambda, coeffs_poly_approx[i], :BigFloat) # Compute the approximant

#         # Generate the system for HomotopyContinuation
#         P1 = differentiate(R, x[1])
#         P2 = differentiate(R, x[2])
#         P3 = differentiate(R, x[3])

#         S = RRsolve([P1, P2, P3]) # HomotopyContinuation

#         # Define the condition for filtering
#         condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1 && -1 < point[3] < 1

#         # Filter points using the filter function
#         filtered_points = filter(condition, S)
#         println("Degree: ", d)
#         println("Number of solutions: ", length(filtered_points))

#         append!(h_x, [point[1] for point in filtered_points]) # For plotting
#         append!(h_y, [point[2] for point in filtered_points])
#         append!(h_z, [point[3] for point in filtered_points])
#         append!(col, fill(d, length(filtered_points)))
#     end

#     return h_x, h_y, h_z, col
# end

# function main_4d(n::Int, d1::Int, d2::Int, ds::Int, coeffs_poly_approx::Vector{Vector{Float64}})

#     h_x = Float64[]
#     h_y = Float64[]
#     h_z = Float64[]
#     h_t = Float64[]
#     col = Int[]  # Initialize the color vector

#     for (i, d) in enumerate(d1:ds:d2)
#         lambda = support_gen(n, d)[1] # Take support
#         R = generateApproximant(lambda, coeffs_poly_approx[i], :BigFloat) # Compute the approximant

#         # Generate the system for HomotopyContinuation
#         P1 = differentiate(R, x[1])
#         P2 = differentiate(R, x[2])
#         P3 = differentiate(R, x[3])
#         P4 = differentiate(R, x[4])

#         S = RRsolve([P1, P2, P3, P4]) # HomotopyContinuation

#         # Define the condition for filtering
#         condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1 && -1 < point[3] < 1 && -1 < point[4] < 1

#         # Filter points using the filter function
#         filtered_points = filter(condition, S)
#         println("Degree: ", d)
#         println("Number of solutions: ", length(filtered_points))

#         append!(h_x, [point[1] for point in filtered_points]) # For plotting
#         append!(h_y, [point[2] for point in filtered_points])
#         append!(h_z, [point[3] for point in filtered_points])
#         append!(h_t, [point[4] for point in filtered_points])
#         append!(col, fill(d, length(filtered_points)))
#     end

#     return h_x, h_y, h_z, h_t, col
# end
