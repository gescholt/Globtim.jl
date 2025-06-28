# ================================================================================
# 4D Deuflhard - Full 16 Orthant Analysis with 2D Comparison
# ================================================================================
# 
# This analyzes all 16 orthants and compares:
# 1. Raw critical points from polynomial system
# 2. BFGS-optimized minimizers
# 3. Expected critical points from 2D analysis

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, CSV, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials
import DataFrames: combine, groupby

# ================================================================================
# CONFIGURATION FOR FULL ANALYSIS
# ================================================================================

# Domain parameters - balanced for accuracy and speed
const CENTER_4D = [0.0, 0.0, 0.0, 0.0]        
const SAMPLE_RANGE_4D = 0.8                    
const POLYNOMIAL_DEGREE = 6                    
const DISTANCE_TOLERANCE = 0.02                

# ================================================================================
# KNOWN 2D CRITICAL POINTS
# ================================================================================

# From 2D Deuflhard analysis
const DEUFLHARD_2D_CRITS = [
    ([-0.7412, 0.7412], -0.87107, "Global minimum"),
    ([0.7412, -0.7412], -0.87107, "Global minimum (symmetric)"),
    ([0.0, 0.0], 0.0, "Saddle point"),
    # Additional critical points exist but these are the main ones
]

# Generate expected 4D points as tensor products
function generate_expected_4d_points()
    expected = []
    
    # Tensor products of 2D critical points
    for (p1, v1, t1) in DEUFLHARD_2D_CRITS
        for (p2, v2, t2) in DEUFLHARD_2D_CRITS
            point_4d = vcat(p1, p2)
            value_4d = v1 + v2  # f(x1,x2,x3,x4) = f(x1,x2) + f(x3,x4)
            
            # Determine type
            if t1 == "Global minimum" && t2 == "Global minimum"
                type_4d = "Global minimum"
            elseif contains(t1, "minimum") && contains(t2, "minimum")
                type_4d = "Local minimum"
            else
                type_4d = "Saddle point"
            end
            
            push!(expected, (point_4d, value_4d, type_4d))
        end
    end
    
    return expected
end

# ================================================================================
# 4D COMPOSITE DEUFLHARD FUNCTION
# ================================================================================

function deuflhard_4d_composite(x::AbstractVector)
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# ================================================================================
# ORTHANT ANALYSIS WITH RAW/REFINED TRACKING
# ================================================================================

function analyze_orthant_with_tracking(orthant_signs::Vector{Int}, orthant_idx::Int)
    label = "(" * join([s > 0 ? '+' : '-' for s in orthant_signs], "") * ")"
    
    println("\n" * "="^60)
    println("Orthant $orthant_idx/16: $label")
    println("="^60)
    
    # Create orthant-specific domain
    orthant_shift = 0.3 * SAMPLE_RANGE_4D
    orthant_center = CENTER_4D .+ orthant_shift .* orthant_signs
    orthant_range = 0.6 * SAMPLE_RANGE_4D
    
    TR = test_input(deuflhard_4d_composite, dim=4, 
                   center=orthant_center, sample_range=orthant_range)
    
    # Polynomial approximation
    pol = Constructor(TR, POLYNOMIAL_DEGREE, basis=:chebyshev, verbose=false)
    println("  L²-norm: $(Printf.@sprintf("%.2e", pol.nrm))")
    
    # Solve system
    @polyvar x[1:4]
    actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
    solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, 
                                      basis=:chebyshev)
    println("  Raw solutions: $(length(solutions))")
    
    # Process critical points
    df_raw = process_crit_pts(solutions, deuflhard_4d_composite, TR)
    
    # Filter to orthant domain
    raw_points = []
    for i in 1:nrow(df_raw)
        point = [df_raw[i, Symbol("x$j")] for j in 1:4]
        if all(abs.(point .- orthant_center) .<= orthant_range * 1.1)
            push!(raw_points, (point, df_raw[i, :z]))
        end
    end
    println("  Valid raw critical points: $(length(raw_points))")
    
    # BFGS refinement
    df_refined, _ = analyze_critical_points(
        deuflhard_4d_composite, df_raw, TR,
        enable_hessian=false,
        tol_dist=0.025,
        verbose=false,
        max_iters_in_optim=100
    )
    
    # Filter refined points
    refined_points = []
    for i in 1:nrow(df_refined)
        point = [df_refined[i, Symbol("y$j")] for j in 1:4]
        if all(abs.(point .- orthant_center) .<= orthant_range * 1.1)
            push!(refined_points, (point, df_refined[i, :z]))
        end
    end
    println("  Refined critical points: $(length(refined_points))")
    
    return raw_points, refined_points, label
end

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

println("\n" * "="^80)
println("FULL 4D DEUFLHARD ANALYSIS - ALL 16 ORTHANTS")
println("="^80)

# Generate expected 4D points
expected_4d = generate_expected_4d_points()
println("\nExpected 4D critical points (from 2D tensor products): $(length(expected_4d))")

# Show expected global minima
println("\nExpected global minima:")
for (point, value, type) in expected_4d
    if type == "Global minimum"
        println("  [$(join([@sprintf("%.4f", x) for x in point], ", "))], value = $(Printf.@sprintf("%.5f", value))")
    end
end

# Generate all 16 orthant signs
orthant_signs = []
for s1 in [-1, 1], s2 in [-1, 1], s3 in [-1, 1], s4 in [-1, 1]
    push!(orthant_signs, [s1, s2, s3, s4])
end

# Analyze all orthants
all_raw_points = []
all_refined_points = []
all_labels = []

for (idx, signs) in enumerate(orthant_signs)
    raw, refined, label = analyze_orthant_with_tracking(signs, idx)
    append!(all_raw_points, [(p, v, label) for (p, v) in raw])
    append!(all_refined_points, [(p, v, label) for (p, v) in refined])
end

# ================================================================================
# REMOVE DUPLICATES
# ================================================================================

function remove_duplicate_points(points_data, tol=DISTANCE_TOLERANCE)
    unique_data = []
    
    for (point, value, label) in points_data
        is_duplicate = false
        for (i, (up, uv, ul)) in enumerate(unique_data)
            if norm(point - up) < tol
                # Keep the one with better (lower) function value
                if value < uv
                    unique_data[i] = (point, value, label)
                end
                is_duplicate = true
                break
            end
        end
        
        if !is_duplicate
            push!(unique_data, (point, value, label))
        end
    end
    
    return unique_data
end

unique_raw = remove_duplicate_points(all_raw_points)
unique_refined = remove_duplicate_points(all_refined_points)

println("\n" * "="^80)
println("SUMMARY OF ALL ORTHANTS")
println("="^80)
println("Total raw critical points: $(length(all_raw_points))")
println("Unique raw critical points: $(length(unique_raw))")
println("Total refined critical points: $(length(all_refined_points))")
println("Unique refined critical points: $(length(unique_refined))")

# ================================================================================
# COMPARISON WITH EXPECTED POINTS
# ================================================================================

println("\n" * "="^80)
println("COMPARISON WITH EXPECTED 2D TENSOR PRODUCTS")
println("="^80)

function find_matches(found_points, expected_points, tol=0.05)
    matches = []
    unmatched_expected = copy(expected_points)
    unmatched_found = copy(found_points)
    
    for (fp, fv, fl) in found_points
        best_match = nothing
        best_dist = Inf
        best_idx = 0
        
        for (i, (ep, ev, et)) in enumerate(unmatched_expected)
            dist = norm(fp - ep)
            if dist < tol && dist < best_dist
                best_match = (ep, ev, et)
                best_dist = dist
                best_idx = i
            end
        end
        
        if best_match !== nothing
            push!(matches, (fp, fv, fl, best_match..., best_dist))
            deleteat!(unmatched_expected, best_idx)
            filter!(x -> x != (fp, fv, fl), unmatched_found)
        end
    end
    
    return matches, unmatched_expected, unmatched_found
end

# Compare raw points
println("\n--- RAW CRITICAL POINTS ---")
raw_matches, unmatched_exp_raw, unmatched_raw = find_matches(unique_raw, expected_4d)
println("Matched with expected: $(length(raw_matches))")
println("Unmatched expected: $(length(unmatched_exp_raw))")
println("Additional found: $(length(unmatched_raw))")

# Compare refined points
println("\n--- REFINED (BFGS) CRITICAL POINTS ---")
refined_matches, unmatched_exp_refined, unmatched_refined = find_matches(unique_refined, expected_4d)
println("Matched with expected: $(length(refined_matches))")
println("Unmatched expected: $(length(unmatched_exp_refined))")
println("Additional found: $(length(unmatched_refined))")

# ================================================================================
# DETAILED MATCH REPORT
# ================================================================================

println("\n" * "="^80)
println("DETAILED MATCHING REPORT")
println("="^80)

# Sort matches by function value
sort!(refined_matches, by=x->x[2])

println("\nTop 10 Refined Matches with Expected Points:")
println("-"^80)
for i in 1:min(10, length(refined_matches))
    fp, fv, fl, ep, ev, et, dist = refined_matches[i]
    println("\n$i. Expected: $et")
    println("   Expected point: [$(join([@sprintf("%.4f", x) for x in ep], ", "))]")
    println("   Expected value: $(Printf.@sprintf("%.5f", ev))")
    println("   Found point:    [$(join([@sprintf("%.4f", x) for x in fp], ", "))]")
    println("   Found value:    $(Printf.@sprintf("%.5f", fv))")
    println("   Distance:       $(Printf.@sprintf("%.2e", dist))")
    println("   Found in:       $fl")
end

# Check if global minima were found
println("\n" * "="^80)
println("GLOBAL MINIMA CHECK")
println("="^80)

global_min_value = -0.87107 * 2  # Two times the 2D minimum
found_global = false

for (fp, fv, fl) in unique_refined
    if abs(fv - global_min_value) < 0.001
        found_global = true
        println("✓ Global minimum found!")
        println("  Point: [$(join([@sprintf("%.4f", x) for x in fp], ", "))]")
        println("  Value: $(Printf.@sprintf("%.5f", fv)) (expected: $(Printf.@sprintf("%.5f", global_min_value)))")
        println("  Orthant: $fl")
    end
end

if !found_global
    println("✗ Global minimum not found accurately")
    # Find closest
    best_val = Inf
    best_point = nothing
    best_label = ""
    for (fp, fv, fl) in unique_refined
        if fv < best_val
            best_val = fv
            best_point = fp
            best_label = fl
        end
    end
    println("  Best found: $(Printf.@sprintf("%.5f", best_val)) at")
    println("  [$(join([@sprintf("%.4f", x) for x in best_point], ", "))] in $best_label")
end

# ================================================================================
# ORTHANT STATISTICS
# ================================================================================

println("\n" * "="^80)
println("CRITICAL POINTS PER ORTHANT")
println("="^80)

# Count points per orthant
orthant_counts = Dict{String, Int}()
for (_, _, label) in unique_refined
    orthant_counts[label] = get(orthant_counts, label, 0) + 1
end

# Sort by label
sorted_labels = sort(collect(keys(orthant_counts)))
for label in sorted_labels
    println("$label: $(orthant_counts[label]) critical points")
end

println("\n" * "="^80)
println("ANALYSIS COMPLETE")
println("="^80)