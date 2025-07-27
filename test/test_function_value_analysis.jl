# Test Function Value Error Analysis functionality

using Test
using Globtim
using DataFrames
using LinearAlgebra

@testset "Function Value Error Analysis" begin
    
    @testset "Basic Error Computation" begin
        # Simple quadratic function with known minimum
        f(x) = sum(x.^2)
        
        # Theoretical critical point (global minimum)
        theoretical_points = [[0.0, 0.0]]
        
        # Computed points with small errors
        computed_points = [
            [0.01, 0.01],
            [0.05, -0.03],
            [-0.02, 0.04]
        ]
        
        # Compute errors
        errors = compute_function_value_errors(
            theoretical_points, computed_points, f;
            match_threshold = 0.1
        )
        
        @test length(errors) == 1  # Should match the closest point
        @test errors[1].theoretical_value ≈ 0.0
        @test errors[1].computed_value ≈ f(computed_points[1])
        @test errors[1].absolute_error ≈ abs(f(computed_points[1]) - 0.0)
        @test errors[1].distance_to_theoretical ≈ norm(computed_points[1] - [0.0, 0.0])
    end
    
    @testset "Error Metrics Computation" begin
        # Create mock errors
        errors = [
            FunctionValueError(
                [0.0, 0.0], [0.01, 0.01], 0.0, 0.0002,
                0.0002, Inf, :minimum, 0.014, 0.0, 0.02
            ),
            FunctionValueError(
                [1.0, 1.0], [0.99, 1.01], 2.0, 2.0002,
                0.0002, 0.0001, :minimum, 0.014, 0.0, 0.02
            )
        ]
        
        metrics = compute_error_metrics(errors)
        
        @test metrics.mean_absolute_error ≈ 0.0002
        @test metrics.n_points == 2
        @test metrics.max_absolute_error ≈ 0.0002
        @test metrics.median_absolute_error ≈ 0.0002
    end
    
    @testset "Analysis by Point Type" begin
        # Create errors with different types
        errors = [
            FunctionValueError(
                [0.0, 0.0], [0.01, 0.01], 0.0, 0.0002,
                0.0002, Inf, :minimum, 0.014, 0.0, 0.02
            ),
            FunctionValueError(
                [1.0, 0.0], [0.99, 0.01], 1.0, 1.0003,
                0.0003, 0.0003, :saddle, 0.014, 0.0, 0.02
            ),
            FunctionValueError(
                [0.0, 1.0], [0.01, 0.99], 1.0, 1.0001,
                0.0001, 0.0001, :saddle, 0.014, 0.0, 0.02
            )
        ]
        
        metrics_by_type = analyze_errors_by_type(errors)
        
        @test haskey(metrics_by_type, :minimum)
        @test haskey(metrics_by_type, :saddle)
        @test metrics_by_type[:minimum].n_points == 1
        @test metrics_by_type[:saddle].n_points == 2
        @test metrics_by_type[:saddle].mean_absolute_error ≈ 0.0002
    end
    
    @testset "Error Analysis DataFrame" begin
        # Simple test case
        f(x) = x[1]^2 + x[2]^2
        theoretical_points = [[0.0, 0.0]]
        computed_points = [[0.01, -0.01]]
        
        errors = compute_function_value_errors(
            theoretical_points, computed_points, f;
            point_types = [:minimum]
        )
        
        df = create_error_analysis_dataframe(errors)
        
        @test nrow(df) == 1
        @test "absolute_error" in names(df)
        @test "relative_error" in names(df)
        @test "theo_x1" in names(df)
        @test "comp_x1" in names(df)
        @test df[1, :point_type] == :minimum
    end
    
    @testset "Convergence Analysis" begin
        # Mock tolerance results
        tolerance_results = Dict{Float64, Vector{FunctionValueError}}()
        
        # Decreasing errors with decreasing tolerance
        for (tol, err_scale) in [(1e-2, 1e-2), (1e-3, 1e-3), (1e-4, 1e-4)]
            errors = [
                FunctionValueError(
                    [0.0, 0.0], [err_scale, err_scale], 0.0, err_scale^2,
                    err_scale^2, Inf, :minimum, sqrt(2)*err_scale, 0.0, 2*err_scale
                )
            ]
            tolerance_results[tol] = errors
        end
        
        conv_df = convergence_analysis(tolerance_results)
        
        @test nrow(conv_df) == 3
        @test issorted(conv_df.tolerance, rev=true)
        @test all(conv_df.mean_absolute_error .> 0)
        @test "convergence_rate_absolute" in names(conv_df)
        
        # Check that errors decrease with tolerance
        @test issorted(conv_df.mean_absolute_error, rev=true)
    end
    
    @testset "BFGS Integration" begin
        # Create a mock DataFrame from analyze_critical_points
        f(x) = x[1]^2 + x[2]^2
        df = DataFrame(
            x1 = [0.05, 0.5],
            x2 = [0.05, -0.5],
            y1 = [0.01, 0.48],
            y2 = [0.01, -0.49],
            converged = [true, true],
            z = [f([0.05, 0.05]), f([0.5, -0.5])]
        )
        
        theoretical_points = [[0.0, 0.0], [0.5, -0.5]]
        theoretical_types = [:minimum, :saddle]
        
        # Integrate with BFGS results
        df_enhanced = integrate_with_bfgs_results(
            df, f, theoretical_points;
            theoretical_types = theoretical_types
        )
        
        @test "has_theoretical_match" in names(df_enhanced)
        @test "function_value_error" in names(df_enhanced)
        @test "relative_function_error" in names(df_enhanced)
        @test any(df_enhanced.has_theoretical_match)
        
        # Check that at least one point has error computed
        @test any(!isnan(x) for x in df_enhanced.function_value_error)
    end
    
    @testset "4D Deuflhard Analysis" begin
        # Test with 4D Deuflhard function
        f = deuflhard_4d_composite
        
        # Known critical points for 4D Deuflhard
        # (combinations of 2D Deuflhard critical points)
        theoretical_points = [
            [0.0, 0.0, 0.0, 0.0],  # Global minimum
            [0.0, 0.9, 0.0, 0.9]   # Local minimum
        ]
        
        # Computed points with small perturbations
        computed_points = [
            [0.01, -0.01, 0.01, -0.01],
            [0.02, 0.89, -0.01, 0.91]
        ]
        
        errors = compute_function_value_errors(
            theoretical_points, computed_points, f;
            match_threshold = 0.1,
            point_types = [:minimum, :minimum]
        )
        
        @test length(errors) == 2
        @test all(e.point_type == :minimum for e in errors)
        @test all(e.distance_to_theoretical < 0.1 for e in errors)
        
        # Create error metrics
        metrics = compute_error_metrics(errors)
        @test metrics.n_points == 2
        @test metrics.mean_absolute_error > 0
    end
end