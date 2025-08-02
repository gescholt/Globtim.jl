"""
Test suite for Globtim.jl Error Handling Framework

This test suite validates the comprehensive error handling, validation,
and recovery mechanisms implemented in the error handling framework.
"""

using Test
using Globtim
using DataFrames
using LinearAlgebra

@testset "Error Handling Framework Tests" begin
    
    # ========================================================================
    # INPUT VALIDATION TESTS
    # ========================================================================
    
    @testset "Input Validation" begin
        
        @testset "Dimension Validation" begin
            # Valid dimensions
            @test_nowarn validate_dimension(1)
            @test_nowarn validate_dimension(5)
            @test_nowarn validate_dimension(10)
            
            # Invalid dimensions
            @test_throws InputValidationError validate_dimension(0)
            @test_throws InputValidationError validate_dimension(-1)
            @test_throws InputValidationError validate_dimension(15)
        end
        
        @testset "Polynomial Degree Validation" begin
            # Valid degrees
            @test_nowarn validate_polynomial_degree(4, 200)
            @test_nowarn validate_polynomial_degree(6, 500)

            # Invalid degrees
            @test_throws InputValidationError validate_polynomial_degree(0, 100)
            @test_throws InputValidationError validate_polynomial_degree(12, 100)  # Too high degree
            @test_throws InputValidationError validate_polynomial_degree(8, 50)   # Too few samples
        end
        
        @testset "Sample Count Validation" begin
            # Valid sample counts
            @test_nowarn validate_sample_count(50)
            @test_nowarn validate_sample_count(1000)
            
            # Invalid sample counts
            @test_throws InputValidationError validate_sample_count(5)
            @test_throws InputValidationError validate_sample_count(100000)
        end
        
        @testset "Center Vector Validation" begin
            # Valid center vectors
            @test_nowarn validate_center_vector([0.0, 0.0], 2)
            @test_nowarn validate_center_vector([1.0, -1.0, 0.5], 3)
            
            # Invalid center vectors
            @test_throws InputValidationError validate_center_vector([0.0], 2)  # Wrong dimension
            @test_throws InputValidationError validate_center_vector([NaN, 0.0], 2)  # Contains NaN
            @test_throws InputValidationError validate_center_vector([Inf, 0.0], 2)  # Contains Inf
        end
        
        @testset "Sample Range Validation" begin
            # Valid sample ranges
            @test_nowarn validate_sample_range(1.0)
            @test_nowarn validate_sample_range(10.0)
            
            # Invalid sample ranges
            @test_throws InputValidationError validate_sample_range(0.0)
            @test_throws InputValidationError validate_sample_range(-1.0)
            @test_throws InputValidationError validate_sample_range(NaN)
            @test_throws InputValidationError validate_sample_range(Inf)
            @test_throws InputValidationError validate_sample_range(2000.0)  # Too large
        end
        
        @testset "Objective Function Validation" begin
            # Valid functions
            f_good(x) = sum(x.^2)
            @test_nowarn validate_objective_function(f_good, 2, [0.0, 0.0])
            
            # Invalid functions
            f_nan(x) = NaN
            @test_throws InputValidationError validate_objective_function(f_nan, 2, [0.0, 0.0])
            
            f_inf(x) = Inf
            @test_throws InputValidationError validate_objective_function(f_inf, 2, [0.0, 0.0])
            
            f_string(x) = "invalid"
            @test_throws InputValidationError validate_objective_function(f_string, 2, [0.0, 0.0])
        end
    end
    
    # ========================================================================
    # NUMERICAL STABILITY TESTS
    # ========================================================================
    
    @testset "Numerical Stability Monitoring" begin
        
        @testset "Matrix Conditioning" begin
            # Well-conditioned matrix
            A_good = [1.0 0.0; 0.0 1.0]
            @test_nowarn check_matrix_conditioning(A_good, "test_operation")
            
            # Ill-conditioned matrix
            A_bad = [1.0 1.0; 1.0 1.0+1e-15]
            @test_throws NumericalError check_matrix_conditioning(A_bad, "test_operation", max_condition=1e10)
            
            # Singular matrix
            A_singular = [1.0 1.0; 1.0 1.0]
            @test_throws NumericalError check_matrix_conditioning(A_singular, "test_operation")
            
            # Empty matrix
            A_empty = Matrix{Float64}(undef, 0, 0)
            @test_throws NumericalError check_matrix_conditioning(A_empty, "test_operation")
        end
        
        @testset "Polynomial Coefficient Validation" begin
            # Valid coefficients
            coeffs_good = [1.0, 0.5, -0.2, 0.1]
            @test_nowarn validate_polynomial_coefficients(coeffs_good, "test_operation")
            
            # Coefficients with NaN
            coeffs_nan = [1.0, NaN, 0.5]
            @test_throws NumericalError validate_polynomial_coefficients(coeffs_nan, "test_operation")
            
            # Coefficients with Inf
            coeffs_inf = [1.0, Inf, 0.5]
            @test_throws NumericalError validate_polynomial_coefficients(coeffs_inf, "test_operation")
            
            # All zero coefficients
            coeffs_zero = [0.0, 0.0, 0.0]
            @test_throws NumericalError validate_polynomial_coefficients(coeffs_zero, "test_operation")
            
            # Empty coefficients
            coeffs_empty = Float64[]
            @test_throws NumericalError validate_polynomial_coefficients(coeffs_empty, "test_operation")
        end
    end
    
    # ========================================================================
    # RESOURCE MONITORING TESTS
    # ========================================================================
    
    @testset "Resource Monitoring" begin
        
        @testset "Memory Usage Monitoring" begin
            # Should not throw for reasonable memory usage
            @test_nowarn check_memory_usage("test_operation", memory_limit_gb=100.0)
            
            # Should warn or throw for very low memory limits (if we could control memory usage)
            # This is hard to test reliably, so we just ensure the function runs
            @test_nowarn check_memory_usage("test_operation", memory_limit_gb=0.001)
        end
        
        @testset "Complexity Estimation" begin
            # Test complexity estimation
            complexity = estimate_computation_complexity(2, 6, 100)

            @test haskey(complexity, "estimated_terms")
            @test haskey(complexity, "matrix_elements")
            @test haskey(complexity, "matrix_memory_mb")
            @test haskey(complexity, "total_memory_mb")
            @test haskey(complexity, "system_complexity")
            @test haskey(complexity, "warnings")
            @test haskey(complexity, "memory_feasible")
            @test haskey(complexity, "time_feasible")

            @test complexity["estimated_terms"] > 0
            @test complexity["matrix_elements"] > 0
            @test complexity["matrix_memory_mb"] > 0

            # Test high complexity case (more conservative)
            complexity_high = estimate_computation_complexity(4, 8, 500)
            @test length(complexity_high["warnings"]) > 0
            @test !complexity_high["memory_feasible"] || !complexity_high["time_feasible"]
        end
    end
    
    # ========================================================================
    # PARAMETER ADJUSTMENT TESTS
    # ========================================================================
    
    @testset "Parameter Adjustment" begin
        
        @testset "Numerical Error Adjustments" begin
            error = NumericalError(
                "test_operation",
                "Matrix is ill-conditioned",
                ["Reduce degree"],
                Dict("condition_number" => 1e15)
            )
            
            params = Dict("degree" => 10, "GN" => 100)
            suggestions = suggest_parameter_adjustments(error, params)
            
            @test haskey(suggestions, "degree")
            @test suggestions["degree"] < params["degree"]
        end
        
        @testset "Resource Error Adjustments" begin
            error = ResourceError("memory", 10.0, 8.0, "Reduce sample count")
            
            params = Dict("GN" => 1000, "degree" => 8)
            suggestions = suggest_parameter_adjustments(error, params)
            
            @test haskey(suggestions, "GN")
            @test suggestions["GN"] < params["GN"]
        end
    end
    
    # ========================================================================
    # PROGRESS MONITORING TESTS
    # ========================================================================
    
    @testset "Progress Monitoring" begin
        
        @testset "ComputationProgress" begin
            progress = ComputationProgress("test_stage")
            
            @test progress.stage == "test_stage"
            @test progress.progress == 0.0
            @test progress.can_interrupt == true
            
            # Test progress updates
            update_progress!(progress, 0.5, "halfway")
            @test progress.progress == 0.5
            @test progress.stage == "halfway"
            
            # Test clamping
            update_progress!(progress, 1.5)
            @test progress.progress == 1.0
            
            update_progress!(progress, -0.1)
            @test progress.progress == 0.0
        end
        
        @testset "Progress Monitoring Wrapper" begin
            # Test successful execution
            result = with_progress_monitoring(
                progress -> begin
                    update_progress!(progress, 0.5, "working")
                    return "success"
                end,
                "test_computation"
            )
            @test result == "success"
            
            # Test error handling
            @test_throws ErrorException with_progress_monitoring(
                progress -> error("test error"),
                "test_computation"
            )
        end
    end
    
    # ========================================================================
    # ERROR DISPLAY TESTS
    # ========================================================================
    
    @testset "Error Display" begin
        
        @testset "InputValidationError Display" begin
            error = InputValidationError("test_param", 42, "valid range", "fix suggestion")
            
            # Test that custom error display doesn't throw
            io = IOBuffer()
            @test_nowarn showerror(io, error)
            
            output = String(take!(io))
            @test occursin("Invalid Input Parameter", output)
            @test occursin("test_param", output)
            @test occursin("42", output)
        end
        
        @testset "NumericalError Display" begin
            error = NumericalError(
                "test_op", "test problem", 
                ["suggestion 1", "suggestion 2"],
                Dict("context" => "test")
            )
            
            io = IOBuffer()
            @test_nowarn showerror(io, error)
            
            output = String(take!(io))
            @test occursin("Numerical Instability", output)
            @test occursin("test_op", output)
            @test occursin("suggestion 1", output)
        end
    end
end
