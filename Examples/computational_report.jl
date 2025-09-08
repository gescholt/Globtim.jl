#!/usr/bin/env julia

"""
Computational Report Generator

Executable Julia script that generates computational results reports.
Focus on numerical outputs with minimal text.

Usage:
    julia --project=. Examples/computational_report.jl [result_file]
    julia --project=. Examples/computational_report.jl 4d_results.json

Features:
- Only uses Julia standard library
- Focuses on numerical results and distances  
- Executable format (not static markdown)
- Integration with standardized example outputs

Author: GlobTim Team
Date: September 2025
"""

# Activate project
using Pkg
Pkg.activate(".")

# Load post-processing core (standard library only)
include("../src/PostProcessingCore.jl")

using Printf
using Dates

"""
    generate_computational_report(file_path::String)

Generate and display computational report for experiment results.
"""
function generate_computational_report(file_path::String)
    println("="^60)
    println("🔢 COMPUTATIONAL RESULTS REPORT")
    println("="^60)
    println("Generated: $(now())")
    println("Source: $file_path")
    println()
    
    try
        # Load experiment data
        data = load_experiment_data(file_path)
        
        # Core computational metrics
        println("📊 CORE METRICS")
        println("-"^30)
        
        if data.dimension !== nothing
            println("Dimension: $(data.dimension)")
        end
        
        if data.degree !== nothing
            println("Polynomial_degree: $(data.degree)")
        end
        
        if data.l2_norm !== nothing
            println("L2_norm: $(@sprintf("%.6e", data.l2_norm))")
            println("log10_L2_norm: $(@sprintf("%.2f", log10(data.l2_norm)))")
        end
        
        if data.condition_number !== nothing
            println("Condition_number: $(@sprintf("%.6e", data.condition_number))")
            println("log10_Condition: $(@sprintf("%.2f", log10(data.condition_number)))")
        end
        
        println()
        
        # Quality assessment
        println("🎯 QUALITY ASSESSMENT")
        println("-"^30)
        
        quality_metrics = compute_quality_metrics(data)
        if haskey(quality_metrics, "quality_class")
            class = quality_metrics["quality_class"]
            score = quality_metrics["quality_score"]
            println("Quality_class: $class")
            println("Quality_score: $score/4")
        end
        
        if haskey(quality_metrics, "stability_class")
            stability = quality_metrics["stability_class"]
            stab_score = quality_metrics["stability_score"]
            println("Stability_class: $stability")
            println("Stability_score: $stab_score/3")
        end
        
        println()
        
        # Sampling efficiency
        println("📏 SAMPLING EFFICIENCY")
        println("-"^30)
        
        sampling_metrics = compute_sampling_efficiency(data)
        
        if haskey(sampling_metrics, "theoretical_monomials")
            println("Theoretical_monomials: $(sampling_metrics["theoretical_monomials"])")
        end
        
        if data.total_samples !== nothing
            println("Total_samples: $(data.total_samples)")
        end
        
        if haskey(sampling_metrics, "sample_monomial_ratio")
            ratio = sampling_metrics["sample_monomial_ratio"]
            println("Sample_monomial_ratio: $(@sprintf("%.4f", ratio))")
        end
        
        if haskey(sampling_metrics, "sampling_class")
            samp_class = sampling_metrics["sampling_class"]
            samp_score = sampling_metrics["sampling_score"]
            println("Sampling_class: $samp_class")
            println("Sampling_score: $samp_score/3")
        end
        
        if haskey(sampling_metrics, "samples_per_dimension")
            spd = sampling_metrics["samples_per_dimension"]
            println("Samples_per_dimension: $(@sprintf("%.2f", spd))")
        end
        
        println()
        
        # Parameter information
        println("🎯 PARAMETER CONFIGURATION")
        println("-"^30)
        
        if data.center !== nothing
            center_str = join([@sprintf("%.4f", x) for x in data.center], ", ")
            println("Parameter_center: [$center_str]")
        end
        
        if data.sample_range !== nothing
            println("Sample_range: $(data.sample_range)")
        end
        
        if data.samples_per_dim !== nothing
            println("Configured_samples_per_dim: $(data.samples_per_dim)")
        end
        
        println()
        
        # Summary assessment
        println("📈 OVERALL ASSESSMENT")
        println("-"^30)
        
        total_score = 0
        max_score = 0
        
        if haskey(quality_metrics, "quality_score")
            total_score += quality_metrics["quality_score"]
            max_score += 4
            println("Quality_contribution: $(quality_metrics["quality_score"])/4")
        end
        
        if haskey(quality_metrics, "stability_score")
            total_score += quality_metrics["stability_score"]  
            max_score += 3
            println("Stability_contribution: $(quality_metrics["stability_score"])/3")
        end
        
        if haskey(sampling_metrics, "sampling_score")
            total_score += sampling_metrics["sampling_score"]
            max_score += 3
            println("Sampling_contribution: $(sampling_metrics["sampling_score"])/3")
        end
        
        if max_score > 0
            overall_score = total_score / max_score * 100.0
            println("Overall_score: $(@sprintf("%.1f", overall_score))% ($total_score/$max_score)")
            
            if overall_score >= 85.0
                println("Overall_assessment: EXCELLENT")
            elseif overall_score >= 70.0
                println("Overall_assessment: GOOD")
            elseif overall_score >= 50.0
                println("Overall_assessment: ACCEPTABLE")
            else
                println("Overall_assessment: NEEDS_IMPROVEMENT")
            end
        end
        
        println()
        
    catch e
        println("❌ Error processing $file_path: $e")
        return false
    end
    
    return true
end

"""
    compare_experiments(file_paths::Vector{String})

Compare multiple experiments and show progression analysis.
"""
function compare_experiments(file_paths::Vector{String})
    println("="^60)
    println("📊 COMPARATIVE ANALYSIS")
    println("="^60)
    
    experiments = ExperimentData[]
    
    # Load all valid experiments
    for file_path in file_paths
        try
            data = load_experiment_data(file_path)
            push!(experiments, data)
            println("✅ Loaded: $(basename(file_path))")
        catch e
            println("❌ Failed to load $(basename(file_path)): $e")
        end
    end
    
    if length(experiments) < 2
        println("⚠️  Need at least 2 valid experiments for comparison")
        return
    end
    
    println()
    
    # Degree progression analysis
    progression = analyze_degree_progression(experiments)
    
    if !haskey(progression, "error")
        println("📈 DEGREE PROGRESSION ANALYSIS")
        println("-"^40)
        
        degrees = progression["degrees"]
        l2_norms = progression["l2_norms"] 
        improvements = progression["improvements_percent"]
        
        for i in 1:length(degrees)
            println("Degree_$(degrees[i]): L2_norm = $(@sprintf("%.6e", l2_norms[i]))")
        end
        
        println()
        println("IMPROVEMENT ANALYSIS:")
        for i in 1:length(improvements)
            from_deg = degrees[i]
            to_deg = degrees[i+1]
            improvement = improvements[i]
            println("Degree_$(from_deg)_to_$(to_deg): $(@sprintf("%.2f", improvement))% improvement")
        end
        
        println()
        println("SUMMARY:")
        println("Total_improvement: $(@sprintf("%.2f", progression["total_improvement"]))%")
        println("Mean_improvement: $(@sprintf("%.2f", progression["mean_improvement"]))%")
        println("Best_single_improvement: $(@sprintf("%.2f", progression["best_improvement"]))%")
        
    else
        println("⚠️  $(progression["error"])")
    end
    
    println()
end

"""
    main()

Main entry point with command line argument handling.
"""
function main()
    if length(ARGS) == 0
        # Default: try to process 4d_results.json if available
        default_file = "4d_results.json"
        if isfile(default_file)
            println("📁 Processing default file: $default_file")
            generate_computational_report(default_file)
        else
            println("❌ No arguments provided and no default file found")
            println("\nUsage:")
            println("  julia --project=. Examples/computational_report.jl [result_file]")
            println("  julia --project=. Examples/computational_report.jl 4d_results.json")
            println("  julia --project=. Examples/computational_report.jl file1.json file2.json  # comparison")
            return
        end
    elseif length(ARGS) == 1
        # Single file analysis
        generate_computational_report(ARGS[1])
    else
        # Multiple file comparison
        compare_experiments(ARGS)
    end
    
    println("\n💡 This report was generated by an executable Julia script.")
    println("   Modify Examples/computational_report.jl to customize output.")
end

# Execute main function if script is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end