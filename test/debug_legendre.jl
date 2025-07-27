using Globtim
using DynamicPolynomials

# Test Legendre conversion
f = x -> sin(π*x[1]/2)
TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
pol_leg = Constructor(TR, 15, basis=:legendre, normalized=false)

println("Legendre polynomial L2-norm error: ", pol_leg.nrm)
println("pol_leg.normalized = ", pol_leg.normalized)

# Test polynomial evaluation before conversion
test_pts = [-1.0, 0.0, 0.5, 1.0]
println("\nTesting direct polynomial evaluation (should be very accurate):")
for pt in test_pts
    # Evaluate polynomial directly using SVector
    using StaticArrays
    pol_val = eval_approx_poly(pol_leg, SVector(pt))
    func_val = f([pt])
    error = abs(pol_val - func_val)
    println("Direct eval at pt=$pt: poly=$pol_val, func=$func_val, error=$error")
end

# Convert to monomial
@polyvar x
mono_poly_leg = to_exact_monomial_basis(pol_leg, variables=[x])

println("\nAfter conversion:")
for pt in test_pts
    poly_val = mono_poly_leg(pt)
    func_val = f([pt])
    error = abs(poly_val - func_val)
    println("Monomial at pt=$pt: poly=$poly_val, func=$func_val, error=$error")
end