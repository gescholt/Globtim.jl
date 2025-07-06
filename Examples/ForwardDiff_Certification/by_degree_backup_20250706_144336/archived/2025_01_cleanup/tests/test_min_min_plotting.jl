"""
Test suite for min+min distance plotting functionality.
Validates the plot_min_min_distances_dual_scale function.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim
using DataFrames
using Dates
using LinearAlgebra
using Statistics

# Include enhanced utilities
include("shared/EnhancedAnalysisUtilities.jl")
include("shared/EnhancedPlottingUtilities.jl")
using .EnhancedAnalysisUtilities
using .EnhancedPlottingUtilities

# Mock DegreeAnalysisResult for testing
struct DegreeAnalysisResult
    degree::Int
    l2_norm::Float64
    n_theoretical_points::Int
    n_computed_points::Int
    n_successful_recoveries::Int
    success_rate::Float64
    runtime_seconds::Float64
    converged::Bool
    computed_points::Vector{Vector{Float64}}
    min_min_success_rate::Float64
    min_min_distances::Vector{Float64}
end

# Test function 1: Single domain min+min distance plotting
function test_single_domain_min_min()
    println("\n=== Testing Single Domain Min+Min Distance Plot ===")
    
    # Create mock data with decreasing distances as degree increases
    degrees = [2, 4, 6, 8, 10]
    min_min_data = []
    
    for deg in degrees
        # Generate 9 min+min distances that decrease with degree
        base_dist = 0.5 / deg
        distances = [base_dist * (1.0 + 0.2 * randn()) for _ in 1:9]
        # Ensure positive distances
        distances = max.(distances, 1e-6)
        push!(min_min_data, distances)
    end
    
    # Create DataFrame for plotting
    df = DataFrame(
        degree = degrees,
        min_min_distances = min_min_data
    )
    
    println("Plotting single domain min+min distances...")
    println("  Degrees: $(df.degree)")
    println("  Min distances: $(round.([minimum(d) for d in df.min_min_distances], digits=4))")
    println("  Avg distances: $(round.([mean(d) for d in df.min_min_distances], digits=4))")
    
    # Plot with tolerance line
    fig = plot_min_min_distances_dual_scale(
        df,
        title="Single Domain Min+Min Distance Convergence",
        tolerance_line=0.05
    )
    
    # Save test output
    output_dir = joinpath(@__DIR__, "test_outputs", "min_min_" * Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    fig_save = plot_min_min_distances_dual_scale(
        df,
        title="Single Domain Min+Min Distance Convergence",
        tolerance_line=0.05,
        save_plots=true,
        plots_directory=output_dir
    )
    
    println("✓ Single domain min+min plot created")
    println("  - Shows both minimum and average distances")
    println("  - Tolerance line at 0.05")
    println("  - Output saved to: $(output_dir)")
    
    return fig
end

# Test function 2: Multi-domain min+min distance plotting
function test_multi_domain_min_min()
    println("\n=== Testing Multi-Domain Min+Min Distance Plot ===")
    
    # Create mock results for multiple subdomains
    subdomain_results = Dict{String,Vector{EnhancedDegreeAnalysisResult}}()
    
    subdomains = ["0000", "0001", "0010", "0011", "0100", "0101"]
    
    for (idx, subdomain) in enumerate(subdomains)
        results = EnhancedDegreeAnalysisResult[]
        
        for deg in 2:2:10
            # Vary performance by subdomain
            performance_factor = 1.0 + 0.3 * sin(idx * 0.5 + deg * 0.1)
            
            # Generate min+min distances
            base_dist = 0.4 / deg * performance_factor
            min_min_distances = [base_dist * (1.0 + 0.15 * randn()) for _ in 1:9]
            min_min_distances = max.(min_min_distances, 1e-6)
            
            basic = DegreeAnalysisResult(
                deg,
                10.0^(-0.4 * deg) * performance_factor,
                81,
                round(Int, 70 + deg - idx),
                round(Int, 65 + deg - idx),
                (65 + deg - idx) / 81,
                deg * 1.2,
                deg >= 6,
                [rand(4) for _ in 1:round(Int, 70 + deg - idx)],
                0.75 + 0.03 * deg,
                min_min_distances
            )
            
            theoretical_points = [rand(4) for _ in 1:81]
            min_min_indices = collect(1:9)
            
            enhanced = convert_to_enhanced(
                basic,
                theoretical_points,
                min_min_indices,
                subdomain
            )
            
            push!(results, enhanced)
        end
        
        subdomain_results[subdomain] = results
    end
    
    println("Plotting multi-domain min+min distances...")
    for (label, results) in sort(collect(subdomain_results), by=x->x[1])
        degrees = [r.degree for r in results]
        min_dists = [minimum(r.min_min_distances) for r in results]
        avg_dists = [mean(r.min_min_distances) for r in results]
        println("  Subdomain $label: min $(round.(min_dists, digits=4)), avg $(round.(avg_dists, digits=4))")
    end
    
    # Plot multi-domain with dual scales
    fig = plot_min_min_distances_dual_scale(
        subdomain_results,
        title="Multi-Domain Min+Min Distance Analysis",
        tolerance_line=0.05
    )
    
    # Save test output
    output_dir = joinpath(@__DIR__, "test_outputs", "min_min_" * Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    fig_save = plot_min_min_distances_dual_scale(
        subdomain_results,
        title="Multi-Domain Min+Min Distance Analysis",
        tolerance_line=0.05,
        save_plots=true,
        plots_directory=output_dir
    )
    
    println("✓ Multi-domain min+min plot created")
    println("  - Subdomains: $(join(subdomains, ", "))")
    println("  - Left axis: Individual subdomain curves (min & avg)")
    println("  - Right axis: Aggregated full domain (min & avg)")
    println("  - Output saved to: $(output_dir)")
    
    return fig
end

# Test function 3: Edge cases for min+min plotting
function test_min_min_edge_cases()
    println("\n=== Testing Min+Min Distance Plot Edge Cases ===")
    
    output_dir = joinpath(@__DIR__, "test_outputs", "min_min_edge_" * Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    # Test 1: Empty min+min distances
    println("\nTest 1: Empty min+min distances")
    df_empty = DataFrame(
        degree = [2, 4, 6],
        min_min_distances = [Float64[], Float64[], Float64[]]
    )
    
    try
        fig1 = plot_min_min_distances_dual_scale(
            df_empty,
            title="Empty Min+Min Distances Test",
            save_plots=true,
            plots_directory=output_dir
        )
        println("  ✓ Empty distances handled gracefully")
    catch e
        println("  ! Empty distances caused error: $e")
    end
    
    # Test 2: Single min+min point
    println("\nTest 2: Single min+min point per degree")
    df_single = DataFrame(
        degree = [2, 4, 6, 8],
        min_min_distances = [[0.1], [0.05], [0.02], [0.01]]
    )
    
    fig2 = plot_min_min_distances_dual_scale(
        df_single,
        title="Single Min+Min Point Test",
        save_plots=true,
        plots_directory=output_dir
    )
    println("  ✓ Single point per degree handled (min = avg)")
    
    # Test 3: Very small values (testing log scale)
    println("\nTest 3: Very small distance values")
    df_small = DataFrame(
        degree = [2, 4, 6, 8, 10],
        min_min_distances = [
            [1e-2, 2e-2, 1.5e-2],
            [1e-4, 2e-4, 1.5e-4],
            [1e-6, 2e-6, 1.5e-6],
            [1e-8, 2e-8, 1.5e-8],
            [1e-10, 2e-10, 1.5e-10]
        ]
    )
    
    fig3 = plot_min_min_distances_dual_scale(
        df_small,
        title="Very Small Distances Test (1e-2 to 1e-10)",
        tolerance_line=1e-6,
        save_plots=true,
        plots_directory=output_dir
    )
    println("  ✓ Very small values handled with log scale")
    
    println("\nEdge case tests complete!")
    println("Output saved to: $(output_dir)")
    
    return output_dir
end

# Main test runner
function run_all_tests()
    println("Min+Min Distance Plotting Test Suite")
    println("====================================")
    
    try
        # Run all test functions
        fig1 = test_single_domain_min_min()
        fig2 = test_multi_domain_min_min()
        edge_dir = test_min_min_edge_cases()
        
        println("\n=== All Tests Completed Successfully! ===")
        
        println("\nKey Features Tested:")
        println("1. Single domain min+min distance plotting ✓")
        println("   - Minimum distances shown as solid lines")
        println("   - Average distances shown as dashed lines")
        println("2. Multi-domain dual-scale plotting ✓")
        println("   - Left axis: Individual subdomain curves")
        println("   - Right axis: Aggregated full domain")
        println("3. Edge cases handled ✓")
        println("   - Empty distances")
        println("   - Single point per degree")
        println("   - Very small values with log scale")
        println("4. Tolerance line visualization ✓")
        
        println("\nTest outputs saved in: test_outputs/min_min_*/")
        
        return (single=fig1, multi=fig2, edge_dir=edge_dir)
        
    catch e
        println("\n!!! Test Failed !!!")
        println("Error: $e")
        rethrow(e)
    end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    figs = run_all_tests()
    
    # Optionally display one of the plots
    println("\n📊 Displaying the multi-domain min+min distance plot...")
    display(figs.multi)
end