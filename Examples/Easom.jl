using DynamicPolynomials
using HomotopyContinuation
using DataFrames
using CSV
using Globtim
include("../src/lib_func.jl")



# @polyvar x[1:2] # Define the variables
f = easom # Define the function to be approximated (from lib_func.jl)
global d = 3 #15           # Define the degree of the polynomial approximant
scale_factor = 3.0         # Define the scaling factor
tol_l2 = 2

# 5e-2    # Define the tolerance for the L2-norm


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

ap = expansion_main_2d(d, poly_approx.coeffs) 
println("coeff type:" , typeof(ap))
# converts the polynomial approximant to the standard monomial basis in the Lexicographic order.
# By default, the conversion is carried out over BigFloats, but it can be done over Rational numbers as well.

#-------------------# Float64 coefficients #-------------------#
""" redefine the variables x to be used in the DynamicPolynomials environment """

@polyvar x[1:2]

# Convert the system to Float64 coefficients because problem with homotopy continuation
PolynomialApproximant = sum(Float64.(ap) .* MonomialVector(x, 0:d)) # Convert coefficients to Float64 for homotopy continuation
println("Polynomial L2 Approximant floats: ", PolynomialApproximant)
grad = differentiate.(PolynomialApproximant, x)
sys = System(grad)
Real_sol_lstsq = HomotopyContinuation.solve(sys) # Solve the system of equations with Float64 coefficients

real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)

# Sort throught the solutions and filter the points that are within the domain of the function.
condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1
filtered_points = filter(condition, real_pts) # Filter points using the filter function

h_x = Float64[point[1] for point in filtered_points] # Initialize the x vector for critical points of approximant
h_y = Float64[point[2] for point in filtered_points] # Initialize the y vector
experimental_df = DataFrame(x=scale_factor * h_x, y=scale_factor * h_y)

#-------------------# BigFloat coefficients #-------------------#
PolynomialApproximant_BF = sum(ap .* MonomialVector(x, 0:d))
grad_BF = differentiate.(PolynomialApproximant_BF, x)
sys_BF = System(grad_BF)

Real_sol_lstsq_BF = HomotopyContinuation.solve(sys_BF; start_system=:total_degree) 
# The method for solving the system of equations with BigFloat coefficients has to be switched to total degree.
real_pts_BF = HomotopyContinuation.real_solutions(Real_sol_lstsq_BF; only_real=true, multiple_results=false)
filtered_points_BF = filter(condition, real_pts_BF) # Filter points using the filter function

h_x_BF = scale_factor * Float64[point[1] for point in filtered_points_BF] # Initialize the x vector for critical points of approximant
h_y_BF = scale_factor * Float64[point[2] for point in filtered_points_BF] # Initialize the y vector
BF_df = DataFrame(x= h_x_BF, y= h_y_BF)

# CSV.write("easom_d$d.csv", BF_df)