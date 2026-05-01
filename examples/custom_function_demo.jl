# Custom Function Demo
# Demonstrates how to optimize user-defined objective functions with Globtim

using Globtim
using DynamicPolynomials
using DataFrames
using Printf

# 1. Define a custom objective function
# Must accept a vector x and return a scalar
function my_objective(x)
    return (x[1]^2 - 1)^2 + (x[2]^2 - 1)^2 + 0.1 * sin(10 * x[1] * x[2])
end

println("1. Custom function defined: f(x) = (x[1]^2 - 1)^2 + (x[2]^2 - 1)^2 + 0.1*sin(10*x[1]*x[2])")
println("   This function has 4 minima near (±1, ±1)")

# 2. Create test input specification
println("\n2. Setting up problem...")
TR = TestInput(my_objective, dim=2, center=[0.0, 0.0], sample_range=2.0)
println("   Domain: [-2, 2] × [-2, 2]")

# 3. Build polynomial approximation
println("\n3. Building polynomial approximation...")
pol = Constructor(TR, 10, precision=AdaptivePrecision)
println("   Degree: 10")
@printf("   L2-norm error: %.2e\n", pol.nrm)

# 4. Find critical points
println("\n4. Solving for critical points...")
@polyvar x[1:2]
solutions = solve_polynomial_system(x, pol)
df = process_crit_pts(solutions, my_objective, TR)
println("   Found $(nrow(df)) raw critical points")

# 5. Refine and classify
println("\n5. Refining and classifying critical points...")
df_enhanced, df_min = analyze_critical_points(
    my_objective, df, TR,
    enable_hessian=true,
    verbose=false
)

# 6. Display results
println("\n6. Results:")
println("   Total critical points: $(nrow(df_enhanced))")
println("   Local minima found: $(nrow(df_min))")

if nrow(df_min) > 0
    println("\n   Minima locations:")
    for i in 1:nrow(df_min)
        x1 = round(df_min[i, :x1], digits=4)
        x2 = round(df_min[i, :x2], digits=4)
        val = round(df_min[i, :value], digits=6)
        println("   [$i] ($x1, $x2) → f = $val")
    end
end

# 7. Summary
println("\n7. Summary:")
println("   - Custom functions must accept Vector and return scalar")
println("   - Higher polynomial degree improves approximation accuracy")
println("   - enable_hessian=true classifies critical point types")
