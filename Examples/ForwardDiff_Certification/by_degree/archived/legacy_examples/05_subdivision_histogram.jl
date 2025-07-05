# 05_subdivision_histogram.jl
# Example showing subdivision histogram visualization
# Demonstrates both combined and separate views for multi-subdomain analysis

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using Globtim
using DynamicPolynomials
using CairoMakie
using Dates
using DataFrames
using CSV

# Add shared modules
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))
using Common4DDeuflhard
using AnalysisUtilities
using PlottingUtilities
using TheoreticalPoints
using SubdomainManagement

"""
Run subdivision analysis with histogram visualizations
"""
function run_subdivision_histogram_demo()
    println("=== Subdivision Histogram Demo ===")
    println("Analyzing Deuflhard 4D with domain subdivision...")
    
    # Parameters
    n_subdivisions = 4  # Create 4 subdomains
    degrees = 4:2:10   # Test degrees 4, 6, 8, 10
    tolerance_target = 0.001
    
    # Get theoretical points for full domain
    all_theoretical_points, all_theoretical_types = get_4d_deuflhard_theoretical_points()
    
    # Create subdomains
    subdomains = create_subdomains_fixed([-0.5, -0.5, -0.5, -0.5], 
                                        [0.5, 0.5, 0.5, 0.5], 
                                        n_subdivisions)
    
    println("Created $(length(subdomains)) subdomains")
    println("Analyzing degrees: ", degrees)
    
    # Store results for each subdomain
    all_results = Dict{String, Vector{DegreeAnalysisResult}}()
    
    # Analyze each subdomain
    for (idx, subdomain) in enumerate(subdomains)
        println("\n--- Subdomain $idx ---")
        center, range_val = subdomain
        println("Center: $center, Range: $range_val")
        
        # Filter theoretical points for this subdomain
        subdomain_points, subdomain_types = filter_points_to_subdomain(
            all_theoretical_points, 
            all_theoretical_types,
            center, 
            range_val
        )
        println("Theoretical points in subdomain: $(length(subdomain_points))")
        
        # Skip if no points in subdomain
        if isempty(subdomain_points)
            println("No theoretical points in this subdomain, skipping...")
            continue
        end
        
        # Analyze each degree
        subdomain_results = DegreeAnalysisResult[]
        for degree in degrees
            print("  Degree $degree: ")
            result = analyze_single_degree(
                deuflhard_4d_composite,
                degree,
                center,
                range_val,
                subdomain_points,
                subdomain_types,
                gn=GN_FIXED,
                tolerance_target=tolerance_target,
                basis=:chebyshev
            )
            push!(subdomain_results, result)
            println("found $(result.n_successful_recoveries)/$(result.n_theoretical_points) points")
        end
        
        all_results["Subdomain $idx"] = subdomain_results
    end
    
    # Create output directory
    output_dir = joinpath(@__DIR__, "../outputs", 
                         "subdivision_histogram_" * Dates.format(now(), "mm-dd_HH-MM"))
    mkpath(output_dir)
    
    println("\nGenerating subdivision histogram visualizations...")
    
    # Combined view - shows total across all subdomains
    fig_combined = plot_subdivision_recovery_histogram(
        all_results,
        title="Combined Subdivision Recovery ($(n_subdivisions) subdomains)",
        show_combined=true
    )
    save(joinpath(output_dir, "subdivision_histogram_combined.png"), fig_combined)
    println("  Saved: subdivision_histogram_combined.png")
    
    # Separate view - shows each subdomain individually
    fig_separate = plot_subdivision_recovery_histogram(
        all_results,
        title="Individual Subdomain Recovery",
        show_combined=false
    )
    save(joinpath(output_dir, "subdivision_histogram_separate.png"), fig_separate)
    println("  Saved: subdivision_histogram_separate.png")
    
    # Also create standard subdivision plots for comparison
    println("\nGenerating standard subdivision plots...")
    
    # L² convergence
    fig_l2 = plot_subdivision_convergence(
        all_results,
        title="Subdivision L²-Norm Convergence",
        tolerance_line=tolerance_target
    )
    save(joinpath(output_dir, "subdivision_l2_convergence.png"), fig_l2)
    
    # Recovery rates
    fig_rates = plot_subdivision_recovery_rates(
        all_results,
        title="Subdivision Recovery Rates"
    )
    save(joinpath(output_dir, "subdivision_recovery_rates.png"), fig_rates)
    
    # Save combined results to CSV
    all_data = []
    for (subdomain_name, results) in all_results
        for r in results
            push!(all_data, (
                subdomain = subdomain_name,
                degree = r.degree,
                l2_norm = r.l2_norm,
                n_theoretical = r.n_theoretical_points,
                n_found = r.n_successful_recoveries,
                success_rate = r.success_rate,
                runtime = r.runtime_seconds
            ))
        end
    end
    df = DataFrame(all_data)
    CSV.write(joinpath(output_dir, "subdivision_results.csv"), df)
    
    # Print summary statistics
    println("\n=== Summary ===")
    println("Output directory: $output_dir")
    println("Number of subdomains analyzed: $(length(all_results))")
    
    # Calculate total points across all subdomains
    total_theoretical = 0
    total_found = 0
    for (_, results) in all_results
        if !isempty(results)
            # Use highest degree for best recovery
            best_result = results[end]
            total_theoretical += best_result.n_theoretical_points
            total_found += best_result.n_successful_recoveries
        end
    end
    
    println("Total theoretical points: $total_theoretical")
    println("Total points found (best degree): $total_found")
    println("Overall recovery rate: $(round(total_found/total_theoretical * 100, digits=1))%")
    
    return all_results, output_dir
end

# Helper function to filter points to subdomain
function filter_points_to_subdomain(points, types, center, range_val)
    filtered_points = Vector{Vector{Float64}}()
    filtered_types = String[]
    
    for (i, point) in enumerate(points)
        # Check if point is within subdomain bounds
        in_bounds = all(abs.(point .- center) .<= range_val .+ 1e-10)
        if in_bounds
            push!(filtered_points, point)
            push!(filtered_types, types[i])
        end
    end
    
    return filtered_points, filtered_types
end

# Run the demo if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    all_results, output_dir = run_subdivision_histogram_demo()
    
    # Try to display the combined histogram
    try
        fig = plot_subdivision_recovery_histogram(all_results, show_combined=true)
        display(fig)
    catch e
        println("\nNote: Could not display plot in terminal. Check output files.")
    end
end