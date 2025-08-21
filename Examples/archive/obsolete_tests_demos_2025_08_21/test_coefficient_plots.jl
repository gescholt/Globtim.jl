"""
Test Coefficient Visualization

Quick test script to demonstrate coefficient magnitude plotting with truncation thresholds.

Usage:
    julia --project=. Examples/test_coefficient_plots.jl
"""

using Pkg
Pkg.activate(".")

# Load visualization system
include("coefficient_visualization.jl")

println("🎨 Testing Coefficient Visualization")
println("=" ^ 40)

# ============================================================================
# TEST FUNCTIONS
# ============================================================================

"""
    test_basic_visualization()

Test basic coefficient visualization functionality.
"""
function test_basic_visualization()
    println("\n🧪 Test 1: Basic Coefficient Visualization")
    println("-" ^ 40)
    
    if !plotting_available
        println("❌ Plotting not available - skipping visualization tests")
        println("   Install plotting: using Pkg; Pkg.add(\"CairoMakie\")")
        return false
    end
    
    try
        # Create a simple polynomial
        TR = test_input(shubert_4d, dim=4, center=[0.0,0.0,0.0,0.0], GN=15, 
                       sample_range=2.0, degree_max=6)
        
        poly = Constructor(TR, 4, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
        @printf "  Constructed polynomial: L2=%.6e, %d coeffs\n" poly.nrm length(poly.coeffs)
        
        # Create visualization
        println("  Creating coefficient distribution plot...")
        fig, coeff_data, threshold_data = plot_coefficient_distribution(
            poly, 
            [1e-12, 1e-10, 1e-8, 1e-6],
            title="Test Coefficient Distribution",
            save_path="test_coefficient_plot.png"
        )
        
        println("  ✅ Visualization created successfully")
        return true
        
    catch e
        println("  ❌ Visualization test failed: $e")
        return false
    end
end

"""
    test_coefficient_extraction()

Test coefficient data extraction without plotting.
"""
function test_coefficient_extraction()
    println("\n🧪 Test 2: Coefficient Data Extraction")
    println("-" ^ 40)
    
    try
        # Create polynomial
        TR = test_input(shubert_4d, dim=4, center=[0.0,0.0,0.0,0.0], GN=10, 
                       sample_range=2.0, degree_max=5)
        
        poly = Constructor(TR, 3, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
        
        # Extract coefficient data
        coeff_data = extract_coefficient_data(poly)
        
        @printf "  Total terms: %d\n" coeff_data[:total_terms]
        @printf "  Largest coefficient: %.6e\n" maximum(coeff_data[:magnitudes])
        @printf "  Smallest coefficient: %.6e\n" minimum(coeff_data[:magnitudes])
        
        # Test threshold analysis
        thresholds = [1e-10, 1e-8, 1e-6]
        threshold_data = analyze_truncation_thresholds(coeff_data[:magnitudes], thresholds)
        
        println("  Threshold analysis:")
        for data in threshold_data
            @printf "    %.0e: %d kept, %.1f%% sparse\n" data[:threshold] data[:kept] data[:sparsity]
        end
        
        println("  ✅ Coefficient extraction successful")
        return true
        
    catch e
        println("  ❌ Coefficient extraction failed: $e")
        return false
    end
end

"""
    test_sparsity_visualization()

Test sparsity-focused visualization.
"""
function test_sparsity_visualization()
    println("\n🧪 Test 3: Sparsity Visualization")
    println("-" ^ 40)
    
    if !plotting_available
        println("❌ Plotting not available - skipping test")
        return false
    end
    
    try
        # Create polynomial with known sparsity pattern
        TR = test_input(shubert_4d, dim=4, center=[0.0,0.0,0.0,0.0], GN=20, 
                       sample_range=2.0, degree_max=7)
        
        poly = Constructor(TR, 5, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
        
        # Focus on sparsity thresholds that show clear separation
        sparsity_thresholds = [1e-15, 1e-12, 1e-10, 1e-8]
        
        println("  Creating sparsity-focused plot...")
        fig, coeff_data, threshold_data = plot_coefficient_distribution(
            poly,
            sparsity_thresholds,
            title="Sparsity Analysis: Coefficient Truncation",
            save_path="sparsity_analysis_plot.png"
        )
        
        # Analyze the sparsity pattern
        magnitudes = coeff_data[:magnitudes]
        
        println("  📊 Sparsity Pattern Analysis:")
        for (i, data) in enumerate(threshold_data)
            if i == 1
                continue  # Skip first threshold for comparison
            end
            
            prev_data = threshold_data[i-1]
            additional_removed = data[:removed] - prev_data[:removed]
            
            @printf "    Between %.0e and %.0e: %d additional coefficients removed\n" prev_data[:threshold] data[:threshold] additional_removed
        end
        
        println("  ✅ Sparsity visualization successful")
        return true
        
    catch e
        println("  ❌ Sparsity visualization failed: $e")
        return false
    end
end

"""
    demonstrate_truncation_effects()

Demonstrate the visual effects of different truncation thresholds.
"""
function demonstrate_truncation_effects()
    println("\n🎯 Demonstration: Truncation Effects")
    println("-" ^ 40)
    
    # Create polynomial
    TR = test_input(shubert_4d, dim=4, center=[0.0,0.0,0.0,0.0], GN=25, 
                   sample_range=2.0, degree_max=8)
    
    poly = Constructor(TR, 6, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
    
    # Extract coefficients
    coeff_data = extract_coefficient_data(poly)
    magnitudes = coeff_data[:magnitudes]
    
    println("📊 Coefficient Statistics:")
    @printf "  Total coefficients: %d\n" length(magnitudes)
    @printf "  Dynamic range: %.2e\n" maximum(magnitudes) / minimum(magnitudes[magnitudes .> 0])
    @printf "  Largest: %.6e\n" maximum(magnitudes)
    @printf "  Smallest (non-zero): %.6e\n" minimum(magnitudes[magnitudes .> 0])
    
    # Test different truncation strategies
    println("\n🎯 Truncation Strategies:")
    
    # Conservative truncation
    conservative_threshold = 1e-12
    conservative_kept = sum(magnitudes .> conservative_threshold)
    conservative_sparsity = (length(magnitudes) - conservative_kept) / length(magnitudes) * 100
    @printf "  Conservative (%.0e): %d/%d kept (%.1f%% sparse)\n" conservative_threshold conservative_kept length(magnitudes) conservative_sparsity
    
    # Moderate truncation
    moderate_threshold = 1e-10
    moderate_kept = sum(magnitudes .> moderate_threshold)
    moderate_sparsity = (length(magnitudes) - moderate_kept) / length(magnitudes) * 100
    @printf "  Moderate    (%.0e): %d/%d kept (%.1f%% sparse)\n" moderate_threshold moderate_kept length(magnitudes) moderate_sparsity
    
    # Aggressive truncation
    aggressive_threshold = 1e-8
    aggressive_kept = sum(magnitudes .> aggressive_threshold)
    aggressive_sparsity = (length(magnitudes) - aggressive_kept) / length(magnitudes) * 100
    @printf "  Aggressive  (%.0e): %d/%d kept (%.1f%% sparse)\n" aggressive_threshold aggressive_kept length(magnitudes) aggressive_sparsity
    
    # Very aggressive truncation
    very_aggressive_threshold = 1e-6
    very_aggressive_kept = sum(magnitudes .> very_aggressive_threshold)
    very_aggressive_sparsity = (length(magnitudes) - very_aggressive_kept) / length(magnitudes) * 100
    @printf "  Very Aggr.  (%.0e): %d/%d kept (%.1f%% sparse)\n" very_aggressive_threshold very_aggressive_kept length(magnitudes) very_aggressive_sparsity
    
    println("\n💡 Recommendations:")
    if moderate_sparsity > 50.0
        println("  ✅ Moderate truncation gives >50% sparsity - good balance")
    end
    if aggressive_sparsity > 70.0
        println("  🚀 Aggressive truncation gives >70% sparsity - excellent compression")
    end
    if very_aggressive_sparsity > 80.0
        println("  ⚡ Very aggressive truncation gives >80% sparsity - maximum compression")
        println("     (verify accuracy is maintained)")
    end
    
    return coeff_data
end

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    println("🚀 Running coefficient visualization tests...")
    
    # Run tests
    test1_success = test_coefficient_extraction()
    test2_success = test_basic_visualization()
    test3_success = test_sparsity_visualization()
    
    # Demonstration
    println("\n" * "="^50)
    coeff_data = demonstrate_truncation_effects()
    
    # Summary
    println("\n" * "="^50)
    println("🏆 Test Summary:")
    @printf "  Coefficient extraction: %s\n" (test1_success ? "✅ PASS" : "❌ FAIL")
    @printf "  Basic visualization:    %s\n" (test2_success ? "✅ PASS" : "❌ FAIL")
    @printf "  Sparsity visualization: %s\n" (test3_success ? "✅ PASS" : "❌ FAIL")
    
    if test2_success || test3_success
        println("\n📁 Generated files:")
        if isfile("test_coefficient_plot.png")
            println("  - test_coefficient_plot.png")
        end
        if isfile("sparsity_analysis_plot.png")
            println("  - sparsity_analysis_plot.png")
        end
    end
    
    println("\n🎉 Coefficient visualization testing complete!")
    
else
    println("💡 Test functions loaded:")
    println("  - test_coefficient_extraction()")
    println("  - test_basic_visualization()")
    println("  - test_sparsity_visualization()")
    println("  - demonstrate_truncation_effects()")
end
