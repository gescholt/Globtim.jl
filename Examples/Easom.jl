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
@polyvar x[1:2]
# Assuming x is already defined as @polyvar x[1:2]
loc = "Examples/inputs.ms"
names = [x[i].name for i in 1:length(x)]
open(loc, "w") do file
    println(file, join(names, ", "))
    println(file, 0)
end

# Define the polynomial approximant 
PolynomialApproximant = sum(ap .* MonomialVector(x, 0:d))
for i in 1:2 
    partial = differentiate(PolynomialApproximant, x[i])
    open(loc, "a") do file
        println(file, string(partial, ","))
    end
end

run(`msolve -v 2 -f Examples/inputs.ms -o Examples/outputs.ms`)

# File path of the output file
file_path_output = "Examples/outputs.ms"

# Function to read and process the file
function process_output_file(file_path)
    # Read the file content
    content = read(file_path, String)
    println(content)
    # Extract the array starting from line 2
    array_start = findfirst(r"\[\[\[", content)[1]
    array_end   = findfirst(r"\]\]\]", content)[end]
    if array_start === nothing
        error("No array found starting from line 2.")
    end
    array_content = content[array_start:array_end]
    return array_content
end

# Process the file and get the points
array_content = process_output_file(file_path)

# Function to parse the interval and compute the middle point
function middle_of_interval(interval)
    num, denom = interval.split("/")
    num = parse(BigInt, num)
    denom = parse(Int, denom[2:end])  # Remove the leading '^' character
    return num / (2^denom)
end


# Function to parse the array content and compute the points
function parse_array_content(array_content)
    println("Array Content: ", array_content)  # Debugging line

    # Extract the list of intervals
    interval_pattern = r"\[\[([^\[\]]+)\]\]"
    match_result = match(interval_pattern, array_content)

    if match_result === nothing
        println("No intervals found in the array. Check the format of array_content.")
        error("No intervals found in the array.")
    end

    intervals = match_result.captures[1]
    println("Intervals: ", intervals)  # Debugging line

    # Split the intervals into individual elements
    interval_list = split(intervals, "], [")
    println("Interval List: ", interval_list)  # Debugging line

    # Compute the middle points for each interval
    points = []
    for interval in interval_list
        coords = split(interval, ", ")
        x = middle_of_interval(coords[1])
        y = middle_of_interval(coords[2])
        push!(points, (x, y))
    end

    return points
end

last_point = parse_array_content(array_content)


# Print the points
for point in points
    println("Point: ", point)
end

# println("coeff type:" , typeof(ap))
# # converts the polynomial approximant to the standard monomial basis in the Lexicographic order.
# # By default, the conversion is carried out over BigFloats, but it can be done over Rational numbers as well.

# #-------------------# Float64 coefficients #-------------------#
# """ redefine the variables x to be used in the DynamicPolynomials environment """



# # Convert the system to Float64 coefficients because problem with homotopy continuation
 # Convert coefficients to Float64 for homotopy continuation
# println("Polynomial L2 Approximant floats: ", PolynomialApproximant)
# grad = differentiate.(PolynomialApproximant, x)
# sys = System(grad)
# Real_sol_lstsq = HomotopyContinuation.solve(sys) # Solve the system of equations with Float64 coefficients

# real_pts = HomotopyContinuation.real_solutions(Real_sol_lstsq; only_real=true, multiple_results=false)

# # Sort throught the solutions and filter the points that are within the domain of the function.
# condition(point) = -1 < point[1] < 1 && -1 < point[2] < 1
# filtered_points = filter(condition, real_pts) # Filter points using the filter function

# h_x = Float64[point[1] for point in filtered_points] # Initialize the x vector for critical points of approximant
# h_y = Float64[point[2] for point in filtered_points] # Initialize the y vector
# experimental_df = DataFrame(x=scale_factor * h_x, y=scale_factor * h_y)

# #-------------------# BigFloat coefficients #-------------------#
# PolynomialApproximant_BF = sum(ap .* MonomialVector(x, 0:d))
# grad_BF = differentiate.(PolynomialApproximant_BF, x)
# sys_BF = System(grad_BF)

# Real_sol_lstsq_BF = HomotopyContinuation.solve(sys_BF; start_system=:total_degree) 
# # The method for solving the system of equations with BigFloat coefficients has to be switched to total degree.
# real_pts_BF = HomotopyContinuation.real_solutions(Real_sol_lstsq_BF; only_real=true, multiple_results=false)
# filtered_points_BF = filter(condition, real_pts_BF) # Filter points using the filter function

# h_x_BF = scale_factor * Float64[point[1] for point in filtered_points_BF] # Initialize the x vector for critical points of approximant
# h_y_BF = scale_factor * Float64[point[2] for point in filtered_points_BF] # Initialize the y vector
# BF_df = DataFrame(x= h_x_BF, y= h_y_BF)

# # CSV.write("easom_d$d.csv", BF_df)