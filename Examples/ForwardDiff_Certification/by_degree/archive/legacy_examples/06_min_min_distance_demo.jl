# 06_min_min_distance_demo.jl
# Demonstrates the new min+min distance tracking and visualization
# Shows how distance from min+min theoretical points to closest computed points changes with degree

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using Globtim
using DynamicPolynomials
using CairoMakie
using Dates
using DataFrames
using CSV
using Statistics

# Add shared modules
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))
using Common4DDeuflhard
using AnalysisUtilities
using PlottingUtilities
using TheoreticalPoints
using SubdomainManagement

"""
Run demonstration of min+min distance analysis
"""
function run_min_min_distance_demo()
    println("=== Min+Min Distance Analysis Demo ===")
    println("Tracking distance from theoretical min+min points to closest computed points")
    
    # Parameters
    degrees = 4:2:12
    
    # Part 1: Full domain analysis
    println("\nPart 1: Full Domain Analysis")
    println("==============================")
    
    # Get theoretical points
    theoretical_points, theoretical_values, theoretical_types = load_theoretical_4d_points_orthant()
    n_min_min = count(t -> t == "min+min", theoretical_types)
    println("Total theoretical points: $(length(theoretical_points))")
    println("Min+min points: $n_min_min")
    
    # Analyze each degree
    results = DegreeAnalysisResult[]
    for degree in degrees
        println("\nDegree $degree:")
        result = analyze_single_degree(
            deuflhard_4d_composite,
            degree,
            [0.5, -0.5, 0.5, -0.5],  # Center of (+,-,+,-) orthant
            0.5,
            theoretical_points,
            theoretical_types,
            gn=GN_FIXED,
            tolerance_target=0.01
        )
        push!(results, result)
        
        # Report min+min distances
        if !isempty(result.min_min_distances)
            println("  Min+min distances: min=$(minimum(result.min_min_distances)), " *
                   "max=$(maximum(result.min_min_distances)), " *
                   "mean=$(mean(result.min_min_distances))")
            println("  Min+min within tolerance: $(sum(result.min_min_distances .< 1e-4))/$(length(result.min_min_distances))")
        else
            println("  No min+min points in domain")
        end
    end
    
    # Create output directory
    output_dir = joinpath(@__DIR__, "../outputs", "min_min_demo_" * Dates.format(now(), "mm-dd_HH-MM"))
    mkpath(output_dir)
    
    # Generate min+min distance plot
    println("\nGenerating min+min distance plot...")
    fig_full = plot_min_min_distances(
        results,
        title="Min+Min Distance Analysis - Full Orthant Domain",
        save_path=joinpath(output_dir, "full_domain_min_min_distances.png")
    )
    println("  Saved: full_domain_min_min_distances.png")
    
    # Part 2: Subdivision analysis
    println("\nPart 2: Subdivision Analysis")
    println("============================")
    
    # Create 16 subdivisions
    subdivisions = generate_16_subdivisions_orthant()
    println("Generated $(length(subdivisions)) subdomains")
    
    # Analyze selected degrees for subdivisions
    subdivision_degrees = [6, 8, 10]
    all_results = Dict{String, Vector{DegreeAnalysisResult}}()
    
    for subdomain in subdivisions[1:4]  # Demo with first 4 subdomains
        println("\nAnalyzing subdomain: $(subdomain.label)")
        
        # Get theoretical points for this subdomain
        sub_theoretical_points, sub_theoretical_values, sub_theoretical_types = 
            load_theoretical_points_for_subdomain_orthant(subdomain)
        
        n_sub_min_min = count(t -> t == "min+min", sub_theoretical_types)
        println("  Theoretical points: $(length(sub_theoretical_points)), min+min: $n_sub_min_min")
        
        if isempty(sub_theoretical_points)
            println("  Skipping - no theoretical points")
            continue
        end
        
        subdomain_results = DegreeAnalysisResult[]
        for degree in subdivision_degrees
            result = analyze_single_degree(
                deuflhard_4d_composite,
                degree,
                subdomain.center,
                subdomain.range,
                sub_theoretical_points,
                sub_theoretical_types,
                gn=GN_FIXED,
                tolerance_target=0.01
            )
            push!(subdomain_results, result)
            
            if !isempty(result.min_min_distances)
                println("    Degree $degree: mean min+min distance = $(mean(result.min_min_distances))")
            end
        end
        
        all_results[subdomain.label] = subdomain_results
    end
    
    # Generate subdivision min+min distance plot
    println("\nGenerating subdivision min+min distance plot...")
    fig_sub = plot_subdivision_min_min_distances(
        all_results,
        title="Min+Min Distance Analysis - Subdomain Comparison",
        save_path=joinpath(output_dir, "subdivision_min_min_distances.png")
    )
    println("  Saved: subdivision_min_min_distances.png")
    
    # Generate comparison statistics
    println("\n=== Distance Statistics Summary ===")
    
    # Full domain statistics
    println("\nFull Domain Results:")
    for (i, result) in enumerate(results)
        if !isempty(result.min_min_distances)
            println("  Degree $(result.degree): " *
                   "mean=$(round(mean(result.min_min_distances), digits=6)), " *
                   "min=$(round(minimum(result.min_min_distances), digits=6)), " *
                   "recovered=$(sum(result.min_min_distances .< 1e-4))/$(length(result.min_min_distances))")
        end
    end
    
    # Subdivision statistics
    println("\nSubdivision Average Distances:")
    for degree in subdivision_degrees
        all_distances = Float64[]
        n_subdomains_with_minmin = 0
        
        for (label, results) in all_results
            degree_result = findfirst(r -> r.degree == degree, results)
            if degree_result !== nothing && !isempty(results[degree_result].min_min_distances)
                append!(all_distances, results[degree_result].min_min_distances)
                n_subdomains_with_minmin += 1
            end
        end
        
        if !isempty(all_distances)
            println("  Degree $degree: " *
                   "mean=$(round(mean(all_distances), digits=6)) " *
                   "across $n_subdomains_with_minmin subdomains")
        end
    end
    
    println("\nDemo complete! Output directory: $output_dir")
    
    return results, all_results, output_dir
end

# Run the demo if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    results, all_results, output_dir = run_min_min_distance_demo()
    
    # Try to display one of the plots
    try
        fig = plot_min_min_distances(results)
        display(fig)
    catch e
        println("\nNote: Could not display plot in terminal. Check output files.")
    end
end