# PlottingUtilities.jl - Non-interactive plotting functions using CairoMakie

module PlottingUtilities

using CairoMakie
using Printf

export plot_l2_convergence, plot_recovery_rates, plot_subdivision_convergence

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
        ygridvisible = true
    )
    
    # Extract data
    degrees = [r.degree for r in results]
    l2_norms = [r.l2_norm for r in results]
    
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
        title = title,
        xlabel = "Polynomial Degree",
        ylabel = "Success Rate (%)",
        xgridvisible = true,
        ygridvisible = true,
        limits = (nothing, nothing, -5, 105)
    )
    
    # Extract data
    degrees = [r.degree for r in results]
    all_rates = [r.success_rate * 100 for r in results]
    min_min_rates = [r.min_min_success_rate * 100 for r in results]
    
    # Plot success rates
    scatterlines!(ax, degrees, all_rates, 
                 color = :blue, markersize = 8, linewidth = 2)
    scatterlines!(ax, degrees, min_min_rates, 
                 color = :red, markersize = 8, linewidth = 2)
    
    # Add 90% reference line
    hlines!(ax, [90], color = :gray, linestyle = :dash, linewidth = 1.5)
    
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
        title = title,
        xlabel = "Polynomial Degree",
        ylabel = "L²-Norm",
        yscale = log10,
        xgridvisible = true,
        ygridvisible = true
    )
    
    # Color palette for 16 subdomains
    colors = [:red, :blue, :green, :orange, :purple, :cyan, :magenta, :yellow,
              :darkred, :darkblue, :darkgreen, :darkorange, :darkmagenta, :darkcyan, 
              :brown, :pink]
    
    # Plot each subdomain
    for (i, (label, results)) in enumerate(sort(collect(all_results)))
        if !isempty(results)
            degrees = [r.degree for r in results]
            l2_norms = [r.l2_norm for r in results]
            
            # Filter valid values
            valid_indices = findall(isfinite.(l2_norms) .&& (l2_norms .> 0))
            if !isempty(valid_indices)
                valid_degrees = degrees[valid_indices]
                valid_l2_norms = l2_norms[valid_indices]
                
                color_idx = mod1(i, length(colors))
                scatterlines!(ax, valid_degrees, valid_l2_norms, 
                           color = colors[color_idx], markersize = 6, linewidth = 1.5)
            end
        end
    end
    
    # Add tolerance reference line if specified
    if tolerance_line !== nothing && tolerance_line > 0
        hlines!(ax, [tolerance_line], color = :black, linestyle = :dash, linewidth = 2)
    end
    
    # Save if path provided
    if save_path !== nothing
        save(save_path, fig)
    end
    
    return fig
end

end # module