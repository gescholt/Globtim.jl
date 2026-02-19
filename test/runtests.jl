using Test
using Globtim

# Test timeout infrastructure
include("timeout_utils.jl")

# CSV is required for tests - no fallback
import CSV

using DataFrames
using DynamicPolynomials
using LinearAlgebra

# Default timeouts in seconds (override with GLOBTIM_TEST_TIMEOUT_MULTIPLIER)
const TIMEOUT_CONSTRUCT = 60    # Polynomial construction
const TIMEOUT_SOLVE     = 300   # HomotopyContinuation system solve
const TIMEOUT_TESTFILE  = 120   # Included test files (sparsification, truncation, etc.)

@testset "Polynomial System Solving" begin
    # Test parameters
    n = 2
    a, b = 7, 5
    scale_factor = a / b
    f = Deuflhard  # Objective function
    d = 22      # Initial Degree
    SMPL = 120

    println("Number of samples: ", SMPL^n)

    # Create test input
    TR = TestInput(
        f,
        dim = n,
        center = [0.0, 0.0],
        GN = SMPL,
        sample_range = scale_factor
    )

    # Define df_cheb at this scope level so both nested testsets can access it
    df_cheb = nothing

    @testset "Chebyshev basis" begin
        pol_cheb = with_timeout(TIMEOUT_CONSTRUCT, label="Chebyshev construction (deg=$d, GN=$SMPL)") do
            Constructor(TR, d, basis = :chebyshev, normalized = false)
        end

        @polyvar(x[1:n])

        real_pts_cheb = with_timeout(TIMEOUT_SOLVE, label="solve_polynomial_system (deg=$d, 2D)") do
            solve_polynomial_system(
                x,
                n,
                d,
                pol_cheb.coeffs;
                basis = :chebyshev,
                normalized = false
            )
        end

        println("Found $(length(real_pts_cheb)) real critical points")

        if !isempty(real_pts_cheb)
            dimensions_correct = all(p -> length(p) == TR.dim, real_pts_cheb)
            @test dimensions_correct
        end

        # Process critical points
        df_cheb = process_crit_pts(real_pts_cheb, f, TR; skip_filtering = false)
        @test isa(df_cheb, DataFrame)
        @test nrow(df_cheb) > 0
        println("Processed $(nrow(df_cheb)) critical points")
    end

    # Optional: Compare with pre-computed critical points from MATLAB
    @testset "Comparison with MATLAB results" begin
        matlab_file_path = joinpath(@__DIR__, "..", "data", "matlab_critical_points", "valid_points_deuflhard.csv")
        if isfile(matlab_file_path)
            matlab_df = DataFrame(CSV.File(matlab_file_path))

            if df_cheb !== nothing && nrow(df_cheb) > 0
                tol_l2 = 1e-2
                for matlab_point in eachrow(matlab_df)
                    x0 = [matlab_point.x, matlab_point.y]
                    distances_cheb =
                        [norm(x0 - [row.x1, row.x2]) for row in eachrow(df_cheb)]
                    @test minimum(distances_cheb) < tol_l2
                end
            else
                @info "DataFrame from Chebyshev test is empty or undefined, skipping comparison"
            end
        else
            @info "MATLAB comparison file not found, skipping comparison tests"
        end
    end
end

# Active test files — each guarded with a timeout
with_timeout(TIMEOUT_TESTFILE, label="test_sparsification.jl") do
    include("test_sparsification.jl")
end

with_timeout(TIMEOUT_TESTFILE, label="test_truncation.jl") do
    include("test_truncation.jl")
end

with_timeout(TIMEOUT_TESTFILE, label="test_relative_l2.jl") do
    include("test_relative_l2.jl")
end

with_timeout(TIMEOUT_TESTFILE, label="test_aqua.jl") do
    include("test_aqua.jl")
end
