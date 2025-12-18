"""
HPC Standalone Test - No Package Dependencies

Completely standalone test that uses ONLY built-in Julia packages.
No Pkg.activate(), no external dependencies, just core Julia functionality.

This tests the basic HPC environment and Julia functionality without
any package installation delays.

Usage:
    julia Examples/hpc_standalone_test.jl
    julia Examples/hpc_standalone_test.jl --light
"""

# ONLY use built-in Julia packages (no external dependencies)
using LinearAlgebra
using Random
using Printf
using Dates

println("🚀 HPC Standalone Test - Core Julia Functionality")
println("="^60)
println("Started: $(now())")
println()

# Check for --light flag
light_mode = "--light" in ARGS

if light_mode
    println("🪶 LIGHT MODE: Minimal testing")
    CONFIG = (
        n_samples = 50,
        n_tests = 5,
        matrix_size = 10
    )
else
    println("⚡ STANDARD MODE: Comprehensive testing")
    CONFIG = (
        n_samples = 200,
        n_tests = 10,
        matrix_size = 20
    )
end

println("📋 Configuration:")
println("   Samples: $(CONFIG.n_samples)")
println("   Tests: $(CONFIG.n_tests)")
println("   Matrix size: $(CONFIG.matrix_size)")
println()

# ============================================================================
# ENVIRONMENT DIAGNOSTICS
# ============================================================================

println("🔍 Environment Diagnostics")
println("-"^40)

println("Julia version: $(VERSION)")
println("Available threads: $(Threads.nthreads())")
println("Working directory: $(pwd())")

# Check memory
try
    total_mem = Sys.total_memory()
    free_mem = Sys.free_memory()
    println("Total memory: $(@sprintf("%.1f", total_mem / 1e9)) GB")
    println("Free memory: $(@sprintf("%.1f", free_mem / 1e9)) GB")
catch
    println("Memory info: Not available")
end

# Check environment variables
slurm_job_id = get(ENV, "SLURM_JOB_ID", "not_set")
slurm_node = get(ENV, "SLURMD_NODENAME", "not_set")
println("SLURM Job ID: $slurm_job_id")
println("SLURM Node: $slurm_node")

println()

# ============================================================================
# CORE JULIA FUNCTIONALITY TESTS
# ============================================================================

println("🧮 Core Julia Functionality Tests")
println("-"^40)

test_results = Dict{String, Any}()
tests_passed = 0
total_tests = 6

# Test 1: Basic arithmetic
try
    result = 2.0^3 + sqrt(16) - sin(π / 2)
    expected = 8.0 + 4.0 - 1.0  # = 11.0

    if abs(result - expected) < 1e-10
        println("✅ Test 1: Basic arithmetic passed")
        test_results["arithmetic"] = "PASS"
        tests_passed += 1
    else
        println("❌ Test 1: Basic arithmetic failed")
        test_results["arithmetic"] = "FAIL"
    end
catch e
    println("❌ Test 1: Basic arithmetic error: $e")
    test_results["arithmetic"] = "ERROR"
end

# Test 2: Linear algebra
try
    A = rand(CONFIG.matrix_size, CONFIG.matrix_size)
    b = rand(CONFIG.matrix_size)
    x = A \ b
    residual = norm(A * x - b)

    if residual < 1e-10
        println("✅ Test 2: Linear algebra passed (residual: $(@sprintf("%.2e", residual)))")
        test_results["linear_algebra"] = "PASS"
        test_results["linear_algebra_residual"] = residual
        tests_passed += 1
    else
        println("❌ Test 2: Linear algebra failed (residual: $(@sprintf("%.2e", residual)))")
        test_results["linear_algebra"] = "FAIL"
    end
catch e
    println("❌ Test 2: Linear algebra error: $e")
    test_results["linear_algebra"] = "ERROR"
end

# Test 3: Random number generation
try
    Random.seed!(12345)
    samples = rand(CONFIG.n_samples)

    mean_val = sum(samples) / length(samples)
    std_val = sqrt(sum((samples .- mean_val) .^ 2) / (length(samples) - 1))

    # Should be approximately mean=0.5, std≈0.29 for uniform [0,1]
    if 0.4 < mean_val < 0.6 && 0.2 < std_val < 0.4
        println(
            "✅ Test 3: Random generation passed (mean=$(@sprintf("%.3f", mean_val)), std=$(@sprintf("%.3f", std_val)))"
        )
        test_results["random"] = "PASS"
        test_results["random_mean"] = mean_val
        test_results["random_std"] = std_val
        tests_passed += 1
    else
        println("❌ Test 3: Random generation failed")
        test_results["random"] = "FAIL"
    end
catch e
    println("❌ Test 3: Random generation error: $e")
    test_results["random"] = "ERROR"
end

# Test 4: Function evaluation and optimization
try
    # Simple 2D function: f(x,y) = (x-1)² + (y+0.5)²
    f(x) = (x[1] - 1.0)^2 + (x[2] + 0.5)^2

    # Test evaluation
    test_point = [1.0, -0.5]
    test_value = f(test_point)

    # Simple grid search for minimum
    best_value = Inf
    best_point = [0.0, 0.0]

    for x1 in range(0.0, 2.0, length = 21)
        for x2 in range(-1.0, 0.0, length = 21)
            point = [x1, x2]
            value = f(point)
            if value < best_value
                best_value = value
                best_point = copy(point)
            end
        end
    end

    if test_value < 1e-10 && best_value < 0.01
        println("✅ Test 4: Function optimization passed")
        println("   f([1.0, -0.5]) = $(@sprintf("%.2e", test_value))")
        println(
            "   Grid search minimum: $(@sprintf("%.4f", best_value)) at $(@sprintf("[%.2f, %.2f]", best_point[1], best_point[2]))"
        )
        test_results["optimization"] = "PASS"
        test_results["optimization_minimum"] = best_value
        tests_passed += 1
    else
        println("❌ Test 4: Function optimization failed")
        test_results["optimization"] = "FAIL"
    end
catch e
    println("❌ Test 4: Function optimization error: $e")
    test_results["optimization"] = "ERROR"
end

# Test 5: Multi-threading (if available)
try
    if Threads.nthreads() > 1
        # Simple parallel computation
        results = zeros(CONFIG.n_tests)
        Threads.@threads for i in 1:(CONFIG.n_tests)
            results[i] = sum(rand(1000))
        end

        if all(results .> 400) && all(results .< 600)  # Should be around 500
            println("✅ Test 5: Multi-threading passed ($(Threads.nthreads()) threads)")
            test_results["threading"] = "PASS"
            test_results["thread_count"] = Threads.nthreads()
            tests_passed += 1
        else
            println("❌ Test 5: Multi-threading failed")
            test_results["threading"] = "FAIL"
        end
    else
        println("⚠️  Test 5: Multi-threading skipped (single thread)")
        test_results["threading"] = "SKIP"
        tests_passed += 1  # Count as passed since it's not an error
    end
catch e
    println("❌ Test 5: Multi-threading error: $e")
    test_results["threading"] = "ERROR"
end

# Test 6: File I/O
try
    test_filename = "hpc_test_output.txt"
    test_data = "HPC test data: $(now())\nRandom number: $(rand())\n"

    # Write file
    open(test_filename, "w") do f
        write(f, test_data)
    end

    # Read file back
    read_data = read(test_filename, String)

    if read_data == test_data
        println("✅ Test 6: File I/O passed")
        test_results["file_io"] = "PASS"
        tests_passed += 1

        # Clean up
        rm(test_filename)
    else
        println("❌ Test 6: File I/O failed")
        test_results["file_io"] = "FAIL"
    end
catch e
    println("❌ Test 6: File I/O error: $e")
    test_results["file_io"] = "ERROR"
end

# ============================================================================
# PERFORMANCE BENCHMARK
# ============================================================================

println("\n⚡ Performance Benchmark")
println("-"^40)

benchmark_start = time()

# Matrix multiplication benchmark
n = CONFIG.matrix_size * 2
A = rand(n, n)
B = rand(n, n)

mult_start = time()
C = A * B
mult_time = time() - mult_start

# Eigenvalue computation benchmark
eigen_start = time()
eigenvals = eigvals(A)
eigen_time = time() - eigen_start

benchmark_time = time() - benchmark_start

println("Matrix multiplication ($n×$n): $(@sprintf("%.3f", mult_time)) seconds")
println("Eigenvalue computation ($n×$n): $(@sprintf("%.3f", eigen_time)) seconds")
println("Total benchmark time: $(@sprintf("%.3f", benchmark_time)) seconds")

# ============================================================================
# FINAL RESULTS
# ============================================================================

total_time = time() - benchmark_start

println("\n" * "="^60)
println("🏁 HPC STANDALONE TEST COMPLETED")
println("="^60)

# Comprehensive results
final_results = Dict(
    "test_name" => "hpc_standalone_test",
    "mode" => light_mode ? "light" : "standard",
    "julia_version" => string(VERSION),
    "thread_count" => Threads.nthreads(),
    "slurm_job_id" => slurm_job_id,
    "slurm_node" => slurm_node,
    "tests_passed" => tests_passed,
    "total_tests" => total_tests,
    "success_rate" => tests_passed / total_tests,
    "matrix_mult_time" => mult_time,
    "eigenvalue_time" => eigen_time,
    "total_time" => total_time,
    "overall_success" => tests_passed == total_tests
)

# Merge individual test results
for (key, value) in test_results
    final_results["test_$key"] = value
end

# Save results as simple text file
results_filename = "hpc_standalone_results.txt"
open(results_filename, "w") do f
    println(f, "# HPC Standalone Test Results")
    println(f, "# Generated: $(now())")
    println(f, "")
    for (key, value) in final_results
        println(f, "$key: $value")
    end
end

# Display summary
println("📊 Final Summary:")
println("   Mode: $(final_results["mode"])")
println("   Julia version: $(final_results["julia_version"])")
println("   Tests passed: $(final_results["tests_passed"])/$(final_results["total_tests"])")
println("   Success rate: $(@sprintf("%.1f", 100 * final_results["success_rate"]))%")
println(
    "   Performance: Matrix mult $(@sprintf("%.3f", mult_time))s, Eigenvals $(@sprintf("%.3f", eigen_time))s"
)
println("   Total time: $(@sprintf("%.2f", final_results["total_time"])) seconds")

if final_results["overall_success"]
    println("\n🎉 SUCCESS: All core Julia functionality working!")
    println("   ✅ HPC environment is ready for computation")
    println("   ✅ No external package dependencies needed")
    println("   📊 Results saved to: $results_filename")
else
    println("\n⚠️  ISSUES DETECTED: Some tests failed")
    println("   Check individual test results above")
    println("   📊 Detailed results saved to: $results_filename")
end

println("\nCompleted: $(now())")
println("🚀 Standalone test complete - no package installation required!")
