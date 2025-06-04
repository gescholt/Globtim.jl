module Globtim

using Requires
using CSV
using StaticArrays
using DataFrames
using DynamicPolynomials
using LinearSolve
using LinearAlgebra
using Distributions
using Random
using Parameters
using TOML
using TimerOutputs

@enum PrecisionType Float64Precision RationalPrecision BigFloatPrecision BigIntPrecision

import HomotopyContinuation: solve, real_solutions, System

const _TO = TimerOutputs.TimerOutput()

# Exported functions and variables
export test_input,
    ApproxPoly,
    camel,
    CrossInTray,
    Deuflhard,
    noisy_Deuflhard,
    random_noise,
    bivariate_gaussian_noise,
    tref,
    tref_3d,
    Ackley,
    camel_3,
    camel,
    shubert,
    dejong5,
    easom,
    init_gaussian_params,
    rand_gaussian,
    HolderTable,
    CrossInTray,
    Deuflhard,
    noisy_Deuflhard,
    old_alpine1,
    shubert_4d,
    camel_4d,
    camel_3_by_3,
    cosine_mixture,
    camel_3_6d,
    Csendes,
    alpine1,
    alpine2,
    GaussianParams,
    Rastringin,
    Deuflhard_4d,
    calculate_samples,
    create_test_input,
    Constructor,
    solve_polynomial_system,
    msolve_polynomial_system,
    msolve_parser,
    process_output_file,
    plot_polyapprox,
    generate_grid,
    SupportGen,
    ChebyshevPolyExact,
    construct_chebyshev_approx,
    subdivide_domain,
    solve_and_parse,
    analyze_critical_points,
    plot_talk,
    load_function_params,
    FunctionParameters,
    analyze_degrees,
    analyze_converged_points,
    generate_grid_small_n,
    Toy_gen,
    simple_lambda_vandermonde,
    create_level_set_animation,
    create_level_set_visualization,
    process_crit_pts # Function previously giving trouble in test

# Precision type export
export PrecisionType, Float64Precision, RationalPrecision, BigFloatPrecision, BigIntPrecision

# Legendre polynomial functions
export symbolic_legendre, evaluate_legendre, get_legendre_coeffs, construct_legendre_approx

# Chebyshev polynomial functions
export symbolic_chebyshev, evaluate_chebyshev, get_chebyshev_coeffs, construct_chebyshev_approx

# Unified orthogonal polynomial interface
export symbolic_orthopoly, evaluate_orthopoly, get_orthopoly_coeffs, construct_orthopoly_polynomial

# ApproxPoly accessor functions
export get_basis, get_precision, is_normalized, has_power_of_two_denom, get_scale_factor

# Scaling utilities
export scale_point, get_scale_factor_type, transform_coordinates, compute_norm

include("config.jl")
include("LibFunctions.jl") #list of test functions. 
include("Structures.jl") # list of structures used in the code.
include("scaling_utils.jl") # Type-stable scaling utilities
include("Samples.jl") #functions to generate samples.
include("Main_Gen.jl") #functions to construct polynomial approximations.
include("l2_norm.jl") #measure error of approx.
include("ApproxConstruct.jl") #construct Vandermonde like matrix.
include("OrthogonalInterface.jl") #unified orthogonal polynomial interface.
include("cheb_pol.jl") #functions to generate Chebyshev polynomials.
include("lege_pol.jl") #functions to generate Legendre polynomials.
include("msolve_system.jl") #polynomial system solving with Msolve.
include("hom_solve.jl") #polynomial system solving with homotopy Continuation. 
include("ParsingOutputs.jl") #functions to parse the output of the polynomial approximation.

function __init__()
    # This code only runs if/when GLMakie is loaded
    @require GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a" begin
        include("graphs_makie.jl")
        export plot_polyapprox_3d
        include("LevelSetViz.jl")
        export LevelSetData,
            VisualizationParameters,
            prepare_level_set_data,
            to_makie_format,
            plot_level_set,
            create_level_set_visualization,
            plot_polyapprox_rotate,
            plot_polyapprox_levelset,
            plot_polyapprox_flyover,
            plot_polyapprox_animate,
            plot_polyapprox_animate2
    end

    # Add CairoMakie functionality
    @require CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0" begin
        include("graphs_cairo.jl")
        export plot_convergence_analysis,
            capture_histogram,
            create_legend_figure,
            plot_discrete_l2,
            plot_convergence_captured,
            plot_filtered_y_distances,
            cairo_plot_polyapprox_levelset,
            plot_distance_statistics
    end

    @require Optim = "429524aa-4258-5aef-a3af-852621145aeb" begin
        include("refine.jl")
        export analyze_critical_points, points_in_hypercube, points_in_range
    end
end
end