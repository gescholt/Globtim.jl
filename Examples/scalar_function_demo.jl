# Scalar Function Demo
# Demonstrates Globtim on 1D functions with scalar input (like sin, cos)

using Globtim
using DynamicPolynomials
using DataFrames
using Printf

println("1D Scalar Function Demo")
println("="^50)

# 1. Simple 1D function with scalar input
f1 = x -> sin(3x) + 0.1 * x^2

println("\n1. Function: f(x) = sin(3x) + 0.1*x²")
println("   Domain: [-π, π]")

TR1 = test_input(f1, dim=1, center=[0.0], sample_range=π)
pol1 = Constructor(TR1, 12)
@printf("   Polynomial degree: 12, L2-error: %.2e\n", pol1.nrm)

@polyvar x
solutions1 = solve_polynomial_system(x, pol1)
df1 = process_crit_pts(solutions1, f1, TR1)

println("\n   Critical points found: $(nrow(df1))")
println("   x-values:")
for i in 1:nrow(df1)
    x_val = round(df1.x1[i], digits=4)
    f_val = round(df1.z[i], digits=4)
    println("      x = $x_val → f(x) = $f_val")
end

# 2. Using built-in sin function
println("\n" * "="^50)
println("\n2. Built-in function: f(x) = sin(x)")
println("   Domain: [-2π, 2π]")

f2 = x -> sin(x)
TR2 = test_input(f2, dim=1, center=[0.0], sample_range=2π)
pol2 = Constructor(TR2, 15)
@printf("   Polynomial degree: 15, L2-error: %.2e\n", pol2.nrm)

@polyvar y
solutions2 = solve_polynomial_system(y, pol2)
df2 = process_crit_pts(solutions2, f2, TR2)

println("\n   Critical points (extrema of sin):")
for i in 1:nrow(df2)
    x_val = round(df2.x1[i], digits=4)
    f_val = round(df2.z[i], digits=4)
    type_str = abs(f_val) ≈ 1.0 ? (f_val > 0 ? "max" : "min") : "???"
    println("      x = $x_val → sin(x) = $f_val [$type_str]")
end

# 3. Runge function (challenging for polynomials)
println("\n" * "="^50)
println("\n3. Runge function: f(x) = 1/(1 + 25x²)")
println("   Domain: [-1, 1]")

f3 = x -> 1 / (1 + 25 * x^2)
TR3 = test_input(f3, dim=1, center=[0.0], sample_range=1.0)
pol3 = Constructor(TR3, 20)
@printf("   Polynomial degree: 20, L2-error: %.2e\n", pol3.nrm)

@polyvar z
solutions3 = solve_polynomial_system(z, pol3)
df3 = process_crit_pts(solutions3, f3, TR3)

println("\n   Critical points:")
for i in 1:nrow(df3)
    x_val = round(df3.x1[i], digits=4)
    f_val = round(df3.z[i], digits=4)
    println("      x = $x_val → f(x) = $f_val")
end
println("   (Runge function has single maximum at x=0)")

# Summary
println("\n" * "="^50)
println("Summary")
println("="^50)
println("   - 1D functions work with dim=1 and center=[0.0]")
println("   - Globtim auto-handles scalar vs vector input")
println("   - Higher degrees needed for oscillatory functions")
println("   - Runge function demonstrates polynomial approximation limits")
