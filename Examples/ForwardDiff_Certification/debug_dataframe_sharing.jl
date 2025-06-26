using Pkg
Pkg.activate(joinpath(@__DIR__, "../"))
using Globtim
using DynamicPolynomials
using DataFrames

f_quad(x) = (x[1] - 1)^2 + (x[2] + 0.5)^2

# Create separate dataframes for each test
println("=== Creating first DataFrame ===")
TR1 = test_input(f_quad, dim=2, center=[1.0, -0.5], sample_range=2.0)
pol1 = Constructor(TR1, 6)
@polyvar x[1:2]
real_pts1 = solve_polynomial_system(x, 2, 6, pol1.coeffs)
df1 = process_crit_pts(real_pts1, f_quad, TR1)

println("Original df1 columns: $(names(df1))")

println("\n=== Testing enable_hessian=false ===")
df_phase1, df_min_phase1 = analyze_critical_points(f_quad, df1, TR1, enable_hessian=false, verbose=false)

println("After phase1 - df1 columns: $(names(df1))")
println("Phase 1 result columns: $(names(df_phase1))")

println("\n=== Creating second DataFrame ===")
TR2 = test_input(f_quad, dim=2, center=[1.0, -0.5], sample_range=2.0)
pol2 = Constructor(TR2, 6)
real_pts2 = solve_polynomial_system(x, 2, 6, pol2.coeffs)
df2 = process_crit_pts(real_pts2, f_quad, TR2)

println("Original df2 columns: $(names(df2))")

println("\n=== Testing enable_hessian=true ===")
df_phase2, df_min_phase2 = analyze_critical_points(f_quad, df2, TR2, enable_hessian=true, verbose=false)

println("After phase2 - df2 columns: $(names(df2))")
println("Phase 2 result columns: $(names(df_phase2))")

# Check if the first result was affected
println("\n=== Final check ===")
println("Final df1 columns: $(names(df1))")
println("Final df_phase1 columns: $(names(df_phase1))")

# Object identity check
println("\nObject identity check:")
println("df1 === df_phase1: $(df1 === df_phase1)")
println("df2 === df_phase2: $(df2 === df_phase2)")