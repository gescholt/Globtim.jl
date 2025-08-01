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
catch
    false
end

if !BENCHMARKTOOLS_AVAILABLE
    println("⚠️  BenchmarkTools not available - using basic timing fallback")
    println("   For better benchmarking, install with: Pkg.add(\"BenchmarkTools\")")
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
        println("   2. Reload the framework: include(\"test/adaptive_precision_4d_framework.jl\")")
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
    return x[1]^4 + 2*x[1]^2*x[2]^2 + x[2]^4 + 0.5*x[3]^3*x[4] + x[4]^2
end

# Oscillatory functions
function trigonometric_4d(x)
    """4D trigonometric: oscillatory, challenging for approximation"""
    return sin(π*x[1])*cos(π*x[2])*sin(2*π*x[3])*cos(2*π*x[4])
end

function mixed_frequency_4d(x)
    """Mixed frequency: multiple scales, good for sparsity testing"""
    return sin(x[1]) + 0.1*sin(10*x[2]) + 0.01*sin(100*x[3]) + cos(x[4])
end

# Sparse functions
function sparse_4d(x)
    """Sparse structure: few significant terms, ideal for truncation testing"""
    return x[1]^4 + 0.1*x[1]^3*x[2] + 0.01*x[1]^2*x[2]^2 + 0.001*x[1]*x[2]^3*x[3] + x[4]^4
end

function exponential_decay_4d(x)
    """Exponential decay: natural sparsity in coefficient magnitudes"""
    return exp(-x[1]^2) + 0.1*exp(-x[2]^2) + 0.01*exp(-x[3]^2) + 0.001*exp(-x[4]^2)
end

# Challenging functions
function holder_table_4d(x)
    """4D extension of Holder table: multiple local extrema"""
    return -abs(sin(x[1])*cos(x[2])*exp(abs(1 - sqrt(x[3]^2 + x[4]^2)/π)))
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
                             samples=config.samples[1], 
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
    return Constructor(TR, degree, precision=precision_type, verbose=0; kwargs...)
end

"""
    compare_4d_precisions(func_name, degree, samples; config=QUICK_CONFIG)

Compare Float64Precision vs AdaptivePrecision for a single 4D test case.
"""
function compare_4d_precisions(func_name::Symbol, degree::Int, samples::Int; 
                              config=QUICK_CONFIG)
    # Create test input
    TR = create_4d_test_input(func_name, config, samples=samples)
    
    # Construct polynomials with different precisions
    println("Testing $func_name (degree=$degree, samples=$samples)")
    
    # Float64 precision
    time_float64 = @elapsed pol_float64 = construct_4d_polynomial(TR, degree, Float64Precision)
    
    # Adaptive precision  
    time_adaptive = @elapsed pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)
    
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
    println("=" ^ 50)
    
    results = []
    
    for func_name in QUICK_CONFIG.functions
        for degree in QUICK_CONFIG.degrees
            for samples in QUICK_CONFIG.samples
                try
                    result, pol_f64, pol_adaptive = compare_4d_precisions(func_name, degree, samples)
                    push!(results, result)
                    
                    println("✓ $func_name: degree=$degree, samples=$samples")
                    println("  Float64 time: $(round(result[:float64_time], digits=3))s")
                    println("  Adaptive time: $(round(result[:adaptive_time], digits=3))s")
                    println("  Overhead: $(round(result[:precision_overhead], digits=2))x")
                    println("  Norms: F64=$(round(result[:float64_norm], digits=6)), Adaptive=$(round(result[:adaptive_norm], digits=6))")
                    println()
                    
                catch e
                    println("❌ Error with $func_name (degree=$degree, samples=$samples): $e")
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
function run_4d_precision_comparison(config=STANDARD_CONFIG)
    println("📊 Running 4D Precision Comparison Analysis")
    println("=" ^ 50)
    
    results = []
    
    for func_name in config.functions
        println("\n🔍 Testing function: $func_name")
        
        for degree in config.degrees
            for samples in config.samples
                try
                    result, pol_f64, pol_adaptive = compare_4d_precisions(func_name, degree, samples, config=config)
                    
                    # Extended analysis
                    @polyvar x[1:4]
                    
                    # Convert to monomial basis for detailed analysis
                    mono_f64 = to_exact_monomial_basis(pol_f64, variables=x)
                    mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables=x)
                    
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
                        result[:coeff_range_adaptive] = maximum(coeff_mags_adaptive) / minimum(coeff_mags_adaptive[coeff_mags_adaptive .> 1e-15])
                    end
                    
                    push!(results, result)
                    
                    println("  ✓ degree=$degree, samples=$samples: overhead=$(round(result[:precision_overhead], digits=2))x")
                    
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
function run_4d_scaling_analysis(func_name=:gaussian; max_degree=10, max_samples=200)
    println("📈 Running 4D Scalability Analysis for $func_name")
    println("=" ^ 50)

    results = []

    # Degree scaling (fixed samples)
    println("\n🔍 Degree Scaling Analysis (samples=50)")
    for degree in 2:2:max_degree
        try
            TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples=50)

            # Benchmark both precisions
            time_f64 = @elapsed pol_f64 = construct_4d_polynomial(TR, degree, Float64Precision)
            time_adaptive = @elapsed pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)

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
            println("  Degree $degree: overhead=$(round(result[:overhead], digits=2))x, norms=($(round(pol_f64.nrm, digits=4)), $(round(pol_adaptive.nrm, digits=4)))")

        catch e
            println("  ❌ Error at degree $degree: $e")
        end
    end

    # Sample scaling (fixed degree)
    println("\n🔍 Sample Scaling Analysis (degree=6)")
    for samples in [20, 50, 100, 200]
        if samples <= max_samples
            try
                TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples=samples)

                time_f64 = @elapsed pol_f64 = construct_4d_polynomial(TR, 6, Float64Precision)
                time_adaptive = @elapsed pol_adaptive = construct_4d_polynomial(TR, 6, AdaptivePrecision)

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
                println("  Samples $samples: overhead=$(round(result[:overhead], digits=2))x, times=($(round(time_f64, digits=3))s, $(round(time_adaptive, digits=3))s)")

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
function analyze_4d_sparsity(func_name=:sparse; degree=8, samples=100)
    println("✂️  Running 4D Sparsity Analysis for $func_name")
    println("=" ^ 50)

    TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples=samples)

    # Construct polynomials
    pol_f64 = construct_4d_polynomial(TR, degree, Float64Precision)
    pol_adaptive = construct_4d_polynomial(TR, degree, AdaptivePrecision)

    @polyvar x[1:4]

    # Convert to monomial basis
    mono_f64 = to_exact_monomial_basis(pol_f64, variables=x)
    mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables=x)

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
            println("  Threshold $(threshold): keep $(stats.n_kept)/$(stats.n_total) ($(round(stats.sparsity_ratio*100, digits=1))% sparse)")
        end

        return analysis, mono_f64, mono_adaptive
    else
        println("⚠️  No coefficients found for analysis")
        return nothing, mono_f64, mono_adaptive
    end
end

# ============================================================================
# PERFORMANCE BENCHMARKING
# ============================================================================

"""
    benchmark_4d_construction(func_name=:gaussian; degree=6, samples=100, trials=5)

Detailed performance benchmarking of 4D polynomial construction.
Uses BenchmarkTools if available, otherwise falls back to basic timing.
"""
function benchmark_4d_construction(func_name=:gaussian; degree=6, samples=100, trials=5)
    println("⏱️  Benchmarking 4D Construction for $func_name")
    println("=" ^ 50)

    TR = create_4d_test_input(func_name, STANDARD_CONFIG, samples=samples)

    if BENCHMARKTOOLS_AVAILABLE
        # Use BenchmarkTools for detailed statistics
        println("🔍 Benchmarking Float64Precision...")
        bench_f64 = @benchmark construct_4d_polynomial($TR, $degree, Float64Precision) samples=trials

        println("🔍 Benchmarking AdaptivePrecision...")
        bench_adaptive = @benchmark construct_4d_polynomial($TR, $degree, AdaptivePrecision) samples=trials

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
        println("  Float64Precision: $(round(results[:float64_median], digits=4))s ± $(round(results[:float64_std], digits=4))s")
        println("  AdaptivePrecision: $(round(results[:adaptive_median], digits=4))s ± $(round(results[:adaptive_std], digits=4))s")
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
        println("  Float64Precision: $(round(results[:float64_median], digits=4))s ± $(round(results[:float64_std], digits=4))s")
        println("  AdaptivePrecision: $(round(results[:adaptive_median], digits=4))s ± $(round(results[:adaptive_std], digits=4))s")
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
    println("=" ^ 50)

    if nrow(results_df) == 0
        println("No results to report.")
        return
    end

    # Overall statistics
    println("📊 Overall Statistics:")
    println("  Total test cases: $(nrow(results_df))")
    println("  Functions tested: $(length(unique(results_df.function)))")
    println("  Degree range: $(minimum(results_df.degree)) - $(maximum(results_df.degree))")
    println("  Sample range: $(minimum(results_df.samples)) - $(maximum(results_df.samples))")

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
        println("  Cases with improved accuracy: $(sum(results_df.adaptive_norm .< results_df.float64_norm))")
    end

    # Function-specific analysis
    println("\n🔍 Function-Specific Results:")
    for func in unique(results_df.function)
        func_data = filter(row -> row.function == func, results_df)
        if :precision_overhead in names(func_data)
            avg_overhead = mean(func_data.precision_overhead)
            println("  $func: $(nrow(func_data)) tests, avg overhead $(round(avg_overhead, digits=2))x")
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
    println("=" ^ 70)

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

println("💡 Short aliases available: help_4d(), quick_test(), compare_precisions(), scaling_analysis(), sparsity_analysis()")
