# main.jl
include("construct_lib.jl")
using LinearSolve, DynamicPolynomials, MultivariatePolynomials


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

P1 = differentiate(R, x[1])
P2 = differentiate(R, x[2])

print(P1)