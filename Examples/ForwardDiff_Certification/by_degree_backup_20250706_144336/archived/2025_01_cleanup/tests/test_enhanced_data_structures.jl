"""
Test suite for enhanced data structures and analysis utilities.
Validates the new EnhancedDegreeAnalysisResult and conversion functions.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim
using LinearAlgebra
using Statistics
using Test

# Include the enhanced utilities (which includes AnalysisUtilities)
include("shared/EnhancedAnalysisUtilities.jl")

# Test function 1: Basic structure creation
function test_enhanced_structure_creation()
    println("\n=== Testing Enhanced Structure Creation ===")
    
    # Create mock data
    degree = 4
    l2_norm = 0.001
    computed_points = [
        [0.5, 0.5, 0.5, 0.5],
        [-0.5, -0.5, -0.5, -0.5],
        [0.7, -0.7, 0.7, -0.7]
    ]
    theoretical_points = [
        [0.5, 0.5, 0.5, 0.5],      # min+min
        [-0.5, -0.5, -0.5, -0.5],  # min+min
        [0.7, -0.7, 0.7, -0.7],    # min+min
        [1.0, 0.0, 0.0, 0.0],      # saddle
        [0.0, 1.0, 0.0, 0.0]       # saddle
    ]
    min_min_indices = [1, 2, 3]
    
    # Create basic result
    basic_result = DegreeAnalysisResult(
        degree,
        l2_norm,
        5,  # n_theoretical
        3,  # n_computed
        3,  # n_successful
        0.6,  # success_rate
        1.23,  # runtime
        true,  # converged
        computed_points,
        1.0,  # min_min_success_rate
        [0.0, 0.0, 0.0]  # perfect min_min_distances
    )
    
    # Convert to enhanced
    enhanced = convert_to_enhanced(
        basic_result,
        theoretical_points,
        min_min_indices,
        "test_domain"
    )
    
    # Validate
    @test enhanced.degree == degree
    @test enhanced.l2_norm ≈ l2_norm
    @test length(enhanced.all_critical_distances) == length(theoretical_points)
    @test length(enhanced.min_min_found_by_bfgs) == length(min_min_indices)
    @test enhanced.subdomain_label == "test_domain"
    
    println("✓ Basic structure creation successful")
    println("  - All critical distances: $(enhanced.all_critical_distances)")
    println("  - Min+min within tolerance: $(enhanced.min_min_within_tolerance)")
    
    return enhanced
end

# Test function 2: Distance computation
function test_distance_computations()
    println("\n=== Testing Distance Computations ===")
    
    # Test cases
    computed = [[0.0, 0.0], [1.0, 1.0], [2.0, 0.0]]
    theoretical = [[0.1, 0.1], [1.1, 0.9], [3.0, 3.0], [-1.0, -1.0]]
    
    distances = compute_all_point_distances(computed, theoretical)
    
    @test length(distances) == length(theoretical)
    @test distances[1] ≈ norm([0.0, 0.0] - [0.1, 0.1])  # Closest to first computed
    @test distances[2] ≈ norm([1.0, 1.0] - [1.1, 0.9])  # Closest to second computed
    
    println("✓ Distance computations correct")
    println("  - Computed distances: $distances")
    
    # Test empty computed points
    empty_distances = compute_all_point_distances(Vector{Float64}[], theoretical)
    @test all(isinf.(empty_distances))
    println("  - Empty case handled correctly")
    
    return distances
end

# Test function 3: Min+min capture analysis
function test_min_min_capture_analysis()
    println("\n=== Testing Min+Min Capture Analysis ===")
    
    # Mock data
    computed_points = [
        [0.5, 0.5],    # Close to first min+min
        [1.0, 1.0],    # Close to second min+min
        [2.1, 2.1]     # Far from third min+min
    ]
    
    min_min_points = [
        [0.51, 0.51],  # Within tolerance of first
        [1.02, 1.02],  # Within tolerance of second
        [3.0, 3.0]     # Not captured
    ]
    
    min_distances = [
        norm(computed_points[1] - min_min_points[1]),
        norm(computed_points[2] - min_min_points[2]),
        norm([2.1, 2.1] - min_min_points[3])
    ]
    
    # Test without BFGS data
    analysis = analyze_min_min_capture(
        computed_points,
        min_min_points,
        min_distances,
        nothing
    )
    
    @test count(analysis.within_tolerance) == 2  # First two within tolerance
    @test !any(analysis.found_by_bfgs)  # No BFGS data provided
    
    # Test with BFGS data
    bfgs_data = Dict(:refined_indices => [2])  # Second point was refined
    analysis_with_bfgs = analyze_min_min_capture(
        computed_points,
        min_min_points,
        min_distances,
        bfgs_data
    )
    
    @test analysis_with_bfgs.found_by_bfgs[2] == true
    
    println("✓ Min+min capture analysis working")
    println("  - Within tolerance: $(analysis.within_tolerance)")
    println("  - Found by BFGS: $(analysis_with_bfgs.found_by_bfgs)")
    
    return analysis
end

# Test function 4: Aggregation functions
function test_aggregation_functions()
    println("\n=== Testing Aggregation Functions ===")
    
    # Create multiple enhanced results
    results = EnhancedDegreeAnalysisResult[]
    
    for deg in 2:4
        basic = DegreeAnalysisResult(
            deg,
            10.0^(-deg),  # L2 norm decreases
            10,           # theoretical points
            8,            # computed points
            7,            # successful
            0.7,          # success rate
            deg * 0.5,    # runtime
            true,
            [rand(4) for _ in 1:8],  # Random points
            0.8,          # min_min success
            rand(3) .* 0.1  # min_min distances
        )
        
        enhanced = convert_to_enhanced(
            basic,
            [rand(4) for _ in 1:10],  # Random theoretical
            [1, 2, 3],  # min+min indices
            "test"
        )
        
        push!(results, enhanced)
    end
    
    # Test aggregation
    agg = aggregate_enhanced_results(results)
    
    @test agg[:degrees] == [2, 3, 4]
    @test length(agg[:l2_norms]) == 3
    @test all(agg[:l2_norms] .> 0)
    @test haskey(agg, :avg_min_min_distances)
    
    println("✓ Aggregation successful")
    println("  - Degrees: $(agg[:degrees])")
    println("  - L2 norms: $(agg[:l2_norms])")
    println("  - Success rates: $(agg[:success_rates])")
    
    return agg
end

# Test function 5: Subdomain statistics
function test_subdomain_statistics()
    println("\n=== Testing Subdomain Statistics ===")
    
    # Create mock subdomain results
    subdomain_results = Dict{String,Vector{EnhancedDegreeAnalysisResult}}()
    
    for sub in ["0000", "0001", "0010"]
        results = EnhancedDegreeAnalysisResult[]
        
        for deg in 2:3
            basic = DegreeAnalysisResult(
                deg,
                10.0^(-deg) * (1 + 0.1*rand()),  # Some variation
                10, 8, 7, 0.7, 1.0, true,
                [rand(4) for _ in 1:8],
                0.8,
                rand(3) .* 0.1
            )
            
            enhanced = convert_to_enhanced(
                basic,
                [rand(4) for _ in 1:10],
                [1, 2, 3],
                sub
            )
            
            push!(results, enhanced)
        end
        
        subdomain_results[sub] = results
    end
    
    # Collect statistics
    stats = collect_subdomain_statistics(subdomain_results)
    
    @test stats[:degrees] == [2, 3]
    @test length(stats[:l2_norm_mean]) == 2
    @test stats[:subdomain_count] == 3
    @test all(stats[:l2_norm_std] .>= 0)
    
    println("✓ Subdomain statistics collected")
    println("  - Degrees: $(stats[:degrees])")
    println("  - L2 mean: $(stats[:l2_norm_mean])")
    println("  - L2 std: $(stats[:l2_norm_std])")
    println("  - Subdomain count: $(stats[:subdomain_count])")
    
    return stats
end

# Main test runner
function run_all_tests()
    println("Starting Enhanced Data Structure Tests")
    println("=====================================")
    
    try
        # Run all tests
        enhanced = test_enhanced_structure_creation()
        distances = test_distance_computations()
        capture_analysis = test_min_min_capture_analysis()
        aggregation = test_aggregation_functions()
        subdomain_stats = test_subdomain_statistics()
        
        println("\n=== All Tests Passed! ===")
        println("\nSummary:")
        println("- Enhanced structure supports $(length(fieldnames(EnhancedDegreeAnalysisResult))) fields")
        println("- Distance computations handle edge cases")
        println("- Min+min capture analysis distinguishes BFGS vs direct capture")
        println("- Aggregation functions provide plotting-ready data")
        println("- Subdomain statistics enable multi-scale visualization")
        
        return true
        
    catch e
        println("\n!!! Test Failed !!!")
        println("Error: $e")
        println(stacktrace())
        return false
    end
end

# Run the tests
if abspath(PROGRAM_FILE) == @__FILE__
    run_all_tests()
end