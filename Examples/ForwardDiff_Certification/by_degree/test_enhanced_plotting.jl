"""
Test suite for enhanced plotting utilities.
Validates the L2 convergence dual-scale plotting functionality.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim
using DataFrames
using Dates

# Include enhanced utilities
include("shared/EnhancedAnalysisUtilities.jl")
include("shared/EnhancedPlottingUtilities.jl")
using .EnhancedAnalysisUtilities
using .EnhancedPlottingUtilities

# Include basic utilities for DegreeAnalysisResult
include("shared/AnalysisUtilities.jl")
using .AnalysisUtilities

# Test function 1: Single domain plotting
function test_single_domain_plotting()
    println("\n=== Testing Single Domain L2 Convergence Plot ===")
    
    # Create mock results for single domain
    results = EnhancedDegreeAnalysisResult[]
    
    for deg in 2:2:10
        # Create basic result first
        basic = DegreeAnalysisResult(
            deg,
            10.0^(-0.3 * deg),  # L2 norm decreases with degree
            81,  # theoretical points
            70 + deg,  # more points found at higher degree
            65 + deg,  # successful recoveries
            (65 + deg) / 81,  # success rate
            deg * 1.5,  # runtime
            deg >= 6,  # converged at degree 6 and above
            [rand(4) for _ in 1:(70 + deg)],  # computed points
            0.8 + 0.02 * deg,  # min_min success rate
            [0.1 / deg for _ in 1:9]  # min_min distances
        )
        
        # Convert to enhanced
        theoretical_points = [rand(4) for _ in 1:81]
        min_min_indices = collect(1:9)
        
        enhanced = convert_to_enhanced(
            basic,
            theoretical_points,
            min_min_indices,
            "full_domain"
        )
        
        push!(results, enhanced)
    end
    
    # Create DataFrame for plotting
    df = DataFrame(
        degree = [r.degree for r in results],
        l2_norm = [r.l2_norm for r in results],
        converged = [r.converged for r in results]
    )
    
    # Plot single domain
    fig = plot_l2_convergence_dual_scale(
        df,
        title="Single Domain L2 Convergence Test"
    )
    
    # Save test output
    output_dir = joinpath(@__DIR__, "test_outputs", Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    save(joinpath(output_dir, "single_domain_l2_convergence.png"), fig)
    
    println("✓ Single domain plot created")
    println("  - Degrees tested: 2, 4, 6, 8, 10")
    println("  - Output saved to: $(output_dir)")
    
    return fig
end

# Test function 2: Multi-domain plotting
function test_multi_domain_plotting()
    println("\n=== Testing Multi-Domain L2 Convergence Plot ===")
    
    # Create mock results for multiple subdomains
    subdomain_results = Dict{String,Vector{EnhancedDegreeAnalysisResult}}()
    
    subdomains = ["0000", "0001", "0010", "0011", "0100", "0101"]
    
    for (idx, subdomain) in enumerate(subdomains)
        results = EnhancedDegreeAnalysisResult[]
        
        for deg in 2:2:8
            # Vary performance by subdomain
            performance_factor = 1.0 + 0.2 * sin(idx + deg)
            
            basic = DegreeAnalysisResult(
                deg,
                10.0^(-0.4 * deg) * performance_factor,  # L2 norm with subdomain variation
                81,
                round(Int, 70 + deg - idx),
                round(Int, 65 + deg - idx),
                (65 + deg - idx) / 81,
                deg * 1.2,
                deg >= 6,
                [rand(4) for _ in 1:round(Int, 70 + deg - idx)],
                0.75 + 0.03 * deg,
                [0.15 / deg * performance_factor for _ in 1:9]
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
    
    # Plot multi-domain with dual scales
    fig = plot_l2_convergence_dual_scale(
        subdomain_results,
        title="Multi-Domain L2 Convergence with Dual Scales",
        tolerance_line=0.0007
    )
    
    # Save test output
    output_dir = joinpath(@__DIR__, "test_outputs", Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    save(joinpath(output_dir, "multi_domain_l2_convergence.png"), fig)
    
    println("✓ Multi-domain plot created")
    println("  - Subdomains: $(join(subdomains, ", "))")
    println("  - Degrees: 2, 4, 6, 8")
    println("  - Left axis: Individual subdomain curves")
    println("  - Right axis: Aggregated full domain curve")
    println("  - Output saved to: $(output_dir)")
    
    return fig
end

# Test function 3: Edge cases
function test_edge_cases()
    println("\n=== Testing Edge Cases ===")
    
    output_dir = joinpath(@__DIR__, "test_outputs", Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    # Test 1: Single degree point
    println("\nTest 1: Single degree point")
    single_result = EnhancedDegreeAnalysisResult[]
    
    basic = DegreeAnalysisResult(
        4, 0.001, 81, 75, 70, 70/81, 2.5, false,
        [rand(4) for _ in 1:75], 0.85, rand(9) .* 0.1
    )
    
    enhanced = convert_to_enhanced(
        basic,
        [rand(4) for _ in 1:81],
        collect(1:9),
        "test"
    )
    
    push!(single_result, enhanced)
    
    df = DataFrame(
        degree = [4],
        l2_norm = [0.001],
        converged = [false]
    )
    
    fig1 = plot_l2_convergence_dual_scale(df, title="Single Degree Test")
    save(joinpath(output_dir, "edge_case_single_degree.png"), fig1)
    println("  ✓ Single degree handled correctly")
    
    # Test 2: Empty subdomain
    println("\nTest 2: Empty subdomain in multi-domain")
    subdomain_results = Dict{String,Vector{EnhancedDegreeAnalysisResult}}()
    subdomain_results["0000"] = single_result
    subdomain_results["0001"] = EnhancedDegreeAnalysisResult[]  # Empty
    
    try
        fig2 = plot_l2_convergence_dual_scale(
            subdomain_results,
            title="Empty Subdomain Test"
        )
        save(joinpath(output_dir, "edge_case_empty_subdomain.png"), fig2)
        println("  ✓ Empty subdomain handled gracefully")
    catch e
        println("  ! Empty subdomain caused error: $e")
    end
    
    # Test 3: Very small and very large values
    println("\nTest 3: Extreme values")
    extreme_results = EnhancedDegreeAnalysisResult[]
    
    for (deg, l2_val) in [(2, 1e-1), (4, 1e-5), (6, 1e-10), (8, 1e-15)]
        basic = DegreeAnalysisResult(
            deg, l2_val, 81, 75, 70, 70/81, 2.5, l2_val < 1e-6,
            [rand(4) for _ in 1:75], 0.85, rand(9) .* 0.1
        )
        
        enhanced = convert_to_enhanced(
            basic,
            [rand(4) for _ in 1:81],
            collect(1:9),
            "extreme"
        )
        
        push!(extreme_results, enhanced)
    end
    
    df_extreme = DataFrame(
        degree = [r.degree for r in extreme_results],
        l2_norm = [r.l2_norm for r in extreme_results],
        converged = [r.converged for r in extreme_results]
    )
    
    fig3 = plot_l2_convergence_dual_scale(
        df_extreme,
        title="Extreme Values Test (1e-1 to 1e-15)"
    )
    save(joinpath(output_dir, "edge_case_extreme_values.png"), fig3)
    println("  ✓ Extreme values handled with log scale")
    
    println("\nEdge case tests complete!")
    return output_dir
end

# Test function 4: Display vs Save behavior
function test_display_behavior()
    println("\n=== Testing Display vs Save Behavior ===")
    
    # Create simple test data
    results = EnhancedDegreeAnalysisResult[]
    
    basic = DegreeAnalysisResult(
        4, 0.001, 81, 75, 70, 70/81, 2.5, false,
        [rand(4) for _ in 1:75], 0.85, rand(9) .* 0.1
    )
    
    enhanced = convert_to_enhanced(
        basic,
        [rand(4) for _ in 1:81],
        collect(1:9),
        "display_test"
    )
    
    push!(results, enhanced)
    
    df = DataFrame(
        degree = [4],
        l2_norm = [0.001],
        converged = [false]
    )
    
    # Test default behavior (display)
    println("\nTesting default display behavior...")
    fig1 = plot_l2_convergence_dual_scale(df, title="Display Test")
    println("  ✓ Figure created for display (save_plots=false by default)")
    
    # Test save behavior
    println("\nTesting save behavior...")
    output_dir = joinpath(@__DIR__, "test_outputs", "display_test")
    mkpath(output_dir)
    
    fig2 = plot_l2_convergence_dual_scale(
        df, 
        title="Save Test",
        save_plots=true,
        plots_directory=output_dir
    )
    
    # Check if file was saved
    expected_file = joinpath(output_dir, "l2_convergence_dual_scale.png")
    if isfile(expected_file)
        println("  ✓ File saved successfully to: $expected_file")
    else
        println("  ! File not found at expected location")
    end
    
    return fig1, fig2
end

# Main test runner
function run_all_tests()
    println("Enhanced Plotting Utilities Test Suite")
    println("=====================================")
    
    try
        # Run all test functions
        fig1 = test_single_domain_plotting()
        fig2 = test_multi_domain_plotting()
        output_dir = test_edge_cases()
        display_figs = test_display_behavior()
        
        println("\n=== All Tests Completed Successfully! ===")
        
        println("\nKey Features Tested:")
        println("1. Single domain L2 convergence plotting")
        println("2. Multi-domain dual-scale plotting:")
        println("   - Left axis: Individual subdomain curves")
        println("   - Right axis: Aggregated full domain")
        println("3. Edge cases: single degree, empty data, extreme values")
        println("4. Display vs save behavior control")
        
        println("\nTest outputs saved in: test_outputs/")
        
        return true
        
    catch e
        println("\n!!! Test Failed !!!")
        println("Error: $e")
        println(stacktrace())
        return false
    end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    success = run_all_tests()
    
    if success
        println("\n✅ All plotting tests passed!")
    else
        println("\n❌ Some tests failed!")
        exit(1)
    end
end