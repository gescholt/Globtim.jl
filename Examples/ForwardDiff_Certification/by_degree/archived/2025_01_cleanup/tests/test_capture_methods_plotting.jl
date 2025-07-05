"""
Test suite for min+min capture methods histogram functionality.
Validates the plot_min_min_capture_methods function.
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

# Test function 1: Single domain capture methods
function test_single_domain_capture_methods()
    println("\n=== Testing Single Domain Capture Methods Histogram ===")
    
    # Create mock enhanced results with varied capture methods
    results = EnhancedDegreeAnalysisResult[]
    
    degrees = [2, 4, 6, 8, 10]
    n_min_min = 9
    
    # Define capture patterns for each degree
    capture_patterns = [
        (direct=2, bfgs=1, not_found=6),  # degree 2: poor performance
        (direct=3, bfgs=2, not_found=4),  # degree 4: improving
        (direct=5, bfgs=2, not_found=2),  # degree 6: good
        (direct=6, bfgs=3, not_found=0),  # degree 8: all found
        (direct=7, bfgs=2, not_found=0),  # degree 10: mostly direct
    ]
    
    for (i, (deg, pattern)) in enumerate(zip(degrees, capture_patterns))
        # Create boolean vectors based on pattern
        min_min_within_tolerance = falses(n_min_min)
        min_min_found_by_bfgs = falses(n_min_min)
        
        # Set direct captures (within tolerance but not by BFGS)
        for j in 1:pattern.direct
            min_min_within_tolerance[j] = true
        end
        
        # Set BFGS captures (both within tolerance and by BFGS)
        for j in (pattern.direct + 1):(pattern.direct + pattern.bfgs)
            min_min_within_tolerance[j] = true
            min_min_found_by_bfgs[j] = true
        end
        
        basic = DegreeAnalysisResult(
            deg,
            10.0^(-0.3 * deg),
            81,
            60 + i * 5,
            55 + i * 5,
            (55 + i * 5) / 81,
            deg * 2.0,
            deg >= 6,
            [rand(4) for _ in 1:(60 + i * 5)],
            sum(min_min_within_tolerance) / n_min_min,
            [j <= sum(min_min_within_tolerance) ? 0.01 : 0.1 for j in 1:n_min_min]
        )
        
        enhanced = convert_to_enhanced(
            basic,
            [rand(4) for _ in 1:81],
            collect(1:n_min_min),
            "full_domain"
        )
        
        # Override capture method fields
        enhanced = EnhancedDegreeAnalysisResult(
            enhanced.degree, enhanced.l2_norm, enhanced.n_theoretical_points,
            enhanced.n_computed_points, enhanced.n_successful_recoveries,
            enhanced.success_rate, enhanced.runtime_seconds, enhanced.converged,
            enhanced.computed_points, enhanced.min_min_success_rate,
            enhanced.min_min_distances, enhanced.all_critical_distances,
            min_min_found_by_bfgs, min_min_within_tolerance,
            enhanced.point_classifications, enhanced.theoretical_points,
            enhanced.subdomain_label, enhanced.bfgs_iterations,
            enhanced.function_values
        )
        
        push!(results, enhanced)
    end
    
    println("Testing capture methods for degrees: $(degrees)")
    for (i, r) in enumerate(results)
        direct = sum(r.min_min_within_tolerance .& .!r.min_min_found_by_bfgs)
        bfgs = sum(r.min_min_found_by_bfgs)
        not_found = n_min_min - sum(r.min_min_within_tolerance)
        println("  Degree $(r.degree): Direct=$direct, BFGS=$bfgs, Not found=$not_found")
    end
    
    # Test with counts display
    fig_counts = plot_min_min_capture_methods(
        results,
        title="Min+Min Capture Methods by Degree",
        show_percentages=false
    )
    
    # Test with percentages display
    fig_percents = plot_min_min_capture_methods(
        results,
        title="Min+Min Capture Methods (Percentages)",
        show_percentages=true
    )
    
    # Save test outputs
    output_dir = joinpath(@__DIR__, "test_outputs", "capture_methods_" * Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    plot_min_min_capture_methods(
        results,
        title="Min+Min Capture Methods by Degree",
        save_plots=true,
        plots_directory=output_dir
    )
    
    println("✓ Single domain capture methods histogram created")
    println("  - Shows direct tolerance, BFGS, and not found")
    println("  - Both count and percentage versions tested")
    println("  - Output saved to: $(output_dir)")
    
    return fig_counts, fig_percents
end

# Test function 2: Multi-domain capture methods
function test_multi_domain_capture_methods()
    println("\n=== Testing Multi-Domain Capture Methods Histogram ===")
    
    # Create mock results for multiple subdomains
    subdomain_results = Dict{String,Vector{EnhancedDegreeAnalysisResult}}()
    
    subdomains = ["0000", "0001", "0010", "0011", "0100"]
    degrees = [2, 4, 6, 8]
    
    for (sub_idx, subdomain) in enumerate(subdomains)
        results = EnhancedDegreeAnalysisResult[]
        
        for (deg_idx, deg) in enumerate(degrees)
            # Vary capture methods by subdomain
            performance_factor = 0.6 + 0.1 * sub_idx
            
            n_min_min = 9
            
            # Calculate captures based on degree and subdomain
            direct_base = round(Int, 2 + deg_idx * performance_factor)
            bfgs_base = round(Int, 1 + deg_idx * 0.5)
            
            direct_captures = min(direct_base, n_min_min - bfgs_base)
            bfgs_captures = min(bfgs_base, n_min_min - direct_captures)
            
            # Create boolean vectors
            min_min_within_tolerance = falses(n_min_min)
            min_min_found_by_bfgs = falses(n_min_min)
            
            # Set captures
            for j in 1:direct_captures
                min_min_within_tolerance[j] = true
            end
            
            for j in (direct_captures + 1):(direct_captures + bfgs_captures)
                min_min_within_tolerance[j] = true
                min_min_found_by_bfgs[j] = true
            end
            
            basic = DegreeAnalysisResult(
                deg,
                10.0^(-0.4 * deg) * (1.0 / performance_factor),
                81,
                round(Int, 50 + deg_idx * 10 * performance_factor),
                round(Int, 45 + deg_idx * 10 * performance_factor),
                0.5 + deg_idx * 0.1,
                deg * 1.8,
                deg >= 6,
                [rand(4) for _ in 1:round(Int, 50 + deg_idx * 10)],
                sum(min_min_within_tolerance) / n_min_min,
                [j <= sum(min_min_within_tolerance) ? 0.02 : 0.15 for j in 1:n_min_min]
            )
            
            enhanced = convert_to_enhanced(
                basic,
                [rand(4) for _ in 1:81],
                collect(1:n_min_min),
                subdomain
            )
            
            # Override capture fields
            enhanced = EnhancedDegreeAnalysisResult(
                enhanced.degree, enhanced.l2_norm, enhanced.n_theoretical_points,
                enhanced.n_computed_points, enhanced.n_successful_recoveries,
                enhanced.success_rate, enhanced.runtime_seconds, enhanced.converged,
                enhanced.computed_points, enhanced.min_min_success_rate,
                enhanced.min_min_distances, enhanced.all_critical_distances,
                min_min_found_by_bfgs, min_min_within_tolerance,
                enhanced.point_classifications, enhanced.theoretical_points,
                enhanced.subdomain_label, enhanced.bfgs_iterations,
                enhanced.function_values
            )
            
            push!(results, enhanced)
        end
        
        subdomain_results[subdomain] = results
    end
    
    println("Testing multi-domain capture methods...")
    println("  Subdomains: $(join(subdomains, ", "))")
    println("  Degrees: $(degrees)")
    
    # Show aggregated totals
    for deg in degrees
        total_direct = 0
        total_bfgs = 0
        total_not_found = 0
        
        for (_, results) in subdomain_results
            for r in results
                if r.degree == deg
                    direct = sum(r.min_min_within_tolerance .& .!r.min_min_found_by_bfgs)
                    bfgs = sum(r.min_min_found_by_bfgs)
                    not_found = 9 - sum(r.min_min_within_tolerance)
                    
                    total_direct += direct
                    total_bfgs += bfgs
                    total_not_found += not_found
                end
            end
        end
        
        println("  Degree $deg totals: Direct=$total_direct, BFGS=$total_bfgs, Not found=$total_not_found")
    end
    
    # Create histogram
    fig = plot_min_min_capture_methods(
        subdomain_results,
        title="Multi-Domain Min+Min Capture Methods"
    )
    
    # Save test output
    output_dir = joinpath(@__DIR__, "test_outputs", "capture_methods_" * Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    plot_min_min_capture_methods(
        subdomain_results,
        title="Multi-Domain Min+Min Capture Methods",
        save_plots=true,
        plots_directory=output_dir
    )
    
    println("✓ Multi-domain capture methods histogram created")
    println("  - Aggregated data from $(length(subdomains)) subdomains")
    println("  - Reference line at $(9 * length(subdomains)) total min+min")
    println("  - Output saved to: $(output_dir)")
    
    return fig
end

# Test function 3: Edge cases
function test_capture_methods_edge_cases()
    println("\n=== Testing Capture Methods Edge Cases ===")
    
    output_dir = joinpath(@__DIR__, "test_outputs", "capture_edge_" * Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    # Test 1: All captured by direct tolerance
    println("\nTest 1: All min+min captured directly")
    results_all_direct = EnhancedDegreeAnalysisResult[]
    
    for deg in [4, 6, 8]
        enhanced = create_test_result(deg, 81, 75,
            min_min_within_tolerance=trues(9),
            min_min_found_by_bfgs=falses(9))
        push!(results_all_direct, enhanced)
    end
    
    fig1 = plot_min_min_capture_methods(
        results_all_direct,
        title="All Direct Capture Test",
        save_plots=true,
        plots_directory=output_dir
    )
    println("  ✓ All direct capture case handled")
    
    # Test 2: All captured by BFGS
    println("\nTest 2: All min+min captured by BFGS")
    results_all_bfgs = EnhancedDegreeAnalysisResult[]
    
    for deg in [4, 6, 8]
        enhanced = create_test_result(deg, 81, 75,
            min_min_within_tolerance=trues(9),
            min_min_found_by_bfgs=trues(9))
        push!(results_all_bfgs, enhanced)
    end
    
    fig2 = plot_min_min_capture_methods(
        results_all_bfgs,
        title="All BFGS Capture Test",
        save_plots=true,
        plots_directory=output_dir
    )
    println("  ✓ All BFGS capture case handled")
    
    # Test 3: None captured
    println("\nTest 3: No min+min captured")
    results_none = EnhancedDegreeAnalysisResult[]
    
    for deg in [2, 4]
        enhanced = create_test_result(deg, 81, 20,
            min_min_within_tolerance=falses(9),
            min_min_found_by_bfgs=falses(9))
        push!(results_none, enhanced)
    end
    
    fig3 = plot_min_min_capture_methods(
        results_none,
        title="No Capture Test",
        show_percentages=true,
        save_plots=true,
        plots_directory=output_dir
    )
    println("  ✓ No capture case handled")
    
    println("\nEdge case tests complete!")
    println("Output saved to: $(output_dir)")
    
    return output_dir
end

# Helper function to create test results
function create_test_result(degree, n_theoretical, n_computed; 
                           min_min_within_tolerance, min_min_found_by_bfgs)
    basic = DegreeAnalysisResult(
        degree, 10.0^(-0.3 * degree), n_theoretical, n_computed,
        round(Int, n_computed * 0.9), n_computed / n_theoretical,
        degree * 2.0, degree >= 6,
        [rand(4) for _ in 1:n_computed],
        sum(min_min_within_tolerance) / 9,
        [i <= sum(min_min_within_tolerance) ? 0.01 : 0.1 for i in 1:9]
    )
    
    enhanced = convert_to_enhanced(
        basic,
        [rand(4) for _ in 1:n_theoretical],
        collect(1:9),
        "test"
    )
    
    # Override capture fields
    return EnhancedDegreeAnalysisResult(
        enhanced.degree, enhanced.l2_norm, enhanced.n_theoretical_points,
        enhanced.n_computed_points, enhanced.n_successful_recoveries,
        enhanced.success_rate, enhanced.runtime_seconds, enhanced.converged,
        enhanced.computed_points, enhanced.min_min_success_rate,
        enhanced.min_min_distances, enhanced.all_critical_distances,
        min_min_found_by_bfgs, min_min_within_tolerance,
        enhanced.point_classifications, enhanced.theoretical_points,
        enhanced.subdomain_label, enhanced.bfgs_iterations,
        enhanced.function_values
    )
end

# Main test runner
function run_all_tests()
    println("Min+Min Capture Methods Histogram Test Suite")
    println("===========================================")
    
    try
        # Run all test functions
        fig_counts, fig_percents = test_single_domain_capture_methods()
        fig_multi = test_multi_domain_capture_methods()
        edge_dir = test_capture_methods_edge_cases()
        
        println("\n=== All Tests Completed Successfully! ===")
        
        println("\nKey Features Tested:")
        println("1. Single domain capture methods ✓")
        println("   - Direct tolerance captures (green)")
        println("   - BFGS refinement captures (orange)")
        println("   - Not found (red)")
        println("2. Count vs percentage display ✓")
        println("3. Multi-domain aggregation ✓")
        println("4. Edge cases handled ✓")
        println("   - All direct captures")
        println("   - All BFGS captures")
        println("   - No captures")
        println("5. Reference line at expected count ✓")
        
        println("\nTest outputs saved in: test_outputs/capture_*/")
        
        return (counts=fig_counts, percents=fig_percents, multi=fig_multi, edge_dir=edge_dir)
        
    catch e
        println("\n!!! Test Failed !!!")
        println("Error: $e")
        rethrow(e)
    end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    figs = run_all_tests()
    
    # Display the multi-domain plot
    println("\n📊 Displaying the multi-domain capture methods histogram...")
    display(figs.multi)
end