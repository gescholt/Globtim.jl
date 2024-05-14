# main.jl
include("construct_lib.jl")
using DynamicPolynomials, MultivariatePolynomials, AlgebraicSolving, HomotopyContinuation


# Constants and Parameters
const d1, d2, ds = 2, 8, 1  # Degree range and step
const n, a, b = 2, 1, 3
const C = a / b  # Scaling constant
const delta, alph = 1 / 2, 9 / 10  # Sampling parameters

# Execute the computation
results = main_computation(n, d1, d2, ds)
sol = results[end][1]
lambda = support_gen(n, d2)[1]

# Compute the approximant 
@polyvar(x[1:n]) # Define polynomial ring 
R = generateApproximant(lambda, sol)


# Generate the system for homotopy HomotopyContinuation
P1 = differentiate(R, x[1])
P2 = differentiate(R, x[2])

# Prepare for HomotopyContinuation
p1_converted = mapcoefficients(rational_bigint_to_int, P1)
p2_converted = mapcoefficients(rational_bigint_to_int, P2)

# Solve homotopy continuation system with reduced rational fractions. 
@var(x[1:n]) # Define polynomial ring for HomotopyContinuation
# Z  = System([P1, P2])
Z  = System([p1_converted, p2_converted])

Real_sol_lstsq = HomotopyContinuation.solve(Z)
HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)
