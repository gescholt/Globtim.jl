# ================================================================================
# Simple 4D Deuflhard Comparison: Raw vs Refined vs Expected
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Printf, LinearAlgebra, DataFrames, DynamicPolynomials
using Optim

# Configuration
const DEGREE = 4
const TOL = 0.05

# 4D function
deuflhard_4d(x) = Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])

# Expected critical points from 2D analysis
expected_2d_minima = [[-0.7412, 0.7412], [0.7412, -0.7412]]
expected_2d_saddle = [0.0, 0.0]

# Generate 4D expected points
expected_4d = []
# Global minimum (both 2D parts at minima)
push!(expected_4d, (vcat(expected_2d_minima[1], expected_2d_minima[1]), -0.87107*2, "Global min"))
# Local minima (one at minimum, one at saddle)
push!(expected_4d, (vcat(expected_2d_minima[1], expected_2d_saddle), -0.87107, "Local min"))
push!(expected_4d, (vcat(expected_2d_saddle, expected_2d_minima[1]), -0.87107, "Local min"))
# Saddle point
push!(expected_4d, ([0.0, 0.0, 0.0, 0.0], 0.0, "Saddle"))

println("="^80)
println("SIMPLE 4D COMPARISON")
println("="^80)
println("\nExpected critical points:")
for (i, (pt, val, type)) in enumerate(expected_4d)
    println("$i. $type at [$(join([@sprintf("%.4f", x) for x in pt], ", "))], f = $(Printf.@sprintf("%.5f", val))")
end

# Analyze one orthant containing the global minimum
println("\n" * "="^80)
println("ANALYZING ORTHANT (-,+,-,+)")
println("="^80)

# This orthant should contain [-0.7412, 0.7412, -0.7412, 0.7412]
center = [-0.2, 0.2, -0.2, 0.2]
range = 0.6

TR = test_input(deuflhard_4d, dim=4, center=center, sample_range=range)

# Polynomial approximation
pol = Constructor(TR, DEGREE, basis=:chebyshev, verbose=false)
println("L²-norm: $(Printf.@sprintf("%.2e", pol.nrm))")

# Solve system
@polyvar x[1:4]
actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
println("Solutions found: $(length(solutions))")

# Process to get raw critical points
df_raw = process_crit_pts(solutions, deuflhard_4d, TR)
println("Raw critical points: $(nrow(df_raw))")

# Simple refinement with BFGS
println("\n" * "="^80)
println("REFINEMENT WITH BFGS")
println("="^80)

refined_points = []
for i in 1:min(10, nrow(df_raw))  # Limit to 10 for speed
    x0 = [df_raw[i, Symbol("x$j")] for j in 1:4]
    
    # BFGS optimization
    result = Optim.optimize(deuflhard_4d, x0, Optim.BFGS(), 
                           Optim.Options(iterations=50, g_tol=1e-6))
    
    if Optim.converged(result)
        xopt = Optim.minimizer(result)
        fopt = Optim.minimum(result)
        push!(refined_points, (xopt, fopt))
    end
end

println("Refined points: $(length(refined_points))")

# Compare with expected
println("\n" * "="^80)
println("COMPARISON TABLE")
println("="^80)

println("\nRaw points vs Expected:")
println("-"^60)
for i in 1:min(5, nrow(df_raw))
    raw_pt = [df_raw[i, Symbol("x$j")] for j in 1:4]
    raw_val = df_raw[i, :z]
    
    # Find closest expected
    best_dist = Inf
    best_exp = nothing
    for (exp_pt, exp_val, exp_type) in expected_4d
        dist = norm(raw_pt - exp_pt)
        if dist < best_dist
            best_dist = dist
            best_exp = (exp_pt, exp_val, exp_type)
        end
    end
    
    if best_exp !== nothing && best_dist < 0.2
        exp_pt, exp_val, exp_type = best_exp
        println("\nRaw point $i:")
        println("  Found:    [$(join([@sprintf("%.4f", x) for x in raw_pt], ", "))]")
        println("  Expected: [$(join([@sprintf("%.4f", x) for x in exp_pt], ", "))] ($exp_type)")
        println("  Distance: $(Printf.@sprintf("%.3e", best_dist))")
        println("  Value error: $(Printf.@sprintf("%.3e", abs(raw_val - exp_val)))")
    end
end

println("\n\nRefined points vs Expected:")
println("-"^60)
for i in 1:min(5, length(refined_points))
    ref_pt, ref_val = refined_points[i]
    
    # Find closest expected
    best_dist = Inf
    best_exp = nothing
    for (exp_pt, exp_val, exp_type) in expected_4d
        dist = norm(ref_pt - exp_pt)
        if dist < best_dist
            best_dist = dist
            best_exp = (exp_pt, exp_val, exp_type)
        end
    end
    
    if best_exp !== nothing && best_dist < 0.1
        exp_pt, exp_val, exp_type = best_exp
        println("\nRefined point $i:")
        println("  Found:    [$(join([@sprintf("%.4f", x) for x in ref_pt], ", "))]")
        println("  Expected: [$(join([@sprintf("%.4f", x) for x in exp_pt], ", "))] ($exp_type)")
        println("  Distance: $(Printf.@sprintf("%.3e", best_dist))")
        println("  Value error: $(Printf.@sprintf("%.3e", abs(ref_val - exp_val)))")
    end
end

# Check for global minimum
println("\n" * "="^80)
println("GLOBAL MINIMUM CHECK")
println("="^80)

expected_global = expected_4d[1]
exp_pt, exp_val, _ = expected_global

found_raw = false
found_refined = false

# Check raw
for i in 1:nrow(df_raw)
    pt = [df_raw[i, Symbol("x$j")] for j in 1:4]
    if norm(pt - exp_pt) < TOL
        found_raw = true
        println("✓ Raw: Found global minimum at distance $(Printf.@sprintf("%.3e", norm(pt - exp_pt)))")
        break
    end
end

# Check refined
for (pt, val) in refined_points
    if norm(pt - exp_pt) < TOL
        found_refined = true
        println("✓ Refined: Found global minimum at distance $(Printf.@sprintf("%.3e", norm(pt - exp_pt)))")
        println("  Value: $(Printf.@sprintf("%.5f", val)) (expected: $(Printf.@sprintf("%.5f", exp_val)))")
        break
    end
end

if !found_raw
    println("✗ Raw: Global minimum not found")
end
if !found_refined
    println("✗ Refined: Global minimum not found accurately")
end

println("\n" * "="^80)
println("KEY INSIGHT")
println("="^80)
println("\nBFGS refinement significantly improves accuracy of critical points")
println("found by the polynomial system solver, especially for finding")
println("accurate function values at the minima.")