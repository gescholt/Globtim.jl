"""
    EnhancedPlottingUtilities

A module providing advanced plotting functions for visualizing polynomial approximation
convergence and optimization results. Designed to work with the enhanced data structures
from the by_degree framework.
"""
module EnhancedPlottingUtilities

using CairoMakie
using GLMakie
using DataFrames
using Statistics
using Printf

# Import the enhanced data structure
include("EnhancedAnalysisUtilities.jl")
using .EnhancedAnalysisUtilities: EnhancedDegreeAnalysisResult

export plot_l2_convergence_dual_scale, plot_min_min_distances_dual_scale, plot_critical_point_recovery_histogram, plot_min_min_capture_methods

"""
    plot_l2_convergence_dual_scale(results; title="", tolerance_line=nothing, 
                                  save_plots=false, plots_directory="plots")

Create a dual-scale plot showing L² convergence for both subdomain and full domain scales.

# Arguments
- `results`: Can be either:
  - A Dict{String,Vector{EnhancedDegreeAnalysisResult}} for multi-domain
  - A DataFrame with columns [:degree, :l2_norm, :converged] for single domain
- `title::String=""`: Plot title
- `tolerance_line::Union{Nothing,Float64}=nothing`: Optional horizontal tolerance line
- `save_plots::Bool=false`: Whether to save plots to files (default: display in window)
- `plots_directory::String="plots"`: Directory for saving plots if save_plots=true

# Returns
- `fig`: The Makie figure object

# Example
```julia
# For multi-domain case
subdomain_results = Dict(
    "0000" => [result1, result2, ...],  # Vector of EnhancedDegreeAnalysisResult
    "0001" => [result1, result2, ...]
)
fig = plot_l2_convergence_dual_scale(subdomain_results, title="Multi-Domain")

# For single domain case
single_results = DataFrame(degree=[2,4,6,8], l2_norm=[0.1, 0.01, 0.001, 0.0001], 
                          converged=[false, false, true, true])
fig = plot_l2_convergence_dual_scale(single_results, title="Single Domain")
```
"""
function plot_l2_convergence_dual_scale(results; 
                                      title::String="",
                                      tolerance_line::Union{Nothing,Float64}=nothing,
                                      save_plots::Bool=false, 
                                      plots_directory::String="plots")
    # Determine if we have multi-domain or single domain results
    is_multi_domain = isa(results, Dict)
    
    # Create figure
    fig = Figure(size=(1000, 600))
    
    if is_multi_domain
        # Multi-domain case with dual axes
        ax_left = Axis(fig[1, 1],
            xlabel="Polynomial Degree",
            ylabel="L² Error (Subdomain Scale)",
            title=isempty(title) ? "L² Convergence: Subdomain vs Full Domain" : title,
            yscale=log10,
            xlabelsize=16,
            ylabelsize=16,
            titlesize=18,
            yticklabelcolor=:blue,
            ylabelcolor=:blue,
            ytickcolor=:blue,
            yminorticksvisible=true,
            yminorgridvisible=true
        )
        
        ax_right = Axis(fig[1, 1],
            ylabel="L² Error (Full Domain Scale)",
            yscale=log10,
            yaxisposition=:right,
            ylabelsize=16,
            yticklabelcolor=:red,
            ylabelcolor=:red,
            ytickcolor=:red,
            yminorticksvisible=true
        )
        
        # Hide the right axis grid to avoid overlap
        ax_right.xgridvisible = false
        ax_right.ygridvisible = false
        hidespines!(ax_right, :l, :t, :b)
        
        # Plot subdomain results on left axis
        subdomain_colors = [:blue, :cyan, :teal, :navy, :dodgerblue]
        for (idx, (name, result_vec)) in enumerate(sort(collect(results), by=x->x[1]))
            if !isempty(result_vec)
                degrees = [r.degree for r in result_vec]
                l2_norms = [r.l2_norm for r in result_vec]
                color_idx = mod1(idx, length(subdomain_colors))
                lines!(ax_left, degrees, l2_norms,
                    color=subdomain_colors[color_idx],
                    linewidth=2,
                    label=name)
                scatter!(ax_left, degrees, l2_norms,
                    color=subdomain_colors[color_idx],
                    markersize=8)
            end
        end
        
        # Calculate and plot aggregated full domain results on right axis
        full_domain_data = aggregate_full_domain_errors(results)
        if !isnothing(full_domain_data)
            lines!(ax_right, full_domain_data.degree, full_domain_data.l2_error,
                color=:red,
                linewidth=3,
                linestyle=:dash,
                label="Full Domain (Aggregated)")
            scatter!(ax_right, full_domain_data.degree, full_domain_data.l2_error,
                color=:red,
                markersize=10,
                marker=:diamond)
        end
        
        # Create legend
        axislegend(ax_left, position=:rt, labelsize=12)
        axislegend(ax_right, position=:rb, labelsize=12)
        
    else
        # Single domain case - simple plot
        ax = Axis(fig[1, 1],
            xlabel="Polynomial Degree",
            ylabel="L² Error",
            title=isempty(title) ? "L² Convergence" : title,
            yscale=log10,
            xlabelsize=16,
            ylabelsize=16,
            titlesize=18,
            yminorticksvisible=true,
            yminorgridvisible=true,
            xminorticksvisible=true,
            xminorgridvisible=true
        )
        
        # Handle different input types for single domain
        if isa(results, Vector) && length(results) > 0 && hasproperty(results[1], :degree) && hasproperty(results[1], :l2_norm)
            # Extract degrees and l2_norms from vector of analysis results
            degrees = [r.degree for r in results]
            l2_norms = [r.l2_norm for r in results]
            
            lines!(ax, degrees, l2_norms,
                color=:blue,
                linewidth=2.5,
                label="L² Error")
            scatter!(ax, degrees, l2_norms,
                color=:blue,
                markersize=10)
                
            # Add convergence status markers if available
            if hasproperty(results[1], :converged)
                converged_mask = [r.converged for r in results]
                if any(converged_mask)
                    converged_degrees = degrees[converged_mask]
                    converged_l2 = l2_norms[converged_mask]
                    scatter!(ax, converged_degrees, converged_l2,
                        color=:green,
                        marker=:star5,
                        markersize=15,
                        label="Converged")
                end
            end
            
        elseif hasproperty(results, :degree) && hasproperty(results, :l2_norm)
            # DataFrame case
            lines!(ax, results.degree, results.l2_norm,
                color=:blue,
                linewidth=2.5,
                label="L² Error")
            scatter!(ax, results.degree, results.l2_norm,
                color=:blue,
                markersize=10)
        else
            error("Single domain results must be Vector{EnhancedDegreeAnalysisResult} or have :degree and :l2_norm columns")
        end
        
        axislegend(ax, position=:rt, labelsize=12)
    end
    
    # Add tolerance line if specified
    if tolerance_line !== nothing
        if is_multi_domain
            hlines!(ax_left, [tolerance_line], color=:black, linestyle=:dash, 
                   linewidth=2, label="Tolerance")
            hlines!(ax_right, [tolerance_line], color=:black, linestyle=:dash, 
                   linewidth=2)
        else
            hlines!(ax, [tolerance_line], color=:black, linestyle=:dash, 
                   linewidth=2, label="Tolerance")
        end
    end
    
    # Save or display
    if save_plots
        mkpath(plots_directory)
        filename = joinpath(plots_directory, "l2_convergence_dual_scale.png")
        save(filename, fig, px_per_unit=2)
        println("Saved plot to: $filename")
    else
        display(fig)
    end
    
    return fig
end

"""
    aggregate_full_domain_errors(subdomain_results::Dict)

Aggregate subdomain L² errors to compute full domain errors.

# Arguments
- `subdomain_results`: Dictionary of subdomain results

# Returns
- DataFrame with columns [:degree, :l2_error] for the full domain
"""
function aggregate_full_domain_errors(subdomain_results::Dict)
    # Get all unique degrees across subdomains
    all_degrees = Int[]
    for (_, result_vec) in subdomain_results
        if !isempty(result_vec)
            append!(all_degrees, [r.degree for r in result_vec])
        end
    end
    unique_degrees = sort(unique(all_degrees))
    
    if isempty(unique_degrees)
        return nothing
    end
    
    # For each degree, compute RMS of subdomain errors
    full_domain_errors = Float64[]
    valid_degrees = Int[]
    
    for deg in unique_degrees
        errors_at_degree = Float64[]
        for (_, result_vec) in subdomain_results
            for r in result_vec
                if r.degree == deg
                    push!(errors_at_degree, r.l2_norm)
                end
            end
        end
        
        if !isempty(errors_at_degree)
            # RMS aggregation for L² errors
            rms_error = sqrt(mean(errors_at_degree.^2))
            push!(full_domain_errors, rms_error)
            push!(valid_degrees, deg)
        end
    end
    
    return DataFrame(degree=valid_degrees, l2_error=full_domain_errors)
end

"""
    configure_convergence_axes!(ax::Axis; is_log_scale::Bool=true)

Configure axis properties for convergence plots.

# Arguments
- `ax`: Makie Axis object
- `is_log_scale`: Whether to use logarithmic scale for y-axis
"""
function configure_convergence_axes!(ax::Axis; is_log_scale::Bool=true)
    if is_log_scale
        ax.yscale = log10
    end
    
    # Grid styling
    ax.xminorticksvisible = true
    ax.yminorticksvisible = true
    ax.xminorgridvisible = true
    ax.yminorgridvisible = true
    ax.xgridstyle = :dash
    ax.ygridstyle = :dash
    ax.xminorgridstyle = :dot
    ax.yminorgridstyle = :dot
    
    # Font sizes
    ax.xlabelsize = 16
    ax.ylabelsize = 16
    ax.titlesize = 18
    ax.xticklabelsize = 12
    ax.yticklabelsize = 12
end

"""
    plot_min_min_distances_dual_scale(results; title="", tolerance_line=nothing,
                                     save_plots=false, plots_directory="plots")

Create a dual-scale plot showing min+min distances for both subdomain and full domain scales.
Displays both the minimal distance and average distance to min+min points.

# Arguments
- `results`: Can be either:
  - A Dict{String,Vector{EnhancedDegreeAnalysisResult}} for multi-domain
  - A DataFrame with columns [:degree, :min_min_distances] for single domain
- `title::String=""`: Plot title
- `tolerance_line::Union{Nothing,Float64}=nothing`: Optional horizontal tolerance line
- `save_plots::Bool=false`: Whether to save plots to files (default: display in window)
- `plots_directory::String="plots"`: Directory for saving plots if save_plots=true

# Returns
- `fig`: The Makie figure object

# Example
```julia
# For multi-domain case
subdomain_results = Dict(
    "0000" => [result1, result2, ...],  # Vector of EnhancedDegreeAnalysisResult
    "0001" => [result1, result2, ...]
)
fig = plot_min_min_distances_dual_scale(subdomain_results, title="Min+Min Distances")

# For single domain case
single_results = DataFrame(degree=[2,4,6,8], 
                          min_min_distances=[[0.1, 0.15], [0.01, 0.02], [0.001, 0.002], [0.0001, 0.0002]])
fig = plot_min_min_distances_dual_scale(single_results, title="Single Domain Min+Min")
```
"""
function plot_min_min_distances_dual_scale(results; 
                                         title::String="",
                                         tolerance_line::Union{Nothing,Float64}=nothing,
                                         save_plots::Bool=false, 
                                         plots_directory::String="plots")
    # Determine if we have multi-domain or single domain results
    is_multi_domain = isa(results, Dict)
    
    # Create figure
    fig = Figure(size=(1000, 600))
    
    if is_multi_domain
        # Multi-domain case with dual axes
        ax_left = Axis(fig[1, 1],
            xlabel="Polynomial Degree",
            ylabel="Min+Min Distance (Subdomain Scale)",
            title=isempty(title) ? "Min+Min Distance Convergence: Subdomain vs Full Domain" : title,
            yscale=log10,
            xlabelsize=16,
            ylabelsize=16,
            titlesize=18,
            yticklabelcolor=:blue,
            ylabelcolor=:blue,
            ytickcolor=:blue,
            yminorticksvisible=true,
            yminorgridvisible=true
        )
        
        ax_right = Axis(fig[1, 1],
            ylabel="Min+Min Distance (Full Domain Scale)",
            yscale=log10,
            yaxisposition=:right,
            ylabelsize=16,
            yticklabelcolor=:red,
            ylabelcolor=:red,
            ytickcolor=:red,
            yminorticksvisible=true
        )
        
        # Hide the right axis grid to avoid overlap
        ax_right.xgridvisible = false
        ax_right.ygridvisible = false
        hidespines!(ax_right, :l, :t, :b)
        
        # Plot subdomain results on left axis
        subdomain_colors = [:blue, :cyan, :teal, :navy, :dodgerblue]
        for (idx, (name, result_vec)) in enumerate(sort(collect(results), by=x->x[1]))
            if !isempty(result_vec)
                min_distances = [minimum(r.min_min_distances) for r in result_vec if !isempty(r.min_min_distances)]
                avg_distances = [mean(r.min_min_distances) for r in result_vec if !isempty(r.min_min_distances)]
                valid_degrees = [r.degree for r in result_vec if !isempty(r.min_min_distances)]
                
                if !isempty(valid_degrees)
                    color_idx = mod1(idx, length(subdomain_colors))
                    # Plot minimum distances as solid line
                    lines!(ax_left, valid_degrees, min_distances,
                        color=subdomain_colors[color_idx],
                        linewidth=2.5,
                        label="$name (min)")
                    scatter!(ax_left, valid_degrees, min_distances,
                        color=subdomain_colors[color_idx],
                        markersize=8)
                    
                    # Plot average distances as dashed line
                    lines!(ax_left, valid_degrees, avg_distances,
                        color=subdomain_colors[color_idx],
                        linewidth=2,
                        linestyle=:dash,
                        label="$name (avg)")
                    scatter!(ax_left, valid_degrees, avg_distances,
                        color=subdomain_colors[color_idx],
                        markersize=6,
                        marker=:utriangle)
                end
            end
        end
        
        # Calculate and plot aggregated full domain results on right axis
        full_domain_data = aggregate_full_domain_min_min_distances(results)
        if !isnothing(full_domain_data)
            # Plot minimum of minimums
            lines!(ax_right, full_domain_data.degree, full_domain_data.min_distance,
                color=:red,
                linewidth=3,
                label="Full Domain (min)")
            scatter!(ax_right, full_domain_data.degree, full_domain_data.min_distance,
                color=:red,
                markersize=10,
                marker=:diamond)
            
            # Plot average of minimums
            lines!(ax_right, full_domain_data.degree, full_domain_data.avg_distance,
                color=:darkgreen,
                linewidth=3,
                linestyle=:dash,
                label="Full Domain (avg)")
            scatter!(ax_right, full_domain_data.degree, full_domain_data.avg_distance,
                color=:darkgreen,
                markersize=10,
                marker=:rect)
        end
        
        # Create legend
        axislegend(ax_left, position=:rt, labelsize=10, nbanks=2)
        axislegend(ax_right, position=:rb, labelsize=12)
        
    else
        # Single domain case - simple plot
        ax = Axis(fig[1, 1],
            xlabel="Polynomial Degree",
            ylabel="Min+Min Distance",
            title=isempty(title) ? "Min+Min Distance Convergence" : title,
            yscale=log10,
            xlabelsize=16,
            ylabelsize=16,
            titlesize=18,
            yminorticksvisible=true,
            yminorgridvisible=true,
            xminorticksvisible=true,
            xminorgridvisible=true
        )
        
        # Handle different input types for single domain
        if isa(results, Vector) && length(results) > 0 && hasproperty(results[1], :degree) && hasproperty(results[1], :min_min_distances)
            # Extract data from vector of analysis results
            valid_degrees = Int[]
            min_distances = Float64[]
            avg_distances = Float64[]
            
            for result in results
                if !isempty(result.min_min_distances)
                    push!(valid_degrees, result.degree)
                    push!(min_distances, minimum(result.min_min_distances))
                    push!(avg_distances, mean(result.min_min_distances))
                end
            end
            
            if !isempty(valid_degrees)
                # Plot minimum distances
                lines!(ax, valid_degrees, min_distances,
                    color=:blue,
                    linewidth=3,
                    label="Minimum Distance")
                scatter!(ax, valid_degrees, min_distances,
                    color=:blue,
                    markersize=10)
                
                # Plot average distances
                lines!(ax, valid_degrees, avg_distances,
                    color=:green,
                    linewidth=2.5,
                    linestyle=:dash,
                    label="Average Distance")
                scatter!(ax, valid_degrees, avg_distances,
                    color=:green,
                    markersize=8,
                    marker=:utriangle)
                
                axislegend(ax, position=:rt, labelsize=12)
            end
            
        elseif hasproperty(results, :degree) && hasproperty(results, :min_min_distances)
            # DataFrame case
            valid_degrees = Int[]
            min_distances = Float64[]
            avg_distances = Float64[]
            
            for i in 1:nrow(results)
                if !isempty(results.min_min_distances[i])
                    push!(valid_degrees, results.degree[i])
                    push!(min_distances, minimum(results.min_min_distances[i]))
                    push!(avg_distances, mean(results.min_min_distances[i]))
                end
            end
            
            if !isempty(valid_degrees)
                # Plot minimum distances
                lines!(ax, valid_degrees, min_distances,
                    color=:blue,
                    linewidth=3,
                    label="Minimum Distance")
                scatter!(ax, valid_degrees, min_distances,
                    color=:blue,
                    markersize=10)
                
                # Plot average distances
                lines!(ax, valid_degrees, avg_distances,
                    color=:green,
                    linewidth=2.5,
                    linestyle=:dash,
                    label="Average Distance")
                scatter!(ax, valid_degrees, avg_distances,
                    color=:green,
                    markersize=8,
                    marker=:utriangle)
                
                axislegend(ax, position=:rt, labelsize=12)
            end
        else
            error("Single domain results must be Vector of results with :degree and :min_min_distances or DataFrame")
        end
    end
    
    # Add tolerance line if specified
    if tolerance_line !== nothing
        if is_multi_domain
            hlines!(ax_left, [tolerance_line], color=:black, linestyle=:dot, 
                   linewidth=2, label="Tolerance")
            hlines!(ax_right, [tolerance_line], color=:black, linestyle=:dot, 
                   linewidth=2)
        else
            hlines!(ax, [tolerance_line], color=:black, linestyle=:dot, 
                   linewidth=2, label="Tolerance")
        end
    end
    
    # Save or display
    if save_plots
        mkpath(plots_directory)
        filename = joinpath(plots_directory, "min_min_distances_dual_scale.png")
        save(filename, fig, px_per_unit=2)
        println("Saved plot to: $filename")
    else
        display(fig)
    end
    
    return fig
end

"""
    aggregate_full_domain_min_min_distances(subdomain_results::Dict)

Aggregate subdomain min+min distances to compute full domain statistics.

# Arguments
- `subdomain_results`: Dictionary of subdomain results

# Returns
- DataFrame with columns [:degree, :min_distance, :avg_distance] for the full domain
"""
function aggregate_full_domain_min_min_distances(subdomain_results::Dict)
    # Get all unique degrees across subdomains
    all_degrees = Int[]
    for (_, result_vec) in subdomain_results
        if !isempty(result_vec)
            append!(all_degrees, [r.degree for r in result_vec])
        end
    end
    unique_degrees = sort(unique(all_degrees))
    
    if isempty(unique_degrees)
        return nothing
    end
    
    # For each degree, compute min and average across all subdomain min distances
    full_domain_min_distances = Float64[]
    full_domain_avg_distances = Float64[]
    valid_degrees = Int[]
    
    for deg in unique_degrees
        all_min_distances = Float64[]
        for (_, result_vec) in subdomain_results
            for r in result_vec
                if r.degree == deg && !isempty(r.min_min_distances)
                    # Collect the minimum distance from each subdomain
                    push!(all_min_distances, minimum(r.min_min_distances))
                end
            end
        end
        
        if !isempty(all_min_distances)
            # Global minimum across all subdomains
            push!(full_domain_min_distances, minimum(all_min_distances))
            # Average of minimum distances across subdomains
            push!(full_domain_avg_distances, mean(all_min_distances))
            push!(valid_degrees, deg)
        end
    end
    
    return DataFrame(degree=valid_degrees, 
                    min_distance=full_domain_min_distances,
                    avg_distance=full_domain_avg_distances)
end

"""
    plot_critical_point_recovery_histogram(results; title="", save_plots=false, plots_directory="plots")

Create a stacked histogram showing critical point recovery across polynomial degrees.
The histogram has three layers:
1. Bottom layer: Min+min points captured (solid dark blue)
2. Middle layer: Other critical points captured (medium blue)
3. Top layer: Total theoretical points (light transparent blue)

# Arguments
- `results`: Can be either:
  - A Dict{String,Vector{EnhancedDegreeAnalysisResult}} for multi-domain
  - A Vector{EnhancedDegreeAnalysisResult} for single domain
- `title::String=""`: Plot title
- `save_plots::Bool=false`: Whether to save plots to files (default: display in window)
- `plots_directory::String="plots"`: Directory for saving plots if save_plots=true

# Returns
- `fig`: The Makie figure object

# Example
```julia
# For multi-domain case
subdomain_results = Dict(
    "0000" => [result1, result2, ...],  # Vector of EnhancedDegreeAnalysisResult
    "0001" => [result1, result2, ...]
)
fig = plot_critical_point_recovery_histogram(subdomain_results, title="Critical Point Recovery")

# For single domain case
single_results = [result1, result2, ...]  # Vector of EnhancedDegreeAnalysisResult
fig = plot_critical_point_recovery_histogram(single_results, title="Single Domain Recovery")
```
"""
function plot_critical_point_recovery_histogram(results; 
                                              title::String="",
                                              save_plots::Bool=false, 
                                              plots_directory::String="plots")
    # Determine if we have multi-domain or single domain results
    is_multi_domain = isa(results, Dict)
    
    # Create figure
    fig = Figure(size=(1000, 700))
    
    # Create main axis
    ax = Axis(fig[1, 1],
        xlabel="Polynomial Degree",
        ylabel="Number of Points",
        title=isempty(title) ? "Critical Point Recovery by Degree" : title,
        xlabelsize=16,
        ylabelsize=16,
        titlesize=18,
        xminorticksvisible=true,
        xminorgridvisible=true,
        yminorticksvisible=true,
        yminorgridvisible=true
    )
    
    if is_multi_domain
        # Aggregate data across all subdomains
        degree_data = Dict{Int, Tuple{Int, Int, Int}}()  # degree => (min_min_count, other_count, theoretical_count)
        
        for (subdomain_name, result_vec) in results
            for result in result_vec
                deg = result.degree
                
                # Count min+min points captured
                min_min_count = count(result.min_min_within_tolerance)
                
                # Total computed points
                total_computed = result.n_computed_points
                
                # Other critical points = total - min+min
                other_count = max(0, total_computed - min_min_count)
                
                # Theoretical points (should be consistent across subdomains)
                theoretical = result.n_theoretical_points
                
                # Aggregate across subdomains
                if haskey(degree_data, deg)
                    prev_min_min, prev_other, prev_theoretical = degree_data[deg]
                    degree_data[deg] = (prev_min_min + min_min_count, 
                                      prev_other + other_count,
                                      theoretical)  # Theoretical should be same for all subdomains
                else
                    degree_data[deg] = (min_min_count, other_count, theoretical)
                end
            end
        end
        
        # Sort degrees for plotting
        sorted_degrees = sort(collect(keys(degree_data)))
        
        # Prepare data for stacked bar plot
        degrees = Float64[]
        min_min_counts = Float64[]
        other_counts = Float64[]
        theoretical_counts = Float64[]
        
        for deg in sorted_degrees
            min_min, other, theoretical = degree_data[deg]
            push!(degrees, Float64(deg))
            push!(min_min_counts, Float64(min_min))
            push!(other_counts, Float64(other))
            push!(theoretical_counts, Float64(theoretical))
        end
        
    else
        # Single domain case - extract data directly
        degrees = Float64[]
        min_min_counts = Float64[]
        other_counts = Float64[]
        theoretical_counts = Float64[]
        
        for result in results
            push!(degrees, Float64(result.degree))
            
            # Count min+min points captured
            min_min_count = count(result.min_min_within_tolerance)
            push!(min_min_counts, Float64(min_min_count))
            
            # Other critical points
            other_count = max(0, result.n_computed_points - min_min_count)
            push!(other_counts, Float64(other_count))
            
            # Theoretical points
            push!(theoretical_counts, Float64(result.n_theoretical_points))
        end
    end
    
    # Create stacked bar plot
    bar_width = 0.8
    
    # Create stacked data for plotting
    # We'll use a grouped approach instead of stacking
    
    # Calculate cumulative heights for stacking effect
    bottom_layer = zeros(length(degrees))  # Start at 0
    middle_layer = min_min_counts  # Top of first layer
    top_layer = min_min_counts .+ other_counts  # Top of second layer
    
    # Calculate remaining points
    remaining_counts = theoretical_counts .- (min_min_counts .+ other_counts)
    remaining_counts = max.(remaining_counts, 0.0)  # Ensure non-negative
    
    # Plot as separate bars with manual positioning to create stacking effect
    # Layer 1: Min+min points (dark blue, bottom)
    for (i, deg) in enumerate(degrees)
        if min_min_counts[i] > 0
            poly!(ax, 
                  [deg - bar_width/2, deg - bar_width/2, deg + bar_width/2, deg + bar_width/2],
                  [0, min_min_counts[i], min_min_counts[i], 0],
                  color=:darkblue)
        end
    end
    
    # Layer 2: Other critical points (dodger blue, middle)
    for (i, deg) in enumerate(degrees)
        if other_counts[i] > 0
            poly!(ax,
                  [deg - bar_width/2, deg - bar_width/2, deg + bar_width/2, deg + bar_width/2],
                  [middle_layer[i], middle_layer[i] + other_counts[i], 
                   middle_layer[i] + other_counts[i], middle_layer[i]],
                  color=:dodgerblue)
        end
    end
    
    # Layer 3: Remaining theoretical points (light blue transparent, top)
    for (i, deg) in enumerate(degrees)
        if remaining_counts[i] > 0
            poly!(ax,
                  [deg - bar_width/2, deg - bar_width/2, deg + bar_width/2, deg + bar_width/2],
                  [top_layer[i], top_layer[i] + remaining_counts[i],
                   top_layer[i] + remaining_counts[i], top_layer[i]],
                  color=(:lightblue, 0.5))
        end
    end
    
    # Add legend entries manually
    # Create dummy plots for legend
    scatter!(ax, [NaN], [NaN], color=:darkblue, marker=:rect, markersize=15,
             label="Min+Min Points Captured")
    scatter!(ax, [NaN], [NaN], color=:dodgerblue, marker=:rect, markersize=15,
             label="Other Critical Points")
    scatter!(ax, [NaN], [NaN], color=(:lightblue, 0.5), marker=:rect, markersize=15,
             label="Theoretical Points (Not Found)")
    
    # Add horizontal reference line at 9 for min+min count
    expected_min_min = is_multi_domain ? 9 * length(results) : 9
    hlines!(ax, [expected_min_min], 
           color=:black, 
           linestyle=:dash, 
           linewidth=2, 
           label="Expected Min+Min ($(expected_min_min))")
    
    # Configure axis
    ax.xticks = degrees
    xlims!(ax, minimum(degrees) - 1, maximum(degrees) + 1)
    
    # Set y-axis limits to show full theoretical count
    max_theoretical = maximum(theoretical_counts)
    ylims!(ax, 0, max_theoretical * 1.1)
    
    # Add legend
    axislegend(ax, position=:lt, labelsize=12, framevisible=true)
    
    # Add grid for better readability
    ax.xgridstyle = :dash
    ax.ygridstyle = :dash
    ax.xminorgridstyle = :dot
    ax.yminorgridstyle = :dot
    
    # Save or display
    if save_plots
        mkpath(plots_directory)
        filename = joinpath(plots_directory, "critical_point_recovery_histogram.png")
        save(filename, fig, px_per_unit=2)
        println("Saved plot to: $filename")
    else
        display(fig)
    end
    
    return fig
end

"""
    plot_min_min_capture_methods(results; title="", show_percentages=false,
                                save_plots=false, plots_directory="plots")

Create a grouped bar chart showing how min+min points were captured:
1. Direct tolerance capture (green bars) - found within tolerance without BFGS
2. BFGS refinement capture (orange bars) - found only after BFGS refinement
3. Not found (red bars) - min+min points not captured

# Arguments
- `results`: Can be either:
  - A Dict{String,Vector{EnhancedDegreeAnalysisResult}} for multi-domain
  - A Vector{EnhancedDegreeAnalysisResult} for single domain
- `title::String=""`: Plot title
- `show_percentages::Bool=false`: Show percentages instead of counts (default: counts)
- `save_plots::Bool=false`: Whether to save plots to files (default: display in window)
- `plots_directory::String="plots"`: Directory for saving plots if save_plots=true

# Returns
- `fig`: The Makie figure object

# Example
```julia
# For multi-domain case
subdomain_results = Dict(
    "0000" => [result1, result2, ...],  # Vector of EnhancedDegreeAnalysisResult
    "0001" => [result1, result2, ...]
)
fig = plot_min_min_capture_methods(subdomain_results, title="Min+Min Capture Methods")

# For single domain case
single_results = [result1, result2, ...]  # Vector of EnhancedDegreeAnalysisResult
fig = plot_min_min_capture_methods(single_results, show_percentages=true)
```
"""
function plot_min_min_capture_methods(results; 
                                    title::String="",
                                    show_percentages::Bool=false,
                                    save_plots::Bool=false, 
                                    plots_directory::String="plots")
    # Determine if we have multi-domain or single domain results
    is_multi_domain = isa(results, Dict)
    
    # Create figure
    fig = Figure(size=(1000, 700))
    
    # Create main axis
    ax = Axis(fig[1, 1],
        xlabel="Polynomial Degree",
        ylabel=show_percentages ? "Percentage of Min+Min Points" : "Number of Min+Min Points",
        title=isempty(title) ? "Min+Min Point Capture Methods by Degree" : title,
        xlabelsize=16,
        ylabelsize=16,
        titlesize=18,
        xminorticksvisible=true,
        xminorgridvisible=true,
        yminorticksvisible=true,
        yminorgridvisible=true
    )
    
    if is_multi_domain
        # Aggregate data across all subdomains
        degree_data = Dict{Int, Tuple{Int, Int, Int, Int}}()  # degree => (direct, bfgs, not_found, total_expected)
        
        for (_, result_vec) in results
            for result in result_vec
                deg = result.degree
                
                # Calculate capture methods
                direct_capture = sum(result.min_min_within_tolerance .& .!result.min_min_found_by_bfgs)
                bfgs_capture = sum(result.min_min_found_by_bfgs)
                total_found = sum(result.min_min_within_tolerance)
                not_found = 9 - total_found  # 9 min+min per subdomain
                
                # Aggregate across subdomains
                if haskey(degree_data, deg)
                    prev_direct, prev_bfgs, prev_not_found, prev_total = degree_data[deg]
                    degree_data[deg] = (prev_direct + direct_capture, 
                                      prev_bfgs + bfgs_capture,
                                      prev_not_found + not_found,
                                      prev_total + 9)
                else
                    degree_data[deg] = (direct_capture, bfgs_capture, not_found, 9)
                end
            end
        end
        
        # Sort degrees for plotting
        sorted_degrees = sort(collect(keys(degree_data)))
        
        # Prepare data for grouped bar plot
        degrees = Float64[]
        direct_counts = Float64[]
        bfgs_counts = Float64[]
        not_found_counts = Float64[]
        total_expected = Float64[]
        
        for deg in sorted_degrees
            direct, bfgs, not_found, total = degree_data[deg]
            push!(degrees, Float64(deg))
            
            if show_percentages
                total_min_min = Float64(total)
                push!(direct_counts, 100.0 * direct / total_min_min)
                push!(bfgs_counts, 100.0 * bfgs / total_min_min)
                push!(not_found_counts, 100.0 * not_found / total_min_min)
            else
                push!(direct_counts, Float64(direct))
                push!(bfgs_counts, Float64(bfgs))
                push!(not_found_counts, Float64(not_found))
            end
            push!(total_expected, Float64(total))
        end
        
    else
        # Single domain case - extract data directly
        degrees = Float64[]
        direct_counts = Float64[]
        bfgs_counts = Float64[]
        not_found_counts = Float64[]
        
        for result in results
            push!(degrees, Float64(result.degree))
            
            # Calculate capture methods - handle potentially missing fields
            if hasproperty(result, :min_min_within_tolerance) && hasproperty(result, :min_min_found_by_bfgs)
                direct_capture = sum(result.min_min_within_tolerance .& .!result.min_min_found_by_bfgs)
                bfgs_capture = sum(result.min_min_found_by_bfgs)
                total_found = sum(result.min_min_within_tolerance)
                not_found = 9 - total_found  # 9 min+min expected
            else
                # If fields are missing, assume all min+min were not found
                direct_capture = 0
                bfgs_capture = 0
                not_found = 9
            end
            
            if show_percentages
                push!(direct_counts, 100.0 * direct_capture / 9.0)
                push!(bfgs_counts, 100.0 * bfgs_capture / 9.0)
                push!(not_found_counts, 100.0 * not_found / 9.0)
            else
                push!(direct_counts, Float64(direct_capture))
                push!(bfgs_counts, Float64(bfgs_capture))
                push!(not_found_counts, Float64(not_found))
            end
        end
    end
    
    # Create grouped bar plot
    bar_width = 0.25
    
    # Calculate positions for each group
    x_positions = degrees
    x_direct = x_positions .- bar_width
    x_bfgs = x_positions
    x_not_found = x_positions .+ bar_width
    
    # Plot bars
    barplot!(ax, x_direct, direct_counts, 
            width=bar_width, 
            color=:green,
            label="Direct Tolerance Capture")
    
    barplot!(ax, x_bfgs, bfgs_counts, 
            width=bar_width, 
            color=:orange,
            label="BFGS Refinement Capture")
    
    barplot!(ax, x_not_found, not_found_counts, 
            width=bar_width, 
            color=:red,
            label="Not Found")
    
    # Add horizontal reference line
    if !show_percentages
        expected_min_min = is_multi_domain ? 9 * length(results) : 9
        hlines!(ax, [expected_min_min], 
               color=:black, 
               linestyle=:dash, 
               linewidth=2, 
               label="Expected Min+Min ($(expected_min_min))")
    else
        hlines!(ax, [100.0], 
               color=:black, 
               linestyle=:dash, 
               linewidth=2, 
               label="100%")
    end
    
    # Configure axis
    ax.xticks = degrees
    xlims!(ax, minimum(degrees) - 0.5, maximum(degrees) + 0.5)
    
    # Set y-axis limits
    if show_percentages
        ylims!(ax, 0, 105)
    else
        max_count = is_multi_domain ? 9 * length(results) : 9
        ylims!(ax, 0, max_count * 1.1)
    end
    
    # Add legend
    axislegend(ax, position=:rt, labelsize=12, framevisible=true)
    
    # Add grid for better readability
    ax.xgridstyle = :dash
    ax.ygridstyle = :dash
    ax.xminorgridstyle = :dot
    ax.yminorgridstyle = :dot
    
    # Add summary text if space allows
    if length(degrees) <= 6
        # Calculate totals for summary
        total_direct = sum(direct_counts)
        total_bfgs = sum(bfgs_counts)
        total_not_found = sum(not_found_counts)
        
        if show_percentages
            summary_text = @sprintf("Overall: Direct %.1f%%, BFGS %.1f%%, Not Found %.1f%%",
                                  total_direct/length(degrees), 
                                  total_bfgs/length(degrees),
                                  total_not_found/length(degrees))
        else
            total_points = is_multi_domain ? 9 * length(results) * length(degrees) : 9 * length(degrees)
            summary_text = @sprintf("Total: Direct %d, BFGS %d, Not Found %d (of %d)",
                                  Int(sum(direct_counts)), 
                                  Int(sum(bfgs_counts)),
                                  Int(sum(not_found_counts)),
                                  total_points)
        end
        
        text!(ax, 0.02, 0.95, text=summary_text, 
              space=:relative,
              fontsize=14,
              align=(:left, :top))
    end
    
    # Save or display
    if save_plots
        mkpath(plots_directory)
        filename = joinpath(plots_directory, "min_min_capture_methods.png")
        save(filename, fig, px_per_unit=2)
        println("Saved plot to: $filename")
    else
        display(fig)
    end
    
    return fig
end

end # module