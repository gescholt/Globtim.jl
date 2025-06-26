module GlobtimCairoMakieExt

using Globtim
using CairoMakie
using DataFrames

# Include CairoMakie-specific plotting functionality
include("../src/graphs_cairo.jl")

# Include Phase 2 Hessian visualization functions with proper CairoMakie scope
function Globtim.plot_hessian_norms(df::DataFrames.DataFrame)
    fig = CairoMakie.Figure(size=(800, 600))
    ax = CairoMakie.Axis(fig[1, 1], 
              xlabel="Critical Point Index", 
              ylabel="Hessian L2 Norm",
              title="L2 Norm of Hessian Matrices")
    
    # Color by classification if available
    if "critical_point_type" in names(df)
        for classification in unique(df.critical_point_type)
            mask = df.critical_point_type .== classification
            CairoMakie.scatter!(ax, findall(mask), df.hessian_norm[mask], 
                    label=string(classification), markersize=8)
        end
        CairoMakie.axislegend(ax)
    else
        CairoMakie.scatter!(ax, 1:nrow(df), df.hessian_norm, markersize=8)
    end
    
    return fig
end

function Globtim.plot_condition_numbers(df::DataFrames.DataFrame)
    fig = CairoMakie.Figure(size=(800, 600))
    ax = CairoMakie.Axis(fig[1, 1], 
              xlabel="Critical Point Index", 
              ylabel="Condition Number (log scale)",
              title="Condition Numbers of Hessian Matrices",
              yscale=CairoMakie.log10)
    
    # Filter out NaN and infinite values
    valid_indices = findall(x -> isfinite(x) && x > 0, df.hessian_condition_number)
    
    if "critical_point_type" in names(df)
        for classification in unique(df.critical_point_type)
            mask = (df.critical_point_type .== classification) .& 
                   [i in valid_indices for i in 1:nrow(df)]
            indices = findall(mask)
            if !isempty(indices)
                CairoMakie.scatter!(ax, indices, df.hessian_condition_number[indices], 
                        label=string(classification), markersize=8)
            end
        end
        CairoMakie.axislegend(ax)
    else
        CairoMakie.scatter!(ax, valid_indices, df.hessian_condition_number[valid_indices], markersize=8)
    end
    
    return fig
end

function Globtim.plot_critical_eigenvalues(df::DataFrames.DataFrame)
    fig = CairoMakie.Figure(size=(1200, 500))
    
    # Plot 1: Smallest positive eigenvalues for minima
    ax1 = CairoMakie.Axis(fig[1, 1], 
               xlabel="Minimum Index", 
               ylabel="Smallest Positive Eigenvalue",
               title="Smallest Positive Eigenvalues (Minima)")
    
    minima_mask = df.critical_point_type .== :minimum
    valid_minima = findall(x -> isfinite(x) && x > 0, df.smallest_positive_eigenval[minima_mask])
    
    if !isempty(valid_minima)
        CairoMakie.scatter!(ax1, valid_minima, df.smallest_positive_eigenval[minima_mask][valid_minima], 
                color=:blue, markersize=10)
        # Add horizontal line at machine epsilon for reference
        CairoMakie.hlines!(ax1, [1e-12], color=:red, linestyle=:dash, label="Numerical Zero")
        CairoMakie.axislegend(ax1)
    end
    
    # Plot 2: Largest negative eigenvalues for maxima
    ax2 = CairoMakie.Axis(fig[1, 2], 
               xlabel="Maximum Index", 
               ylabel="Largest Negative Eigenvalue",
               title="Largest Negative Eigenvalues (Maxima)")
    
    maxima_mask = df.critical_point_type .== :maximum
    valid_maxima = findall(x -> isfinite(x) && x < 0, df.largest_negative_eigenval[maxima_mask])
    
    if !isempty(valid_maxima)
        CairoMakie.scatter!(ax2, valid_maxima, df.largest_negative_eigenval[maxima_mask][valid_maxima], 
                color=:red, markersize=10)
        # Add horizontal line at negative machine epsilon for reference
        CairoMakie.hlines!(ax2, [-1e-12], color=:red, linestyle=:dash, label="Numerical Zero")
        CairoMakie.axislegend(ax2)
    end
    
    return fig
end

# Export plotting functions that require CairoMakie
export plot_convergence_analysis,
    capture_histogram,
    create_legend_figure,
    plot_discrete_l2,
    plot_convergence_captured,
    plot_filtered_y_distances,
    cairo_plot_polyapprox_levelset,
    plot_distance_statistics,
    plot_hessian_norms,
    plot_condition_numbers,
    plot_critical_eigenvalues

end