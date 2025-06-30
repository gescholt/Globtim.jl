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

df_enhanced, df_min = analyze_critical_points(f_quad, df, TR, enable_hessian=true, verbose=false)

println("Column names type: $(typeof(names(df_enhanced)))")
println("Column names: $(names(df_enhanced))")
println()

# Test different ways of checking for columns
col_name = :critical_point_type
println("Testing column: $col_name")
println("  Type of column name: $(typeof(col_name))")
println("  In names(): ", col_name in names(df_enhanced))
println("  String version in names(): ", "critical_point_type" in names(df_enhanced))
println("  Symbol version in names(): ", :critical_point_type in names(df_enhanced))
println("  Has column: $(hasproperty(df_enhanced, :critical_point_type))")

if hasproperty(df_enhanced, :critical_point_type)
    println("  Column data type: $(typeof(df_enhanced.critical_point_type))")
    println("  First few values: $(df_enhanced.critical_point_type)")
end

println()
println("All columns with their types:")
for (i, name) in enumerate(names(df_enhanced))
    println("  $i. $name ($(typeof(name)))")
end