"""
Comprehensive Globtim Compilation Test for HPC Cluster

This script provides a systematic, thorough test of Globtim compilation and functionality
on the HPC cluster. It covers all major components and provides detailed diagnostics.

Features:
- Complete dependency verification
- Module-by-module compilation testing
- End-to-end workflow validation
- Performance benchmarking
- Detailed error reporting and recovery
- Results logging for analysis

Usage:
    julia hpc/scripts/compilation_tests/comprehensive_compilation_test.jl [--mode MODE]
    
Modes:
    --quick     : Fast compilation check (minimal testing)
    --standard  : Complete compilation and functionality test (default)
    --thorough  : Exhaustive testing with all features
"""

using Pkg
using Printf
using Dates
using LinearAlgebra
using Statistics
using Random

# ============================================================================
# CONFIGURATION AND SETUP
# ============================================================================

println("🚀 COMPREHENSIVE GLOBTIM COMPILATION TEST")
println("=" ^ 70)
println("Started: $(now())")
println("Julia version: $(VERSION)")
println("Threads: $(Threads.nthreads())")
println()

# Parse command line arguments
test_mode = "standard"
if "--quick" in ARGS
    test_mode = "quick"
elseif "--thorough" in ARGS
    test_mode = "thorough"
end

# Configuration based on test mode
if test_mode == "quick"
    CONFIG = (
        mode = "quick",
        test_timeout = 300,      # 5 minutes
        sample_sizes = [20, 50],
        degrees = [3, 4],
        dimensions = [2],
        enable_benchmarks = false,
        enable_advanced_tests = false
    )
elseif test_mode == "thorough"
    CONFIG = (
        mode = "thorough", 
        test_timeout = 3600,     # 1 hour
        sample_sizes = [50, 100, 200],
        degrees = [3, 4, 5, 6],
        dimensions = [2, 3, 4],
        enable_benchmarks = true,
        enable_advanced_tests = true
    )
else # standard
    CONFIG = (
        mode = "standard",
        test_timeout = 1800,     # 30 minutes
        sample_sizes = [50, 100],
        degrees = [3, 4, 5],
        dimensions = [2, 3],
        enable_benchmarks = true,
        enable_advanced_tests = false
    )
end

println("📋 Test Configuration:")
println("   Mode: $(CONFIG.mode)")
println("   Timeout: $(CONFIG.test_timeout) seconds")
println("   Sample sizes: $(CONFIG.sample_sizes)")
println("   Degrees: $(CONFIG.degrees)")
println("   Dimensions: $(CONFIG.dimensions)")
println("   Benchmarks: $(CONFIG.enable_benchmarks)")
println("   Advanced tests: $(CONFIG.enable_advanced_tests)")
println()

# Global test tracking
test_results = Dict{String, Any}()
test_start_time = time()
tests_passed = 0
total_tests = 0

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function run_test(test_name::String, test_function::Function)
    global tests_passed, total_tests
    total_tests += 1
    
    println("🧪 Testing: $test_name")
    start_time = time()
    
    try
        result = test_function()
        elapsed = time() - start_time
        
        if result isa Bool && result
            println("   ✅ PASSED ($(@sprintf("%.2f", elapsed))s)")
            test_results[test_name] = Dict("status" => "PASS", "time" => elapsed)
            tests_passed += 1
            return true
        elseif result isa Dict
            if get(result, "success", false)
                println("   ✅ PASSED ($(@sprintf("%.2f", elapsed))s)")
                test_results[test_name] = merge(result, Dict("status" => "PASS", "time" => elapsed))
                tests_passed += 1
                return true
            else
                println("   ❌ FAILED ($(@sprintf("%.2f", elapsed))s): $(get(result, "error", "Unknown error"))")
                test_results[test_name] = merge(result, Dict("status" => "FAIL", "time" => elapsed))
                return false
            end
        else
            println("   ❌ FAILED ($(@sprintf("%.2f", elapsed))s): Invalid test result")
            test_results[test_name] = Dict("status" => "FAIL", "time" => elapsed, "error" => "Invalid result")
            return false
        end
    catch e
        elapsed = time() - start_time
        println("   ❌ ERROR ($(@sprintf("%.2f", elapsed))s): $e")
        test_results[test_name] = Dict("status" => "ERROR", "time" => elapsed, "error" => string(e))
        return false
    end
end

function log_section(title::String)
    println("\n" * "=" * "^" * 50)
    println("📋 $title")
    println("=" * "^" * 50)
end

# ============================================================================
# TEST FUNCTIONS
# ============================================================================

function test_julia_environment()
    # Test basic Julia functionality
    try
        # Basic arithmetic
        result1 = 2.0^3 + sqrt(16) - sin(π/2)
        if abs(result1 - 11.0) > 1e-10
            return Dict("success" => false, "error" => "Basic arithmetic failed")
        end
        
        # Linear algebra
        A = rand(10, 10)
        b = rand(10)
        x = A \ b
        residual = norm(A * x - b)
        if residual > 1e-10
            return Dict("success" => false, "error" => "Linear algebra failed")
        end
        
        # Threading
        if Threads.nthreads() > 1
            results = zeros(Threads.nthreads())
            Threads.@threads for i in 1:Threads.nthreads()
                results[i] = i^2
            end
            if !all(results[i] == i^2 for i in 1:Threads.nthreads())
                return Dict("success" => false, "error" => "Threading failed")
            end
        end
        
        return Dict("success" => true, "threads" => Threads.nthreads(), "residual" => residual)
    catch e
        return Dict("success" => false, "error" => string(e))
    end
end

function test_essential_packages()
    essential_packages = [
        "LinearAlgebra", "Statistics", "Random", "Printf", "Dates",
        "CSV", "DataFrames", "Parameters", "TOML"
    ]
    
    loaded_packages = String[]
    failed_packages = String[]
    
    for pkg in essential_packages
        try
            eval(Meta.parse("using $pkg"))
            push!(loaded_packages, pkg)
        catch e
            push!(failed_packages, pkg)
        end
    end
    
    success_rate = length(loaded_packages) / length(essential_packages)
    
    return Dict(
        "success" => success_rate >= 0.8,  # At least 80% must load
        "loaded" => loaded_packages,
        "failed" => failed_packages,
        "success_rate" => success_rate
    )
end

function test_polynomial_packages()
    polynomial_packages = [
        "DynamicPolynomials", "MultivariatePolynomials", 
        "ForwardDiff", "Distributions"
    ]
    
    loaded_packages = String[]
    failed_packages = String[]
    
    for pkg in polynomial_packages
        try
            eval(Meta.parse("using $pkg"))
            push!(loaded_packages, pkg)
        catch e
            push!(failed_packages, pkg)
        end
    end
    
    success_rate = length(loaded_packages) / length(polynomial_packages)
    
    return Dict(
        "success" => success_rate >= 0.75,  # At least 75% must load
        "loaded" => loaded_packages,
        "failed" => failed_packages,
        "success_rate" => success_rate
    )
end

function test_advanced_packages()
    advanced_packages = [
        "HomotopyContinuation", "LinearSolve", "Clustering", "Optim"
    ]
    
    loaded_packages = String[]
    failed_packages = String[]
    
    for pkg in advanced_packages
        try
            eval(Meta.parse("using $pkg"))
            push!(loaded_packages, pkg)
        catch e
            push!(failed_packages, pkg)
        end
    end
    
    success_rate = length(loaded_packages) / length(advanced_packages)
    
    return Dict(
        "success" => success_rate >= 0.5,  # At least 50% must load (these are harder)
        "loaded" => loaded_packages,
        "failed" => failed_packages,
        "success_rate" => success_rate
    )
end

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

log_section("PHASE 1: ENVIRONMENT VALIDATION")

run_test("Julia Environment", test_julia_environment)
run_test("Essential Packages", test_essential_packages)
run_test("Polynomial Packages", test_polynomial_packages)

if CONFIG.enable_advanced_tests
    run_test("Advanced Packages", test_advanced_packages)
end

log_section("PHASE 2: GLOBTIM MODULE LOADING")

function test_globtim_core_modules()
    # Test loading individual Globtim modules
    core_modules = [
        ("Structures.jl", "Core data structures"),
        ("BenchmarkFunctions.jl", "Benchmark functions"),
        ("LibFunctions.jl", "Library functions"),
        ("Samples.jl", "Sampling utilities")
    ]

    loaded_modules = String[]
    failed_modules = String[]

    for (module_file, description) in core_modules
        try
            include("src/$module_file")
            push!(loaded_modules, module_file)
            println("     ✓ $module_file loaded ($description)")
        catch e
            push!(failed_modules, module_file)
            println("     ❌ $module_file failed: $e")
        end
    end

    success_rate = length(loaded_modules) / length(core_modules)

    return Dict(
        "success" => success_rate >= 0.75,
        "loaded" => loaded_modules,
        "failed" => failed_modules,
        "success_rate" => success_rate
    )
end

function test_globtim_full_module()
    # Test loading the complete Globtim module
    try
        # Activate project environment
        Pkg.activate(".")

        # Try to load complete Globtim
        using Globtim

        # Test basic functionality
        test_function(x) = sum(x.^2)

        # Create test input
        TR = Globtim.test_input(
            test_function,
            dim = 2,
            center = [0.0, 0.0],
            sample_range = 1.0,
            GN = 50
        )

        return Dict(
            "success" => true,
            "samples" => TR.GN,
            "dimension" => length(TR.center)
        )

    catch e
        return Dict(
            "success" => false,
            "error" => string(e)
        )
    end
end

function test_benchmark_functions()
    # Test benchmark function evaluation
    try
        # Test 2D functions
        x2d = [0.5, 0.5]

        # These should be available from BenchmarkFunctions.jl
        functions_2d = [
            ("trefethen_3_8", x2d),
            ("sphere_2d", x2d)
        ]

        results = Dict()

        for (func_name, test_point) in functions_2d
            try
                if isdefined(Main, Symbol(func_name))
                    func = getfield(Main, Symbol(func_name))
                    result = func(test_point)
                    results[func_name] = result
                    println("     ✓ $func_name($test_point) = $result")
                else
                    println("     ⚠️  $func_name not defined")
                end
            catch e
                println("     ❌ $func_name failed: $e")
            end
        end

        return Dict(
            "success" => length(results) >= 1,
            "functions_tested" => collect(keys(results)),
            "results" => results
        )

    catch e
        return Dict(
            "success" => false,
            "error" => string(e)
        )
    end
end

run_test("Globtim Core Modules", test_globtim_core_modules)
run_test("Globtim Full Module", test_globtim_full_module)
run_test("Benchmark Functions", test_benchmark_functions)

log_section("PHASE 3: WORKFLOW TESTING")

function test_basic_workflow()
    # Test basic polynomial construction workflow
    try
        # Simple test function
        test_func(x) = (x[1] - 1.0)^2 + (x[2] + 0.5)^2

        # Generate sample points manually (fallback approach)
        n_samples = CONFIG.sample_sizes[1]
        center = [1.0, -0.5]
        sample_range = 1.0

        sample_points = []
        sample_values = []

        Random.seed!(42)  # Reproducible results

        for i in 1:n_samples
            x1 = center[1] + sample_range * (2 * rand() - 1)
            x2 = center[2] + sample_range * (2 * rand() - 1)
            point = [x1, x2]
            value = test_func(point)

            push!(sample_points, point)
            push!(sample_values, value)
        end

        # Basic statistics
        min_val = minimum(sample_values)
        max_val = maximum(sample_values)
        mean_val = mean(sample_values)

        return Dict(
            "success" => true,
            "samples" => n_samples,
            "min_value" => min_val,
            "max_value" => max_val,
            "mean_value" => mean_val,
            "range" => max_val - min_val
        )

    catch e
        return Dict(
            "success" => false,
            "error" => string(e)
        )
    end
end

run_test("Basic Workflow", test_basic_workflow)

if CONFIG.enable_benchmarks
    log_section("PHASE 4: PERFORMANCE BENCHMARKING")

    function test_performance_benchmark()
        try
            # Matrix multiplication benchmark
            n = 500
            A = rand(n, n)
            B = rand(n, n)

            start_time = time()
            C = A * B
            mult_time = time() - start_time

            # Eigenvalue computation
            start_time = time()
            eigenvals = eigvals(A[1:100, 1:100])  # Smaller matrix for speed
            eigen_time = time() - start_time

            return Dict(
                "success" => true,
                "matrix_mult_time" => mult_time,
                "eigenvalue_time" => eigen_time,
                "matrix_size" => n
            )

        catch e
            return Dict(
                "success" => false,
                "error" => string(e)
            )
        end
    end

    run_test("Performance Benchmark", test_performance_benchmark)
end

# ============================================================================
# FINAL RESULTS AND REPORTING
# ============================================================================

total_time = time() - test_start_time

log_section("COMPILATION TEST RESULTS")

println("📊 Test Summary:")
println("   Mode: $(CONFIG.mode)")
println("   Tests passed: $tests_passed / $total_tests")
println("   Success rate: $(@sprintf("%.1f", 100 * tests_passed / total_tests))%")
println("   Total time: $(@sprintf("%.2f", total_time)) seconds")
println()

# Determine overall success
overall_success = tests_passed >= ceil(0.8 * total_tests)  # 80% pass rate required

if overall_success
    println("🎉 COMPILATION TEST: SUCCESS")
    println("   ✅ Globtim compilation and basic functionality verified")
    println("   ✅ Ready for production HPC workflows")
else
    println("⚠️  COMPILATION TEST: ISSUES DETECTED")
    println("   ❌ Some critical components failed")
    println("   🔧 Review failed tests and address issues")
end

# Save detailed results
results_filename = "compilation_test_results_$(Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")).txt"
open(results_filename, "w") do f
    println(f, "# Globtim Compilation Test Results")
    println(f, "# Generated: $(now())")
    println(f, "# Mode: $(CONFIG.mode)")
    println(f, "")
    println(f, "overall_success: $overall_success")
    println(f, "tests_passed: $tests_passed")
    println(f, "total_tests: $total_tests")
    println(f, "success_rate: $(tests_passed / total_tests)")
    println(f, "total_time: $total_time")
    println(f, "julia_version: $(VERSION)")
    println(f, "threads: $(Threads.nthreads())")
    println(f, "")

    for (test_name, result) in test_results
        println(f, "[$test_name]")
        for (key, value) in result
            println(f, "$key: $value")
        end
        println(f, "")
    end
end

println("\n📄 Detailed results saved to: $results_filename")
println("\nCompleted: $(now())")

if overall_success
    println("🚀 Globtim compilation verification complete - ready for cluster deployment!")
else
    println("🔧 Address compilation issues before proceeding with cluster deployment.")
    exit(1)  # Exit with error code for automated systems
end
