module GlobtimGLMakieExt

using Globtim
using GLMakie
using DataFrames

# Include GLMakie-specific plotting functionality
include("../src/graphs_makie.jl")
include("../src/LevelSetViz.jl")

# Include Phase 2 Hessian visualization functions with proper GLMakie scope
function Globtim.plot_hessian_norms(df::DataFrames.DataFrame)
    fig = GLMakie.Figure(size=(800, 600))
    ax = GLMakie.Axis(fig[1, 1], 
              xlabel="Critical Point Index", 
              ylabel="Hessian L2 Norm",
              title="L2 Norm of Hessian Matrices")
    
    # Color by classification if available
    if "critical_point_type" in names(df)
        for classification in unique(df.critical_point_type)
            mask = df.critical_point_type .== classification
            GLMakie.scatter!(ax, findall(mask), df.hessian_norm[mask], 
                    label=string(classification), markersize=8)
        end
        GLMakie.axislegend(ax)
    else
        GLMakie.scatter!(ax, 1:nrow(df), df.hessian_norm, markersize=8)
    end
    
    return fig
end

function Globtim.plot_condition_numbers(df::DataFrames.DataFrame)
    fig = GLMakie.Figure(size=(800, 600))
    ax = GLMakie.Axis(fig[1, 1], 
              xlabel="Critical Point Index", 
              ylabel="Condition Number (log scale)",
              title="Condition Numbers of Hessian Matrices",
              yscale=GLMakie.log10)
    
    # Filter out NaN and infinite values
    valid_indices = findall(x -> isfinite(x) && x > 0, df.hessian_condition_number)
    
    if "critical_point_type" in names(df)
        for (i, classification) in enumerate(unique(df.critical_point_type))
            mask = (df.critical_point_type .== classification) .& 
                   [i in valid_indices for i in 1:nrow(df)]
            indices = findall(mask)
            if !isempty(indices)
                GLMakie.scatter!(ax, indices, df.hessian_condition_number[indices], 
                        label=string(classification), markersize=8)
            end
        end
        GLMakie.axislegend(ax)
    else
        GLMakie.scatter!(ax, valid_indices, df.hessian_condition_number[valid_indices], markersize=8)
    end
    
    return fig
end

function Globtim.plot_critical_eigenvalues(df::DataFrames.DataFrame)
    fig = GLMakie.Figure(size=(1200, 500))
    
    # Plot 1: Smallest positive eigenvalues for minima
    ax1 = GLMakie.Axis(fig[1, 1], 
               xlabel="Minimum Index", 
               ylabel="Smallest Positive Eigenvalue",
               title="Smallest Positive Eigenvalues (Minima)")
    
    minima_mask = df.critical_point_type .== :minimum
    valid_minima = findall(x -> isfinite(x) && x > 0, df.smallest_positive_eigenval[minima_mask])
    
    if !isempty(valid_minima)
        GLMakie.scatter!(ax1, valid_minima, df.smallest_positive_eigenval[minima_mask][valid_minima], 
                color=:blue, markersize=10)
        # Add horizontal line at machine epsilon for reference
        GLMakie.hlines!(ax1, [1e-12], color=:red, linestyle=:dash, label="Numerical Zero")
        GLMakie.axislegend(ax1)
    end
    
    # Plot 2: Largest negative eigenvalues for maxima
    ax2 = GLMakie.Axis(fig[1, 2], 
               xlabel="Maximum Index", 
               ylabel="Largest Negative Eigenvalue",
               title="Largest Negative Eigenvalues (Maxima)")
    
    maxima_mask = df.critical_point_type .== :maximum
    valid_maxima = findall(x -> isfinite(x) && x < 0, df.largest_negative_eigenval[maxima_mask])
    
    if !isempty(valid_maxima)
        GLMakie.scatter!(ax2, valid_maxima, df.largest_negative_eigenval[maxima_mask][valid_maxima], 
                color=:red, markersize=10)
        # Add horizontal line at negative machine epsilon for reference
        GLMakie.hlines!(ax2, [-1e-12], color=:red, linestyle=:dash, label="Numerical Zero")
        GLMakie.axislegend(ax2)
    end
    
    return fig
end

# Export plotting functions that require GLMakie
export plot_polyapprox_3d,
    LevelSetData,
    VisualizationParameters,
    prepare_level_set_data,
    to_makie_format,
    plot_level_set,
    create_level_set_visualization,
    plot_polyapprox_rotate,
    plot_polyapprox_levelset,
    plot_polyapprox_flyover,
    plot_polyapprox_animate,
    plot_polyapprox_animate2,
    plot_hessian_norms,
    plot_condition_numbers,
    plot_critical_eigenvalues

end