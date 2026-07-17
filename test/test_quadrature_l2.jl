# Tests for compute_l2_norm_quadrature / gauss_legendre (src/quadrature_l2_norm.jl)

using Test
using Globtim

@testset "Quadrature L2 norm" begin
    @testset "Gauss-Legendre rule" begin
        for n in (1, 2, 5, 20)
            nodes, weights = Globtim.gauss_legendre(n)
            @test length(nodes) == n
            @test length(weights) == n
            @test sum(weights) ≈ 2.0 atol = 1e-13
            @test all(-1.0 .<= nodes .<= 1.0)
            # exactness: an n-point rule integrates degree 2n-1 exactly
            for k = 0:(2n-1)
                exact = iseven(k) ? 2.0 / (k + 1) : 0.0
                @test sum(weights .* nodes .^ k) ≈ exact atol = 1e-12
            end
        end
        @test_throws ErrorException Globtim.gauss_legendre(0)
    end

    @testset "Polynomial exactness (2D)" begin
        # ||1||_{L2([-1,1]^2)} = 2
        @test compute_l2_norm_quadrature(x -> 1.0, [5, 5], :legendre) ≈ 2.0 atol = 1e-12
        # ||x1^2||^2 = ∫x^4 dx * ∫1 dy = (2/5)*2
        @test compute_l2_norm_quadrature(x -> x[1]^2, [5, 5], :chebyshev) ≈ sqrt(0.8) atol =
            1e-12
        # :uniform must agree with :legendre (weights absorb the measure normalization)
        @test compute_l2_norm_quadrature(x -> x[1]^2 * x[2], [6, 6], :uniform) ≈
              compute_l2_norm_quadrature(x -> x[1]^2 * x[2], [6, 6], :legendre) atol = 1e-13
    end

    @testset "Convergence on a smooth non-polynomial (1D)" begin
        # ||exp(x)||^2 = ∫ exp(2x) dx = (e^2 - e^-2)/2 on [-1,1]
        exact = sqrt((exp(2.0) - exp(-2.0)) / 2.0)
        @test compute_l2_norm_quadrature(x -> exp(x[1]), [12], :legendre) ≈ exact atol =
            1e-12
        err_coarse = abs(compute_l2_norm_quadrature(x -> exp(x[1]), [3], :legendre) - exact)
        err_fine = abs(compute_l2_norm_quadrature(x -> exp(x[1]), [6], :legendre) - exact)
        @test err_fine < err_coarse
    end

    @testset "Anisotropic grids (3D)" begin
        # ||x1 * x2^2 * x3^3||^2 = (2/3)(2/5)(2/7)
        exact = sqrt((2.0 / 3.0) * (2.0 / 5.0) * (2.0 / 7.0))
        @test compute_l2_norm_quadrature(
            x -> x[1] * x[2]^2 * x[3]^3,
            [2, 3, 4],
            :legendre,
        ) ≈ exact atol = 1e-12
    end

    @testset "Unknown basis errors" begin
        @test_throws ErrorException compute_l2_norm_quadrature(x -> 1.0, [3], :hermite)
    end
end
