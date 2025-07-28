# Test suite for anisotropic Globtim.lambda_vandermonde implementation

using Test
using Globtim
using LinearAlgebra
using StaticArrays

@testset "Anisotropic Lambda Vandermonde Tests" begin

    @testset "Grid Structure Analysis" begin
        # Test 1: Isotropic grid detection
        S_iso = [
            -0.5 -0.5
            0.5 -0.5
            -0.5 0.5
            0.5 0.5
        ]
        @test !is_grid_anisotropic(S_iso)

        info_iso = analyze_grid_structure(S_iso)
        @test info_iso.is_tensor_product == true
        @test length(info_iso.unique_points_per_dim[1]) == 2
        @test length(info_iso.unique_points_per_dim[2]) == 2

        # Test 2: Anisotropic grid detection
        S_aniso = [
            -0.8 -0.5
            0.0 -0.5
            0.8 -0.5
            -0.8 0.5
            0.0 0.5
            0.8 0.5
        ]
        @test is_grid_anisotropic(S_aniso)

        info_aniso = analyze_grid_structure(S_aniso)
        @test info_aniso.is_tensor_product == true
        @test length(info_aniso.unique_points_per_dim[1]) == 3
        @test length(info_aniso.unique_points_per_dim[2]) == 2

        # Test 3: Non-tensor product grid
        S_scattered = [
            0.0 0.0
            0.3 0.7
            -0.5 0.2
            0.8 -0.4
        ]
        info_scattered = analyze_grid_structure(S_scattered)
        @test info_scattered.is_tensor_product == false
    end

    @testset "Anisotropic Vandermonde Construction" begin
        # Simple 2D test with known polynomial
        Lambda = (data = [0 0; 1 0; 0 1; 1 1], size = (4, 2))

        # Anisotropic grid: 3 points in x, 2 in y
        x_nodes = [-0.8, 0.0, 0.8]
        y_nodes = [-0.5, 0.5]
        S = Matrix{Float64}(undef, 6, 2)
        idx = 1
        for j in 1:2, i in 1:3
            S[idx, 1] = x_nodes[i]
            S[idx, 2] = y_nodes[j]
            idx += 1
        end

        # Test Chebyshev basis
        V_cheb = Globtim.lambda_vandermonde_anisotropic(Lambda, S, basis = :chebyshev)
        @test size(V_cheb) == (6, 4)
        @test V_cheb[:, 1] ≈ ones(6)  # T_0(x) * T_0(y) = 1

        # Test Legendre basis
        V_leg = Globtim.lambda_vandermonde_anisotropic(Lambda, S, basis = :legendre)
        @test size(V_leg) == (6, 4)
        # For normalized Legendre polynomials, P_0(x) = 1/√2
        # So P_0(x) * P_0(y) = 1/2
        @test V_leg[:, 1] ≈ fill(0.5, 6)
    end

    @testset "Wrapper Function Integration" begin
        Lambda = (data = [0 0; 1 0; 0 1], size = (3, 2))

        # Test 1: Isotropic grid uses original implementation
        S_iso = [
            -0.5 -0.5
            0.5 -0.5
            -0.5 0.5
            0.5 0.5
        ]
        V_iso = Globtim.lambda_vandermonde(Lambda, S_iso)
        @test size(V_iso) == (4, 3)

        # Test 2: Anisotropic grid uses new implementation
        S_aniso = [
            -0.8 -0.5
            0.0 -0.5
            0.8 -0.5
            -0.8 0.5
            0.0 0.5
            0.8 0.5
        ]
        V_aniso = Globtim.lambda_vandermonde(Lambda, S_aniso)
        @test size(V_aniso) == (6, 3)

        # Test 3: Force anisotropic on isotropic grid
        V_forced = Globtim.lambda_vandermonde(Lambda, S_iso, force_anisotropic = true)
        @test size(V_forced) == (4, 3)
        @test V_forced ≈ V_iso  # Should give same result
    end

    @testset "Type Stability" begin
        Lambda = (data = [0 0; 1 0], size = (2, 2))

        # Test Float64
        S_f64 = Float64[0.0 0.0; 0.5 0.5]
        V_f64 = Globtim.lambda_vandermonde_anisotropic(Lambda, S_f64)
        @test eltype(V_f64) == Float64

        # Test Float32
        S_f32 = Float32[0.0 0.0; 0.5 0.5]
        V_f32 = Globtim.lambda_vandermonde_anisotropic(Lambda, S_f32)
        @test eltype(V_f32) == Float32

        # Test Rational
        S_rat = Rational{Int}[0//1 0//1; 1//2 1//2]
        V_rat = Globtim.lambda_vandermonde_anisotropic(Lambda, S_rat)
        @test eltype(V_rat) == Rational{Int}
    end

    @testset "MainGenerate Integration" begin
        # Test function
        f = x -> exp(-x[1]^2 - 4 * x[2]^2)
        n = 2

        # Create anisotropic grid
        grid_aniso = generate_anisotropic_grid([8, 4], basis = :chebyshev)
        grid_matrix = convert_to_matrix_grid(vec(grid_aniso))

        # Test that MainGenerate works with anisotropic grid
        pol = Globtim.MainGenerate(f, n, grid_matrix, 0.1, 0.99, 1.0, 1.0, verbose = 0)
        @test isa(pol, ApproxPoly)
        @test pol.grid == grid_matrix

        # Verify it detects anisotropic structure
        @test is_grid_anisotropic(grid_matrix)
    end

    @testset "Constructor Integration" begin
        # Create test input
        f = x -> sin(π * x[1]) * cos(π * x[2])
        TR = test_input(
            f,
            dim = 2,
            center = [0.0, 0.0],
            sample_range = 1.0,
            tolerance = nothing
        )

        # Test 1: Traditional usage (should work as before)
        pol_trad = Constructor(TR, 5, verbose = 0)
        @test isa(pol_trad, ApproxPoly)

        # Test 2: With anisotropic grid
        grid_aniso = generate_anisotropic_grid([10, 5], basis = :chebyshev)
        grid_matrix = convert_to_matrix_grid(vec(grid_aniso))
        pol_aniso = Constructor(TR, 0, grid = grid_matrix, verbose = 0)
        @test isa(pol_aniso, ApproxPoly)
        @test pol_aniso.grid == grid_matrix
    end

    @testset "Performance Comparison" begin
        # Compare isotropic vs anisotropic for suitable function
        f = x -> exp(-50 * x[1]^2 - 2 * x[2]^2)  # Highly anisotropic
        n = 2
        Lambda = (
            data = [i + j for i in 0:5, j in 0:5] |> vec |> x -> hcat(x .÷ 6, x .% 6),
            size = (36, 2)
        )

        # Isotropic grid (6x6)
        grid_iso = Globtim.generate_grid(n, 6, basis = :chebyshev)
        S_iso = reduce(vcat, map(x -> x', reshape(grid_iso, :)))

        # Anisotropic grid (9x4)
        grid_aniso = generate_anisotropic_grid([9, 4], basis = :chebyshev)
        S_aniso = convert_to_matrix_grid(vec(grid_aniso))

        # Both should work
        V_iso = Globtim.lambda_vandermonde(Lambda, S_iso)
        V_aniso = Globtim.lambda_vandermonde(Lambda, S_aniso)

        @test size(V_iso) == (49, 36)
        @test size(V_aniso) == (50, 36)  # 10x5 = 50 points

        # Check conditioning (anisotropic might be better for this function)
        println("Isotropic conditioning: ", cond(V_iso))
        println("Anisotropic conditioning: ", cond(V_aniso))
    end
end

# Demonstration function
function demonstrate_anisotropic_lambda_vandermonde()
    println("\n" * "="^60)
    println("Anisotropic Lambda Vandermonde Demonstration")
    println("="^60)

    # Function with different scales
    f = x -> exp(-100 * x[1]^2 - x[2]^2)
    TR =
        test_input(f, dim = 2, center = [0.0, 0.0], sample_range = 1.0, tolerance = nothing)

    println("\n1. Traditional Constructor (isotropic grid):")
    pol_iso = Constructor(TR, 8, GN = 10, verbose = 0)
    println("   Grid points: $(pol_iso.N)")
    println("   L2 norm: $(pol_iso.nrm)")

    println("\n2. Anisotropic grid Constructor:")
    # More points in x where function varies rapidly
    grid_aniso = generate_anisotropic_grid([14, 6], basis = :chebyshev)
    grid_matrix = convert_to_matrix_grid(vec(grid_aniso))
    pol_aniso = Constructor(TR, 0, grid = grid_matrix, verbose = 0)
    println("   Grid points: $(pol_aniso.N)")
    println("   L2 norm: $(pol_aniso.nrm)")
    println("   Grid is anisotropic: $(is_grid_anisotropic(grid_matrix))")

    println("\n3. Grid structure analysis:")
    info = analyze_grid_structure(grid_matrix)
    println("   Points in x: $(length(info.unique_points_per_dim[1]))")
    println("   Points in y: $(length(info.unique_points_per_dim[2]))")
    println("   Maintains tensor product: $(info.is_tensor_product)")

    println("\n" * "="^60)
end

println("\nAnisotropic lambda_vandermonde tests completed!")
