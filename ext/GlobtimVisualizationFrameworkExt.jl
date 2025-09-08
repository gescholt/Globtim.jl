"""
    GlobtimVisualizationFrameworkExt.jl

Makie extension for the VisualizationFramework module.
Implements concrete plot renderers for CairoMakie and GLMakie.

This extension automatically loads when both Globtim and Makie packages are available,
providing full plotting capabilities for the visualization framework.

Author: GlobTim Team
Date: September 2025
"""
module GlobtimVisualizationFrameworkExt

using Globtim.VisualizationFramework
using CairoMakie, GLMakie
using Colors, ColorSchemes
using Printf

# =============================================================================
# Concrete Renderer Implementations
# =============================================================================

"""
    CairoMakieRenderer

CairoMakie-based renderer for static publication-quality plots.
Best for L2-degree analysis and parameter space plots.
"""
struct CairoMakieRenderer <: AbstractPlotRenderer
    backend::String
    
    CairoMakieRenderer() = new("CairoMakie")
end

"""
    GLMakieRenderer

GLMakie-based renderer for interactive plots.
Best for convergence trajectories and real-time visualization.
"""
struct GLMakieRenderer <: AbstractPlotRenderer
    backend::String
    
    GLMakieRenderer() = new("GLMakie")
end

# =============================================================================
# L2-Degree Analysis Plot Implementation
# =============================================================================

function VisualizationFramework.render_plot(renderer::CairoMakieRenderer, 
                                           data::L2DegreeAnalysisData, 
                                           config::PlotConfig)
    CairoMakie.activate!()
    
    fig = Figure(resolution=config.figure_size)
    
    # Main L2-norm vs degree plot (log scale)
    ax1 = Axis(fig[1, 1], 
               title=isempty(config.title) ? "L2-Norm vs Polynomial Degree" : config.title,
               xlabel="Polynomial Degree",
               ylabel="L2-Norm", 
               yscale=log10)
    
    # Color points by dimension
    unique_dims = unique(data.dimensions)
    color_palette = ColorSchemes.Set1_9
    
    for (i, dim) in enumerate(unique_dims)
        dim_mask = data.dimensions .== dim
        if any(dim_mask)
            color = color_palette[mod1(i, length(color_palette))]
            scatter!(ax1, data.degrees[dim_mask], data.l2_norms[dim_mask],
                    color=color, markersize=config.marker_size, 
                    alpha=config.transparency, label="$(dim)D")
        end
    end
    
    # Add quality threshold lines
    hlines!(ax1, [data.excellent_threshold], color=:green, linestyle=:dash, 
           linewidth=config.line_width, alpha=0.7, label="Excellent")
    hlines!(ax1, [data.good_threshold], color=:orange, linestyle=:dash,
           linewidth=config.line_width, alpha=0.7, label="Good") 
    hlines!(ax1, [data.acceptable_threshold], color=:red, linestyle=:dash,
           linewidth=config.line_width, alpha=0.7, label="Acceptable")
    
    if config.show_legend
        axislegend(ax1, position=config.legend_position)
    end
    
    # Condition number subplot (if data available)
    valid_cond = .!isnan.(data.condition_numbers)
    if any(valid_cond)
        ax2 = Axis(fig[1, 2],
                   title="Condition Number vs Degree",
                   xlabel="Polynomial Degree", 
                   ylabel="Condition Number",
                   yscale=log10)
        
        for (i, dim) in enumerate(unique_dims)
            dim_mask = (data.dimensions .== dim) .& valid_cond
            if any(dim_mask)
                color = color_palette[mod1(i, length(color_palette))]
                scatter!(ax2, data.degrees[dim_mask], data.condition_numbers[dim_mask],
                        color=color, markersize=config.marker_size, alpha=config.transparency)
            end
        end
        
        # Stability threshold
        hlines!(ax2, [1e12], color=:orange, linestyle=:dash, 
               linewidth=config.line_width, label="Stability Limit")
        if config.show_legend
            axislegend(ax2, position=config.legend_position)
        end
    end
    
    # Quality distribution histogram
    ax3 = Axis(fig[2, 1:2], 
               title="Quality Distribution",
               xlabel="L2-Norm Quality Categories",
               ylabel="Number of Experiments")
    
    # Categorize experiments
    excellent_count = sum(data.l2_norms .< data.excellent_threshold)
    good_count = sum((data.l2_norms .>= data.excellent_threshold) .& 
                    (data.l2_norms .< data.good_threshold))
    acceptable_count = sum((data.l2_norms .>= data.good_threshold) .& 
                          (data.l2_norms .< data.acceptable_threshold))
    poor_count = sum(data.l2_norms .>= data.acceptable_threshold)
    
    categories = ["Excellent", "Good", "Acceptable", "Poor"]
    counts = [excellent_count, good_count, acceptable_count, poor_count]
    colors_bar = [:green, :orange, :yellow, :red]
    
    barplot!(ax3, 1:4, counts, color=colors_bar, alpha=config.transparency)
    ax3.xticks = (1:4, categories)
    
    if config.grid
        ax1.xgridvisible = true
        ax1.ygridvisible = true
        if any(valid_cond)
            ax2.xgridvisible = true
            ax2.ygridvisible = true
        end
        ax3.xgridvisible = true
        ax3.ygridvisible = true
    end
    
    # Save if requested
    if config.save_path !== nothing
        save(config.save_path, fig)
        println("📊 L2-degree analysis plot saved to: $(config.save_path)")
    end
    
    return fig
end

# =============================================================================
# Parameter Space Plot Implementation  
# =============================================================================

function VisualizationFramework.render_plot(renderer::CairoMakieRenderer,
                                           data::ParameterSpaceData,
                                           config::PlotConfig)
    CairoMakie.activate!()
    
    n_dims = size(data.points, 2)
    
    if n_dims == 1
        return render_1d_parameter_space(data, config)
    elseif n_dims == 2
        return render_2d_parameter_space(data, config)
    else
        return render_nd_parameter_space(data, config)
    end
end

function render_1d_parameter_space(data::ParameterSpaceData, config::PlotConfig)
    fig = Figure(resolution=config.figure_size)
    
    ax = Axis(fig[1, 1],
              title=isempty(config.title) ? "1D Parameter Space" : config.title,
              xlabel=data.dimension_labels[1],
              ylabel="Function Value")
    
    # Sort points for line plot
    sorted_indices = sortperm(data.points[:, 1])
    x_vals = data.points[sorted_indices, 1]
    f_vals = data.function_values[sorted_indices]
    
    lines!(ax, x_vals, f_vals, color=:blue, linewidth=config.line_width)
    scatter!(ax, data.points[:, 1], data.function_values, 
            color=data.function_values, colormap=config.color_scheme,
            markersize=config.marker_size, alpha=config.transparency)
    
    if config.grid
        ax.xgridvisible = true
        ax.ygridvisible = true
    end
    
    if config.save_path !== nothing
        save(config.save_path, fig)
        println("📊 1D parameter space plot saved to: $(config.save_path)")
    end
    
    return fig
end

function render_2d_parameter_space(data::ParameterSpaceData, config::PlotConfig)
    fig = Figure(resolution=config.figure_size)
    
    ax = Axis(fig[1, 1],
              title=isempty(config.title) ? "2D Parameter Space" : config.title,
              xlabel=data.dimension_labels[1],
              ylabel=data.dimension_labels[2])
    
    # Scatter plot colored by function value
    sc = scatter!(ax, data.points[:, 1], data.points[:, 2], 
                 color=data.function_values, colormap=config.color_scheme,
                 markersize=config.marker_size, alpha=config.transparency)
    
    # Add colorbar
    Colorbar(fig[1, 2], sc, label="Function Value")
    
    # Highlight best point
    best_idx = argmin(data.function_values)
    scatter!(ax, [data.points[best_idx, 1]], [data.points[best_idx, 2]], 
            color=:red, marker=:star5, markersize=config.marker_size*2,
            label="Best Point")
    
    if config.show_legend
        axislegend(ax, position=config.legend_position)
    end
    
    if config.grid
        ax.xgridvisible = true
        ax.ygridvisible = true
    end
    
    if config.save_path !== nothing
        save(config.save_path, fig)
        println("📊 2D parameter space plot saved to: $(config.save_path)")
    end
    
    return fig
end

function render_nd_parameter_space(data::ParameterSpaceData, config::PlotConfig)
    n_dims = size(data.points, 2)
    
    # Create pairwise scatter plot matrix
    n_plots = min(n_dims, 4)  # Limit to 4x4 grid for readability
    fig = Figure(resolution=config.figure_size)
    
    for i in 1:n_plots, j in 1:n_plots
        ax = Axis(fig[i, j], 
                  xlabel=i == n_plots ? data.dimension_labels[j] : "",
                  ylabel=j == 1 ? data.dimension_labels[i] : "")
        
        if i == j
            # Diagonal: histogram of dimension values
            hist!(ax, data.points[:, i], bins=20, color=(:blue, config.transparency))
        else
            # Off-diagonal: scatter plot
            scatter!(ax, data.points[:, j], data.points[:, i],
                    color=data.function_values, colormap=config.color_scheme,
                    markersize=max(2.0, config.marker_size/2), 
                    alpha=config.transparency)
        end
    end
    
    # Add overall title
    Label(fig[0, :], isempty(config.title) ? "$(n_dims)D Parameter Space" : config.title,
          fontsize=16)
    
    if config.save_path !== nothing
        save(config.save_path, fig)
        println("📊 $(n_dims)D parameter space plot saved to: $(config.save_path)")
    end
    
    return fig
end

# =============================================================================
# Convergence Trajectory Plot Implementation
# =============================================================================

function VisualizationFramework.render_plot(renderer::GLMakieRenderer,
                                           data::ConvergenceTrajectoryData, 
                                           config::PlotConfig)
    GLMakie.activate!()
    
    # Check dimensionality of trajectories
    max_dim = maximum([size(traj, 2) for traj in values(data.trajectories)])
    
    if max_dim == 1
        return render_1d_convergence(data, config)
    elseif max_dim == 2
        return render_2d_convergence(data, config)
    else
        return render_nd_convergence(data, config)
    end
end

function render_1d_convergence(data::ConvergenceTrajectoryData, config::PlotConfig)
    fig = Figure(resolution=config.figure_size)
    
    ax = Axis(fig[1, 1],
              title=isempty(config.title) ? "1D Convergence Trajectories" : config.title,
              xlabel="Iteration",
              ylabel="Position")
    
    for (i, name) in enumerate(data.algorithm_names)
        if haskey(data.trajectories, name)
            traj = data.trajectories[name][:, 1]  # First dimension
            color = data.colors[i]
            lines!(ax, 1:length(traj), traj, color=color, linewidth=config.line_width,
                  label=name, alpha=config.transparency)
        end
    end
    
    if config.show_legend
        axislegend(ax, position=config.legend_position)
    end
    
    if config.save_path !== nothing
        save(config.save_path, fig)
        println("📊 1D convergence plot saved to: $(config.save_path)")
    end
    
    return fig
end

function render_2d_convergence(data::ConvergenceTrajectoryData, config::PlotConfig)
    fig = Figure(resolution=config.figure_size)
    
    ax = Axis(fig[1, 1], 
              title=isempty(config.title) ? "2D Convergence Trajectories" : config.title,
              xlabel="x₁", ylabel="x₂")
    
    for (i, name) in enumerate(data.algorithm_names)
        if haskey(data.trajectories, name)
            traj = data.trajectories[name]
            color = data.colors[i]
            
            # Plot trajectory
            lines!(ax, traj[:, 1], traj[:, 2], color=color, linewidth=config.line_width,
                  alpha=config.transparency, label=name)
            
            # Mark start and end points
            if size(traj, 1) > 0
                scatter!(ax, [traj[1, 1]], [traj[1, 2]], color=color, marker=:circle,
                        markersize=config.marker_size, label="")
                scatter!(ax, [traj[end, 1]], [traj[end, 2]], color=color, marker=:star5,
                        markersize=config.marker_size*1.5, label="")
            end
        end
    end
    
    if config.show_legend
        axislegend(ax, position=config.legend_position)
    end
    
    # Function value evolution subplot
    ax2 = Axis(fig[2, 1],
               title="Function Value Evolution", 
               xlabel="Iteration",
               ylabel="Function Value",
               yscale=log10)
    
    for (i, name) in enumerate(data.algorithm_names)
        if haskey(data.function_values, name) && !isempty(data.function_values[name])
            values = data.function_values[name]
            color = data.colors[i]
            lines!(ax2, 1:length(values), values, color=color, linewidth=config.line_width,
                  alpha=config.transparency)
        end
    end
    
    if config.grid
        ax.xgridvisible = true
        ax.ygridvisible = true
        ax2.xgridvisible = true
        ax2.ygridvisible = true
    end
    
    if config.save_path !== nothing
        save(config.save_path, fig)
        println("📊 2D convergence plot saved to: $(config.save_path)")
    end
    
    return fig
end

function render_nd_convergence(data::ConvergenceTrajectoryData, config::PlotConfig)
    # For high-dimensional trajectories, show function value evolution and distance metrics
    fig = Figure(resolution=config.figure_size)
    
    # Function value evolution
    ax1 = Axis(fig[1, 1],
               title="Function Value Evolution",
               xlabel="Iteration", 
               ylabel="Function Value",
               yscale=log10)
    
    for (i, name) in enumerate(data.algorithm_names)
        if haskey(data.function_values, name) && !isempty(data.function_values[name])
            values = data.function_values[name]
            color = data.colors[i]
            lines!(ax1, 1:length(values), values, color=color, linewidth=config.line_width,
                  alpha=config.transparency, label=name)
        end
    end
    
    if config.show_legend
        axislegend(ax1, position=config.legend_position)
    end
    
    # Distance from start
    ax2 = Axis(fig[1, 2],
               title="Distance from Start",
               xlabel="Iteration",
               ylabel="Distance")
    
    for (i, name) in enumerate(data.algorithm_names)
        if haskey(data.trajectories, name)
            traj = data.trajectories[name]
            if size(traj, 1) > 1
                start_point = traj[1, :]
                distances = [norm(traj[j, :] - start_point) for j in 1:size(traj, 1)]
                color = data.colors[i]
                lines!(ax2, 1:length(distances), distances, color=color, 
                      linewidth=config.line_width, alpha=config.transparency)
            end
        end
    end
    
    # Step size evolution  
    ax3 = Axis(fig[2, 1:2],
               title="Step Size Evolution", 
               xlabel="Iteration",
               ylabel="Step Size")
    
    for (i, name) in enumerate(data.algorithm_names)
        if haskey(data.trajectories, name)
            traj = data.trajectories[name]
            if size(traj, 1) > 1
                step_sizes = [norm(traj[j, :] - traj[j-1, :]) for j in 2:size(traj, 1)]
                color = data.colors[i]
                lines!(ax3, 2:size(traj, 1), step_sizes, color=color,
                      linewidth=config.line_width, alpha=config.transparency)
            end
        end
    end
    
    if config.grid
        for ax in [ax1, ax2, ax3]
            ax.xgridvisible = true
            ax.ygridvisible = true
        end
    end
    
    Label(fig[0, :], isempty(config.title) ? "High-Dimensional Convergence Analysis" : config.title,
          fontsize=16)
    
    if config.save_path !== nothing
        save(config.save_path, fig)
        println("📊 High-dimensional convergence plot saved to: $(config.save_path)")
    end
    
    return fig
end

# =============================================================================
# Extension Initialization
# =============================================================================

function __init__()
    # Register the Makie-based renderers
    VisualizationFramework.register_plot_renderer!(L2DegreeAnalysisData, CairoMakieRenderer(), set_default=true)
    VisualizationFramework.register_plot_renderer!(ParameterSpaceData, CairoMakieRenderer(), set_default=true)
    VisualizationFramework.register_plot_renderer!(ConvergenceTrajectoryData, GLMakieRenderer(), set_default=true)
    
    println("✅ GlobtimVisualizationFrameworkExt loaded - Makie plotting available")
end

end # module GlobtimVisualizationFrameworkExt