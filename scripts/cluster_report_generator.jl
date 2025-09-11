#!/usr/bin/env julia

"""
Cluster Report Generator

Simple executable that takes a tag/identifier and generates a basic report from 
cluster computation outputs. Leverages existing post-processing infrastructure.

Usage:
    julia scripts/cluster_report_generator.jl <tag>
    
Examples:
    julia scripts/cluster_report_generator.jl 4d_results
    julia scripts/cluster_report_generator.jl job_59780294  
    julia scripts/cluster_report_generator.jl 20250809
"""

using Pkg
Pkg.activate(".")

# Import existing post-processing infrastructure  
include(joinpath(@__DIR__, "..", "src", "PostProcessingCore.jl"))

# Use PostProcessingCore functions directly
using JSON
using Printf
using Dates

"""
    find_cluster_outputs(tag::String) -> Vector{String}
    
Find cluster output files/directories matching the given tag/identifier.
"""
function find_cluster_outputs(tag::String)
    outputs = String[]
    
    # Search patterns based on identified cluster output structures
    search_locations = [
        ".",                            # Current directory 
        "collected_results",           # Main results directory
        "hpc/jobs/submission/collected_results"  # Alternative location
    ]
    
    for location in search_locations
        if isdir(location)
            # Pattern 1: Direct JSON files (like "4d_results.json")
            json_pattern = joinpath(location, "$(tag).json")
            if isfile(json_pattern)
                push!(outputs, json_pattern)
            end
            
            # Pattern 2: Job directories (like "job_59780294_20250809_142058")
            for item in readdir(location, join=true)
                if isdir(item) && contains(basename(item), tag)
                    push!(outputs, item)
                end
            end
            
            # Pattern 3: Date-based search (like "20250809")
            for item in readdir(location, join=true)
                if isdir(item) && contains(basename(item), tag)
                    push!(outputs, item)
                end
            end
        end
    end
    
    return unique(outputs)
end

"""
    generate_minimal_report(output_path::String) -> String
    
Generate a minimal computational report from a single output file/directory.
"""
function generate_minimal_report(output_path::String)
    println("📄 Processing: $output_path")
    
    try
        # Load experiment data using existing infrastructure
        data = PostProcessingCore.load_experiment_data(output_path)
        
        # Generate computational summary using existing function
        summary = PostProcessingCore.create_computational_summary(data)
        
        return summary
        
    catch e
        return "❌ Error processing $output_path: $e"
    end
end

"""
    generate_collection_report(output_paths::Vector{String}, tag::String) -> String
    
Generate a report combining multiple outputs with the same tag.
"""
function generate_collection_report(output_paths::Vector{String}, tag::String)
    io = IOBuffer()
    
    println(io, "# Cluster Report for Tag: $tag")
    println(io, "Generated: $(now())")
    println(io, "Found $(length(output_paths)) matching outputs")
    println(io)
    
    for (i, output_path) in enumerate(output_paths)
        println(io, "## Output $i: $(basename(output_path))")
        println(io)
        
        report = generate_minimal_report(output_path)
        println(io, report)
        println(io)
        println(io, "---")
        println(io)
    end
    
    return String(take!(io))
end

"""
    main()
    
Main entry point for the cluster report generator.
"""
function main()
    if length(ARGS) < 1
        println("❌ Usage: julia cluster_report_generator.jl <tag>")
        println("   Examples:")
        println("     julia cluster_report_generator.jl 4d_results")
        println("     julia cluster_report_generator.jl job_59780294")  
        println("     julia cluster_report_generator.jl 20250809")
        return
    end
    
    tag = ARGS[1]
    println("🔍 Searching for cluster outputs with tag: '$tag'")
    
    # Find matching outputs
    outputs = find_cluster_outputs(tag)
    
    if isempty(outputs)
        println("❌ No cluster outputs found for tag: '$tag'")
        println("   Searched in:")
        println("     - Current directory (*.json)")
        println("     - collected_results/")
        println("     - hpc/jobs/submission/collected_results/")
        return
    end
    
    println("✅ Found $(length(outputs)) matching outputs:")
    for output in outputs
        println("   - $output")
    end
    println()
    
    # Generate report
    if length(outputs) == 1
        # Single output - use minimal report
        report = generate_minimal_report(outputs[1])
        println(report)
    else
        # Multiple outputs - use collection report  
        report = generate_collection_report(outputs, tag)
        println(report)
    end
    
    # Optionally save to file
    report_filename = "cluster_report_$(tag)_$(now()).md"
    if length(outputs) == 1
        report_content = generate_minimal_report(outputs[1])
    else
        report_content = generate_collection_report(outputs, tag)
    end
    
    open(report_filename, "w") do f
        write(f, report_content)
    end
    
    println("\n📁 Report saved to: $report_filename")
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end