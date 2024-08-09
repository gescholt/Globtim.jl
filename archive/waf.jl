using HomotopyContinuation
# using DynamicPolynomials
using Random

# Set random seed 
Random.seed!(1874)

# @polyvar x[1:2]
@var x[1:2]

# Function to generate a random polynomial with BigFloat coefficients
function random_polynomial(variables, degree::Int, num_terms::Int)
    polynomial = zero(BigFloat) # Initialize the polynomial with a BigFloat zero
    for _ in 1:num_terms
        coeff = BigFloat(rand(-10.0:0.1:10.0))
        powers = rand(0:degree, length(variables))
        monomial = prod(v^p for (v, p) in zip(variables, powers))
        polynomial += coeff * monomial
    end
    return polynomial
end

# Generate two random polynomials of degree 2 with 5 terms each
poly1 = random_polynomial(x, 4, 10) 
poly2 = poly1 + BigFloat(1.0) * x[1] + BigFloat(1.0) * x[2]
grad_p1 = differentiate.(poly1, x)
grad_p2 = differentiate.(poly2, x)


dump(poly1)
dump(poly2)
dump(grad_p1)
dump(grad_p2)
# Define the system of equations
system_1 = System(grad_p1)
system_2 = System(grad_p2)

# poly1 = random_polynomial(x, 4, 10)
# poly2 = random_polynomial(x, 4, 10)
# poly3 = poly2 + BigFloat(8.0) 
# system_1 = System([poly1, poly2])
# system_2 = System([poly1, poly3])

# Solve the system
R1 = HomotopyContinuation.solve(system_1)
println("Result: ", R1)
# R2 = HomotopyContinuation.solve(system_2)
R2 = HomotopyContinuation.solve(system_2; start_system=:total_degree)
println("Result: ", R2)

# R1 = HomotopyContinuation.solve(system_1)


# R2 = HomotopyContinuation.solve(system_2)
