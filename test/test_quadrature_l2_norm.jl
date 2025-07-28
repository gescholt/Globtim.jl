using Test
using Globtim
using PolyChaos
using LinearAlgebra
using StaticArrays

# Placeholder for the quadrature L2 norm function that will be implemented
# For now, we'll use a mock that calls the example from L2_grid_ideas.jl
include("../Examples/L2_grid_ideas.jl")

@testset "Quadrature-based L2 Norm Tests" begin

    @testset "1. Polynomial Exactness Tests" begin
        @testset "1D polynomial exactness" begin
            # Test that quadrature is exact for polynomials up to degree 2n-1
            # For n Chebyshev nodes, should be exact for polynomials up to degree 2n-1

            # Test constant function: f(x) = 1
            # Analytical L2 norm on [-1,1]: sqrt(2)
            f_const = x -> 1.0
            for n_points in [5, 10, 15]
                l2_norm = compute_L2_norm_tensor(f_const, [n_points], :chebyshev)
                @test l2_norm ≈ sqrt(2.0) rtol = 1e-12
            end

            # Test quadratic: f(x) = x^2
            # Analytical L2 norm: sqrt(2/5)
            f_quad = x -> x[1]^2
            for n_points in [3, 5, 10]
                l2_norm = compute_L2_norm_tensor(f_quad, [n_points], :chebyshev)
                @test l2_norm ≈ sqrt(2 / 5) rtol = 1e-12
            end

            # Test x^4
            # Analytical L2 norm: sqrt(2/9)
            f_quartic = x -> x[1]^4
            for n_points in [3, 5, 10]
                l2_norm = compute_L2_norm_tensor(f_quartic, [n_points], :chebyshev)
                @test l2_norm ≈ sqrt(2 / 9) rtol = 1e-12
            end
        end

        @testset "2D polynomial exactness" begin
            # Test constant in 2D: f(x,y) = 1
            # L2 norm on [-1,1]^2: sqrt(4) = 2
            f_const_2d = x -> 1.0
            l2_norm = compute_L2_norm_tensor(f_const_2d, [10, 10], :chebyshev)
            @test l2_norm ≈ 2.0 rtol = 1e-12

            # Test separable polynomial: f(x,y) = x^2 * y^2
            # L2 norm: sqrt((2/5) * (2/5)) = 2/5
            f_sep = x -> x[1]^2 * x[2]^2
            l2_norm = compute_L2_norm_tensor(f_sep, [5, 5], :chebyshev)
            @test l2_norm ≈ 2 / 5 rtol = 1e-12
        end

        @testset "3D polynomial exactness" begin
            # Test constant in 3D: f(x,y,z) = 1
            # L2 norm on [-1,1]^3: sqrt(8) = 2*sqrt(2)
            f_const_3d = x -> 1.0
            l2_norm = compute_L2_norm_tensor(f_const_3d, [5, 5, 5], :chebyshev)
            @test l2_norm ≈ 2 * sqrt(2) rtol = 1e-12
        end
    end

    @testset "2. Multi-dimensional Integration Tests" begin
        @testset "2D functions from LibFunctions" begin
            # Test on a smaller domain to avoid extreme oscillations
            scale = 0.5

            # Simple 2D Gaussian-like function
            f_gauss_2d = x -> exp(-(x[1]^2 + x[2]^2))
            l2_norm_5 = compute_L2_norm_tensor(f_gauss_2d, [5, 5], :chebyshev)
            l2_norm_10 = compute_L2_norm_tensor(f_gauss_2d, [10, 10], :chebyshev)
            l2_norm_20 = compute_L2_norm_tensor(f_gauss_2d, [20, 20], :chebyshev)

            # Should see convergence
            @test l2_norm_5 > 0
            @test l2_norm_10 > 0
            @test l2_norm_20 > 0

            # Test Ackley function (scaled domain)
            f_ackley = x -> Ackley(scale * x)
            l2_norm = compute_L2_norm_tensor(f_ackley, [20, 20], :chebyshev)
            @test l2_norm > 0
            @test isfinite(l2_norm)
        end

        @testset "3D functions from LibFunctions" begin
            # 3D Gaussian
            f_gauss_3d = x -> exp(-(x[1]^2 + x[2]^2 + x[3]^2))
            l2_norm = compute_L2_norm_tensor(f_gauss_3d, [10, 10, 10], :chebyshev)
            @test l2_norm > 0
            @test isfinite(l2_norm)

            # Alpine1 function (scaled)
            f_alpine = x -> alpine1(0.1 * SVector(x...))
            l2_norm = compute_L2_norm_tensor(f_alpine, [15, 15, 15], :chebyshev)
            @test l2_norm > 0
            @test isfinite(l2_norm)
        end

        @testset "4D functions" begin
            # 4D Gaussian
            f_gauss_4d = x -> exp(-sum(x[i]^2 for i in 1:4))
            l2_norm = compute_L2_norm_tensor(f_gauss_4d, [5, 5, 5, 5], :chebyshev)
            @test l2_norm > 0
            @test isfinite(l2_norm)

            # Cosine mixture (scaled)
            f_cos_mix = x -> cosine_mixture(SVector(x...))
            l2_norm = compute_L2_norm_tensor(f_cos_mix, [8, 8, 8, 8], :chebyshev)
            @test l2_norm > 0
            @test isfinite(l2_norm)
        end
    end

    @testset "3. Convergence Tests" begin
        # Test that L2 norm estimates converge as we increase grid size
        grid_sizes = [5, 10, 12, 14]

        @testset "1D convergence" begin
            f = x -> exp(-x[1]^2)
            norms = Float64[]

            for n in grid_sizes
                push!(norms, compute_L2_norm_tensor(f, [n], :chebyshev))
            end

            # Check that differences decrease
            diffs = [abs(norms[i + 1] - norms[i]) for i in 1:(length(norms) - 1)]
            for i in 1:(length(diffs) - 1)
                @test diffs[i + 1] < diffs[i] || diffs[i + 1] < 1e-10
            end
        end

        @testset "2D convergence" begin
            f = x -> exp(-(x[1]^2 + x[2]^2))
            norms = Float64[]

            for n in grid_sizes[1:3]  # Limit to avoid too many points
                push!(norms, compute_L2_norm_tensor(f, [n, n], :chebyshev))
            end

            # Check convergence
            diffs = [abs(norms[i + 1] - norms[i]) for i in 1:(length(norms) - 1)]
            @test all(d -> d ≥ 0, diffs)  # All norms should be positive
            @test diffs[end] < diffs[1] || diffs[end] < 1e-8  # Should converge
        end

        @testset "3D convergence" begin
            f = x -> exp(-sum(x[i]^2 for i in 1:3))
            norms = Float64[]

            for n in [5, 10, 15]  # Smaller grids for 3D
                push!(norms, compute_L2_norm_tensor(f, [n, n, n], :chebyshev))
            end

            # Check basic properties
            @test all(n -> n > 0, norms)
            @test all(n -> isfinite(n), norms)
        end
    end

    @testset "4. Different Polynomial Bases" begin
        # Test that different bases give consistent results for smooth functions
        f_smooth = x -> exp(-(x[1]^2 + x[2]^2))
        n_points = [14, 14]

        @testset "Pure bases" begin
            l2_cheb = compute_L2_norm_tensor(f_smooth, n_points, :chebyshev)
            l2_leg = compute_L2_norm_tensor(f_smooth, n_points, :legendre)
            l2_unif = compute_L2_norm_tensor(f_smooth, n_points, :uniform)

            # All should give similar results for smooth functions
            @test l2_cheb ≈ l2_leg rtol = 0.01
            @test l2_cheb ≈ l2_unif rtol = 0.01
        end

        @testset "Mixed bases" begin
            # Test mixed bases in 2D
            specs = [(15, :chebyshev), (15, :legendre)]
            l2_mixed = compute_L2_norm_mixed(f_smooth, specs)
            l2_pure = compute_L2_norm_tensor(f_smooth, n_points, :chebyshev)

            @test l2_mixed ≈ l2_pure rtol = 0.01
        end

        @testset "Jacobi polynomials" begin
            # Test with Jacobi parameters
            specs = [(10, :jacobi), (10, :jacobi)]
            l2_jacobi = compute_L2_norm_mixed(f_smooth, specs)

            @test l2_jacobi > 0
            @test isfinite(l2_jacobi)
        end
    end

    @testset "5. Special Function Classes" begin
        @testset "Constants in various dimensions" begin
            f_const = x -> 1.0

            # 1D: L2 norm = sqrt(2)
            @test compute_L2_norm_tensor(f_const, [5], :chebyshev) ≈ sqrt(2) rtol = 1e-12

            # 2D: L2 norm = 2
            @test compute_L2_norm_tensor(f_const, [5, 5], :chebyshev) ≈ 2.0 rtol = 1e-12

            # 3D: L2 norm = 2*sqrt(2)
            @test compute_L2_norm_tensor(f_const, [5, 5, 5], :chebyshev) ≈ 2 * sqrt(2) rtol =
                1e-12

            # 4D: L2 norm = 4
            @test compute_L2_norm_tensor(f_const, [5, 5, 5, 5], :chebyshev) ≈ 4.0 rtol =
                1e-12
        end

        @testset "Odd functions (should integrate to 0)" begin
            # Odd functions should have very small L2 norms due to cancellation
            # Actually, L2 norm of odd functions is NOT zero! Only the integral is zero
            # L2 norm involves squaring, which makes everything positive

            # Linear function: f(x) = x
            f_linear = x -> x[1]
            l2_norm = compute_L2_norm_tensor(f_linear, [10], :chebyshev)
            @test l2_norm ≈ sqrt(2 / 3) rtol = 1e-10  # Analytical: sqrt(∫x² dx from -1 to 1)
        end

        @testset "Gaussian mixtures" begin
            # Test with a simple Gaussian mixture
            params = init_gaussian_params(2, 3, 1.0, 0.5)
            f_gauss_mix = x -> rand_gaussian(SVector(x...), params)

            l2_norm = compute_L2_norm_tensor(f_gauss_mix, [20, 20], :chebyshev)
            @test l2_norm > 0
            @test isfinite(l2_norm)
        end

        @testset "Highly oscillatory functions" begin
            # Scaled version of tref to avoid extreme oscillations
            f_tref_scaled = x -> tref(0.1 * SVector(x...))

            # Should still get finite results
            l2_norm = compute_L2_norm_tensor(f_tref_scaled, [30, 30], :chebyshev)
            @test l2_norm > 0
            @test isfinite(l2_norm)
        end
    end

    @testset "6. Numerical Stability Tests" begin
        @testset "Near-zero functions" begin
            f_tiny = x -> 1e-10 * exp(-(x[1]^2 + x[2]^2))
            l2_norm = compute_L2_norm_tensor(f_tiny, [10, 10], :chebyshev)

            @test l2_norm > 0
            @test l2_norm < 1e-8
            @test isfinite(l2_norm)
        end

        @testset "Large coefficient ranges" begin
            # Function with large dynamic range
            f_large_range = x -> 1e6 * exp(-100 * (x[1]^2 + x[2]^2))
            l2_norm = compute_L2_norm_tensor(f_large_range, [20, 20], :chebyshev)

            @test l2_norm > 0
            @test isfinite(l2_norm)
        end

        @testset "Higher dimensions (up to 8)" begin
            # Test 6D
            f_6d = x -> exp(-sum(x[i]^2 for i in 1:6))
            l2_norm_6d = compute_L2_norm_tensor(f_6d, [3, 3, 3, 3, 3, 3], :chebyshev)
            @test l2_norm_6d > 0
            @test isfinite(l2_norm_6d)

            # Test 8D with very few points
            f_8d = x -> exp(-sum(x[i]^2 for i in 1:8))
            l2_norm_8d = compute_L2_norm_tensor(f_8d, [2, 2, 2, 2, 2, 2, 2, 2], :chebyshev)
            @test l2_norm_8d > 0
            @test isfinite(l2_norm_8d)
        end

        @testset "Boundary-concentrated functions" begin
            # Function concentrated near x = 1
            f_boundary = x -> exp(-10 * (x[1] - 0.9)^2)
            l2_norm = compute_L2_norm_tensor(f_boundary, [30], :chebyshev)

            @test l2_norm > 0
            @test isfinite(l2_norm)
        end
    end

    @testset "7. Integration with Existing Code" begin
        @testset "Comparison with discrete_l2_norm_riemann" begin
            # Create a simple test function
            f_test = x -> exp(-(x[1]^2 + x[2]^2))

            # Generate a Chebyshev grid using Globtim
            grid = generate_grid(2, 14, basis = :chebyshev)

            # Compute using Riemann sum approach
            f_vals_dict = Dict(i => f_test(grid[i]) for i in eachindex(grid))
            f_indexed = idx -> f_vals_dict[idx]
            l2_riemann = discrete_l2_norm_riemann(f_indexed, grid)

            # Compute using quadrature
            l2_quad = compute_L2_norm_tensor(f_test, [16, 16], :chebyshev)

            # They should be reasonably close
            @test l2_riemann > 0
            @test l2_quad > 0
            @test abs(l2_riemann - l2_quad) / l2_quad < 0.1  # Within 10%
        end

        @testset "Test with ApproxPoly structure" begin
            # Create a simple polynomial approximation
            f = x -> x[1]^2 + x[2]^2
            TR = test_input(f, dim = 2, center = [0.0, 0.0], sample_range = 1.0)
            pol = Constructor(TR, 5, basis = :chebyshev)

            # The stored L2 norm
            stored_norm = pol.nrm

            # For now, just check it's valid
            @test stored_norm > 0
            @test isfinite(stored_norm)
        end
    end
end
