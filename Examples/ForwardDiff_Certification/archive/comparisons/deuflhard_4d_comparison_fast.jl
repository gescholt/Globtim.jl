# ================================================================================
# 4D Deuflhard - Fast Comparison of Raw vs Refined vs Expected
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials
using Optim

# ================================================================================
# FAST CONFIGURATION
# ================================================================================

const CENTER_4D = [0.0, 0.0, 0.0, 0.0]        
const SAMPLE_RANGE_4D = 0.5                    
const POLYNOMIAL_DEGREE = 4                    # Very low for speed
const DISTANCE_TOLERANCE = 0.05                

# ================================================================================
# KNOWN 2D CRITICAL POINTS
# ================================================================================

# From 2D Deuflhard analysis
const DEUFLHARD_2D_CRITS = [
    ([-0.7412, 0.7412], -0.87107, "Global minimum"),
    ([0.7412, -0.7412], -0.87107, "Global minimum (symmetric)"),
    ([0.0, 0.0], 0.0, "Saddle point")
]

# Generate expected 4D points
function generate_expected_4d_points()
    expected = []
    for (p1, v1, t1) in DEUFLHARD_2D_CRITS
        for (p2, v2, t2) in DEUFLHARD_2D_CRITS
            point_4d = vcat(p1, p2)
            value_4d = v1 + v2
            
            if t1 == "Global minimum" && t2 == "Global minimum"
                type_4d = "Global minimum"
            elseif contains(t1, "minimum") && contains(t2, "minimum")
                type_4d = "Local minimum"
            else
                type_4d = "Saddle/Mixed"
            end
            
            push!(expected, (point_4d, value_4d, type_4d))
        end
    end
    return expected
end

# 4D function
function deuflhard_4d_composite(x::AbstractVector)
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# ================================================================================
# FAST ORTHANT ANALYSIS
# ================================================================================

println("\n" * "="^80)
println("FAST 4D COMPARISON: RAW vs REFINED vs EXPECTED")
println("="^80)

# Expected points
expected_4d = generate_expected_4d_points()
println("\nExpected critical points from 2D tensor products: $(length(expected_4d))")
println("\nExpected types:")
for type in ["Global minimum", "Local minimum", "Saddle/Mixed"]
    type_count = Base.count(x -> x[3] == type, expected_4d)
    println("  $type: $type_count")
end

# Sample just 4 diverse orthants for speed
test_orthants = [
    ([1, 1, 1, 1], "(++++)"),      
    ([-1, -1, -1, -1], "(----)"),  
    ([1, -1, 1, -1], "(+-+-)"),    
    ([-1, 1, -1, 1], "(-+-+)")     
]

all_raw = []
all_refined = []

println("\n" * "="^80)
println("ANALYZING 4 REPRESENTATIVE ORTHANTS")
println("="^80)

for (signs, label) in test_orthants
    println("\nOrthant $label:")
    
    # Create domain
    orthant_shift = 0.2 * SAMPLE_RANGE_4D
    orthant_center = CENTER_4D .+ orthant_shift .* signs
    orthant_range = 0.4 * SAMPLE_RANGE_4D
    
    TR = test_input(deuflhard_4d_composite, dim=4, 
                   center=orthant_center, sample_range=orthant_range)
    
    # Polynomial
    pol = Constructor(TR, POLYNOMIAL_DEGREE, basis=:chebyshev, verbose=false)
    
    # Solve
    @polyvar x[1:4]
    actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
    solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
    
    # Process raw
    df_raw = process_crit_pts(solutions, deuflhard_4d_composite, TR)
    
    # Quick BFGS refinement (limited iterations)
    df_refined = copy(df_raw)
    for i in 1:nrow(df_refined)
        x0 = [df_raw[i, Symbol("x$j")] for j in 1:4]
        
        # Simple BFGS with few iterations
        result = Optim.optimize(deuflhard_4d_composite, x0, 
                               Optim.BFGS(), 
                               Optim.Options(iterations=20, g_tol=1e-4))
        
        if Optim.converged(result)
            xopt = Optim.minimizer(result)
            for j in 1:4
                df_refined[i, Symbol("y$j")] = xopt[j]
            end
            df_refined[i, :z] = Optim.minimum(result)
        else
            # Keep original if not converged
            for j in 1:4
                df_refined[i, Symbol("y$j")] = df_raw[i, Symbol("x$j")]
            end
        end
    end
    
    # Collect valid points
    for i in 1:nrow(df_raw)
        raw_pt = [df_raw[i, Symbol("x$j")] for j in 1:4]
        ref_pt = [df_refined[i, Symbol("y$j")] for j in 1:4]
        
        # Check if in domain
        if all(abs.(raw_pt .- orthant_center) .<= orthant_range * 1.1)
            push!(all_raw, (raw_pt, df_raw[i, :z], label))
        end
        
        if all(abs.(ref_pt .- orthant_center) .<= orthant_range * 1.1)
            push!(all_refined, (ref_pt, df_refined[i, :z], label))
        end
    end
    
    println("  Raw points: $(Base.count(x->x[3]==label, all_raw))")
    println("  Refined points: $(Base.count(x->x[3]==label, all_refined))")
end

# ================================================================================
# COMPARISON
# ================================================================================

println("\n" * "="^80)
println("COMPARISON WITH EXPECTED POINTS")
println("="^80)

function find_closest_match(point, expected_list)
    best_dist = Inf
    best_match = nothing
    
    for (ep, ev, et) in expected_list
        dist = norm(point - ep)
        if dist < best_dist
            best_dist = dist
            best_match = (ep, ev, et)
        end
    end
    
    return best_match, best_dist
end

# Analyze raw points
println("\n--- RAW CRITICAL POINTS ---")
raw_matched = 0
raw_close = 0
for (rp, rv, rl) in all_raw
    match, dist = find_closest_match(rp, expected_4d)
    if dist < DISTANCE_TOLERANCE
        raw_matched += 1
    elseif dist < 2*DISTANCE_TOLERANCE
        raw_close += 1
    end
end
println("Total raw points: $(length(all_raw))")
println("Matched to expected (< $(DISTANCE_TOLERANCE)): $raw_matched")
println("Close to expected (< $(2*DISTANCE_TOLERANCE)): $raw_close")

# Analyze refined points
println("\n--- REFINED CRITICAL POINTS ---")
refined_matched = 0
refined_close = 0
refined_matches = []

for (rp, rv, rl) in all_refined
    match, dist = find_closest_match(rp, expected_4d)
    if dist < DISTANCE_TOLERANCE
        refined_matched += 1
        push!(refined_matches, (rp, rv, rl, match..., dist))
    elseif dist < 2*DISTANCE_TOLERANCE
        refined_close += 1
    end
end
println("Total refined points: $(length(all_refined))")
println("Matched to expected (< $(DISTANCE_TOLERANCE)): $refined_matched")
println("Close to expected (< $(2*DISTANCE_TOLERANCE)): $refined_close")

# ================================================================================
# DETAILED MATCHES
# ================================================================================

println("\n" * "="^80)
println("BEST MATCHES (REFINED)")
println("="^80)

# Sort by function value
sort!(refined_matches, by=x->x[2])

println("\nTop matches:")
for i in 1:min(5, length(refined_matches))
    rp, rv, rl, ep, ev, et, dist = refined_matches[i]
    println("\n$i. Type: $et")
    println("   Expected: [$(join([@sprintf("%.4f", x) for x in ep], ", "))] = $(Printf.@sprintf("%.5f", ev))")
    println("   Found:    [$(join([@sprintf("%.4f", x) for x in rp], ", "))] = $(Printf.@sprintf("%.5f", rv))")
    println("   Distance: $(Printf.@sprintf("%.3e", dist))")
    println("   Orthant:  $rl")
end

# ================================================================================
# IMPROVEMENT ANALYSIS
# ================================================================================

println("\n" * "="^80)
println("IMPROVEMENT FROM RAW TO REFINED")
println("="^80)

# Track improvement for matched points
improvements = []
for (raw_pt, raw_val, raw_lab) in all_raw
    # Find corresponding refined point
    for (ref_pt, ref_val, ref_lab) in all_refined
        if raw_lab == ref_lab && norm(raw_pt - ref_pt) < 0.5
            # Find expected match
            match, dist = find_closest_match(ref_pt, expected_4d)
            if dist < DISTANCE_TOLERANCE
                ep, ev, et = match
                raw_err = abs(raw_val - ev)
                ref_err = abs(ref_val - ev)
                improvement = (raw_err - ref_err) / raw_err * 100
                push!(improvements, (et, raw_err, ref_err, improvement))
            end
        end
    end
end

if length(improvements) > 0
    println("\nFunction value error reduction:")
    for (type, raw_err, ref_err, imp) in improvements[1:min(5, length(improvements))]
        println("  $type:")
        println("    Raw error:     $(Printf.@sprintf("%.3e", raw_err))")
        println("    Refined error: $(Printf.@sprintf("%.3e", ref_err))")
        println("    Improvement:   $(Printf.@sprintf("%.1f", imp))%")
    end
end

# Check for global minimum
println("\n" * "="^80)
println("GLOBAL MINIMUM CHECK")
println("="^80)

expected_global_val = -0.87107 * 2
found_global = false

for (rp, rv, rl) in all_refined
    if abs(rv - expected_global_val) < 0.01
        found_global = true
        println("✓ Global minimum found in orthant $rl")
        println("  Point: [$(join([@sprintf("%.4f", x) for x in rp], ", "))]")
        println("  Value: $(Printf.@sprintf("%.5f", rv)) (expected: $(Printf.@sprintf("%.5f", expected_global_val)))")
        break
    end
end

if !found_global
    println("✗ Global minimum not found in tested orthants")
    println("  Note: Only 4 out of 16 orthants were tested")
end

println("\n" * "="^80)
println("ANALYSIS COMPLETE")
println("="^80)