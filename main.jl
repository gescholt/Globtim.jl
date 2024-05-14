# main.jl
include("construct_lib.jl")
using DynamicPolynomials, MultivariatePolynomials, AlgebraicSolving, HomotopyContinuation, JSON


# Constants and Parameters
const d1, d2, ds = 3, 8, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters

# Execute the computation
results = main_computation(n, d1, d2, ds)

@polyvar(x[1:n]) # Define polynomial ring 
# for (i, d) in enumerate(d1:ds:d2)
#     local locsol = results[i][1] #take coeff 
#     local lambda = support_gen(n, d)[1] #take support 
#     # Compute the approximant 
#     local R = generateApproximant(lambda, locsol)
#     # Generate the system for homotopy HomotopyContinuation
#     local P1 = differentiate(R, x[1])
#     local P2 = differentiate(R, x[2])
#     # Prepare for HomotopyContinuation
#     local p1_rat = mapcoefficients(rational_bigint_to_int, P1) #Move away from BigInt rational coefficients 
#     local p2_rat = mapcoefficients(rational_bigint_to_int, P2)

#     local S = RRsolve(n,p1_rat, p2_rat)
#     println("Homotopy real solutions at degree d=", d)
#     println(S)
# end



for (i, d) in enumerate(d1:ds:d2)
    local file_path_pts = expanduser("data/pts_rat_msolve_d$(d)_C_$(a)_$b.txt")
    local file_path_pol = expanduser("data/pol_rat_msolve_d$(d)_C_$(a)_$b.txt")

    # Read and parse the JSON files
    data_pts = read(file_path_pts, String)
    data_pol = read(file_path_pol, String)

    polynomial_expr = Meta.parse(data_pol)
    polynomial = eval(polynomial_expr)

    println("Homotopy real solutions at degree d=", polynomial)
    # println(S)
end