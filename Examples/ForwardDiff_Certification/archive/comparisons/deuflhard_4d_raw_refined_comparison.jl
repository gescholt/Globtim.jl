# ================================================================================
# Raw vs Refined Comparison for 4D Deuflhard
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Printf, LinearAlgebra, DataFrames, DynamicPolynomials
using Optim

# 4D function
deuflhard_4d(x) = Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])

println("="^80)
println("RAW VS REFINED COMPARISON - 4D DEUFLHARD")
println("="^80)

# Expected critical points from 2D
# 2D has minima at (±0.7412, ∓0.7412) with value -0.87107
# 4D global minimum: both parts at minimum = -0.87107 * 2 = -1.74214
expected_global = [-0.7412, 0.7412, -0.7412, 0.7412]
expected_global_val = -1.74214

println("\nExpected global minimum:")
println("  Point: [$(join([@sprintf("%.4f", x) for x in expected_global], ", "))]")
println("  Value: $(Printf.@sprintf("%.5f", expected_global_val))")

# Analyze the orthant containing the global minimum
println("\n" * "="^80)
println("ANALYZING SINGLE ORTHANT")
println("="^80)

# Setup with fixed degree (no auto-increase)
center = [-0.3, 0.3, -0.3, 0.3]  # Shifted toward expected minimum
range = 0.5
degree = 5  # Fixed degree

TR = test_input(deuflhard_4d, dim=4, center=center, sample_range=range)

# Construct polynomial with fixed degree
pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
println("Degree: $actual_degree")
println("L²-norm: $(Printf.@sprintf("%.2e", pol.nrm))")

# Solve polynomial system
@polyvar x[1:4]
solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
println("Solutions found: $(length(solutions))")

# Get raw critical points
df_raw = process_crit_pts(solutions, deuflhard_4d, TR)
println("Raw critical points in domain: $(nrow(df_raw))")

# Show top 5 raw points
println("\n" * "="^80)
println("TOP 5 RAW CRITICAL POINTS")
println("="^80)

sort!(df_raw, :z)
for i in 1:min(5, nrow(df_raw))
    pt = [df_raw[i, Symbol("x$j")] for j in 1:4]
    val = df_raw[i, :z]
    dist = norm(pt - expected_global)
    
    println("\n$i. Point: [$(join([@sprintf("%.4f", x) for x in pt], ", "))]")
    println("   Value: $(Printf.@sprintf("%.5f", val))")
    println("   Distance from expected: $(Printf.@sprintf("%.3e", dist))")
end

# BFGS refinement
println("\n" * "="^80)
println("BFGS REFINEMENT")
println("="^80)

refined_results = []
for i in 1:min(10, nrow(df_raw))
    x0 = [df_raw[i, Symbol("x$j")] for j in 1:4]
    
    # Run BFGS
    result = Optim.optimize(deuflhard_4d, x0, Optim.BFGS(), 
                           Optim.Options(iterations=100, g_tol=1e-8))
    
    if Optim.converged(result)
        xopt = Optim.minimizer(result)
        fopt = Optim.minimum(result)
        push!(refined_results, (i, x0, xopt, fopt, df_raw[i, :z]))
    end
end

println("Successfully refined: $(length(refined_results)) points")

# Show improvements
println("\n" * "="^80)
println("IMPROVEMENT FROM RAW TO REFINED")
println("="^80)

for (idx, x0, xopt, fopt, f0) in refined_results[1:min(5, length(refined_results))]
    dist_before = norm(x0 - expected_global)
    dist_after = norm(xopt - expected_global)
    
    println("\nPoint $idx:")
    println("  Distance to expected: $(Printf.@sprintf("%.3e", dist_before)) → $(Printf.@sprintf("%.3e", dist_after))")
    println("  Function value: $(Printf.@sprintf("%.5f", f0)) → $(Printf.@sprintf("%.5f", fopt))")
    
    if dist_after < 0.01
        println("  ✓ CONVERGED to expected global minimum!")
    end
end

# Final check
println("\n" * "="^80)
println("FINAL ASSESSMENT")
println("="^80)

# Find best refined point
best_refined = nothing
best_dist = Inf
for (_, _, xopt, fopt, _) in refined_results
    dist = norm(xopt - expected_global)
    if dist < best_dist
        best_dist = dist
        best_refined = (xopt, fopt)
    end
end

if best_refined !== nothing && best_dist < 0.01
    xopt, fopt = best_refined
    println("✓ SUCCESS: Found global minimum after refinement")
    println("  Final point: [$(join([@sprintf("%.4f", x) for x in xopt], ", "))]")
    println("  Final value: $(Printf.@sprintf("%.5f", fopt))")
    println("  Error in point: $(Printf.@sprintf("%.3e", best_dist))")
    println("  Error in value: $(Printf.@sprintf("%.3e", abs(fopt - expected_global_val)))")
else
    println("✗ Global minimum not found accurately")
    if best_refined !== nothing
        println("  Best distance achieved: $(Printf.@sprintf("%.3e", best_dist))")
    end
end

println("\n" * "="^80)
println("CONCLUSION")
println("="^80)
println("\nThe polynomial system solver finds approximate critical points,")
println("but BFGS refinement is essential for achieving high accuracy,")
println("especially for locating global minima with precise function values.")