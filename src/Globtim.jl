module Globtim

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
using ForwardDiff
using Clustering
using Optim

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
    analyze_converged_points,
    generate_grid_small_n,
    Toy_gen,
    simple_lambda_vandermonde,
    create_level_set_animation,
    create_level_set_visualization,
    process_crit_pts, # Function previously giving trouble in test,
    EllipseSupport

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
include("data_structures.jl") #Enhanced data structures for multi-tolerance analysis
include("refine.jl") #functions for critical point analysis and refinement.
include("hessian_analysis.jl") #Phase 2: Hessian-based critical point classification
include("enhanced_analysis.jl") #Phase 3: Enhanced statistical tables and analysis
include("subdomain_management.jl") #4D subdomain decomposition management
include("multi_tolerance_analysis.jl") #Multi-tolerance execution framework
include("function_value_analysis.jl") #Function value error analysis

# Export non-plotting functions that are always available
export points_in_hypercube, points_in_range

# Phase 2: Hessian analysis functions
export compute_hessians, classify_critical_points, store_all_eigenvalues, 
       extract_critical_eigenvalues, compute_hessian_norms, compute_eigenvalue_stats,
       extract_all_eigenvalues_for_visualization,
       plot_hessian_norms, plot_condition_numbers, plot_critical_eigenvalues, plot_all_eigenvalues

# CairoMakie extension plotting functions (available when CairoMakie is loaded)
export plot_convergence_analysis,
       capture_histogram,
       create_legend_figure,
       plot_discrete_l2,
       plot_convergence_captured,
       plot_filtered_y_distances,
       cairo_plot_polyapprox_levelset,
       plot_distance_statistics,
       histogram_enhanced,
       histogram_minimizers_only

# Phase 3: Enhanced statistical tables and analysis
export analyze_critical_points_with_tables, display_statistical_table, export_analysis_tables,
       create_statistical_summary, quick_table_preview, compute_type_specific_statistics,
       render_table, render_console_table, render_comparative_table

# Enhanced data structures
export OrthantResult, ToleranceResult, MultiToleranceResults, BFGSConfig, BFGSResult

# Subdomain management functions
export generate_4d_orthant_centers, create_orthant_test_inputs, orthant_id_to_signs,
       signs_to_orthant_id, point_to_orthant_id, filter_points_by_orthant,
       merge_orthant_results, analyze_orthant_coverage, compute_orthant_statistics

# Multi-tolerance analysis functions
export execute_multi_tolerance_analysis, execute_single_tolerance_analysis,
       deuflhard_4d_composite

# Enhanced BFGS functions
export enhanced_bfgs_refinement, refine_with_enhanced_bfgs, determine_convergence_reason

# Additional refine.jl functions
export compute_gradients, analyze_basins

# Function value error analysis
export FunctionValueError, ErrorMetrics,
       evaluate_function_values, compute_function_value_errors,
       compute_error_metrics, analyze_errors_by_type,
       create_error_analysis_dataframe, convergence_analysis,
       integrate_with_bfgs_results

# Stub functions for CairoMakie extension
# These will be properly implemented when CairoMakie is loaded
function cairo_plot_polyapprox_levelset end
function plot_convergence_analysis end
function capture_histogram end
function create_legend_figure end
function plot_discrete_l2 end
function plot_convergence_captured end
function plot_filtered_y_distances end
function plot_distance_statistics end
function histogram_enhanced end
function histogram_minimizers_only end

end