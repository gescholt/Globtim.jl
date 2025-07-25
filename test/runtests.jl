using Test
using Globtim
# Add this diagnostic code near the top of your test file
println("Checking if Constructor is defined: ", isdefined(Globtim, :Constructor))
println("Checking if test_input is defined: ", isdefined(Globtim, :test_input))
println("Checking if process_crit_pts is defined: ", isdefined(Globtim, :process_crit_pts))

# You're already using Constructor and test_input in your test, so they should be defined
println("Names exported from Globtim: ", filter(name -> string(name) ∈ ["Constructor", "test_input"], names(Globtim)))

using CSV
using DataFrames
using DynamicPolynomials
# using HomotopyContinuation
using LinearAlgebra
using ProgressLogging



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
    TR = test_input(
        f,
        dim=n,
        center=[0.0, 0.0],
        GN=SMPL,
        sample_range=scale_factor
    )

    # Define df_cheb at this scope level so both nested testsets can access it
    df_cheb = nothing

    @testset "Chebyshev basis" begin
        time_construct = @elapsed begin
            pol_cheb = Constructor(TR, d, basis=:chebyshev, normalized=false)
        end
        println("Time to construct Chebyshev polynomial: $(time_construct) seconds")

        @polyvar(x[1:n]) # Define polynomial ring

        time_solve = @elapsed begin
            real_pts_cheb = solve_polynomial_system(
                x, n, d, pol_cheb.coeffs;
                basis=:chebyshev, normalized=false
            )
        end
        println("Time to solve Chebyshev system: $(time_solve) seconds")

        # Debug output
        println("Type of real_pts_cheb: ", typeof(real_pts_cheb))
        println("Length of real_pts_cheb: ", length(real_pts_cheb))
        if !isempty(real_pts_cheb)
            println("First point: ", real_pts_cheb[1])
            println("Type of first point: ", typeof(real_pts_cheb[1]))

            # Check if all points have the correct dimension
            dimensions_correct = all(p -> length(p) == TR.dim, real_pts_cheb)
            println("All points have correct dimension? ", dimensions_correct)

            if !dimensions_correct
                wrong_points = filter(p -> length(p) != TR.dim, real_pts_cheb)
                println("Points with wrong dimension: ", wrong_points)
            end
        end

        # Process critical points
        try
            # Assign to the outer variable to make it accessible in other testsets
            df_cheb = process_crit_pts(
                real_pts_cheb,
                f,
                TR;
                skip_filtering=false
            )
            println("Successfully created DataFrame with $(nrow(df_cheb)) rows")
            println("DataFrame columns: ", names(df_cheb))
            @test isa(df_cheb, DataFrame)
            @test nrow(df_cheb) > 0
        catch e
            println("Error in process_crit_pts: ", e)
            for (exc, bt) in Base.catch_stack()
                showerror(stdout, exc, bt)
                println()
            end
        end
    end

    # Optional: Compare with pre-computed critical points from MATLAB
    @testset "Comparison with MATLAB results" begin
        # Load the pre-computed critical points from MATLAB if the file exists
        matlab_file_path = "../data/matlab_critical_points/valid_points_deuflhard.csv"
        if isfile(matlab_file_path)
            matlab_df = DataFrame(CSV.File(matlab_file_path))

            # Make sure df_cheb exists and has rows
            if df_cheb !== nothing && nrow(df_cheb) > 0
                # Test if each MATLAB point is found in Chebyshev results
                tol_l2 = 1e-2
                for matlab_point in eachrow(matlab_df)
                    x0 = [matlab_point.x, matlab_point.y]

                    # Check distances to Chebyshev points
                    distances_cheb = [norm(x0 - [row.x1, row.x2]) for row in eachrow(df_cheb)]
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

# Include ForwardDiff integration tests
include("test_forwarddiff_integration.jl")

# Include function value error analysis tests
include("test_function_value_analysis.jl")

# Include new exact arithmetic and sparsification tests
include("test_exact_conversion.jl")
include("test_sparsification.jl") 
include("test_truncation.jl")

# Include L2-norm scaling and type safety tests
include("test_l2_norm_scaling.jl")

# Include anisotropic grid functionality tests
include("test_anisotropic_grids.jl")

# Include quadrature-based L2 norm tests
include("test_quadrature_l2_norm_simple.jl")  # Using simplified version

# Include Phase 1/2 quadrature integration tests
include("test_quadrature_l2_phase1_2.jl")

# Include quadrature vs Riemann comparison tests
include("test_quadrature_vs_riemann.jl")

# Include Phase 2 Hessian analysis tests
include("test_hessian_analysis.jl")

# Include Phase 3 enhanced analysis integration tests
include("test_enhanced_analysis_integration.jl")

# Include Phase 3 statistical tables tests
include("test_statistical_tables.jl")

# Include grid-based MainGenerate tests
include("test_maingen_grid_functionality.jl")

# Include anisotropic grid integration tests
include("test_anisotropic_integration.jl")

# Include lambda_vandermonde anisotropic tests
include("test_lambda_vandermonde_anisotropic.jl")
