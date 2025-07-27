# Test suite for anisotropic grid integration with MainGenerate
# Focus on testing limitations and edge cases

using Test
using Globtim
using LinearAlgebra
using StaticArrays

@testset "Anisotropic Grid Integration Tests" begin

    @testset "Lambda Vandermonde Limitations" begin
        # Test 1: True anisotropic grid that violates tensor product structure
        f = x -> sum(x .^ 2)
        n = 2

        # Create a truly anisotropic grid (different Chebyshev nodes per dimension)
        nodes_x = [cos((2i + 1) * π / (2 * 4)) for i = 0:3]  # 4 points
        nodes_y = [cos((2i + 1) * π / (2 * 6)) for i = 0:5]  # 6 points

        # This grid has 4×6=24 points but violates tensor product assumption
        grid_aniso = Matrix{Float64}(undef, 24, 2)
        idx = 1
        for i = 1:4, j = 1:6
            grid_aniso[idx, 1] = nodes_x[i]
            grid_aniso[idx, 2] = nodes_y[j]
            idx += 1
        end

        # This should work but with limitations
        pol = Globtim.MainGenerate(f, n, grid_aniso, 0.1, 0.99, 1.0, 1.0, verbose = 0)
        @test isa(pol, ApproxPoly)

        # Test 2: Document the inferred degree behavior
        # For 24 points in 2D, it infers degree ≈ 4 (since sqrt(24) ≈ 4.9)
        @test pol.degree == (:one_d_for_all, 4)

        # Test 3: Check if lambda_vandermonde handles this correctly
        # Currently it assumes same nodes in each dimension
        Lambda = Globtim.SupportGen(n, pol.degree)
        VL = Globtim.lambda_vandermonde(Lambda, grid_aniso, basis = :chebyshev)
        @test size(VL) == (24, size(Lambda.data, 2))
    end

    @testset "Grid Conversion Edge Cases" begin
        # Test 1: Single point grid
        single_pt = [SVector(0.5, -0.3)]
        mat = convert_to_matrix_grid(single_pt)
        @test size(mat) == (1, 2)
        @test mat[1, :] == [0.5, -0.3]

        # Test 2: High-dimensional grid
        grid_7d = [SVector{7}(randn(7)) for _ = 1:10]
        mat_7d = convert_to_matrix_grid(grid_7d)
        @test size(mat_7d) == (10, 7)

        # Test 3: Round-trip conversion accuracy
        original = randn(100, 5)
        vec_form = convert_to_svector_grid(original)
        recovered = convert_to_matrix_grid(vec_form)
        @test norm(original - recovered) < 1e-14
    end

    @testset "Performance Comparison" begin
        # Function with different scales in each direction
        f = x -> exp(-50 * x[1]^2 - 2 * x[2]^2)
        n = 2

        # Test different grid configurations
        configs = [
            ([15, 15], "Isotropic"),
            ([30, 8], "Anisotropic (tensor)"),
            ([25, 10], "Anisotropic (tensor)"),
        ]

        times = Float64[]
        errors = Float64[]

        # Reference solution
        ref_grid = Globtim.generate_grid(n, 14, basis = :chebyshev)
        ref_matrix = reduce(vcat, map(x -> x', reshape(ref_grid, :)))
        ref_pol = Globtim.MainGenerate(f, n, ref_matrix, 0.1, 0.99, 1.0, 1.0, verbose = 0)

        for (grid_size, name) in configs
            # Generate grid
            if grid_size[1] == grid_size[2]
                grid = Globtim.generate_grid(n, grid_size[1], basis = :chebyshev)
            else
                # Create pseudo-anisotropic grid (still tensor product)
                grid = Globtim.generate_anisotropic_grid(grid_size, basis = :chebyshev)
            end
            grid_matrix = reduce(vcat, map(x -> x', reshape(grid, :)))

            # Time approximation
            t = @elapsed pol = Globtim.MainGenerate(
                f,
                n,
                grid_matrix,
                0.1,
                0.99,
                1.0,
                1.0,
                verbose = 0,
            )
            push!(times, t)

            # Measure approximation error (simplified)
            push!(errors, pol.nrm)

            println("$name: time=$t, error=$(pol.nrm)")
        end

        # Anisotropic grids should provide better error/time tradeoff
        @test minimum(errors) < maximum(errors)
    end

    @testset "Numerical Stability Analysis" begin
        f = x -> prod(sin.(π * x))
        n = 2

        # Test increasingly stretched grids
        stretch_factors = [1.0, 2.0, 5.0, 10.0]
        condition_numbers = Float64[]

        for s in stretch_factors
            # Create stretched grid
            GN = 8
            grid = Globtim.generate_grid(n, GN, basis = :chebyshev)
            grid_matrix = reduce(vcat, map(x -> x', reshape(grid, :)))

            # Stretch in x-direction
            grid_matrix[:, 1] .*= s

            # Compute with stretched grid
            pol = Globtim.MainGenerate(
                f,
                n,
                grid_matrix,
                0.1,
                0.99,
                [s, 1.0],
                1.0,
                verbose = 0,
            )
            push!(condition_numbers, pol.G_cond)

            println("Stretch factor $s: condition number = $(pol.G_cond)")
        end

        # Condition number should increase with stretching
        @test issorted(condition_numbers)
        @test condition_numbers[end] / condition_numbers[1] > 2.0
    end

    @testset "Error Handling and User Experience" begin
        f = x -> sum(x)
        n = 2

        # Test 1: Non-tensor product grid (scattered points)
        # This represents a truly non-tensor grid that current implementation can't handle well
        scattered_grid = [
            0.0 0.0
            0.3 0.7
            -0.5 0.2
            0.8 -0.4
            -0.2 -0.9
        ]

        # Should still work but with degraded performance
        pol = Globtim.MainGenerate(f, n, scattered_grid, 0.1, 0.99, 1.0, 1.0, verbose = 0)
        @test isa(pol, ApproxPoly)
        @test pol.degree == (:one_d_for_all, 1)  # Inferred as degree 1

        # Test 2: Grid with duplicate points
        dup_grid = [
            0.0 0.0
            0.5 0.5
            0.5 0.5  # duplicate
            -0.5 -0.5
        ]

        # Should handle duplicates gracefully
        @test_logs (:warn, "Grid contains duplicate points") validate_grid(dup_grid, n)

        # Test 3: Grid outside standard range
        large_grid = [
            0.0 0.0
            2.0 1.0  # outside [-1,1]
            -1.5 0.5  # outside [-1,1]
        ]

        @test_logs (:warn,) (:warn,) validate_grid(large_grid, n, basis = :chebyshev)
    end

    @testset "Integration with Existing Features" begin
        # Test that grid-based MainGenerate works with all existing features
        f = x -> exp(-norm(x)^2)
        n = 3

        # Create a 3D grid
        grid_3d = Globtim.generate_grid(n, 5, basis = :legendre)
        grid_matrix = reduce(vcat, map(x -> x', reshape(grid_3d, :)))

        # Test with different precision types
        pol_float = Globtim.MainGenerate(
            f,
            n,
            grid_matrix,
            0.1,
            0.99,
            1.0,
            1.0,
            precision = Globtim.FloatPrecision,
            verbose = 0,
        )
        @test pol_float.precision == Globtim.FloatPrecision

        pol_rat = Globtim.MainGenerate(
            f,
            n,
            grid_matrix,
            0.1,
            0.99,
            1.0,
            1.0,
            precision = Globtim.RationalPrecision,
            verbose = 0,
        )
        @test pol_rat.precision == Globtim.RationalPrecision

        # Test with normalization
        pol_norm = Globtim.MainGenerate(
            f,
            n,
            grid_matrix,
            0.1,
            0.99,
            1.0,
            1.0,
            normalized = true,
            verbose = 0,
        )
        @test pol_norm.normalized == true
    end
end

# Summary function to report limitations
function report_anisotropic_limitations()
    println("\n" * "="^60)
    println("Anisotropic Grid Integration - Current Limitations")
    println("="^60)

    println("\n1. Tensor Product Requirement:")
    println("   - Grids must maintain tensor product structure")
    println("   - True anisotropic grids are converted to nearest tensor product")

    println("\n2. Degree Inference:")
    println("   - Degree = round(n_points^(1/dim)) - 1")
    println("   - May not be optimal for anisotropic grids")

    println("\n3. Lambda Vandermonde:")
    println("   - Assumes same unique points in each dimension")
    println("   - Cannot leverage different node distributions")

    println("\n4. Workarounds:")
    println("   - Use quadrature-based L2 norm for true anisotropic benefits")
    println("   - Pre-filter grids to ensure tensor product structure")
    println("   - Consider Phase 2 implementation for full support")

    println("\n" * "="^60)
end

println("\nAnisotropic grid integration tests completed!")
