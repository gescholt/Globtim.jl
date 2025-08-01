"""
AdaptivePrecision 4D Development Script

Companion script to the development notebook for quick testing and profiling.
Use this for rapid iteration when you don't need the full notebook interface.

Usage:
    julia --project=. Examples/adaptive_precision_4d_dev.jl
    
Or in REPL:
    include("Examples/adaptive_precision_4d_dev.jl")
"""

using Pkg
Pkg.activate(".")

# Load Revise first for automatic reloading
using Revise

# Core packages
using Globtim
using DynamicPolynomials
using DataFrames
using BenchmarkTools
using Statistics
using LinearAlgebra
using Printf

# Load testing framework
include("test/adaptive_precision_4d_framework.jl")

println("🚀 AdaptivePrecision 4D Development Environment")
println("=" ^ 60)
println("📋 Revise active - Globtim changes will auto-reload")
println("⚡ BenchmarkTools available: $BENCHMARKTOOLS_AVAILABLE")

# ============================================================================
# CONFIGURATION
# ============================================================================

# Shubert 4D parameters
const n, a, b = 4, 2, 1
const scale_factor = a / b
const center = [0.0, 0.0, 0.0, 0.0]

# Development testing parameters (start small)
const DEV_CONFIG = (
    degrees = [4, 6, 8],
    samples = [50, 100, 200],
    function_name = :shubert
)

println("\n🎯 Development Configuration:")
println("  Function: $(DEV_CONFIG.function_name)")
println("  Degrees: $(DEV_CONFIG.degrees)")
println("  Samples: $(DEV_CONFIG.samples)")
println("  Scale factor: $scale_factor")

# ============================================================================
# QUICK TESTING FUNCTIONS
# ============================================================================

"""
    quick_shubert_test(degree=6, samples=100)

Quick test of Shubert 4D with specified parameters.
"""
function quick_shubert_test(degree=6, samples=100)
    println("\n🔬 Quick Shubert 4D Test (degree=$degree, samples=$samples)")
    println("-" ^ 50)
    
    # Create test input
    TR = test_input(
        shubert_4d,
        dim = n,
        center = center,
        GN = samples,
        sample_range = scale_factor,
        degree_max = degree + 4
    )
    
    # Compare precisions
    result, pol_f64, pol_adaptive = compare_4d_precisions(:shubert, degree, samples)
    
    println("✅ Test Results:")
    println("  Time overhead: $(round(result[:precision_overhead], digits=3))x")
    println("  Float64 time: $(round(result[:float64_time], digits=4))s")
    println("  Adaptive time: $(round(result[:adaptive_time], digits=4))s")
    println("  L2 norms: F64=$(round(result[:float64_norm], digits=6)), Adaptive=$(round(result[:adaptive_norm], digits=6))")
    println("  Norm difference: $(abs(result[:adaptive_norm] - result[:float64_norm]))")
    println("  Coefficients: $(result[:adaptive_coeffs])")
    
    return result, pol_f64, pol_adaptive
end

"""
    profile_adaptive_construction(degree=6, samples=100, iterations=5)

Profile AdaptivePrecision construction to identify bottlenecks.
"""
function profile_adaptive_construction(degree=6, samples=100, iterations=5)
    println("\n🔬 Profiling AdaptivePrecision Construction")
    println("-" ^ 50)
    
    # Create test input
    TR = test_input(
        shubert_4d,
        dim = n,
        center = center,
        GN = samples,
        sample_range = scale_factor,
        degree_max = degree + 4
    )
    
    # Clear previous profile data
    using Profile
    Profile.clear()
    
    # Profile construction
    println("📊 Running profiled construction ($iterations iterations)...")
    @profile for i in 1:iterations
        pol = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
    end
    
    println("📈 Profile Results:")
    Profile.print(maxdepth=15, mincount=5)
    
    println("\n💡 Use ProfileView.view() for interactive analysis")
    return TR
end

"""
    benchmark_construction_detailed(degree=6, samples=100)

Detailed benchmarking of construction phases.
"""
function benchmark_construction_detailed(degree=6, samples=100)
    println("\n⏱️  Detailed Construction Benchmarking")
    println("-" ^ 50)
    
    # Create test input
    TR = test_input(
        shubert_4d,
        dim = n,
        center = center,
        GN = samples,
        sample_range = scale_factor,
        degree_max = degree + 4
    )
    
    println("📊 Benchmarking construction phase...")
    
    # Benchmark Float64Precision
    bench_f64 = @benchmark Constructor($TR, $degree, basis=:chebyshev, precision=Float64Precision, verbose=0) samples=5
    
    # Benchmark AdaptivePrecision
    bench_adaptive = @benchmark Constructor($TR, $degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0) samples=5
    
    # Results
    println("📈 Construction Phase Results:")
    println("  Float64Precision:")
    println("    Median time: $(round(median(bench_f64.times) / 1e9, digits=4))s")
    println("    Memory: $(bench_f64.memory) bytes")
    println("  AdaptivePrecision:")
    println("    Median time: $(round(median(bench_adaptive.times) / 1e9, digits=4))s")
    println("    Memory: $(bench_adaptive.memory) bytes")
    println("  Overhead:")
    println("    Time: $(round(median(bench_adaptive.times) / median(bench_f64.times), digits=3))x")
    println("    Memory: $(round(bench_adaptive.memory / bench_f64.memory, digits=3))x")
    
    # Test monomial conversion
    println("\n🔄 Benchmarking monomial conversion phase...")
    
    pol_f64 = Constructor(TR, degree, basis=:chebyshev, precision=Float64Precision, verbose=0)
    pol_adaptive = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
    
    @polyvar x[1:n]
    
    # Benchmark monomial conversion
    bench_mono_f64 = @benchmark to_exact_monomial_basis($pol_f64, variables=$x) samples=3
    bench_mono_adaptive = @benchmark to_exact_monomial_basis($pol_adaptive, variables=$x) samples=3
    
    println("📈 Monomial Conversion Results:")
    println("  Float64Precision:")
    println("    Median time: $(round(median(bench_mono_f64.times) / 1e9, digits=4))s")
    println("    Memory: $(bench_mono_f64.memory) bytes")
    println("  AdaptivePrecision:")
    println("    Median time: $(round(median(bench_mono_adaptive.times) / 1e9, digits=4))s")
    println("    Memory: $(bench_mono_adaptive.memory) bytes")
    println("  Overhead:")
    println("    Time: $(round(median(bench_mono_adaptive.times) / median(bench_mono_f64.times), digits=3))x")
    println("    Memory: $(round(bench_mono_adaptive.memory / bench_mono_f64.memory, digits=3))x")
    
    return (
        construction = (f64 = bench_f64, adaptive = bench_adaptive),
        conversion = (f64 = bench_mono_f64, adaptive = bench_mono_adaptive)
    )
end

"""
    test_sparsity_analysis(degree=8, samples=100)

Test sparsity analysis with AdaptivePrecision.
"""
function test_sparsity_analysis(degree=8, samples=100)
    println("\n✂️  Sparsity Analysis Test")
    println("-" ^ 50)
    
    analysis, mono_f64, mono_adaptive = analyze_4d_sparsity(:shubert, degree=degree, samples=samples)
    
    if analysis !== nothing
        println("📊 Sparsity Results:")
        println("  Dynamic range: $(round(analysis.dynamic_range, digits=2))")
        println("  Suggested thresholds: $(length(analysis.suggested_thresholds))")
        
        if length(analysis.suggested_thresholds) > 0
            threshold = analysis.suggested_thresholds[1]
            truncated_poly, stats = truncate_polynomial_adaptive(mono_adaptive, threshold)
            
            println("  Optimal truncation ($(threshold)):")
            println("    Sparsity: $(round(stats.sparsity_ratio*100, digits=1))%")
            println("    Terms: $(stats.n_kept)/$(stats.n_total)")
        end
    end
    
    return analysis, mono_f64, mono_adaptive
end

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Script is being run directly
    println("\n🚀 Running Development Tests...")
    
    # Quick test
    println("\n" * "="^60)
    result, pol_f64, pol_adaptive = quick_shubert_test()
    
    # Detailed benchmarking
    println("\n" * "="^60)
    benchmarks = benchmark_construction_detailed()
    
    # Sparsity analysis
    println("\n" * "="^60)
    analysis, mono_f64, mono_adaptive = test_sparsity_analysis()
    
    println("\n🎉 Development testing complete!")
    println("💡 Use the individual functions for targeted testing:")
    println("  - quick_shubert_test(degree, samples)")
    println("  - profile_adaptive_construction(degree, samples)")
    println("  - benchmark_construction_detailed(degree, samples)")
    println("  - test_sparsity_analysis(degree, samples)")
    
else
    # Script is being included
    println("\n💡 Development functions loaded:")
    println("  - quick_shubert_test(degree, samples)")
    println("  - profile_adaptive_construction(degree, samples)")
    println("  - benchmark_construction_detailed(degree, samples)")
    println("  - test_sparsity_analysis(degree, samples)")
    println("\n🚀 Ready for interactive development!")
end
