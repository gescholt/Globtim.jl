"""
AdaptivePrecision 4D Testing Framework

This framework provides infrastructure for testing AdaptivePrecision with 4D examples,
focusing on scalability, performance analysis, and comparative studies.

Key Features:
- Fast testing configurations for rapid iteration
- Comprehensive comparison between Float64Precision and AdaptivePrecision
- Scalability analysis across degrees, samples, and complexity
- Performance benchmarking and accuracy validation
- Grid optimization strategies for higher dimensions

Usage:
    include("test/adaptive_precision_4d_framework.jl")
    
    # Quick test
    results = run_4d_quick_test()
    
    # Full comparison
    comparison = run_4d_precision_comparison()
    
    # Scalability analysis
    scaling_results = run_4d_scaling_analysis()
"""

using Globtim
using DynamicPolynomials
using DataFrames
using Statistics
using LinearAlgebra

# Import Pkg at top level for installation helper
import Pkg

# Optional BenchmarkTools - use fallback timing if not available
const BENCHMARKTOOLS_AVAILABLE = try
    using BenchmarkTools
    true
catch e
    @debug "BenchmarkTools not available" exception=(e, catch_backtrace())
    false
end

if !BENCHMARKTOOLS_AVAILABLE
    println("⚠️  BenchmarkTools not available - using basic timing fallback")
    println(
        "   For better benchmarking, run: include(\"Examples/install_optional_deps.jl\")"
    )
    println("   Or manually: Pkg.add(\"BenchmarkTools\")")
    println("   Then restart Julia and reload this framework.")
else
    println("✅ BenchmarkTools available - full benchmarking features enabled")
end

"""
    install_benchmarktools()

Helper function to install BenchmarkTools if needed.
Call this function, then restart Julia and reload the framework.
"""
function install_benchmarktools()
    if !BENCHMARKTOOLS_AVAILABLE
        println("Installing BenchmarkTools...")
        Pkg.add("BenchmarkTools")
        println("✅ BenchmarkTools installed!")
        println("📋 Next steps:")
        println("   1. Restart Julia")
        println(
            "   2. Reload the framework: include(\"test/adaptive_precision_4d_framework.jl\")"
        )
        println("   3. You'll then have access to detailed benchmarking statistics")
    else
        println("✅ BenchmarkTools is already available.")
    end
end

# ============================================================================
# 4D TEST FUNCTION LIBRARY
# ============================================================================

"""
Library of 4D test functions with different characteristics for comprehensive testing.
"""

# Smooth functions
shubert_4d_smooth(x) = shubert_4d(x)  # Already defined in Globtim

function gaussian_4d(x)
    """4D Gaussian: smooth, well-behaved, good for basic testing"""
    return exp(-(x[1]^2 + x[2]^2 + x[3]^2 + x[4]^2))
end

function polynomial_4d_exact(x)
    """Exact 4D polynomial: perfect for accuracy testing"""
    return x[1]^4 + 2 * x[1]^2 * x[2]^2 + x[2]^4 + 0.5 * x[3]^3 * x[4] + x[4]^2
end

# Oscillatory functions
function trigonometric_4d(x)
    """4D trigonometric: oscillatory, challenging for approximation"""
    return sin(π * x[1]) * cos(π * x[2]) * sin(2 * π * x[3]) * cos(2 * π * x[4])
end

function mixed_frequency_4d(x)
    """Mixed frequency: multiple scales, good for sparsity testing"""
    return sin(x[1]) + 0.1 * sin(10 * x[2]) + 0.01 * sin(100 * x[3]) + cos(x[4])
end

# Sparse functions
function sparse_4d(x)
    """Sparse structure: few significant terms, ideal for truncation testing"""
    return x[1]^4 + 0.1 * x[1]^3 * x[2] + 0.01 * x[1]^2 * x[2]^2 +
           0.001 * x[1] * x[2]^3 * x[3] + x[4]^4
end

function exponential_decay_4d(x)
    """Exponential decay: natural sparsity in coefficient magnitudes"""
    return exp(-x[1]^2) + 0.1 * exp(-x[2]^2) + 0.01 * exp(-x[3]^2) + 0.001 * exp(-x[4]^2)
end

# Challenging functions
function holder_table_4d(x)
    """4D extension of Holder table: multiple local extrema"""
    return -abs(sin(x[1]) * cos(x[2]) * exp(abs(1 - sqrt(x[3]^2 + x[4]^2) / π)))
end

# Function registry
const TEST_FUNCTIONS_4D = Dict(
    :gaussian => gaussian_4d,
    :polynomial_exact => polynomial_4d_exact,
    :shubert => shubert_4d_smooth,
    :trigonometric => trigonometric_4d,
    :mixed_frequency => mixed_frequency_4d,
    :sparse => sparse_4d,
    :exponential_decay => exponential_decay_4d,
    :holder_table => holder_table_4d
)

# ============================================================================
# FAST TESTING CONFIGURATIONS
# ============================================================================

"""
Configuration sets for different testing scenarios.
"""

# Quick testing: minimal resources for rapid iteration
const QUICK_CONFIG = (
    degrees = [2, 4],
    samples = [10, 20],
    center = [0.0, 0.0, 0.0, 0.0],
    sample_range = 1.0,
    functions = [:gaussian, :polynomial_exact]
)

# Standard testing: balanced resource usage
const STANDARD_CONFIG = (
    degrees = [4, 6, 8],
    samples = [20, 50, 100],
    center = [0.0, 0.0, 0.0, 0.0],
    sample_range = 1.0,
    functions = [:gaussian, :polynomial_exact, :shubert, :sparse]
)

# Comprehensive testing: full analysis
const COMPREHENSIVE_CONFIG = (
    degrees = [4, 6, 8, 10, 12],
    samples = [50, 100, 200, 500],
    center = [0.0, 0.0, 0.0, 0.0],
    sample_range = 1.0,
    functions = keys(TEST_FUNCTIONS_4D)
)

# ============================================================================
# BASIC ADAPTIVE PRECISION INTEGRATION
# ============================================================================

"""
    create_4d_test_input(func_name, config; kwargs...)

Create a test_input for 4D function testing with specified configuration.
"""
function create_4d_test_input(func_name::Symbol, config;
    samples = config.samples[1],
    kwargs...)
    func = TEST_FUNCTIONS_4D[func_name]
    return test_input(
        func,
        dim = 4,
        center = config.center,
        sample_range = config.sample_range,
        GN = samples,
        tolerance = nothing;
        kwargs...
    )
end

"""
    construct_4d_polynomial(TR, degree, precision_type; kwargs...)

Construct 4D polynomial with specified precision type.
"""
function construct_4d_polynomial(TR, degree, precision_type; kwargs...)
    return Constructor(TR, degree, precision = precision_type, verbose = 0; kwargs...)
end

"""
    compare_4d_precisions(func_name, degree, samples; config=QUICK_CONFIG)

Compare Float64Precision vs AdaptivePrecision for a single 4D test case.
"""
function compare_4d_precisions(func_name::Symbol, degree::Int, samples::Int;
    config = QUICK_CONFIG)
    # Create test input
    TR = create_4d_test_input(func_name, config, samples = samples)

    # Construct polynomials with different precisions
    println("Testing $func_name (degree=$degree, samples=$samples)")

    # Float64 precision
    time_float64 =
        @elapsed pol_float64 = construct_4d_polynomial(TR, degree, Float64Precision)

    # Adaptive precision  
    time_adaptive =
        @elapsed pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)

    # Basic comparison
    results = Dict(
        :function => func_name,
        :degree => degree,
        :samples => samples,
        :float64_time => time_float64,
        :adaptive_time => time_adaptive,
        :float64_coeffs => length(pol_float64.coeffs),
        :adaptive_coeffs => length(pol_adaptive.coeffs),
        :float64_norm => pol_float64.nrm,
        :adaptive_norm => pol_adaptive.nrm,
        :precision_overhead => time_adaptive / time_float64
    )

    return results, pol_float64, pol_adaptive
end

# ============================================================================
# QUICK TESTING FUNCTIONS
# ============================================================================

"""
    run_4d_quick_test()

Run a quick 4D test to verify AdaptivePrecision is working correctly.
"""
function run_4d_quick_test()
    println("🚀 Running 4D AdaptivePrecision Quick Test")
    println("="^50)

    results = []

    for func_name in QUICK_CONFIG.functions
        for degree in QUICK_CONFIG.degrees
            for samples in QUICK_CONFIG.samples
                try
                    result, pol_f64, pol_adaptive =
                        compare_4d_precisions(func_name, degree, samples)
                    push!(results, result)

                    println("✓ $func_name: degree=$degree, samples=$samples")
                    println("  Float64 time: $(round(result[:float64_time], digits=3))s")
                    println("  Adaptive time: $(round(result[:adaptive_time], digits=3))s")
                    println("  Overhead: $(round(result[:precision_overhead], digits=2))x")
                    println(
                        "  Norms: F64=$(round(result[:float64_norm], digits=6)), Adaptive=$(round(result[:adaptive_norm], digits=6))"
                    )
                    println()

                catch e
                    println(
                        "❌ Error with $func_name (degree=$degree, samples=$samples): $e"
                    )
                end
            end
        end
    end

    println("🎉 Quick test completed! $(length(results)) test cases run.")
    return results
end

"""
    run_4d_precision_comparison(config=STANDARD_CONFIG)

Run comprehensive comparison between precision types.
"""
function run_4d_precision_comparison(config = STANDARD_CONFIG)
    println("📊 Running 4D Precision Comparison Analysis")
    println("="^50)

    results = []

    for func_name in config.functions
        println("\n🔍 Testing function: $func_name")

        for degree in config.degrees
            for samples in config.samples
                try
                    result, pol_f64, pol_adaptive =
                        compare_4d_precisions(func_name, degree, samples, config = config)

                    # Extended analysis
                    @polyvar x[1:4]

                    # Convert to monomial basis for detailed analysis
                    mono_f64 = to_exact_monomial_basis(pol_f64, variables = x)
                    mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables = x)

                    # Coefficient analysis
                    coeffs_f64 = [coefficient(t) for t in terms(mono_f64)]
                    coeffs_adaptive = [coefficient(t) for t in terms(mono_adaptive)]

                    # Extended results
                    result[:mono_terms_f64] = length(coeffs_f64)
                    result[:mono_terms_adaptive] = length(coeffs_adaptive)
                    result[:coeff_type_f64] = typeof(coeffs_f64[1])
                    result[:coeff_type_adaptive] = typeof(coeffs_adaptive[1])

                    if length(coeffs_adaptive) > 0
                        coeff_mags_adaptive = [abs(Float64(c)) for c in coeffs_adaptive]
                        result[:coeff_range_adaptive] =
                            maximum(coeff_mags_adaptive) /
                            minimum(coeff_mags_adaptive[coeff_mags_adaptive .> 1e-15])
                    end

                    push!(results, result)

                    println(
                        "  ✓ degree=$degree, samples=$samples: overhead=$(round(result[:precision_overhead], digits=2))x"
                    )

                catch e
                    println("  ❌ Error with degree=$degree, samples=$samples: $e")
                end
            end
        end
    end

    println("\n🎉 Precision comparison completed! $(length(results)) test cases analyzed.")
    return DataFrame(results)
end

# ============================================================================
# SCALABILITY ANALYSIS
# ============================================================================

"""
    run_4d_scaling_analysis(func_name=:gaussian; max_degree=10, max_samples=200)

Analyze how AdaptivePrecision scales with increasing degree and sample size.
"""
function run_4d_scaling_analysis(func_name = :gaussian; max_degree = 10, max_samples = 200)
    println("📈 Running 4D Scalability Analysis for $func_name")
    println("="^50)

    results = []

    # Degree scaling (fixed samples)
    println("\n🔍 Degree Scaling Analysis (samples=50)")
    for degree in 2:2:max_degree
        try
            TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = 50)

            # Benchmark both precisions
            time_f64 =
                @elapsed pol_f64 = construct_4d_polynomial(TR, degree, Float64Precision)
            time_adaptive = @elapsed pol_adaptive =
                construct_4d_polynomial(TR, degree, AdaptivePrecision)

            result = Dict(
                :analysis_type => "degree_scaling",
                :function => func_name,
                :degree => degree,
                :samples => 50,
                :float64_time => time_f64,
                :adaptive_time => time_adaptive,
                :overhead => time_adaptive / time_f64,
                :float64_norm => pol_f64.nrm,
                :adaptive_norm => pol_adaptive.nrm
            )

            push!(results, result)
            println(
                "  Degree $degree: overhead=$(round(result[:overhead], digits=2))x, norms=($(round(pol_f64.nrm, digits=4)), $(round(pol_adaptive.nrm, digits=4)))"
            )

        catch e
            println("  ❌ Error at degree $degree: $e")
        end
    end

    # Sample scaling (fixed degree)
    println("\n🔍 Sample Scaling Analysis (degree=6)")
    for samples in [20, 50, 100, 200]
        if samples <= max_samples
            try
                TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)

                time_f64 =
                    @elapsed pol_f64 = construct_4d_polynomial(TR, 6, Float64Precision)
                time_adaptive = @elapsed pol_adaptive =
                    construct_4d_polynomial(TR, 6, AdaptivePrecision)

                result = Dict(
                    :analysis_type => "sample_scaling",
                    :function => func_name,
                    :degree => 6,
                    :samples => samples,
                    :float64_time => time_f64,
                    :adaptive_time => time_adaptive,
                    :overhead => time_adaptive / time_f64,
                    :float64_norm => pol_f64.nrm,
                    :adaptive_norm => pol_adaptive.nrm
                )

                push!(results, result)
                println(
                    "  Samples $samples: overhead=$(round(result[:overhead], digits=2))x, times=($(round(time_f64, digits=3))s, $(round(time_adaptive, digits=3))s)"
                )

            catch e
                println("  ❌ Error at samples $samples: $e")
            end
        end
    end

    println("\n🎉 Scalability analysis completed!")
    return DataFrame(results)
end

"""
    analyze_4d_sparsity(func_name=:sparse; degree=8, samples=100)

Analyze sparsity characteristics of AdaptivePrecision vs Float64Precision.
"""
function analyze_4d_sparsity(func_name = :sparse; degree = 8, samples = 100)
    println("✂️  Running 4D Sparsity Analysis for $func_name")
    println("="^50)

    TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)

    # Construct polynomials
    pol_f64 = construct_4d_polynomial(TR, degree, Float64Precision)
    pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)

    @polyvar x[1:4]

    # Convert to monomial basis
    mono_f64 = to_exact_monomial_basis(pol_f64, variables = x)
    mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables = x)

    # Analyze coefficients
    coeffs_f64 = [coefficient(t) for t in terms(mono_f64)]
    coeffs_adaptive = [coefficient(t) for t in terms(mono_adaptive)]

    println("📊 Coefficient Analysis:")
    println("  Float64 terms: $(length(coeffs_f64))")
    println("  AdaptivePrecision terms: $(length(coeffs_adaptive))")
    println("  Float64 coeff type: $(typeof(coeffs_f64[1]))")
    println("  AdaptivePrecision coeff type: $(typeof(coeffs_adaptive[1]))")

    # Sparsity analysis for AdaptivePrecision
    if length(coeffs_adaptive) > 0
        analysis = analyze_coefficient_distribution(mono_adaptive)
        println("\n📈 AdaptivePrecision Coefficient Distribution:")
        println("  Total terms: $(analysis.n_total)")
        println("  Dynamic range: $(analysis.dynamic_range)")
        println("  Max coefficient: $(analysis.max_coefficient)")
        println("  Min coefficient: $(analysis.min_coefficient)")

        # Test truncation
        thresholds = [1e-15, 1e-12, 1e-10, 1e-8]
        println("\n✂️  Truncation Analysis:")
        for threshold in thresholds
            truncated_poly, stats = truncate_polynomial_adaptive(mono_adaptive, threshold)
            println(
                "  Threshold $(threshold): keep $(stats.n_kept)/$(stats.n_total) ($(round(stats.sparsity_ratio*100, digits=1))% sparse)"
            )
        end

        return analysis, mono_f64, mono_adaptive
    else
        println("⚠️  No coefficients found for analysis")
        return nothing, mono_f64, mono_adaptive
    end
end

"""
    compare_critical_point_accuracy(func_name=:shubert; degree=8, samples=100)

Compare critical point detection accuracy between Float64Precision and AdaptivePrecision.
"""
function compare_critical_point_accuracy(func_name = :shubert; degree = 8, samples = 100)
    println("🎯 Critical Point Detection Accuracy Comparison for $func_name")
    println("="^60)

    TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)

    # Construct polynomials with both precisions
    println("📊 Constructing polynomials...")
    pol_f64 = construct_4d_polynomial(TR, degree, Float64Precision)
    pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)

    @polyvar x[1:4]

    # Convert to monomial basis
    println("🔄 Converting to monomial basis...")
    mono_f64 = to_exact_monomial_basis(pol_f64, variables = x)
    mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables = x)

    # Analyze polynomial accuracy
    results = Dict(
        :function => func_name,
        :degree => degree,
        :samples => samples,
        :f64_terms => length([coefficient(t) for t in terms(mono_f64)]),
        :adaptive_terms => length([coefficient(t) for t in terms(mono_adaptive)]),
        :f64_norm => pol_f64.nrm,
        :adaptive_norm => pol_adaptive.nrm,
        :norm_difference => abs(pol_adaptive.nrm - pol_f64.nrm)
    )

    # Test polynomial evaluation accuracy at random test points
    println("🔍 Testing evaluation accuracy at test points...")

    f_func = TEST_FUNCTIONS_4D[func_name]
    max_error_f64 = 0.0
    max_error_adaptive = 0.0
    n_test_points = 5

    for i in 1:n_test_points
        # Generate random test point in the sampling range
        test_point = [2.0 * rand() - 1.0 for _ in 1:4]  # Random point in [-1, 1]^4

        # Expected value
        expected = f_func(test_point)

        # Polynomial evaluations
        try
            poly_f64_val = substitute(mono_f64, x, test_point)
            poly_adaptive_val = substitute(mono_adaptive, x, test_point)

            error_f64 = abs(Float64(poly_f64_val) - expected)
            error_adaptive = abs(Float64(poly_adaptive_val) - expected)

            max_error_f64 = max(max_error_f64, error_f64)
            max_error_adaptive = max(max_error_adaptive, error_adaptive)
        catch e
            println("  ⚠️  Evaluation error at test point: $e")
        end
    end

    results[:max_eval_error_f64] = max_error_f64
    results[:max_eval_error_adaptive] = max_error_adaptive
    results[:accuracy_improvement] =
        max_error_f64 > 0 ? max_error_f64 / max_error_adaptive : 1.0

    println("📈 Critical Point Accuracy Results:")
    println("  Float64Precision L2 norm: $(results[:f64_norm])")
    println("  AdaptivePrecision L2 norm: $(results[:adaptive_norm])")
    println("  Norm difference: $(results[:norm_difference])")
    println("  Max evaluation error (F64): $(max_error_f64)")
    println("  Max evaluation error (Adaptive): $(max_error_adaptive)")

    if max_error_adaptive < max_error_f64 && max_error_f64 > 1e-15
        improvement = max_error_f64 / max_error_adaptive
        println(
            "  ✅ AdaptivePrecision improvement: $(round(improvement, digits=2))x more accurate"
        )
    elseif max_error_adaptive > max_error_f64 && max_error_adaptive > 1e-15
        degradation = max_error_adaptive / max_error_f64
        println(
            "  ⚠️  AdaptivePrecision $(round(degradation, digits=2))x less accurate in this test"
        )
    else
        println("  ➡️  Similar accuracy between precision types")
    end

    return results, mono_f64, mono_adaptive
end

"""
    optimize_4d_accuracy(func_name=:shubert; max_degree=12, max_samples=500)

Find optimal parameters for maximum accuracy with 4D AdaptivePrecision.
"""
function optimize_4d_accuracy(func_name = :shubert; max_degree = 12, max_samples = 500)
    println("🎯 Accuracy Optimization for $func_name")
    println("="^50)

    # Parameter ranges to test
    degrees =
        [4, 6, 8, 10, 12][1:(findfirst(x -> x > max_degree, [4, 6, 8, 10, 12, 14]) - 1)]
    sample_sizes = [50, 100, 200, 300, 500][1:(findfirst(
        x -> x > max_samples,
        [50, 100, 200, 300, 500, 1000]
    ) - 1)]

    println("📊 Testing degrees: $degrees")
    println("📊 Testing sample sizes: $sample_sizes")

    results = []
    best_accuracy = Inf
    best_config = nothing

    for degree in degrees
        for samples in sample_sizes
            println("\n🔍 Testing degree=$degree, samples=$samples")

            try
                # Test both precision types
                result_f64, _, _ = compare_4d_precisions(func_name, degree, samples)

                # Focus on AdaptivePrecision accuracy
                adaptive_norm = result_f64[:adaptive_norm]

                config_result = Dict(
                    :degree => degree,
                    :samples => samples,
                    :adaptive_norm => adaptive_norm,
                    :float64_norm => result_f64[:float64_norm],
                    :precision_overhead => result_f64[:precision_overhead],
                    :adaptive_coeffs => result_f64[:adaptive_coeffs]
                )

                push!(results, config_result)

                # Track best accuracy (lowest L2 norm)
                if adaptive_norm < best_accuracy
                    best_accuracy = adaptive_norm
                    best_config = (degree = degree, samples = samples)
                end

                println("  L2 norm: $(round(adaptive_norm, digits=8))")
                println("  Overhead: $(round(result_f64[:precision_overhead], digits=3))x")

            catch e
                println("  ❌ Failed: $e")
            end
        end
    end

    println("\n🏆 Accuracy Optimization Results:")
    println("  Best accuracy: $(round(best_accuracy, digits=8))")
    println(
        "  Best configuration: degree=$(best_config.degree), samples=$(best_config.samples)"
    )

    # Find Pareto-optimal configurations (best accuracy for each performance level)
    sorted_results = sort(results, by = x -> x[:precision_overhead])
    pareto_configs = []
    best_norm_so_far = Inf

    for result in sorted_results
        if result[:adaptive_norm] < best_norm_so_far
            push!(pareto_configs, result)
            best_norm_so_far = result[:adaptive_norm]
        end
    end

    println("\n📈 Pareto-Optimal Configurations:")
    for (i, config) in enumerate(pareto_configs)
        println("  $i. Degree=$(config[:degree]), Samples=$(config[:samples])")
        println("     L2 norm: $(round(config[:adaptive_norm], digits=8))")
        println("     Overhead: $(round(config[:precision_overhead], digits=3))x")
    end

    return DataFrame(results), best_config, pareto_configs
end

"""
    profile_4d_bottlenecks(func_name=:shubert; degree=8, samples=200, iterations=10)

Identify performance bottlenecks in AdaptivePrecision 4D construction.
"""
function profile_4d_bottlenecks(
    func_name = :shubert;
    degree = 8,
    samples = 200,
    iterations = 10
)
    println("🔬 Performance Bottleneck Analysis for $func_name")
    println("="^60)

    TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)

    # Profile different phases
    phases = Dict(
        "Test Input Creation" =>
            () -> create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples),
        "Float64 Construction" =>
            () -> construct_4d_polynomial(TR, degree, Float64Precision),
        "Adaptive Construction" =>
            () -> construct_4d_polynomial(TR, degree, AdaptivePrecision),
        "Monomial Conversion (F64)" =>
            () -> begin
                pol = construct_4d_polynomial(TR, degree, Float64Precision)
                @polyvar x[1:4]
                to_exact_monomial_basis(pol, variables = x)
            end,
        "Monomial Conversion (Adaptive)" =>
            () -> begin
                pol = construct_4d_polynomial(TR, degree, AdaptivePrecision)
                @polyvar x[1:4]
                to_exact_monomial_basis(pol, variables = x)
            end
    )

    bottleneck_results = Dict()

    for (phase_name, phase_func) in phases
        println("\n🔍 Profiling: $phase_name")

        # Warm up
        try
            phase_func()
        catch e
            println("  ⚠️  Warmup failed: $e")
            continue
        end

        # Time multiple iterations
        times = Float64[]
        for i in 1:iterations
            try
                time_taken = @elapsed phase_func()
                push!(times, time_taken)
            catch e
                println("  ⚠️  Iteration $i failed: $e")
            end
        end

        if !isempty(times)
            mean_time = mean(times)
            std_time = std(times)
            min_time = minimum(times)
            max_time = maximum(times)

            bottleneck_results[phase_name] = Dict(
                :mean => mean_time,
                :std => std_time,
                :min => min_time,
                :max => max_time,
                :samples => length(times)
            )

            println(
                "  Mean time: $(round(mean_time, digits=4))s ± $(round(std_time, digits=4))s"
            )
            println(
                "  Range: $(round(min_time, digits=4))s - $(round(max_time, digits=4))s"
            )
        else
            println("  ❌ No successful iterations")
        end
    end

    # Identify bottlenecks
    println("\n🎯 Bottleneck Analysis:")
    if !isempty(bottleneck_results)
        sorted_phases = sort(collect(bottleneck_results), by = x -> x[2][:mean], rev = true)

        total_time = sum(result[:mean] for (_, result) in bottleneck_results)

        for (i, (phase, result)) in enumerate(sorted_phases)
            percentage = (result[:mean] / total_time) * 100
            println(
                "  $i. $phase: $(round(result[:mean], digits=4))s ($(round(percentage, digits=1))%)"
            )
        end

        # Identify the main bottleneck
        if length(sorted_phases) > 0
            main_bottleneck = sorted_phases[1][1]
            println("\n🚨 Main bottleneck: $main_bottleneck")

            # Provide optimization suggestions
            if contains(main_bottleneck, "Adaptive Construction")
                println("💡 Optimization suggestions:")
                println("  - Consider reducing polynomial degree")
                println("  - Optimize BigFloat operations in coefficient computation")
                println("  - Profile internal AdaptivePrecision implementation")
            elseif contains(main_bottleneck, "Monomial Conversion")
                println("💡 Optimization suggestions:")
                println("  - Cache basis conversion matrices")
                println("  - Optimize polynomial term iteration")
                println("  - Consider sparse representation")
            end
        end
    end

    return bottleneck_results
end

"""
    optimize_4d_parameters(func_name=:shubert; target_accuracy=1e-6, max_time=60.0)

Find optimal degree/sample combinations for best accuracy/performance trade-off.
"""
function optimize_4d_parameters(
    func_name = :shubert;
    target_accuracy = 1e-6,
    max_time = 60.0
)
    println("⚖️  Parameter Optimization for $func_name")
    println("="^50)
    println("Target accuracy (L2 norm): $target_accuracy")
    println("Max time budget: $(max_time)s")

    # Parameter search space
    degrees = [4, 6, 8, 10, 12]
    sample_sizes = [50, 100, 200, 300, 500]

    results = []
    feasible_configs = []

    for degree in degrees
        for samples in sample_sizes
            println("\n🔍 Testing degree=$degree, samples=$samples")

            try
                # Time the construction
                start_time = time()
                result, _, _ = compare_4d_precisions(func_name, degree, samples)
                elapsed_time = time() - start_time

                config_result = Dict(
                    :degree => degree,
                    :samples => samples,
                    :adaptive_norm => result[:adaptive_norm],
                    :float64_norm => result[:float64_norm],
                    :precision_overhead => result[:precision_overhead],
                    :construction_time => elapsed_time,
                    :adaptive_coeffs => result[:adaptive_coeffs],
                    :meets_accuracy => result[:adaptive_norm] <= target_accuracy,
                    :meets_time => elapsed_time <= max_time,
                    :feasible =>
                        (result[:adaptive_norm] <= target_accuracy) &&
                        (elapsed_time <= max_time)
                )

                push!(results, config_result)

                if config_result[:feasible]
                    push!(feasible_configs, config_result)
                end

                println(
                    "  L2 norm: $(round(result[:adaptive_norm], digits=8)) $(result[:adaptive_norm] <= target_accuracy ? "✅" : "❌")"
                )
                println(
                    "  Time: $(round(elapsed_time, digits=3))s $(elapsed_time <= max_time ? "✅" : "❌")"
                )
                println("  Feasible: $(config_result[:feasible] ? "✅" : "❌")")

            catch e
                println("  ❌ Failed: $e")
            end
        end
    end

    println("\n🎯 Parameter Optimization Results:")

    if !isempty(feasible_configs)
        # Find Pareto-optimal configurations
        println("📊 Feasible configurations: $(length(feasible_configs))")

        # Sort by accuracy (best first)
        sorted_by_accuracy = sort(feasible_configs, by = x -> x[:adaptive_norm])
        best_accuracy_config = sorted_by_accuracy[1]

        # Sort by speed (fastest first)
        sorted_by_speed = sort(feasible_configs, by = x -> x[:construction_time])
        fastest_config = sorted_by_speed[1]

        # Find balanced configuration (minimize weighted combination)
        # Normalize accuracy and time to [0,1] range
        min_norm = minimum(c[:adaptive_norm] for c in feasible_configs)
        max_norm = maximum(c[:adaptive_norm] for c in feasible_configs)
        min_time = minimum(c[:construction_time] for c in feasible_configs)
        max_time_actual = maximum(c[:construction_time] for c in feasible_configs)

        balanced_scores = []
        for config in feasible_configs
            norm_score = (config[:adaptive_norm] - min_norm) / (max_norm - min_norm + 1e-10)
            time_score =
                (config[:construction_time] - min_time) /
                (max_time_actual - min_time + 1e-10)
            balanced_score = 0.6 * norm_score + 0.4 * time_score  # Weight accuracy more
            push!(balanced_scores, (config, balanced_score))
        end

        balanced_config = sort(balanced_scores, by = x -> x[2])[1][1]

        println("\n🏆 Recommended Configurations:")
        println("1. Best Accuracy:")
        println(
            "   Degree=$(best_accuracy_config[:degree]), Samples=$(best_accuracy_config[:samples])"
        )
        println("   L2 norm: $(round(best_accuracy_config[:adaptive_norm], digits=8))")
        println("   Time: $(round(best_accuracy_config[:construction_time], digits=3))s")

        println("\n2. Fastest:")
        println("   Degree=$(fastest_config[:degree]), Samples=$(fastest_config[:samples])")
        println("   L2 norm: $(round(fastest_config[:adaptive_norm], digits=8))")
        println("   Time: $(round(fastest_config[:construction_time], digits=3))s")

        println("\n3. Balanced (Recommended):")
        println(
            "   Degree=$(balanced_config[:degree]), Samples=$(balanced_config[:samples])"
        )
        println("   L2 norm: $(round(balanced_config[:adaptive_norm], digits=8))")
        println("   Time: $(round(balanced_config[:construction_time], digits=3))s")

        return DataFrame(results), best_accuracy_config, fastest_config, balanced_config

    else
        println("❌ No feasible configurations found!")
        println("💡 Suggestions:")
        println("  - Increase target_accuracy threshold")
        println("  - Increase max_time budget")
        println("  - Consider smaller degree/sample combinations")

        return DataFrame(results), nothing, nothing, nothing
    end
end

"""
    optimize_sparsity_thresholds(func_name=:sparse; degree=8, samples=200, max_accuracy_loss=0.01)

Find optimal coefficient truncation thresholds for maximum sparsity with minimal accuracy loss.
"""
function optimize_sparsity_thresholds(
    func_name = :sparse;
    degree = 8,
    samples = 200,
    max_accuracy_loss = 0.01
)
    println("✂️  Sparsity Threshold Optimization for $func_name")
    println("="^60)
    println("Max accuracy loss: $(max_accuracy_loss*100)%")

    # Create polynomial with AdaptivePrecision
    TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)
    pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)

    @polyvar x[1:4]
    mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables = x)

    # Analyze coefficient distribution
    analysis = analyze_coefficient_distribution(mono_adaptive)
    original_norm = pol_adaptive.nrm

    println("📊 Original polynomial:")
    println("  Terms: $(analysis.n_total)")
    println("  L2 norm: $(round(original_norm, digits=8))")
    println("  Dynamic range: $(round(analysis.dynamic_range, digits=2))")

    # Test different threshold strategies
    threshold_strategies = [
        ("Absolute", [1e-16, 1e-14, 1e-12, 1e-10, 1e-8, 1e-6]),
        ("Relative", [1e-16, 1e-14, 1e-12, 1e-10, 1e-8, 1e-6]),
        ("Percentile", [0.1, 0.5, 1.0, 2.0, 5.0, 10.0])
    ]

    results = []
    optimal_configs = []

    for (strategy_name, thresholds) in threshold_strategies
        println("\n🔍 Testing $strategy_name thresholds...")

        for threshold in thresholds
            try
                if strategy_name == "Percentile"
                    # Convert percentile to actual threshold
                    coeffs = [abs(coefficient(t)) for t in terms(mono_adaptive)]
                    sorted_coeffs = sort(coeffs)
                    percentile_idx =
                        max(1, round(Int, length(sorted_coeffs) * threshold / 100))
                    actual_threshold = sorted_coeffs[percentile_idx]
                else
                    actual_threshold = threshold
                end

                # Apply truncation
                truncated_poly, stats =
                    truncate_polynomial_adaptive(mono_adaptive, actual_threshold)

                # Estimate accuracy loss (approximate)
                sparsity_ratio = stats.sparsity_ratio
                accuracy_loss = stats.largest_removed / analysis.max_coefficient

                config_result = Dict(
                    :strategy => strategy_name,
                    :threshold => threshold,
                    :actual_threshold => actual_threshold,
                    :original_terms => stats.n_total,
                    :kept_terms => stats.n_kept,
                    :sparsity_ratio => sparsity_ratio,
                    :accuracy_loss_estimate => accuracy_loss,
                    :largest_removed => stats.largest_removed,
                    :smallest_kept => stats.smallest_kept,
                    :meets_accuracy_constraint => accuracy_loss <= max_accuracy_loss
                )

                push!(results, config_result)

                if config_result[:meets_accuracy_constraint]
                    push!(optimal_configs, config_result)
                end

                println(
                    "  Threshold $threshold: $(round(sparsity_ratio*100, digits=1))% sparse, est. loss $(round(accuracy_loss*100, digits=3))% $(accuracy_loss <= max_accuracy_loss ? "✅" : "❌")"
                )

            catch e
                println("  ❌ Threshold $threshold failed: $e")
            end
        end
    end

    println("\n🎯 Sparsity Optimization Results:")

    if !isempty(optimal_configs)
        # Find configuration with maximum sparsity within accuracy constraint
        best_sparsity_config =
            sort(optimal_configs, by = x -> x[:sparsity_ratio], rev = true)[1]

        # Find most conservative configuration (minimum accuracy loss)
        most_conservative_config =
            sort(optimal_configs, by = x -> x[:accuracy_loss_estimate])[1]

        println("📊 Feasible configurations: $(length(optimal_configs))")

        println("\n🏆 Recommended Configurations:")
        println("1. Maximum Sparsity:")
        println("   Strategy: $(best_sparsity_config[:strategy])")
        println("   Threshold: $(best_sparsity_config[:threshold])")
        println(
            "   Sparsity: $(round(best_sparsity_config[:sparsity_ratio]*100, digits=1))%"
        )
        println(
            "   Est. accuracy loss: $(round(best_sparsity_config[:accuracy_loss_estimate]*100, digits=3))%"
        )
        println(
            "   Terms: $(best_sparsity_config[:kept_terms])/$(best_sparsity_config[:original_terms])"
        )

        println("\n2. Most Conservative:")
        println("   Strategy: $(most_conservative_config[:strategy])")
        println("   Threshold: $(most_conservative_config[:threshold])")
        println(
            "   Sparsity: $(round(most_conservative_config[:sparsity_ratio]*100, digits=1))%"
        )
        println(
            "   Est. accuracy loss: $(round(most_conservative_config[:accuracy_loss_estimate]*100, digits=3))%"
        )
        println(
            "   Terms: $(most_conservative_config[:kept_terms])/$(most_conservative_config[:original_terms])"
        )

        # Pareto frontier analysis
        pareto_configs = []
        sorted_by_sparsity = sort(optimal_configs, by = x -> x[:sparsity_ratio], rev = true)
        min_accuracy_loss = Inf

        for config in sorted_by_sparsity
            if config[:accuracy_loss_estimate] < min_accuracy_loss
                push!(pareto_configs, config)
                min_accuracy_loss = config[:accuracy_loss_estimate]
            end
        end

        println("\n📈 Pareto-Optimal Configurations: $(length(pareto_configs))")
        for (i, config) in enumerate(pareto_configs[1:min(3, end)])
            println(
                "  $i. $(config[:strategy]) $(config[:threshold]): $(round(config[:sparsity_ratio]*100, digits=1))% sparse, $(round(config[:accuracy_loss_estimate]*100, digits=3))% loss"
            )
        end

        return DataFrame(results),
        best_sparsity_config,
        most_conservative_config,
        pareto_configs

    else
        println("❌ No configurations meet the accuracy constraint!")
        println("💡 Suggestions:")
        println("  - Increase max_accuracy_loss threshold")
        println("  - Use smaller truncation thresholds")
        println("  - Consider different sparsity strategies")

        return DataFrame(results), nothing, nothing, []
    end
end

# ============================================================================
# SCALABILITY TESTING
# ============================================================================

"""
    analyze_degree_scaling(func_name=:shubert; degrees=[4,6,8,10,12], samples=200)

Analyze how AdaptivePrecision performance scales with polynomial degree.
"""
function analyze_degree_scaling(
    func_name = :shubert;
    degrees = [4, 6, 8, 10, 12],
    samples = 200
)
    println("📈 Degree Scaling Analysis for $func_name")
    println("="^50)
    println("Testing degrees: $degrees")
    println("Fixed samples: $samples")

    TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)

    results = []

    for degree in degrees
        println("\n🔍 Testing degree $degree...")

        try
            # Time both precision types
            start_time = time()
            pol_f64 = construct_4d_polynomial(TR, degree, Float64Precision)
            f64_time = time() - start_time

            start_time = time()
            pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)
            adaptive_time = time() - start_time

            # Monomial conversion timing
            @polyvar x[1:4]

            start_time = time()
            mono_f64 = to_exact_monomial_basis(pol_f64, variables = x)
            f64_conversion_time = time() - start_time

            start_time = time()
            mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables = x)
            adaptive_conversion_time = time() - start_time

            # Coefficient analysis
            f64_coeffs = [coefficient(t) for t in terms(mono_f64)]
            adaptive_coeffs = [coefficient(t) for t in terms(mono_adaptive)]

            result = Dict(
                :degree => degree,
                :samples => samples,
                :f64_construction_time => f64_time,
                :adaptive_construction_time => adaptive_time,
                :construction_overhead => adaptive_time / f64_time,
                :f64_conversion_time => f64_conversion_time,
                :adaptive_conversion_time => adaptive_conversion_time,
                :conversion_overhead => adaptive_conversion_time / f64_conversion_time,
                :total_f64_time => f64_time + f64_conversion_time,
                :total_adaptive_time => adaptive_time + adaptive_conversion_time,
                :total_overhead =>
                    (adaptive_time + adaptive_conversion_time) /
                    (f64_time + f64_conversion_time),
                :f64_terms => length(f64_coeffs),
                :adaptive_terms => length(adaptive_coeffs),
                :f64_norm => pol_f64.nrm,
                :adaptive_norm => pol_adaptive.nrm,
                :norm_difference => abs(pol_adaptive.nrm - pol_f64.nrm)
            )

            push!(results, result)

            println(
                "  Construction: $(round(f64_time, digits=3))s → $(round(adaptive_time, digits=3))s ($(round(result[:construction_overhead], digits=2))x)"
            )
            println(
                "  Conversion: $(round(f64_conversion_time, digits=3))s → $(round(adaptive_conversion_time, digits=3))s ($(round(result[:conversion_overhead], digits=2))x)"
            )
            println(
                "  Total: $(round(result[:total_f64_time], digits=3))s → $(round(result[:total_adaptive_time], digits=3))s ($(round(result[:total_overhead], digits=2))x)"
            )
            println("  Terms: $(result[:f64_terms]) → $(result[:adaptive_terms])")
            println(
                "  L2 norm: $(round(result[:f64_norm], digits=8)) → $(round(result[:adaptive_norm], digits=8))"
            )

        catch e
            println("  ❌ Failed: $e")
        end
    end

    if !isempty(results)
        println("\n📊 Degree Scaling Summary:")

        # Analyze scaling trends
        construction_overheads = [r[:construction_overhead] for r in results]
        conversion_overheads = [r[:conversion_overhead] for r in results]
        total_overheads = [r[:total_overhead] for r in results]

        println(
            "  Construction overhead: $(round(minimum(construction_overheads), digits=2))x - $(round(maximum(construction_overheads), digits=2))x"
        )
        println(
            "  Conversion overhead: $(round(minimum(conversion_overheads), digits=2))x - $(round(maximum(conversion_overheads), digits=2))x"
        )
        println(
            "  Total overhead: $(round(minimum(total_overheads), digits=2))x - $(round(maximum(total_overheads), digits=2))x"
        )

        # Check if overhead is increasing with degree
        if length(results) >= 3
            early_overhead = mean(total_overheads[1:2])
            late_overhead = mean(total_overheads[(end - 1):end])

            if late_overhead > early_overhead * 1.2
                println("  ⚠️  Overhead increases significantly with degree")
                println("     Early degrees: $(round(early_overhead, digits=2))x")
                println("     Later degrees: $(round(late_overhead, digits=2))x")
            else
                println("  ✅ Overhead remains relatively stable across degrees")
            end
        end

        # Accuracy analysis
        norm_differences = [r[:norm_difference] for r in results]
        max_norm_diff = maximum(norm_differences)

        if max_norm_diff < 1e-14
            println("  ✅ Excellent accuracy consistency across degrees")
        elseif max_norm_diff < 1e-10
            println("  ✅ Good accuracy consistency across degrees")
        else
            println("  ⚠️  Accuracy varies across degrees (max diff: $(max_norm_diff))")
        end
    end

    return DataFrame(results)
end

"""
    analyze_sample_scaling(func_name=:shubert; degree=8, sample_sizes=[50,100,200,400,800])

Analyze how AdaptivePrecision performance scales with number of samples.
"""
function analyze_sample_scaling(
    func_name = :shubert;
    degree = 8,
    sample_sizes = [50, 100, 200, 400, 800]
)
    println("📊 Sample Size Scaling Analysis for $func_name")
    println("="^50)
    println("Fixed degree: $degree")
    println("Testing sample sizes: $sample_sizes")

    results = []

    for samples in sample_sizes
        println("\n🔍 Testing $samples samples...")

        try
            # Create test input with specific sample size
            TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)

            # Time both precision types
            start_time = time()
            pol_f64 = construct_4d_polynomial(TR, degree, Float64Precision)
            f64_time = time() - start_time

            start_time = time()
            pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)
            adaptive_time = time() - start_time

            # Monomial conversion timing
            @polyvar x[1:4]

            start_time = time()
            mono_f64 = to_exact_monomial_basis(pol_f64, variables = x)
            f64_conversion_time = time() - start_time

            start_time = time()
            mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables = x)
            adaptive_conversion_time = time() - start_time

            # Memory usage estimation (approximate)
            f64_coeffs = [coefficient(t) for t in terms(mono_f64)]
            adaptive_coeffs = [coefficient(t) for t in terms(mono_adaptive)]

            result = Dict(
                :samples => samples,
                :degree => degree,
                :f64_construction_time => f64_time,
                :adaptive_construction_time => adaptive_time,
                :construction_overhead => adaptive_time / f64_time,
                :f64_conversion_time => f64_conversion_time,
                :adaptive_conversion_time => adaptive_conversion_time,
                :conversion_overhead => adaptive_conversion_time / f64_conversion_time,
                :total_f64_time => f64_time + f64_conversion_time,
                :total_adaptive_time => adaptive_time + adaptive_conversion_time,
                :total_overhead =>
                    (adaptive_time + adaptive_conversion_time) /
                    (f64_time + f64_conversion_time),
                :f64_terms => length(f64_coeffs),
                :adaptive_terms => length(adaptive_coeffs),
                :f64_norm => pol_f64.nrm,
                :adaptive_norm => pol_adaptive.nrm,
                :norm_difference => abs(pol_adaptive.nrm - pol_f64.nrm),
                :time_per_sample_f64 => (f64_time + f64_conversion_time) / samples,
                :time_per_sample_adaptive =>
                    (adaptive_time + adaptive_conversion_time) / samples
            )

            push!(results, result)

            println(
                "  Construction: $(round(f64_time, digits=3))s → $(round(adaptive_time, digits=3))s ($(round(result[:construction_overhead], digits=2))x)"
            )
            println(
                "  Total: $(round(result[:total_f64_time], digits=3))s → $(round(result[:total_adaptive_time], digits=3))s ($(round(result[:total_overhead], digits=2))x)"
            )
            println(
                "  Time/sample: $(round(result[:time_per_sample_f64]*1000, digits=2))ms → $(round(result[:time_per_sample_adaptive]*1000, digits=2))ms"
            )
            println(
                "  L2 norm: $(round(result[:f64_norm], digits=8)) → $(round(result[:adaptive_norm], digits=8))"
            )

        catch e
            println("  ❌ Failed: $e")
        end
    end

    if !isempty(results)
        println("\n📊 Sample Size Scaling Summary:")

        # Analyze scaling trends
        construction_overheads = [r[:construction_overhead] for r in results]
        total_overheads = [r[:total_overhead] for r in results]

        println(
            "  Construction overhead: $(round(minimum(construction_overheads), digits=2))x - $(round(maximum(construction_overheads), digits=2))x"
        )
        println(
            "  Total overhead: $(round(minimum(total_overheads), digits=2))x - $(round(maximum(total_overheads), digits=2))x"
        )

        # Check scaling behavior
        if length(results) >= 3
            small_samples_overhead = mean(total_overheads[1:2])
            large_samples_overhead = mean(total_overheads[(end - 1):end])

            if large_samples_overhead < small_samples_overhead * 0.8
                println("  ✅ Overhead decreases with more samples (better amortization)")
                println("     Small samples: $(round(small_samples_overhead, digits=2))x")
                println("     Large samples: $(round(large_samples_overhead, digits=2))x")
            elseif large_samples_overhead > small_samples_overhead * 1.2
                println("  ⚠️  Overhead increases with more samples")
                println("     Small samples: $(round(small_samples_overhead, digits=2))x")
                println("     Large samples: $(round(large_samples_overhead, digits=2))x")
            else
                println("  ✅ Overhead remains stable across sample sizes")
            end
        end

        # Time per sample analysis
        times_per_sample_f64 = [r[:time_per_sample_f64] for r in results]
        times_per_sample_adaptive = [r[:time_per_sample_adaptive] for r in results]

        # Check if time per sample decreases (good scaling)
        if length(results) >= 3
            early_time_f64 = mean(times_per_sample_f64[1:2])
            late_time_f64 = mean(times_per_sample_f64[(end - 1):end])
            early_time_adaptive = mean(times_per_sample_adaptive[1:2])
            late_time_adaptive = mean(times_per_sample_adaptive[(end - 1):end])

            f64_scaling = late_time_f64 / early_time_f64
            adaptive_scaling = late_time_adaptive / early_time_adaptive

            println("  Time/sample scaling:")
            println(
                "    Float64: $(round(f64_scaling, digits=3))x ($(f64_scaling < 1.0 ? "improving" : "degrading"))"
            )
            println(
                "    Adaptive: $(round(adaptive_scaling, digits=3))x ($(adaptive_scaling < 1.0 ? "improving" : "degrading"))"
            )
        end

        # Accuracy consistency
        norm_differences = [r[:norm_difference] for r in results]
        max_norm_diff = maximum(norm_differences)

        if max_norm_diff < 1e-14
            println("  ✅ Excellent accuracy consistency across sample sizes")
        elseif max_norm_diff < 1e-10
            println("  ✅ Good accuracy consistency across sample sizes")
        else
            println(
                "  ⚠️  Accuracy varies across sample sizes (max diff: $(max_norm_diff))"
            )
        end
    end

    return DataFrame(results)
end

"""
    analyze_coefficient_ranges(func_names=[:gaussian, :shubert, :sparse]; degree=8, samples=200)

Analyze how AdaptivePrecision handles different coefficient magnitude ranges across functions.
"""
function analyze_coefficient_ranges(
    func_names = [:gaussian, :shubert, :sparse];
    degree = 8,
    samples = 200
)
    println("🔢 Coefficient Range Analysis")
    println("="^40)
    println("Testing functions: $func_names")
    println("Degree: $degree, Samples: $samples")

    results = []

    for func_name in func_names
        println("\n🔍 Analyzing $func_name...")

        try
            TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)

            # Construct with both precisions
            pol_f64 = construct_4d_polynomial(TR, degree, Float64Precision)
            pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)

            @polyvar x[1:4]
            mono_f64 = to_exact_monomial_basis(pol_f64, variables = x)
            mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables = x)

            # Analyze coefficient distributions
            f64_coeffs = [abs(coefficient(t)) for t in terms(mono_f64)]
            adaptive_coeffs = [abs(coefficient(t)) for t in terms(mono_adaptive)]

            # Remove zero coefficients for analysis
            f64_nonzero = filter(x -> x > 0, f64_coeffs)
            adaptive_nonzero = filter(x -> x > 0, adaptive_coeffs)

            if !isempty(f64_nonzero) && !isempty(adaptive_nonzero)
                f64_analysis = Dict(
                    :min => minimum(f64_nonzero),
                    :max => maximum(f64_nonzero),
                    :mean => mean(f64_nonzero),
                    :median => median(f64_nonzero),
                    :std => std(f64_nonzero),
                    :dynamic_range => maximum(f64_nonzero) / minimum(f64_nonzero),
                    :log_dynamic_range =>
                        log10(maximum(f64_nonzero) / minimum(f64_nonzero))
                )

                adaptive_analysis = Dict(
                    :min => Float64(minimum(adaptive_nonzero)),
                    :max => Float64(maximum(adaptive_nonzero)),
                    :mean => Float64(mean(adaptive_nonzero)),
                    :median => Float64(median(adaptive_nonzero)),
                    :std => Float64(std(adaptive_nonzero)),
                    :dynamic_range =>
                        Float64(maximum(adaptive_nonzero) / minimum(adaptive_nonzero)),
                    :log_dynamic_range => log10(
                        Float64(maximum(adaptive_nonzero) / minimum(adaptive_nonzero))
                    )
                )

                result = Dict(
                    :function => func_name,
                    :degree => degree,
                    :samples => samples,
                    :f64_terms => length(f64_coeffs),
                    :adaptive_terms => length(adaptive_coeffs),
                    :f64_nonzero_terms => length(f64_nonzero),
                    :adaptive_nonzero_terms => length(adaptive_nonzero),
                    :f64_min_coeff => f64_analysis[:min],
                    :f64_max_coeff => f64_analysis[:max],
                    :f64_dynamic_range => f64_analysis[:dynamic_range],
                    :f64_log_dynamic_range => f64_analysis[:log_dynamic_range],
                    :adaptive_min_coeff => adaptive_analysis[:min],
                    :adaptive_max_coeff => adaptive_analysis[:max],
                    :adaptive_dynamic_range => adaptive_analysis[:dynamic_range],
                    :adaptive_log_dynamic_range =>
                        adaptive_analysis[:log_dynamic_range],
                    :dynamic_range_ratio =>
                        adaptive_analysis[:dynamic_range] / f64_analysis[:dynamic_range],
                    :precision_advantage =>
                        adaptive_analysis[:log_dynamic_range] -
                        f64_analysis[:log_dynamic_range],
                    :f64_norm => pol_f64.nrm,
                    :adaptive_norm => pol_adaptive.nrm,
                    :norm_difference => abs(pol_adaptive.nrm - pol_f64.nrm)
                )

                push!(results, result)

                println(
                    "  Float64 coefficient range: [$(scientific_notation(f64_analysis[:min])), $(scientific_notation(f64_analysis[:max]))]"
                )
                println(
                    "  Adaptive coefficient range: [$(scientific_notation(adaptive_analysis[:min])), $(scientific_notation(adaptive_analysis[:max]))]"
                )
                println(
                    "  Dynamic range: F64=$(round(f64_analysis[:log_dynamic_range], digits=1)) decades, Adaptive=$(round(adaptive_analysis[:log_dynamic_range], digits=1)) decades"
                )
                println(
                    "  Precision advantage: $(round(result[:precision_advantage], digits=1)) decades"
                )
                println(
                    "  L2 norms: F64=$(round(result[:f64_norm], digits=8)), Adaptive=$(round(result[:adaptive_norm], digits=8))"
                )

            else
                println("  ⚠️  No non-zero coefficients found")
            end

        catch e
            println("  ❌ Failed: $e")
        end
    end

    if !isempty(results)
        println("\n📊 Coefficient Range Summary:")

        # Overall statistics
        precision_advantages = [r[:precision_advantage] for r in results]
        dynamic_range_ratios = [r[:dynamic_range_ratio] for r in results]

        println(
            "  Precision advantage: $(round(minimum(precision_advantages), digits=1)) - $(round(maximum(precision_advantages), digits=1)) decades"
        )
        println(
            "  Dynamic range improvement: $(round(minimum(dynamic_range_ratios), digits=2))x - $(round(maximum(dynamic_range_ratios), digits=2))x"
        )

        # Identify functions that benefit most from AdaptivePrecision
        best_advantage_idx = argmax(precision_advantages)
        best_function = results[best_advantage_idx][:function]
        best_advantage = precision_advantages[best_advantage_idx]

        println(
            "  Best precision advantage: $best_function ($(round(best_advantage, digits=1)) decades)"
        )

        # Check for functions where AdaptivePrecision provides significant benefit
        significant_benefit = filter(r -> r[:precision_advantage] > 2.0, results)
        if !isempty(significant_benefit)
            println(
                "  Functions with significant benefit (>2 decades): $(length(significant_benefit))"
            )
            for r in significant_benefit
                println(
                    "    $(r[:function]): $(round(r[:precision_advantage], digits=1)) decades"
                )
            end
        else
            println("  No functions show significant precision advantage")
        end

        # Accuracy consistency check
        norm_differences = [r[:norm_difference] for r in results]
        max_norm_diff = maximum(norm_differences)

        if max_norm_diff < 1e-14
            println("  ✅ Excellent accuracy consistency across coefficient ranges")
        elseif max_norm_diff < 1e-10
            println("  ✅ Good accuracy consistency across coefficient ranges")
        else
            println(
                "  ⚠️  Accuracy varies across coefficient ranges (max diff: $(max_norm_diff))"
            )
        end
    end

    return DataFrame(results)
end

# Helper function for scientific notation display
function scientific_notation(x::Real)
    if x == 0
        return "0.0"
    end
    exp = floor(Int, log10(abs(x)))
    mantissa = x / (10.0^exp)
    return "$(round(mantissa, digits=2))e$(exp)"
end

# ============================================================================
# GRID OPTIMIZATION AND CACHING
# ============================================================================

"""
    FunctionEvaluationCache

Cache system for pre-saving and reusing function evaluations in 4D.
"""
mutable struct FunctionEvaluationCache
    cache::Dict{String, Dict{Vector{Float64}, Float64}}
    hit_count::Dict{String, Int}
    miss_count::Dict{String, Int}

    function FunctionEvaluationCache()
        new(Dict{String, Dict{Vector{Float64}, Float64}}(),
            Dict{String, Int}(),
            Dict{String, Int}())
    end
end

"""
    cache_function_evaluations!(cache, func_name, points, func)

Pre-compute and cache function evaluations at specified points.
"""
function cache_function_evaluations!(
    cache::FunctionEvaluationCache,
    func_name::String,
    points::Vector{Vector{Float64}},
    func::Function
)
    println("💾 Caching $(length(points)) evaluations for $func_name...")

    if !haskey(cache.cache, func_name)
        cache.cache[func_name] = Dict{Vector{Float64}, Float64}()
        cache.hit_count[func_name] = 0
        cache.miss_count[func_name] = 0
    end

    cached_count = 0
    for point in points
        if !haskey(cache.cache[func_name], point)
            try
                value = func(point)
                cache.cache[func_name][point] = value
                cached_count += 1
            catch e
                println("  ⚠️  Failed to evaluate at $point: $e")
            end
        end
    end

    println("  ✅ Cached $cached_count new evaluations")
    println("  📊 Total cached: $(length(cache.cache[func_name]))")

    return cached_count
end

"""
    get_cached_evaluation(cache, func_name, point, func)

Get function evaluation from cache, computing if not cached.
"""
function get_cached_evaluation(
    cache::FunctionEvaluationCache,
    func_name::String,
    point::Vector{Float64},
    func::Function
)
    if haskey(cache.cache, func_name) && haskey(cache.cache[func_name], point)
        cache.hit_count[func_name] += 1
        return cache.cache[func_name][point]
    else
        cache.miss_count[func_name] += 1
        value = func(point)

        # Cache the new evaluation
        if !haskey(cache.cache, func_name)
            cache.cache[func_name] = Dict{Vector{Float64}, Float64}()
            cache.hit_count[func_name] = 0
            cache.miss_count[func_name] = 0
        end
        cache.cache[func_name][point] = value

        return value
    end
end

"""
    generate_4d_grid_points(center, range, samples_per_dim)

Generate grid points for 4D function evaluation caching.
"""
function generate_4d_grid_points(
    center::Vector{Float64},
    range::Float64,
    samples_per_dim::Int
)
    points = Vector{Float64}[]

    # Generate 1D grid points
    grid_1d = range(center[1] - range, center[1] + range, length = samples_per_dim)

    # Generate 4D tensor product grid
    for x1 in grid_1d
        for x2 in grid_1d
            for x3 in grid_1d
                for x4 in grid_1d
                    push!(points, [x1, x2, x3, x4])
                end
            end
        end
    end

    return points
end

"""
    benchmark_cached_construction(func_name=:shubert; degree=8, samples=200, cache_samples_per_dim=10)

Benchmark polynomial construction with and without function evaluation caching.
"""
function benchmark_cached_construction(
    func_name = :shubert;
    degree = 8,
    samples = 200,
    cache_samples_per_dim = 10
)
    println("🚀 Cached Construction Benchmark for $func_name")
    println("="^50)

    func = TEST_FUNCTIONS_4D[func_name]
    center = [0.0, 0.0, 0.0, 0.0]
    range_val = 1.0

    # Generate cache points
    cache_points = generate_4d_grid_points(center, range_val, cache_samples_per_dim)
    total_cache_points = length(cache_points)

    println("📊 Cache configuration:")
    println("  Grid points per dimension: $cache_samples_per_dim")
    println("  Total cache points: $total_cache_points")
    println("  Construction samples: $samples")

    # Create cache and pre-populate
    cache = FunctionEvaluationCache()

    println("\n💾 Pre-populating cache...")
    start_time = time()
    cached_count = cache_function_evaluations!(cache, string(func_name), cache_points, func)
    cache_time = time() - start_time

    println("  Cache population time: $(round(cache_time, digits=3))s")

    # Benchmark without cache (standard construction)
    println("\n🔍 Benchmarking standard construction...")
    start_time = time()
    TR_standard = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)
    pol_standard = construct_4d_polynomial(TR_standard, degree, AdaptivePrecision)
    standard_time = time() - start_time

    # Create a cached version of test_input (conceptual - would need integration with Globtim)
    # For now, we'll simulate the benefit by measuring cache hit rates

    println("\n📈 Cache Performance Analysis:")

    # Simulate some lookups to test cache performance
    test_points = [center .+ 0.1 * randn(4) for _ in 1:100]

    cache_hits = 0
    cache_misses = 0

    for point in test_points
        # Check if point would be in cache (approximate)
        closest_cache_point = nothing
        min_distance = Inf

        for cache_point in cache_points
            distance = norm(point - cache_point)
            if distance < min_distance
                min_distance = distance
                closest_cache_point = cache_point
            end
        end

        # Consider it a "hit" if very close to a cached point
        if min_distance < 0.1
            cache_hits += 1
        else
            cache_misses += 1
        end
    end

    hit_rate = cache_hits / (cache_hits + cache_misses)

    results = Dict(
        :function => func_name,
        :degree => degree,
        :samples => samples,
        :cache_points => total_cache_points,
        :cache_population_time => cache_time,
        :standard_construction_time => standard_time,
        :estimated_hit_rate => hit_rate,
        :cache_efficiency => cached_count / total_cache_points,
        :standard_norm => pol_standard.nrm
    )

    println("  Cache hit rate (estimated): $(round(hit_rate*100, digits=1))%")
    println("  Cache efficiency: $(round(results[:cache_efficiency]*100, digits=1))%")
    println("  Standard construction time: $(round(standard_time, digits=3))s")
    println("  Cache population overhead: $(round(cache_time, digits=3))s")

    # Estimate potential speedup
    if hit_rate > 0.5
        estimated_speedup = 1.0 + hit_rate * 0.8  # Assume 80% speedup for cache hits
        println("  Estimated speedup potential: $(round(estimated_speedup, digits=2))x")
    else
        println("  Low hit rate - caching may not be beneficial for this configuration")
    end

    return results, cache
end

"""
    GridStrategy

Abstract type for different grid selection strategies.
"""
abstract type GridStrategy end

struct UniformGrid <: GridStrategy
    samples_per_dim::Int
end

struct AdaptiveGrid <: GridStrategy
    initial_samples::Int
    refinement_levels::Int
    refinement_threshold::Float64
end

struct RandomGrid <: GridStrategy
    total_samples::Int
    seed::Int
end

"""
    generate_grid_points(strategy::GridStrategy, center, range, func)

Generate grid points according to the specified strategy.
"""
function generate_grid_points(
    strategy::UniformGrid,
    center::Vector{Float64},
    range::Float64,
    func::Function
)
    return generate_4d_grid_points(center, range, strategy.samples_per_dim)
end

function generate_grid_points(
    strategy::RandomGrid,
    center::Vector{Float64},
    range::Float64,
    func::Function
)
    Random.seed!(strategy.seed)
    points = Vector{Float64}[]

    for _ in 1:(strategy.total_samples)
        point = center .+ range * (2.0 * rand(4) .- 1.0)
        push!(points, point)
    end

    return points
end

function generate_grid_points(
    strategy::AdaptiveGrid,
    center::Vector{Float64},
    range::Float64,
    func::Function
)
    println("🎯 Generating adaptive grid...")

    # Start with coarse uniform grid
    coarse_samples_per_dim = max(2, round(Int, strategy.initial_samples^(1 / 4)))
    points = generate_4d_grid_points(center, range, coarse_samples_per_dim)

    println("  Initial uniform grid: $(length(points)) points")

    # Evaluate function at initial points
    evaluations = Dict{Vector{Float64}, Float64}()
    for point in points
        try
            evaluations[point] = func(point)
        catch e
            println("  ⚠️  Failed to evaluate at $point: $e")
        end
    end

    # Adaptive refinement
    for level in 1:(strategy.refinement_levels)
        println("  Refinement level $level...")

        # Find regions with high variation
        refinement_candidates = Vector{Float64}[]

        # Simple refinement strategy: add points between existing points with large differences
        point_list = collect(keys(evaluations))

        for i in 1:length(point_list)
            for j in (i + 1):length(point_list)
                p1, p2 = point_list[i], point_list[j]

                # Check if points are neighbors (within reasonable distance)
                if norm(p1 - p2) < range * 0.5
                    val_diff = abs(evaluations[p1] - evaluations[p2])

                    if val_diff > strategy.refinement_threshold
                        # Add midpoint
                        midpoint = (p1 + p2) / 2

                        # Check if midpoint is not too close to existing points
                        too_close = false
                        for existing_point in keys(evaluations)
                            if norm(midpoint - existing_point) < range * 0.1
                                too_close = true
                                break
                            end
                        end

                        if !too_close
                            push!(refinement_candidates, midpoint)
                        end
                    end
                end
            end
        end

        # Limit number of refinement points per level
        max_refinements = min(length(refinement_candidates), strategy.initial_samples)
        selected_refinements = refinement_candidates[1:max_refinements]

        # Evaluate at refinement points
        new_evaluations = 0
        for point in selected_refinements
            try
                evaluations[point] = func(point)
                new_evaluations += 1
            catch e
                println("    ⚠️  Failed to evaluate refinement point: $e")
            end
        end

        println("    Added $new_evaluations refinement points")

        if new_evaluations == 0
            println("    No more refinements needed")
            break
        end
    end

    final_points = collect(keys(evaluations))
    println("  Final adaptive grid: $(length(final_points)) points")

    return final_points
end

"""
    compare_grid_strategies(func_name=:shubert; degree=8, strategies=nothing)

Compare different grid selection strategies for 4D polynomial construction.
"""
function compare_grid_strategies(func_name = :shubert; degree = 8, strategies = nothing)
    println("🎯 Grid Strategy Comparison for $func_name")
    println("="^50)

    if strategies === nothing
        strategies = [
            ("Uniform 4^4", UniformGrid(4)),
            ("Uniform 5^4", UniformGrid(5)),
            ("Random 200", RandomGrid(200, 42)),
            ("Random 500", RandomGrid(500, 42)),
            ("Adaptive", AdaptiveGrid(100, 2, 0.1))
        ]
    end

    func = TEST_FUNCTIONS_4D[func_name]
    center = [0.0, 0.0, 0.0, 0.0]
    range_val = 1.0

    results = []

    for (strategy_name, strategy) in strategies
        println("\n🔍 Testing strategy: $strategy_name")

        try
            # Generate grid points
            start_time = time()
            grid_points = generate_grid_points(strategy, center, range_val, func)
            grid_generation_time = time() - start_time

            # Create cache with these points
            cache = FunctionEvaluationCache()
            start_time = time()
            cached_count =
                cache_function_evaluations!(cache, string(func_name), grid_points, func)
            cache_time = time() - start_time

            # Estimate construction benefit (conceptual)
            # In practice, this would require integration with Globtim's sampling

            result = Dict(
                :strategy => strategy_name,
                :grid_points => length(grid_points),
                :grid_generation_time => grid_generation_time,
                :cache_population_time => cache_time,
                :total_setup_time => grid_generation_time + cache_time,
                :cache_efficiency => cached_count / length(grid_points),
                :points_per_second =>
                    length(grid_points) / (grid_generation_time + cache_time)
            )

            push!(results, result)

            println("  Grid points: $(length(grid_points))")
            println("  Generation time: $(round(grid_generation_time, digits=3))s")
            println("  Cache time: $(round(cache_time, digits=3))s")
            println("  Total setup: $(round(result[:total_setup_time], digits=3))s")
            println("  Efficiency: $(round(result[:cache_efficiency]*100, digits=1))%")

        catch e
            println("  ❌ Strategy failed: $e")
        end
    end

    if !isempty(results)
        println("\n📊 Grid Strategy Summary:")

        # Find most efficient strategies
        sorted_by_efficiency = sort(results, by = x -> x[:cache_efficiency], rev = true)
        sorted_by_speed = sort(results, by = x -> x[:points_per_second], rev = true)
        sorted_by_coverage = sort(results, by = x -> x[:grid_points], rev = true)

        println(
            "  Most efficient: $(sorted_by_efficiency[1][:strategy]) ($(round(sorted_by_efficiency[1][:cache_efficiency]*100, digits=1))%)"
        )
        println(
            "  Fastest setup: $(sorted_by_speed[1][:strategy]) ($(round(sorted_by_speed[1][:points_per_second], digits=1)) pts/s)"
        )
        println(
            "  Best coverage: $(sorted_by_coverage[1][:strategy]) ($(sorted_by_coverage[1][:grid_points]) points)"
        )

        # Recommendations
        println("\n💡 Recommendations:")

        # Find balanced strategy
        balanced_scores = []
        for result in results
            # Normalize metrics to [0,1] and combine
            max_efficiency = maximum(r[:cache_efficiency] for r in results)
            max_speed = maximum(r[:points_per_second] for r in results)
            max_coverage = maximum(r[:grid_points] for r in results)

            efficiency_score = result[:cache_efficiency] / max_efficiency
            speed_score = result[:points_per_second] / max_speed
            coverage_score = result[:grid_points] / max_coverage

            balanced_score =
                0.4 * efficiency_score + 0.3 * speed_score + 0.3 * coverage_score
            push!(balanced_scores, (result, balanced_score))
        end

        best_balanced = sort(balanced_scores, by = x -> x[2], rev = true)[1][1]
        println("  Balanced choice: $(best_balanced[:strategy])")

        # Specific recommendations based on use case
        if any(r[:grid_points] > 1000 for r in results)
            println(
                "  For large-scale problems: Consider uniform grids for predictable performance"
            )
        end

        if any(r[:total_setup_time] > 5.0 for r in results)
            println("  For interactive use: Prefer faster setup strategies")
        end
    end

    return DataFrame(results)
end

"""
    PolynomialStorage

Memory-efficient storage system for large-scale 4D polynomial data.
"""
struct PolynomialStorage
    coefficients::Dict{Vector{Int}, BigFloat}  # Sparse storage: exponent -> coefficient
    variables::Vector{Symbol}
    degree::Int
    sparsity_threshold::Float64
    metadata::Dict{String, Any}

    function PolynomialStorage(degree::Int,
        variables::Vector{Symbol} = [:x1, :x2, :x3, :x4];
        sparsity_threshold::Float64 = 1e-15)
        new(Dict{Vector{Int}, BigFloat}(), variables, degree, sparsity_threshold,
            Dict{String, Any}())
    end
end

"""
    store_polynomial!(storage, polynomial)

Store a polynomial in memory-efficient format with automatic sparsification.
"""
function store_polynomial!(storage::PolynomialStorage, polynomial)
    println("💾 Storing polynomial in memory-efficient format...")

    # Extract terms and coefficients
    terms_stored = 0
    terms_skipped = 0
    total_terms = 0

    for term in terms(polynomial)
        total_terms += 1
        coeff = coefficient(term)

        # Skip small coefficients
        if abs(coeff) < storage.sparsity_threshold
            terms_skipped += 1
            continue
        end

        # Extract exponents
        exponents = zeros(Int, length(storage.variables))

        # This is a simplified extraction - would need proper integration with DynamicPolynomials
        # For now, we'll create a placeholder
        try
            # Convert coefficient to BigFloat for storage
            big_coeff = BigFloat(coeff)

            # Use a hash of the term as a simple key (placeholder)
            term_hash = hash(string(term))
            exponent_key = [
                term_hash % 10,
                (term_hash ÷ 10) % 10,
                (term_hash ÷ 100) % 10,
                (term_hash ÷ 1000) % 10
            ]

            storage.coefficients[exponent_key] = big_coeff
            terms_stored += 1

        catch e
            println("  ⚠️  Failed to store term: $e")
        end
    end

    # Update metadata
    storage.metadata["terms_stored"] = terms_stored
    storage.metadata["terms_skipped"] = terms_skipped
    storage.metadata["total_terms"] = total_terms
    storage.metadata["sparsity_ratio"] = terms_skipped / total_terms
    storage.metadata["storage_efficiency"] = terms_stored / total_terms

    println("  ✅ Stored $terms_stored terms (skipped $terms_skipped)")
    println("  📊 Sparsity: $(round(storage.metadata["sparsity_ratio"]*100, digits=1))%")

    return terms_stored
end

"""
    analyze_storage_efficiency(func_names=[:gaussian, :shubert, :sparse]; degree=8, samples=200)

Analyze memory efficiency of polynomial storage across different functions.
"""
function analyze_storage_efficiency(
    func_names = [:gaussian, :shubert, :sparse];
    degree = 8,
    samples = 200
)
    println("💾 Storage Efficiency Analysis")
    println("="^40)

    results = []

    for func_name in func_names
        println("\n🔍 Analyzing storage for $func_name...")

        try
            # Create polynomial
            TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)
            pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)

            @polyvar x[1:4]
            mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables = x)

            # Test different sparsity thresholds
            thresholds = [1e-16, 1e-14, 1e-12, 1e-10, 1e-8]

            for threshold in thresholds
                storage = PolynomialStorage(
                    degree,
                    [:x1, :x2, :x3, :x4],
                    sparsity_threshold = threshold
                )

                # Store polynomial
                terms_stored = store_polynomial!(storage, mono_adaptive)

                # Estimate memory usage
                # BigFloat: ~32 bytes, Vector{Int}(4): ~32 bytes, overhead: ~16 bytes
                estimated_memory_per_term = 80  # bytes
                estimated_total_memory = terms_stored * estimated_memory_per_term

                # Compare to dense storage
                max_terms_4d = binomial(degree + 4, 4)  # Maximum terms for degree d in 4D
                dense_memory = max_terms_4d * estimated_memory_per_term

                result = Dict(
                    :function => func_name,
                    :degree => degree,
                    :samples => samples,
                    :threshold => threshold,
                    :terms_stored => terms_stored,
                    :total_terms => storage.metadata["total_terms"],
                    :sparsity_ratio => storage.metadata["sparsity_ratio"],
                    :storage_efficiency => storage.metadata["storage_efficiency"],
                    :estimated_memory_mb => estimated_total_memory / (1024^2),
                    :dense_memory_mb => dense_memory / (1024^2),
                    :memory_savings => 1.0 - (estimated_total_memory / dense_memory),
                    :max_possible_terms => max_terms_4d
                )

                push!(results, result)

                println(
                    "  Threshold $(threshold): $(terms_stored) terms, $(round(result[:estimated_memory_mb], digits=2)) MB"
                )
            end

        catch e
            println("  ❌ Failed: $e")
        end
    end

    if !isempty(results)
        println("\n📊 Storage Efficiency Summary:")

        # Overall statistics
        memory_savings = [r[:memory_savings] for r in results]
        sparsity_ratios = [r[:sparsity_ratio] for r in results]

        println(
            "  Memory savings: $(round(minimum(memory_savings)*100, digits=1))% - $(round(maximum(memory_savings)*100, digits=1))%"
        )
        println(
            "  Sparsity ratios: $(round(minimum(sparsity_ratios)*100, digits=1))% - $(round(maximum(sparsity_ratios)*100, digits=1))%"
        )

        # Best configurations
        best_savings_idx = argmax(memory_savings)
        best_config = results[best_savings_idx]

        println(
            "  Best memory savings: $(best_config[:function]) with threshold $(best_config[:threshold])"
        )
        println("    Savings: $(round(best_config[:memory_savings]*100, digits=1))%")
        println(
            "    Memory: $(round(best_config[:estimated_memory_mb], digits=2)) MB vs $(round(best_config[:dense_memory_mb], digits=2)) MB dense"
        )

        # Recommendations by function type
        function_groups = Dict()
        for result in results
            func = result[:function]
            if !haskey(function_groups, func)
                function_groups[func] = []
            end
            push!(function_groups[func], result)
        end

        println("\n💡 Function-Specific Recommendations:")
        for (func, func_results) in function_groups
            best_func_result =
                sort(func_results, by = x -> x[:memory_savings], rev = true)[1]
            println(
                "  $func: Use threshold $(best_func_result[:threshold]) for $(round(best_func_result[:memory_savings]*100, digits=1))% savings"
            )
        end

        # Storage scaling analysis
        println("\n📈 Storage Scaling:")
        degree_4_terms = binomial(4 + 4, 4)
        degree_8_terms = binomial(8 + 4, 4)
        degree_12_terms = binomial(12 + 4, 4)

        println(
            "  Theoretical max terms: deg 4→$(degree_4_terms), deg 8→$(degree_8_terms), deg 12→$(degree_12_terms)"
        )
        println(
            "  Memory scaling (dense): deg 4→$(round(degree_4_terms*80/(1024^2), digits=2))MB, deg 8→$(round(degree_8_terms*80/(1024^2), digits=2))MB, deg 12→$(round(degree_12_terms*80/(1024^2), digits=2))MB"
        )

        if maximum(sparsity_ratios) > 0.8
            println(
                "  ✅ High sparsity enables significant memory savings for large degrees"
            )
        else
            println("  ⚠️  Low sparsity - memory savings may be limited")
        end
    end

    return DataFrame(results)
end

# ============================================================================
# PERFORMANCE BENCHMARKING
# ============================================================================

"""
    benchmark_4d_construction(func_name=:gaussian; degree=6, samples=100, trials=5)

Detailed performance benchmarking of 4D polynomial construction.
Uses BenchmarkTools if available, otherwise falls back to basic timing.
"""
function benchmark_4d_construction(
    func_name = :gaussian;
    degree = 6,
    samples = 100,
    trials = 5
)
    println("⏱️  Benchmarking 4D Construction for $func_name")
    println("="^50)

    TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples = samples)

    if BENCHMARKTOOLS_AVAILABLE
        # Use BenchmarkTools for detailed statistics
        println("🔍 Benchmarking Float64Precision...")
        bench_f64 =
            @benchmark construct_4d_polynomial($TR, $degree, Float64Precision) samples =
                trials

        println("🔍 Benchmarking AdaptivePrecision...")
        bench_adaptive =
            @benchmark construct_4d_polynomial($TR, $degree, AdaptivePrecision) samples =
                trials

        # Results with detailed statistics
        results = Dict(
            :function => func_name,
            :degree => degree,
            :samples => samples,
            :float64_median => median(bench_f64.times) / 1e9,  # Convert to seconds
            :float64_mean => mean(bench_f64.times) / 1e9,
            :float64_std => std(bench_f64.times) / 1e9,
            :adaptive_median => median(bench_adaptive.times) / 1e9,
            :adaptive_mean => mean(bench_adaptive.times) / 1e9,
            :adaptive_std => std(bench_adaptive.times) / 1e9,
            :overhead_median => median(bench_adaptive.times) / median(bench_f64.times),
            :overhead_mean => mean(bench_adaptive.times) / mean(bench_f64.times)
        )

        println("📊 Benchmark Results:")
        println(
            "  Float64Precision: $(round(results[:float64_median], digits=4))s ± $(round(results[:float64_std], digits=4))s"
        )
        println(
            "  AdaptivePrecision: $(round(results[:adaptive_median], digits=4))s ± $(round(results[:adaptive_std], digits=4))s"
        )
        println("  Overhead (median): $(round(results[:overhead_median], digits=2))x")
        println("  Overhead (mean): $(round(results[:overhead_mean], digits=2))x")

    else
        # Fallback to basic timing
        println("🔍 Basic timing Float64Precision...")
        times_f64 = Float64[]
        for i in 1:trials
            time_f64 = @elapsed construct_4d_polynomial(TR, degree, Float64Precision)
            push!(times_f64, time_f64)
        end

        println("🔍 Basic timing AdaptivePrecision...")
        times_adaptive = Float64[]
        for i in 1:trials
            time_adaptive = @elapsed construct_4d_polynomial(TR, degree, AdaptivePrecision)
            push!(times_adaptive, time_adaptive)
        end

        # Results with basic statistics
        results = Dict(
            :function => func_name,
            :degree => degree,
            :samples => samples,
            :float64_median => median(times_f64),
            :float64_mean => mean(times_f64),
            :float64_std => std(times_f64),
            :adaptive_median => median(times_adaptive),
            :adaptive_mean => mean(times_adaptive),
            :adaptive_std => std(times_adaptive),
            :overhead_median => median(times_adaptive) / median(times_f64),
            :overhead_mean => mean(times_adaptive) / mean(times_f64)
        )

        println("📊 Basic Timing Results:")
        println(
            "  Float64Precision: $(round(results[:float64_median], digits=4))s ± $(round(results[:float64_std], digits=4))s"
        )
        println(
            "  AdaptivePrecision: $(round(results[:adaptive_median], digits=4))s ± $(round(results[:adaptive_std], digits=4))s"
        )
        println("  Overhead (median): $(round(results[:overhead_median], digits=2))x")
        println("  Overhead (mean): $(round(results[:overhead_mean], digits=2))x")
    end

    return results
end

# ============================================================================
# SUMMARY AND REPORTING
# ============================================================================

"""
    generate_4d_test_report(results_df)

Generate a comprehensive report from 4D testing results.
"""
function generate_4d_test_report(results_df)
    println("📋 4D AdaptivePrecision Test Report")
    println("="^50)

    if nrow(results_df) == 0
        println("No results to report.")
        return
    end

    # Overall statistics
    println("📊 Overall Statistics:")
    println("  Total test cases: $(nrow(results_df))")
    println("  Functions tested: $(length(unique(results_df.function)))")
    println("  Degree range: $(minimum(results_df.degree)) - $(maximum(results_df.degree))")
    println(
        "  Sample range: $(minimum(results_df.samples)) - $(maximum(results_df.samples))"
    )

    # Performance analysis
    if :precision_overhead in names(results_df)
        overhead_stats = describe(results_df.precision_overhead)
        println("\n⏱️  Performance Overhead Analysis:")
        println("  Mean overhead: $(round(overhead_stats[:mean], digits=2))x")
        println("  Median overhead: $(round(overhead_stats[:median], digits=2))x")
        println("  Min overhead: $(round(overhead_stats[:min], digits=2))x")
        println("  Max overhead: $(round(overhead_stats[:max], digits=2))x")
    end

    # Accuracy comparison
    if :float64_norm in names(results_df) && :adaptive_norm in names(results_df)
        norm_diff = abs.(results_df.adaptive_norm .- results_df.float64_norm)
        println("\n🎯 Accuracy Analysis:")
        println("  Mean norm difference: $(round(mean(norm_diff), digits=8))")
        println("  Max norm difference: $(round(maximum(norm_diff), digits=8))")
        println(
            "  Cases with improved accuracy: $(sum(results_df.adaptive_norm .< results_df.float64_norm))"
        )
    end

    # Function-specific analysis
    println("\n🔍 Function-Specific Results:")
    for func in unique(results_df.function)
        func_data = filter(row -> row.function == func, results_df)
        if :precision_overhead in names(func_data)
            avg_overhead = mean(func_data.precision_overhead)
            println(
                "  $func: $(nrow(func_data)) tests, avg overhead $(round(avg_overhead, digits=2))x"
            )
        end
    end

    println("\n✅ Report generation completed!")
end

# ============================================================================
# FRAMEWORK DISCOVERY AND HELP
# ============================================================================

"""
    show_4d_framework_functions()

Display all available functions in the 4D AdaptivePrecision testing framework.
"""
function show_4d_framework_functions()
    println("🚀 4D AdaptivePrecision Testing Framework - Available Functions")
    println("="^70)

    println("\n📊 Quick Testing:")
    println("  run_4d_quick_test()                    - Fast verification test")
    println("  compare_4d_precisions(func, deg, smp)  - Single comparison")

    println("\n📈 Comprehensive Analysis:")
    println("  run_4d_precision_comparison()          - Multi-function comparison")
    println("  run_4d_scaling_analysis(func)          - Degree/sample scaling")
    println("  analyze_4d_sparsity(func)              - Coefficient sparsity analysis")

    println("\n⏱️  Performance Benchmarking:")
    println("  benchmark_4d_construction(func)        - Detailed timing analysis")

    println("\n📋 Reporting:")
    println("  generate_4d_test_report(results_df)    - Comprehensive report")

    println("\n🔧 Utilities:")
    println("  install_benchmarktools()               - Install optional dependencies")
    println("  create_4d_test_input(func, config)     - Create test input")
    println("  construct_4d_polynomial(TR, deg, prec) - Build polynomial")

    println("\n📚 Available Test Functions:")
    for (name, func) in TEST_FUNCTIONS_4D
        println("  :$name")
    end

    println("\n⚙️  Available Configurations:")
    println("  QUICK_CONFIG        - Fast testing (degrees 2-4, samples 10-20)")
    println("  STANDARD_CONFIG     - Balanced testing (degrees 4-8, samples 20-100)")
    println("  COMPREHENSIVE_CONFIG - Full analysis (degrees 4-12, samples 50-500)")

    println("\n💡 Quick Start Examples:")
    println("  # Quick test")
    println("  results = run_4d_quick_test()")
    println("")
    println("  # Compare specific function")
    println("  result, pol_f64, pol_adaptive = compare_4d_precisions(:gaussian, 6, 50)")
    println("")
    println("  # Full comparison study")
    println("  comparison_df = run_4d_precision_comparison()")
    println("  generate_4d_test_report(comparison_df)")
    println("")
    println("  # Sparsity analysis")
    println("  analysis, mono_f64, mono_adaptive = analyze_4d_sparsity(:sparse)")

    println("\n🎯 Framework Status:")
    println("  BenchmarkTools available: $BENCHMARKTOOLS_AVAILABLE")
    println("  Test functions loaded: $(length(TEST_FUNCTIONS_4D))")
    println("  Configurations available: 3")

    println("\n📖 For detailed help on any function, use: ?function_name")
end

# Display framework info when loaded
println("\n🎯 4D AdaptivePrecision Testing Framework Loaded!")
println("📋 Type show_4d_framework_functions() to see all available functions")
println("🚀 Quick start: run_4d_quick_test()")

# Make key functions easily discoverable by defining short aliases
const help_4d = show_4d_framework_functions
const quick_test = run_4d_quick_test
const compare_precisions = run_4d_precision_comparison
const scaling_analysis = run_4d_scaling_analysis
const sparsity_analysis = analyze_4d_sparsity

println(
    "💡 Short aliases available: help_4d(), quick_test(), compare_precisions(), scaling_analysis(), sparsity_analysis()"
)
