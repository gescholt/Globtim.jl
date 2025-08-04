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
using Dates

# Optional packages for profiling
profile_available = false
try
    using Profile
    global profile_available = true
    println("✅ Profile package loaded - profiling available")
catch
    println("⚠️  Profile package not available - profiling disabled")
end

# Load testing framework with robust path handling
global framework_loaded = false
framework_paths = ["../test/adaptive_precision_4d_framework.jl", "test/adaptive_precision_4d_framework.jl"]

for path in framework_paths
    try
        if isfile(path)
            include(path)
            global framework_loaded = true
            break
        end
    catch e
        continue
    end
end

println("🚀 AdaptivePrecision 4D Development Environment")
println("=" ^ 60)
println("📋 Revise active - Globtim changes will auto-reload")

if framework_loaded
    println("✅ Testing framework loaded successfully")
    if @isdefined(BENCHMARKTOOLS_AVAILABLE)
        println("⚡ BenchmarkTools available: $BENCHMARKTOOLS_AVAILABLE")
    end
    if @isdefined(TEST_FUNCTIONS_4D)
        @printf "📊 Available test functions: %d\n" length(TEST_FUNCTIONS_4D)
    end
else
    println("⚠️  Testing framework not found - basic functionality only")
end

# ============================================================================
# CONFIGURATION
# ============================================================================

# Shubert 4D parameters
const n, a, b = 4, 2, 1
const scale_factor = a / b
const center = [0.0, 0.0, 0.0, 0.0]

# Development testing parameters (start small)
const DEV_CONFIG = (
    degrees = [3, 4],
    samples = [10, 11, 12],
    function_name = :shubert
)

println("\n🎯 Development Configuration:")
println("  Function: $(DEV_CONFIG.function_name)")
println("  Degrees: $(DEV_CONFIG.degrees)")
println("  Samples: $(DEV_CONFIG.samples)")
println("  Scale factor: $scale_factor")

# ============================================================================
# COMPACT STATISTICS SYSTEM
# ============================================================================

function create_stats(bench_f64, bench_adaptive, pol_f64, pol_adaptive, degree, samples)
    Dict(
        :degree => degree, :samples => samples, :dimension => n,
        :time_overhead => median(bench_adaptive.times) / median(bench_f64.times),
        :memory_overhead => bench_adaptive.memory / bench_f64.memory,
        :f64_norm => pol_f64.nrm, :adaptive_norm => pol_adaptive.nrm,
        :norm_diff => abs(pol_adaptive.nrm - pol_f64.nrm),
        :coeffs => length(pol_adaptive.coeffs), :expected => binomial(degree + n, n)
    )
end

function display_stats(s)
    @printf "📊 %dD deg=%d n=%d: %.2fx time, %.2fx mem, L2diff=%.1e, %d/%d coeffs\n" s[:dimension] s[:degree] s[:samples] s[:time_overhead] s[:memory_overhead] s[:norm_diff] s[:coeffs] s[:expected]
end

# ============================================================================
# QUICK TESTING FUNCTIONS
# ============================================================================

"""
    check_framework_status()

Check what components of the development environment are available.
"""
function check_framework_status()
    println("\n🔍 Development Environment Status")
    println("-" ^ 40)

    println("Framework loaded: $(framework_loaded)")
    println("Profile available: $(profile_available)")

    if framework_loaded
        println("✅ Testing framework functions available:")
        if @isdefined(compare_4d_precisions)
            println("  ✅ compare_4d_precisions")
        else
            println("  ❌ compare_4d_precisions")
        end

        if @isdefined(TEST_FUNCTIONS_4D)
            println("  ✅ TEST_FUNCTIONS_4D ($(length(TEST_FUNCTIONS_4D)) functions)")
        else
            println("  ❌ TEST_FUNCTIONS_4D")
        end
    else
        println("⚠️  Testing framework not loaded - using basic functions only")
    end

    println("\n💡 Available functions:")
    println("  check_framework_status()    - This status check")
    println("  quick_shubert_test()        - Quick test (with fallback)")
    println("  basic_shubert_test()        - Basic test (no framework)")
    println("  profile_adaptive_construction() - Profiling (if available)")
end

"""
    quick_shubert_test(degree=6, samples=100)

Quick test of Shubert 4D with specified parameters.
"""
function quick_shubert_test(degree=3, samples=10)
    println("\n🔬 Quick Shubert 4D Test (degree=$degree, samples=$samples)")
    println("-" ^ 50)

    # Check if testing framework is available
    if !framework_loaded || !@isdefined(compare_4d_precisions)
        println("⚠️  Testing framework not available - running basic test instead")
        return basic_shubert_test(degree, samples)
    end

    # Use framework function
    try
        result, pol_f64, pol_adaptive = compare_4d_precisions(:shubert, degree, samples)

        println("✅ Test Results:")
        println("  Time overhead: $(round(result[:precision_overhead], digits=3))x")
        println("  Float64 time: $(round(result[:float64_time], digits=4))s")
        println("  Adaptive time: $(round(result[:adaptive_time], digits=4))s")
        println("  L2 norms: F64=$(round(result[:float64_norm], digits=6)), Adaptive=$(round(result[:adaptive_norm], digits=6))")
        println("  Norm difference: $(abs(result[:adaptive_norm] - result[:float64_norm]))")
        println("  Coefficients: $(result[:adaptive_coeffs])")

        return result, pol_f64, pol_adaptive
    catch e
        println("❌ Framework test failed: $e")
        println("   Falling back to basic test...")
        return basic_shubert_test(degree, samples)
    end
end

"""
    basic_shubert_test(degree=3, samples=10)

Basic Shubert 4D test without framework dependencies.
"""
function basic_shubert_test(degree=3, samples=10)
    println("\n🔧 Basic Shubert 4D Test (degree=$degree, samples=$samples)")

    # Create test input
    TR = test_input(
        shubert_4d,
        dim = n,
        center = center,
        GN = samples,
        sample_range = scale_factor,
        degree_max = degree + 2
    )

    # Test both precisions
    println("Testing Float64Precision...")
    @time pol_f64 = Constructor(TR, degree, basis=:chebyshev, precision=Float64Precision, verbose=0)

    println("Testing AdaptivePrecision...")
    @time pol_adaptive = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)

    # Basic comparison
    println("\n✅ Basic Results:")
    @printf "  Float64 L2 norm:    %.6e\n" pol_f64.nrm
    @printf "  Adaptive L2 norm:   %.6e\n" pol_adaptive.nrm
    @printf "  L2 norm difference: %.6e\n" abs(pol_adaptive.nrm - pol_f64.nrm)
    @printf "  Coefficients:       %d\n" length(pol_adaptive.coeffs)

    return nothing  # Don't return huge polynomials
end

"""
    profile_adaptive_construction(degree=6, samples=100, iterations=5)

Profile AdaptivePrecision construction to identify bottlenecks.
"""
function profile_adaptive_construction(degree=3, samples=10, iterations=5)
    println("\n🔬 Profiling AdaptivePrecision Construction")
    println("-" ^ 50)
    
    # Create test input
    TR = test_input(
        shubert_4d,
        dim = n,
        center = center,
        GN = samples,
        sample_range = scale_factor,
        degree_max = degree + 2
    )
    
    # Profile construction if available
    if profile_available
        Profile.clear()
        println("📊 Running profiled construction ($iterations iterations)...")
        @profile for i in 1:iterations
            pol = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
        end

        println("📈 Profile Results:")
        Profile.print(maxdepth=15, mincount=5)
        println("\n💡 Use ProfileView.view() for interactive analysis")
    else
        println("⚠️  Profiling not available - running basic timing instead...")
        @time for i in 1:iterations
            pol = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
        end
    end
    return TR
end

"""
    benchmark_construction_detailed(degree=6, samples=100)

Detailed benchmarking of construction phases.
"""
function benchmark_construction_detailed(degree=4, samples=10)
    println("\n⏱️  Benchmarking deg=$degree, n=$samples")

    TR = test_input(shubert_4d, dim=n, center=center, GN=samples, sample_range=scale_factor, degree_max=degree+2)

    # Test constructions
    pol_f64 = Constructor(TR, degree, basis=:chebyshev, precision=Float64Precision, verbose=0)
    pol_adaptive = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)

    # Quick benchmarks
    bench_f64 = @benchmark Constructor($TR, $degree, basis=:chebyshev, precision=Float64Precision, verbose=0) samples=2 seconds=5
    bench_adaptive = @benchmark Constructor($TR, $degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0) samples=2 seconds=5

    stats = create_stats(bench_f64, bench_adaptive, pol_f64, pol_adaptive, degree, samples)
    display_stats(stats)
    return stats
end

"""
    comprehensive_4d_test(degrees=[3, 4], samples=[10, 12])

Run comprehensive testing across multiple parameter combinations with detailed statistics.
"""
function comprehensive_4d_test(degrees=[3, 4], samples=[10, 12])
    println("\n🎯 Comprehensive 4D AdaptivePrecision Test Suite")
    println("=" ^ 60)

    all_results = []

    for degree in degrees
        for sample_count in samples
            println("\n" * "─"^50)
            @printf "Testing: degree=%d, samples=%d\n" degree sample_count
            println("─"^50)

            try
                # Run detailed benchmark
                stats = benchmark_construction_detailed(degree, sample_count)

                if stats !== nothing
                    push!(all_results, stats)

                    # Quick quality check
                    if stats[:time_overhead] > 5.0
                        println("⚠️  High overhead detected - consider optimization")
                    end

                    if stats[:norm_relative_error] > 1e-6
                        println("⚠️  Precision loss detected - investigate")
                    end
                else
                    println("❌ Test failed for degree=$degree, samples=$sample_count")
                end

            catch e
                println("❌ Error in test: $e")
                continue
            end
        end
    end

    # Create comprehensive summary
    if !isempty(all_results)
        create_test_summary(all_results...)

        # Performance trends
        println("\n📈 Performance Trends:")
        for degree in degrees
            degree_results = filter(r -> r[:degree] == degree, all_results)
            if !isempty(degree_results)
                avg_overhead = mean([r[:time_overhead] for r in degree_results])
                @printf "   Degree %d: %.2fx average overhead\n" degree avg_overhead
            end
        end

        # Best and worst cases
        if length(all_results) > 1
            best_idx = argmin([r[:time_overhead] for r in all_results])
            worst_idx = argmax([r[:time_overhead] for r in all_results])

            best = all_results[best_idx]
            worst = all_results[worst_idx]

            println("\n🏆 Performance Summary:")
            @printf "   Best:  deg=%d, n=%d (%.2fx overhead)\n" best[:degree] best[:samples] best[:time_overhead]
            @printf "   Worst: deg=%d, n=%d (%.2fx overhead)\n" worst[:degree] worst[:samples] worst[:time_overhead]
        end
    else
        println("\n❌ No successful tests completed")
    end

    return all_results
end

"""
    test_sparsity_analysis(degrees=[4,5,6], samples=[10,20,30])

Extended sparsity analysis across multiple parameter combinations.
"""
function test_sparsity_analysis(degrees=[4,5,6], samples=[10,20,30])
    println("\n✂️  Extended Sparsity Analysis")
    println("=" ^ 50)

    results = []

    for degree in degrees
        for sample_count in samples
            println("\n📊 Testing degree=$degree, samples=$sample_count")
            println("-" ^ 30)

            try
                result = basic_sparsity_analysis(degree, sample_count)
                push!(results, (degree=degree, samples=sample_count, result=result))
            catch e
                println("❌ Failed: $e")
                continue
            end
        end
    end

    # Summary
    if !isempty(results)
        println("\n🎯 Sparsity Summary:")
        println("Deg  Samples  Terms  Sparse@1e-10  Sparse@1e-08")
        println("-" ^ 45)
        for r in results
            if r.result !== nothing && isa(r.result, Dict)
                @printf "%2d   %7d   %4d   %8.1f%%     %8.1f%%\n" r.degree r.samples r.result[:terms] r.result[:sparse_1e10] r.result[:sparse_1e8]
            end
        end
    end

    return nothing  # Don't return raw data
end

"""
    basic_sparsity_analysis(degree=4, samples=10)

Basic sparsity analysis without framework dependencies.
"""
function basic_sparsity_analysis(degree=4, samples=10)
    TR = test_input(shubert_4d, dim=n, center=center, GN=samples, sample_range=scale_factor, degree_max=degree+2)

    pol_f64 = Constructor(TR, degree, basis=:chebyshev, precision=Float64Precision, verbose=0)
    pol_adaptive = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)

    @polyvar x[1:n]
    mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables=x)
    coeffs = abs.(Float64.([coefficient(t) for t in terms(mono_adaptive)]))

    # Calculate sparsity at key thresholds
    total_terms = length(coeffs)
    sparse_1e10 = (total_terms - sum(coeffs .> 1e-10)) / total_terms * 100
    sparse_1e8 = (total_terms - sum(coeffs .> 1e-8)) / total_terms * 100

    l2_diff = abs(pol_adaptive.nrm - pol_f64.nrm)

    @printf "  L2diff=%.1e, %d terms, %.1f%% sparse@1e-10, %.1f%% sparse@1e-8\n" l2_diff total_terms sparse_1e10 sparse_1e8

    return Dict(:terms => total_terms, :sparse_1e10 => sparse_1e10, :sparse_1e8 => sparse_1e8, :l2_diff => l2_diff)
end

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Script is being run directly
    println("\n🚀 Running Development Tests...")
    
    # Quick test
    println("\n" * "="^60)
    quick_shubert_test()

    # Detailed benchmarking
    println("\n" * "="^60)
    benchmark_construction_detailed()

    # Sparsity analysis
    println("\n" * "="^60)
    test_sparsity_analysis()
    
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
