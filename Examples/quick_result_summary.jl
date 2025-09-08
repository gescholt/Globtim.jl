#!/usr/bin/env julia

"""
Quick Result Summary

Quickly analyze and summarize experiment results without full post-processing.
Perfect for getting a fast overview of node experiment outputs.

Usage:
    julia Examples/quick_result_summary.jl [result_file]
    julia Examples/quick_result_summary.jl 4d_results.json

Author: GlobTim Team  
Date: September 2025
"""

using JSON
using Printf
using Dates

"""
    analyze_json_result(file_path::String)

Quick analysis of a JSON result file.
"""
function analyze_json_result(file_path::String)
    println("🔍 Quick Analysis: $(basename(file_path))")
    println("="^50)
    
    try
        data = JSON.parsefile(file_path)
        
        # Basic configuration
        if haskey(data, "dimension")
            println("📐 Dimension: $(data["dimension"])")
        end
        if haskey(data, "degree")
            println("📊 Polynomial Degree: $(data["degree"])")
        end
        if haskey(data, "basis")
            println("🧮 Basis: $(data["basis"])")
        end
        
        # Sampling information  
        if haskey(data, "total_samples")
            println("🎯 Total Samples: $(data["total_samples"])")
        end
        if haskey(data, "samples_per_dim")
            println("🎯 Samples per Dimension: $(data["samples_per_dim"])")
        end
        if haskey(data, "sample_range")
            println("📏 Sample Range: $(data["sample_range"])")
        end
        
        # Quality metrics
        if haskey(data, "L2_norm")
            norm_val = data["L2_norm"]
            log_norm = log10(norm_val)
            println("📈 L2 Norm: $(@sprintf("%.2e", norm_val)) (log₁₀: $(@sprintf("%.2f", log_norm)))")
            
            # Quality classification
            if norm_val < 1e-10
                println("✅ Quality: 🟢 EXCELLENT")
            elseif norm_val < 1e-6
                println("✅ Quality: 🟡 GOOD")
            elseif norm_val < 1e-3
                println("✅ Quality: 🟠 ACCEPTABLE") 
            else
                println("⚠️  Quality: 🔴 POOR")
            end
        end
        
        if haskey(data, "condition_number")
            cond_val = data["condition_number"]
            println("🧮 Condition Number: $(@sprintf("%.2e", cond_val))")
            
            if cond_val > 1e12
                println("⚠️  Stability: 🔴 POOR (high condition number)")
            elseif cond_val > 1e8
                println("⚠️  Stability: 🟠 MODERATE")
            else
                println("✅ Stability: 🟢 GOOD")
            end
        end
        
        # Parameter center
        if haskey(data, "center")
            center = data["center"]
            println("🎯 Parameter Center: [$(join([@sprintf("%.3f", x) for x in center], ", "))]")
        end
        
        # Complexity analysis
        if haskey(data, "dimension") && haskey(data, "degree")
            dim = data["dimension"]
            deg = data["degree"]
            theoretical_monomials = binomial(dim + deg, deg)
            println("🔢 Theoretical Monomials: $theoretical_monomials")
            
            if haskey(data, "total_samples")
                samples = data["total_samples"]
                sample_ratio = samples / theoretical_monomials
                println("⚖️  Sample/Monomial Ratio: $(@sprintf("%.3f", sample_ratio))")
                
                if sample_ratio < 1.0
                    println("⚠️  Sampling: 🔴 UNDERDETERMINED (insufficient samples)")
                elseif sample_ratio < 2.0
                    println("⚠️  Sampling: 🟠 MARGINAL")
                else
                    println("✅ Sampling: 🟢 WELL-CONDITIONED")
                end
            end
        end
        
    catch e
        println("❌ Error reading JSON file: $e")
        return false
    end
    
    return true
end

"""
    main()

Main entry point.
"""
function main()
    println("⚡ GlobTim Quick Result Summary")
    println("Generated: $(Dates.now())\n")
    
    # Get file path from command line or use default
    file_path = length(ARGS) > 0 ? ARGS[1] : "4d_results.json"
    
    if !isfile(file_path)
        println("❌ File not found: $file_path")
        println("\nUsage:")
        println("  julia Examples/quick_result_summary.jl [result_file]")
        println("  julia Examples/quick_result_summary.jl 4d_results.json")
        return
    end
    
    success = analyze_json_result(file_path)
    
    if success
        println("\n💡 For detailed analysis with plots, use:")
        println("   julia Examples/post_process_node_results.jl $file_path")
    end
end

# Run main function if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end