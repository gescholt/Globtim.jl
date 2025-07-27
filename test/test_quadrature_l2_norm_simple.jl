using Test
using Globtim
using LinearAlgebra

@testset "Simple Quadrature L2 Norm Tests" begin
    # Test that the quadrature function exists
    @test isdefined(Globtim, :compute_l2_norm_quadrature)

    @testset "Basic functionality" begin
        # Simple constant function test
        f_const = x -> 1.0

        # 1D test
        n_points = [10]
        result = compute_l2_norm_quadrature(f_const, n_points, :chebyshev)
        expected = sqrt(2.0)  # sqrt of integral of 1² over [-1,1]
        @test result ≈ expected rtol = 1e-10

        # 2D test  
        n_points_2d = [10, 10]
        result_2d = compute_l2_norm_quadrature(f_const, n_points_2d, :chebyshev)
        expected_2d = 2.0  # sqrt of integral of 1² over [-1,1]^2 = sqrt(4) = 2
        @test result_2d ≈ expected_2d rtol = 1e-10
    end

    @testset "Different bases" begin
        f_test = x -> exp(-sum(x .^ 2))
        n_points = [15, 15]

        # Test that different bases give similar results
        result_cheb = compute_l2_norm_quadrature(f_test, n_points, :chebyshev)
        result_leg = compute_l2_norm_quadrature(f_test, n_points, :legendre)

        @test result_cheb > 0
        @test result_leg > 0
        @test result_cheb ≈ result_leg rtol = 0.01
    end
end
