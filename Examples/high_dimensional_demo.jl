# High-Dimensional Optimization Demo
# Demonstrates Globtim on 3D and 4D problems

using Globtim
using DynamicPolynomials
using DataFrames
using Printf

# 1. 3D Rastrigin function
println("1. 3D Rastrigin Function")
println("="^50)

f_3d = Rastrigin
TR_3d = TestInput(f_3d, dim=3, center=zeros(3), sample_range=2.0)
println("   Domain: [-2, 2]³")

println("\n2. Building 3D polynomial approximation...")
pol_3d = Constructor(TR_3d, 6, precision=AdaptivePrecision)
@printf("   Degree: 6, L2-norm error: %.2e\n", pol_3d.nrm)

println("\n3. Finding 3D critical points...")
@polyvar x[1:3]
solutions_3d = solve_polynomial_system(x, pol_3d)
df_3d = process_crit_pts(solutions_3d, f_3d, TR_3d)
println("   Raw critical points: $(nrow(df_3d))")

println("\n4. Refining 3D results (Hessian disabled for speed)...")
df_enhanced_3d, df_min_3d = analyze_critical_points(
    f_3d, df_3d, TR_3d,
    enable_hessian=false,
    verbose=false
)
println("   Local minima found: $(nrow(df_min_3d))")

# 2. 4D example with custom function
println("\n" * "="^50)
println("5. 4D Custom Function")
println("="^50)

f_4d = x -> sum(x.^2) + 0.1 * prod(sin.(5 * pi .* x))
TR_4d = TestInput(f_4d, dim=4, center=zeros(4), sample_range=1.0)
println("   f(x) = sum(x^2) + 0.1*prod(sin(5π*x))")
println("   Domain: [-1, 1]⁴")

println("\n6. Building 4D polynomial approximation...")
pol_4d = Constructor(TR_4d, 4, precision=AdaptivePrecision)
@printf("   Degree: 4, L2-norm error: %.2e\n", pol_4d.nrm)
println("   Note: Lower degree used in 4D due to term count explosion")

println("\n7. Finding 4D critical points...")
@polyvar y[1:4]
solutions_4d = solve_polynomial_system(y, pol_4d)
df_4d = process_crit_pts(solutions_4d, f_4d, TR_4d)
println("   Raw critical points: $(nrow(df_4d))")

println("\n8. Refining 4D results...")
df_enhanced_4d, df_min_4d = analyze_critical_points(
    f_4d, df_4d, TR_4d,
    enable_hessian=false,
    verbose=false
)
println("   Local minima found: $(nrow(df_min_4d))")

# Summary
println("\n" * "="^50)
println("Summary")
println("="^50)
println("   3D problem: $(nrow(df_min_3d)) minima (degree 6)")
println("   4D problem: $(nrow(df_min_4d)) minima (degree 4)")
println("\nTips for high-dimensional problems:")
println("   - Use AdaptivePrecision for accuracy/performance balance")
println("   - Reduce polynomial degree as dimension increases")
println("   - Disable Hessian analysis for faster results")
println("   - Consider sparsification for large polynomials")
