using Globim

# Constants and Parameters
d1, d2, ds = 6, 8, 1  # Degree range and step
const n, a, b = 2, 3, 1
const C = a / b  # Scaling constant, C is appears in `main_computation`, maybe it should be a parameter.
const delta, alph = 0.5, 9 / 10  # Sampling parameters
const cntr = Vector([3.14, 3.14]) # Center of the domain
# const cntr = Vector(2*[-3.14, -3.14]) # Center of the domain
f = easom # Objective function

# Compute the coefficients of the polynomial approximation
coeffs_poly_approx = main_gen(f, n, d1, d2, ds, delta, alph, C, 0.1, center=cntr)
println(coeffs_poly_approx)