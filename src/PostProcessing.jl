"""
    PostProcessing.jl

Unified post-processing framework for GlobTim experiment results.
Provides comprehensive analysis, visualization, and reporting capabilities.

Main components:
- ResultsLoader: Load and parse experiment outputs
- StatisticalAnalyzer: Compute comprehensive statistics  
- Visualizer: Create publication-ready plots
- ReportGenerator: Generate automated analysis reports

Author: GlobTim Team
Date: September 2025
"""
module PostProcessing

using JSON
using CSV
using DataFrames
using Statistics
using LinearAlgebra
using Printf
using Dates

# Optional plotting dependencies
const MAKIE_AVAILABLE = try
    using CairoMakie
    using GLMakie
    true
catch
    false
end

MAKIE_AVAILABLE && using Colors, ColorSchemes

export load_experiment_results, analyze_experiment, create_experiment_report,
       plot_convergence_analysis, plot_parameter_space, plot_performance_metrics,
       ExperimentResults, StatisticalSummary

"""
    ExperimentResults

Container for parsed experiment results with standardized fields.
"""
struct ExperimentResults
    metadata::Dict{String,Any}
    function_evaluations::Union{DataFrame,Nothing}
    convergence_data::Union{DataFrame,Nothing}
    critical_points::Union{DataFrame,Nothing}
    polynomial_data::Union{Dict,Nothing}
    timing_data::Union{Dict,Nothing}
    source_files::Vector{String}
end

"""
    StatisticalSummary

Container for computed statistics from experiment analysis.
"""
struct StatisticalSummary
    convergence_stats::Dict{String,Any}
    performance_metrics::Dict{String,Any}
    polynomial_quality::Dict{String,Any}
    dimensional_analysis::Dict{String,Any}
end

"""
    load_experiment_results(result_path::String) -> ExperimentResults

Load experiment results from a directory or file path.
Automatically detects and parses JSON, CSV, and other output formats.
"""
function load_experiment_results(result_path::String)
    println("🔄 Loading experiment results from: $result_path")
    
    if isdir(result_path)
        return load_from_directory(result_path)
    elseif isfile(result_path)
        return load_from_file(result_path)
    else
        error("Path not found: $result_path")
    end
end

function load_from_directory(dir_path::String)
    source_files = String[]
    metadata = Dict{String,Any}()
    function_evaluations = nothing
    convergence_data = nothing
    critical_points = nothing
    polynomial_data = nothing
    timing_data = nothing
    
    # Look for standard output files
    for file in readdir(dir_path)
        file_path = joinpath(dir_path, file)
        push!(source_files, file_path)
        
        if endswith(file, ".json")
            try
                data = JSON.parsefile(file_path)
                if haskey(data, "sample_range") && haskey(data, "L2_norm")
                    # Main results file
                    metadata = merge(metadata, data)
                elseif haskey(data, "job_id")
                    # Monitoring file
                    timing_data = data
                end
            catch e
                println("⚠️  Warning: Could not parse JSON file $file: $e")
            end
        elseif endswith(file, ".csv")
            try
                df = CSV.read(file_path, DataFrame)
                if "function_value" in names(df)
                    function_evaluations = df
                elseif "iteration" in names(df) || "step" in names(df)
                    convergence_data = df
                end
            catch e
                println("⚠️  Warning: Could not parse CSV file $file: $e")
            end
        end
    end
    
    return ExperimentResults(metadata, function_evaluations, convergence_data, 
                           critical_points, polynomial_data, timing_data, source_files)
end

function load_from_file(file_path::String)
    source_files = [file_path]
    
    if endswith(file_path, ".json")
        metadata = JSON.parsefile(file_path)
        return ExperimentResults(metadata, nothing, nothing, nothing, nothing, nothing, source_files)
    else
        error("Unsupported file type: $file_path")
    end
end

"""
    analyze_experiment(results::ExperimentResults) -> StatisticalSummary

Perform comprehensive statistical analysis of experiment results.
"""
function analyze_experiment(results::ExperimentResults)
    println("📊 Analyzing experiment results...")
    
    convergence_stats = analyze_convergence(results)
    performance_metrics = analyze_performance(results)
    polynomial_quality = analyze_polynomial_quality(results)
    dimensional_analysis = analyze_dimensions(results)
    
    return StatisticalSummary(convergence_stats, performance_metrics, 
                            polynomial_quality, dimensional_analysis)
end

function analyze_convergence(results::ExperimentResults)
    stats = Dict{String,Any}()
    
    # Basic convergence metrics
    if haskey(results.metadata, "L2_norm")
        stats["final_l2_norm"] = results.metadata["L2_norm"]
        stats["log10_l2_norm"] = log10(results.metadata["L2_norm"])
    end
    
    # Function evaluation analysis
    if results.function_evaluations !== nothing
        df = results.function_evaluations
        if "function_value" in names(df)
            values = df.function_value
            stats["min_function_value"] = minimum(values)
            stats["max_function_value"] = maximum(values)
            stats["mean_function_value"] = mean(values)
            stats["std_function_value"] = std(values)
            stats["num_evaluations"] = length(values)
            
            # Improvement metrics
            if length(values) > 1
                stats["initial_value"] = values[1]
                stats["final_value"] = values[end]
                stats["total_improvement"] = values[1] - values[end]
                stats["relative_improvement"] = (values[1] - values[end]) / values[1]
            end
        end
    end
    
    return stats
end

function analyze_performance(results::ExperimentResults)
    metrics = Dict{String,Any}()
    
    # Polynomial metrics
    if haskey(results.metadata, "degree")
        metrics["polynomial_degree"] = results.metadata["degree"]
    end
    if haskey(results.metadata, "condition_number")
        metrics["condition_number"] = results.metadata["condition_number"]
        metrics["log10_condition"] = log10(results.metadata["condition_number"])
    end
    if haskey(results.metadata, "total_samples")
        metrics["total_samples"] = results.metadata["total_samples"]
    end
    
    # Timing analysis
    if results.timing_data !== nothing && haskey(results.timing_data, "elapsed_time")
        metrics["total_time"] = results.timing_data["elapsed_time"]
    end
    
    return metrics
end

function analyze_polynomial_quality(results::ExperimentResults)
    quality = Dict{String,Any}()
    
    # Approximation quality metrics
    if haskey(results.metadata, "L2_norm") && haskey(results.metadata, "degree")
        l2_norm = results.metadata["L2_norm"]
        degree = results.metadata["degree"]
        
        quality["l2_norm"] = l2_norm
        quality["degree"] = degree
        quality["quality_per_degree"] = l2_norm / degree
        
        # Quality classification
        if l2_norm < 1e-10
            quality["quality_class"] = "excellent"
        elseif l2_norm < 1e-6
            quality["quality_class"] = "good"  
        elseif l2_norm < 1e-3
            quality["quality_class"] = "acceptable"
        else
            quality["quality_class"] = "poor"
        end
    end
    
    return quality
end

function analyze_dimensions(results::ExperimentResults)
    analysis = Dict{String,Any}()
    
    if haskey(results.metadata, "dimension")
        dim = results.metadata["dimension"]
        analysis["dimension"] = dim
        
        # Dimensional complexity metrics
        if haskey(results.metadata, "degree")
            degree = results.metadata["degree"]
            # Number of monomials in d dimensions of degree n
            analysis["theoretical_monomials"] = binomial(dim + degree, degree)
        end
        
        if haskey(results.metadata, "total_samples")
            samples = results.metadata["total_samples"]
            analysis["samples_per_dimension"] = samples / dim
        end
    end
    
    return analysis
end

"""
    create_experiment_report(results::ExperimentResults, summary::StatisticalSummary; 
                           save_path::Union{String,Nothing}=nothing) -> String

Generate a comprehensive analysis report in markdown format.
"""
function create_experiment_report(results::ExperimentResults, summary::StatisticalSummary; 
                                save_path::Union{String,Nothing}=nothing)
    println("📝 Generating experiment report...")
    
    report = generate_markdown_report(results, summary)
    
    if save_path !== nothing
        open(save_path, "w") do io
            write(io, report)
        end
        println("📄 Report saved to: $save_path")
    end
    
    return report
end

function generate_markdown_report(results::ExperimentResults, summary::StatisticalSummary)
    io = IOBuffer()
    
    # Header
    println(io, "# GlobTim Experiment Analysis Report")
    println(io, "Generated: $(Dates.now())")
    println(io, "")
    
    # Metadata section
    println(io, "## Experiment Configuration")
    println(io, "")
    for (key, value) in results.metadata
        println(io, "- **$key**: $value")
    end
    println(io, "")
    
    # Performance summary
    println(io, "## Performance Summary")
    println(io, "")
    
    conv_stats = summary.convergence_stats
    perf_metrics = summary.performance_metrics
    
    if haskey(conv_stats, "final_l2_norm")
        norm_val = conv_stats["final_l2_norm"]
        log_norm = haskey(conv_stats, "log10_l2_norm") ? conv_stats["log10_l2_norm"] : log10(norm_val)
        println(io, "- **Final L2 Norm**: $(Printf.@sprintf("%.2e", norm_val)) (log₁₀: $(Printf.@sprintf("%.2f", log_norm)))")
    end
    
    if haskey(conv_stats, "num_evaluations")
        println(io, "- **Function Evaluations**: $(conv_stats["num_evaluations"])")
    end
    
    if haskey(conv_stats, "relative_improvement")
        improvement = conv_stats["relative_improvement"] * 100
        println(io, "- **Relative Improvement**: $(Printf.@sprintf("%.2f", improvement))%")
    end
    
    if haskey(perf_metrics, "condition_number")
        cond_num = perf_metrics["condition_number"]
        println(io, "- **Condition Number**: $(Printf.@sprintf("%.2e", cond_num))")
    end
    
    println(io, "")
    
    # Polynomial quality
    println(io, "## Polynomial Approximation Quality")
    println(io, "")
    
    poly_quality = summary.polynomial_quality
    if haskey(poly_quality, "quality_class")
        class = poly_quality["quality_class"]
        emoji = class == "excellent" ? "🟢" : class == "good" ? "🟡" : class == "acceptable" ? "🟠" : "🔴"
        println(io, "- **Quality Classification**: $emoji $class")
    end
    
    if haskey(poly_quality, "quality_per_degree")
        quality_ratio = poly_quality["quality_per_degree"]
        println(io, "- **Quality per Degree**: $(Printf.@sprintf("%.2e", quality_ratio))")
    end
    
    println(io, "")
    
    # Dimensional analysis
    dim_analysis = summary.dimensional_analysis
    if haskey(dim_analysis, "dimension")
        println(io, "## Dimensional Analysis")
        println(io, "")
        println(io, "- **Problem Dimension**: $(dim_analysis["dimension"])")
        
        if haskey(dim_analysis, "theoretical_monomials")
            println(io, "- **Theoretical Monomials**: $(dim_analysis["theoretical_monomials"])")
        end
        
        if haskey(dim_analysis, "samples_per_dimension")
            samples_per_dim = dim_analysis["samples_per_dimension"]
            println(io, "- **Samples per Dimension**: $(Printf.@sprintf("%.1f", samples_per_dim))")
        end
        println(io, "")
    end
    
    # File sources
    println(io, "## Source Files")
    println(io, "")
    for file in results.source_files
        println(io, "- `$file`")
    end
    
    return String(take!(io))
end

# Visualization functions (only if Makie is available)
if MAKIE_AVAILABLE
    """
        plot_convergence_analysis(results_collection::Vector{ExperimentResults}; save_path=nothing)
    
    Create convergence analysis plots for multiple experiments.
    Shows L2 norm vs degree, condition number scaling, etc.
    """
    function plot_convergence_analysis(results_collection::Vector{ExperimentResults}; save_path=nothing)
        degrees = Float64[]
        l2_norms = Float64[]
        condition_numbers = Float64[]
        dimensions = Int[]
        
        for result in results_collection
            if haskey(result.metadata, "degree") && haskey(result.metadata, "L2_norm")
                push!(degrees, result.metadata["degree"])
                push!(l2_norms, result.metadata["L2_norm"])
                
                if haskey(result.metadata, "condition_number")
                    push!(condition_numbers, result.metadata["condition_number"])
                else
                    push!(condition_numbers, NaN)
                end
                
                if haskey(result.metadata, "dimension")
                    push!(dimensions, result.metadata["dimension"])
                else
                    push!(dimensions, 2)  # default
                end
            end
        end
        
        if isempty(degrees)
            println("⚠️  No convergence data found")
            return nothing
        end
        
        fig = Figure(resolution=(1200, 800))
        
        # L2 norm vs degree (log scale)
        ax1 = Axis(fig[1, 1], 
                   title="Convergence Quality vs Polynomial Degree",
                   xlabel="Polynomial Degree",
                   ylabel="L2 Norm",
                   yscale=log10)
        
        scatter!(ax1, degrees, l2_norms, color=:blue, markersize=12)
        
        # Add quality thresholds
        hlines!(ax1, [1e-10], color=:green, linestyle=:dash, linewidth=2, label="Excellent")
        hlines!(ax1, [1e-6], color=:orange, linestyle=:dash, linewidth=2, label="Good")
        hlines!(ax1, [1e-3], color=:red, linestyle=:dash, linewidth=2, label="Acceptable")
        axislegend(ax1, position=:rt)
        
        # Condition number vs degree
        ax2 = Axis(fig[1, 2],
                   title="Numerical Stability vs Degree", 
                   xlabel="Polynomial Degree",
                   ylabel="Condition Number",
                   yscale=log10)
        
        valid_cond = .!isnan.(condition_numbers)
        if any(valid_cond)
            scatter!(ax2, degrees[valid_cond], condition_numbers[valid_cond], 
                    color=:red, markersize=12)
            # Add stability threshold
            hlines!(ax2, [1e12], color=:orange, linestyle=:dash, linewidth=2, 
                   label="Stability Limit")
            axislegend(ax2, position=:lt)
        end
        
        # Degree efficiency by dimension
        ax3 = Axis(fig[2, 1:2],
                   title="Approximation Quality by Dimension and Degree",
                   xlabel="Polynomial Degree", 
                   ylabel="L2 Norm",
                   yscale=log10)
        
        unique_dims = unique(dimensions)
        colors = [:blue, :red, :green, :purple, :orange]
        
        for (i, dim) in enumerate(unique_dims)
            dim_mask = dimensions .== dim
            if any(dim_mask)
                color = colors[mod1(i, length(colors))]
                scatter!(ax3, degrees[dim_mask], l2_norms[dim_mask], 
                        color=color, markersize=10, label="$(dim)D")
            end
        end
        axislegend(ax3, position=:rt)
        
        if save_path !== nothing
            save(save_path, fig)
            println("📊 Convergence analysis saved to: $save_path")
        end
        
        return fig
    end
    
    """
        plot_function_evaluation_analysis(results::ExperimentResults; save_path=nothing)
    
    Analyze and plot function evaluation data from CSV files.
    """
    function plot_function_evaluation_analysis(results::ExperimentResults; save_path=nothing)
        if results.function_evaluations === nothing
            println("⚠️  No function evaluation data found")
            return nothing
        end
        
        df = results.function_evaluations
        if !("function_value" in names(df))
            println("⚠️  No function_value column found")
            return nothing
        end
        
        fig = Figure(resolution=(1200, 600))
        
        # Function value distribution
        ax1 = Axis(fig[1, 1],
                   title="Function Value Distribution",
                   xlabel="Function Value", 
                   ylabel="Count")
        
        hist!(ax1, df.function_value, bins=20, color=(:blue, 0.7))
        
        # Add statistics
        mean_val = mean(df.function_value)
        min_val = minimum(df.function_value)
        max_val = maximum(df.function_value)
        
        vlines!(ax1, [mean_val], color=:red, linewidth=2, label="Mean")
        vlines!(ax1, [min_val], color=:green, linewidth=2, label="Min")
        axislegend(ax1, position=:rt)
        
        # Parameter space visualization (if 2D)
        if "x1" in names(df) && "x2" in names(df)
            ax2 = Axis(fig[1, 2],
                       title="Parameter Space Sampling",
                       xlabel="x₁",
                       ylabel="x₂")
            
            scatter!(ax2, df.x1, df.x2, color=df.function_value, 
                    colormap=:viridis, markersize=12)
            Colorbar(fig[1, 3], limits=(min_val, max_val), colormap=:viridis,
                    label="Function Value")
        else
            # Function values over evaluation order
            ax2 = Axis(fig[1, 2],
                       title="Function Values vs Evaluation Order",
                       xlabel="Evaluation Index",
                       ylabel="Function Value")
            
            lines!(ax2, 1:length(df.function_value), df.function_value,
                   color=:blue, linewidth=2)
            scatter!(ax2, 1:length(df.function_value), df.function_value,
                    color=:blue, markersize=8)
        end
        
        if save_path !== nothing
            save(save_path, fig) 
            println("📊 Function evaluation analysis saved to: $save_path")
        end
        
        return fig
    end
    
    """
        create_experiment_dashboard(results::ExperimentResults, summary::StatisticalSummary; save_path=nothing)
    
    Create comprehensive dashboard for a single experiment.
    """
    function create_experiment_dashboard(results::ExperimentResults, summary::StatisticalSummary; save_path=nothing)
        fig = Figure(resolution=(1600, 1000))
        
        # Title with key metrics
        metadata = results.metadata
        title_text = "GlobTim Experiment Dashboard"
        if haskey(metadata, "dimension") && haskey(metadata, "degree")
            title_text *= " - $(metadata["dimension"])D, Degree $(metadata["degree"])"
        end
        
        Label(fig[0, :], title_text, textsize=24, font="Arial Black")
        
        # Performance metrics (top row)
        ax1 = Axis(fig[1, 1], title="Key Performance Metrics")
        
        metrics_text = ""
        conv_stats = summary.convergence_stats
        perf_metrics = summary.performance_metrics
        
        if haskey(conv_stats, "final_l2_norm")
            norm_val = conv_stats["final_l2_norm"]
            metrics_text *= "L2 Norm: $(Printf.@sprintf("%.2e", norm_val))\n"
        end
        
        if haskey(perf_metrics, "condition_number")
            cond_val = perf_metrics["condition_number"]
            metrics_text *= "Condition #: $(Printf.@sprintf("%.2e", cond_val))\n"
        end
        
        if haskey(conv_stats, "num_evaluations")
            metrics_text *= "Evaluations: $(conv_stats["num_evaluations"])\n"
        end
        
        text!(ax1, 0.1, 0.8, text=metrics_text, fontsize=14, align=(:left, :top))
        hidespines!(ax1)
        hidedecorations!(ax1)
        
        # Quality classification
        ax2 = Axis(fig[1, 2], title="Quality Assessment")
        
        poly_quality = summary.polynomial_quality  
        if haskey(poly_quality, "quality_class")
            class = poly_quality["quality_class"]
            color = class == "excellent" ? :green : class == "good" ? :orange : 
                   class == "acceptable" ? :yellow : :red
            
            # Simple quality indicator
            scatter!(ax2, [0.5], [0.5], color=color, markersize=50)
            text!(ax2, 0.5, 0.3, text=uppercase(class), fontsize=16, 
                  align=(:center, :center))
        end
        
        xlims!(ax2, 0, 1)
        ylims!(ax2, 0, 1)
        hidespines!(ax2)
        hidedecorations!(ax2)
        
        # Function evaluation analysis (if available)
        if results.function_evaluations !== nothing
            df = results.function_evaluations
            
            ax3 = Axis(fig[2, 1], title="Function Value Distribution")
            hist!(ax3, df.function_value, bins=15, color=(:blue, 0.7))
            
            if "x1" in names(df) && "x2" in names(df) && nrow(df) < 1000
                ax4 = Axis(fig[2, 2], title="Parameter Space", xlabel="x₁", ylabel="x₂")
                scatter!(ax4, df.x1, df.x2, color=df.function_value,
                        colormap=:viridis, markersize=8)
            end
        end
        
        if save_path !== nothing
            save(save_path, fig)
            println("📊 Experiment dashboard saved to: $save_path")
        end
        
        return fig
    end
    
    # Export plotting functions
    export plot_convergence_analysis, plot_function_evaluation_analysis, create_experiment_dashboard
    
else
    # Stub functions when Makie not available
    for func in [:plot_convergence_analysis, :plot_function_evaluation_analysis, :create_experiment_dashboard]
        @eval function $(func)(args...; kwargs...)
            println("❌ CairoMakie/GLMakie not available - install with: using Pkg; Pkg.add([\"CairoMakie\", \"GLMakie\"])")
            return nothing
        end
    end
end

end # module PostProcessing