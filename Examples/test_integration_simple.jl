# Simple test to verify Phase 2 integration

using Pkg
Pkg.activate(joinpath(@__DIR__, "../"))
using Globtim
using DynamicPolynomials
using DataFrames

println("=== Testing Phase 2 Integration ===")

# Simple quadratic function
f_quad(x) = (x[1] - 1)^2 + (x[2] + 0.5)^2

TR = test_input(f_quad, dim=2, center=[1.0, -0.5], sample_range=2.0)
pol = Constructor(TR, 6)
@polyvar x[1:2]
real_pts = solve_polynomial_system(x, 2, 6, pol.coeffs)
df = process_crit_pts(real_pts, f_quad, TR)

println("Original DataFrame columns: $(names(df))")
println("Number of critical points: $(nrow(df))")

# Test with Phase 2 enabled
println("\n=== Testing Phase 2 enabled ===")
df_enhanced, df_min = analyze_critical_points(f_quad, df, TR, enable_hessian=true, verbose=true)

println("\nEnhanced DataFrame columns: $(names(df_enhanced))")
println("Number of enhanced points: $(nrow(df_enhanced))")

# Check for Phase 2 columns
phase2_columns = [:critical_point_type, :smallest_positive_eigenval, :largest_negative_eigenval, 
                  :hessian_norm, :hessian_eigenvalue_min, :hessian_eigenvalue_max, 
                  :hessian_condition_number, :hessian_determinant, :hessian_trace]

for col in phase2_columns
    if col in names(df_enhanced)
        println("✓ Column $col found")
    else
        println("✗ Column $col MISSING")
    end
end

# Test with Phase 2 disabled
println("\n=== Testing Phase 2 disabled ===")
df_phase1, df_min_phase1 = analyze_critical_points(f_quad, df, TR, enable_hessian=false, verbose=true)

println("\nPhase 1 only DataFrame columns: $(names(df_phase1))")
println("Number of Phase 1 points: $(nrow(df_phase1))")

for col in phase2_columns
    if col in names(df_phase1)
        println("✗ Column $col found (should not be there)")
    else
        println("✓ Column $col not found (expected)")
    end
end

println("\n=== Classification Results ===")
if :critical_point_type in names(df_enhanced)
    println("Critical point classifications:")
    for (i, row) in enumerate(eachrow(df_enhanced))
        if i <= 5  # Show first 5 points
            println("  Point $i: ($(row.x1), $(row.x2)) -> $(row.critical_point_type)")
        end
    end
end

println("\n=== Test Complete ===")