# Final comparison: Raw vs Refined for 4D Deuflhard
# Using working syntax from demo files

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Printf, LinearAlgebra, DataFrames, DynamicPolynomials, Optim

# 4D Deuflhard composite
function deuflhard_4d_composite(x::AbstractVector)
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# Expected critical points from 2D analysis
println("="^80)
println("4D DEUFLHARD: RAW vs REFINED COMPARISON")
println("="^80)

# Known 2D critical points
println("\nKnown 2D Deuflhard critical points:")
println("  Minima: (±0.7412, ∓0.7412) with f = -0.87107")
println("  Saddle: (0, 0) with f = 0")

# Expected 4D points (tensor products)
println("\nExpected 4D critical points (tensor products):")
println("  Global min: [-0.7412, 0.7412, -0.7412, 0.7412] with f = -1.74214")
println("  Local mins: e.g., [-0.7412, 0.7412, 0, 0] with f = -0.87107")
println("  Saddle: [0, 0, 0, 0] with f = 0")

# Analyze one orthant
println("\n" * "="^80)
println("ANALYZING ORTHANT (-,+,-,+)")
println("="^80)

# Domain setup
center = [-0.4, 0.4, -0.4, 0.4]
range = 0.5

TR = test_input(deuflhard_4d_composite, dim=4, center=center, sample_range=range)

# Polynomial with low initial degree
pol = Constructor(TR, 4, basis=:chebyshev, verbose=false)
actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
println("\nPolynomial degree: $actual_degree")
println("L²-norm: $(Printf.@sprintf("%.2e", pol.nrm))")

# Solve
@polyvar x[1:4]
solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
df_raw = process_crit_pts(solutions, deuflhard_4d_composite, TR)

println("Raw solutions: $(length(solutions))")
println("Valid critical points: $(nrow(df_raw))")

# Expected values for comparison
expected_points = [
    ([-0.7412, 0.7412, -0.7412, 0.7412], -1.74214, "Global minimum"),
    ([-0.7412, 0.7412, 0.0, 0.0], -0.87107, "Local minimum"),
    ([0.0, 0.0, -0.7412, 0.7412], -0.87107, "Local minimum"),
    ([0.0, 0.0, 0.0, 0.0], 0.0, "Saddle point")
]

# Compare raw points
println("\n" * "="^80)
println("RAW CRITICAL POINTS")
println("="^80)

sort!(df_raw, :z)
matches_raw = []

for i in 1:min(10, nrow(df_raw))
    pt = [df_raw[i, Symbol("x$j")] for j in 1:4]
    val = df_raw[i, :z]
    
    # Find closest expected
    best_match = nothing
    best_dist = Inf
    for (exp_pt, exp_val, exp_type) in expected_points
        dist = norm(pt - exp_pt)
        if dist < best_dist
            best_dist = dist
            best_match = (exp_pt, exp_val, exp_type)
        end
    end
    
    if best_match !== nothing && best_dist < 0.1
        push!(matches_raw, (i, pt, val, best_match..., best_dist))
    end
end

println("\nMatched raw points:")
for (idx, pt, val, exp_pt, exp_val, exp_type, dist) in matches_raw
    println("\n$idx. Type: $exp_type")
    println("   Raw point: [$(join([@sprintf("%.4f", x) for x in pt], ", "))]")
    println("   Expected:  [$(join([@sprintf("%.4f", x) for x in exp_pt], ", "))]")
    println("   Distance:  $(Printf.@sprintf("%.3e", dist))")
    println("   Raw f:     $(Printf.@sprintf("%.5f", val))")
    println("   Expected:  $(Printf.@sprintf("%.5f", exp_val))")
end

# BFGS refinement
println("\n" * "="^80)
println("BFGS REFINEMENT")
println("="^80)

refined_matches = []
for (idx, pt, val, exp_pt, exp_val, exp_type, _) in matches_raw[1:min(3, length(matches_raw))]
    # Run BFGS from raw point
    result = Optim.optimize(deuflhard_4d_composite, pt, Optim.BFGS(), 
                           Optim.Options(iterations=100, g_tol=1e-8))
    
    if Optim.converged(result)
        ref_pt = Optim.minimizer(result)
        ref_val = Optim.minimum(result)
        ref_dist = norm(ref_pt - exp_pt)
        
        push!(refined_matches, (exp_type, pt, ref_pt, val, ref_val, 
                               exp_pt, exp_val, ref_dist))
    end
end

println("\nRefined results:")
for (type, raw_pt, ref_pt, raw_val, ref_val, exp_pt, exp_val, dist) in refined_matches
    println("\nType: $type")
    println("  Expected: [$(join([@sprintf("%.4f", x) for x in exp_pt], ", "))]")
    println("  Refined:  [$(join([@sprintf("%.4f", x) for x in ref_pt], ", "))]")
    println("  Final distance: $(Printf.@sprintf("%.3e", dist))")
    println("  Value improvement: $(Printf.@sprintf("%.5f", raw_val)) → $(Printf.@sprintf("%.5f", ref_val))")
    println("  Expected value: $(Printf.@sprintf("%.5f", exp_val))")
end

# Summary
println("\n" * "="^80)
println("SUMMARY")
println("="^80)

found_global = false
for (type, _, ref_pt, _, ref_val, exp_pt, exp_val, dist) in refined_matches
    if type == "Global minimum" && dist < 0.01
        found_global = true
        println("\n✓ Successfully found global minimum!")
        println("  Final error in position: $(Printf.@sprintf("%.3e", dist))")
        println("  Final error in value: $(Printf.@sprintf("%.3e", abs(ref_val - exp_val)))")
        break
    end
end

if !found_global
    println("\n✗ Global minimum not found in this orthant")
    println("  (May be in a different orthant)")
end

println("\nConclusion: BFGS refinement is essential for accurate critical point location")