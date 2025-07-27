using Globtim
using DynamicPolynomials

# Simple 1D test
f = x -> x[1]^2
TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
pol = Constructor(TR, 4, basis = :chebyshev)

println("Polynomial L2-norm error: ", pol.nrm)
println("Polynomial coefficients: ", pol.coeffs)

# Convert to monomial
@polyvar x
mono_poly = to_exact_monomial_basis(pol, variables = [x])

println("\nMonomial polynomial: ", mono_poly)

# Test evaluation
test_pts = [-1.0, 0.0, 0.5, 1.0]
for pt in test_pts
    poly_val = mono_poly(pt)
    func_val = f([pt])
    error = abs(poly_val - func_val)
    println("pt=$pt: poly=$poly_val, func=$func_val, error=$error")
end

# Check if the domain is the issue
println("\nTR.sample_range = ", TR.sample_range)
println("TR.center = ", TR.center)
println("pol.scale_factor = ", pol.scale_factor)
println("pol fields: ", fieldnames(typeof(pol)))
# Check if pol has normalized field
if hasproperty(pol, :normalized)
    println("pol.normalized = ", pol.normalized)
end
