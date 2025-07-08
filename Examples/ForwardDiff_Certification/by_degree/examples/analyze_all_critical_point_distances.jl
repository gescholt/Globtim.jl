# ================================================================================
# Analysis of Distances to ALL Critical Points (not just minima)
# ================================================================================
#
# This module analyzes how well Globtim recovers ALL theoretical critical points
# (minima and saddles) by computing distances from theoretical points to nearest
# computed points across polynomial degrees.
#
# ================================================================================

using DataFrames, CSV
using LinearAlgebra
using Statistics
using CairoMakie
using Printf

"""
    analyze_critical_point_distances(computed_points_by_degree, degrees; threshold)

Analyze distances from ALL theoretical critical points to computed points.

# Arguments
- `computed_points_by_degree`: Dict mapping degree to all computed critical points
- `degrees`: Vector of polynomial degrees
- `threshold`: Distance threshold for considering a point "captured"

# Returns
- `results_df`: DataFrame with distance statistics by degree
"""
function analyze_critical_point_distances(
    computed_points_by_degree::Dict{Int, Vector{Vector{Float64}}},
    degrees::Vector{Int};
    threshold::Float64 = 0.1
)
    # Load all theoretical critical points
    println("📊 Loading theoretical critical points...")
    df = CSV.read(joinpath(@__DIR__, "../data/4d_all_critical_points_orthant.csv"), DataFrame)
    
    # Determine dimensionality from df columns
    dim_cols = [col for col in names(df) if startswith(String(col), "x")]
    n_dims = length(dim_cols)
    
    theoretical_points = [[row[Symbol("x$i")] for i in 1:n_dims] for row in eachrow(df)]
    
    println("   Found $(length(theoretical_points)) theoretical critical points")
    
    # Compute distance statistics for each degree
    results = []
    all_distances_by_degree = Dict{Int, Vector{Float64}}()
    
    for degree in degrees
        computed = computed_points_by_degree[degree]
        
        if isempty(computed)
            push!(results, (
                degree = degree,
                n_computed = 0,
                min_distance = NaN,
                median_distance = NaN,
                mean_distance = NaN,
                max_distance = NaN,
                q1_distance = NaN,
                q3_distance = NaN,
                n_captured = 0,
                capture_rate = 0.0
            ))
            all_distances_by_degree[degree] = Float64[]
            continue
        end
        
        # Distance from each theoretical point to nearest computed point
        distances = Float64[]
        for t_point in theoretical_points
            min_dist = minimum(norm(t_point - c_point) for c_point in computed)
            push!(distances, min_dist)
        end
        
        # Store all distances for this degree
        all_distances_by_degree[degree] = distances
        
        # Count how many theoretical points are "captured" (within threshold)
        n_captured = sum(distances .< threshold)
        
        # Compute quartiles
        q1 = quantile(distances, 0.25)
        q3 = quantile(distances, 0.75)
        
        push!(results, (
            degree = degree,
            n_computed = length(computed),
            min_distance = minimum(distances),
            median_distance = median(distances),
            mean_distance = mean(distances),
            max_distance = maximum(distances),
            q1_distance = q1,
            q3_distance = q3,
            n_captured = n_captured,
            capture_rate = 100.0 * n_captured / length(theoretical_points)
        ))
    end
    
    results_df = DataFrame(results)
    
    # Display summary
    println("\n📈 Critical Point Distance Analysis Summary:")
    println("   Theoretical critical points: $(length(theoretical_points))")
    println("   Distance threshold: $threshold")
    println("\n   Degree | Computed | Min Dist | Q1 Dist  | Median   | Q3 Dist  | Max Dist | Captured | Rate")
    println("   " * "-"^95)
    
    for row in eachrow(results_df)
        @printf("   %6d | %8d | %8.2e | %8.2e | %8.2e | %8.2e | %8.2e | %8d | %4.1f%%\n",
                row.degree, row.n_computed, row.min_distance, row.q1_distance, 
                row.median_distance, row.q3_distance, row.max_distance,
                row.n_captured, row.capture_rate)
    end
    
    return results_df
end

"""
    plot_critical_point_distances(results_df; output_file)

Create a convergence plot showing distance statistics across degrees.

# Arguments
- `results_df`: DataFrame from analyze_critical_point_distances
- `output_file`: Where to save the plot
"""
function plot_critical_point_distances(results_df::DataFrame; 
                                     output_file::String = "critical_point_distances.png")
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1],
              xlabel = "Polynomial Degree",
              ylabel = "Distance to Nearest Computed Point",
              yscale = log10)
    
    # Plot only mean distance with enhanced visualization
    lines!(ax, results_df.degree, results_df.mean_distance,
           linewidth=3, color=:darkblue, label="Mean")
    scatter!(ax, results_df.degree, results_df.mean_distance,
             markersize=12, color=:darkblue)
    
    # Add vertical bars showing quartiles at each degree
    for row in eachrow(results_df)
        # Use actual quartiles from the data
        q1 = row.q1_distance
        q3 = row.q3_distance
        
        # Skip if NaN
        if isnan(q1) || isnan(q3)
            continue
        end
        
        # Draw vertical line from Q1 to Q3
        lines!(ax, [row.degree, row.degree], [q1, q3], 
               color=(:darkblue, 0.4), linewidth=8)
        
        # Add horizontal ticks at quartiles
        tick_width = 0.15
        lines!(ax, [row.degree - tick_width/2, row.degree + tick_width/2], [q1, q1],
               color=:darkblue, linewidth=2)
        lines!(ax, [row.degree - tick_width/2, row.degree + tick_width/2], [q3, q3],
               color=:darkblue, linewidth=2)
    end
    
    # Set x-axis ticks to match degrees
    ax.xticks = results_df.degree
    xlims!(ax, minimum(results_df.degree) - 0.5, maximum(results_df.degree) + 0.5)
    
    # Save and display
    save(output_file, fig)
    display(fig)
    
    # Also create a capture rate plot
    fig2 = Figure(size=(800, 600))
    ax2 = Axis(fig2[1, 1],
               xlabel = "Polynomial Degree",
               ylabel = "Capture Rate (%)")
    
    lines!(ax2, results_df.degree, results_df.capture_rate,
           linewidth=3, color=:purple)
    scatter!(ax2, results_df.degree, results_df.capture_rate,
             markersize=12, color=:purple)
    
    # Add horizontal line at 100%
    hlines!(ax2, [100.0], color=:gray, linestyle=:dash, alpha=0.5)
    
    # Set y-axis limits
    ylims!(ax2, 0, 105)
    
    # Save capture rate plot
    capture_file = replace(output_file, ".png" => "_capture_rate.png")
    save(capture_file, fig2)
    display(fig2)
    
    println("\n✅ Plots saved:")
    println("   - $output_file")
    println("   - $capture_file")
end