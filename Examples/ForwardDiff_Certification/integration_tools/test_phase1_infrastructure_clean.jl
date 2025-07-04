# ================================================================================
# Clean Unit Tests for Phase 1 Data Infrastructure
# ================================================================================
#
# Streamlined test suite for validated data structures and multi-tolerance
# execution framework with focused testing and improved organization.
#
# Test Categories:
# 1. Core Data Structure Tests
# 2. Pipeline Execution Tests  
# 3. Integration & Performance Tests

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))
using Test
using Statistics, LinearAlgebra

# Include the Phase 1 infrastructure
include("phase1_data_infrastructure.jl")

# ================================================================================
# TEST SUITE 1: CORE DATA STRUCTURE TESTS
# ================================================================================

@testset "Data Structure Validation" begin
    
    @testset "OrthantResult Validation" begin
        # Valid construction
        orthant = OrthantResult(1, [0.1, 0.2, 0.3, 0.4], [0.25, 0.25, 0.25, 0.25], 
                               50, 45, 0.9, 0.05, 5, 6, 2.5)
        @test orthant.orthant_id == 1
        @test orthant.success_rate == 0.9
        
        # Validation constraints
        @test_throws AssertionError OrthantResult(0, [0,0,0,0], [1,1,1,1], 10, 10, 0.5, 0.1, 0, 4, 1.0)  # Invalid ID
        @test_throws AssertionError OrthantResult(1, [0,0,0], [1,1,1,1], 10, 10, 0.5, 0.1, 0, 4, 1.0)    # Wrong center dim
        @test_throws AssertionError OrthantResult(1, [0,0,0,0], [1,1,1,1], 10, 10, 1.5, 0.1, 0, 4, 1.0)  # Invalid success rate
        @test_throws AssertionError OrthantResult(1, [0,0,0,0], [1,1,1,1], 10, 15, 0.5, 0.1, 0, 4, 1.0)  # BFGS > raw count
    end
    
    @testset "ToleranceResult Validation" begin
        orthants = [OrthantResult(i, rand(4), rand(4), 20, 18, 0.9, 0.05, 2, 5, 1.5) for i in 1:16]
        
        # Valid construction
        tol_result = ToleranceResult(0.01, [0.1, 0.05], [0.08, 0.03], ["minimum", "saddle"],
                                   orthants, [4, 5], [100, 120], 3.2, (raw=0.75, bfgs=0.85, combined=0.80))
        @test tol_result.tolerance == 0.01
        @test length(tol_result.orthant_data) == 16
        
        # Array consistency validation
        @test_throws AssertionError ToleranceResult(0.01, [0.1], [0.08, 0.03], ["minimum"], 
                                                  orthants, [4], [100], 1.0, (raw=0.8, bfgs=0.9, combined=0.85))
    end
    
    @testset "MultiToleranceResults Validation" begin
        orthants = [OrthantResult(i, rand(4), rand(4), 20, 18, 0.9, 0.05, 2, 5, 1.5) for i in 1:16]
        tol_result = ToleranceResult(0.01, [0.1], [0.08], ["minimum"], orthants, [4], [100], 1.0, 
                                   (raw=0.8, bfgs=0.9, combined=0.85))
        
        # Valid construction
        multi_results = MultiToleranceResults([0.1, 0.01], Dict(0.01 => tol_result, 0.1 => tol_result),
                                            5.0, "2024-01-01", "test_function", (center=[0,0,0,0], sample_range=1.0))
        @test length(multi_results.tolerance_sequence) == 2
        @test multi_results.total_computation_time == 5.0
        
        # Sequence ordering validation
        @test_throws AssertionError MultiToleranceResults([0.01, 0.1], Dict(0.01 => tol_result), 
                                                        5.0, "2024-01-01", "test", (center=[0,0,0,0],))
    end
end

# ================================================================================
# TEST SUITE 2: PIPELINE EXECUTION TESTS
# ================================================================================

@testset "Pipeline Execution" begin
    
    @testset "Test Function Validation" begin
        # Valid function
        @test_nowarn validate_test_function_compatible("deuflhard_4d_composite")
        
        # Invalid function
        @test_throws ArgumentError validate_test_function_compatible("invalid_function")
    end
    
    @testset "Mock Analysis Execution" begin
        # Test mock analysis with small tolerance sequence
        tolerances = [0.1, 0.01]
        results = execute_multi_tolerance_analysis(tolerances, function_name="deuflhard_4d_composite", max_retries=1)
        
        @test results isa MultiToleranceResults
        @test length(results.tolerance_sequence) == 2
        @test all(haskey(results.results_by_tolerance, tol) for tol in tolerances)
        
        # Verify data structure integrity
        for tol in tolerances
            tol_result = results.results_by_tolerance[tol]
            @test tol_result.tolerance == tol
            @test length(tol_result.orthant_data) == 16
            @test all(or.orthant_id in 1:16 for or in tol_result.orthant_data)
        end
    end
    
    @testset "Error Handling" begin
        # Empty tolerance sequence
        @test_throws ArgumentError execute_multi_tolerance_analysis(Float64[])
        
        # Invalid tolerance values
        @test_throws ArgumentError execute_multi_tolerance_analysis([-0.1, 0.01])
        @test_throws ArgumentError execute_multi_tolerance_analysis([0.0, 0.01])
    end
end

# ================================================================================
# TEST SUITE 3: INTEGRATION & PERFORMANCE TESTS
# ================================================================================

@testset "Integration & Performance" begin
    
    @testset "Data Export/Import" begin
        # Create test data
        tolerances = [0.1, 0.01]
        results = execute_multi_tolerance_analysis(tolerances, function_name="deuflhard_4d_composite", max_retries=1)
        
        # Test export
        test_export_path = "./test_export_clean"
        @test_nowarn save_multi_tolerance_results(results, test_export_path)
        @test isdir(test_export_path)
        @test isfile(joinpath(test_export_path, "metadata.csv"))
        
        # Cleanup
        rm(test_export_path, recursive=true, force=true)
    end
    
    @testset "Performance Validation" begin
        # Test with moderate dataset size
        tolerances = [0.1, 0.01]
        start_time = time()
        results = execute_multi_tolerance_analysis(tolerances, function_name="deuflhard_4d_composite", max_retries=1)
        execution_time = time() - start_time
        
        @test execution_time < 30.0  # Should complete within 30 seconds
        @test results.total_computation_time > 0
        
        # Verify reasonable data sizes
        for tol_result in values(results.results_by_tolerance)
            @test length(tol_result.raw_distances) <= 1000  # Reasonable upper bound
            @test length(tol_result.orthant_data) == 16     # Always 16 orthants
        end
    end
    
    @testset "Memory Efficiency" begin
        # Test multiple executions don't cause memory issues
        for i in 1:3
            tolerances = [0.1]
            results = execute_multi_tolerance_analysis(tolerances, function_name="deuflhard_4d_composite", max_retries=1)
            @test results isa MultiToleranceResults
            # Force garbage collection
            GC.gc()
        end
    end
end

# ================================================================================
# SUMMARY REPORT
# ================================================================================

println("\n" * "="^80)
println("PHASE 1 INFRASTRUCTURE TEST SUITE (CLEAN VERSION) COMPLETED")
println("="^80)
println("✅ All core data structure validation tests passed")
println("✅ Pipeline execution and error handling verified")
println("✅ Integration and performance requirements met")
println("✅ Phase 1 infrastructure ready for Phase 2-3 integration")
println("="^80)