using Test
using Globtim
using LinearAlgebra
using StaticArrays

# Try to import BenchmarkTools - if not available, skip performance tests
const BENCHMARKS_AVAILABLE = try
    using BenchmarkTools
    true
catch
    false
end

@testset "Quadrature vs Riemann L2 Norm Comparison" begin

    @testset "Accuracy Comparison" begin
        # Test 1: Polynomial functions (quadrature should be exact)
        @testset "Polynomial Exactness" begin
            # 1D polynomial: f(x) = x^4
            f_poly_1d = x -> x[1]^4
            n_quad = [5]  # 5 points sufficient for degree 8

            # Generate grid for Riemann sum
            grid_1d = generate_grid(1, 14, basis = :chebyshev)

            l2_quad = compute_l2_norm_quadrature(f_poly_1d, n_quad, :chebyshev)
            l2_riemann = discrete_l2_norm_riemann(f_poly_1d, grid_1d)
            exact_l2 = sqrt(2 / 9)  # Analytical value

            @test abs(l2_quad - exact_l2) < 1e-14  # Quadrature should be exact
            @test abs(l2_riemann - exact_l2) > 1e-4  # Riemann has discretization error

            # 2D polynomial: f(x,y) = x^2 * y^2
            f_poly_2d = x -> x[1]^2 * x[2]^2
            n_quad_2d = [5, 5]
            grid_2d = generate_grid(2, 14, basis = :chebyshev)

            l2_quad_2d = compute_l2_norm_quadrature(f_poly_2d, n_quad_2d, :chebyshev)
            l2_riemann_2d = discrete_l2_norm_riemann(f_poly_2d, grid_2d)
            exact_l2_2d = 2 / 5  # sqrt((2/5)*(2/5)) = 2/5

            @test abs(l2_quad_2d - exact_l2_2d) < 1e-14
            @test abs(l2_riemann_2d - exact_l2_2d) > 1e-4
        end

        # Test 2: Smooth non-polynomial functions
        @testset "Smooth Functions" begin
            f_exp = x -> exp(-(x[1]^2 + get(x, 2, 0)^2))

            # 1D case
            errors_quad_1d = Float64[]
            errors_riemann_1d = Float64[]
            sizes = [5, 10, 15, 20]

            for n in sizes
                l2_quad = compute_l2_norm_quadrature(f_exp, [n], :chebyshev)
                grid = generate_grid(1, n, basis = :chebyshev)
                l2_riemann = discrete_l2_norm_riemann(f_exp, grid)

                # Use high-accuracy quadrature as reference
                l2_ref = compute_l2_norm_quadrature(f_exp, [20], :chebyshev)

                push!(errors_quad_1d, abs(l2_quad - l2_ref))
                push!(errors_riemann_1d, abs(l2_riemann - l2_ref))
            end

            # Quadrature should converge faster
            @test errors_quad_1d[end] < errors_riemann_1d[end]
            @test errors_quad_1d[end] < 1e-10

            # 2D case
            errors_quad_2d = Float64[]
            errors_riemann_2d = Float64[]
            sizes_2d = [5, 10, 20]

            for n in sizes_2d
                l2_quad = compute_l2_norm_quadrature(f_exp, [n, n], :chebyshev)
                grid = generate_grid(2, n, basis = :chebyshev)
                l2_riemann = discrete_l2_norm_riemann(f_exp, grid)

                # Use high-accuracy quadrature as reference
                l2_ref = compute_l2_norm_quadrature(f_exp, [20, 20], :chebyshev)

                push!(errors_quad_2d, abs(l2_quad - l2_ref))
                push!(errors_riemann_2d, abs(l2_riemann - l2_ref))
            end

            @test errors_quad_2d[end] < errors_riemann_2d[end]
        end

        # Test 3: Functions with singularities
        @testset "Peaked Functions" begin
            # Function with a peak at origin
            f_peak = x -> 1.0 / (1.0 + 100.0 * sum(xi -> xi^2, x))

            # Both methods should give reasonable results
            l2_quad = compute_l2_norm_quadrature(f_peak, [20, 20], :chebyshev)
            grid = generate_grid(2, 14, basis = :chebyshev)
            l2_riemann = discrete_l2_norm_riemann(f_peak, grid)

            @test l2_quad > 0 && isfinite(l2_quad)
            @test l2_riemann > 0 && isfinite(l2_riemann)
            @test abs(l2_quad - l2_riemann) / l2_quad < 0.1  # Within 10%
        end
    end

    @testset "Performance Comparison" begin
        # Skip detailed benchmarking in normal test runs or if BenchmarkTools not available
        if BENCHMARKS_AVAILABLE && get(ENV, "BENCHMARK_TESTS", "false") == "true"
            println("\nPerformance Comparison Results:")
            println("="^60)

            # 2D moderate size
            f_test = x -> exp(-(x[1]^2 + x[2]^2))
            n = 20

            println("\n2D Function (20×20 points):")
            t_quad = @benchmark compute_l2_norm_quadrature($f_test, [$n, $n], :chebyshev)
            grid_2d = generate_grid(2, n, basis = :chebyshev)
            t_riemann = @benchmark discrete_l2_norm_riemann($f_test, $grid_2d)

            println("  Quadrature: ", minimum(t_quad.times) / 1e6, " ms")
            println("  Riemann:    ", minimum(t_riemann.times) / 1e6, " ms")

            # 3D comparison
            println("\n3D Function (10×10×10 points):")
            f_test_3d = x -> exp(-sum(xi -> xi^2, x))
            n_3d = 10

            t_quad_3d = @benchmark compute_l2_norm_quadrature(
                $f_test_3d,
                [$n_3d, $n_3d, $n_3d],
                :chebyshev,
            )
            grid_3d = generate_grid(3, n_3d, basis = :chebyshev)
            t_riemann_3d = @benchmark discrete_l2_norm_riemann($f_test_3d, $grid_3d)

            println("  Quadrature: ", minimum(t_quad_3d.times) / 1e6, " ms")
            println("  Riemann:    ", minimum(t_riemann_3d.times) / 1e6, " ms")

            # 4D comparison (smaller grid)
            println("\n4D Function (5×5×5×5 points):")
            f_test_4d = x -> exp(-sum(xi -> xi^2, x))
            n_4d = 5

            t_quad_4d = @benchmark compute_l2_norm_quadrature(
                $f_test_4d,
                fill($n_4d, 4),
                :chebyshev,
            )
            grid_4d = generate_grid_small_n(4, n_4d, basis = :chebyshev)
            t_riemann_4d = @benchmark discrete_l2_norm_riemann($f_test_4d, $grid_4d)

            println("  Quadrature: ", minimum(t_quad_4d.times) / 1e6, " ms")
            println("  Riemann:    ", minimum(t_riemann_4d.times) / 1e6, " ms")
        else
            # Basic performance test
            f_test = x -> exp(-(x[1]^2 + x[2]^2))

            # Just verify both methods complete in reasonable time
            t1 = @elapsed compute_l2_norm_quadrature(f_test, [20, 20], :chebyshev)
            grid = generate_grid(2, 14, basis = :chebyshev)
            t2 = @elapsed discrete_l2_norm_riemann(f_test, grid)

            @test t1 < 1.0  # Should complete in less than 1 second
            @test t2 < 1.0
        end
    end

    @testset "Different Bases Comparison" begin
        f_test = x -> exp(-sum(xi -> xi^2, x))
        n = 15

        # Compare across different bases
        bases = [:chebyshev, :legendre, :uniform]

        for basis in bases
            @testset "Basis: $basis" begin
                # Quadrature
                l2_quad = compute_l2_norm_quadrature(f_test, [n, n], basis)

                # Riemann (generate appropriate grid)
                grid = generate_grid(2, n, basis = basis)
                l2_riemann = discrete_l2_norm_riemann(f_test, grid)

                @test l2_quad > 0 && isfinite(l2_quad)
                @test l2_riemann > 0 && isfinite(l2_riemann)

                # They should be reasonably close
                rel_diff = abs(l2_quad - l2_riemann) / l2_quad
                @test rel_diff < 0.05  # Within 5%
            end
        end
    end
end

# Utility function to run benchmarks separately
function run_performance_benchmarks()
    ENV["BENCHMARK_TESTS"] = "true"
    include("test_quadrature_vs_riemann.jl")
end
