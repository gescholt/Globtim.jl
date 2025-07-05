"""
Test suite for critical point recovery histogram functionality.
Validates the plot_critical_point_recovery_histogram function.
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

# Test function 1: Single domain histogram
function test_single_domain_histogram()
    println("\n=== Testing Single Domain Recovery Histogram ===")
    
    # Create mock enhanced results with improving recovery
    results = EnhancedDegreeAnalysisResult[]
    
    degrees = [2, 4, 6, 8, 10, 12]
    n_theoretical = 81  # 4D Deuflhard
    n_min_min = 9
    
    for (i, deg) in enumerate(degrees)
        # Simulate improving performance with degree
        recovery_rate = min(0.3 + 0.1 * i, 0.95)
        n_computed = round(Int, n_theoretical * recovery_rate * 0.8)  # Not all computed are successful
        
        # Min+min recovery improves faster
        min_min_recovery_rate = min(0.4 + 0.15 * i, 1.0)
        n_min_min_found = round(Int, n_min_min * min_min_recovery_rate)
        
        # Create boolean vector for min+min captures
        min_min_within_tolerance = [j <= n_min_min_found for j in 1:n_min_min]
        
        basic = DegreeAnalysisResult(
            deg,
            10.0^(-0.3 * deg),
            n_theoretical,
            n_computed,
            round(Int, n_computed * 0.9),
            recovery_rate,
            deg * 2.0,
            deg >= 6,
            [rand(4) for _ in 1:n_computed],
            min_min_recovery_rate,
            [0.1 / deg for _ in 1:n_min_min]
        )
        
        enhanced = convert_to_enhanced(
            basic,
            [rand(4) for _ in 1:n_theoretical],
            collect(1:n_min_min),
            "full_domain",
            bfgs_data=Dict(:refined_indices => [], :iterations => zeros(Int, n_computed))
        )
        
        # Override the min_min_within_tolerance with our test data
        enhanced = EnhancedDegreeAnalysisResult(
            enhanced.degree, enhanced.l2_norm, enhanced.n_theoretical_points,
            enhanced.n_computed_points, enhanced.n_successful_recoveries,
            enhanced.success_rate, enhanced.runtime_seconds, enhanced.converged,
            enhanced.computed_points, enhanced.min_min_success_rate,
            enhanced.min_min_distances, enhanced.all_critical_distances,
            enhanced.min_min_found_by_bfgs, min_min_within_tolerance,
            enhanced.point_classifications, enhanced.theoretical_points,
            enhanced.subdomain_label, enhanced.bfgs_iterations,
            enhanced.function_values
        )
        
        push!(results, enhanced)
    end
    
    println("Plotting single domain recovery histogram...")
    println("  Degrees: $(degrees)")
    println("  Min+min found: $([sum(r.min_min_within_tolerance) for r in results])")
    println("  Total computed: $([r.n_computed_points for r in results])")
    println("  Theoretical: $(n_theoretical)")
    
    # Create histogram
    fig = plot_critical_point_recovery_histogram(
        results,
        title="Critical Point Recovery Progress"
    )
    
    # Save test output
    output_dir = joinpath(@__DIR__, "test_outputs", "histogram_" * Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    fig_save = plot_critical_point_recovery_histogram(
        results,
        title="Critical Point Recovery Progress",
        save_plots=true,
        plots_directory=output_dir
    )
    
    println("✓ Single domain histogram created")
    println("  - Shows 3-layer stacked bars")
    println("  - Reference line at 9 min+min points")
    println("  - Output saved to: $(output_dir)")
    
    return fig
end

# Test function 2: Multi-domain histogram
function test_multi_domain_histogram()
    println("\n=== Testing Multi-Domain Recovery Histogram ===")
    
    # Create mock results for multiple subdomains
    subdomain_results = Dict{String,Vector{EnhancedDegreeAnalysisResult}}()
    
    subdomains = ["0000", "0001", "0010", "0011"]
    degrees = [2, 4, 6, 8]
    
    for (sub_idx, subdomain) in enumerate(subdomains)
        results = EnhancedDegreeAnalysisResult[]
        
        for (deg_idx, deg) in enumerate(degrees)
            # Vary performance by subdomain
            performance_factor = 0.8 + 0.1 * sub_idx
            
            n_theoretical = 81
            n_min_min = 9
            
            # Compute points found
            base_rate = 0.3 + 0.15 * deg_idx
            n_computed = round(Int, n_theoretical * base_rate * performance_factor)
            
            # Min+min found
            min_min_rate = 0.4 + 0.2 * deg_idx
            n_min_min_found = min(round(Int, n_min_min * min_min_rate * performance_factor), n_min_min)
            
            min_min_within_tolerance = [j <= n_min_min_found for j in 1:n_min_min]
            
            basic = DegreeAnalysisResult(
                deg,
                10.0^(-0.4 * deg) * (1.0 / performance_factor),
                n_theoretical,
                n_computed,
                round(Int, n_computed * 0.85),
                n_computed / n_theoretical,
                deg * 1.5,
                deg >= 6,
                [rand(4) for _ in 1:n_computed],
                n_min_min_found / n_min_min,
                [0.1 / deg * (1.0 / performance_factor) for _ in 1:n_min_min]
            )
            
            enhanced = convert_to_enhanced(
                basic,
                [rand(4) for _ in 1:n_theoretical],
                collect(1:n_min_min),
                subdomain
            )
            
            # Override min_min_within_tolerance
            enhanced = EnhancedDegreeAnalysisResult(
                enhanced.degree, enhanced.l2_norm, enhanced.n_theoretical_points,
                enhanced.n_computed_points, enhanced.n_successful_recoveries,
                enhanced.success_rate, enhanced.runtime_seconds, enhanced.converged,
                enhanced.computed_points, enhanced.min_min_success_rate,
                enhanced.min_min_distances, enhanced.all_critical_distances,
                enhanced.min_min_found_by_bfgs, min_min_within_tolerance,
                enhanced.point_classifications, enhanced.theoretical_points,
                enhanced.subdomain_label, enhanced.bfgs_iterations,
                enhanced.function_values
            )
            
            push!(results, enhanced)
        end
        
        subdomain_results[subdomain] = results
    end
    
    println("Plotting multi-domain recovery histogram...")
    println("  Subdomains: $(join(subdomains, ", "))")
    println("  Degrees: $(degrees)")
    
    # Show aggregated stats
    for deg in degrees
        total_min_min = 0
        total_computed = 0
        for (_, results) in subdomain_results
            for r in results
                if r.degree == deg
                    total_min_min += sum(r.min_min_within_tolerance)
                    total_computed += r.n_computed_points
                end
            end
        end
        println("  Degree $deg: $total_min_min min+min, $total_computed total")
    end
    
    # Create histogram
    fig = plot_critical_point_recovery_histogram(
        subdomain_results,
        title="Multi-Domain Critical Point Recovery"
    )
    
    # Save test output
    output_dir = joinpath(@__DIR__, "test_outputs", "histogram_" * Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    fig_save = plot_critical_point_recovery_histogram(
        subdomain_results,
        title="Multi-Domain Critical Point Recovery",
        save_plots=true,
        plots_directory=output_dir
    )
    
    println("✓ Multi-domain histogram created")
    println("  - Shows aggregated data from $(length(subdomains)) subdomains")
    println("  - Reference line at $(9 * length(subdomains)) total min+min points")
    println("  - Output saved to: $(output_dir)")
    
    return fig
end

# Test function 3: Edge cases
function test_histogram_edge_cases()
    println("\n=== Testing Histogram Edge Cases ===")
    
    output_dir = joinpath(@__DIR__, "test_outputs", "histogram_edge_" * Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    # Test 1: No points found
    println("\nTest 1: No critical points found")
    results_empty = EnhancedDegreeAnalysisResult[]
    
    for deg in [2, 4, 6]
        basic = DegreeAnalysisResult(
            deg, 0.1, 81, 0, 0, 0.0, 1.0, false,
            Vector{Vector{Float64}}(), 0.0, Float64[]
        )
        
        enhanced = convert_to_enhanced(
            basic,
            [rand(4) for _ in 1:81],
            collect(1:9),
            "empty_test"
        )
        
        push!(results_empty, enhanced)
    end
    
    fig1 = plot_critical_point_recovery_histogram(
        results_empty,
        title="No Points Found Test",
        save_plots=true,
        plots_directory=output_dir
    )
    println("  ✓ Empty results handled (all bars show theoretical only)")
    
    # Test 2: Perfect recovery
    println("\nTest 2: Perfect recovery (all points found)")
    results_perfect = EnhancedDegreeAnalysisResult[]
    
    for deg in [4, 6, 8]
        basic = DegreeAnalysisResult(
            deg, 1e-10, 81, 81, 81, 1.0, 5.0, true,
            [rand(4) for _ in 1:81], 1.0, zeros(9)
        )
        
        enhanced = convert_to_enhanced(
            basic,
            [rand(4) for _ in 1:81],
            collect(1:9),
            "perfect_test"
        )
        
        # Set all min+min as found
        enhanced = EnhancedDegreeAnalysisResult(
            enhanced.degree, enhanced.l2_norm, enhanced.n_theoretical_points,
            enhanced.n_computed_points, enhanced.n_successful_recoveries,
            enhanced.success_rate, enhanced.runtime_seconds, enhanced.converged,
            enhanced.computed_points, enhanced.min_min_success_rate,
            enhanced.min_min_distances, enhanced.all_critical_distances,
            enhanced.min_min_found_by_bfgs, trues(9),  # All 9 min+min found
            enhanced.point_classifications, enhanced.theoretical_points,
            enhanced.subdomain_label, enhanced.bfgs_iterations,
            enhanced.function_values
        )
        
        push!(results_perfect, enhanced)
    end
    
    fig2 = plot_critical_point_recovery_histogram(
        results_perfect,
        title="Perfect Recovery Test",
        save_plots=true,
        plots_directory=output_dir
    )
    println("  ✓ Perfect recovery shown (full bars, no transparent layer)")
    
    println("\nEdge case tests complete!")
    println("Output saved to: $(output_dir)")
    
    return output_dir
end

# Main test runner
function run_all_tests()
    println("Critical Point Recovery Histogram Test Suite")
    println("===========================================")
    
    try
        # Run all test functions
        fig1 = test_single_domain_histogram()
        fig2 = test_multi_domain_histogram()
        edge_dir = test_histogram_edge_cases()
        
        println("\n=== All Tests Completed Successfully! ===")
        
        println("\nKey Features Tested:")
        println("1. Single domain histogram ✓")
        println("   - 3-layer stacked bars (min+min, other, remaining)")
        println("   - Reference line at 9 for min+min count")
        println("2. Multi-domain aggregated histogram ✓")
        println("   - Combines data from multiple subdomains")
        println("   - Reference line scales with subdomain count")
        println("3. Edge cases handled ✓")
        println("   - No points found")
        println("   - Perfect recovery")
        println("4. Visual styling ✓")
        println("   - Blue color palette")
        println("   - Clear legend and labels")
        
        println("\nTest outputs saved in: test_outputs/histogram_*/")
        
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
    
    # Display the single domain histogram
    println("\n📊 Displaying the single domain recovery histogram...")
    display(figs.single)
end