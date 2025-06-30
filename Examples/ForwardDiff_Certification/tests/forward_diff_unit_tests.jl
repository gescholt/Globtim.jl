# ForwardDiff Unit Tests for Phase 2 Hessian Analysis
#
# Comprehensive unit tests for ForwardDiff integration and Hessian computation
# This file tests the core mathematical correctness of Phase 2 functionality

# Proper initialization for examples
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames
using Test
using BenchmarkTools

println("=== ForwardDiff Unit Tests for Phase 2 ===\n")

# Test 1: Basic Hessian computation accuracy
println("Test 1: Hessian Computation Accuracy")
println("-"^40)

@testset "Hessian Computation Tests" begin
    # Simple quadratic function: f(x) = x₁² + 2x₂²
    # Expected Hessian: [2 0; 0 4]
    f_quad(x) = x[1]^2 + 2*x[2]^2
    test_points = [0.0 0.0; 1.0 1.0; -1.0 0.5]
    
    println("Testing quadratic function f(x) = x₁² + 2x₂²")
    hessians = compute_hessians(f_quad, test_points)
    
    @test length(hessians) == 3
    @test size(hessians[1]) == (2, 2)
    
    # All points should have same Hessian for quadratic
    expected_H = [2.0 0.0; 0.0 4.0]
    for i in 1:3
        @test isapprox(hessians[i], expected_H, atol=1e-10)
        println("  Point $i: $(test_points[i, :]) -> Hessian correct ✓")
    end
    
    # Test cross-terms: f(x) = x₁x₂
    # Expected Hessian: [0 1; 1 0]
    f_cross(x) = x[1] * x[2]
    hessians_cross = compute_hessians(f_cross, [0.0 0.0; 1.0 1.0])
    expected_H_cross = [0.0 1.0; 1.0 0.0]
    
    println("Testing cross-term function f(x) = x₁x₂")
    for i in 1:2
        @test isapprox(hessians_cross[i], expected_H_cross, atol=1e-10)
        println("  Point $i: Hessian correct ✓")
    end
end

# Test 2: Critical point classification
println("\nTest 2: Critical Point Classification")
println("-"^40)

@testset "Classification Tests" begin
    # Create test Hessian matrices with known properties
    H_minimum = [2.0 0.0; 0.0 3.0]        # Positive definite
    H_maximum = [-2.0 0.0; 0.0 -3.0]      # Negative definite  
    H_saddle = [2.0 0.0; 0.0 -3.0]        # Indefinite
    H_degenerate = [2.0 0.0; 0.0 0.0]     # Singular
    H_error = [NaN NaN; NaN NaN]          # Error case
    
    test_hessians = [H_minimum, H_maximum, H_saddle, H_degenerate, H_error]
    expected_types = [:minimum, :maximum, :saddle, :degenerate, :error]
    
    classifications = classify_critical_points(test_hessians)
    
    for (i, (expected, actual)) in enumerate(zip(expected_types, classifications))
        @test actual == expected
        println("  Matrix $i: Expected $expected, Got $actual ✓")
    end
end

# Test 3: Eigenvalue statistics computation
println("\nTest 3: Eigenvalue Statistics")
println("-"^40)

@testset "Eigenvalue Statistics Tests" begin
    # Test matrices with known eigenvalues
    H1 = [2.0 0.0; 0.0 3.0]  # Eigenvalues: 2, 3
    H2 = [-1.0 0.0; 0.0 -2.0]  # Eigenvalues: -1, -2
    test_hessians = [H1, H2]
    
    stats = compute_eigenvalue_stats(test_hessians)
    
    # Test H1 (positive definite)
    @test isapprox(stats.eigenvalue_min[1], 2.0, atol=1e-10)
    @test isapprox(stats.eigenvalue_max[1], 3.0, atol=1e-10)
    @test isapprox(stats.condition_number[1], 3.0/2.0, atol=1e-10)
    @test isapprox(stats.determinant[1], 6.0, atol=1e-10)
    @test isapprox(stats.trace[1], 5.0, atol=1e-10)
    println("  Matrix 1 (positive definite): All statistics correct ✓")
    
    # Test H2 (negative definite)
    @test isapprox(stats.eigenvalue_min[2], -2.0, atol=1e-10)
    @test isapprox(stats.eigenvalue_max[2], -1.0, atol=1e-10)
    @test isapprox(stats.condition_number[2], 2.0/1.0, atol=1e-10)
    @test isapprox(stats.determinant[2], 2.0, atol=1e-10)
    @test isapprox(stats.trace[2], -3.0, atol=1e-10)
    println("  Matrix 2 (negative definite): All statistics correct ✓")
end

# Test 4: Critical eigenvalue extraction
println("\nTest 4: Critical Eigenvalue Extraction")
println("-"^40)

@testset "Critical Eigenvalue Tests" begin
    classifications = [:minimum, :maximum, :saddle, :degenerate]
    all_eigenvalues = [
        [2.0, 3.0],      # minimum - all positive
        [-2.0, -1.0],    # maximum - all negative
        [-1.0, 2.0],     # saddle - mixed signs
        [0.0, 2.0]       # degenerate - has zero
    ]
    
    smallest_pos, largest_neg = extract_critical_eigenvalues(classifications, all_eigenvalues)
    
    # Test minimum: should have smallest positive eigenvalue
    @test isapprox(smallest_pos[1], 2.0, atol=1e-10)
    @test isnan(smallest_pos[2])  # maximum shouldn't have positive eigenvalue
    @test isnan(smallest_pos[3])  # saddle - ambiguous
    @test isnan(smallest_pos[4])  # degenerate - ambiguous
    println("  Smallest positive eigenvalues: correct ✓")
    
    # Test maximum: should have largest negative eigenvalue
    @test isnan(largest_neg[1])  # minimum shouldn't have negative eigenvalue
    @test isapprox(largest_neg[2], -1.0, atol=1e-10)
    @test isnan(largest_neg[3])  # saddle - ambiguous
    @test isnan(largest_neg[4])  # degenerate - ambiguous
    println("  Largest negative eigenvalues: correct ✓")
end

# Test 5: Performance benchmarks
println("\nTest 5: Performance Benchmarks")
println("-"^40)

@testset "Performance Tests" begin
    # Test scalability with problem size
    problem_sizes = [2, 3, 4, 5]
    
    for n in problem_sizes
        # Create test function and points
        f_test(x) = sum(x.^2)  # Simple quadratic
        test_points = randn(10, n)  # 10 random points in n dimensions
        
        # Benchmark Hessian computation
        time_result = @benchmark compute_hessians($f_test, $test_points) samples=5 evals=1
        avg_time = mean(time_result.times) / 1e6  # Convert to milliseconds
        
        println("  Dimension $n: $(round(avg_time, digits=2)) ms for 10 points")
        
        # Test that time scaling is reasonable (should be roughly O(n²))
        @test avg_time < 1000.0  # Should complete within 1 second
        
        # Test memory allocation
        alloc_result = @benchmark compute_hessians($f_test, $test_points) samples=3 evals=1
        avg_alloc = mean(alloc_result.memory) / 1024  # Convert to KB
        println("    Memory: $(round(avg_alloc, digits=2)) KB")
    end
end

# Test 6: Error handling and edge cases
println("\nTest 6: Error Handling")
println("-"^40)

@testset "Error Handling Tests" begin
    # Test with problematic function
    f_problematic(x) = x[1]^4 - x[1]^2  # Has flat regions
    
    # Test points near problematic regions
    problematic_points = [0.0 0.0; 1e-15 1e-15; 1e15 1e15]
    
    # Should not throw errors
    hessians = compute_hessians(f_problematic, problematic_points)
    @test length(hessians) == 3
    
    all_eigenvalues = store_all_eigenvalues(hessians)
    @test length(all_eigenvalues) == 3
    
    classifications = classify_critical_points(hessians)
    @test length(classifications) == 3
    @test all(c -> c in [:minimum, :maximum, :saddle, :degenerate, :error], classifications)
    
    println("  Problematic function handling: ✓")
    
    # Test with NaN inputs
    nan_points = [NaN NaN; 0.0 0.0]
    hessians_nan = compute_hessians(f_problematic, nan_points)
    @test any(isnan, hessians_nan[1])  # First should have NaN
    @test !any(isnan, hessians_nan[2])  # Second should be valid
    
    println("  NaN input handling: ✓")
    
    # Test empty input
    empty_points = Matrix{Float64}(undef, 0, 2)
    hessians_empty = compute_hessians(f_problematic, empty_points)
    @test length(hessians_empty) == 0
    
    println("  Empty input handling: ✓")
end

# Test 7: Integration with full workflow
println("\nTest 7: Full Workflow Integration")
println("-"^40)

@testset "Integration Tests" begin
    # Test complete workflow
    f_simple(x) = (x[1] - 1)^2 + (x[2] + 0.5)^2  # Simple quadratic with minimum at (1, -0.5)
    
    TR = test_input(f_simple, dim=2, center=[1.0, -0.5], sample_range=2.0)
    pol = Constructor(TR, 6)
    @polyvar x[1:2]
    solutions = solve_polynomial_system(x, 2, 6, pol.coeffs)
    df = process_crit_pts(solutions, f_simple, TR)
    
    # Test with Phase 2 enabled
    df_enhanced, df_min = analyze_critical_points(f_simple, df, TR, enable_hessian=true, verbose=false)
    
    # Check that Phase 2 columns exist
    phase2_columns = [
        "critical_point_type", "smallest_positive_eigenval", "largest_negative_eigenval",
        "hessian_norm", "hessian_eigenvalue_min", "hessian_eigenvalue_max", 
        "hessian_condition_number", "hessian_determinant", "hessian_trace"
    ]
    
    for col in phase2_columns
        @test col in string.(names(df_enhanced))
        println("  Column '$col': present ✓")
    end
    
    # Should find at least one minimum
    minima_count = count(df_enhanced.critical_point_type .== :minimum)
    @test minima_count >= 1
    println("  Found $minima_count minima ✓")
    
    # Test with Phase 2 disabled
    df_phase1, _ = analyze_critical_points(f_simple, df, TR, enable_hessian=false, verbose=false)
    
    # Phase 2 columns should not exist
    @test !("critical_point_type" in string.(names(df_phase1)))
    @test !("hessian_norm" in string.(names(df_phase1)))
    println("  Phase 1 mode: Phase 2 columns correctly absent ✓")
end

println("\n" * "="^50)
println("FORWARDDIFF UNIT TESTS COMPLETE")
println("="^50)
println("All tests passed! ✅")
println("\nTested components:")
println("  • Hessian computation accuracy")
println("  • Critical point classification")
println("  • Eigenvalue statistics")
println("  • Critical eigenvalue extraction")
println("  • Performance benchmarks")
println("  • Error handling and edge cases")
println("  • Full workflow integration")

nothing  # Suppress final output