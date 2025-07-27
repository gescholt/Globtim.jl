using Test
using Globtim
using DynamicPolynomials
using DataFrames

@testset "Convenience Methods Tests" begin

    @testset "solve_polynomial_system with ApproxPoly" begin
        # Test 1D case with scalar variable
        @testset "1D scalar function" begin
            f = x -> sin(x)
            TR = test_input(f, dim = 1, center = [0.0], sample_range = π)
            pol = Constructor(TR, 8)
            @polyvar x

            # Test with single variable (not in array)
            solutions = solve_polynomial_system(x, pol)
            @test length(solutions) > 0
            @test all(sol -> length(sol) == 1, solutions)

            # Test with variable array
            solutions2 = solve_polynomial_system([x], pol)
            @test length(solutions2) == length(solutions)
        end

        # Test 2D case
        @testset "2D vector function" begin
            f = x -> x[1]^2 + x[2]^2 - 1
            TR = test_input(f, dim = 2, center = [0.0, 0.0], sample_range = 2.0)
            pol = Constructor(TR, 4)
            @polyvar x[1:2]

            solutions = solve_polynomial_system(x, pol)
            @test length(solutions) > 0
            @test all(sol -> length(sol) == 2, solutions)
        end

        # Test dimension mismatch error
        @testset "Dimension mismatch" begin
            f = x -> x[1]^2 + x[2]^2
            TR = test_input(f, dim = 2, center = [0.0, 0.0], sample_range = 1.0)
            pol = Constructor(TR, 4)
            @polyvar x

            @test_throws ErrorException solve_polynomial_system(x, pol)
        end

        # Test with different degree formats
        @testset "Different degree formats" begin
            f = x -> x[1]^2 + x[2]^2
            TR = test_input(f, dim = 2, center = [0.0, 0.0], sample_range = 1.0)

            # Test with :one_d_for_all
            pol1 = Constructor(TR, 4)
            @polyvar x[1:2]
            solutions1 = solve_polynomial_system(x, pol1)
            @test length(solutions1) > 0

            # Test with :one_d_per_dim (if supported by Constructor)
            # This would require modifying Constructor to accept tuple degrees
        end
    end

    @testset "process_crit_pts with scalar functions" begin
        # Test 1D scalar functions
        @testset "Common 1D scalar functions" begin
            test_functions = [
                (x -> sin(x), "sin"),
                (x -> cos(x), "cos"),
                (x -> exp(x), "exp"),
                (x -> x^2, "x^2"),
                (x -> x^3 - x, "x^3 - x"),
            ]

            for (f, fname) in test_functions
                TR = test_input(f, dim = 1, center = [0.0], sample_range = 2.0)

                # Create some test points
                test_points = [[-0.5], [0.0], [0.5], [1.0]]

                df = process_crit_pts(test_points, f, TR)
                @test isa(df, DataFrame)
                @test size(df, 1) == length(test_points)
                @test "x1" in names(df)
                @test "z" in names(df)

                # Verify function values are computed correctly
                for i = 1:size(df, 1)
                    x_transformed = TR.sample_range * test_points[i][1] + TR.center[1]
                    expected_z = f(x_transformed)
                    @test df.z[i] ≈ expected_z atol = 1e-10
                end
            end
        end

        # Test that vector functions still work
        @testset "Vector functions compatibility" begin
            # 1D function that expects vector input
            f_vec = x -> sin(x[1])
            TR = test_input(f_vec, dim = 1, center = [0.0], sample_range = 2.0)
            test_points = [[-0.5], [0.0], [0.5]]

            df = process_crit_pts(test_points, f_vec, TR)
            @test isa(df, DataFrame)
            @test size(df, 1) == length(test_points)
        end

        # Test 2D functions
        @testset "2D functions" begin
            f = x -> x[1]^2 + x[2]^2
            TR = test_input(f, dim = 2, center = [0.0, 0.0], sample_range = 1.0)
            test_points = [[0.0, 0.0], [0.5, 0.5], [1.0, 0.0]]

            df = process_crit_pts(test_points, f, TR)
            @test isa(df, DataFrame)
            @test size(df, 1) == length(test_points)
            @test "x1" in names(df) && "x2" in names(df)
            @test "z" in names(df)
        end

        # Test filtering behavior
        @testset "Point filtering" begin
            f = x -> x^2
            TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)

            # Include points outside [-1,1]
            test_points = [[-2.0], [-0.5], [0.0], [0.5], [2.0]]

            # With filtering (default)
            df_filtered = process_crit_pts(test_points, f, TR)
            @test size(df_filtered, 1) == 3  # Only points in [-1,1]

            # Without filtering
            df_unfiltered = process_crit_pts(test_points, f, TR, skip_filtering = true)
            @test size(df_unfiltered, 1) == 5  # All points
        end

        # Test empty points
        @testset "Empty points handling" begin
            f = x -> x^2
            TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)

            df = process_crit_pts(Vector{Vector{Float64}}(), f, TR)
            @test isa(df, DataFrame)
            @test size(df, 1) == 0
            @test "x1" in names(df) && "z" in names(df)
        end

        # Test anisotropic scaling
        @testset "Anisotropic scaling" begin
            f = x -> x[1]^2 + x[2]^2
            TR = test_input(f, dim = 2, center = [0.0, 0.0], sample_range = [2.0, 3.0])
            test_points = [[0.5, 0.5], [1.0, 1.0]]

            df = process_crit_pts(test_points, f, TR)
            @test isa(df, DataFrame)

            # Check that scaling is applied correctly
            @test df.x1[1] ≈ 2.0 * 0.5 + 0.0
            @test df.x2[1] ≈ 3.0 * 0.5 + 0.0
        end
    end

    @testset "Integration test: Full workflow" begin
        # Test the complete workflow with new convenience methods
        f = x -> sin(3 * x) + 0.1 * x^2
        TR = test_input(f, dim = 1, center = [0.0], sample_range = π)
        pol = Constructor(TR, 10)
        @polyvar x

        # Use convenience method
        solutions = solve_polynomial_system(x, pol)

        # Process the critical points
        df = process_crit_pts(solutions, f, TR)

        @test isa(df, DataFrame)
        @test size(df, 1) == length(solutions)
        @test all(isfinite, df.z)
    end
end
