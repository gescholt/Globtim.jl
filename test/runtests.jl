using Globtim
using Test
# using LinearAlgebra
using CSV
using DataFrames
using DynamicPolynomials
using HomotopyContinuation

# Function to print a check mark and a message
function print_success_message(test_name)
    println("✔️ Critical point captured at tolerance: $test_name")
end

# Load the pre-computed critical points of the camel function
camel_file_path = "../data/camel_d6.csv"  
# Read the CSV file and convert it to a DataFrame
camel_df = DataFrame(CSV.File(camel_file_path))
# Call the function to be approximated, stred in lib_func.jl
f = camel

# Example test cases for functions in Globtim
n = 2 
@polyvar x[1:n] # Define the variables
d = 6           # Define the degree of the polynomial approximant
C = 5.0         # Define the scaling factor


poly_approx = MainGenerate(f, n, d, 0.5, 0.8, C, 0.2) # computes the approximant in Chebyshev basis
ap = main_nd(n, d, poly_approx.coeffs)
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
experimental_df = DataFrame(x=C * h_x, y=C * h_y)
println(experimental_df)
# set a tolerance for the test
eps = 1e-6

@testset "Globtim Tests" begin
    @test camel([3.0, 3.0]) == 405.9
    # Add more tests as needed

    # Test the camel function
    for x_known in eachrow(camel_df)
        x0 = [x_known.x, x_known.y]
        distances = [norm(x0 - [row2.x, row2.y]) for row2 in eachrow(experimental_df)]
        # Check the result using the `Test.Pass` type
        if minimum(distances) < eps
            @test true
            print_success_message(eps)
        else
            @test false
        end
    end

end