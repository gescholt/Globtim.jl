"""
4D Benchmark Plotting Infrastructure

Comprehensive plotting utilities for 4D benchmark analysis with:
- Distance to minimizers plots
- Sparsification analysis visualization
- Convergence tracking plots
- Comparative analysis charts
- Proper labeling and metadata integration

Usage:
    include("Examples/4d_benchmark_tests/plotting_4d.jl")
    
    # Plot distance to minimizers
    plot_distance_to_minimizers(convergence_data, "output_dir")
    
    # Sparsification analysis
    plot_sparsification_analysis(results, "output_dir")
    
    # Convergence comparison
    plot_convergence_comparison(results, "output_dir")
"""

using CairoMakie
using DataFrames
using Statistics
using Colors
using Printf
using Dates
using LinearAlgebra

# ============================================================================
# PLOTTING CONFIGURATION
# ============================================================================

"""
Standardized plotting configuration for consistent visualization.
"""
const PLOT_CONFIG = (
    # Figure settings
    figure_size = (800, 600),
    dpi = 300,
    
    # Colors for different functions (colorblind-friendly palette)
    function_colors = Dict(
        :Sphere => colorant"#1f77b4",
        :Rosenbrock => colorant"#ff7f0e", 
        :Zakharov => colorant"#2ca02c",
        :Griewank => colorant"#d62728",
        :Rastringin => colorant"#9467bd",
        :Levy => colorant"#8c564b",
        :StyblinskiTang => colorant"#e377c2",
        :Michalewicz => colorant"#7f7f7f",
        :Trid => colorant"#bcbd22",
        :RotatedHyperEllipsoid => colorant"#17becf"
    ),
    
    # Markers for different degrees
    degree_markers = Dict(
        4 => :circle,
        6 => :rect,
        8 => :diamond,
        10 => :cross,
        12 => :star5
    ),
    
    # Font settings
    title_font_size = 16,
    axis_font_size = 12,
    legend_font_size = 10
)

# ============================================================================
# DISTANCE TO MINIMIZERS PLOTTING
# ============================================================================

"""
    plot_distance_to_minimizers(convergence_data::Vector, output_dir::String; 
                               save_plots=true, show_plots=false)

Create comprehensive plots showing distance to global minimizers.
"""
function plot_distance_to_minimizers(convergence_data::Vector, output_dir::String; 
                                    save_plots=true, show_plots=false)
    
    if !isdir(output_dir)
        mkpath(output_dir)
    end
    
    println("📊 Creating distance to minimizers plots...")
    
    # Extract data for plotting
    function_names = [d.function_name for d in convergence_data if haskey(d, :function_name)]
    
    # Plot 1: Distance vs Degree for each function
    fig1 = Figure(size=PLOT_CONFIG.figure_size)
    ax1 = Axis(fig1[1, 1], 
               xlabel="Polynomial Degree", 
               ylabel="Mean Distance to Global Minimum",
               title="Distance to Global Minimum vs Polynomial Degree")
    
    for func_name in unique(function_names)
        func_data = filter(d -> get(d, :function_name, nothing) == func_name, convergence_data)
        if !isempty(func_data)
            x_vals = [d.degree for d in func_data]
            y_vals = [mean(d.tracker.distances_to_global) for d in func_data]
            
            color = get(PLOT_CONFIG.function_colors, func_name, colorant"#000000")
            lines!(ax1, x_vals, y_vals, color=color, linewidth=2, label=string(func_name))
            scatter!(ax1, x_vals, y_vals, color=color, markersize=8)
        end
    end
    
    axislegend(ax1, position=:rt)
    
    if save_plots
        save(joinpath(output_dir, "distance_vs_degree.png"), fig1)
        println("  ✓ Saved: distance_vs_degree.png")
    end
    
    # Plot 2: Convergence trajectory for each degree
    fig2 = Figure(size=(1000, 600))
    
    for (i, data) in enumerate(convergence_data)
        ax = Axis(fig2[1, i], 
                 xlabel="Initial Distance", 
                 ylabel="Final Distance",
                 title="Degree $(data.degree)")
        
        # Calculate initial distances (if available)
        if haskey(data, :tracker) && length(data.tracker.initial_points) > 0
            initial_dists = [norm(p - BENCHMARK_4D_FUNCTIONS[data.function_name].global_min) 
                           for p in data.tracker.initial_points]
            final_dists = data.tracker.distances_to_global
            
            scatter!(ax, initial_dists, final_dists, 
                    color=get(PLOT_CONFIG.function_colors, data.function_name, colorant"#1f77b4"),
                    markersize=6, alpha=0.7)
            
            # Add diagonal line (no improvement)
            max_dist = max(maximum(initial_dists), maximum(final_dists))
            lines!(ax, [0, max_dist], [0, max_dist], color=:gray, linestyle=:dash, alpha=0.5)
        end
    end
    
    if save_plots
        save(joinpath(output_dir, "convergence_trajectories.png"), fig2)
        println("  ✓ Saved: convergence_trajectories.png")
    end
    
    # Plot 3: Gradient norm vs Distance to minimum
    fig3 = Figure(size=PLOT_CONFIG.figure_size)
    ax3 = Axis(fig3[1, 1], 
               xlabel="Distance to Global Minimum", 
               ylabel="Gradient Norm (log scale)",
               title="Gradient Norm vs Distance to Global Minimum",
               yscale=log10)
    
    for data in convergence_data
        if haskey(data, :tracker) && length(data.tracker.distances_to_global) > 0
            distances = data.tracker.distances_to_global
            grad_norms = data.tracker.gradient_norms
            
            # Filter out NaN values
            valid_idx = .!isnan.(grad_norms) .& .!isnan.(distances) .& (grad_norms .> 0)
            
            if sum(valid_idx) > 0
                color = get(PLOT_CONFIG.function_colors, get(data, :function_name, :unknown), colorant"#1f77b4")
                marker = get(PLOT_CONFIG.degree_markers, data.degree, :circle)
                
                scatter!(ax3, distances[valid_idx], grad_norms[valid_idx], 
                        color=color, marker=marker, markersize=6, alpha=0.7,
                        label="$(get(data, :function_name, "unknown")) deg=$(data.degree)")
            end
        end
    end
    
    axislegend(ax3, position=:rt)
    
    if save_plots
        save(joinpath(output_dir, "gradient_vs_distance.png"), fig3)
        println("  ✓ Saved: gradient_vs_distance.png")
    end
    
    if show_plots
        display(fig1)
        display(fig2) 
        display(fig3)
    end
    
    return (fig1, fig2, fig3)
end

# ============================================================================
# SPARSIFICATION ANALYSIS PLOTTING
# ============================================================================

"""
    plot_sparsification_analysis(results::Vector{Benchmark4DResult}, output_dir::String;
                                save_plots=true, show_plots=false)

Create plots analyzing sparsification behavior across functions and parameters.
"""
function plot_sparsification_analysis(results::Vector{Benchmark4DResult}, output_dir::String;
                                     save_plots=true, show_plots=false)
    
    if !isdir(output_dir)
        mkpath(output_dir)
    end
    
    println("📊 Creating sparsification analysis plots...")
    
    # Plot 1: Sparsity vs Threshold for different functions
    fig1 = Figure(size=(1000, 600))
    ax1 = Axis(fig1[1, 1], 
               xlabel="Sparsification Threshold", 
               ylabel="Sparsity Gain",
               title="Sparsity Gain vs Threshold",
               xscale=log10)
    
    for result in results
        if haskey(result.sparsification_results, :results)
            thresholds = [r.threshold for r in result.sparsification_results.results]
            sparsity_gains = [r.sparsity_gain for r in result.sparsification_results.results]
            
            color = get(PLOT_CONFIG.function_colors, result.function_name, colorant"#1f77b4")
            marker = get(PLOT_CONFIG.degree_markers, result.degree, :circle)
            
            lines!(ax1, thresholds, sparsity_gains, color=color, linewidth=2)
            scatter!(ax1, thresholds, sparsity_gains, color=color, marker=marker, markersize=8,
                    label="$(result.function_name) deg=$(result.degree)")
        end
    end
    
    axislegend(ax1, position=:rb)
    
    if save_plots
        save(joinpath(output_dir, "sparsity_vs_threshold.png"), fig1)
        println("  ✓ Saved: sparsity_vs_threshold.png")
    end
    
    # Plot 2: L2 ratio preservation vs Sparsity gain
    fig2 = Figure(size=PLOT_CONFIG.figure_size)
    ax2 = Axis(fig2[1, 1], 
               xlabel="Sparsity Gain", 
               ylabel="L2 Ratio Preserved",
               title="L2 Norm Preservation vs Sparsity Gain")
    
    for result in results
        if haskey(result.sparsification_results, :results)
            sparsity_gains = [r.sparsity_gain for r in result.sparsification_results.results]
            l2_ratios = [r.l2_ratio for r in result.sparsification_results.results]
            
            color = get(PLOT_CONFIG.function_colors, result.function_name, colorant"#1f77b4")
            marker = get(PLOT_CONFIG.degree_markers, result.degree, :circle)
            
            scatter!(ax2, sparsity_gains, l2_ratios, color=color, marker=marker, markersize=8,
                    label="$(result.function_name) deg=$(result.degree)")
        end
    end
    
    # Add reference lines
    hlines!(ax2, [0.95, 0.99], color=:gray, linestyle=:dash, alpha=0.5)
    
    axislegend(ax2, position=:bl)
    
    if save_plots
        save(joinpath(output_dir, "l2_vs_sparsity.png"), fig2)
        println("  ✓ Saved: l2_vs_sparsity.png")
    end
    
    # Plot 3: Coefficient count reduction
    fig3 = Figure(size=PLOT_CONFIG.figure_size)
    ax3 = Axis(fig3[1, 1], 
               xlabel="Original Coefficient Count", 
               ylabel="Sparsified Coefficient Count",
               title="Coefficient Count Reduction")
    
    for result in results
        if haskey(result.sparsification_results, :results)
            # Use the most aggressive sparsification (smallest threshold)
            sparse_result = result.sparsification_results.results[end]  # Assuming sorted by threshold
            
            original_count = sparse_result.original_nnz
            new_count = sparse_result.new_nnz
            
            color = get(PLOT_CONFIG.function_colors, result.function_name, colorant"#1f77b4")
            marker = get(PLOT_CONFIG.degree_markers, result.degree, :circle)
            
            scatter!(ax3, [original_count], [new_count], color=color, marker=marker, markersize=10,
                    label="$(result.function_name) deg=$(result.degree)")
        end
    end
    
    # Add diagonal line (no reduction)
    max_count = maximum([r.sparsification_results.results[1].original_nnz for r in results 
                        if haskey(r.sparsification_results, :results)])
    lines!(ax3, [0, max_count], [0, max_count], color=:gray, linestyle=:dash, alpha=0.5)
    
    axislegend(ax3, position=:lt)
    
    if save_plots
        save(joinpath(output_dir, "coefficient_reduction.png"), fig3)
        println("  ✓ Saved: coefficient_reduction.png")
    end
    
    if show_plots
        display(fig1)
        display(fig2)
        display(fig3)
    end
    
    return (fig1, fig2, fig3)
end

# ============================================================================
# CONVERGENCE COMPARISON PLOTTING
# ============================================================================

"""
    plot_convergence_comparison(results::Vector{Benchmark4DResult}, output_dir::String;
                               save_plots=true, show_plots=false)

Create comparative plots showing convergence behavior across functions.
"""
function plot_convergence_comparison(results::Vector{Benchmark4DResult}, output_dir::String;
                                   save_plots=true, show_plots=false)

    if !isdir(output_dir)
        mkpath(output_dir)
    end

    println("📊 Creating convergence comparison plots...")

    # Plot 1: Convergence rate vs Polynomial degree
    fig1 = Figure(size=PLOT_CONFIG.figure_size)
    ax1 = Axis(fig1[1, 1],
               xlabel="Polynomial Degree",
               ylabel="Convergence Rate",
               title="BFGS Convergence Rate vs Polynomial Degree")

    # Group by function
    function_groups = Dict()
    for result in results
        if !haskey(function_groups, result.function_name)
            function_groups[result.function_name] = []
        end
        push!(function_groups[result.function_name], result)
    end

    for (func_name, func_results) in function_groups
        degrees = [r.degree for r in func_results]
        conv_rates = [r.convergence_metrics.convergence_rate for r in func_results]

        color = get(PLOT_CONFIG.function_colors, func_name, colorant"#1f77b4")
        lines!(ax1, degrees, conv_rates, color=color, linewidth=2, label=string(func_name))
        scatter!(ax1, degrees, conv_rates, color=color, markersize=8)
    end

    axislegend(ax1, position=:rb)

    if save_plots
        save(joinpath(output_dir, "convergence_rate_vs_degree.png"), fig1)
        println("  ✓ Saved: convergence_rate_vs_degree.png")
    end

    # Plot 2: L2 error vs Convergence rate
    fig2 = Figure(size=PLOT_CONFIG.figure_size)
    ax2 = Axis(fig2[1, 1],
               xlabel="L2 Approximation Error",
               ylabel="Convergence Rate",
               title="Convergence Rate vs Approximation Quality",
               xscale=log10)

    for result in results
        color = get(PLOT_CONFIG.function_colors, result.function_name, colorant"#1f77b4")
        marker = get(PLOT_CONFIG.degree_markers, result.degree, :circle)

        scatter!(ax2, [result.l2_error], [result.convergence_metrics.convergence_rate],
                color=color, marker=marker, markersize=10,
                label="$(result.function_name) deg=$(result.degree)")
    end

    axislegend(ax2, position=:rb)

    if save_plots
        save(joinpath(output_dir, "convergence_vs_l2_error.png"), fig2)
        println("  ✓ Saved: convergence_vs_l2_error.png")
    end

    # Plot 3: Performance comparison (time vs accuracy)
    fig3 = Figure(size=PLOT_CONFIG.figure_size)
    ax3 = Axis(fig3[1, 1],
               xlabel="Total Analysis Time (seconds)",
               ylabel="Mean Distance to Global Minimum",
               title="Performance vs Accuracy Trade-off")

    for result in results
        total_time = result.construction_time + result.analysis_time
        mean_distance = result.convergence_metrics.mean_distance_to_global

        if !isnan(mean_distance)
            color = get(PLOT_CONFIG.function_colors, result.function_name, colorant"#1f77b4")
            marker = get(PLOT_CONFIG.degree_markers, result.degree, :circle)

            scatter!(ax3, [total_time], [mean_distance],
                    color=color, marker=marker, markersize=10,
                    label="$(result.function_name) deg=$(result.degree)")
        end
    end

    axislegend(ax3, position=:rt)

    if save_plots
        save(joinpath(output_dir, "performance_vs_accuracy.png"), fig3)
        println("  ✓ Saved: performance_vs_accuracy.png")
    end

    if show_plots
        display(fig1)
        display(fig2)
        display(fig3)
    end

    return (fig1, fig2, fig3)
end
