# PlottingUtilities.jl - Non-interactive plotting functions using CairoMakie

module PlottingUtilities

using CairoMakie
using Printf
using Statistics
using Colors

export plot_l2_convergence, plot_recovery_rates, plot_subdivision_convergence, plot_subdivision_recovery_rates,
       plot_recovery_histogram, plot_subdivision_recovery_histogram, plot_min_min_distances, plot_subdivision_min_min_distances

"""
    plot_l2_convergence(results; save_path=nothing, show_legend=false, title="L²-Norm Convergence")

Create L²-norm convergence plot showing approximation error vs polynomial degree.

# Arguments
- `results`: Vector of DegreeAnalysisResult objects
- `save_path`: Optional file path to save plot (PNG)
- `show_legend`: Whether to include legend (default: false to avoid text issues)
- `title`: Plot title

# Returns
- `Figure`: CairoMakie figure object
"""
function plot_l2_convergence(results; save_path=nothing, show_legend=false, 
                           title="L²-Norm Convergence", tolerance_line=nothing)
    fig = Figure(size = (800, 600))
    ax = Axis(fig[1, 1],
        title = title,
        xlabel = "Polynomial Degree",
        ylabel = "L²-Norm",
        yscale = log10,
        xgridvisible = true,
        ygridvisible = true,
    )
    
    # Extract data
    degrees = [r.degree for r in results]
    l2_norms = [r.l2_norm for r in results]
    
    # Set integer x-axis ticks based on actual degree range
    if !isempty(degrees)
        min_deg = minimum(degrees)
        max_deg = maximum(degrees)
        ax.xticks = min_deg:1:max_deg
    end
    
    # Filter valid values
    valid_indices = findall(isfinite.(l2_norms) .&& (l2_norms .> 0))
    if !isempty(valid_indices)
        valid_degrees = degrees[valid_indices]
        valid_l2_norms = l2_norms[valid_indices]
        
        # Plot convergence curve
        scatterlines!(ax, valid_degrees, valid_l2_norms, 
                     color = :purple, markersize = 8, linewidth = 2)
    end
    
    # Add tolerance reference line if specified
    if tolerance_line !== nothing && tolerance_line > 0
        hlines!(ax, [tolerance_line], color = :red, linestyle = :dash, linewidth = 2)
    end
    
    # Save if path provided
    if save_path !== nothing
        save(save_path, fig)
    end
    
    return fig
end

"""
    plot_recovery_rates(results; save_path=nothing, title="Critical Point Recovery Rates")

Create plot showing success rates for critical point recovery vs degree.

# Arguments
- `results`: Vector of DegreeAnalysisResult objects
- `save_path`: Optional file path to save plot (PNG)
- `title`: Plot title

# Returns
- `Figure`: CairoMakie figure object
"""
function plot_recovery_rates(results; save_path=nothing, 
                           title="Critical Point Recovery Rates")
    fig = Figure(size = (800, 600))
    ax = Axis(fig[1, 1],
        title = title,  # Use the provided title
        xlabel = "Polynomial Degree",
        ylabel = "Success Rate (%)",
        xgridvisible = true,
        ygridvisible = true,
        limits = (nothing, nothing, -5, 105),
    )
    
    # Extract data
    degrees = [r.degree for r in results]
    all_rates = [r.success_rate * 100 for r in results]
    
    # Set integer x-axis ticks based on actual degree range
    if !isempty(degrees)
        min_deg = minimum(degrees)
        max_deg = maximum(degrees)
        ax.xticks = min_deg:1:max_deg
    end
    min_min_rates = [r.min_min_success_rate * 100 for r in results]
    
    # Plot success rates with labels
    scatterlines!(ax, degrees, all_rates, 
                 color = :blue, markersize = 8, linewidth = 2,
                 label = "All Critical Points")
    scatterlines!(ax, degrees, min_min_rates, 
                 color = :red, markersize = 8, linewidth = 2,
                 label = "Min+Min Points Only")
    
    # Add 90% reference line
    hlines!(ax, [90], color = :gray, linestyle = :dash, linewidth = 1.5,
            label = "90% Target")
    
    # Add legend
    axislegend(ax, position = :rt, framevisible = true)
    
    # Save if path provided
    if save_path !== nothing
        save(save_path, fig)
    end
    
    return fig
end

"""
    plot_subdivision_convergence(all_results; save_path=nothing, tolerance_line=nothing,
                               title="Subdivision L²-Norm Convergence")

Create combined plot showing L²-norm convergence for multiple subdomains.

# Arguments
- `all_results`: Dict{String, Vector{DegreeAnalysisResult}} mapping labels to results
- `save_path`: Optional file path to save plot (PNG)
- `tolerance_line`: Optional L²-norm tolerance reference
- `title`: Plot title

# Returns
- `Figure`: CairoMakie figure object
"""
function plot_subdivision_convergence(all_results; save_path=nothing, 
                                    tolerance_line=nothing,
                                    title="Subdivision L²-Norm Convergence")
    fig = Figure(size = (1000, 700))
    ax = Axis(fig[1, 1],
        xlabel = "Polynomial Degree",
        ylabel = "L²-Norm",
        yscale = log10,
        xgridvisible = true,
        ygridvisible = true,
    )
    
    # Define colors and line styles for subdomain visualization
    n_subdomains = length(all_results)
    
    # Use a limited color palette with different line styles
    base_colors = [:blue, :red, :green, :purple, :orange, :brown]
    line_styles = [:solid, :dash, :dot, :dashdot]
    
    # Collect all degrees to determine x-axis range
    all_degrees = Int[]
    for (_, results) in all_results
        if !isempty(results)
            append!(all_degrees, [r.degree for r in results])
        end
    end
    
    # Set integer x-axis ticks based on actual degree range
    if !isempty(all_degrees)
        min_deg = minimum(all_degrees)
        max_deg = maximum(all_degrees)
        ax.xticks = min_deg:1:max_deg
    end
    
    # Plot each subdomain with thin lines and varied styles
    for (i, (label, results)) in enumerate(sort(collect(all_results), by=first))
        if !isempty(results)
            # Sort results by degree to ensure proper line connections
            sorted_results = sort(results, by = r -> r.degree)
            degrees = [r.degree for r in sorted_results]
            l2_norms = [r.l2_norm for r in sorted_results]
            
            # Filter valid values while maintaining order
            valid_indices = findall(isfinite.(l2_norms) .&& (l2_norms .> 0))
            if !isempty(valid_indices)
                valid_degrees = degrees[valid_indices]
                valid_l2_norms = l2_norms[valid_indices]
                
                # Choose color and line style based on index
                color_idx = ((i-1) % length(base_colors)) + 1
                style_idx = ((i-1) ÷ length(base_colors) % length(line_styles)) + 1
                
                # Use thin lines with transparency
                lines!(ax, valid_degrees, valid_l2_norms, 
                       color = (base_colors[color_idx], 0.7), 
                       linewidth = 1.5, 
                       linestyle = line_styles[style_idx])
            end
        end
    end
    
    # Add average line on top (thick and solid)
    degree_norms = Dict{Int, Vector{Float64}}()
    for (_, results) in all_results
        for r in results
            if isfinite(r.l2_norm) && r.l2_norm > 0
                if !haskey(degree_norms, r.degree)
                    degree_norms[r.degree] = Float64[]
                end
                push!(degree_norms[r.degree], r.l2_norm)
            end
        end
    end
    
    if !isempty(degree_norms)
        avg_degrees = sort(collect(keys(degree_norms)))
        avg_norms = [mean(degree_norms[d]) for d in avg_degrees]
        lines!(ax, avg_degrees, avg_norms, 
               color = :black, linewidth = 3, label = "Average")
    end
    
    # Add tolerance reference line if specified
    if tolerance_line !== nothing && tolerance_line > 0
        hlines!(ax, [tolerance_line], color = :black, linestyle = :dash, linewidth = 2,
                label = "L² Tolerance")
    end
    
    # Add annotation showing number of subdomains
    n_subdomains = length(all_results)
    text!(ax, 0.02, 0.98, text = "$(n_subdomains) subdomain trajectories (colored/styled) + average (thick black)",
          align = (:left, :top), space = :relative, fontsize = 12)
    
    # Save if path provided
    if save_path !== nothing
        save(save_path, fig)
    end
    
    return fig
end

"""
    plot_subdivision_recovery_rates(all_results; save_path=nothing, 
                                  title="Subdivision Recovery Rates")

Create combined plot showing recovery rates for multiple subdomains.
Shows both all critical points and min+min only success rates.

# Arguments
- `all_results`: Dict{String, Vector{DegreeAnalysisResult}} mapping labels to results
- `save_path`: Optional file path to save plot (PNG)
- `title`: Plot title

# Returns
- `Figure`: CairoMakie figure object
"""
function plot_subdivision_recovery_rates(all_results; save_path=nothing, 
                                       title="Subdivision Recovery Rates")
    fig = Figure(size = (1000, 700))
    
    # Create two subplots - one for all critical points, one for min+min only
    ax1 = Axis(fig[1, 1],
        title = "All Critical Points Recovery",
        xlabel = "Polynomial Degree",
        ylabel = "Success Rate (%)",
        xgridvisible = true,
        ygridvisible = true,
        limits = (nothing, nothing, -5, 105),
    )
    
    ax2 = Axis(fig[2, 1],
        title = "Min+Min Points Only Recovery",
        xlabel = "Polynomial Degree",
        ylabel = "Success Rate (%)",
        xgridvisible = true,
        ygridvisible = true,
        limits = (nothing, nothing, -5, 105),
    )
    
    # Collect all degrees to determine x-axis range
    all_degrees = Int[]
    for (_, results) in all_results
        if !isempty(results)
            append!(all_degrees, [r.degree for r in results])
        end
    end
    
    # Set integer x-axis ticks based on actual degree range
    if !isempty(all_degrees)
        min_deg = minimum(all_degrees)
        max_deg = maximum(all_degrees)
        ax1.xticks = min_deg:1:max_deg
        ax2.xticks = min_deg:1:max_deg
    end
    
    # Define colors and line styles for subdomain visualization
    base_colors = [:blue, :red, :green, :purple, :orange, :brown]
    line_styles = [:solid, :dash, :dot, :dashdot]
    
    # Plot each subdomain with varied styles
    for (i, (label, results)) in enumerate(sort(collect(all_results), by=first))
        if !isempty(results)
            # Sort by degree for proper line connections
            sorted_results = sort(results, by = r -> r.degree)
            degrees = [r.degree for r in sorted_results]
            all_rates = [r.success_rate * 100 for r in sorted_results]
            min_min_rates = [r.min_min_success_rate * 100 for r in sorted_results]
            
            # Choose color and line style based on index
            color_idx = ((i-1) % length(base_colors)) + 1
            style_idx = ((i-1) ÷ length(base_colors) % length(line_styles)) + 1
            
            # Plot all critical points recovery with thin lines
            lines!(ax1, degrees, all_rates, 
                   color = (base_colors[color_idx], 0.6), 
                   linewidth = 1.0,
                   linestyle = line_styles[style_idx])
            
            # Plot min+min recovery (only if there are min+min points in subdomain)
            valid_min_min = findall(min_min_rates .>= 0)  # -1 indicates no min+min points
            if !isempty(valid_min_min)
                lines!(ax2, degrees[valid_min_min], min_min_rates[valid_min_min], 
                       color = (base_colors[color_idx], 0.6), 
                       linewidth = 1.0,
                       linestyle = line_styles[style_idx])
            end
        end
    end
    
    # Add average lines on top
    # All critical points average
    degree_all_rates = Dict{Int, Vector{Float64}}()
    degree_minmin_rates = Dict{Int, Vector{Float64}}()
    
    for (_, results) in all_results
        for r in results
            if !haskey(degree_all_rates, r.degree)
                degree_all_rates[r.degree] = Float64[]
                degree_minmin_rates[r.degree] = Float64[]
            end
            push!(degree_all_rates[r.degree], r.success_rate * 100)
            if r.min_min_success_rate >= 0
                push!(degree_minmin_rates[r.degree], r.min_min_success_rate * 100)
            end
        end
    end
    
    # Plot averages
    if !isempty(degree_all_rates)
        avg_degrees = sort(collect(keys(degree_all_rates)))
        avg_all_rates = [mean(degree_all_rates[d]) for d in avg_degrees]
        lines!(ax1, avg_degrees, avg_all_rates, 
               color = :black, linewidth = 3, label = "Average")
    end
    
    if !isempty(degree_minmin_rates)
        avg_degrees = sort(collect(keys(degree_minmin_rates)))
        avg_minmin_rates = Float64[]
        for d in avg_degrees
            if !isempty(degree_minmin_rates[d])
                push!(avg_minmin_rates, mean(degree_minmin_rates[d]))
            end
        end
        if !isempty(avg_minmin_rates)
            lines!(ax2, avg_degrees[1:length(avg_minmin_rates)], avg_minmin_rates,
                   color = :black, linewidth = 3, label = "Average")
        end
    end
    
    # Add 90% reference lines
    hlines!(ax1, [90], color = :gray, linestyle = :dash, linewidth = 2)
    hlines!(ax2, [90], color = :gray, linestyle = :dash, linewidth = 2)
    
    # Add annotation for number of subdomains
    n_subdomains = length(all_results)
    text!(ax1, 0.02, 0.98, text = "$(n_subdomains) subdomains (thin colored lines) + average (thick black)",
          align = (:left, :top), space = :relative, fontsize = 12)
    n_with_minmin = length([1 for (_, results) in all_results if any(r -> r.min_min_success_rate >= 0, results)])
    text!(ax2, 0.02, 0.98, text = "$(n_with_minmin) subdomains with min+min (thin lines) + average (thick black)",
          align = (:left, :top), space = :relative, fontsize = 12)
    
    # Save if path provided
    if save_path !== nothing
        save(save_path, fig)
    end
    
    return fig
end

"""
    plot_recovery_histogram(results; save_path=nothing, 
                          title="Critical Point Recovery",
                          show_legend=true)

Create a stacked bar chart showing total theoretical points vs found points.
Similar to capture_histogram but adapted for DegreeAnalysisResult data.

# Arguments
- `results`: Vector of DegreeAnalysisResult objects
- `save_path`: Optional file path to save plot (PNG)
- `title`: Plot title
- `show_legend`: Whether to show legend (default: true)

# Returns
- `Figure`: CairoMakie figure object
"""
function plot_recovery_histogram(results; save_path=nothing, 
                               title="Critical Point Recovery",
                               show_legend=true)
    # Adjust figure size based on whether legend is shown
    fig_width = show_legend ? 1000 : 800
    fig = Figure(size = (fig_width, 600))
    
    ax = Axis(fig[1, 1],
        xlabel = "Polynomial Degree",
        ylabel = "Number of Critical Points",
        xgridvisible = true,
        ygridvisible = true,
    )
    
    # Extract data
    degrees = [r.degree for r in results]
    n_theoretical = [r.n_theoretical_points for r in results]
    n_found = [r.n_successful_recoveries for r in results]
    n_not_found = n_theoretical .- n_found
    
    # Set integer x-axis ticks
    if !isempty(degrees)
        min_deg = minimum(degrees)
        max_deg = maximum(degrees)
        ax.xticks = (min_deg:1:max_deg, string.(min_deg:1:max_deg))
    end
    
    # Create stacked bar plot
    # First plot the found points (green)
    barplot!(ax, degrees, n_found, 
             color = (:forestgreen, 0.8),
             label = "Found",
             width = 0.7)
    
    # Then stack the not found points on top (red)
    barplot!(ax, degrees, n_not_found,
             color = (:firebrick, 0.8),
             label = "Not Found",
             width = 0.7,
             stack = n_found)  # Stack on top of found points
    
    # Add value labels on bars
    for (i, d) in enumerate(degrees)
        # Label for theoretical total at top
        text!(ax, d, n_theoretical[i] + 0.5,
              text = string(n_theoretical[i]),
              align = (:center, :bottom),
              fontsize = 12)
        
        # Label for found count if > 0
        if n_found[i] > 0
            text!(ax, d, n_found[i] / 2,
                  text = string(n_found[i]),
                  align = (:center, :center),
                  fontsize = 11,
                  color = :white)
        end
    end
    
    if show_legend
        Legend(fig[1, 2], ax,
               framevisible = true,
               backgroundcolor = (:white, 0.9),
               padding = (10, 10, 10, 10))
        colsize!(fig.layout, 1, Relative(0.8))
        colsize!(fig.layout, 2, Relative(0.2))
    end
    
    # Save if path provided
    if save_path !== nothing
        save(save_path, fig)
    end
    
    return fig
end

"""
    plot_subdivision_recovery_histogram(all_results; save_path=nothing,
                                      title="Subdivision Critical Point Recovery",
                                      show_combined=true)

Create histogram showing recovery rates for subdivision analysis.
Can show either combined totals or separate bars for each subdomain.

# Arguments
- `all_results`: Dict{String, Vector{DegreeAnalysisResult}} mapping labels to results
- `save_path`: Optional file path to save plot (PNG)
- `title`: Plot title
- `show_combined`: If true, show combined totals; if false, show separate subdomains

# Returns
- `Figure`: CairoMakie figure object
"""
function plot_subdivision_recovery_histogram(all_results; save_path=nothing,
                                           title="Subdivision Critical Point Recovery",
                                           show_combined=true)
    fig = Figure(size = (1200, 700))
    
    if show_combined
        # Combined view - sum across all subdomains
        ax = Axis(fig[1, 1],
            xlabel = "Polynomial Degree",
            ylabel = "Total Critical Points (All Subdomains)",
            xgridvisible = true,
            ygridvisible = true,
        )
        
        # Collect all degrees
        all_degrees = Set{Int}()
        for (_, results) in all_results
            for r in results
                push!(all_degrees, r.degree)
            end
        end
        degrees = sort(collect(all_degrees))
        
        # Initialize arrays for combined data
        n_theoretical_total = zeros(Int, length(degrees))
        n_found_total = zeros(Int, length(degrees))
        
        # Sum across all subdomains for each degree
        for (label, results) in all_results
            for r in results
                idx = findfirst(d -> d == r.degree, degrees)
                if idx !== nothing
                    n_theoretical_total[idx] += r.n_theoretical_points
                    n_found_total[idx] += r.n_successful_recoveries
                end
            end
        end
        
        n_not_found_total = n_theoretical_total .- n_found_total
        
        # Set x-axis ticks
        ax.xticks = (degrees, string.(degrees))
        
        # Create stacked bar plot
        barplot!(ax, degrees, n_found_total,
                 color = (:forestgreen, 0.8),
                 label = "Found",
                 width = 0.7)
        
        barplot!(ax, degrees, n_not_found_total,
                 color = (:firebrick, 0.8),
                 label = "Not Found",
                 width = 0.7,
                 stack = n_found_total)
        
        # Add value labels
        for (i, d) in enumerate(degrees)
            if n_theoretical_total[i] > 0
                # Total at top
                text!(ax, d, n_theoretical_total[i] + 1,
                      text = string(n_theoretical_total[i]),
                      align = (:center, :bottom),
                      fontsize = 12)
                
                # Found count if > 0
                if n_found_total[i] > 0
                    text!(ax, d, n_found_total[i] / 2,
                          text = string(n_found_total[i]),
                          align = (:center, :center),
                          fontsize = 11,
                          color = :white)
                end
            end
        end
        
        Legend(fig[1, 2], ax,
               framevisible = true,
               backgroundcolor = (:white, 0.9),
               padding = (10, 10, 10, 10))
        colsize!(fig.layout, 1, Relative(0.85))
        colsize!(fig.layout, 2, Relative(0.15))
        
    else
        # Separate view - show each subdomain
        n_subdomains = length(all_results)
        n_cols = 2
        n_rows = ceil(Int, n_subdomains / n_cols)
        
        for (idx, (label, results)) in enumerate(sort(collect(all_results), by=first))
            row = div(idx - 1, n_cols) + 1
            col = mod(idx - 1, n_cols) + 1
            
            ax = Axis(fig[row, col],
                xlabel = "Degree",
                ylabel = "Critical Points",
                title = label,
                xgridvisible = true,
                ygridvisible = true,
                titlesize = 14,
            )
            
            if !isempty(results)
                degrees = [r.degree for r in results]
                n_theoretical = [r.n_theoretical_points for r in results]
                n_found = [r.n_successful_recoveries for r in results]
                n_not_found = n_theoretical .- n_found
                
                # Set x-axis ticks
                ax.xticks = (degrees, string.(degrees))
                
                # Create stacked bars
                barplot!(ax, degrees, n_found,
                         color = (:forestgreen, 0.8),
                         width = 0.6)
                
                barplot!(ax, degrees, n_not_found,
                         color = (:firebrick, 0.8),
                         width = 0.6,
                         stack = n_found)
                
                # Add total labels
                for (i, d) in enumerate(degrees)
                    if n_theoretical[i] > 0
                        text!(ax, d, n_theoretical[i] + 0.2,
                              text = string(n_theoretical[i]),
                              align = (:center, :bottom),
                              fontsize = 10)
                    end
                end
            end
        end
        
        # Add shared legend at bottom
        label_found = Label(fig[n_rows + 1, :], "■ Found", 
                           color = :forestgreen, fontsize = 14)
        label_not_found = Label(fig[n_rows + 1, :], "■ Not Found", 
                               color = :firebrick, fontsize = 14)
    end
    
    # Save if path provided
    if save_path !== nothing
        save(save_path, fig)
    end
    
    return fig
end

"""
    plot_min_min_distances(results; save_path=nothing, 
                          title="Min+Min Point Distances by Degree")

Create plot showing distance from min+min theoretical points to closest 
computed critical point vs polynomial degree.

# Arguments
- `results`: Vector of DegreeAnalysisResult objects
- `save_path`: Optional file path to save plot (PNG)
- `title`: Plot title

# Returns
- `Figure`: CairoMakie figure object
"""
function plot_min_min_distances(results; save_path=nothing, 
                               title="Min+Min Point Distances by Degree",
                               tolerance_line=1e-4)
    fig = Figure(size = (800, 600))
    ax = Axis(fig[1, 1],
        title = title,
        xlabel = "Polynomial Degree",
        ylabel = "Distance to Closest Critical Point",
        yscale = log10,
        xgridvisible = true,
        ygridvisible = true,
    )
    
    # Extract data
    degrees = [r.degree for r in results]
    all_valid_distances = Float64[]
    
    # Set integer x-axis ticks based on actual degree range
    if !isempty(degrees)
        min_deg = minimum(degrees)
        max_deg = maximum(degrees)
        ax.xticks = min_deg:1:max_deg
    end
    
    # Plot min+min distances for each degree
    for r in results
        if !isempty(r.min_min_distances)
            # Plot each min+min distance as a point
            for dist in r.min_min_distances
                if isfinite(dist) && dist > 0
                    scatter!(ax, [r.degree], [dist], 
                            color = (:blue, 0.5), markersize = 6)
                    push!(all_valid_distances, dist)
                end
            end
        end
    end
    
    # Add average line
    avg_distances = Float64[]
    avg_degrees = Int[]
    for r in results
        if !isempty(r.min_min_distances)
            valid_dists = filter(d -> isfinite(d) && d > 0, r.min_min_distances)
            if !isempty(valid_dists)
                push!(avg_distances, mean(valid_dists))
                push!(avg_degrees, r.degree)
            end
        end
    end
    
    if !isempty(avg_distances)
        lines!(ax, avg_degrees, avg_distances, 
               color = :red, linewidth = 3, label = "Average")
    end
    
    # Set y-axis limits based on data
    if !isempty(all_valid_distances)
        ymin = minimum(all_valid_distances) * 0.5
        ymax = maximum(all_valid_distances) * 2.0
        limits!(ax, nothing, nothing, ymin, ymax)
    end
    
    # Add tolerance reference line if specified and within range
    if tolerance_line !== nothing && tolerance_line > 0 && !isempty(all_valid_distances)
        ymin = minimum(all_valid_distances) * 0.5
        ymax = maximum(all_valid_distances) * 2.0
        if tolerance_line >= ymin && tolerance_line <= ymax
            hlines!(ax, [tolerance_line], color = :green, linestyle = :dash, linewidth = 2,
                    label = "Tolerance")
        end
    end
    
    # Add legend if there are labeled elements
    if !isempty(avg_distances) || (tolerance_line !== nothing && tolerance_line > 0)
        axislegend(ax, position = :rt, framevisible = true)
    end
    
    # Save if path provided
    if save_path !== nothing
        save(save_path, fig)
    end
    
    return fig
end

"""
    plot_subdivision_min_min_distances(all_results; save_path=nothing,
                                     title="Subdivision Min+Min Distances")

Create plot showing min+min distances for subdivision analysis.
Shows individual subdomain curves and overall average.

# Arguments
- `all_results`: Dict{String, Vector{DegreeAnalysisResult}} mapping labels to results
- `save_path`: Optional file path to save plot (PNG)
- `title`: Plot title

# Returns
- `Figure`: CairoMakie figure object
"""
function plot_subdivision_min_min_distances(all_results; save_path=nothing,
                                          title="Subdivision Min+Min Distances",
                                          tolerance_line=1e-4)
    fig = Figure(size = (1000, 700))
    ax = Axis(fig[1, 1],
        title = title,
        xlabel = "Polynomial Degree",
        ylabel = "Distance to Closest Critical Point",
        yscale = log10,
        xgridvisible = true,
        ygridvisible = true,
    )
    
    # Collect all degrees and valid distances
    all_degrees = Int[]
    all_valid_distances = Float64[]
    
    for (_, results) in all_results
        if !isempty(results)
            append!(all_degrees, [r.degree for r in results])
            for r in results
                if !isempty(r.min_min_distances)
                    valid_dists = filter(d -> isfinite(d) && d > 0, r.min_min_distances)
                    append!(all_valid_distances, valid_dists)
                end
            end
        end
    end
    
    # Set integer x-axis ticks based on actual degree range
    if !isempty(all_degrees)
        min_deg = minimum(all_degrees)
        max_deg = maximum(all_degrees)
        ax.xticks = min_deg:1:max_deg
    end
    
    # Define colors and line styles for subdomain visualization
    base_colors = [:blue, :red, :green, :purple, :orange, :brown]
    line_styles = [:solid, :dash, :dot, :dashdot]
    
    # Plot each subdomain with varied styles
    subdomain_count = 0
    subdomain_idx = 0
    for (label, results) in sort(collect(all_results), by=first)
        has_min_min = false
        
        # Check if this subdomain has any min+min points
        for r in results
            if !isempty(r.min_min_distances)
                has_min_min = true
                break
            end
        end
        
        if has_min_min
            subdomain_count += 1
            subdomain_idx += 1
            
            # Extract average distances for this subdomain
            subdomain_avg_distances = Float64[]
            subdomain_degrees = Int[]
            
            for r in results
                if !isempty(r.min_min_distances)
                    valid_dists = filter(d -> isfinite(d) && d > 0, r.min_min_distances)
                    if !isempty(valid_dists)
                        push!(subdomain_avg_distances, mean(valid_dists))
                        push!(subdomain_degrees, r.degree)
                    end
                end
            end
            
            if !isempty(subdomain_avg_distances)
                # Sort by degree to ensure proper line connections
                perm = sortperm(subdomain_degrees)
                sorted_degrees = subdomain_degrees[perm]
                sorted_distances = subdomain_avg_distances[perm]
                
                # Choose color and line style based on index
                color_idx = ((subdomain_idx-1) % length(base_colors)) + 1
                style_idx = ((subdomain_idx-1) ÷ length(base_colors) % length(line_styles)) + 1
                
                # Use thin lines with transparency
                lines!(ax, sorted_degrees, sorted_distances,
                      color = (base_colors[color_idx], 0.5), 
                      linewidth = 1.0,
                      linestyle = line_styles[style_idx])
            end
        end
    end
    
    # Compute and plot overall average across all subdomains
    degree_distances = Dict{Int, Vector{Float64}}()
    
    for (_, results) in all_results
        for r in results
            if !isempty(r.min_min_distances)
                valid_dists = filter(d -> isfinite(d) && d > 0, r.min_min_distances)
                if !isempty(valid_dists)
                    if !haskey(degree_distances, r.degree)
                        degree_distances[r.degree] = Float64[]
                    end
                    append!(degree_distances[r.degree], valid_dists)
                end
            end
        end
    end
    
    # Calculate overall averages
    overall_degrees = sort(collect(keys(degree_distances)))
    overall_averages = [mean(degree_distances[d]) for d in overall_degrees]
    
    if !isempty(overall_averages)
        lines!(ax, overall_degrees, overall_averages,
               color = :red, linewidth = 4, label = "Overall Average")
    end
    
    # Set y-axis limits based on data
    if !isempty(all_valid_distances)
        ymin = minimum(all_valid_distances) * 0.5
        ymax = maximum(all_valid_distances) * 2.0
        limits!(ax, nothing, nothing, ymin, ymax)
    end
    
    # Add tolerance reference line if specified and within range
    if tolerance_line !== nothing && tolerance_line > 0 && !isempty(all_valid_distances)
        ymin = minimum(all_valid_distances) * 0.5
        ymax = maximum(all_valid_distances) * 2.0
        if tolerance_line >= ymin && tolerance_line <= ymax
            hlines!(ax, [tolerance_line], color = :green, linestyle = :dash, linewidth = 2,
                    label = "Tolerance")
        end
    end
    
    # Add info about number of subdomains with min+min points
    n_total_subdomains = length(all_results)
    text!(ax, 0.02, 0.98, text = "Subdomains with min+min: $subdomain_count/$n_total_subdomains",
          align = (:left, :top), space = :relative, fontsize = 14)
    
    # Add legend if there are labeled elements
    if !isempty(overall_averages) || (tolerance_line !== nothing && tolerance_line > 0)
        axislegend(ax, position = :rt, framevisible = true)
    end
    
    # Save if path provided
    if save_path !== nothing
        save(save_path, fig)
    end
    
    return fig
end

end # module