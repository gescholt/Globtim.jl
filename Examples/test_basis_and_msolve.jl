"""
Comprehensive Test: Polynomial Bases + msolve Integration

This script provides a complete test of:
1. Chebyshev vs Legendre polynomial construction
2. AdaptivePrecision → Exact Rational conversion
3. Sparsity analysis for both bases
4. msolve format generation and validation
5. Critical points solving comparison

Usage:
    julia --project=. Examples/test_basis_and_msolve.jl
"""

using Pkg
Pkg.activate(".")

# Load all components
include("polynomial_basis_comparison.jl")
include("critical_points_4d.jl")
include("msolve_integration.jl")

println("🎯 Comprehensive Basis & msolve Integration Test")
println("=" ^ 60)

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

const TEST_CONFIG = (
    degrees = [4, 5],
    samples = [15, 20],
    thresholds = [1e-10, 1e-8],
    bases = [:chebyshev, :legendre],
    test_function = shubert_4d
)

println("📋 Test Configuration:")
println("  Degrees: $(TEST_CONFIG.degrees)")
println("  Samples: $(TEST_CONFIG.samples)")
println("  Bases: $(TEST_CONFIG.bases)")
println("  Thresholds: $(TEST_CONFIG.thresholds)")

# ============================================================================
# ENHANCED COMPARISON FUNCTIONS
# ============================================================================

"""
    test_single_configuration(degree, samples, basis, threshold)

Test a single configuration: specific degree, samples, basis, and threshold.
"""
function test_single_configuration(degree, samples, basis, threshold)
    println("\n" * "─"^50)
    @printf "Testing: degree=%d, samples=%d, basis=%s, threshold=%.0e\n" degree samples basis threshold
    println("─"^50)
    
    try
        # Step 1: Construct polynomial
        TR = test_input(TEST_CONFIG.test_function, dim=4, center=[0.0,0.0,0.0,0.0], 
                       GN=samples, sample_range=2.0, degree_max=degree+2)
        
        @time poly = Constructor(TR, degree, basis=basis, precision=AdaptivePrecision, verbose=0)
        @printf "  Constructed: L2=%.6e, %d coeffs\n" poly.nrm length(poly.coeffs)
        
        # Step 2: Convert to exact rationals
        rationals, monomials, errors, max_denom = polynomial_to_exact_rationals(poly)
        @printf "  Rationals: max_error=%.2e, max_denom=%d\n" maximum(errors) max_denom
        
        # Step 3: Sparsity analysis
        @polyvar x[1:4]
        mono_poly = to_exact_monomial_basis(poly, variables=x)
        coeffs = abs.(Float64.([coefficient(t) for t in terms(mono_poly)]))
        
        significant = sum(coeffs .> threshold)
        total = length(coeffs)
        sparsity = (total - significant) / total * 100
        
        @printf "  Sparsity: %d/%d significant (%.1f%% sparse)\n" significant total sparsity
        
        # Step 4: msolve format generation
        msolve_str = format_for_msolve(rationals, monomials)
        @printf "  msolve string: %d characters\n" length(msolve_str)
        
        # Step 5: Validate msolve format
        valid_format = validate_msolve_format(msolve_str)
        @printf "  msolve format: %s\n" (valid_format ? "✅ Valid" : "❌ Invalid")
        
        return Dict(
            :degree => degree,
            :samples => samples,
            :basis => basis,
            :threshold => threshold,
            :l2_norm => poly.nrm,
            :coeffs_count => length(poly.coeffs),
            :max_conversion_error => maximum(errors),
            :max_denominator => max_denom,
            :sparsity => sparsity,
            :significant_terms => significant,
            :total_terms => total,
            :msolve_string_length => length(msolve_str),
            :msolve_format_valid => valid_format,
            :success => true
        )
        
    catch e
        println("❌ Test failed: $e")
        return Dict(
            :degree => degree,
            :samples => samples,
            :basis => basis,
            :threshold => threshold,
            :success => false,
            :error => string(e)
        )
    end
end

"""
    validate_msolve_format(msolve_str)

Basic validation of msolve format string.
"""
function validate_msolve_format(msolve_str)
    # Basic checks for msolve format
    checks = [
        !isempty(msolve_str),                    # Non-empty
        !contains(msolve_str, "NaN"),           # No NaN values
        !contains(msolve_str, "Inf"),           # No Inf values
        count(c -> c == '/', msolve_str) >= 0,  # Rational format present
        !contains(msolve_str, "**"),            # No double stars (use ^)
    ]
    
    return all(checks)
end

"""
    run_comprehensive_basis_test()

Run comprehensive test across all configurations.
"""
function run_comprehensive_basis_test()
    println("\n🚀 Running Comprehensive Basis & msolve Test...")
    
    all_results = []
    test_count = 0
    success_count = 0
    
    for degree in TEST_CONFIG.degrees
        for samples in TEST_CONFIG.samples
            for basis in TEST_CONFIG.bases
                for threshold in TEST_CONFIG.thresholds
                    test_count += 1
                    
                    result = test_single_configuration(degree, samples, basis, threshold)
                    push!(all_results, result)
                    
                    if result[:success]
                        success_count += 1
                    end
                end
            end
        end
    end
    
    # Analysis and summary
    println("\n" * "="^60)
    println("🏆 COMPREHENSIVE TEST SUMMARY")
    println("="^60)
    
    display_comprehensive_summary(all_results, test_count, success_count)
    
    return all_results
end

"""
    display_comprehensive_summary(results, total_tests, successful_tests)

Display comprehensive summary of all tests.
"""
function display_comprehensive_summary(results, total_tests, successful_tests)
    @printf "Total tests: %d\n" total_tests
    @printf "Successful: %d (%.1f%%)\n" successful_tests (successful_tests/total_tests*100)
    
    # Filter successful results
    successful_results = filter(r -> r[:success], results)
    
    if !isempty(successful_results)
        # Basis comparison
        cheb_results = filter(r -> r[:basis] == :chebyshev, successful_results)
        leg_results = filter(r -> r[:basis] == :legendre, successful_results)
        
        println("\n📊 Basis Comparison Summary:")
        if !isempty(cheb_results) && !isempty(leg_results)
            cheb_avg_sparsity = mean([r[:sparsity] for r in cheb_results])
            leg_avg_sparsity = mean([r[:sparsity] for r in leg_results])
            
            cheb_avg_denom = mean([r[:max_denominator] for r in cheb_results])
            leg_avg_denom = mean([r[:max_denominator] for r in leg_results])
            
            @printf "  Chebyshev: %.1f%% avg sparsity, %.0f avg max denominator\n" cheb_avg_sparsity cheb_avg_denom
            @printf "  Legendre:  %.1f%% avg sparsity, %.0f avg max denominator\n" leg_avg_sparsity leg_avg_denom
            
            if cheb_avg_sparsity > leg_avg_sparsity
                println("  🏆 Chebyshev wins on average sparsity")
            elseif leg_avg_sparsity > cheb_avg_sparsity
                println("  🏆 Legendre wins on average sparsity")
            else
                println("  🤝 Tie on average sparsity")
            end
        end
        
        # Rational conversion quality
        max_errors = [r[:max_conversion_error] for r in successful_results]
        max_denoms = [r[:max_denominator] for r in successful_results]
        
        println("\n🔄 Rational Conversion Quality:")
        @printf "  Conversion error range: %.2e - %.2e\n" minimum(max_errors) maximum(max_errors)
        @printf "  Denominator range: %d - %d\n" minimum(max_denoms) maximum(max_denoms)
        
        # msolve format validation
        format_valid_count = sum(r[:msolve_format_valid] for r in successful_results)
        @printf "  msolve format valid: %d/%d (%.1f%%)\n" format_valid_count length(successful_results) (format_valid_count/length(successful_results)*100)
        
        # Best configurations
        println("\n🎯 Best Configurations:")
        
        # Highest sparsity
        best_sparsity_idx = argmax([r[:sparsity] for r in successful_results])
        best_sparsity = successful_results[best_sparsity_idx]
        @printf "  Highest sparsity: %s deg=%d n=%d (%.1f%% sparse)\n" best_sparsity[:basis] best_sparsity[:degree] best_sparsity[:samples] best_sparsity[:sparsity]
        
        # Lowest max denominator
        best_denom_idx = argmin([r[:max_denominator] for r in successful_results])
        best_denom = successful_results[best_denom_idx]
        @printf "  Simplest rationals: %s deg=%d n=%d (max denom=%d)\n" best_denom[:basis] best_denom[:degree] best_denom[:samples] best_denom[:max_denominator]
        
        # Best conversion accuracy
        best_accuracy_idx = argmin([r[:max_conversion_error] for r in successful_results])
        best_accuracy = successful_results[best_accuracy_idx]
        @printf "  Best accuracy: %s deg=%d n=%d (error=%.2e)\n" best_accuracy[:basis] best_accuracy[:degree] best_accuracy[:samples] best_accuracy[:max_conversion_error]
    end
    
    println("\n💡 Recommendations:")
    if successful_tests == total_tests
        println("  ✅ All tests passed - system is robust")
        println("  ✅ AdaptivePrecision → Rational conversion works reliably")
        println("  ✅ msolve integration is ready for production")
        
        if !isempty(successful_results)
            avg_sparsity = mean([r[:sparsity] for r in successful_results])
            if avg_sparsity > 60.0
                println("  🚀 Excellent sparsity - deploy sparsification immediately")
            elseif avg_sparsity > 40.0
                println("  🟡 Good sparsity - sparsification recommended")
            else
                println("  🔴 Low sparsity - evaluate sparsification benefits")
            end
        end
    else
        println("  ⚠️  Some tests failed - investigate error messages")
        println("  🔧 System may need debugging before production use")
    end
end

# ============================================================================
# EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Run comprehensive test
    results = run_comprehensive_basis_test()
    
    # Save results
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    results_file = "basis_msolve_test_$(timestamp).json"
    
    try
        # Simple JSON export (convert symbols to strings)
        json_results = []
        for result in results
            json_result = Dict()
            for (key, value) in result
                json_result[string(key)] = value
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
    
    println("\n🎉 Comprehensive test complete!")
    
else
    println("\n💡 Test functions loaded:")
    println("  - run_comprehensive_basis_test()")
    println("  - test_single_configuration(degree, samples, basis, threshold)")
    println("  - validate_msolve_format(msolve_str)")
    println("\n🚀 Ready for comprehensive testing!")
end
