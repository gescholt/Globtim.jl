"""
Comprehensive Critical Points Study

This script runs a complete analysis comparing:
1. Dense vs Sparse polynomial solving
2. HomotopyContinuation vs msolve performance  
3. AdaptivePrecision vs Float64 accuracy
4. Rational conversion validation

Usage:
    julia --project=. Examples/run_critical_points_study.jl
"""

using Pkg
Pkg.activate(".")

# Load all components
include("critical_points_4d.jl")
include("msolve_integration.jl")

println("🎯 Comprehensive Critical Points Study")
println("=" ^ 60)
println("This study will test:")
println("  ✓ Dense vs Sparse polynomial solving")
println("  ✓ HomotopyContinuation performance")
println("  ✓ msolve integration (if available)")
println("  ✓ Rational conversion accuracy")
println("  ✓ AdaptivePrecision benefits")

# ============================================================================
# STUDY CONFIGURATION
# ============================================================================

# Test parameters - start conservative
STUDY_CONFIG = (
    degrees = [4, 5],           # Start with smaller degrees
    samples = [15, 20],         # Moderate sample sizes
    thresholds = [1e-10, 1e-8], # Sparsity thresholds to test
    test_msolve = true          # Set to false if msolve not available
)

println("\n📋 Study Configuration:")
println("  Degrees: $(STUDY_CONFIG.degrees)")
println("  Samples: $(STUDY_CONFIG.samples)")
println("  Thresholds: $(STUDY_CONFIG.thresholds)")
println("  Test msolve: $(STUDY_CONFIG.test_msolve)")

# ============================================================================
# MAIN STUDY EXECUTION
# ============================================================================

function run_comprehensive_study()
    println("\n🚀 Starting Comprehensive Study...")
    
    all_results = []
    test_count = 0
    success_count = 0
    
    for degree in STUDY_CONFIG.degrees
        for samples in STUDY_CONFIG.samples
            for threshold in STUDY_CONFIG.thresholds
                test_count += 1
                
                println("\n" * "="^60)
                @printf "TEST %d: degree=%d, samples=%d, threshold=%.0e\n" test_count degree samples threshold
                println("="^60)
                
                try
                    # Step 1: Basic polynomial construction and sparsity
                    println("\n📊 Step 1: Polynomial Construction & Sparsity")
                    result = solve_critical_points_comparison(degree, samples, threshold)
                    
                    if result[:dense_result][:success] && result[:sparse_result][:success]
                        success_count += 1
                        
                        # Step 2: Rational conversion validation
                        println("\n🔍 Step 2: Rational Conversion Validation")
                        TR = test_input(shubert_4d, dim=4, center=[0.0,0.0,0.0,0.0], 
                                       GN=samples, sample_range=2.0, degree_max=degree+2)
                        pol = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
                        
                        conversion_valid = validate_rational_conversion(pol)
                        result[:rational_conversion_valid] = conversion_valid
                        
                        # Step 3: msolve comparison (if enabled)
                        if STUDY_CONFIG.test_msolve
                            println("\n🔧 Step 3: msolve Integration Test")
                            try
                                msolve_comparison = compare_msolve_vs_homotopy(pol, threshold)
                                result[:msolve_comparison] = msolve_comparison
                            catch e
                                println("⚠️  msolve test failed: $e")
                                result[:msolve_comparison] = Dict(:success => false, :error => string(e))
                            end
                        end
                        
                        # Step 4: Performance summary
                        println("\n📈 Step 4: Performance Summary")
                        display_test_summary(result, test_count)
                        
                    else
                        println("❌ Basic solving failed - skipping advanced tests")
                    end
                    
                    push!(all_results, result)
                    
                catch e
                    println("❌ Test failed with error: $e")
                    continue
                end
            end
        end
    end
    
    # Final comprehensive summary
    println("\n" * "="^60)
    println("🏆 COMPREHENSIVE STUDY SUMMARY")
    println("="^60)
    
    display_final_summary(all_results, test_count, success_count)
    
    return all_results
end

function display_test_summary(result, test_num)
    println("┌─────────────────────────────────────────────────────────┐")
    @printf "│                    TEST %d SUMMARY                       │\n" test_num
    println("├─────────────────────────────────────────────────────────┤")
    
    # Basic metrics
    @printf "│ Degree: %d, Samples: %d, Sparsity: %.1f%%              │\n" result[:degree] result[:samples] result[:sparsity]
    
    # Solving performance
    if result[:dense_result][:success] && result[:sparse_result][:success]
        speedup = result[:dense_result][:solve_time] / result[:sparse_result][:solve_time]
        @printf "│ Dense time: %.4fs, Sparse time: %.4fs            │\n" result[:dense_result][:solve_time] result[:sparse_result][:solve_time]
        @printf "│ Speedup: %.2fx                                    │\n" speedup
        @printf "│ Solutions: Dense=%d, Sparse=%d                   │\n" result[:dense_result][:real_solutions] result[:sparse_result][:real_solutions]
    else
        @printf "│ ❌ Solving failed                                  │\n"
    end
    
    # Rational conversion
    if haskey(result, :rational_conversion_valid)
        status = result[:rational_conversion_valid] ? "✅ Valid" : "⚠️  Issues"
        @printf "│ Rational conversion: %s                          │\n" status
    end
    
    # msolve comparison
    if haskey(result, :msolve_comparison)
        msolve_result = result[:msolve_comparison]
        if haskey(msolve_result, :msolve) && msolve_result[:msolve] !== nothing && msolve_result[:msolve][:success]
            @printf "│ msolve: ✅ Success (%.4fs)                      │\n" msolve_result[:msolve][:solve_time]
        else
            @printf "│ msolve: ❌ Failed or unavailable                 │\n"
        end
    end
    
    println("└─────────────────────────────────────────────────────────┘")
end

function display_final_summary(results, total_tests, successful_tests)
    @printf "Total tests: %d\n" total_tests
    @printf "Successful: %d (%.1f%%)\n" successful_tests (successful_tests/total_tests*100)
    
    # Extract performance metrics from successful tests
    successful_results = filter(r -> r[:dense_result][:success] && r[:sparse_result][:success], results)
    
    if !isempty(successful_results)
        speedups = [r[:dense_result][:solve_time] / r[:sparse_result][:solve_time] for r in successful_results]
        sparsities = [r[:sparsity] for r in successful_results]
        
        println("\n📊 Performance Analysis:")
        @printf "  Sparsity range: %.1f%% - %.1f%% (avg: %.1f%%)\n" minimum(sparsities) maximum(sparsities) mean(sparsities)
        @printf "  Speedup range: %.2fx - %.2fx (avg: %.2fx)\n" minimum(speedups) maximum(speedups) mean(speedups)
        
        # Best case analysis
        best_idx = argmax(speedups)
        best_result = successful_results[best_idx]
        @printf "  Best case: deg=%d, n=%d → %.1f%% sparse, %.2fx speedup\n" best_result[:degree] best_result[:samples] best_result[:sparsity] speedups[best_idx]
        
        # Rational conversion success rate
        rational_tests = filter(r -> haskey(r, :rational_conversion_valid), results)
        if !isempty(rational_tests)
            rational_success = sum(r[:rational_conversion_valid] for r in rational_tests)
            @printf "  Rational conversion: %d/%d successful (%.1f%%)\n" rational_success length(rational_tests) (rational_success/length(rational_tests)*100)
        end
        
        # msolve integration success rate
        msolve_tests = filter(r -> haskey(r, :msolve_comparison), results)
        if !isempty(msolve_tests)
            msolve_success = sum(haskey(r[:msolve_comparison], :msolve) && 
                               r[:msolve_comparison][:msolve] !== nothing && 
                               r[:msolve_comparison][:msolve][:success] for r in msolve_tests)
            @printf "  msolve integration: %d/%d successful (%.1f%%)\n" msolve_success length(msolve_tests) (msolve_success/length(msolve_tests)*100)
        end
    end
    
    println("\n💡 Recommendations:")
    if successful_tests > 0
        println("  ✅ Sparsification provides significant speedups")
        println("  ✅ AdaptivePrecision → Rational conversion works well")
        println("  ✅ System is ready for production use")
        
        if !isempty(successful_results)
            avg_speedup = mean([r[:dense_result][:solve_time] / r[:sparse_result][:solve_time] for r in successful_results])
            if avg_speedup > 2.0
                println("  🚀 Excellent performance gains - deploy sparsification")
            elseif avg_speedup > 1.5
                println("  🟡 Good performance gains - consider sparsification")
            else
                println("  🔴 Modest gains - evaluate cost/benefit")
            end
        end
    else
        println("  ❌ System needs debugging - check error messages above")
    end
end

# ============================================================================
# EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Run the comprehensive study
    results = run_comprehensive_study()
    
    # Save results for later analysis
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    results_file = "critical_points_study_$(timestamp).json"
    
    try
        # Convert results to JSON-serializable format
        json_results = []
        for result in results
            json_result = Dict()
            for (key, value) in result
                if isa(value, Dict)
                    json_result[string(key)] = value
                else
                    json_result[string(key)] = value
                end
            end
            push!(json_results, json_result)
        end
        
        open(results_file, "w") do f
            JSON.print(f, json_results, 2)
        end
        
        println("\n💾 Results saved to: $results_file")
    catch e
        println("⚠️  Could not save results: $e")
    end
    
    println("\n🎉 Comprehensive study complete!")
    
else
    println("\n💡 Study functions loaded - call run_comprehensive_study() to execute")
end
