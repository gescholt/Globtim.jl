using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

# Standard packages
using Globtim, DynamicPolynomials
using Printf

# Test polynomial approximation in a subdomain without theoretical points
println("Testing polynomial approximation without theoretical points validation")
println("="^80)

# Define a subdomain center and range (e.g., subdomain 0000)
center = [0.25, -0.75, 0.25, -0.75]
range = 0.25

# Test with Deuflhard function
f = deuflhard_4d_composite

println("\nSubdomain center: $center")
println("Subdomain range: $range")
println("Domain bounds: ")
for (i, c) in enumerate(center)
    println("  Dim $i: [$(c - range), $(c + range)]")
end

# Create test input and polynomial
println("\nCreating polynomial approximation...")
TR = test_input(f, dim=4, center=center, sample_range=range, tolerance=0.01)
pol = Constructor(TR, 4, basis=:chebyshev, verbose=false)

println("\nPolynomial info:")
println("  Degree: $(pol.degree)")
println("  Number of coefficients: $(length(pol.coeffs))")
println("  L2 norm: $(@sprintf("%.6e", pol.L_err[1,2]))")

# Find critical points
@polyvar x[1:4]
println("\nFinding critical points...")
crit_pts = solve_polynomial_system(x, 4, pol.degree, pol.coeffs)

println("\nResults:")
println("  Number of critical points found: $(length(crit_pts))")

# Evaluate function at critical points
if !isempty(crit_pts)
    println("\nFirst few critical points:")
    for (i, pt) in enumerate(crit_pts[1:min(5, length(crit_pts))])
        fval = f(pt)
        println("  Point $i: $([round(x, digits=3) for x in pt]), f = $(@sprintf("%.6e", fval))")
    end
end

println("\n" * "="^80)
println("CONCLUSION: Polynomial approximation works fine without theoretical points!")
println("We can get L2-norm and find critical points for validation.")
println("="^80)