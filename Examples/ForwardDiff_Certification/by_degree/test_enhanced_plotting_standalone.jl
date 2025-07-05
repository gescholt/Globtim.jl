"""
Standalone test for enhanced plotting utilities.
Tests the L2 convergence dual-scale plotting without external dependencies.
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

# Mock DegreeAnalysisResult for testing (to avoid dependency on AnalysisUtilities)
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
    
    println("Plotting single domain with $(nrow(df)) data points...")
    println("  Degrees: $(df.degree)")
    println("  L2 norms: $(round.(df.l2_norm, digits=6))")
    
    # Plot single domain
    fig = plot_l2_convergence_dual_scale(
        df,
        title="Single Domain L2 Convergence Test"
    )
    
    # Save test output
    output_dir = joinpath(@__DIR__, "test_outputs", Dates.format(now(), "yyyy-mm-dd_HH-MM"))
    mkpath(output_dir)
    
    # Save with explicit flag
    fig_save = plot_l2_convergence_dual_scale(
        df,
        title="Single Domain L2 Convergence Test",
        save_plots=true,
        plots_directory=output_dir
    )
    
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
    
    subdomains = ["0000", "0001", "0010", "0011"]
    
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
    
    println("Plotting multi-domain with $(length(subdomain_results)) subdomains...")
    for (label, results) in subdomain_results
        degrees = [r.degree for r in results]
        l2_norms = [r.l2_norm for r in results]
        println("  Subdomain $label: degrees $degrees, L2 norms $(round.(l2_norms, digits=6))")
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
    
    # Save with explicit flag
    fig_save = plot_l2_convergence_dual_scale(
        subdomain_results,
        title="Multi-Domain L2 Convergence with Dual Scales",
        tolerance_line=0.0007,
        save_plots=true,
        plots_directory=output_dir
    )
    
    println("✓ Multi-domain plot created")
    println("  - Subdomains: $(join(subdomains, ", "))")
    println("  - Degrees: 2, 4, 6, 8")
    println("  - Left axis: Individual subdomain curves")
    println("  - Right axis: Aggregated full domain curve")
    println("  - Output saved to: $(output_dir)")
    
    return fig
end

# Test function 3: Interactive display test
function test_interactive_display()
    println("\n=== Testing Interactive Display ===")
    
    # Create simple test data
    df = DataFrame(
        degree = [2, 4, 6, 8],
        l2_norm = [0.01, 0.001, 0.0001, 0.00001],
        converged = [false, false, true, true]
    )
    
    println("Creating figure for interactive display...")
    fig = plot_l2_convergence_dual_scale(
        df,
        title="Interactive Display Test",
        tolerance_line=0.0005
    )
    
    println("✓ Figure created")
    println("  - Default behavior: Display in window (save_plots=false)")
    println("  - To see the plot, the figure object has been returned")
    
    return fig
end

# Main test runner
function run_all_tests()
    println("Enhanced Plotting Utilities Test Suite - Standalone")
    println("==================================================")
    
    try
        # Test single domain
        fig1 = test_single_domain_plotting()
        
        # Test multi-domain
        fig2 = test_multi_domain_plotting()
        
        # Test interactive display
        fig3 = test_interactive_display()
        
        println("\n=== All Tests Completed Successfully! ===")
        
        println("\nKey Features Tested:")
        println("1. Single domain L2 convergence plotting ✓")
        println("2. Multi-domain dual-scale plotting ✓")
        println("   - Left axis: Individual subdomain curves")
        println("   - Right axis: Aggregated full domain")
        println("3. Display vs save behavior ✓")
        println("4. Tolerance line visualization ✓")
        
        println("\nTest outputs saved in: test_outputs/")
        println("\nTo display the plots interactively, the figure objects have been returned.")
        
        return (single=fig1, multi=fig2, interactive=fig3)
        
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
    println("\n📊 Displaying the multi-domain plot...")
    display(figs.multi)
end