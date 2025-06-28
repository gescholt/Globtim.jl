# Raw vs Refined Eigenvalue Comparison Demo
# 
# This example demonstrates the new comparative eigenvalue visualization
# that shows how eigenvalues change from raw polynomial critical points
# to BFGS-refined points, with distance-based ordering.

# Proper initialization for examples
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))

using Globtim
using DynamicPolynomials
using DataFrames
using LinearAlgebra
using Statistics

# Load visualization backend
using CairoMakie

println("=== Raw vs Refined Eigenvalue Comparison Demo ===\n")

# Use Deuflhard function for clear demonstration
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

println("Function: Deuflhard (2D with multiple critical points)")
println("This demo shows eigenvalue evolution during BFGS refinement")
println("Points are ordered by Euclidean distance between raw and refined pairs\n")

# Phase 1: Get raw polynomial critical points
println("=== Step 1: Raw Polynomial Critical Points ===")
pol = Constructor(TR, 8, verbose=true)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df_raw = process_crit_pts(solutions, f, TR)

println("Raw critical points found: $(nrow(df_raw))")
println("Function value range: [$(round(minimum(df_raw.z), digits=4)), $(round(maximum(df_raw.z), digits=4))]")

# Phase 2: Enhanced analysis with BFGS refinement
println("\n=== Step 2: BFGS Refinement and Hessian Analysis ===")
df_refined, df_min = analyze_critical_points(
    f, df_raw, TR,
    enable_hessian=true,
    verbose=true
)

println("Enhanced critical points: $(nrow(df_refined))")
println("Classification summary:")
if "critical_point_type" in names(df_refined)
    classification_counts = combine(groupby(df_refined, :critical_point_type), nrow => :count)
    for row in eachrow(classification_counts)
        percentage = round(100 * row.count / nrow(df_refined), digits=1)
        println("  • $(row.critical_point_type): $(row.count) points ($(percentage)%)")
    end
end

# Step 3: Point matching analysis
println("\n=== Step 3: Point Matching Analysis ===")
matches = Globtim.match_raw_to_refined_points(df_raw, df_refined)
println("Successfully matched $(length(matches)) point pairs")

# Show distance statistics
distances = [match[3] for match in matches]
println("Distance statistics:")
println("  • Mean: $(round(mean(distances), digits=4))")
println("  • Median: $(round(median(distances), digits=4))")
println("  • Range: [$(round(minimum(distances), digits=4)), $(round(maximum(distances), digits=4))]")

# Show closest and farthest pairs
sorted_matches = sort(matches, by=x -> x[3])
println("\nClosest pair:")
close_match = sorted_matches[1]
println("  • Distance: $(round(close_match[3], digits=4))")
println("  • Raw point: $(round.(df_raw[close_match[1], [:x1, :x2]], digits=3))")
println("  • Refined point: $(round.(df_refined[close_match[2], [:x1, :x2]], digits=3))")

println("\nFarthest pair:")
far_match = sorted_matches[end]
println("  • Distance: $(round(far_match[3], digits=4))")
println("  • Raw point: $(round.(df_raw[far_match[1], [:x1, :x2]], digits=3))")
println("  • Refined point: $(round.(df_refined[far_match[2], [:x1, :x2]], digits=3))")

# Step 4: Create comparative eigenvalue visualization
println("\n=== Step 4: Comparative Eigenvalue Visualization ===")
println("Creating raw vs refined eigenvalue comparison plots...")
println("Features:")
println("  • Pairwise matching based on minimal Euclidean distance")
println("  • Distance-based left-to-right ordering (closest pairs first)")
println("  • Vertical columns: raw (top, lighter) vs refined (bottom, darker)")
println("  • Connecting lines show eigenvalue evolution")
println("  • Distance annotations for each pair")
println("  • Separate subplots by critical point type")

# Main comparative visualization
println("\n1. Distance-ordered comparison (default):")
fig1 = plot_raw_vs_refined_eigenvalues(f, df_raw, df_refined)
display(fig1)

println("\n2. Function value difference ordering:")
fig2 = plot_raw_vs_refined_eigenvalues(f, df_raw, df_refined, sort_by=:function_value_diff)
display(fig2)

# Analysis of eigenvalue changes
println("\n=== Step 5: Eigenvalue Change Analysis ===")

# Extract eigenvalues for analysis
raw_eigenvalues = Globtim.extract_all_eigenvalues_for_visualization(f, df_raw)
refined_eigenvalues = Globtim.extract_all_eigenvalues_for_visualization(f, df_refined)

# Analyze eigenvalue changes for matched pairs
eigenvalue_changes = []
for (raw_idx, refined_idx, distance) in matches
    raw_eigs = raw_eigenvalues[raw_idx]
    refined_eigs = refined_eigenvalues[refined_idx]
    
    if !any(isnan, raw_eigs) && !any(isnan, refined_eigs)
        # Compute L2 norm of eigenvalue difference
        raw_sorted = sort(raw_eigs)
        refined_sorted = sort(refined_eigs)
        
        if length(raw_sorted) == length(refined_sorted)
            eig_change = norm(raw_sorted - refined_sorted)
            push!(eigenvalue_changes, eig_change)
        end
    end
end

if !isempty(eigenvalue_changes)
    println("Eigenvalue change statistics (L2 norm):")
    println("  • Mean: $(round(mean(eigenvalue_changes), digits=6))")
    println("  • Median: $(round(median(eigenvalue_changes), digits=6))")
    println("  • Max: $(round(maximum(eigenvalue_changes), digits=6))")
    println("  • Min: $(round(minimum(eigenvalue_changes), digits=6))")
    
    # Identify pairs with largest eigenvalue changes
    sorted_changes = sort(enumerate(eigenvalue_changes), by=x -> x[2], rev=true)
    println("\nTop 3 pairs with largest eigenvalue changes:")
    for i in 1:min(3, length(sorted_changes))
        pair_idx, change = sorted_changes[i]
        match = matches[pair_idx]
        raw_idx, refined_idx, distance = match
        
        println("  $i. Change: $(round(change, digits=6)), Distance: $(round(distance, digits=4))")
        println("     Raw: $(round.(df_raw[raw_idx, [:x1, :x2]], digits=3))")
        println("     Refined: $(round.(df_refined[refined_idx, [:x1, :x2]], digits=3))")
    end
end

# Step 6: Show standard eigenvalue plots for comparison
println("\n=== Step 6: Standard Eigenvalue Visualizations (for comparison) ===")

println("Standard all-eigenvalues plot (refined points only):")
fig3 = plot_all_eigenvalues(f, df_refined, sort_by=:magnitude)
display(fig3)

println("\n=== Demo Complete ===")
println("The raw vs refined comparison reveals:")
println("  • How BFGS refinement affects eigenvalue magnitudes")
println("  • Which critical points move most during refinement")
println("  • Distance correlation with eigenvalue stability")
println("  • Visual validation of numerical refinement quality")