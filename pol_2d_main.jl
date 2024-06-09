# pol2dmain.jl
include("construct_lib.jl")
include("functions_eval.jl")
using DynamicPolynomials, MultivariatePolynomials, HomotopyContinuation, JSON


# Constants and Parameters
const d1, d2, ds = 2, 8, 1  # Degree range and step
const n, a, b = 2, 1, 1
const C = a / b  # Scaling constant
const delta, alph = 1/2, 6 / 10  # Sampling parameters


# Compute the critical points of the original

# Execute the computation of coefficients of approximant, for each degree.
results = main_computation(f26d, n, d1, d2, ds)


@polyvar(x[1:n]) # Define polynomial ring 


for (i, d) in enumerate(d1:ds:d2)

    local lambda = support_gen(n, d)[1] #take support  
    local R = generateApproximant(lambda, results[i], :BigFloat) # Compute the approximant
    # Generate the system for homotopy HomotopyContinuation
    local P1 = differentiate(R, x[1])
    local P2 = differentiate(R, x[2])
    local S = RRsolve(n, P1, P2) # HomotopyContinuation

    # Define the condition for filtering
    condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1

    # Filter points using the filter function
    filtered_points = filter(condition, S)
    h_x = [point[1] for point in filtered_points] # for plotting
    h_y = [point[2] for point in filtered_points]

    # Plot the data
    plot_data([[],[]], h_x, h_y, "Degree $(d)")

end


