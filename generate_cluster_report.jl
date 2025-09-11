#!/usr/bin/env julia

"""
    generate_cluster_report.jl

Easy-to-use script for generating comprehensive reports of GlobTim cluster computations.

Usage:
    julia generate_cluster_report.jl [result_file_or_directory]
    julia generate_cluster_report.jl --all  # Process all available results

Examples:
    julia generate_cluster_report.jl 4d_results.json
    julia generate_cluster_report.jl collected_results/job_59780287_20250809_140333/
    julia generate_cluster_report.jl --all
"""

using Pkg
Pkg.activate(".")

include("src/PostProcessing.jl")
using .PostProcessing
using JSON
using Printf
using Dates

function print_usage()
    println("""
    📊 GlobTim Cluster Report Generator
    
    Usage:
        julia generate_cluster_report.jl [result_file_or_directory]
        julia generate_cluster_report.jl --all
    
    Examples:
        julia generate_cluster_report.jl 4d_results.json
        julia generate_cluster_report.jl collected_results/job_59780287_20250809_140333/
        julia generate_cluster_report.jl --all
    
    Options:
        --all       Process all available results in collected_results/
        --help      Show this help message
    """)
end

function find_all_results()
    """Find all available result files and directories."""
    results = String[]
    
    # Look for individual JSON files
    json_files = filter(x -> endswith(x, ".json") && isfile(x), readdir("."))
    append!(results, json_files)
    
    # Look for collection directories
    if isdir("collected_results")
        for dir in readdir("collected_results")
            full_path = joinpath("collected_results", dir)
            if isdir(full_path)
                push!(results, full_path)
            end
        end
    end
    
    return results
end

function generate_summary_report(all_results::Vector{String})
    """Generate a summary report of all processed results."""
    println("\n" * "="^60)
    println("📊 COMPREHENSIVE CLUSTER COMPUTATION SUMMARY")
    println("="^60)
    
    total_experiments = 0
    successful_analyses = 0
    quality_counts = Dict("excellent" => 0, "good" => 0, "acceptable" => 0, "poor" => 0)
    dimensions = Int[]
    degrees = Int[]
    l2_norms = Float64[]
    
    for result_path in all_results
        try
            println("\n🔄 Processing: $result_path")
            results = load_experiment_results(result_path)
            summary = analyze_experiment(results)
            
            total_experiments += 1
            successful_analyses += 1
            
            # Collect statistics
            if haskey(results.metadata, "dimension")
                push!(dimensions, results.metadata["dimension"])
            end
            if haskey(results.metadata, "degree")
                push!(degrees, results.metadata["degree"])
            end
            if haskey(results.metadata, "L2_norm")
                push!(l2_norms, results.metadata["L2_norm"])
            end
            
            # Count quality classifications
            if haskey(summary.polynomial_quality, "quality_class")
                quality = summary.polynomial_quality["quality_class"]
                quality_counts[quality] += 1
            end
            
            # Generate individual report
            timestamp = replace(string(now()), ":" => "-")
            report_name = "report_$(basename(result_path))_$timestamp.md"
            create_experiment_report(results, summary, save_path=report_name)
            
        catch e
            println("❌ Error processing $result_path: $e")
            total_experiments += 1
        end
    end
    
    # Summary statistics
    println("\n" * "="^60)
    println("📈 OVERALL STATISTICS")
    println("="^60)
    println("Total experiments processed: $total_experiments")
    println("Successful analyses: $successful_analyses")
    
    if successful_analyses > 0
        success_rate = successful_analyses / total_experiments * 100
        println("Success rate: $(Printf.@sprintf("%.1f%%", success_rate))")
        
        if !isempty(dimensions)
            unique_dims = unique(dimensions)
            println("Dimensions tested: $(join(unique_dims, ", "))")
        end
        
        if !isempty(degrees)
            degree_range = (minimum(degrees), maximum(degrees))
            println("Degree range: $(degree_range[1]) - $(degree_range[2])")
        end
        
        if !isempty(l2_norms)
            best_l2 = minimum(l2_norms)
            worst_l2 = maximum(l2_norms)
            avg_l2 = sum(l2_norms) / length(l2_norms)
            println("L2 norm range: $(Printf.@sprintf("%.2e", best_l2)) - $(Printf.@sprintf("%.2e", worst_l2))")
            println("Average L2 norm: $(Printf.@sprintf("%.2e", avg_l2))")
        end
        
        println("\n📊 Quality Distribution:")
        total_quality = sum(values(quality_counts))
        for (quality, count) in sort(collect(quality_counts), by=x->x[2], rev=true)
            if count > 0
                percentage = count / total_quality * 100
                emoji = quality == "excellent" ? "🟢" : quality == "good" ? "🟡" : 
                       quality == "acceptable" ? "🟠" : "🔴"
                println("  $emoji $quality: $count ($(Printf.@sprintf("%.1f%%", percentage)))")
            end
        end
    end
    
    println("\n" * "="^60)
    println("✅ Summary complete! Individual reports saved as report_*.md files")
    println("="^60)
end

function main()
    if length(ARGS) == 0 || "--help" in ARGS
        print_usage()
        return
    end
    
    println("🚀 Starting GlobTim Cluster Report Generation")
    println("Time: $(now())")
    
    if "--all" in ARGS
        println("🔍 Finding all available results...")
        all_results = find_all_results()
        
        if isempty(all_results)
            println("❌ No results found in current directory or collected_results/")
            return
        end
        
        println("📁 Found $(length(all_results)) result files/directories")
        generate_summary_report(all_results)
        
    else
        # Process specific file/directory
        target = ARGS[1]
        
        if !isfile(target) && !isdir(target)
            println("❌ Error: '$target' not found")
            return
        end
        
        try
            println("🔄 Processing: $target")
            results = load_experiment_results(target)
            summary = analyze_experiment(results)
            
            # Generate report with timestamp
            timestamp = replace(string(now()), ":" => "-")
            report_name = "report_$(basename(target))_$timestamp.md"
            create_experiment_report(results, summary, save_path=report_name)
            
            println("\n" * "="^60)
            println("📄 ANALYSIS COMPLETE")
            println("="^60)
            println("Report saved as: $report_name")
            
            # Also display key results
            println("\n🎯 Key Results:")
            if haskey(results.metadata, "L2_norm")
                l2_norm = results.metadata["L2_norm"]
                println("  L2 Norm: $(Printf.@sprintf("%.2e", l2_norm))")
            end
            
            if haskey(summary.polynomial_quality, "quality_class")
                quality = summary.polynomial_quality["quality_class"]
                emoji = quality == "excellent" ? "🟢" : quality == "good" ? "🟡" : 
                       quality == "acceptable" ? "🟠" : "🔴"
                println("  Quality: $emoji $quality")
            end
            
            if haskey(results.metadata, "dimension") && haskey(results.metadata, "degree")
                dim = results.metadata["dimension"]
                deg = results.metadata["degree"]
                println("  Configuration: $(dim)D, degree $deg")
            end
            
        catch e
            println("❌ Error processing '$target': $e")
            println("Please check that the file/directory contains valid GlobTim results")
        end
    end
    
    println("\n✨ Report generation complete!")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end