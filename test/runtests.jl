using Test
using Globtim
using CSV
using DataFrames
using DynamicPolynomials
using HomotopyContinuation

# Constants and Parameters
const n, a, b = 2, 5, 1
const scale_factor = a / b 
center = [0.0, 0.0]

f = camel # Objective function
d = 6 # Initial Degree 

# Load the pre-computed critical points of the camel function
camel_file_path = "../data/camel_d6.csv"
# Read the CSV file and convert it to a DataFrame
camel_df = DataFrame(CSV.File(camel_file_path))

const eps = 1e-6 # Define the tolerance for the critical points
# Function to print a check mark and a message
function print_success_message(test_name)
    println("✔️ Critical point captured at tolerance: $test_name")
end


TR = test_input(f,
    dim=n,
    center=center,
    GN=60,
    sample_range=scale_factor,
    degree_max=12,
)
pol_cheb = Constructor(TR, d, basis=:chebyshev)
pol_lege = Constructor(TR, d, basis=:legendre)

@polyvar(x[1:n]) # Define polynomial ring 
# Chebyshev 
real_pts_cheb = solve_polynomial_system(x, n, d, pol_cheb.coeffs; basis=:chebyshev, bigint=true)
df_cheb = process_critical_points(real_pts_cheb, f, scale_factor)
# Legendre
real_pts_lege = solve_polynomial_system(x, n, d, pol_lege.coeffs; basis=:legendre, bigint=true)
df_lege = process_critical_points(real_pts_lege, f, scale_factor)

@testset "Globtim Tests" begin
    @test camel([3.0, 3.0]) == 405.9
    # Add more tests as needed

    # Test the camel function
    for x_known in eachrow(camel_df)
        x0 = [x_known.x, x_known.y]
        distances_cheb = [norm(x0 - [row2.x1, row2.x2]) for row2 in eachrow(df_cheb)]
        distances_lege = [norm(x0 - [row2.x1, row2.x2]) for row2 in eachrow(df_lege)]
        # Check the result using the `Test.Pass` type
        if minimum(distances_cheb) < eps
            @test true
            print_success_message(eps)
        end
        if minimum(distances_lege) < eps
            @test true
            print_success_message(eps)
        else
            @test false
        end
    end

end
