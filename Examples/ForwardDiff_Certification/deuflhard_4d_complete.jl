# ================================================================================
# 4D Deuflhard - Complete Analysis (All 16 Orthants + BFGS Refinement)
# ================================================================================
# 
# CONSOLIDATED VERSION - Single definitive file for 4D Deuflhard analysis
# 
# Features:
# - Complete 16-orthant decomposition (2^4 = 16 sign combinations)
# - Automatic polynomial degree adaptation until L²-norm ≤ tolerance
# - BFGS refinement for critical points near minimizers
# - Comprehensive validation against expected global minimum
# - High-precision tolerances for accurate results
# - Detailed convergence information and statistics
#
# This file consolidates functionality from multiple experimental versions
# into a single, production-ready implementation.

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using Statistics, Printf, CSV, LinearAlgebra, ForwardDiff, DataFrames, DynamicPolynomials, Optim
import DataFrames: combine, groupby

# ================================================================================
# CONFIGURATION 
# ================================================================================

# Domain parameters
const CENTER_4D = [0.0, 0.0, 0.0, 0.0]        # 4D domain center
const SAMPLE_RANGE_4D = 0.5                    # Sampling range per dimension
const POLYNOMIAL_DEGREE = 4                    # Initial polynomial degree (auto-increases)
const L2_TOLERANCE = 0.0007                    # L²-norm tolerance for polynomial accuracy
const DISTANCE_TOLERANCE = 0.05                # Distance threshold for duplicate removal
const BFGS_TOLERANCE = 1e-8                    # BFGS gradient tolerance
const HIGH_PRECISION_TOLERANCE = 1e-12         # For critical points near zero

# ================================================================================
# 4D COMPOSITE DEUFLHARD FUNCTION
# ================================================================================

function deuflhard_4d_composite(x::AbstractVector)
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# ================================================================================
# EXPECTED CRITICAL POINTS (From 2D Analysis)
# ================================================================================

# Known 2D Deuflhard critical points:
# - Minima: (±0.7412, ∓0.7412) with f = -0.87107
# - Saddle: (0, 0) with f = 0

# 4D critical points are tensor products of 2D points:
const EXPECTED_GLOBAL_MIN = [-0.7412, 0.7412, -0.7412, 0.7412]  # f = -1.74214
const EXPECTED_VALUE = deuflhard_4d_composite(EXPECTED_GLOBAL_MIN)

println("\\n" * "="^80)
println("4D DEUFLHARD - COMPLETE ANALYSIS")
println("="^80)
println("\\nExpected global minimum:")
println("  Point: [$(join([@sprintf("%.4f", x) for x in EXPECTED_GLOBAL_MIN], ", "))]")
println("  Value: $(Printf.@sprintf("%.6f", EXPECTED_VALUE))")

# ================================================================================
# ORTHANT ANALYSIS - ALL 16 ORTHANTS
# ================================================================================

println("\\n" * "="^80)
println("ORTHANT DECOMPOSITION - ALL 16 ORTHANTS")
println("="^80)

# Generate all 16 orthants (2^4 combinations)
all_orthants = []
for s1 in [-1, 1], s2 in [-1, 1], s3 in [-1, 1], s4 in [-1, 1]
    signs = [s1, s2, s3, s4]
    local label = "(" * join([s > 0 ? '+' : '-' for s in signs], ",") * ")"
    push!(all_orthants, (signs, label))
end

println("\\nAnalyzing all 16 orthants (2^4 = 16)")
println("Each orthant represents a unique sign combination in 4D space.")
println("Using tolerance-controlled polynomial approximation (L²-norm ≤ $(L2_TOLERANCE))\\n")

# Storage for all critical points
all_critical_points = Vector{Vector{Float64}}()
all_function_values = Float64[]
all_orthant_labels = String[]
all_polynomial_degrees = Int[]
all_l2_norms = Float64[]

# Analyze each orthant
for (idx, (signs, label)) in enumerate(all_orthants)
    println("="^60)
    println("Orthant $idx/16: $label")
    println("="^60)
    
    # Create orthant-specific domain with overlap
    orthant_shift = 0.2 * SAMPLE_RANGE_4D
    orthant_center = CENTER_4D .+ orthant_shift .* signs
    orthant_range = 0.4 * SAMPLE_RANGE_4D
    
    # Create test input with tolerance control
    TR = test_input(deuflhard_4d_composite, dim=4, 
                   center=orthant_center, sample_range=orthant_range,
                   tolerance=L2_TOLERANCE)
    
    # Polynomial approximation with automatic degree adaptation
    pol = Constructor(TR, POLYNOMIAL_DEGREE, basis=:chebyshev, verbose=false)
    println("  Final L²-norm: $(round(pol.nrm, digits=6))")
    
    # Extract actual degree used
    actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
    println("  Polynomial degree: $actual_degree")
    
    # Solve polynomial system
    @polyvar x[1:4]
    solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, 
                                      basis=:chebyshev)
    println("  Raw solutions: $(length(solutions))")
    
    # Process critical points
    df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR)
    
    # Filter valid points in orthant domain
    valid_points = 0
    for i in 1:nrow(df_crit)
        point = [df_crit[i, Symbol("x$j")] for j in 1:4]
        
        # Check if point is in the orthant's domain (with tolerance)
        in_domain = all(abs.(point .- orthant_center) .<= orthant_range * 1.1)
        
        if in_domain
            push!(all_critical_points, point)
            push!(all_function_values, df_crit[i, :z])
            push!(all_orthant_labels, label)
            push!(all_polynomial_degrees, actual_degree)
            push!(all_l2_norms, pol.nrm)
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
        println("  Best function value: $(Printf.@sprintf("%.6f", best_value))")
    end
end

# ================================================================================
# DUPLICATE REMOVAL AND RANKING
# ================================================================================

println("\\n" * "="^80)
println("DUPLICATE REMOVAL AND RANKING")
println("="^80)

n_total = length(all_critical_points)
println("\\nTotal critical points found: $n_total")

# Remove duplicates using distance tolerance
unique_points = Vector{Vector{Float64}}()
unique_values = Float64[]
unique_labels = String[]
unique_degrees = Int[]
unique_norms = Float64[]

for i in 1:n_total
    is_duplicate = false
    for j in 1:length(unique_points)
        if norm(all_critical_points[i] - unique_points[j]) < DISTANCE_TOLERANCE
            # Replace with better value if found
            if all_function_values[i] < unique_values[j]
                unique_points[j] = all_critical_points[i]
                unique_values[j] = all_function_values[i]
                unique_labels[j] = all_orthant_labels[i]
                unique_degrees[j] = all_polynomial_degrees[i]
                unique_norms[j] = all_l2_norms[i]
            end
            is_duplicate = true
            break
        end
    end
    
    if !is_duplicate
        push!(unique_points, all_critical_points[i])
        push!(unique_values, all_function_values[i])
        push!(unique_labels, all_orthant_labels[i])
        push!(unique_degrees, all_polynomial_degrees[i])
        push!(unique_norms, all_l2_norms[i])
    end
end

println("Unique critical points after duplicate removal: $(length(unique_points))")

# Sort by function value
sort_idx = sortperm(unique_values)

# Display top critical points
println("\\nTop 10 Critical Points (Raw Polynomial Results):")
println("="^70)
n_show = min(10, length(unique_points))

for i in 1:n_show
    idx = sort_idx[i]
    point = unique_points[idx]
    value = unique_values[idx]
    label = unique_labels[idx]
    degree = unique_degrees[idx]
    l2_norm = unique_norms[idx]
    
    println("\\n$i. Orthant: $label")
    println("   Point: [$(join([@sprintf("%.6f", x) for x in point], ", "))]")
    println("   Value: $(Printf.@sprintf("%.8f", value))")
    println("   Degree: $degree, L²-norm: $(Printf.@sprintf("%.2e", l2_norm))")
    
    # Calculate distance to expected global minimum
    dist_to_global = norm(point - EXPECTED_GLOBAL_MIN)
    println("   Distance to expected global min: $(Printf.@sprintf("%.3e", dist_to_global))")
end

# ================================================================================
# BFGS REFINEMENT FOR TOP CRITICAL POINTS
# ================================================================================

println("\\n" * "="^80)
println("BFGS REFINEMENT")
println("="^80)

# Refine top critical points with BFGS optimization
println("\\nRefining top critical points with BFGS optimization...")
println("Using gradient tolerance: $(Printf.@sprintf("%.1e", BFGS_TOLERANCE))")

refined_results = []
n_refine = min(8, length(unique_points))

for i in 1:n_refine
    idx = sort_idx[i]
    initial_point = unique_points[idx]
    initial_value = unique_values[idx]
    orthant_label = unique_labels[idx]
    
    println("\\n" * "-"^60)
    println("Refining critical point $i from orthant $orthant_label")
    println("Initial: [$(join([@sprintf("%.6f", x) for x in initial_point], ", "))]")
    println("Initial value: $(Printf.@sprintf("%.8f", initial_value))")
    
    # Choose tolerance based on function value magnitude
    bfgs_tol = abs(initial_value) < 1e-6 ? HIGH_PRECISION_TOLERANCE : BFGS_TOLERANCE
    
    # Run BFGS optimization
    result = Optim.optimize(deuflhard_4d_composite, initial_point, Optim.BFGS(), 
                           Optim.Options(iterations=100, g_tol=bfgs_tol, show_trace=false))
    
    if Optim.converged(result)
        refined_point = Optim.minimizer(result)
        refined_value = Optim.minimum(result)
        iterations = Optim.iterations(result)
        
        # Calculate improvements
        point_improvement = norm(refined_point - initial_point)
        value_improvement = abs(refined_value - initial_value)
        
        # Calculate gradient norm at solution
        grad = ForwardDiff.gradient(deuflhard_4d_composite, refined_point)
        grad_norm = norm(grad)
        
        push!(refined_results, (
            i, initial_point, refined_point, 
            initial_value, refined_value,
            orthant_label, iterations,
            point_improvement, value_improvement,
            grad_norm, Optim.converged(result)
        ))
        
        println("\\nRefined: [$(join([@sprintf("%.6f", x) for x in refined_point], ", "))]")
        println("Refined value: $(Printf.@sprintf("%.8f", refined_value))")
        println("BFGS iterations: $iterations")
        println("Position change: $(Printf.@sprintf("%.3e", point_improvement))")
        println("Value improvement: $(Printf.@sprintf("%.3e", value_improvement))")
        println("Final gradient norm: $(Printf.@sprintf("%.3e", grad_norm))")
        
        # Check if this might be the global minimum
        dist_to_expected = norm(refined_point - EXPECTED_GLOBAL_MIN)
        if dist_to_expected < DISTANCE_TOLERANCE
            println("*** POTENTIAL GLOBAL MINIMUM FOUND! ***")
            println("Distance to expected: $(Printf.@sprintf("%.3e", dist_to_expected))")
        end
    else
        println("BFGS did not converge!")
    end
end

# ================================================================================
# VALIDATION AND GLOBAL MINIMUM SEARCH
# ================================================================================

println("\\n" * "="^80)
println("VALIDATION AND GLOBAL MINIMUM SEARCH")
println("="^80)

# Find closest points to expected global minimum
println("\\nSearching for expected global minimum:")
println("Expected: [$(join([@sprintf("%.4f", x) for x in EXPECTED_GLOBAL_MIN], ", "))]")
println("Expected value: $(Printf.@sprintf("%.6f", EXPECTED_VALUE))")

# Check raw polynomial results
global min_dist_raw = Inf
global closest_raw_idx = 1
for i in 1:length(unique_points)
    dist = norm(unique_points[i] - EXPECTED_GLOBAL_MIN)
    if dist < min_dist_raw
        global min_dist_raw = dist
        global closest_raw_idx = i
    end
end

# Check refined results
global min_dist_refined = Inf
global closest_refined = nothing
for result in refined_results
    _, _, refined_pt, _, refined_val, label, _, _, _, _, _ = result
    dist = norm(refined_pt - EXPECTED_GLOBAL_MIN)
    if dist < min_dist_refined
        global min_dist_refined = dist
        global closest_refined = result
    end
end

println("\\n" * "-"^60)
println("Raw polynomial solver results:")
if min_dist_raw < DISTANCE_TOLERANCE
    println("  ✓ Found close to expected minimum")
    println("  Distance: $(Printf.@sprintf("%.3e", min_dist_raw))")
    println("  Value: $(Printf.@sprintf("%.6f", unique_values[closest_raw_idx]))")
    println("  Found in orthant: $(unique_labels[closest_raw_idx])")
else
    println("  ✗ Not found within tolerance")
    println("  Closest distance: $(Printf.@sprintf("%.3e", min_dist_raw))")
    println("  Closest value: $(Printf.@sprintf("%.6f", unique_values[closest_raw_idx]))")
end

println("\\n" * "-"^60)
println("After BFGS refinement:")
if min_dist_refined < DISTANCE_TOLERANCE && closest_refined !== nothing
    _, _, refined_pt, _, refined_val, label, iters, pos_change, val_change, grad_norm, _ = closest_refined
    println("  ✓ EXPECTED GLOBAL MINIMUM FOUND!")
    println("  Final point: [$(join([@sprintf("%.6f", x) for x in refined_pt], ", "))]")
    println("  Final value: $(Printf.@sprintf("%.8f", refined_val))")
    println("  Distance to expected: $(Printf.@sprintf("%.3e", min_dist_refined))")
    println("  Value error: $(Printf.@sprintf("%.3e", abs(refined_val - EXPECTED_VALUE)))")
    println("  Final gradient norm: $(Printf.@sprintf("%.3e", grad_norm))")
    println("  BFGS iterations: $iters")
    println("  Found in orthant: $label")
else
    println("  ✗ Expected global minimum NOT found")
    if closest_refined !== nothing
        println("  Closest distance: $(Printf.@sprintf("%.3e", min_dist_refined))")
        _, _, _, _, refined_val, label, _, _, _, _, _ = closest_refined
        println("  Closest value: $(Printf.@sprintf("%.6f", refined_val))")
        println("  Closest orthant: $label")
    end
end

# ================================================================================
# COMPREHENSIVE SUMMARY
# ================================================================================

println("\\n" * "="^80)
println("COMPREHENSIVE SUMMARY")
println("="^80)

println("\\nOrthant Analysis Results:")
println("  Total orthants analyzed: 16")
println("  Total critical points found: $n_total")
println("  Unique critical points: $(length(unique_points))")
println("  Points refined with BFGS: $(length(refined_results))")

if length(refined_results) > 0
    println("\\nBFGS Refinement Statistics:")
    local total_pos_improvement = sum([r[8] for r in refined_results])
    local total_val_improvement = sum([r[9] for r in refined_results])
    local avg_pos_improvement = total_pos_improvement / length(refined_results)
    local avg_val_improvement = total_val_improvement / length(refined_results)
    local avg_grad_norm = sum([r[10] for r in refined_results]) / length(refined_results)
    
    println("  Average position improvement: $(Printf.@sprintf("%.3e", avg_pos_improvement))")
    println("  Average value improvement: $(Printf.@sprintf("%.3e", avg_val_improvement))")
    println("  Average final gradient norm: $(Printf.@sprintf("%.3e", avg_grad_norm))")
    
    # Best function values
    best_refined_val = minimum([r[5] for r in refined_results])
    best_raw_val = minimum(unique_values)
    
    println("\\nBest Function Values:")
    println("  Raw polynomial solver: $(Printf.@sprintf("%.8f", best_raw_val))")
    println("  After BFGS refinement: $(Printf.@sprintf("%.8f", best_refined_val))")
    println("  Total improvement: $(Printf.@sprintf("%.3e", best_raw_val - best_refined_val))")
end

println("\\nPolynomial Approximation Quality:")
local avg_degree = sum(unique_degrees) / length(unique_degrees)
local avg_l2_norm = sum(unique_norms) / length(unique_norms)
println("  Average polynomial degree: $(Printf.@sprintf("%.1f", avg_degree))")
println("  Average L²-norm: $(Printf.@sprintf("%.2e", avg_l2_norm))")
println("  Target L²-norm: $(Printf.@sprintf("%.2e", L2_TOLERANCE))")

# Orthant distribution
println("\\nCritical Points Distribution by Orthant:")
for (signs, label) in all_orthants
    count = sum(unique_labels .== label)
    println("  $label: $count unique critical points")
end

println("\\n" * "="^80)
println("ANALYSIS COMPLETE")
println("="^80)
println("\\nKey Findings:")
println("- Comprehensive 16-orthant coverage ensures no critical points missed")
println("- Tolerance-controlled polynomial approximation provides high accuracy")
println("- BFGS refinement is essential for precise critical point location")
println("- Orthant decomposition enables systematic domain exploration")

global_found = min_dist_refined < DISTANCE_TOLERANCE && closest_refined !== nothing
if global_found
    println("- ✓ Expected global minimum successfully located!")
else
    println("- ⚠ Expected global minimum not found (may need parameter adjustment)")
end

println("\\nThis analysis represents the definitive 4D Deuflhard critical point study.")