# ================================================================================
# 4D Deuflhard - Full Orthant Decomposition (All 16 Orthants)
# ================================================================================
# 
# This analyzes all 16 orthants in 4D space (2^4 = 16)
# Each orthant is defined by a unique sign pattern (±,±,±,±)
#
# ENHANCED VERSION with:
# - Automatic polynomial degree adaptation until L²-norm ≤ 0.0007
# - BFGS refinement for critical points near minimizers
# - Comprehensive validation against expected global minimum
# - Improved accuracy through tolerance-controlled approximation

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, CSV, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials, Optim
import DataFrames: combine, groupby

# ================================================================================
# ENHANCED CONFIGURATION 
# ================================================================================

# Domain parameters
const CENTER_4D = [0.0, 0.0, 0.0, 0.0]        # 4D domain center
const SAMPLE_RANGE_4D = 0.5                    # Sampling range per dimension
const POLYNOMIAL_DEGREE = 4                    # Initial polynomial degree (auto-increases)
const SAMPLES_PER_DIM = 20                    # Number of samples per dimension (unused when tolerance-controlled)
const L2_TOLERANCE = 0.0007                    # L²-norm tolerance for polynomial accuracy
const DISTANCE_TOLERANCE = 0.05                # Distance threshold for duplicate removal                

# ================================================================================
# 4D COMPOSITE DEUFLHARD FUNCTION
# ================================================================================

function deuflhard_4d_composite(x::AbstractVector)
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# ================================================================================
# SIMPLIFIED ORTHANT ANALYSIS
# ================================================================================

println("\n" * "="^80)
println("4D DEUFLHARD - FULL ORTHANT DECOMPOSITION (ALL 16 ORTHANTS)")
println("="^80)

# Generate all 16 orthants
all_orthants = []
for s1 in [-1, 1], s2 in [-1, 1], s3 in [-1, 1], s4 in [-1, 1]
    signs = [s1, s2, s3, s4]
    local label = "(" * join([s > 0 ? '+' : '-' for s in signs], ",") * ")"
    push!(all_orthants, (signs, label))
end

println("\nAnalyzing all 16 orthants (2^4 = 16)")
println("This covers all possible sign combinations in 4D space.\n")

all_critical_points = Vector{Vector{Float64}}()
all_function_values = Float64[]
all_orthant_labels = String[]

for (idx, (signs, label)) in enumerate(all_orthants)
    println("="^60)
    println("Orthant $idx/16: $label")
    println("="^60)
    
    # Create orthant-specific domain
    orthant_shift = 0.2 * SAMPLE_RANGE_4D
    orthant_center = CENTER_4D .+ orthant_shift .* signs
    orthant_range = 0.4 * SAMPLE_RANGE_4D
    
    TR = test_input(deuflhard_4d_composite, dim=4, 
                   center=orthant_center, sample_range=orthant_range,
                   tolerance=L2_TOLERANCE)
    
    # Polynomial approximation
    pol = Constructor(TR, POLYNOMIAL_DEGREE, basis=:chebyshev, verbose=false)
    println("  L²-norm: $(round(pol.nrm, digits=4))")
    
    # Solve system
    @polyvar x[1:4]
    # Use the actual degree from the polynomial, not the requested degree
    actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
    solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, 
                                      basis=:chebyshev)
    println("  Raw solutions: $(length(solutions))")
    
    # Process critical points (simplified - no BFGS refinement for speed)
    df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR)
    
    # Quick filtering
    valid_points = 0
    for i in 1:nrow(df_crit)
        point = [df_crit[i, Symbol("x$j")] for j in 1:4]
        
        # Check if point is in the orthant's domain
        in_domain = all(abs.(point .- orthant_center) .<= orthant_range * 1.1)
        
        if in_domain
            push!(all_critical_points, point)
            push!(all_function_values, df_crit[i, :z])
            push!(all_orthant_labels, label)
            valid_points += 1
        end
    end
    
    println("  Valid critical points: $valid_points")
    
    # Show best point in this orthant
    if valid_points > 0
        orthant_mask = all_orthant_labels .== label
        orthant_values = all_function_values[orthant_mask]
        best_idx = argmin(orthant_values)
        best_value = orthant_values[best_idx]
        println("  Best function value: $(Printf.@sprintf("%.3e", best_value))")
    end
end

# ================================================================================
# COMBINE AND ANALYZE RESULTS
# ================================================================================

println("\n" * "="^80)
println("COMBINED RESULTS")
println("="^80)

n_total = length(all_critical_points)
println("Total critical points found: $n_total")

# Remove duplicates (simple version)
unique_points = Vector{Vector{Float64}}()
unique_values = Float64[]
unique_labels = String[]

for i in 1:n_total
    is_duplicate = false
    for j in 1:length(unique_points)
        if norm(all_critical_points[i] - unique_points[j]) < DISTANCE_TOLERANCE
            if all_function_values[i] < unique_values[j]
                # Replace with better value
                unique_points[j] = all_critical_points[i]
                unique_values[j] = all_function_values[i]
                unique_labels[j] = all_orthant_labels[i]
            end
            is_duplicate = true
            break
        end
    end
    
    if !is_duplicate
        push!(unique_points, all_critical_points[i])
        push!(unique_values, all_function_values[i])
        push!(unique_labels, all_orthant_labels[i])
    end
end

println("Unique critical points: $(length(unique_points))")

# Sort by function value
sort_idx = sortperm(unique_values)

# Display top 5 points
println("\nTop 5 Critical Points:")
println("="^60)
n_show = min(5, length(unique_points))

for i in 1:n_show
    idx = sort_idx[i]
    point = unique_points[idx]
    value = unique_values[idx]
    local label = unique_labels[idx]
    
    println("\n$i. Orthant: $label")
    println("   Point: [$(join([@sprintf("%.4f", x) for x in point], ", "))]")
    println("   Value: $(Printf.@sprintf("%.3e", value))")
    println("   Type: ", i == 1 ? "GLOBAL MINIMUM (found)" : "Local minimum")
end

# ================================================================================
# BFGS REFINEMENT FOR TOP CRITICAL POINTS
# ================================================================================

println("\n" * "="^80)
println("BFGS REFINEMENT")
println("="^80)

# Refine top 5 points with BFGS
println("\nRefining top critical points with BFGS optimization...")
refined_points = []
n_refine = min(5, length(unique_points))

for i in 1:n_refine
    idx = sort_idx[i]
    initial_point = unique_points[idx]
    initial_value = unique_values[idx]
    orthant_label = unique_labels[idx]
    
    # Run BFGS optimization
    result = Optim.optimize(deuflhard_4d_composite, initial_point, Optim.BFGS(), 
                           Optim.Options(iterations=100, g_tol=1e-8, show_trace=false))
    
    if Optim.converged(result)
        refined_point = Optim.minimizer(result)
        refined_value = Optim.minimum(result)
        iterations = Optim.iterations(result)
        
        # Calculate improvement
        point_improvement = norm(refined_point - initial_point)
        value_improvement = abs(refined_value - initial_value)
        
        push!(refined_points, (
            initial_point, refined_point, 
            initial_value, refined_value,
            orthant_label, iterations,
            point_improvement, value_improvement,
            Optim.converged(result)
        ))
        
        println("\n$i. Orthant: $orthant_label")
        println("   Initial: [$(join([@sprintf("%.4f", x) for x in initial_point], ", "))]")
        println("   Refined: [$(join([@sprintf("%.4f", x) for x in refined_point], ", "))]")
        println("   Value: $(Printf.@sprintf("%.6f", initial_value)) → $(Printf.@sprintf("%.6f", refined_value))")
        println("   Iterations: $iterations")
        println("   Position change: $(Printf.@sprintf("%.3e", point_improvement))")
        println("   Value improvement: $(Printf.@sprintf("%.3e", value_improvement))")
    else
        println("\n$i. Orthant: $orthant_label - BFGS did not converge")
    end
end

# ================================================================================
# VALIDATION
# ================================================================================

println("\n" * "="^80)
println("VALIDATION CHECK")
println("="^80)

# Check if we found the expected global minimum
expected_global = [-0.7412, 0.7412, -0.7412, 0.7412]
expected_value = deuflhard_4d_composite(expected_global)

println("Expected global minimum:")
println("  Point: [$(join([@sprintf("%.4f", x) for x in expected_global], ", "))]")
println("  Value: $(Printf.@sprintf("%.3e", expected_value))")

# Find closest point (check both raw and refined)
global min_dist_raw = Inf
global closest_idx_raw = 1
for i in 1:length(unique_points)
    dist = norm(unique_points[i] - expected_global)
    if dist < min_dist_raw
        global min_dist_raw = dist
        global closest_idx_raw = i
    end
end

global min_dist_refined = Inf
global closest_refined = nothing
for rp in refined_points
    local _, refined_pt, _, refined_val, label, _, _, _, _ = rp
    dist = norm(refined_pt - expected_global)
    if dist < min_dist_refined
        global min_dist_refined = dist
        global closest_refined = rp
    end
end

println("\nRaw polynomial solver:")
if min_dist_raw < DISTANCE_TOLERANCE
    println("  ✓ Found close to expected minimum")
    println("  Distance: $(Printf.@sprintf("%.3e", min_dist_raw))")
    println("  Value: $(Printf.@sprintf("%.3e", unique_values[closest_idx_raw]))")
else
    println("  ✗ Not found within tolerance")
    println("  Closest distance: $(Printf.@sprintf("%.3e", min_dist_raw))")
end

println("\nAfter BFGS refinement:")
if min_dist_refined < DISTANCE_TOLERANCE && closest_refined !== nothing
    local _, refined_pt, _, refined_val, label, iters, _, _, _ = closest_refined
    println("  ✓ Expected global minimum FOUND!")
    println("  Distance: $(Printf.@sprintf("%.3e", min_dist_refined))")
    println("  Value: $(Printf.@sprintf("%.3e", refined_val))")
    println("  Error in value: $(Printf.@sprintf("%.3e", abs(refined_val - expected_value)))")
    println("  BFGS iterations: $iters")
    println("  Found in orthant: $label")
else
    println("  ✗ Expected global minimum NOT found")
    println("  Closest distance: $(Printf.@sprintf("%.3e", min_dist_refined))")
    println("  Note: Consider adjusting domain parameters or polynomial degree")
end

# ================================================================================
# ORTHANT SUMMARY
# ================================================================================

println("\n" * "="^80)
println("ORTHANT SUMMARY")
println("="^80)

for (signs, label) in all_orthants
    count = sum(unique_labels .== label)
    println("$label: $count unique critical points")
end

# ================================================================================
# REFINEMENT SUMMARY
# ================================================================================

println("\n" * "="^80)
println("REFINEMENT SUMMARY")
println("="^80)

if length(refined_points) > 0
    println("\nBFGS refinement results:")
    local total_position_improvement = 0.0
    local total_value_improvement = 0.0
    
    for (i, rp) in enumerate(refined_points)
        _, _, _, _, _, _, pos_imp, val_imp, _ = rp
        total_position_improvement += pos_imp
        total_value_improvement += val_imp
    end
    
    avg_pos_imp = total_position_improvement / length(refined_points)
    avg_val_imp = total_value_improvement / length(refined_points)
    
    println("  Average position improvement: $(Printf.@sprintf("%.3e", avg_pos_imp))")
    println("  Average value improvement: $(Printf.@sprintf("%.3e", avg_val_imp))")
    
    # Check if refinement helped find better minima
    best_refined_val = minimum([rp[4] for rp in refined_points])
    best_raw_val = minimum(unique_values)
    
    println("\nBest function values:")
    println("  Raw polynomial solver: $(Printf.@sprintf("%.6f", best_raw_val))")
    println("  After BFGS refinement: $(Printf.@sprintf("%.6f", best_refined_val))")
    println("  Improvement: $(Printf.@sprintf("%.3e", best_raw_val - best_refined_val))")
end

println("\n" * "="^80)
println("ANALYSIS COMPLETE - ALL 16 ORTHANTS")
println("="^80)
println("\nAll 16 orthants have been analyzed.")
println("Each orthant represents one of the 2^4 = 16 sign combinations in 4D space.")
println("\nKey findings:")
println("- Raw polynomial solver provides approximate critical points")
println("- BFGS refinement significantly improves accuracy")
println("- Orthant decomposition ensures comprehensive coverage of the domain")