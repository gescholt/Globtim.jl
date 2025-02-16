using Test
using Globtim
using CSV
using DataFrames
using DynamicPolynomials
using HomotopyContinuation
using LinearAlgebra
using Optim
using StaticArrays

@testset "Globtim Tests" begin
    # Constants and Parameters
    @testset "Basic parameters" begin
        n, a, b = 2, 12, 10
        scale_factor = a / b
        delta, alpha = 0.5, 1 / 10
        tol_l2 = 3e-4

        @test n == 2
        @test scale_factor == 1.2
        @test delta == 0.5~0.1
        @test alpha == 0.1
        @test tol_l2 ≈ 3e-4
    end

    # Test function initialization
    @testset "Function initialization" begin
        f = Deuflhard
        # Test with specific vector types
        @test isa(f, Function)
        @test f([0.0, 0.0]) ≈ 4.0 atol = 1e-10
        @test f(zeros(2)) ≈ 4.0 atol = 1e-10  # Test with Array
    end

    # Test polynomial system solving
    @testset "Polynomial System Solving" begin
        f = CrossInTray
        n = 2
        d = 8
        SMPL = 40
        scale_factor = 12 / 10
        tol_l2 = 3e-4

        # Load the pre-computed critical points from MATLAB
        deuflhard_file_path = "../data/matlab_critical_points/valid_points_deuflhard.csv"
        matlab_df = DataFrame(CSV.File(deuflhard_file_path))

        # Recreate the necessary objects within this testset
        TR = test_input(
            CrossInTray,
            dim=n,
            center=[0.0, 0.0],
            GN=SMPL
        )
        # Create both polynomial approximations
        # pol_cheb = Constructor(TR, d, basis=:chebyshev)
        # pol_lege = Constructor(TR, d, basis=:legendre)

        # @test pol_cheb.degree == d
        # @test pol_lege.degree == d
        # @polyvar(x[1:n])

        # # Get and process critical points using the correct workflow
        # df_cheb = solve_and_parse(pol_cheb, x, f, TR)
        # sort!(df_cheb, :z, rev=true)
        # df_lege = solve_and_parse(pol_lege, x, f, TR, basis=:legendre)
        # sort!(df_lege, :z, rev=true)

        # df_cheb, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist=1.0)
        # df_lege, df_min_lege = analyze_critical_points(f, df_lege, TR, tol_dist=1.0)

        # # Test if each MATLAB point is found in both Chebyshev and Legendre results
        # for matlab_point in eachrow(matlab_df)
        #     x0 = [matlab_point.x, matlab_point.y]

        #     # Check distances to Chebyshev points
        #     distances_cheb = [norm(x0 - [row.x1, row.x2]) for row in eachrow(df_cheb)]
        #     @test minimum(distances_cheb) < tol_l2

        #     # Check distances to Legendre points
        #     distances_lege = [norm(x0 - [row.x1, row.x2]) for row in eachrow(df_lege)]
        #     @test minimum(distances_lege) < tol_l2
        # end

        # # Test DataFrame types and structure
        # @test isa(df_cheb, DataFrame)
        # @test isa(df_lege, DataFrame)
        # @test isa(df_min_cheb, DataFrame)
        # @test isa(df_min_lege, DataFrame)
    end
end