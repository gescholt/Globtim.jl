"""
Plotting Utilities for AdaptivePrecision 4D Analysis

This module provides plotting functions using CairoMakie for high-quality
static plots suitable for notebooks and publications.

Usage:
    include("Examples/plotting_utils.jl")
    
    # Create some test data
    results_df = compare_precisions()
    
    # Generate plots
    plot_precision_comparison(results_df)
    plot_scaling_analysis(scaling_results)
"""

# Check if CairoMakie is available
const MAKIE_AVAILABLE = try
    using CairoMakie
    true
catch
    println("⚠️  CairoMakie not available - install with: import Pkg; Pkg.add(\"CairoMakie\")")
    println("   Plotting functions will not work without CairoMakie")
    false
end

if MAKIE_AVAILABLE
    using DataFrames
    using Statistics
    
    """
        plot_precision_comparison(results_df; save_path=nothing)
    
    Plot comparison between Float64Precision and AdaptivePrecision performance.
    """
    function plot_precision_comparison(results_df; save_path=nothing)
        if !MAKIE_AVAILABLE
            println("❌ CairoMakie not available - cannot create plots")
            return nothing
        end
        
        fig = Figure(resolution=(800, 600))
        
        # Time overhead plot
        ax1 = Axis(fig[1, 1], 
                   title="AdaptivePrecision Performance Overhead",
                   xlabel="Test Case",
                   ylabel="Time Overhead (x)")
        
        if hasproperty(results_df, :precision_overhead)
            scatter!(ax1, 1:nrow(results_df), results_df.precision_overhead, 
                    color=:blue, markersize=10)
            hlines!(ax1, [1.0], color=:red, linestyle=:dash, linewidth=2)
            text!(ax1, nrow(results_df)/2, 1.1, text="1.0x (no overhead)", 
                  align=(:center, :bottom))
        end
        
        # L2 norm comparison
        ax2 = Axis(fig[1, 2],
                   title="L2 Norm Comparison",
                   xlabel="Test Case", 
                   ylabel="L2 Norm")
        
        if hasproperty(results_df, :float64_norm) && hasproperty(results_df, :adaptive_norm)
            scatter!(ax2, 1:nrow(results_df), results_df.float64_norm, 
                    color=:orange, markersize=8, label="Float64")
            scatter!(ax2, 1:nrow(results_df), results_df.adaptive_norm, 
                    color=:green, markersize=8, label="Adaptive")
            axislegend(ax2)
        end
        
        if save_path !== nothing
            save(save_path, fig)
            println("📊 Plot saved to: $save_path")
        end
        
        return fig
    end
    
    """
        plot_scaling_analysis(scaling_df; metric=:precision_overhead, save_path=nothing)
    
    Plot scaling behavior across degrees or sample sizes.
    """
    function plot_scaling_analysis(scaling_df; metric=:precision_overhead, save_path=nothing)
        if !MAKIE_AVAILABLE
            println("❌ CairoMakie not available - cannot create plots")
            return nothing
        end
        
        fig = Figure(resolution=(800, 600))
        ax = Axis(fig[1, 1],
                  title="Scaling Analysis: $(string(metric))",
                  xlabel="Parameter Value",
                  ylabel=string(metric))
        
        if hasproperty(scaling_df, :degree) && hasproperty(scaling_df, metric)
            # Group by degree if available
            if hasproperty(scaling_df, :degree)
                for degree in unique(scaling_df.degree)
                    subset = filter(row -> row.degree == degree, scaling_df)
                    if hasproperty(subset, :samples)
                        lines!(ax, subset.samples, getproperty(subset, metric), 
                              label="Degree $degree", linewidth=2)
                        scatter!(ax, subset.samples, getproperty(subset, metric), 
                                markersize=8)
                    end
                end
                axislegend(ax)
            else
                # Simple scatter plot
                scatter!(ax, 1:nrow(scaling_df), getproperty(scaling_df, metric),
                        color=:blue, markersize=10)
            end
        end
        
        if save_path !== nothing
            save(save_path, fig)
            println("📊 Plot saved to: $save_path")
        end
        
        return fig
    end
    
    """
        plot_sparsity_analysis(sparsity_results; save_path=nothing)
    
    Plot sparsity analysis results showing coefficient truncation effects.
    """
    function plot_sparsity_analysis(sparsity_results; save_path=nothing)
        if !MAKIE_AVAILABLE
            println("❌ CairoMakie not available - cannot create plots")
            return nothing
        end
        
        fig = Figure(resolution=(800, 600))
        
        # Sparsity vs threshold
        ax1 = Axis(fig[1, 1],
                   title="Sparsity vs Threshold",
                   xlabel="Threshold",
                   ylabel="Sparsity Ratio",
                   xscale=log10)
        
        if isa(sparsity_results, DataFrame) && hasproperty(sparsity_results, :threshold) && hasproperty(sparsity_results, :sparsity_ratio)
            scatter!(ax1, sparsity_results.threshold, sparsity_results.sparsity_ratio,
                    color=:blue, markersize=10)
            lines!(ax1, sparsity_results.threshold, sparsity_results.sparsity_ratio,
                   color=:blue, linewidth=2)
        end
        
        # Memory savings
        ax2 = Axis(fig[1, 2],
                   title="Memory Savings",
                   xlabel="Threshold",
                   ylabel="Memory Savings (%)",
                   xscale=log10)
        
        if isa(sparsity_results, DataFrame) && hasproperty(sparsity_results, :memory_savings)
            memory_savings_pct = sparsity_results.memory_savings .* 100
            scatter!(ax2, sparsity_results.threshold, memory_savings_pct,
                    color=:green, markersize=10)
            lines!(ax2, sparsity_results.threshold, memory_savings_pct,
                   color=:green, linewidth=2)
        end
        
        if save_path !== nothing
            save(save_path, fig)
            println("📊 Plot saved to: $save_path")
        end
        
        return fig
    end
    
    """
        plot_coefficient_distribution(mono_polynomial; save_path=nothing)
    
    Plot coefficient magnitude distribution for a monomial polynomial.
    """
    function plot_coefficient_distribution(mono_polynomial; save_path=nothing)
        if !MAKIE_AVAILABLE
            println("❌ CairoMakie not available - cannot create plots")
            return nothing
        end
        
        # Extract coefficients
        coeffs = [abs(coefficient(t)) for t in terms(mono_polynomial)]
        nonzero_coeffs = filter(x -> x > 0, coeffs)
        
        if isempty(nonzero_coeffs)
            println("⚠️  No non-zero coefficients to plot")
            return nothing
        end
        
        fig = Figure(resolution=(800, 600))
        
        # Histogram of coefficient magnitudes
        ax1 = Axis(fig[1, 1],
                   title="Coefficient Magnitude Distribution",
                   xlabel="log₁₀(|coefficient|)",
                   ylabel="Count")
        
        log_coeffs = log10.(nonzero_coeffs)
        hist!(ax1, log_coeffs, bins=20, color=(:blue, 0.7))
        
        # Sorted coefficient plot
        ax2 = Axis(fig[1, 2],
                   title="Sorted Coefficients",
                   xlabel="Coefficient Index",
                   ylabel="log₁₀(|coefficient|)")
        
        sorted_coeffs = sort(nonzero_coeffs, rev=true)
        lines!(ax2, 1:length(sorted_coeffs), log10.(sorted_coeffs),
               color=:red, linewidth=2)
        
        if save_path !== nothing
            save(save_path, fig)
            println("📊 Plot saved to: $save_path")
        end
        
        return fig
    end
    
    """
        create_summary_dashboard(results_dict; save_path=nothing)
    
    Create a comprehensive dashboard with multiple analysis plots.
    """
    function create_summary_dashboard(results_dict; save_path=nothing)
        if !MAKIE_AVAILABLE
            println("❌ CairoMakie not available - cannot create plots")
            return nothing
        end
        
        fig = Figure(resolution=(1200, 800))
        
        # Performance comparison (top left)
        ax1 = Axis(fig[1, 1], title="Performance Overhead")
        if haskey(results_dict, :comparison) && hasproperty(results_dict[:comparison], :precision_overhead)
            scatter!(ax1, 1:nrow(results_dict[:comparison]), 
                    results_dict[:comparison].precision_overhead,
                    color=:blue, markersize=8)
            hlines!(ax1, [1.0], color=:red, linestyle=:dash)
        end
        
        # Accuracy comparison (top right)
        ax2 = Axis(fig[1, 2], title="L2 Norm Accuracy")
        if haskey(results_dict, :comparison)
            df = results_dict[:comparison]
            if hasproperty(df, :float64_norm) && hasproperty(df, :adaptive_norm)
                scatter!(ax2, df.float64_norm, df.adaptive_norm,
                        color=:green, markersize=8)
                # Perfect accuracy line
                min_norm = min(minimum(df.float64_norm), minimum(df.adaptive_norm))
                max_norm = max(maximum(df.float64_norm), maximum(df.adaptive_norm))
                lines!(ax2, [min_norm, max_norm], [min_norm, max_norm],
                       color=:red, linestyle=:dash)
            end
        end
        
        # Scaling analysis (bottom left)
        ax3 = Axis(fig[2, 1], title="Degree Scaling")
        if haskey(results_dict, :scaling) && hasproperty(results_dict[:scaling], :degree)
            df = results_dict[:scaling]
            scatter!(ax3, df.degree, df.total_overhead, color=:orange, markersize=8)
            lines!(ax3, df.degree, df.total_overhead, color=:orange, linewidth=2)
        end
        
        # Sparsity analysis (bottom right)
        ax4 = Axis(fig[2, 2], title="Sparsity Benefits", xscale=log10)
        if haskey(results_dict, :sparsity) && hasproperty(results_dict[:sparsity], :threshold)
            df = results_dict[:sparsity]
            if hasproperty(df, :sparsity_ratio)
                scatter!(ax4, df.threshold, df.sparsity_ratio .* 100,
                        color=:purple, markersize=8)
                lines!(ax4, df.threshold, df.sparsity_ratio .* 100,
                       color=:purple, linewidth=2)
            end
        end
        
        if save_path !== nothing
            save(save_path, fig)
            println("📊 Dashboard saved to: $save_path")
        end
        
        return fig
    end
    
    # Export plotting functions
    export plot_precision_comparison, plot_scaling_analysis, plot_sparsity_analysis,
           plot_coefficient_distribution, create_summary_dashboard
    
else
    # Provide stub functions when CairoMakie is not available
    function plot_precision_comparison(args...; kwargs...)
        println("❌ CairoMakie not available - install with: import Pkg; Pkg.add(\"CairoMakie\")")
        return nothing
    end
    
    function plot_scaling_analysis(args...; kwargs...)
        println("❌ CairoMakie not available - install with: import Pkg; Pkg.add(\"CairoMakie\")")
        return nothing
    end
    
    function plot_sparsity_analysis(args...; kwargs...)
        println("❌ CairoMakie not available - install with: import Pkg; Pkg.add(\"CairoMakie\")")
        return nothing
    end
    
    function plot_coefficient_distribution(args...; kwargs...)
        println("❌ CairoMakie not available - install with: import Pkg; Pkg.add(\"CairoMakie\")")
        return nothing
    end
    
    function create_summary_dashboard(args...; kwargs...)
        println("❌ CairoMakie not available - install with: import Pkg; Pkg.add(\"CairoMakie\")")
        return nothing
    end
end

println("📊 Plotting utilities loaded (CairoMakie available: $MAKIE_AVAILABLE)")
if MAKIE_AVAILABLE
    println("💡 Available functions: plot_precision_comparison, plot_scaling_analysis, plot_sparsity_analysis, plot_coefficient_distribution, create_summary_dashboard")
else
    println("💡 Install CairoMakie to enable plotting: import Pkg; Pkg.add(\"CairoMakie\")")
end
