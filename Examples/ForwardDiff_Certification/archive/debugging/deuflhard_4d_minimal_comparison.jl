# Minimal comparison: Raw vs Refined for 4D Deuflhard

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim, Printf, LinearAlgebra, DataFrames, DynamicPolynomials, Optim

# 4D function and expected minimum
deuflhard_4d(x) = Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
expected_min = [-0.7412, 0.7412, -0.7412, 0.7412]
expected_val = -1.74214

println("="^60)
println("MINIMAL COMPARISON: RAW vs REFINED")
println("="^60)

# Small domain around expected minimum
TR = test_input(deuflhard_4d, dim=4, center=expected_min, sample_range=0.3)

# Use whatever degree it gives us
pol = Constructor(TR, 4, basis=:chebyshev, verbose=false)
degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
println("\nActual degree used: $degree")
println("L²-norm: $(Printf.@sprintf("%.2e", pol.nrm))")

# Solve system
@polyvar x[1:4]
solutions = solve_polynomial_system(x, 4, degree, pol.coeffs, basis=:chebyshev)
df_raw = process_crit_pts(solutions, deuflhard_4d, TR)
println("Raw critical points: $(nrow(df_raw))")

# Find closest raw point to expected
min_dist_raw = Inf
best_raw_idx = 1
for i in 1:nrow(df_raw)
    pt = [df_raw[i, Symbol("x$j")] for j in 1:4]
    dist = norm(pt - expected_min)
    if dist < min_dist_raw
        min_dist_raw = dist
        best_raw_idx = i
    end
end

raw_pt = [df_raw[best_raw_idx, Symbol("x$j")] for j in 1:4]
raw_val = df_raw[best_raw_idx, :z]

println("\n" * "-"^60)
println("RAW (closest to expected):")
println("  Point: [$(join([@sprintf("%.4f", x) for x in raw_pt], ", "))]")
println("  Value: $(Printf.@sprintf("%.5f", raw_val))")
println("  Distance: $(Printf.@sprintf("%.3e", min_dist_raw))")
println("  Value error: $(Printf.@sprintf("%.3e", abs(raw_val - expected_val)))")

# BFGS refinement
result = Optim.optimize(deuflhard_4d, raw_pt, Optim.BFGS())
ref_pt = Optim.minimizer(result)
ref_val = Optim.minimum(result)

println("\n" * "-"^60)
println("REFINED (after BFGS):")
println("  Point: [$(join([@sprintf("%.4f", x) for x in ref_pt], ", "))]")
println("  Value: $(Printf.@sprintf("%.5f", ref_val))")
println("  Distance: $(Printf.@sprintf("%.3e", norm(ref_pt - expected_min)))")
println("  Value error: $(Printf.@sprintf("%.3e", abs(ref_val - expected_val)))")

println("\n" * "="^60)
println("IMPROVEMENT FACTOR:")
println("  Position: $(Printf.@sprintf("%.1f", min_dist_raw / norm(ref_pt - expected_min)))x")
println("  Value: $(Printf.@sprintf("%.1f", abs(raw_val - expected_val) / abs(ref_val - expected_val)))x")
println("="^60)