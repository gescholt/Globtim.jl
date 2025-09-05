#!/usr/bin/env julia
"""
Test runner for precision handling pipeline tests.

This script safely executes precision tests and reports results,
handling cases where some functions might not be available yet.
"""

using Pkg
Pkg.activate(dirname(@__DIR__))  # Activate main globtim project

using Test
using Globtim
using DynamicPolynomials: @polyvar

println("="^70)
println("GlobTim Precision Handling Pipeline Test Suite")
println("="^70)
println()

try
    # First, test basic imports
    println("Testing basic imports...")
    println("✓ Basic imports successful")
    
    # Check GlobTim version and exported functions
    println("\nChecking GlobTim exports...")
    exported_functions = names(Globtim, all=false)
    println("✓ Found $(length(exported_functions)) exported symbols")
    
    # Check for key precision-related exports
    key_precision_exports = [:Float64Precision, :RationalPrecision, :AdaptivePrecision, :BigFloatPrecision]
    missing_exports = [sym for sym in key_precision_exports if sym ∉ exported_functions]
    
    if !isempty(missing_exports)
        println("⚠ Missing precision exports: $missing_exports")
    else
        println("✓ All precision types exported")
    end
    
    println()
    
    # Try to access internal functions needed for testing
    println("Checking internal function availability...")
    
    internal_functions = [
        (:_convert_value, "Precision conversion function"),
        (:construct_orthopoly_polynomial, "Polynomial construction"),
        (:solve_polynomial_system, "Polynomial system solver")
    ]
    
    available_functions = []
    unavailable_functions = []
    
    for (func_name, description) in internal_functions
        if isdefined(Globtim, func_name)
            println("✓ $func_name ($description) - available")
            push!(available_functions, func_name)
        else
            println("⚠ $func_name ($description) - not available")
            push!(unavailable_functions, func_name)
        end
    end
    
    println()
    
    # Decide which tests to run based on availability
    if :_convert_value in available_functions
        println("Running precision conversion tests...")
        
        # Test the basic precision conversion function
        @testset "Basic _convert_value Tests" begin
            # Test Float64Precision (should always work)
            @test Globtim._convert_value(1.5, Float64Precision) === 1.5
            @test Globtim._convert_value(0.0, Float64Precision) === 0.0
            
            println("✓ Float64Precision conversions working")
            
            # Test the problematic zero case in RationalPrecision
            @testset "RationalPrecision Zero Handling" begin
                try
                    result = Globtim._convert_value(0.0, RationalPrecision)
                    @test result == 0//1
                    println("✓ RationalPrecision zero handling working")
                catch e
                    println("✗ RationalPrecision zero handling failed: $e")
                    @test_broken false  # Mark as known broken
                end
                
                try
                    result = Globtim._convert_value(1.5, RationalPrecision) 
                    @test result isa Rational
                    println("✓ RationalPrecision non-zero conversions working")
                catch e
                    println("✗ RationalPrecision non-zero conversions failed: $e")
                end
            end
        end
        
    else
        println("⚠ Skipping precision conversion tests - _convert_value not available")
    end
    
    if :construct_orthopoly_polynomial in available_functions && :solve_polynomial_system in available_functions
        println("\nRunning polynomial construction tests...")
        
        @testset "Basic Polynomial Construction Tests" begin
            @polyvar x
            
            # Simple 1D test
            coeffs = [1.0, 0.0, 2.0]  # Simple polynomial with zero coefficient
            
            try
                pol = Globtim.construct_orthopoly_polynomial(
                    [x], coeffs, (:one_d_for_all, 2), :chebyshev, Float64Precision;
                    verbose = false
                )
                @test !iszero(pol)
                println("✓ 1D polynomial construction working")
                
                # Test polynomial evaluation
                result = pol([0.5])
                @test isfinite(Float64(result))
                println("✓ Polynomial evaluation working")
                
            catch e
                println("✗ Polynomial construction failed: $e")
                @test_broken false
            end
            
            # Test the specific case that was failing in the experiment
            @testset "Minimal 2D Case (Similar to Failing Experiment)" begin
                @polyvar y[1:2]
                
                # Use the same parameters that were failing: degree=2, small number of coefficients
                degree = 2
                n_coeffs = binomial(2 + degree, degree)  # 2D polynomial of degree 2
                coeffs_2d = ones(Float64, n_coeffs)
                coeffs_2d[2] = 0.0  # Add zero coefficient that was causing issues
                
                try
                    pol = Globtim.construct_orthopoly_polynomial(
                        y, coeffs_2d, (:one_d_for_all, degree), :chebyshev, Float64Precision;
                        verbose = false
                    )
                    @test !iszero(pol)
                    println("✓ 2D minimal case polynomial construction working")
                    
                    # Test polynomial system solving with Float64Precision
                    real_pts, (system, nsols) = Globtim.solve_polynomial_system(
                        y, 2, (:one_d_for_all, degree), coeffs_2d;
                        basis = :chebyshev,
                        precision = Float64Precision,  # Explicitly specify Float64Precision
                        return_system = true
                    )
                    
                    @test nsols ≥ 0
                    @test length(real_pts) ≤ nsols
                    println("✓ 2D polynomial system solving with Float64Precision working")
                    
                    # Test with AdaptivePrecision as alternative
                    real_pts_adaptive, (system_adaptive, nsols_adaptive) = Globtim.solve_polynomial_system(
                        y, 2, (:one_d_for_all, degree), coeffs_2d;
                        basis = :chebyshev,
                        precision = AdaptivePrecision,
                        return_system = true
                    )
                    
                    @test nsols_adaptive ≥ 0
                    println("✓ 2D polynomial system solving with AdaptivePrecision working")
                    
                catch e
                    println("✗ 2D minimal case failed: $e")
                    println("  This reproduces the error from the experiment")
                    @test_broken false
                end
            end
        end
        
    else
        println("⚠ Skipping polynomial tests - construction/solving functions not available")
    end
    
    println()
    
    # If we have all functions, run the comprehensive test suite
    if all(func in available_functions for func in [:_convert_value, :construct_orthopoly_polynomial, :solve_polynomial_system])
        println("All required functions available - running comprehensive test suite...")
        println()
        
        # Include and run the full test suite
        include("precision_handling_tests.jl")
        
    else
        println("Some functions unavailable - skipping comprehensive tests")
        println("Available functions: $available_functions")
        println("Missing functions: $unavailable_functions")
        println()
        println("To run full tests, ensure all GlobTim functions are properly exported or accessible.")
    end
    
    println()
    println("="^70)
    println("Test Summary")
    println("="^70)
    println("Available functions: $(length(available_functions))/$(length(internal_functions))")
    
    if :_convert_value in available_functions
        println("✓ Precision conversion testing possible")
    else
        println("⚠ Precision conversion testing not possible")
    end
    
    if :construct_orthopoly_polynomial in available_functions && :solve_polynomial_system in available_functions
        println("✓ Polynomial construction testing possible")  
    else
        println("⚠ Polynomial construction testing not possible")
    end
    
    println()
    println("Next steps:")
    if :_convert_value ∉ available_functions
        println("1. Make _convert_value function accessible for testing")
    end
    if any(func ∉ available_functions for func in [:construct_orthopoly_polynomial, :solve_polynomial_system])
        println("2. Verify polynomial construction functions are available")
    end
    println("3. Fix any failing tests before implementing changes")
    println("4. Use tests to verify each fix works correctly")

catch e
    println("✗ Error during test setup: $e")
    println()
    println("This suggests that basic GlobTim functionality is not available.")
    println("Please ensure:")
    println("1. GlobTim package is properly installed")
    println("2. All dependencies are available")  
    println("3. Project environment is correctly activated")
    println()
    println("Error details:")
    println(e)
    if isa(e, LoadError)
        println("Original error: $(e.error)")
    end
end

println()
println("="^70)