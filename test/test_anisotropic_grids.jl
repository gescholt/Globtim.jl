using Test
using Globtim
using LinearAlgebra
using StaticArrays

@testset "Anisotropic Grid Tests" begin

    @testset "Basic Anisotropic Grid Generation" begin
        # Test 1: 2D anisotropic grid
        grid_2d = generate_anisotropic_grid([3, 5], basis = :chebyshev)
        @test size(grid_2d) == (4, 6)  # 3+1, 5+1
        @test eltype(grid_2d) <: SVector{2, Float64}
        @test all(p -> all(-1 <= p[i] <= 1 for i in 1:2), grid_2d)

        # Test 2: 3D anisotropic grid  
        grid_3d = generate_anisotropic_grid([2, 4, 3], basis = :legendre)
        @test size(grid_3d) == (3, 5, 4)
        @test eltype(grid_3d) <: SVector{3, Float64}

        # Test 3: High-dimensional anisotropic grid
        grid_5d = generate_anisotropic_grid([2, 3, 2, 4, 3], basis = :uniform)
        @test size(grid_5d) == (3, 4, 3, 5, 4)
        @test eltype(grid_5d) <: SVector{5, Float64}
    end

    @testset "Grid Properties" begin
        # Test different bases produce correct node distributions
        n_points = [5, 3]

        # Chebyshev nodes cluster at boundaries
        grid_cheb = generate_anisotropic_grid(n_points, basis = :chebyshev)
        x_coords = unique([p[1] for p in grid_cheb])
        @test length(x_coords) == 6  # 5+1
        # Chebyshev nodes don't include endpoints exactly
        @test maximum(x_coords) < 1.0
        @test minimum(x_coords) > -1.0

        # Uniform nodes are equally spaced
        grid_unif = generate_anisotropic_grid(n_points, basis = :uniform)
        x_coords_unif = sort(unique([p[1] for p in grid_unif]))
        spacings = diff(x_coords_unif)
        @test all(s -> isapprox(s, spacings[1], rtol = 1e-10), spacings)
    end

    @testset "L2 Norm on Anisotropic Grids - Quadrature" begin
        # Test 1: Separable polynomial where we know exact answer
        # f(x,y) = x^2 on [-1,1]×[-1,1], L2 norm = sqrt(∫∫ x^4 dxdy) = sqrt(2/5 * 2) = 2/sqrt(5)
        f_sep = x -> x[1]^2

        # Anisotropic grid: more points in x than y
        l2_aniso = compute_l2_norm_quadrature(f_sep, [10, 3], :chebyshev)
        @test isapprox(l2_aniso, 2 / sqrt(5), rtol = 1e-12)

        # Test 2: Function that varies more in one direction
        # Should benefit from anisotropic grid
        f_aniso = x -> exp(-10 * x[1]^2 - x[2]^2)

        # Compare isotropic vs anisotropic with same total points
        l2_iso = compute_l2_norm_quadrature(f_aniso, [7, 7], :chebyshev)  # 49 points
        l2_aniso_smart = compute_l2_norm_quadrature(f_aniso, [10, 5], :chebyshev)  # 50 points

        # Both should give reasonable results
        @test abs(l2_iso - l2_aniso_smart) / l2_iso < 0.1  # Within 10%
    end

    @testset "L2 Norm on Anisotropic Grids - Riemann" begin
        # Test discrete L2 norm with anisotropic grids
        f_test = x -> exp(-(x[1]^2 + x[2]^2))

        # Create anisotropic grid
        grid = generate_anisotropic_grid([14, 8], basis = :chebyshev)

        # Compute L2 norm
        l2_riemann = discrete_l2_norm_riemann(f_test, grid)
        @test l2_riemann > 0 && isfinite(l2_riemann)

        # Compare with quadrature
        l2_quad = compute_l2_norm_quadrature(f_test, [14, 8], :chebyshev)
        @test abs(l2_riemann - l2_quad) / l2_quad < 0.05  # Within 5%
    end

    @testset "Optimal Anisotropic Grids" begin
        # Test cases where anisotropic grids should outperform isotropic ones

        # Function with different scales in each direction
        f_multiscale = x -> exp(-100 * x[1]^2 - x[2]^2)

        # Reference value with high accuracy
        l2_ref = compute_l2_norm_quadrature(f_multiscale, [14, 14], :chebyshev)

        # Isotropic grid
        n_iso = 12
        l2_iso = compute_l2_norm_quadrature(f_multiscale, [n_iso, n_iso], :chebyshev)
        error_iso = abs(l2_iso - l2_ref)

        # Smart anisotropic grid (more points in x where function varies rapidly)
        l2_aniso = compute_l2_norm_quadrature(f_multiscale, [14, 10], :chebyshev)
        error_aniso = abs(l2_aniso - l2_ref)

        # Anisotropic should be more accurate despite similar total points
        @test error_aniso < error_iso

        println("Isotropic error: $error_iso")
        println("Anisotropic error: $error_aniso")
        println("Improvement factor: $(error_iso/error_aniso)")
    end

    @testset "High-Dimensional Anisotropic Grids" begin
        # Test in 4D with very anisotropic grid
        f_4d = x -> exp(-sum(i * x[i]^2 for i in 1:4))

        # Very anisotropic: more points where function varies more
        grid_sizes = [10, 8, 6, 4]  # Decreasing resolution
        l2_aniso_4d = compute_l2_norm_quadrature(f_4d, grid_sizes, :chebyshev)

        @test l2_aniso_4d > 0 && isfinite(l2_aniso_4d)

        # Test with uniform small grid for comparison
        l2_uniform_4d = compute_l2_norm_quadrature(f_4d, [6, 6, 6, 6], :chebyshev)
        @test abs(l2_aniso_4d - l2_uniform_4d) / l2_uniform_4d < 0.1  # Reasonable agreement
    end

    @testset "Utility Functions" begin
        # Test grid dimension extraction
        grid = generate_anisotropic_grid([3, 5, 2])
        dims = get_grid_dimensions(grid)
        @test dims == [4, 6, 3]

        # Test anisotropy detection
        @test is_anisotropic(grid) == true

        iso_grid = generate_grid(5, 3)  # Old interface
        @test is_anisotropic(iso_grid) == false
    end

    @testset "Backward Compatibility" begin
        # Test that old interface still works
        grid_old = generate_grid(2, 5, basis = :chebyshev)  # 2 dims, 5+1 points each
        grid_new = generate_anisotropic_grid([5, 5], basis = :chebyshev)

        @test size(grid_old) == size(grid_new)
        @test grid_old == grid_new
    end
end

# Function to demonstrate anisotropic grid benefits
function demonstrate_anisotropic_benefits()
    println("\n" * "="^60)
    println("Anisotropic Grid Benefits Demonstration")
    println("="^60)

    # Function that varies at different rates
    f = x -> exp(-50 * x[1]^2 - 2 * x[2]^2)

    # High-accuracy reference
    l2_ref = compute_l2_norm_quadrature(f, [14, 14], :chebyshev)
    println("\nReference L2 norm (14×14): $l2_ref")

    # Test different grid configurations with ~400 total points
    configs = [
        ([10, 10], "Isotropic 10×10"),
        ([14, 7], "Anisotropic 14×7"),
        ([12, 8], "Anisotropic 12×8"),
        ([11, 9], "Anisotropic 11×9")
    ]

    println("\nGrid Configuration Results:")
    println("-"^40)
    for (grid_size, name) in configs
        l2 = compute_l2_norm_quadrature(f, grid_size, :chebyshev)
        error = abs(l2 - l2_ref)
        rel_error = error / l2_ref * 100
        total_points = prod(grid_size .+ 1)
        println(
            "$name ($(total_points) points): L2=$l2, Error=$error ($(round(rel_error, digits=3))%)"
        )
    end
end
