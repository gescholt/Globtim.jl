# Phase 2: Hessian Visualization Functions
# Plotting functions for Hessian analysis visualization

using DataFrames

"""
Plotting functions for Hessian analysis visualization.
Requires CairoMakie or GLMakie to be loaded before calling these functions.

Example usage:
```julia
using CairoMakie  # or using GLMakie
fig = plot_hessian_norms(df_enhanced)
```
"""

function plot_hessian_norms(df::DataFrame)
    # Check if a Makie backend is loaded
    if !isdefined(Main, :Makie) && !isdefined(Main, :CairoMakie) && !isdefined(Main, :GLMakie)
        error("No Makie backend loaded. Please run `using CairoMakie` or `using GLMakie` first.")
    end
    
    fig = Figure(resolution=(800, 600))
    ax = Axis(fig[1, 1], 
              xlabel="Critical Point Index", 
              ylabel="Hessian L2 Norm",
              title="L2 Norm of Hessian Matrices")
    
    # Color by classification if available
    if "critical_point_type" in names(df)
        for (i, classification) in enumerate(unique(df.critical_point_type))
            mask = df.critical_point_type .== classification
            scatter!(ax, findall(mask), df.hessian_norm[mask], 
                    label=string(classification), markersize=8)
        end
        axislegend(ax)
    else
        scatter!(ax, 1:nrow(df), df.hessian_norm, markersize=8)
    end
    
    return fig
end

function plot_condition_numbers(df::DataFrame)
    # Check if a Makie backend is loaded
    if !isdefined(Main, :Makie) && !isdefined(Main, :CairoMakie) && !isdefined(Main, :GLMakie)
        error("No Makie backend loaded. Please run `using CairoMakie` or `using GLMakie` first.")
    end
    
    fig = Figure(resolution=(800, 600))
    ax = Axis(fig[1, 1], 
              xlabel="Critical Point Index", 
              ylabel="Condition Number (log scale)",
              title="Condition Numbers of Hessian Matrices",
              yscale=log10)
    
    # Filter out NaN and infinite values
    valid_indices = findall(x -> isfinite(x) && x > 0, df.hessian_condition_number)
    
    if "critical_point_type" in names(df)
        for (i, classification) in enumerate(unique(df.critical_point_type))
            mask = (df.critical_point_type .== classification) .& 
                   [i in valid_indices for i in 1:nrow(df)]
            indices = findall(mask)
            if !isempty(indices)
                scatter!(ax, indices, df.hessian_condition_number[indices], 
                        label=string(classification), markersize=8)
            end
        end
        axislegend(ax)
    else
        scatter!(ax, valid_indices, df.hessian_condition_number[valid_indices], markersize=8)
    end
    
    return fig
end

function plot_critical_eigenvalues(df::DataFrame)
    # Check if a Makie backend is loaded
    if !isdefined(Main, :Makie) && !isdefined(Main, :CairoMakie) && !isdefined(Main, :GLMakie)
        error("No Makie backend loaded. Please run `using CairoMakie` or `using GLMakie` first.")
    end
    
    fig = Figure(resolution=(1200, 500))
    
    # Plot 1: Smallest positive eigenvalues for minima
    ax1 = Axis(fig[1, 1], 
               xlabel="Minimum Index", 
               ylabel="Smallest Positive Eigenvalue",
               title="Smallest Positive Eigenvalues (Minima)")
    
    minima_mask = df.critical_point_type .== :minimum
    minima_indices = findall(minima_mask)
    valid_minima = findall(x -> isfinite(x) && x > 0, df.smallest_positive_eigenval[minima_mask])
    
    if !isempty(valid_minima)
        scatter!(ax1, valid_minima, df.smallest_positive_eigenval[minima_mask][valid_minima], 
                color=:blue, markersize=10)
        # Add horizontal line at machine epsilon for reference
        hlines!(ax1, [1e-12], color=:red, linestyle=:dash, label="Numerical Zero")
        axislegend(ax1)
    end
    
    # Plot 2: Largest negative eigenvalues for maxima
    ax2 = Axis(fig[1, 2], 
               xlabel="Maximum Index", 
               ylabel="Largest Negative Eigenvalue",
               title="Largest Negative Eigenvalues (Maxima)")
    
    maxima_mask = df.critical_point_type .== :maximum
    maxima_indices = findall(maxima_mask)
    valid_maxima = findall(x -> isfinite(x) && x < 0, df.largest_negative_eigenval[maxima_mask])
    
    if !isempty(valid_maxima)
        scatter!(ax2, valid_maxima, df.largest_negative_eigenval[maxima_mask][valid_maxima], 
                color=:red, markersize=10)
        # Add horizontal line at negative machine epsilon for reference
        hlines!(ax2, [-1e-12], color=:red, linestyle=:dash, label="Numerical Zero")
        axislegend(ax2)
    end
    
    return fig
end