using Pkg
Pkg.activate(joinpath(@__DIR__, "../"))
using Globtim
using DynamicPolynomials
using DataFrames

f_quad(x) = (x[1] - 1)^2 + (x[2] + 0.5)^2

TR = test_input(f_quad, dim=2, center=[1.0, -0.5], sample_range=2.0)
pol = Constructor(TR, 6)
@polyvar x[1:2]
real_pts = solve_polynomial_system(x, 2, 6, pol.coeffs)
df = process_crit_pts(real_pts, f_quad, TR)

println("=== Testing enable_hessian=false ===")
df_phase1, df_min_phase1 = analyze_critical_points(f_quad, df, TR, enable_hessian=false, verbose=true)

println("\nPhase 1 DataFrame columns:")
for (i, name) in enumerate(names(df_phase1))
    println("  $i. $name")
end

println("\n=== Testing enable_hessian=true ===")
df_phase2, df_min_phase2 = analyze_critical_points(f_quad, df, TR, enable_hessian=true, verbose=true)

println("\nPhase 2 DataFrame columns:")
for (i, name) in enumerate(names(df_phase2))
    println("  $i. $name")
end

# Check if Phase 2 columns are in Phase 1 result
phase2_cols = ["critical_point_type", "hessian_norm", "smallest_positive_eigenval"]
println("\n=== Phase 2 column check in Phase 1 result ===")
for col in phase2_cols
    present = col in names(df_phase1)
    println("  $col: $present")
end