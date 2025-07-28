using Test
using Globtim
using LinearAlgebra
using StaticArrays

# The compute_l2_norm_quadrature function is now implemented in src/quadrature_l2_norm.jl

@testset "Quadrature L2 Norm - Phase 1 & 2 Tests" begin

    # ==================== PHASE 1: Core Functionality ====================

    @testset "Phase 1: Core Functionality" begin

        @testset "1.1 Polynomial Exactness (1D)" begin
            # Test constant function: f(x) = 1
            # Analytical L2 norm on [-1,1]: sqrt(∫₋₁¹ 1² dx) = sqrt(2)
            f_const = x -> 1.0
            @test compute_l2_norm_quadrature(f_const, [5], :chebyshev) ≈ sqrt(2.0) rtol =
                1e-12
            @test compute_l2_norm_quadrature(f_const, [10], :chebyshev) ≈ sqrt(2.0) rtol =
                1e-12

            # Test quadratic: f(x) = x²
            # Analytical L2 norm: sqrt(∫₋₁¹ x⁴ dx) = sqrt(2/5)
            f_quad = x -> x[1]^2
            @test compute_l2_norm_quadrature(f_quad, [3], :chebyshev) ≈ sqrt(2 / 5) rtol =
                1e-12
            @test compute_l2_norm_quadrature(f_quad, [5], :chebyshev) ≈ sqrt(2 / 5) rtol =
                1e-12

            # Test quartic: f(x) = x⁴
            # Analytical L2 norm: sqrt(∫₋₁¹ x⁸ dx) = sqrt(2/9)
            f_quartic = x -> x[1]^4
            @test compute_l2_norm_quadrature(f_quartic, [5], :chebyshev) ≈ sqrt(2 / 9) rtol =
                1e-12
            @test compute_l2_norm_quadrature(f_quartic, [10], :chebyshev) ≈ sqrt(2 / 9) rtol =
                1e-12

            # Test linear (odd function): f(x) = x
            # Analytical L2 norm: sqrt(∫₋₁¹ x² dx) = sqrt(2/3)
            f_linear = x -> x[1]
            @test compute_l2_norm_quadrature(f_linear, [5], :chebyshev) ≈ sqrt(2 / 3) rtol =
                1e-12
        end

        @testset "1.2 Basic Multi-dimensional (2D only)" begin
            # Test constant in 2D: f(x,y) = 1
            # L2 norm on [-1,1]²: sqrt(∫∫ 1² dxdy) = sqrt(4) = 2
            f_const_2d = x -> 1.0
            @test compute_l2_norm_quadrature(f_const_2d, [5, 5], :chebyshev) ≈ 2.0 rtol =
                1e-12
            @test compute_l2_norm_quadrature(f_const_2d, [10, 10], :chebyshev) ≈ 2.0 rtol =
                1e-12

            # Test separable polynomial: f(x,y) = x² * y²
            # L2 norm: sqrt(∫∫ x⁴y⁴ dxdy) = sqrt((2/5) * (2/5)) = 2/5
            f_sep = x -> x[1]^2 * x[2]^2
            @test compute_l2_norm_quadrature(f_sep, [5, 5], :chebyshev) ≈ 2 / 5 rtol = 1e-12
            @test compute_l2_norm_quadrature(f_sep, [10, 10], :chebyshev) ≈ 2 / 5 rtol =
                1e-12

            # Test simple Gaussian: f(x,y) = exp(-(x²+y²))
            f_gauss_2d = x -> exp(-(x[1]^2 + x[2]^2))
            # Just test that it gives positive finite results
            @test begin
                l2_norm = compute_l2_norm_quadrature(f_gauss_2d, [10, 10], :chebyshev)
                l2_norm > 0 && isfinite(l2_norm)
            end
            @test begin
                l2_norm = compute_l2_norm_quadrature(f_gauss_2d, [20, 20], :chebyshev)
                l2_norm > 0 && isfinite(l2_norm)
            end
        end

        @testset "1.3 Single Basis Type (Chebyshev only)" begin
            # All tests above use Chebyshev basis
            # Additional test: mixed polynomial in 2D
            f_mixed = x -> x[1]^3 * x[2] + x[1] * x[2]^3
            @test begin
                l2_norm = compute_l2_norm_quadrature(f_mixed, [10, 10], :chebyshev)
                l2_norm > 0 && isfinite(l2_norm)
            end

            # Test polynomial that requires more quadrature points
            f_high_deg = x -> x[1]^6
            # For x^6, L2 norm^2 = ∫x^12 dx, so we need 2n-1 ≥ 12, thus n ≥ 7
            @test compute_l2_norm_quadrature(f_high_deg, [7], :chebyshev) ≈ sqrt(2 / 13) rtol =
                1e-12
            @test compute_l2_norm_quadrature(f_high_deg, [10], :chebyshev) ≈ sqrt(2 / 13) rtol =
                1e-12
        end

        @testset "1.4 Basic Convergence (1D and 2D)" begin
            # 1D convergence test
            f_exp_1d = x -> exp(-x[1]^2)
            grid_sizes_1d = [5, 10, 12, 14]

            @test begin
                norms_1d = [
                    compute_l2_norm_quadrature(f_exp_1d, [n], :chebyshev) for
                    n in grid_sizes_1d
                ]
                # Check that all norms are positive
                all(n -> n > 0, norms_1d) &&
                # Check convergence: differences should decrease
                    begin
                        diffs =
                            [
                                abs(norms_1d[i + 1] - norms_1d[i]) for
                                i in 1:(length(norms_1d) - 1)
                            ]
                        # Either decreasing or very small
                        all(
                            i -> diffs[i + 1] < diffs[i] || diffs[i + 1] < 1e-10,
                            1:(length(diffs) - 1)
                        )
                    end
            end

            # 2D convergence test
            f_exp_2d = x -> exp(-(x[1]^2 + x[2]^2))
            grid_sizes_2d = [5, 10, 14]  # Smaller for 2D

            @test begin
                norms_2d = [
                    compute_l2_norm_quadrature(f_exp_2d, [n, n], :chebyshev) for
                    n in grid_sizes_2d
                ]
                # Check that all norms are positive
                all(n -> n > 0, norms_2d) &&
                # Check convergence
                    begin
                        diffs =
                            [
                                abs(norms_2d[i + 1] - norms_2d[i]) for
                                i in 1:(length(norms_2d) - 1)
                            ]
                        # Last difference should be smaller than first
                        diffs[end] < diffs[1] || diffs[end] < 1e-8
                    end
            end
        end
    end

    # ==================== PHASE 2: Extended Dimensions ====================

    @testset "Phase 2: Extended Dimensions" begin

        @testset "2.1 3D and 4D Integration" begin
            # Constants in higher dimensions
            f_const = x -> 1.0

            # 3D: L2 norm = sqrt(8) = 2√2
            @test compute_l2_norm_quadrature(f_const, [5, 5, 5], :chebyshev) ≈ 2 * sqrt(2) rtol =
                1e-12

            # 4D: L2 norm = sqrt(16) = 4
            @test compute_l2_norm_quadrature(f_const, [5, 5, 5, 5], :chebyshev) ≈ 4.0 rtol =
                1e-12

            # Simple separable functions
            # 3D: f(x,y,z) = x² * y² * z²
            f_sep_3d = x -> x[1]^2 * x[2]^2 * x[3]^2
            @test begin
                l2_norm = compute_l2_norm_quadrature(f_sep_3d, [5, 5, 5], :chebyshev)
                isapprox(l2_norm, (2 / 5)^(3 / 2), rtol = 1e-12)  # Each dimension contributes sqrt(2/5)
            end

            # 4D Gaussian
            f_gauss_4d = x -> exp(-sum(x[i]^2 for i in 1:4))
            @test begin
                l2_norm = compute_l2_norm_quadrature(f_gauss_4d, [5, 5, 5, 5], :chebyshev)
                l2_norm > 0 && isfinite(l2_norm)
            end

            # One function from LibFunctions per dimension
            # 3D: Scaled alpine1 to avoid extreme values
            f_alpine_3d = x -> alpine1(0.1 * SVector(x[1], x[2], x[3]))
            @test begin
                l2_norm = compute_l2_norm_quadrature(f_alpine_3d, [10, 10, 10], :chebyshev)
                l2_norm > 0 && isfinite(l2_norm)
            end

            # 4D: Cosine mixture
            f_cos_4d = x -> cosine_mixture(SVector(x[1], x[2], x[3], x[4]))
            @test begin
                l2_norm = compute_l2_norm_quadrature(f_cos_4d, [5, 5, 5, 5], :chebyshev)
                l2_norm > 0 && isfinite(l2_norm)
            end
        end

        @testset "2.2 Different Polynomial Bases" begin
            # Test function: smooth 2D Gaussian
            f_test = x -> exp(-(x[1]^2 + x[2]^2))
            n_points = [14, 14]

            # Chebyshev basis (reference)
            @test begin
                l2_cheb = compute_l2_norm_quadrature(f_test, n_points, :chebyshev)
                l2_cheb > 0 && isfinite(l2_cheb)
            end

            # Legendre basis
            @test begin
                l2_leg = compute_l2_norm_quadrature(f_test, n_points, :legendre)
                l2_leg > 0 && isfinite(l2_leg)
            end

            # Uniform measure basis
            @test begin
                l2_unif = compute_l2_norm_quadrature(f_test, n_points, :uniform)
                l2_unif > 0 && isfinite(l2_unif)
            end

            # All bases should give similar results for smooth functions
            @test begin
                l2_cheb = compute_l2_norm_quadrature(f_test, n_points, :chebyshev)
                l2_leg = compute_l2_norm_quadrature(f_test, n_points, :legendre)
                l2_unif = compute_l2_norm_quadrature(f_test, n_points, :uniform)

                # Check they're all close (within 1%)
                abs(l2_cheb - l2_leg) / l2_cheb < 0.01 &&
                    abs(l2_cheb - l2_unif) / l2_cheb < 0.01
            end

            # Test polynomial exactness with different bases
            # Constant should give exact result with any basis
            f_const = x -> 1.0
            @test compute_l2_norm_quadrature(f_const, [5, 5], :legendre) ≈ 2.0 rtol = 1e-12
            @test compute_l2_norm_quadrature(f_const, [5, 5], :uniform) ≈ 2.0 rtol = 1e-12
        end
    end
end

# Utility function to run only Phase 1 tests
function run_phase1_tests()
    @testset "Phase 1 Only" begin
        include("test_quadrature_l2_phase1_2.jl")
        # Run only Phase 1 tests by filtering
    end
end

# Utility function to check if implementation is ready for Phase 2
function check_phase1_complete()
    println("Phase 1 tests status:")
    println("- [ ] 1.1 Polynomial Exactness (1D)")
    println("- [ ] 1.2 Basic Multi-dimensional (2D)")
    println("- [ ] 1.3 Single Basis Type (Chebyshev)")
    println("- [ ] 1.4 Basic Convergence")
    println("\nRun all Phase 1 tests and ensure they pass before moving to Phase 2")
end
