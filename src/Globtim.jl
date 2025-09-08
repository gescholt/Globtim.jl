module Globtim

# CORE DEPENDENCIES - Always loaded for fundamental operations
using DynamicPolynomials: @polyvar  # Explicit import to avoid macro issues
using DynamicPolynomials
using ForwardDiff
using LinearAlgebra
using MultivariatePolynomials
using Random
using StaticArrays
using Statistics
using SpecialFunctions
using TimerOutputs
using DataFrames
using Optim
using Parameters
using Dates
using LinearSolve
using DataStructures
using IterTools
using ProgressLogging
using PolyChaos

@enum PrecisionType begin
    Float64Precision
    RationalPrecision
    BigFloatPrecision
    BigIntPrecision
    AdaptivePrecision      # BigFloat for expansion, Float64 for evaluation
end

import HomotopyContinuation: solve, real_solutions, System

# TimerOutputs for performance tracking
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
    # New benchmark functions from Jamil & Yang 2013
    Sphere,
    Rosenbrock,
    Griewank,
    Schwefel,
    Levy,
    Zakharov,
    Beale,
    Booth,
    Branin,
    GoldsteinPrice,
    Matyas,
    McCormick,
    Michalewicz,
    StyblinskiTang,
    SumOfDifferentPowers,
    Trid,
    RotatedHyperEllipsoid,
    Powell,
    # Benchmark function utilities
    get_function_category,
    list_functions_by_category,
    get_function_info,
    BOWL_SHAPED_FUNCTIONS,
    MULTIMODAL_FUNCTIONS,
    VALLEY_SHAPED_FUNCTIONS,
    PLATE_SHAPED_FUNCTIONS,
    TWO_D_FUNCTIONS,
    HIGHER_D_FUNCTIONS,
    calculate_samples,
    create_test_input,
    Constructor,
    solve_polynomial_system,
    solve_polynomial_with_defaults,
    msolve_polynomial_system,
    msolve_parser,
    generate_grid,
    SupportGen,
    construct_chebyshev_approx,
    subdivide_domain,
    solve_and_parse,
    analyze_critical_points,
    load_function_params,
    FunctionParameters,
    generate_grid_small_n,
    simple_lambda_vandermonde,
    create_level_set_animation,
    create_level_set_visualization,
    process_crit_pts, # Function previously giving trouble in test,
    EllipseSupport

# Precision type export
export PrecisionType,
    Float64Precision, RationalPrecision, BigFloatPrecision, BigIntPrecision, AdaptivePrecision

# Legendre polynomial functions
export symbolic_legendre, evaluate_legendre, get_legendre_coeffs, construct_legendre_approx

# Chebyshev polynomial functions
export symbolic_chebyshev,
    evaluate_chebyshev, get_chebyshev_coeffs, construct_chebyshev_approx

# Unified orthogonal polynomial interface
export symbolic_orthopoly,
    evaluate_orthopoly, get_orthopoly_coeffs, construct_orthopoly_polynomial

# Grid utility functions - internal use only
# export grid_to_matrix, ensure_matrix_format, matrix_to_grid, get_grid_info

# ApproxPoly accessor functions - internal use only
# export get_basis, get_precision, is_normalized, has_power_of_two_denom, get_scale_factor

# Scaling utilities - internal use only
# export scale_point, get_scale_factor_type, transform_coordinates, compute_norm

# Exact conversion and sparsification functions - only export main functions
export to_exact_monomial_basis, sparsify_polynomial, exact_polynomial_coefficients
# Internal analysis helpers - not exported
# export compute_l2_norm_vandermonde, compute_l2_norm_coeffs
# export compute_approximation_error,
#     analyze_sparsification_tradeoff, analyze_approximation_error_tradeoff
export truncate_polynomial, monomial_l2_contributions, analyze_truncation_impact
export truncate_polynomial_adaptive, analyze_coefficient_distribution
export BoxDomain,
    AbstractDomain, compute_l2_norm, verify_truncation_quality, integrate_monomial

# Quadrature-based L2 norm
export compute_l2_norm_quadrature

# Anisotropic grid support - only export main function
export generate_anisotropic_grid
# Internal grid helpers - not exported
# export get_grid_dimensions, is_anisotropic

# Timer for performance tracking
# export _TO  # Internal - users don't need direct access

# Error handling framework - only export main error types
export GlobtimError, InputValidationError, NumericalError, ComputationError, ResourceError, ConvergenceError
# Internal validation functions - not exported
# export validate_dimension, validate_polynomial_degree, validate_sample_count, validate_center_vector, validate_sample_range
# export validate_objective_function, check_matrix_conditioning, validate_polynomial_coefficients
# export check_memory_usage, estimate_computation_complexity, suggest_parameter_adjustments, safe_execute_with_fallback
# export ComputationProgress, update_progress!, with_progress_monitoring
# export validate_test_input_parameters, validate_constructor_parameters, create_error_context, log_error_details

# Safe wrapper functions - keep main workflow functions only
export safe_test_input, safe_constructor, safe_globtim_workflow
# Internal safe wrappers - not exported
# export safe_solve_polynomial_system, safe_analyze_critical_points
# export diagnose_globtim_setup

include("config.jl")
include("LibFunctions.jl") #list of test functions.
include("BenchmarkFunctions.jl") #benchmark function categorization and utilities.
include("Structures.jl") # list of structures used in the code.
include("scaling_utils.jl") # Type-stable scaling utilities
include("Samples.jl") #functions to generate samples.
include("Main_Gen.jl") #functions to construct polynomial approximations.
include("l2_norm.jl") #measure error of approx.
include("ApproxConstruct.jl") #construct Vandermonde like matrix.
include("lambda_vandermonde_anisotropic.jl") # Enhanced anisotropic grid support
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
include("grid_utils.jl") #Grid format conversion utilities
include("subdomain_management.jl") #4D subdomain decomposition management
include("multi_tolerance_analysis.jl") #Multi-tolerance execution framework
include("function_value_analysis.jl") #Function value error analysis
include("advanced_l2_analysis.jl") #Advanced L2-norm computation and sparsification
include("truncation_analysis.jl") #Polynomial truncation with L2-norm analysis
include("quadrature_l2_norm.jl") #Quadrature-based L2 norm computation
include("anisotropic_grids.jl") #Anisotropic grid generation
include("error_handling.jl") #Comprehensive error handling framework
include("safe_wrappers.jl") #Safe wrapper functions with error handling
# include("valley_detection.jl") #Valley detection and manifold following algorithms
# include("conservative_valley_walking.jl") #Conservative valley walking with function value validation

# Advanced Interactive Visualization (Issue #50) - Core functionality
include("InteractiveVizCore.jl") #Core analysis functions (no GLMakie dependency)
# Full visualization features available in GLMakie extension:
# - InteractiveViz.jl: Full interactive visualization framework  
# - AlgorithmViz.jl: Algorithm-specific visualization integrations

# Issue #67: Extensible Visualization Framework
include("VisualizationFramework.jl") #Abstract plotting interfaces and data preparation
include("PostProcessing.jl") #Unified post-processing framework with visualization

# Export non-plotting functions that are always available
export points_in_hypercube, points_in_range

# L2 norm functions (after l2_norm.jl is included)
export discrete_l2_norm_riemann

# Phase 2: Hessian analysis functions - only export main functions
export compute_hessians, classify_critical_points
# Internal Hessian analysis helpers - not exported
# export store_all_eigenvalues,
#     extract_critical_eigenvalues,
#     compute_hessian_norms,
#     compute_eigenvalue_stats,
#     extract_all_eigenvalues_for_visualization,
#     plot_hessian_norms,
#     plot_condition_numbers,
#     plot_critical_eigenvalues,
#     plot_all_eigenvalues

# CairoMakie extension plotting functions (available when CairoMakie is loaded)
# These are stub functions - actual implementations in extension
# export plot_convergence_analysis,
#     capture_histogram,
#     create_legend_figure,
#     plot_discrete_l2,
#     plot_convergence_captured,
#     plot_filtered_y_distances,
#     cairo_plot_polyapprox_levelset,
#     plot_distance_statistics,
#     histogram_enhanced,
#     histogram_minimizers_only

# GLMakie extension plotting functions (available when GLMakie is loaded)
# These are stub functions - actual implementations in extension
# export plot_polyapprox_3d,
#     plot_polyapprox_rotate,
#     plot_polyapprox_levelset,
#     plot_polyapprox_flyover,
#     plot_polyapprox_animate,
#     plot_polyapprox_animate2,
#     plot_level_set,
#     create_level_set_visualization,
#     create_level_set_animation,
#     LevelSetData,
#     VisualizationParameters,
#     prepare_level_set_data,
#     to_makie_format,
#     plot_raw_vs_refined_eigenvalues
# Note: LevelSetData and VisualizationParameters types are still defined below

# Phase 3: Enhanced statistical tables and analysis - only export main function
export analyze_critical_points_with_tables
# Internal table helpers - not exported
# export display_statistical_table,
#     export_analysis_tables,
#     create_statistical_summary,
#     quick_table_preview,
#     compute_type_specific_statistics,
#     render_table,
#     render_console_table,
#     render_comparative_table

# Enhanced data structures
export OrthantResult, ToleranceResult, MultiToleranceResults, BFGSConfig, BFGSResult

# Subdomain management functions - only export main functions
export generate_4d_orthant_centers, create_orthant_test_inputs
# Internal orthant helpers - not exported
# export orthant_id_to_signs,
#     signs_to_orthant_id,
#     point_to_orthant_id,
#     filter_points_by_orthant,
#     merge_orthant_results,
#     analyze_orthant_coverage,
#     compute_orthant_statistics

# Multi-tolerance analysis functions
export execute_multi_tolerance_analysis,
    execute_single_tolerance_analysis, deuflhard_4d_composite

# Enhanced BFGS functions - only export main refinement function
export enhanced_bfgs_refinement
# Internal BFGS helpers - not exported  
# export refine_with_enhanced_bfgs, determine_convergence_reason

# Additional refine.jl functions - internal use only
# export compute_gradients, analyze_basins

# Valley detection and manifold following functions
# TODO: These functions are not yet implemented - exports commented out
# export ValleyDetectionConfig, ValleyInfo
# export detect_valley_at_point, follow_valley_manifold, project_to_critical_manifold
# export analyze_valleys_in_critical_points
# export create_valley_test_function, create_ridge_test_function

# Conservative valley walking functions
# TODO: These functions are not yet implemented - exports commented out
# export ConservativeValleyConfig, ConservativeValleyStep
# export conservative_valley_walk, validate_valley_point, explore_valley_manifold_conservative

# Function value error analysis - only export main types and functions
export FunctionValueError, ErrorMetrics, compute_function_value_errors
# Internal error analysis helpers - not exported
# export evaluate_function_values,
#     compute_error_metrics,
#     analyze_errors_by_type,
#     create_error_analysis_dataframe,
#     convergence_analysis,
#     integrate_with_bfgs_results

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

# Type definitions for GLMakie extension
# These types need to be defined in the main module to be exportable

"""
    LevelSetData{T<:AbstractFloat}

Structure to hold level set computation results.

# Fields
- `points::Vector{SVector{3,T}}`: Points near the level set
- `values::Vector{T}`: Function values at the points
- `level::T`: The target level value
"""
struct LevelSetData{T <: AbstractFloat}
    points::Vector{StaticArrays.SVector{3, T}}
    values::Vector{T}
    level::T

    # Inner constructor for validation
    function LevelSetData{T}(
        points::Vector{StaticArrays.SVector{3, T}},
        values::Vector{T},
        level::T
    ) where {T <: AbstractFloat}
        length(points) == length(values) ||
            throw(ArgumentError("Points and values must have same length"))
        new{T}(points, values, level)
    end
end

# Outer constructor for type inference
LevelSetData(
    points::Vector{StaticArrays.SVector{3, T}},
    values::Vector{T},
    level::T
) where {T <: AbstractFloat} = LevelSetData{T}(points, values, level)

"""
    VisualizationParameters{T<:AbstractFloat}

Parameters for level set visualization.

# Fields
- `point_tolerance::T`: Tolerance for level set point detection (default: 1e-1)
- `point_window::T`: Window size for point filtering (default: 2e-1)
- `fig_size::Tuple{Int,Int}`: Figure size in pixels (default: (1000, 800))
"""
struct VisualizationParameters{T <: AbstractFloat}
    point_tolerance::T
    point_window::T
    fig_size::Tuple{Int, Int}

    # Constructor with defaults
    function VisualizationParameters{T}(;
        point_tolerance::T = T(1e-1),
        point_window::T = T(2e-1),
        fig_size::Tuple{Int, Int} = (1000, 800)
    ) where {T <: AbstractFloat}
        new{T}(point_tolerance, point_window, fig_size)
    end
end

# Convenience constructor
VisualizationParameters(; kwargs...) = VisualizationParameters{Float64}(; kwargs...)

# Stub functions for GLMakie extension
# These will be properly implemented when GLMakie is loaded
function plot_polyapprox_3d end
function plot_polyapprox_rotate end
function plot_polyapprox_levelset end
function plot_polyapprox_flyover end
function plot_polyapprox_animate end
function plot_polyapprox_animate2 end
function plot_level_set end
function create_level_set_visualization end
function create_level_set_animation end
function prepare_level_set_data end
function to_makie_format end
function plot_raw_vs_refined_eigenvalues end
function plot_error_function_2D_with_critical_points end
function plot_polyapprox_levelset_2D end
function plot_error_function_1D_with_critical_points end
function plot_error_function_2D_with_critical_points_with_outputs end

# Include PolynomialImports module for robust @polyvar support
include("PolynomialImports.jl")
using .PolynomialImports

# Re-export @polyvar macro for direct access
export @polyvar

# Export polynomial import utilities
export setup_polyvar, ensure_polyvar, create_polynomial_vars, test_polyvar_availability

# Advanced Interactive Visualization Functions (Issue #50) - Core analysis
export InteractiveVizConfig, AlgorithmTracker, ConvergenceMetrics
export analyze_convergence, hessian_eigenvalue_analysis, momentum_enhanced_tracking
export algorithm_performance_comparison, update_algorithm_tracker!
export create_gradient_field_data
# Full interactive visualization functions available when GLMakie is loaded:
# create_interactive_viz, update_visualization, gradient_field_viz, hessian_eigenvalue_viz, 
# momentum_vector_viz, multi_algorithm_comparison, parameter_exploration_interface
# ValleyWalkingViz, BFGSViz, GradientDescentViz, integrate_valley_walking!, etc.

end
