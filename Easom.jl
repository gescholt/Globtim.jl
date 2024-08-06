using DynamicPolynomials
using HomotopyContinuation
using DataFrames
using Globtim
include("src/lib_func.jl")



@polyvar x[1:2] # Define the variables
f = easom # Define the function to be approximated (from lib_func.jl)
global d = 15           # Define the degree of the polynomial approximant
scale_factor = 3.0         # Define the scaling factor
tol_l2 = 5e-2    # Define the tolerance for the L2-norm


while true # Potential infinite loop
    global poly_approx = MainGenerate(f, 2, d, 0.5, 0.5, scale_factor, 0.2, center=Vector([3.14, 3.14])) # computes the approximant in Chebyshev basis
    if poly_approx.nrm < tol_l2
        println("attained the desired L2-norm: ", poly_approx.nrm)
        break
    else
        println("current L2-norm: ", poly_approx.nrm)
        global d += 1
    end
end


ap = main_2d(d, poly_approx.coeffs, x) # converts the approximant to the coefficients in the Lexicographic order  
# Convert the system to Float64 coefficients because problem with homotopy continuation
PolynomialApproximant = sum(Float64.(ap) .* MonomialVector(x, 0:d))
grad = differentiate.(PolynomialApproximant, x)
sys = System(grad)
Real_sol_lstsq = HomotopyContinuation.solve(sys)
real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)

# Should be standalone function
condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1
filtered_points = filter(condition, real_pts) # Filter points using the filter function

h_x = Float64[point[1] for point in filtered_points] # Initialize the x vector for critical points of approximant
h_y = Float64[point[2] for point in filtered_points] # Initialize the y vector
experimental_df = DataFrame(x=scale_factor * h_x, y=scale_factor * h_y)
println(experimental_df)

