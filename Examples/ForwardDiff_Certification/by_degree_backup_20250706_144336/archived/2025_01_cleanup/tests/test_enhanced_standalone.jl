"""
Standalone test for enhanced data structures.
Tests the new data collection and aggregation logic without dependencies.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim
using LinearAlgebra
using Statistics
using Test
using DataFrames

# Include enhanced utilities module
include("shared/EnhancedAnalysisUtilities.jl")
using .EnhancedAnalysisUtilities

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

# Test 1: Enhanced structure creation and data flow
function test_enhanced_data_flow()
    println("\n=== Testing Enhanced Data Flow ===")
    
    # Create comprehensive test case
    dim = 4
    degree = 4
    
    # Mock theoretical points (5 total: 3 min+min, 2 others)
    theoretical_points = [
        [0.5, 0.5, 0.5, 0.5],      # min+min
        [-0.5, -0.5, -0.5, -0.5],  # min+min  
        [0.7, -0.7, 0.7, -0.7],    # min+min
        [1.0, 0.0, 0.0, 0.0],      # saddle
        [0.0, 1.0, 0.0, 0.0]       # saddle
    ]
    min_min_indices = [1, 2, 3]
    
    # Mock computed points (4 found)
    computed_points = [
        [0.51, 0.49, 0.50, 0.51],   # Close to min+min 1
        [-0.48, -0.52, -0.49, -0.50], # Close to min+min 2
        [0.95, 0.05, -0.02, 0.03],  # Close to saddle 1
        [0.8, -0.6, 0.75, -0.65]    # Somewhat close to min+min 3
    ]
    
    # Calculate min+min distances
    min_min_distances = Float64[]
    for mm_idx in min_min_indices
        min_dist = minimum(norm(cp - theoretical_points[mm_idx]) for cp in computed_points)
        push!(min_min_distances, min_dist)
    end
    
    # Create basic result
    basic = DegreeAnalysisResult(
        degree,
        0.001,  # l2_norm
        5,      # n_theoretical
        4,      # n_computed
        3,      # n_successful (3 points within tolerance)
        0.6,    # success_rate
        1.23,   # runtime
        true,   # converged
        computed_points,
        2/3,    # min_min_success_rate (2 of 3 found)
        min_min_distances
    )
    
    # Test conversion with BFGS data
    bfgs_data = Dict(
        :refined_indices => [4],  # Fourth point needed BFGS
        :iterations => [0, 0, 0, 15]  # Iterations per point
    )
    
    enhanced = convert_to_enhanced(
        basic,
        theoretical_points,
        min_min_indices,
        "test_subdomain",
        bfgs_data=bfgs_data
    )
    
    # Validate enhanced fields
    println("Enhanced structure created:")
    println("  - Degree: $(enhanced.degree)")
    println("  - L2 norm: $(enhanced.l2_norm)")
    println("  - Subdomain: $(enhanced.subdomain_label)")
    println("  - All distances: $(round.(enhanced.all_critical_distances, digits=3))")
    println("  - Min+min within tolerance: $(enhanced.min_min_within_tolerance)")
    println("  - Min+min by BFGS: $(enhanced.min_min_found_by_bfgs)")
    println("  - BFGS iterations: $(enhanced.bfgs_iterations)")
    
    @test enhanced.degree == degree
    @test length(enhanced.all_critical_distances) == 5
    @test count(enhanced.min_min_within_tolerance) >= 2
    @test enhanced.subdomain_label == "test_subdomain"
    
    return enhanced
end

# Test 2: Multi-domain aggregation
function test_multidomain_aggregation()
    println("\n=== Testing Multi-Domain Aggregation ===")
    
    # Create results for multiple subdomains
    subdomain_results = Dict{String,Vector{EnhancedDegreeAnalysisResult}}()
    
    theoretical_points = [
        [0.5, 0.5], [-0.5, -0.5], [0.0, 1.0]
    ]
    min_min_indices = [1, 2]
    
    for (idx, subdomain) in enumerate(["00", "01", "10", "11"])
        results = EnhancedDegreeAnalysisResult[]
        
        for deg in 2:4
            # Vary performance by subdomain
            performance_factor = 1.0 + 0.1 * idx
            
            basic = DegreeAnalysisResult(
                deg,
                10.0^(-deg) * performance_factor,  # L2 norm
                3,  # theoretical
                3,  # computed  
                2,  # successful
                2/3,  # success_rate
                deg * 0.5,  # runtime
                true,  # converged
                [[x + 0.01*idx for x in pt] for pt in theoretical_points[1:2]],
                1.0,  # min_min_success
                [0.01 * idx, 0.02 * idx]  # min_min_distances
            )
            
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
    
    # Test aggregation
    stats = collect_subdomain_statistics(subdomain_results)
    
    println("Subdomain statistics collected:")
    println("  - Degrees analyzed: $(stats[:degrees])")
    println("  - L2 norm means: $(round.(stats[:l2_norm_mean], digits=5))")
    println("  - L2 norm stds: $(round.(stats[:l2_norm_std], digits=6))")
    println("  - Min distance means: $(round.(stats[:min_dist_mean], digits=4))")
    println("  - Subdomain count: $(stats[:subdomain_count])")
    
    @test stats[:degrees] == [2, 3, 4]
    @test length(stats[:l2_norm_mean]) == 3
    @test all(stats[:l2_norm_mean] .> 0)
    @test stats[:subdomain_count] == 4
    
    # Test single domain aggregation
    single_results = subdomain_results["00"]
    agg = aggregate_enhanced_results(single_results)
    
    println("\nSingle domain aggregation:")
    println("  - Total points: $(agg[:total_points])")
    println("  - Min+min found: $(agg[:min_min_found])")
    println("  - Success rates: $(agg[:success_rates])")
    
    return stats, agg
end

# Test 3: Plotting data preparation
function test_plotting_data_preparation()
    println("\n=== Testing Plotting Data Preparation ===")
    
    # Create a realistic scenario with varying performance
    degrees = 2:6
    n_theoretical = 81  # 4D Deuflhard
    n_min_min = 9
    
    results = EnhancedDegreeAnalysisResult[]
    
    for deg in degrees
        # Simulate improving performance with degree
        l2_norm = 10.0^(-0.5 * deg)
        success_rate = min(0.3 + 0.15 * deg, 1.0)
        n_found = round(Int, n_theoretical * success_rate)
        
        # Mock points
        computed_points = [rand(4) for _ in 1:n_found]
        theoretical_points = [rand(4) for _ in 1:n_theoretical]
        min_min_indices = collect(1:n_min_min)
        
        # Min+min specific metrics
        min_min_distances = [0.1 / deg for _ in 1:n_min_min]
        min_min_success = min((deg - 1) / length(degrees), 1.0)
        
        basic = DegreeAnalysisResult(
            deg, l2_norm, n_theoretical, n_found,
            round(Int, n_found * 0.9), success_rate,
            deg^2 * 0.1, true, computed_points,
            min_min_success, min_min_distances
        )
        
        # Create enhanced with varied BFGS usage
        bfgs_data = Dict(
            :refined_indices => collect(1:2:min(n_found, 10)),
            :iterations => [i % 2 == 0 ? rand(5:20) : 0 for i in 1:n_found]
        )
        
        enhanced = convert_to_enhanced(
            basic, theoretical_points, min_min_indices,
            "full_domain", bfgs_data=bfgs_data
        )
        
        push!(results, enhanced)
    end
    
    # Prepare data for different plot types
    
    # 1. L2-norm convergence data
    l2_data = Dict(
        :degrees => [r.degree for r in results],
        :l2_norms => [r.l2_norm for r in results],
        :converged => [r.converged for r in results]
    )
    
    # 2. Min+min distance data
    distance_data = Dict(
        :degrees => [r.degree for r in results],
        :min_distances => [minimum(r.min_min_distances) for r in results],
        :avg_distances => [mean(r.min_min_distances) for r in results],
        :all_distances => [r.min_min_distances for r in results]
    )
    
    # 3. Recovery histogram data
    histogram_data = Dict(
        :degrees => [r.degree for r in results],
        :total_found => [r.n_computed_points for r in results],
        :min_min_found => [count(r.min_min_within_tolerance) for r in results],
        :min_min_by_bfgs => [count(r.min_min_found_by_bfgs) for r in results],
        :min_min_direct => [count(r.min_min_within_tolerance .& .!r.min_min_found_by_bfgs) for r in results]
    )
    
    println("Prepared plotting data:")
    println("  - L2 convergence: degrees $(l2_data[:degrees])")
    println("    norms: $(round.(l2_data[:l2_norms], digits=5))")
    println("  - Min distances: $(round.(distance_data[:min_distances], digits=4))")
    println("  - Recovery counts: $(histogram_data[:total_found])")
    println("  - Min+min by BFGS: $(histogram_data[:min_min_by_bfgs])")
    println("  - Min+min direct: $(histogram_data[:min_min_direct])")
    
    return l2_data, distance_data, histogram_data
end

# Main test runner
function run_all_tests()
    println("Enhanced Data Structure Tests - Standalone")
    println("==========================================")
    
    try
        # Run tests
        enhanced = test_enhanced_data_flow()
        stats, agg = test_multidomain_aggregation()
        l2_data, dist_data, hist_data = test_plotting_data_preparation()
        
        println("\n=== All Tests Completed Successfully! ===")
        
        println("\nKey Capabilities Demonstrated:")
        println("1. Enhanced data structure tracks:")
        println("   - All critical point distances (not just min+min)")
        println("   - BFGS vs direct capture distinction")
        println("   - Point classifications and subdomain labels")
        println("   - Comprehensive metrics for 4 plot types")
        
        println("\n2. Data aggregation supports:")
        println("   - Multi-subdomain statistics")
        println("   - Degree-wise progression tracking")
        println("   - Separate BFGS/tolerance capture counts")
        
        println("\n3. Plot data preparation provides:")
        println("   - L2-norm convergence trajectories")
        println("   - Min+min distance tracking (min & average)")
        println("   - Three-layer histogram data")
        println("   - BFGS usage breakdown")
        
        return true
        
    catch e
        println("\n!!! Test Failed !!!")
        println("Error: $e")
        rethrow(e)
    end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_all_tests()
end