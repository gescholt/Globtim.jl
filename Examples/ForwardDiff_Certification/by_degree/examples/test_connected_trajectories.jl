# Test script to verify connected L2-norm trajectories for all 16 subdomains

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using Globtim
using CairoMakie
using Colors
using Dates

# Add shared modules
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))
using Common4DDeuflhard
using AnalysisUtilities
using PlottingUtilities
using TheoreticalPoints
using SubdomainManagement

function test_connected_trajectories()
    println("Testing connected L2-norm trajectories visualization")
    println("=" ^ 60)
    
    # Generate 16 subdivisions
    subdivisions = generate_16_subdivisions_orthant()
    println("Generated $(length(subdivisions)) subdomains")
    
    # Test with a few degrees
    degrees = [2, 3, 4, 5, 6]
    
    # Analyze first 4 subdomains for quick test
    all_results = Dict{String, Vector{DegreeAnalysisResult}}()
    
    for (i, subdomain) in enumerate(subdivisions[1:4])
        println("\nAnalyzing subdomain $i: $(subdomain.label)")
        
        # Get theoretical points
        theoretical_points, theoretical_values, theoretical_types = 
            load_theoretical_points_for_subdomain_orthant(subdomain)
        
        if isempty(theoretical_points)
            println("  No theoretical points, skipping")
            continue
        end
        
        subdomain_results = DegreeAnalysisResult[]
        
        for degree in degrees
            println("  Degree $degree...")
            result = analyze_single_degree(
                deuflhard_4d_composite,
                degree,
                subdomain.center,
                subdomain.range,
                theoretical_points,
                theoretical_types,
                gn = GN_FIXED,
                tolerance_target = 0.01
            )
            push!(subdomain_results, result)
        end
        
        all_results[subdomain.label] = subdomain_results
    end
    
    # Create output directory
    output_dir = joinpath(@__DIR__, "../outputs", "trajectory_test_" * Dates.format(now(), "HH-MM"))
    mkpath(output_dir)
    
    # Generate plot with connected trajectories
    println("\nGenerating connected trajectory plot...")
    fig = plot_subdivision_convergence(
        all_results,
        title = "L²-Norm Convergence: Connected Trajectories Test",
        tolerance_line = 0.01,
        save_path = joinpath(output_dir, "connected_trajectories.png")
    )
    
    println("\nPlot saved to: $output_dir")
    
    # Also create a version with all 16 subdomains if desired
    println("\nWould analyze all 16 subdomains in production")
    
    return fig, all_results
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    fig, results = test_connected_trajectories()
    
    # Try to display
    try
        display(fig)
    catch
        println("\nPlot saved but cannot display in terminal")
    end
end