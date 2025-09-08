#!/usr/bin/env julia

"""
Post-Process Node Experiment Results

This script demonstrates how to analyze and visualize results from experiments
run on the HPC node. It can process both individual experiment results and
collections of results for comparative analysis.

Usage:
    julia Examples/post_process_node_results.jl [result_path]
    julia Examples/post_process_node_results.jl collected_results/
    julia Examples/post_process_node_results.jl 4d_results.json

Features:
- Load experiment results from JSON/CSV outputs
- Generate comprehensive statistical analysis  
- Create publication-ready plots
- Generate markdown reports
- Batch process multiple experiments for comparison

Author: GlobTim Team
Date: September 2025
"""

using Pkg
Pkg.activate(".")
using Printf
using Dates

# Load the post-processing module
include("../src/PostProcessing.jl")
using .PostProcessing

# Optional: Load plotting packages if available
try
    using CairoMakie
    using GLMakie
    println("📊 Makie plotting available")
catch e
    println("⚠️  Makie not available - plots will be skipped")
    println("   Install with: using Pkg; Pkg.add([\"CairoMakie\", \"GLMakie\"])")
end

"""
    process_single_experiment(result_path::String)

Process and analyze a single experiment result.
"""
function process_single_experiment(result_path::String)
    println("\n" * "="^60)
    println("🔬 SINGLE EXPERIMENT ANALYSIS")
    println("="^60)
    
    # Load results
    results = load_experiment_results(result_path)
    println("✅ Loaded experiment from: $result_path")
    
    # Perform analysis
    summary = analyze_experiment(results)
    println("✅ Statistical analysis complete")
    
    # Print key metrics
    print_key_metrics(results, summary)
    
    # Generate report
    base_name = splitext(basename(result_path))[1]
    report_path = "$(base_name)_analysis_report.md"
    report = create_experiment_report(results, summary, save_path=report_path)
    
    # Create plots if Makie available
    if PostProcessing.MAKIE_AVAILABLE
        plot_path = "$(base_name)_dashboard.png"
        dashboard = create_experiment_dashboard(results, summary, save_path=plot_path)
        
        if results.function_evaluations !== nothing
            eval_plot_path = "$(base_name)_evaluations.png" 
            eval_plot = plot_function_evaluation_analysis(results, save_path=eval_plot_path)
        end
    end
    
    return results, summary
end

"""
    process_experiment_collection(results_dir::String)

Process and compare multiple experiment results from a directory.
"""
function process_experiment_collection(results_dir::String)
    println("\n" * "="^60)
    println("📊 BATCH EXPERIMENT ANALYSIS")
    println("="^60)
    
    # Find all experiment directories and JSON files
    experiment_paths = String[]
    
    if isdir(results_dir)
        for item in readdir(results_dir)
            item_path = joinpath(results_dir, item)
            if isdir(item_path)
                # Check if it's an experiment directory with results
                json_files = filter(f -> endswith(f, ".json"), readdir(item_path))
                if !isempty(json_files)
                    push!(experiment_paths, item_path)
                end
            elseif endswith(item, ".json")
                push!(experiment_paths, item_path)
            end
        end
    end
    
    if isempty(experiment_paths)
        println("⚠️  No experiment results found in $results_dir")
        return nothing
    end
    
    println("📂 Found $(length(experiment_paths)) experiment(s)")
    
    # Load all experiments
    all_results = ExperimentResults[]
    all_summaries = StatisticalSummary[]
    
    for path in experiment_paths
        try
            results = load_experiment_results(path)
            summary = analyze_experiment(results)
            push!(all_results, results)
            push!(all_summaries, summary)
            println("✅ Processed: $(basename(path))")
        catch e
            println("❌ Failed to process $(basename(path)): $e")
        end
    end
    
    if isempty(all_results)
        println("❌ No valid experiment results could be loaded")
        return nothing
    end
    
    # Generate comparative analysis
    print_comparative_summary(all_results, all_summaries)
    
    # Create comparative plots
    if PostProcessing.MAKIE_AVAILABLE && length(all_results) > 1
        conv_plot_path = "convergence_comparison.png"
        convergence_plot = plot_convergence_analysis(all_results, save_path=conv_plot_path)
    end
    
    return all_results, all_summaries
end

"""
    print_key_metrics(results::ExperimentResults, summary::StatisticalSummary)

Print key metrics for a single experiment.
"""
function print_key_metrics(results::ExperimentResults, summary::StatisticalSummary)
    println("\n📈 KEY METRICS:")
    
    # Basic configuration
    if haskey(results.metadata, "dimension")
        println("  Dimension: $(results.metadata["dimension"])")
    end
    if haskey(results.metadata, "degree") 
        println("  Polynomial Degree: $(results.metadata["degree"])")
    end
    
    # Quality metrics
    conv_stats = summary.convergence_stats
    if haskey(conv_stats, "final_l2_norm")
        norm_val = conv_stats["final_l2_norm"]
        println("  L2 Norm: $(Printf.@sprintf("%.2e", norm_val))")
    end
    
    perf_metrics = summary.performance_metrics
    if haskey(perf_metrics, "condition_number")
        cond_val = perf_metrics["condition_number"]
        println("  Condition Number: $(Printf.@sprintf("%.2e", cond_val))")
    end
    
    # Quality classification
    poly_quality = summary.polynomial_quality
    if haskey(poly_quality, "quality_class")
        class = poly_quality["quality_class"]
        emoji = class == "excellent" ? "🟢" : class == "good" ? "🟡" : 
               class == "acceptable" ? "🟠" : "🔴"
        println("  Quality: $emoji $class")
    end
    
    # Function evaluation stats
    if haskey(conv_stats, "num_evaluations")
        println("  Function Evaluations: $(conv_stats["num_evaluations"])")
    end
    if haskey(conv_stats, "relative_improvement")
        improvement = conv_stats["relative_improvement"] * 100
        println("  Relative Improvement: $(Printf.@sprintf("%.2f", improvement))%")
    end
end

"""
    print_comparative_summary(all_results, all_summaries)

Print comparative analysis summary for multiple experiments.
"""
function print_comparative_summary(all_results, all_summaries)
    println("\n📊 COMPARATIVE ANALYSIS:")
    
    # Extract key metrics for comparison
    l2_norms = Float64[]
    degrees = Int[]
    dimensions = Int[]
    condition_numbers = Float64[]
    
    for results in all_results
        if haskey(results.metadata, "L2_norm")
            push!(l2_norms, results.metadata["L2_norm"])
        end
        if haskey(results.metadata, "degree")
            push!(degrees, results.metadata["degree"]) 
        end
        if haskey(results.metadata, "dimension")
            push!(dimensions, results.metadata["dimension"])
        end
        if haskey(results.metadata, "condition_number")
            push!(condition_numbers, results.metadata["condition_number"])
        end
    end
    
    # Summary statistics
    if !isempty(l2_norms)
        println("  L2 Norm Range: $(Printf.@sprintf("%.2e", minimum(l2_norms))) - $(Printf.@sprintf("%.2e", maximum(l2_norms)))")
    end
    if !isempty(degrees)
        println("  Degree Range: $(minimum(degrees)) - $(maximum(degrees))")
    end
    if !isempty(dimensions)
        unique_dims = unique(dimensions)
        println("  Dimensions: $(unique_dims)")
    end
    if !isempty(condition_numbers)
        println("  Condition Number Range: $(Printf.@sprintf("%.2e", minimum(condition_numbers))) - $(Printf.@sprintf("%.2e", maximum(condition_numbers)))")
    end
    
    # Quality distribution
    quality_counts = Dict("excellent" => 0, "good" => 0, "acceptable" => 0, "poor" => 0)
    for summary in all_summaries
        if haskey(summary.polynomial_quality, "quality_class")
            class = summary.polynomial_quality["quality_class"]
            quality_counts[class] += 1
        end
    end
    
    println("  Quality Distribution:")
    for (quality, count) in quality_counts
        if count > 0
            emoji = quality == "excellent" ? "🟢" : quality == "good" ? "🟡" : 
                   quality == "acceptable" ? "🟠" : "🔴"
            println("    $emoji $quality: $count experiments")
        end
    end
end

"""
    main()

Main entry point - process command line arguments and run analysis.
"""
function main()
    println("🎯 GlobTim Post-Processing System")
    println("Generated: $(Dates.now())")
    
    # Get result path from command line or use default
    result_path = length(ARGS) > 0 ? ARGS[1] : "."
    
    if !isdir(result_path) && !isfile(result_path)
        println("❌ Path not found: $result_path")
        println("\nUsage:")
        println("  julia Examples/post_process_node_results.jl [result_path]")
        println("  julia Examples/post_process_node_results.jl collected_results/")  
        println("  julia Examples/post_process_node_results.jl 4d_results.json")
        return
    end
    
    # Determine processing mode
    if isdir(result_path)
        # Look for multiple experiments
        results, summaries = process_experiment_collection(result_path)
    else
        # Single experiment file
        results, summary = process_single_experiment(result_path)
    end
    
    println("\n✅ Post-processing complete!")
    println("📄 Check generated files for detailed analysis and plots.")
end

# Run main function if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end