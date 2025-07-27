# Test suite for new grid-based MainGenerate functionality

using Test
using Globtim
using LinearAlgebra
using StaticArrays

@testset "Grid-based MainGenerate" begin

    @testset "Simple 1D grid input" begin
        # Test with a simple quadratic function
        f = x -> x[1]^2
        n = 1

        # Create a simple 1D grid
        grid_1d = reshape([-0.8, -0.4, 0.0, 0.4, 0.8], :, 1)

        # Call MainGenerate with grid
        pol = Globtim.MainGenerate(f, n, grid_1d, 0.1, 0.99, 1.0, 1.0, verbose = 0)

        @test isa(pol, ApproxPoly)
        @test pol.grid == grid_1d
        @test pol.N == 5
        @test pol.degree == (:one_d_for_all, 4)  # 5 points → degree 4
        @test pol.nrm < 1e-10  # Should be very accurate for polynomial
    end

    @testset "2D grid input" begin
        f = x -> x[1]^2 + x[2]^2
        n = 2

        # Create a simple 2D grid (2x2 tensor product)
        grid_2d = [
            -0.7071 -0.7071
            0.7071 -0.7071
            -0.7071 0.7071
            0.7071 0.7071
        ]

        pol = Globtim.MainGenerate(f, n, grid_2d, 0.1, 0.99, 1.0, 1.0, verbose = 0)

        @test pol.grid == grid_2d
        @test pol.N == 4
        @test pol.degree == (:one_d_for_all, 1)  # 2 points per dim → degree 1
        @test pol.nrm < 1e-10
    end

    @testset "Custom grid with tensor product structure" begin
        f = x -> x[1]^4 + x[2]^2
        n = 2

        # Create a custom grid that maintains tensor product structure
        # This demonstrates current limitation: grids must be tensor products
        GN = 4  # 4x4 grid
        points = [cos((2i + 1) * π / (2 * GN)) for i = 0:GN-1]

        # Create tensor product grid manually
        grid_matrix = Matrix{Float64}(undef, GN^2, 2)
        idx = 1
        for i = 1:GN, j = 1:GN
            grid_matrix[idx, 1] = points[i]
            grid_matrix[idx, 2] = points[j]
            idx += 1
        end

        pol = Globtim.MainGenerate(f, n, grid_matrix, 0.1, 0.99, 1.0, 1.0, verbose = 0)

        @test size(pol.grid, 1) == GN^2
        @test size(pol.grid, 2) == 2
        @test pol.N == GN^2
        @test pol.degree == (:one_d_for_all, GN - 1)

        # NOTE: True anisotropic grids (different points per dimension)
        # are not yet supported due to lambda_vandermonde limitations
    end

    @testset "Grid validation" begin
        f = x -> sum(x)

        # Test dimension mismatch
        n = 2
        grid_wrong_dim = reshape([1.0, 2.0, 3.0], :, 1)  # 1D grid for 2D problem

        @test_throws AssertionError Globtim.MainGenerate(
            f,
            n,
            grid_wrong_dim,
            0.1,
            0.99,
            1.0,
            1.0,
        )

        # Test empty grid
        empty_grid = Matrix{Float64}(undef, 0, 2)
        @test_throws AssertionError Globtim.MainGenerate(
            f,
            n,
            empty_grid,
            0.1,
            0.99,
            1.0,
            1.0,
        )
    end

    @testset "Different basis types with grid" begin
        f = x -> exp(-sum(x .^ 2))
        n = 2

        # Create a grid manually
        grid = [
            0.0 0.0
            0.5 0.5
            -0.5 0.5
            0.5 -0.5
            -0.5 -0.5
        ]

        # Test with Chebyshev
        pol_cheb = Globtim.MainGenerate(
            f,
            n,
            grid,
            0.1,
            0.99,
            1.0,
            1.0,
            basis = :chebyshev,
            verbose = 0,
        )
        @test pol_cheb.basis == :chebyshev

        # Test with Legendre
        pol_leg = Globtim.MainGenerate(
            f,
            n,
            grid,
            0.1,
            0.99,
            1.0,
            1.0,
            basis = :legendre,
            verbose = 0,
        )
        @test pol_leg.basis == :legendre

        # Both should use the same grid
        @test pol_cheb.grid == pol_leg.grid == grid
    end

    @testset "Scale factor with grid input" begin
        f = x -> sum(x .^ 2)
        n = 2

        grid = [
            0.0 0.0
            1.0 0.0
            0.0 1.0
            1.0 1.0
        ]

        # Scalar scale factor
        pol_scalar = Globtim.MainGenerate(f, n, grid, 0.1, 0.99, 2.0, 1.0, verbose = 0)
        @test pol_scalar.scale_factor == 2.0

        # Vector scale factor
        pol_vec = Globtim.MainGenerate(f, n, grid, 0.1, 0.99, [2.0, 3.0], 1.0, verbose = 0)
        @test pol_vec.scale_factor == [2.0, 3.0]

        # Grid should be the same
        @test pol_scalar.grid == pol_vec.grid == grid
    end

    @testset "Performance comparison" begin
        # Grid input should be faster than grid generation
        f = x -> exp(-sum(x .^ 2))
        n = 2  # Use 2D for simpler testing
        d = (:one_d_for_all, 4)

        # Create a specific grid to use for both
        GN = 5
        grid_test = Globtim.generate_grid(n, GN, basis = :chebyshev)
        grid_matrix = reduce(vcat, map(x -> x', reshape(grid_test, :)))

        # Time with automatic grid generation
        t1 = @elapsed pol1 =
            Globtim.MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0, GN = GN, verbose = 0)

        # Time with pre-generated grid
        t2 = @elapsed pol2 =
            Globtim.MainGenerate(f, n, grid_matrix, 0.1, 0.99, 1.0, 1.0, verbose = 0)

        # Check that grid-based produces reasonable results
        @test pol2.N == size(grid_matrix, 1)
        @test pol2.grid == grid_matrix

        # Grid-based should be somewhat faster (skip grid generation)
        println("Grid generation time: $t1 seconds")
        println("Pre-generated grid time: $t2 seconds")
        @test t2 < t1 * 1.2  # Allow some variance
    end
end

@testset "Grid conversion utilities" begin

    @testset "Vector to matrix conversion" begin
        # Create vector of SVectors
        grid_vec = [SVector(0.0, 0.0), SVector(1.0, 0.0), SVector(0.0, 1.0)]

        # Convert to matrix
        grid_mat = convert_to_matrix_grid(grid_vec)

        @test size(grid_mat) == (3, 2)
        @test grid_mat[1, :] == [0.0, 0.0]
        @test grid_mat[2, :] == [1.0, 0.0]
        @test grid_mat[3, :] == [0.0, 1.0]
    end

    @testset "Matrix to vector conversion" begin
        # Create matrix grid
        grid_mat = [0.0 0.0; 1.0 0.0; 0.0 1.0]

        # Convert to vector of SVectors
        grid_vec = convert_to_svector_grid(grid_mat)

        @test length(grid_vec) == 3
        @test grid_vec[1] == SVector(0.0, 0.0)
        @test grid_vec[2] == SVector(1.0, 0.0)
        @test grid_vec[3] == SVector(0.0, 1.0)
    end

    @testset "Grid validation" begin
        n = 2

        # Valid grid
        valid_grid = [0.0 0.0; 0.5 0.5; -0.5 -0.5]
        @test validate_grid(valid_grid, n) === nothing

        # Wrong dimension
        wrong_dim = [0.0; 0.5; -0.5]
        @test_throws DimensionMismatch validate_grid(reshape(wrong_dim, :, 1), n)

        # Empty grid
        empty_grid = Matrix{Float64}(undef, 0, 2)
        @test_throws ArgumentError validate_grid(empty_grid, n)

        # Points outside range (should warn)
        out_of_range = [0.0 0.0; 1.5 0.5; -0.5 -1.2]
        @test_logs (:warn,) (:warn,) validate_grid(out_of_range, n)
    end
end

println("\nGrid-based MainGenerate tests completed!")
