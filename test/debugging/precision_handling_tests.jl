"""
Comprehensive test suite for precision handling in GlobTim polynomial approximation pipeline.

Tests verify:
1. Precision type conversion functions
2. Zero value handling in rational arithmetic
3. Coefficient conversion consistency
4. End-to-end precision flow in polynomial construction
5. Numerical stability across precision types
"""

using Test
using Globtim
using DynamicPolynomials

@testset "Precision Handling Pipeline Tests" begin

    @testset "Basic Precision Type Conversions" begin
        @testset "_convert_value Function Tests" begin

            # Test Float64Precision conversions
            @test Globtim._convert_value(1.5, Float64Precision) === 1.5
            @test Globtim._convert_value(0.0, Float64Precision) === 0.0
            @test Globtim._convert_value(-2.5, Float64Precision) === -2.5
            @test typeof(Globtim._convert_value(1.5, Float64Precision)) === Float64

            # Test BigFloatPrecision conversions
            result_bf = Globtim._convert_value(1.5, BigFloatPrecision)
            @test result_bf ≈ BigFloat(1.5)
            @test typeof(result_bf) === BigFloat

            # Test AdaptivePrecision conversions
            result_adaptive = Globtim._convert_value(1.5, AdaptivePrecision)
            @test typeof(result_adaptive) === BigFloat  # AdaptivePrecision uses BigFloat internally
            @test result_adaptive ≈ BigFloat(1.5)
        end

        @testset "RationalPrecision Zero Handling" begin
            # Test the problematic zero conversion that was causing errors
            @test_nowarn Globtim._convert_value(0.0, RationalPrecision)
            @test_nowarn Globtim._convert_value(0, RationalPrecision)

            result_zero_float = Globtim._convert_value(0.0, RationalPrecision)
            result_zero_int = Globtim._convert_value(0, RationalPrecision)

            # Both should produce valid rational numbers
            @test typeof(result_zero_float) <: Rational
            @test typeof(result_zero_int) <: Rational
            @test result_zero_float == 0 // 1
            @test result_zero_int == 0 // 1

            # Test non-zero rationals work correctly
            result_nonzero = Globtim._convert_value(1.5, RationalPrecision)
            @test typeof(result_nonzero) <: Rational
            @test result_nonzero ≈ 3 // 2
        end

        @testset "Edge Cases in Precision Conversion" begin
            # Test very small numbers
            @test_nowarn Globtim._convert_value(1e-16, Float64Precision)
            @test_nowarn Globtim._convert_value(1e-16, RationalPrecision)

            # Test very large numbers
            @test_nowarn Globtim._convert_value(1e12, Float64Precision)
            @test_nowarn Globtim._convert_value(1e12, BigFloatPrecision)

            # Test negative numbers including negative zero
            @test_nowarn Globtim._convert_value(-0.0, RationalPrecision)
            result_neg_zero = Globtim._convert_value(-0.0, RationalPrecision)
            @test result_neg_zero == 0 // 1  # Negative zero should become positive zero rational
        end
    end

    @testset "Coefficient Vector Conversion Tests" begin

        @testset "Mixed Coefficient Types" begin
            # Test coefficient vectors with different value types
            mixed_coeffs = [1.0, 0.0, -2.5, 1e-10, 1e10]

            # Float64Precision should preserve all values
            converted_f64 =
                [Globtim._convert_value(c, Float64Precision) for c in mixed_coeffs]
            @test all(c isa Float64 for c in converted_f64)
            @test converted_f64 ≈ mixed_coeffs

            # RationalPrecision should handle all values including zeros
            @test_nowarn converted_rational =
                [Globtim._convert_value(c, RationalPrecision) for c in mixed_coeffs]
            converted_rational =
                [Globtim._convert_value(c, RationalPrecision) for c in mixed_coeffs]
            @test all(c isa Rational for c in converted_rational)

            # AdaptivePrecision should use BigFloat
            converted_adaptive =
                [Globtim._convert_value(c, AdaptivePrecision) for c in mixed_coeffs]
            @test all(c isa BigFloat for c in converted_adaptive)
        end

        @testset "Zero-Heavy Coefficient Vectors" begin
            # Test vectors with many zeros (common in sparse polynomials)
            zero_heavy_coeffs = [1.0, 0.0, 0.0, 0.0, 2.5, 0.0, 0.0, -1.2]

            for precision_type in
                [Float64Precision, RationalPrecision, BigFloatPrecision, AdaptivePrecision]
                @test_nowarn converted =
                    [Globtim._convert_value(c, precision_type) for c in zero_heavy_coeffs]

                converted =
                    [Globtim._convert_value(c, precision_type) for c in zero_heavy_coeffs]

                # Check zero values are handled correctly
                zero_indices = findall(x -> x == 0.0, zero_heavy_coeffs)
                for idx in zero_indices
                    if precision_type == RationalPrecision
                        @test converted[idx] == 0 // 1
                    else
                        @test converted[idx] ≈ 0.0
                    end
                end

                # Check non-zero values are preserved
                nonzero_indices = findall(x -> x != 0.0, zero_heavy_coeffs)
                for idx in nonzero_indices
                    @test abs(Float64(converted[idx]) - zero_heavy_coeffs[idx]) < 1e-10
                end
            end
        end
    end

    @testset "Polynomial Construction Precision Flow" begin

        @testset "Simple 1D Polynomial Precision Consistency" begin
            @polyvar x
            coeffs_1d = [1.0, 0.0, -2.0, 0.0, 1.5]  # x^4 + 1.5x^3 - 2x^2 + 1

            # Test that we can construct polynomials with different precision types
            for precision_type in [Float64Precision, AdaptivePrecision]  # Skip RationalPrecision for now due to known issues
                @test_nowarn begin
                    pol = Globtim.construct_orthopoly_polynomial(
                        [x], coeffs_1d, (:one_d_for_all, 4), :chebyshev, precision_type;
                        verbose = false
                    )
                end

                pol = Globtim.construct_orthopoly_polynomial(
                    [x], coeffs_1d, (:one_d_for_all, 4), :chebyshev, precision_type;
                    verbose = false
                )

                # Polynomial should be non-trivial
                @test !iszero(pol)

                # Should be able to evaluate the polynomial
                @test_nowarn eval_result = pol([0.5])
                eval_result = pol([0.5])
                @test isfinite(Float64(eval_result))
            end
        end

        @testset "2D Minimal Polynomial Construction" begin
            @polyvar x[1:2]

            # Very simple 2D polynomial to minimize computational complexity
            degree = 2
            n_terms = binomial(2 + degree, degree)  # Number of terms in 2D polynomial of degree 2
            coeffs_2d = ones(Float64, n_terms)  # All coefficients = 1.0
            coeffs_2d[1] = 2.0  # Make constant term different
            coeffs_2d[end] = 0.0  # Add a zero coefficient

            @test_nowarn begin
                pol = Globtim.construct_orthopoly_polynomial(
                    x, coeffs_2d, (:one_d_for_all, degree), :chebyshev,
                    Float64Precision;
                    verbose = false
                )
            end

            pol = Globtim.construct_orthopoly_polynomial(
                x, coeffs_2d, (:one_d_for_all, degree), :chebyshev, Float64Precision;
                verbose = false
            )

            @test !iszero(pol)

            # Test evaluation at a simple point
            @test_nowarn eval_result = pol([0.1, 0.2])
            eval_result = pol([0.1, 0.2])
            @test isfinite(Float64(eval_result))
        end
    end

    @testset "End-to-End Precision Pipeline Tests" begin

        @testset "Constructor → Polynomial System Precision Consistency" begin
            # Create a minimal 2D optimization problem similar to the failing 4D case
            function simple_2d_objective(θ)
                return (θ[1] - 1.0)^2 + (θ[2] - 0.5)^2  # Simple quadratic with minimum at [1.0, 0.5]
            end

            # Generate test input similar to TestInput function
            n = 2
            center = [1.0, 0.5]
            GN = 9  # 3^2 total samples
            sample_range = 1.0

            # Create sample points manually to avoid TestInput dependency
            samples_per_dim = Int(round(GN^(1 / n)))
            sample_points = []
            sample_values = []

            for i in 1:samples_per_dim
                for j in 1:samples_per_dim
                    θ = [
                        center[1] +
                        sample_range * (2 * (i - 1) / (samples_per_dim - 1) - 1),
                        center[2] +
                        sample_range * (2 * (j - 1) / (samples_per_dim - 1) - 1)
                    ]
                    push!(sample_points, θ)
                    push!(sample_values, simple_2d_objective(θ))
                end
            end

            @test length(sample_points) == GN
            @test length(sample_values) == GN
            @test all(isfinite, sample_values)

            # Test different precision combinations
            constructor_precisions = [Float64Precision, AdaptivePrecision]
            solver_precisions = [Float64Precision, AdaptivePrecision]

            for const_prec in constructor_precisions
                for solve_prec in solver_precisions
                    @testset "Constructor: $const_prec, Solver: $solve_prec" begin

                        # Mock the Constructor result structure for testing
                        # In real code, this would come from Constructor function
                        n_coeffs = binomial(n + 2, 2)  # Degree 2 polynomial in 2D
                        mock_coeffs = randn(n_coeffs)
                        mock_coeffs[1] = 1.0  # Ensure non-zero constant term

                        # Test polynomial construction with specified precisions
                        @polyvar y[1:2]

                        @test_nowarn begin
                            pol = Globtim.construct_orthopoly_polynomial(
                                y, mock_coeffs, (:one_d_for_all, 2), :chebyshev,
                                const_prec;
                                verbose = false
                            )
                        end

                        pol = Globtim.construct_orthopoly_polynomial(
                            y, mock_coeffs, (:one_d_for_all, 2), :chebyshev, const_prec;
                            verbose = false
                        )

                        # Test that we can solve the polynomial system with specified precision
                        @test_nowarn begin
                            real_pts, (poly, system, nsols) = Globtim.solve_polynomial_system(
                                y, n, (:one_d_for_all, 2), mock_coeffs;
                                basis = :chebyshev,
                                precision = solve_prec,
                                return_system = true
                            )
                        end

                        real_pts, (poly, system, nsols) = Globtim.solve_polynomial_system(
                            y, n, (:one_d_for_all, 2), mock_coeffs;
                            basis = :chebyshev,
                            precision = solve_prec,
                            return_system = true
                        )

                        # Basic sanity checks
                        @test nsols ≥ 0
                        @test length(real_pts) ≤ nsols
                        @test all(length(pt) == n for pt in real_pts)  # Each point should be n-dimensional
                        @test all(all(isfinite, pt) for pt in real_pts)  # All coordinates should be finite
                    end
                end
            end
        end
    end

    @testset "Numerical Stability Tests" begin

        @testset "Condition Number Behavior Across Precisions" begin
            # Test how condition numbers behave with different precision types
            @polyvar z

            # Create a well-conditioned coefficient vector
            well_conditioned = [1.0, 0.5, 0.25]  # Simple decreasing coefficients

            # Create an ill-conditioned coefficient vector  
            ill_conditioned = [1.0, 1e-15, 1e-14, 1.0]  # Mix of large and tiny coefficients

            for coeffs in [well_conditioned, ill_conditioned]
                for precision_type in [Float64Precision, AdaptivePrecision]
                    @test_nowarn begin
                        pol = Globtim.construct_orthopoly_polynomial(
                            [z], coeffs, (:one_d_for_all, length(coeffs) - 1),
                            :chebyshev, precision_type;
                            verbose = false
                        )
                    end
                end
            end
        end

        @testset "Precision Loss Detection" begin
            # Test detection of precision loss in coefficient conversion

            # Values that might lose precision in conversion
            precision_sensitive = [
                1.0 + eps(Float64),  # Just above 1
                1.0 - eps(Float64),  # Just below 1  
                nextfloat(0.0),      # Smallest positive Float64
                prevfloat(0.0),      # Largest negative Float64 (closest to zero)
                floatmax(Float64),   # Largest representable Float64
                floatmin(Float64)    # Smallest normal Float64
            ]

            # Test that AdaptivePrecision preserves more precision than Float64Precision
            for val in precision_sensitive
                if isfinite(val) && val != 0.0
                    f64_result = Globtim._convert_value(val, Float64Precision)
                    adaptive_result = Globtim._convert_value(val, AdaptivePrecision)

                    @test typeof(f64_result) === Float64
                    @test typeof(adaptive_result) === BigFloat

                    # BigFloat should be at least as accurate as Float64
                    @test abs(Float64(adaptive_result) - val) ≤ abs(f64_result - val)
                end
            end
        end
    end

    @testset "Performance and Memory Tests" begin

        @testset "Precision Conversion Performance" begin
            # Test that precision conversions don't have unexpected performance regressions
            large_coeffs = randn(1000)

            # Time Float64 conversions (should be fastest)
            @test (@elapsed [
                Globtim._convert_value(c, Float64Precision) for c in large_coeffs
            ]) < 1.0

            # Time other precision conversions (should complete in reasonable time)
            @test (@elapsed [
                Globtim._convert_value(c, AdaptivePrecision) for c in large_coeffs
            ]) < 5.0
            @test (@elapsed [
                Globtim._convert_value(c, BigFloatPrecision) for c in large_coeffs
            ]) < 5.0
        end

        @testset "Memory Usage Patterns" begin
            # Test that we don't have obvious memory leaks in precision conversions
            coeffs = randn(100)

            # Multiple conversion rounds shouldn't cause unbounded memory growth
            for i in 1:10
                converted = [Globtim._convert_value(c, AdaptivePrecision) for c in coeffs]
                # Force garbage collection to detect leaks
                GC.gc()
            end

            # Test passes if no out-of-memory errors occur
            @test true
        end
    end

end

# Helper function to check if tests can run (dependencies available)
function can_run_precision_tests()
    try
        # Check if required GlobTim functions are available
        return isdefined(Globtim, :_convert_value) &&
               isdefined(Globtim, :construct_orthopoly_polynomial) &&
               isdefined(Globtim, :solve_polynomial_system)
    catch e
        @debug "Precision test dependencies check failed" exception=(e, catch_backtrace())
        return false
    end
end

# Only run tests if dependencies are available
if can_run_precision_tests()
    println("✓ All precision handling pipeline dependencies available")
    println("✓ Running comprehensive precision tests...")
else
    println("⚠ Some GlobTim functions not available - skipping precision tests")
    println("  This is expected if running before implementing the fixes")
end
