"""
    valley_walking_visualization.jl

Simplified visualization functions for valley walking results.
Provides clean, focused plots using GLMakie.

Main functions:
- `plot_valley_walk_simple`: Creates a 2-panel figure with level sets and function values
- `plot_level_sets_with_path`: Plots the 2D level sets with valley walking path
- `plot_function_values_along_path`: Plots function values along the path

Author: Valley Walking Module
Date: 2025
"""

using GLMakie
using DataFrames
using LinearAlgebra
using Colors
using Printf

# Include polynomial evaluation functions
include("polynomial_evaluation.jl")

"""
    plot_valley_walk_simple(valley_results, objective_func, domain_bounds; kwargs...)

Create a simple 2-panel visualization showing:
1. Left panel: 2D level sets with valley walking path
2. Right panel: Function values along the path

This is the main visualization function that creates a clean, publication-ready figure.

# Arguments
- `valley_results`: Array of valley walking results, where each result contains:
  - `points`: Array of 2D points along the path
  - `f_values`: Function values at each point
  - `start_point`: Starting point of the walk
  - `source` (optional): Label for the path source (e.g., "Raw critical points", "Refined critical points")
- `objective_func`: The objective function f(x) being minimized, where x is a 2D vector
- `domain_bounds`: Tuple (x_min, x_max, y_min, y_max) defining the plot domain

# Keyword Arguments
- `fig_size = (1200, 500)`: Figure size in pixels (width, height)
- `show_true_minimum = nothing`: Optional [x, y] coordinates of true minimum to display
- `path_index = 1`: Which path to plot if valley_results contains multiple paths (set to :all to plot all)
- `colormap = :viridis`: Colormap for the level sets
- `use_log_scale = true`: Whether to use log scale for function values
- `raw_color = :red`: Color for paths from raw critical points
- `refined_color = :blue`: Color for paths from refined critical points

# Returns
- `fig`: GLMakie Figure object that can be displayed or saved

# Example
```julia
# Single valley walk result
valley_result = enhanced_valley_walk(rosenbrock_2d, [0.0, 0.0])
fig = plot_valley_walk_simple(
    [valley_result], 
    rosenbrock_2d, 
    (-2, 2, -1, 3),
    show_true_minimum = [1.0, 1.0]
)
display(fig)
GLMakie.save("valley_walk.png", fig)
```
"""
function plot_valley_walk_simple(valley_results, objective_func, domain_bounds;
                                fig_size = (2000, 500),
                                show_true_minimum = nothing,
                                path_index = 1,
                                colormap = :viridis,
                                use_log_scale = true,
                                raw_color = :red,
                                refined_color = :blue,
                                degree_colors = Dict(4 => :red, 6 => :blue, 8 => :purple))
    
    # Create figure with consistent styling
    fig = Figure(size=fig_size, fontsize=14)
    
    # First panel: Level sets with paths (linear scale)
    ax_level_linear = Axis(fig[1, 1],
        xlabel = "x₁",
        ylabel = "x₂",
        title = "Level Sets (Linear Scale)",
        aspect = DataAspect(),
        titlesize = 16,
        xlabelsize = 14,
        ylabelsize = 14
    )
    
    # Plot level sets background (linear scale)
    plot_level_sets_background!(ax_level_linear, objective_func, domain_bounds,
                               colormap = colormap,
                               use_log_scale = false)
    
    # Second panel: Level sets with paths (log scale)
    ax_level_log = Axis(fig[1, 3],
        xlabel = "x₁",
        ylabel = "x₂",
        title = "Level Sets (Log Scale)",
        aspect = DataAspect(),
        titlesize = 16,
        xlabelsize = 14,
        ylabelsize = 14
    )
    
    # Plot level sets background (log scale)
    plot_level_sets_background!(ax_level_log, objective_func, domain_bounds,
                               colormap = colormap,
                               use_log_scale = true)
    
    # Determine which paths to plot
    if path_index == :all
        paths_to_plot = valley_results
    else
        if path_index > length(valley_results)
            @warn "Path index $path_index exceeds number of paths. Using all paths."
            paths_to_plot = valley_results
        else
            paths_to_plot = [valley_results[path_index]]
        end
    end
    
    # Plot all selected paths on BOTH level set axes
    # Track which path labels we've already used to avoid duplicates
    used_path_labels_linear = Set{String}()
    used_path_labels_log = Set{String}()
    
    for result in paths_to_plot
        # Determine color based on degree
        path_color = if haskey(result, :degree) && haskey(degree_colors, result.degree)
            degree_colors[result.degree]
        else
            raw_color  # fallback color
        end
        
        # Determine label for path (only use once per type per axis)
        if haskey(result, :degree)
            degree_label = "Paths from degree $(result.degree)"
            path_label_linear = if degree_label ∉ used_path_labels_linear
                push!(used_path_labels_linear, degree_label)
                degree_label
            else
                nothing
            end
            path_label_log = if degree_label ∉ used_path_labels_log
                push!(used_path_labels_log, degree_label)
                degree_label
            else
                nothing
            end
        else
            path_label_linear = nothing
            path_label_log = nothing
        end
        
        # Plot the path on both axes
        plot_valley_path!(ax_level_linear, result, path_color, label=path_label_linear)
        plot_valley_path!(ax_level_log, result, path_color, label=path_label_log)
    end
    
    # Don't show separate true minimum - it's already shown as one of the optimized minima
    
    # Don't add legend here - will be added at the bottom of the figure
    
    # Get the heatmap data for colorbars
    x_min, x_max, y_min, y_max = domain_bounds
    x_range = range(x_min, x_max, length=200)
    y_range = range(y_min, y_max, length=200)
    Z = [objective_func([x, y]) for y in y_range, x in x_range]
    
    # Add colorbar for linear scale level sets
    Colorbar(fig[1, 2],
             limits = (minimum(Z), maximum(Z)),
             colormap = colormap,
             label = "f(x₁, x₂)",
             labelsize = 14,
             width = 20)
    
    # Add colorbar for log scale level sets
    Z_log = log10.(Z .+ 1e-10)
    Colorbar(fig[1, 4],
             limits = (minimum(Z_log), maximum(Z_log)),
             colormap = colormap,
             label = "log₁₀(f(x₁, x₂))",
             labelsize = 14,
             width = 20)
    
    # Third panel: Function values along paths (log scale)
    ax_values_log = Axis(fig[1, 5],
        xlabel = "Step Number",
        ylabel = "log₁₀(f(x))",
        title = "Function Values (Log Scale)",
        titlesize = 16,
        xlabelsize = 14,
        ylabelsize = 14,
        yscale = log10
    )
    
    # Fourth panel: Function values along paths (linear scale)
    ax_values_linear = Axis(fig[1, 6],
        xlabel = "Step Number",
        ylabel = "f(x)",
        title = "Function Values (Linear Scale)",
        titlesize = 16,
        xlabelsize = 14,
        ylabelsize = 14
    )
    
    # Plot function values for all selected paths on both axes
    # Track which labels we've already used to avoid duplicates
    used_labels_log = Set{String}()
    used_labels_linear = Set{String}()
    
    for result in paths_to_plot
        # Determine color based on degree
        path_color = if haskey(result, :degree) && haskey(degree_colors, result.degree)
            degree_colors[result.degree]
        else
            raw_color  # fallback color
        end
        
        # Create appropriate label based on degree or source
        if haskey(result, :degree)
            degree_label = "Paths from degree $(result.degree)"
            label_log = if degree_label ∉ used_labels_log
                push!(used_labels_log, degree_label)
                degree_label
            else
                nothing
            end
            label_linear = if degree_label ∉ used_labels_linear
                push!(used_labels_linear, degree_label)
                degree_label
            else
                nothing
            end
        else
            source_label = haskey(result, :source) ? result.source : "Valley Path"
            label_log = if source_label ∉ used_labels_log
                push!(used_labels_log, source_label)
                source_label
            else
                nothing
            end
            label_linear = if source_label ∉ used_labels_linear
                push!(used_labels_linear, source_label)
                source_label
            else
                nothing
            end
        end
        
        # Plot on log scale axis
        plot_function_values_along_path!(ax_values_log, result,
                                       line_color = path_color,
                                       marker_color = path_color,
                                       show_markers = false,
                                       label = label_log)
        
        # Plot on linear scale axis
        plot_function_values_along_path!(ax_values_linear, result,
                                       line_color = path_color,
                                       marker_color = path_color,
                                       show_markers = false,
                                       label = label_linear)
    end
    
    # Adjust layout for optimal spacing
    colsize!(fig.layout, 1, Relative(0.22))  # Linear level set plot
    colsize!(fig.layout, 2, Relative(0.04))  # Colorbar
    colsize!(fig.layout, 3, Relative(0.22))  # Log level set plot
    colsize!(fig.layout, 4, Relative(0.04))  # Colorbar
    colsize!(fig.layout, 5, Relative(0.24))  # Log scale function plot
    colsize!(fig.layout, 6, Relative(0.24))  # Linear scale function plot
    colgap!(fig.layout, 10)
    
    # Add legends below the plots if there are multiple path types or critical points
    if path_index == :all
        # Create legend for critical points below level set plots
        # This will include raw critical points by degree and optimized minima
        Legend(fig[2, 1:4], ax_level_linear,
               tellheight = true, tellwidth = false,
               orientation = :horizontal,
               labelsize = 11,
               nbanks = 2,  # Allow 2 rows
               colgap = 20,
               halign = :center,
               valign = :top)
        
        # Create legend for paths below function value plots
        # This will include paths by degree and manual starting points
        Legend(fig[2, 5:6], ax_values_log, 
               tellheight = true, tellwidth = false,
               orientation = :horizontal,
               labelsize = 11,
               halign = :center,
               valign = :top)
    end
    
    return fig
end

"""
    plot_valley_walk_with_error(valley_results, objective_func, pol, TR, domain_bounds; kwargs...)

Create a 3-panel visualization showing:
1. Left panel: 2D level sets with valley walking path
2. Middle panel: Function values along the path
3. Right panel: Approximation error |f(x) - w_d(x)|

# Arguments
- `valley_results`: Array of valley walking results
- `objective_func`: The objective function f(x)
- `pol`: ApproxPoly object (polynomial approximant)
- `TR`: test_input object with domain information
- `domain_bounds`: Tuple (x_min, x_max, y_min, y_max)

# Keyword Arguments
Same as plot_valley_walk_simple, plus:
- `error_use_log_scale = true`: Whether to use log scale for error values
- `n_error_contours = 20`: Number of contour lines for error plot
"""
function plot_valley_walk_with_error(valley_results, objective_func, pol, TR, domain_bounds;
                                    fig_size = (1800, 500),
                                    show_true_minimum = nothing,
                                    path_index = 1,
                                    colormap = :viridis,
                                    use_log_scale = true,
                                    raw_color = :red,
                                    refined_color = :blue,
                                    degree_colors = Dict(4 => :red, 6 => :blue, 8 => :purple),
                                    error_use_log_scale = true,
                                    n_error_contours = 20)
    
    # Create figure with consistent styling
    fig = Figure(size=fig_size, fontsize=14)
    
    # Left panel: Level sets with paths
    ax_level = Axis(fig[1, 1],
        xlabel = "x₁",
        ylabel = "x₂",
        title = "Function Level Sets with Valley Paths",
        aspect = DataAspect(),
        titlesize = 16,
        xlabelsize = 14,
        ylabelsize = 14
    )
    
    # Plot level sets background first (without log scale for 2D plot)
    plot_level_sets_background!(ax_level, objective_func, domain_bounds,
                               colormap = colormap,
                               use_log_scale = false)
    
    # Determine which paths to plot
    if path_index == :all
        paths_to_plot = valley_results
    else
        if path_index > length(valley_results)
            @warn "Path index $path_index exceeds number of paths. Using all paths."
            paths_to_plot = valley_results
        else
            paths_to_plot = [valley_results[path_index]]
        end
    end
    
    # Plot all selected paths
    used_path_labels = Set{String}()
    
    for result in paths_to_plot
        # Determine color based on degree
        path_color = if haskey(result, :degree) && haskey(degree_colors, result.degree)
            degree_colors[result.degree]
        else
            raw_color  # fallback color
        end
        
        # Determine label for path (only use once per type)
        path_label = nothing
        if haskey(result, :degree)
            degree_label = "Paths from degree $(result.degree)"
            if degree_label ∉ used_path_labels
                push!(used_path_labels, degree_label)
                path_label = degree_label
            end
        end
        
        # Plot the path with or without label
        plot_valley_path!(ax_level, result, path_color, label=path_label)
    end
    
    # Add colorbar for level sets
    if use_log_scale
        cb_label = "log₁₀(f(x₁, x₂))"
    else
        cb_label = "f(x₁, x₂)"
    end
    
    # Get the heatmap limits for colorbar
    x_min, x_max, y_min, y_max = domain_bounds
    x_range = range(x_min, x_max, length=200)
    y_range = range(y_min, y_max, length=200)
    Z = [objective_func([x, y]) for y in y_range, x in x_range]
    
    if use_log_scale
        Z_plot = log10.(Z .+ 1e-10)
    else
        Z_plot = Z
    end
    
    Colorbar(fig[1, 2],
             limits = (minimum(Z_plot), maximum(Z_plot)),
             colormap = colormap,
             label = cb_label,
             labelsize = 14,
             width = 20)
    
    # Middle panel: Function values along paths
    ax_values = Axis(fig[1, 3],
        xlabel = "Step Number",
        ylabel = "Function Value f(x)",
        title = "Function Values Along Valley Paths",
        titlesize = 16,
        xlabelsize = 14,
        ylabelsize = 14,
        yscale = use_log_scale ? log10 : identity
    )
    
    # Plot function values for all selected paths
    used_labels = Set{String}()
    
    for result in paths_to_plot
        # Determine color based on degree
        path_color = if haskey(result, :degree) && haskey(degree_colors, result.degree)
            degree_colors[result.degree]
        else
            raw_color  # fallback color
        end
        
        # Create appropriate label
        if haskey(result, :degree)
            degree_label = "Paths from degree $(result.degree)"
            label = if degree_label ∉ used_labels
                push!(used_labels, degree_label)
                degree_label
            else
                nothing
            end
        else
            label = nothing
        end
        
        plot_function_values_along_path!(ax_values, result,
                                       line_color = path_color,
                                       marker_color = path_color,
                                       show_markers = false,
                                       label = label)
    end
    
    # Right panel: Approximation error
    ax_error = Axis(fig[1, 5],
        xlabel = "x₁",
        ylabel = "x₂",
        title = "Approximation Error |f - w_$(pol.degree)|",
        aspect = DataAspect(),
        titlesize = 16,
        xlabelsize = 14,
        ylabelsize = 14
    )
    
    # Compute approximation error on grid
    x_range_error = range(x_min, x_max, length=100)
    y_range_error = range(y_min, y_max, length=100)
    Z_error = compute_approximation_error_on_grid(objective_func, pol, TR, x_range_error, y_range_error)
    
    # Apply log scale if requested
    if error_use_log_scale
        # Take absolute value and add small constant to avoid log(0)
        Z_error_plot = log10.(abs.(Z_error) .+ 1e-16)
        error_cb_label = "log₁₀|f - w_$(pol.degree)|"
    else
        Z_error_plot = abs.(Z_error)
        error_cb_label = "|f - w_$(pol.degree)|"
    end
    
    # Create error heatmap
    heatmap!(ax_error, x_range_error, y_range_error, Z_error_plot,
             colormap = :plasma,
             transparency = false)
    
    # Add contour lines
    contour!(ax_error, x_range_error, y_range_error, Z_error_plot,
             levels = n_error_contours,
             color = :white,
             linewidth = 1,
             alpha = 0.5)
    
    # Set axis limits
    xlims!(ax_error, x_min, x_max)
    ylims!(ax_error, y_min, y_max)
    
    # Add colorbar for error plot
    Colorbar(fig[1, 6],
             limits = extrema(Z_error_plot),
             colormap = :plasma,
             label = error_cb_label,
             labelsize = 14,
             width = 20)
    
    # Adjust layout for optimal spacing
    colsize!(fig.layout, 1, Relative(0.3))   # Level set plot
    colsize!(fig.layout, 2, Relative(0.05))  # Colorbar
    colsize!(fig.layout, 3, Relative(0.3))   # Function values plot
    colsize!(fig.layout, 4, Relative(0.02))  # Space
    colsize!(fig.layout, 5, Relative(0.3))   # Error plot
    colsize!(fig.layout, 6, Relative(0.05))  # Colorbar
    colgap!(fig.layout, 10)
    
    # Add legends below the plots if there are multiple path types
    if path_index == :all
        # Create legend for paths below middle plot
        Legend(fig[2, 3], ax_values, 
               tellheight = true, tellwidth = false,
               orientation = :horizontal,
               labelsize = 11,
               halign = :center,
               valign = :top)
    end
    
    return fig
end

# Keep the original function for backwards compatibility but mark as deprecated
function plot_valley_paths_2d(valley_results, objective_func, domain_bounds; kwargs...)
    @warn "plot_valley_paths_2d is deprecated. Use plot_valley_walk_simple instead."
    return plot_valley_walk_simple(valley_results, objective_func, domain_bounds; kwargs...)
end

# Legacy function - kept for compatibility
function plot_paths_on_axis!(ax, valley_results, path_colors)
    for (i, result) in enumerate(valley_results)
        plot_level_sets_with_path!(ax, result, nothing, (0, 1, 0, 1),
                                  path_color = path_colors[mod1(i, length(path_colors))])
    end
end

# Legacy function - kept for compatibility with old code
function create_function_evolution_plot!(grid_pos, valley_results, path_colors)
    # Create axis with basic setup
    ax_f = Axis(grid_pos,
        xlabel = "Step Number",
        ylabel = "Function Value f(x)",
        title = "Function Decrease Along Paths",
        yscale = log10
    )
    
    # Plot each path
    for (i, result) in enumerate(valley_results)
        plot_function_values_along_path!(ax_f, result, 
                                       line_color = path_colors[mod1(i, length(path_colors))],
                                       show_markers = true)
    end
    
    return ax_f
end

"""
    plot_critical_points!(ax, df_critical_points; kwargs...)

Add critical points from polynomial approximation to an existing 2D plot.

# Arguments
- `ax`: GLMakie Axis to add points to
- `df_critical_points`: DataFrame with columns x1, x2 containing critical point coordinates

# Keyword Arguments
- `color = :red`: Color for the critical points
- `markersize = 18`: Size of the markers
- `marker = :diamond`: Marker shape
- `label = "Critical Points"`: Label for legend

# Details
Critical points are where the gradient of the polynomial approximation is zero.
These are candidate locations for minima, maxima, and saddle points.
"""
function plot_critical_points!(ax, df_critical_points;
                              color = :red,
                              markersize = 18,
                              marker = :diamond,
                              label = "Critical Points")
    if !isempty(df_critical_points)
        scatter!(ax, df_critical_points.x1, df_critical_points.x2,
                color = color, 
                markersize = markersize, 
                marker = marker,
                strokecolor = :white, 
                strokewidth = 3,
                label = label)
    end
end

"""
    plot_level_sets_with_path!(ax, valley_result, objective_func, domain_bounds; kwargs...)

Plot 2D level sets of the objective function with the valley walking path overlaid.

# Arguments
- `ax`: GLMakie Axis to plot on
- `valley_result`: Single valley walking result containing points and other data
- `objective_func`: The objective function to visualize
- `domain_bounds`: Tuple (x_min, x_max, y_min, y_max)

# Keyword Arguments
- `show_true_minimum = nothing`: Optional [x, y] coordinates of true minimum
- `colormap = :viridis`: Colormap for the heatmap
- `use_log_scale = true`: Whether to use log scale for function values
- `n_grid_points = 200`: Grid resolution for level sets
- `n_contours = 20`: Number of contour lines
- `path_color = :red`: Color of the valley walking path
- `path_linewidth = 4`: Line width of the path
"""
function plot_level_sets_with_path!(ax, valley_result, objective_func, domain_bounds;
                                   show_true_minimum = nothing,
                                   colormap = :viridis,
                                   use_log_scale = true,
                                   n_grid_points = 200,
                                   n_contours = 20,
                                   path_color = :red,
                                   path_linewidth = 4)
    
    # Unpack domain bounds
    x_min, x_max, y_min, y_max = domain_bounds
    
    # Create grid for level sets
    x_range = range(x_min, x_max, length=n_grid_points)
    y_range = range(y_min, y_max, length=n_grid_points)
    
    # Evaluate function on grid
    Z = [objective_func([x, y]) for y in y_range, x in x_range]
    
    # Apply log scale if requested
    if use_log_scale
        # Clip small/negative values to avoid log issues
        Z_plot = log10.(max.(Z, 1e-16))
    else
        Z_plot = Z
    end
    
    # Create heatmap
    heatmap!(ax, x_range, y_range, Z_plot, 
             colormap = colormap,
             transparency = false)
    
    # Add contour lines
    contour!(ax, x_range, y_range, Z_plot,
             levels = n_contours,
             color = :white,
             linewidth = 1,
             alpha = 0.5)
    
    # Plot the valley walking path
    points = valley_result.points
    xs = [p[1] for p in points]
    ys = [p[2] for p in points]
    
    # Main path line
    lines!(ax, xs, ys, 
           color = path_color,
           linewidth = path_linewidth,
           label = "Valley Path")
    
    # Start point
    scatter!(ax, [xs[1]], [ys[1]], 
             color = path_color,
             markersize = 20,
             marker = :circle,
             strokecolor = :white,
             strokewidth = 2,
             label = "Start")
    
    # End point
    scatter!(ax, [xs[end]], [ys[end]], 
             color = path_color,
             markersize = 25,
             marker = :star5,
             strokecolor = :white,
             strokewidth = 2,
             label = "End")
    
    # Add arrows along path for direction
    add_simple_path_arrows!(ax, xs, ys, path_color)
    
    # Show true minimum if provided
    if show_true_minimum !== nothing
        scatter!(ax, [show_true_minimum[1]], [show_true_minimum[2]],
                 color = :gold,
                 markersize = 30,
                 marker = :star5,
                 strokecolor = :black,
                 strokewidth = 2,
                 label = "True Minimum")
    end
    
    # Set axis limits
    xlims!(ax, x_min, x_max)
    ylims!(ax, y_min, y_max)
end

"""
    plot_level_sets_background!(ax, objective_func, domain_bounds; kwargs...)

Plot just the level sets background without any paths.
"""
function plot_level_sets_background!(ax, objective_func, domain_bounds;
                                    colormap = :viridis,
                                    use_log_scale = true,
                                    n_grid_points = 200,
                                    n_contours = 20)
    
    # Unpack domain bounds
    x_min, x_max, y_min, y_max = domain_bounds
    
    # Create grid for level sets
    x_range = range(x_min, x_max, length=n_grid_points)
    y_range = range(y_min, y_max, length=n_grid_points)
    
    # Evaluate function on grid
    Z = [objective_func([x, y]) for y in y_range, x in x_range]
    
    # Apply log scale if requested
    if use_log_scale
        Z_plot = log10.(max.(Z, 1e-16))
    else
        Z_plot = Z
    end
    
    # Create heatmap
    heatmap!(ax, x_range, y_range, Z_plot, 
             colormap = colormap,
             transparency = false)
    
    # Add contour lines
    contour!(ax, x_range, y_range, Z_plot,
             levels = n_contours,
             color = :white,
             linewidth = 1,
             alpha = 0.5)
    
    # Set axis limits
    xlims!(ax, x_min, x_max)
    ylims!(ax, y_min, y_max)
end

"""
    plot_valley_path!(ax, valley_result, color; label=nothing)

Plot a single valley walking path on the axis.
"""
function plot_valley_path!(ax, valley_result, color; label=nothing)
    points = valley_result.points
    xs = [p[1] for p in points]
    ys = [p[2] for p in points]
    
    # Use provided label, or nothing if not provided
    # (label management is now handled by the calling function)
    
    # Main path line
    lines!(ax, xs, ys, 
           color = color,
           linewidth = 3,
           label = label)
    
    # Don't plot individual start/end points - they clutter the visualization
    # The path itself shows the trajectory clearly
    
    # Add arrows for direction (fewer arrows for clarity)
    add_simple_path_arrows!(ax, xs, ys, color, n_arrows = 3, arrow_size = 12)
end

"""
    plot_function_values_along_path!(ax, valley_result; kwargs...)

Plot the function values along the valley walking path.

# Arguments
- `ax`: GLMakie Axis to plot on
- `valley_result`: Valley walking result containing f_values

# Keyword Arguments
- `line_color = :blue`: Color of the line
- `marker_color = :blue`: Color of the markers
- `linewidth = 3`: Line width
- `markersize = 8`: Marker size
- `show_markers = true`: Whether to show markers at each point
- `label = nothing`: Label for the path
"""
function plot_function_values_along_path!(ax, valley_result;
                                         line_color = :blue,
                                         marker_color = :blue,
                                         linewidth = 3,
                                         markersize = 8,
                                         show_markers = true,
                                         label = nothing)
    
    f_values = valley_result.f_values
    steps = 0:(length(f_values)-1)
    
    # Plot line with label
    lines!(ax, steps, f_values,
           color = line_color,
           linewidth = linewidth,
           label = label)
    
    # Optionally add markers
    if show_markers
        scatter!(ax, steps, f_values,
                 color = marker_color,
                 markersize = markersize,
                 strokecolor = :white,
                 strokewidth = 1)
    end
    
    # Add grid
    ax.xgridvisible = true
    ax.ygridvisible = true
    ax.xgridstyle = :dash
    ax.ygridstyle = :dash
end

"""
    add_simple_path_arrows!(ax, xs, ys, color)

Add directional arrows along a path to show movement direction.

# Arguments
- `ax`: GLMakie Axis
- `xs`: X coordinates of the path
- `ys`: Y coordinates of the path  
- `color`: Arrow color

# Details
Adds arrows at regular intervals along the path to indicate direction of movement.
"""
function add_simple_path_arrows!(ax, xs, ys, color;
                                n_arrows = 5,
                                arrow_size = 15)
    
    n_points = length(xs)
    if n_points < 2
        return
    end
    
    # Calculate arrow positions
    arrow_indices = unique([1 + round(Int, i * (n_points-1) / (n_arrows+1)) 
                           for i in 1:n_arrows])
    
    for idx in arrow_indices
        if idx < n_points
            # Direction vector
            dx = xs[idx+1] - xs[idx]
            dy = ys[idx+1] - ys[idx]
            
            # Normalize
            norm_factor = sqrt(dx^2 + dy^2)
            if norm_factor > 0
                dx /= norm_factor
                dy /= norm_factor
                
                # Draw arrow
                arrows!(ax, [xs[idx]], [ys[idx]], [dx], [dy],
                       color = color,
                       arrowsize = arrow_size,
                       lengthscale = 0.3)
            end
        end
    end
end