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



import HomotopyContinuation: solve, real_solutions, System

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
    process_critical_points,
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
    create_level_set_animation

include("config.jl")
include("LibFunctions.jl") #list of test functions. 
include("Structures.jl") # list of structures used in the code.
include("Samples.jl") #functions to generate samples.
# include("OrthogPoly.jl") #functions to generate orthogonal polynomials.
include("cheb_pol.jl") #functions to generate Chebyshev polynomials.
include("lege_pol.jl") #functions to generate Legendre polynomials.
include("ApproxConstruct.jl") # Construct Vandermonde like matrix.
include("Main_Gen.jl") #functions to construct polynomial approximations.
include("ParsingOutputs.jl") #functions to parse the output of the polynomial approximation and polynomial system solving.


function __init__()
    # This code only runs if/when GLMakie is loaded
    @require GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a" begin
        include("LevelSetViz.jl")
        export LevelSetData,
            VisualizationParameters,
            plot_result,
            visualize_3d,
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
