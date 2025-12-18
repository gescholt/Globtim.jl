#!/usr/bin/env julia
"""
Validation script for Lotka-Volterra 4D experiment setup
========================================================

This script validates:
1. Function evaluations work correctly
2. Domain setup is correct
3. Random offset vectors are properly generated
4. All configurations are valid
5. No errors in the experimental pipeline

Author: GlobTim Project
Date: September 15, 2025
"""

using Pkg
project_root = dirname(dirname(dirname(@__FILE__)))
Pkg.activate(project_root)
Pkg.instantiate()

using LinearAlgebra
using StaticArrays
using Printf
using Random

# Use Dynamic_objectives package for ODE models
using Dynamic_objectives

# Import Globtim after activation
using Globtim

# Set seed for reproducible validation
Random.seed!(42)

# Configuration constants (matching current campaign: lv4d_campaign_2025)
const GN = 16
const DOMAIN_RANGES = [0.4, 0.8, 1.2, 1.6]
const P_TRUE = [0.2, 0.3, 0.5, 0.6]
const IC = [1.0, 2.0, 1.0, 1.0]
const TIME_INTERVAL = [0.0, 10.0]
const NUM_POINTS = 25

println("="^80)
println("Lotka-Volterra 4D Experiment Validation")
println("="^80)

"""
Test 1: Validate Lotka-Volterra 4D model setup
"""
function test_model_setup()
    println("\n📋 Test 1: Model Setup Validation")
    println("-"^50)

    try
        # Test model creation
        model, params, states, outputs = define_daisy_ex3_model_4D()

        println("✓ Model created successfully")
        println("  Parameters: $(length(params)) - $(params)")
        println("  States: $(length(states)) - $(states)")
        println("  Outputs: $(length(outputs)) - $(outputs)")

        # Validate parameter dimensions
        if length(params) == 4
            println("✓ Parameter dimension correct (4)")
        else
            error("❌ Expected 4 parameters, got $(length(params))")
        end

        # Test error function creation
        error_func = make_error_distance(
            model,
            outputs,
            IC,
            P_TRUE,
            TIME_INTERVAL,
            NUM_POINTS,
            L2_norm
        )

        println("✓ Error function created successfully")

        # Test function evaluation at true parameters
        error_at_true = error_func(P_TRUE)
        println("✓ Function evaluates at true parameters")
        println("  Error at true params: $(round(error_at_true, digits=6))")

        if error_at_true < 1e-10
            println("✓ Error at true parameters is near zero ($(error_at_true))")
        else
            @warn "Error at true parameters is not near zero: $(error_at_true)"
        end

        return true, error_func
    catch e
        println("❌ Model setup failed: $e")
        return false, nothing
    end
end

"""
Test 2: Validate random offset vector generation
"""
function test_random_offset_generation()
    println("\n📋 Test 2: Random Offset Vector Generation")
    println("-"^50)

    target_length = sqrt(4 * 0.05^2) / 2
    println("Target offset length: $(round(target_length, digits=6))")

    try
        # Generate multiple offset vectors
        for i in 1:5
            components = randn(4)
            unit_vector = components / norm(components)
            offset_vector = unit_vector * target_length

            actual_length = norm(offset_vector)
            println(
                "  Vector $(i): length = $(round(actual_length, digits=6)), components = $(round.(offset_vector, digits=4))"
            )

            if abs(actual_length - target_length) < 1e-10
                println("    ✓ Length matches target")
            else
                error("❌ Length mismatch: expected $(target_length), got $(actual_length)")
            end
        end

        println("✓ Random offset vector generation working correctly")
        return true
    catch e
        println("❌ Random offset generation failed: $e")
        return false
    end
end

"""
Test 3: Validate domain center calculations
"""
function test_domain_centers()
    println("\n📋 Test 3: Domain Center Calculations")
    println("-"^50)

    target_offset_length = sqrt(4 * 0.05^2) / 2

    try
        for (i, domain_range) in enumerate(DOMAIN_RANGES)
            # Generate offset vector (same method as setup script)
            components = randn(4)
            unit_vector = components / norm(components)
            offset_vector = unit_vector * target_offset_length
            p_center = P_TRUE .+ offset_vector

            println("Experiment $(i) (range $(domain_range)):")
            println("  True params: $(round.(P_TRUE, digits=4))")
            println("  Offset vector: $(round.(offset_vector, digits=4))")
            println("  Domain center: $(round.(p_center, digits=4))")
            println("  Distance from true: $(round(norm(offset_vector), digits=6))")

            # Validate that center is within reasonable bounds
            if all(-1.0 .<= p_center .<= 2.0)
                println("  ✓ Domain center within reasonable bounds")
            else
                @warn "Domain center outside expected bounds: $(p_center)"
            end
        end

        println("✓ Domain center calculations working correctly")
        return true
    catch e
        println("❌ Domain center calculation failed: $e")
        return false
    end
end

"""
Test 4: Validate function evaluations in domains
"""
function test_function_evaluations(error_func)
    println("\n📋 Test 4: Function Evaluation Validation")
    println("-"^50)

    if error_func === nothing
        println("❌ Cannot test - error function not available")
        return false
    end

    try
        # Test evaluations for each domain configuration
        target_offset_length = sqrt(4 * 0.05^2) / 2

        for (i, domain_range) in enumerate(DOMAIN_RANGES)
            println("Testing domain range $(domain_range):")

            # Generate domain center
            components = randn(4)
            unit_vector = components / norm(components)
            offset_vector = unit_vector * target_offset_length
            p_center = P_TRUE .+ offset_vector

            # Test evaluation at center
            error_at_center = error_func(p_center)
            println("  Error at center: $(round(error_at_center, digits=6))")

            # Test evaluation at domain boundaries
            for j in 1:4
                # Create test points at domain boundaries
                test_point_low = copy(p_center)
                test_point_high = copy(p_center)
                test_point_low[j] -= domain_range
                test_point_high[j] += domain_range

                error_low = error_func(test_point_low)
                error_high = error_func(test_point_high)

                println(
                    "  Boundary dim $(j): low=$(round(error_low, digits=6)), high=$(round(error_high, digits=6))"
                )

                # Check for NaN or Inf
                if isnan(error_low) || isinf(error_low) || isnan(error_high) ||
                   isinf(error_high)
                    error("❌ Invalid function values at boundaries")
                end
            end

            # Test random points in domain
            for k in 1:3
                random_point = p_center .+ (2 * rand(4) .- 1) .* domain_range
                error_random = error_func(random_point)
                println(
                    "  Random point $(k): $(round.(random_point, digits=4)) -> $(round(error_random, digits=6))"
                )

                if isnan(error_random) || isinf(error_random)
                    error("❌ Invalid function value at random point")
                end
            end

            println("  ✓ All evaluations successful for domain range $(domain_range)")
        end

        println("✓ Function evaluations working correctly in all domains")
        return true
    catch e
        println("❌ Function evaluation test failed: $e")
        return false
    end
end

"""
Test 5: Validate GN and memory requirements
"""
function test_memory_requirements()
    println("\n📋 Test 5: Memory Requirements Validation")
    println("-"^50)

    try
        # Calculate expected memory usage
        total_grid_points = GN^4
        grid_memory_gb = (total_grid_points) * (4 * 8 + 32) / (1024^3)

        println("GN (samples per dimension): $(GN)")
        println("Total grid points: $(total_grid_points)")
        println("Estimated memory usage: $(round(grid_memory_gb, digits=3)) GB")

        # Validate safe parameters
        if grid_memory_gb <= 10.0
            println("✓ Memory usage within safe limits (<= 10 GB)")
        else
            error("❌ Memory usage too high: $(round(grid_memory_gb, digits=3)) GB")
        end

        if GN <= 15
            println("✓ GN within recommended range for 4D (<= 15)")
        else
            @warn "GN might be too high for stable 4D computation"
        end

        return true
    catch e
        println("❌ Memory validation failed: $e")
        return false
    end
end

"""
Test 6: Quick test_input validation
"""
function test_test_input_function(error_func)
    println("\n📋 Test 6: test_input Function Validation")
    println("-"^50)

    if error_func === nothing
        println("❌ Cannot test - error function not available")
        return false
    end

    try
        # Test with smallest domain range
        domain_range = DOMAIN_RANGES[1]  # 0.05
        components = randn(4)
        unit_vector = components / norm(components)
        offset_vector = unit_vector * sqrt(4 * 0.05^2) / 2
        p_center = P_TRUE .+ offset_vector

        println("Testing test_input with:")
        println("  Domain range: $(domain_range)")
        println("  GN: $(GN)")
        println("  Center: $(round.(p_center, digits=4))")

        # Call test_input
        TR = test_input(
            error_func,
            dim = 4,
            center = p_center,
            GN = GN,
            sample_range = domain_range
        )

        println("✓ test_input completed successfully")
        println("  Generated samples: $(TR.GN)")
        println("  Grid size per dim: $(TR.GN)")

        # Validate TR object
        if hasfield(typeof(TR), :GN) && TR.GN == GN
            println("✓ Sample count matches expected")
        else
            @warn "Sample count mismatch"
        end

        return true
    catch e
        println("❌ test_input validation failed: $e")
        return false
    end
end

# Main validation execution
function main()
    println("Starting comprehensive validation...")

    all_tests_passed = true

    # Run all tests
    test1_passed, error_func = test_model_setup()
    all_tests_passed &= test1_passed

    test2_passed = test_random_offset_generation()
    all_tests_passed &= test2_passed

    test3_passed = test_domain_centers()
    all_tests_passed &= test3_passed

    test4_passed = test_function_evaluations(error_func)
    all_tests_passed &= test4_passed

    test5_passed = test_memory_requirements()
    all_tests_passed &= test5_passed

    test6_passed = test_test_input_function(error_func)
    all_tests_passed &= test6_passed

    # Final summary
    println("\n" * "="^80)
    println("VALIDATION SUMMARY")
    println("="^80)

    if all_tests_passed
        println("🎉 ALL TESTS PASSED! 🎉")
        println()
        println("The Lotka-Volterra 4D experiment setup is validated and ready for:")
        println("  ✓ Function evaluations")
        println("  ✓ Domain setup with random offsets")
        println("  ✓ Memory-safe parameters")
        println("  ✓ Error-free execution pipeline")
        println()
        println("🚀 Ready to proceed with HPC cluster deployment!")
    else
        println("❌ SOME TESTS FAILED")
        println()
        println("Please review the failed tests above before proceeding.")
        println("Do not deploy to HPC until all validation tests pass.")
    end

    println("="^80)

    return all_tests_passed
end

# Execute validation
if abspath(PROGRAM_FILE) == @__FILE__
    success = main()
    exit(success ? 0 : 1)
end
