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
using TimerOutputs
using DataFrames
using Optim
using Dates
using LinearSolve
using PolyChaos
using TOML

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
export TestInput,
    test_input,  # deprecated alias, will be removed
    ApproxPoly,
    DegreeSpec,
    SupportMatrix,
    normalize_degree,
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
    shubert,
    dejong5,
    easom,
    init_gaussian_params,
    rand_gaussian,
    HolderTable,
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
    Rastrigin,
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
    generate_grid_small_n,
    simple_lambda_vandermonde,
    process_crit_pts, # Function previously giving trouble in test,
    EllipseSupport

# Precision type export
export PrecisionType,
    Float64Precision, RationalPrecision, BigFloatPrecision, BigIntPrecision,
    AdaptivePrecision

# Legendre polynomial functions
export symbolic_legendre, evaluate_legendre, get_legendre_coeffs, construct_legendre_approx

# Chebyshev polynomial functions
export symbolic_chebyshev,
    evaluate_chebyshev, get_chebyshev_coeffs

# Unified orthogonal polynomial interface
export symbolic_orthopoly,
    evaluate_orthopoly, get_orthopoly_coeffs, construct_orthopoly_polynomial

# Grid utility functions - internal use only
# export grid_to_matrix, ensure_matrix_format, matrix_to_grid, get_grid_info

# ApproxPoly evaluation functions
export evaluate, gradient

# ApproxPoly accessor functions - internal use only
# export get_basis, get_precision, is_normalized, has_power_of_two_denom, get_scale_factor

# Scaling utilities - internal use only
# export scale_point, get_scale_factor_type, transform_coordinates, compute_norm
export relative_l2_error

# Exact conversion and sparsification functions - only export main functions
export to_exact_monomial_basis, sparsify_polynomial, exact_polynomial_coefficients
# L²-norm computation methods (documented in sparsification.md)
export compute_l2_norm_vandermonde, compute_l2_norm_coeffs
# Sparsification analysis helpers (documented in sparsification.md)
export compute_approximation_error,
    analyze_sparsification_tradeoff, analyze_approximation_error_tradeoff
# Truncation analysis functions
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

# Adaptive subdivision - error-driven domain refinement
export Subdomain, SubdivisionTree,
    adaptive_refine, two_phase_refine,
    estimate_subdomain_error, subdivide_domain,
    select_cut_dimension, find_optimal_cut_sparse,
    get_bounds, n_leaves, n_active, total_error, error_balance_ratio,
    dimension, volume,  # Subdomain utilities
    select_cut_dimension_by_width,  # Fallback dimension selection
    display_tree, get_max_depth  # Tree visualization & info

# GPU acceleration - optional (requires CUDA.jl)
export gpu_available, gpu_memory_info, estimate_gpu_memory_requirement
export BatchGroup, group_subdomains_for_gpu

# Timer for performance tracking
# export _TO  # Internal - users don't need direct access

# Error handling framework - only export main error types
export GlobtimError,
    InputValidationError, NumericalError, ComputationError, ResourceError, ConvergenceError
# Internal validation functions - not exported
# export validate_dimension, validate_polynomial_degree, validate_sample_count, validate_center_vector, validate_sample_range
# export validate_objective_function, check_matrix_conditioning, validate_polynomial_coefficients
# export check_memory_usage, estimate_computation_complexity
# export ComputationProgress, update_progress!, with_progress_monitoring
# export validate_test_input_parameters, validate_constructor_parameters, create_error_context, log_error_details

# Validation framework - consolidated from ValidationBoundaries, PipelineErrorBoundaries, PipelineDefenseIntegration
export ValidationError, DataValidationError, PipelineBoundaryError
export FilenameContaminationError, ParameterRangeError, SchemaValidationError, ContentValidationError
export DataLoadError, DataQualityError, DataProductionError
export StageTransitionError, InterfaceCompatibilityError, ResourceBoundaryError, FileSystemBoundaryError
export DEFENSE_SUCCESS, DEFENSE_WARNING, DEFENSE_ERROR, DEFENSE_CRITICAL
export PipelineBoundary, HPC_JOB_BOUNDARY, DATA_PROCESSING_BOUNDARY, VISUALIZATION_BOUNDARY, FILE_OPERATION_BOUNDARY
export chain_validation, validate_column_type, safe_read_csv
export detect_filename_contamination, validate_parameter_ranges, validate_experiment_output_strict
export save_experiment_results_safe, load_and_validate_experiment_data, verify_written_data
export validate_stage_transition, detect_interface_issues, validate_pipeline_connection
export enhanced_pipeline_validation, validate_hpc_pipeline_stage
export format_validation_error, format_boundary_error
export create_validation_report, create_boundary_report, create_defense_report

export print_timing_breakdown

include("LibFunctions.jl") #list of test functions.
include("BenchmarkFunctions.jl") #benchmark function categorization and utilities.
include("Structures.jl") # list of structures used in the code.
include("scaling_utils.jl") # Type-stable scaling utilities
include("Samples.jl") #functions to generate samples.
include("Main_Gen.jl") #functions to construct polynomial approximations.
include("l2_norm.jl") #measure error of approx.
include("ApproxConstruct.jl") #construct Vandermonde like matrix.
include("lambda_vandermonde_anisotropic.jl") # Enhanced anisotropic grid support
include("lambda_vandermonde_tensorized.jl") # Optimized tensor-product grid support
include("lambda_vandermonde_tier1_optimizations.jl") # Tier 1 performance optimizations
include("OrthogonalInterface.jl") #unified orthogonal polynomial interface.
include("cheb_pol.jl") #functions to generate Chebyshev polynomials.
include("lege_pol.jl") #functions to generate Legendre polynomials.
include("ApproxPolyEval.jl") #ApproxPoly evaluation and gradient functions.
include("msolve_system.jl") #polynomial system solving with Msolve.
include("hom_solve.jl") #polynomial system solving with homotopy Continuation. 
include("ParsingOutputs.jl") #functions to parse the output of the polynomial approximation.
include("data_structures.jl") #Enhanced data structures for multi-tolerance analysis
include("config.jl") # Unified configuration module (consolidates config.jl, ConfigValidation.jl, parameter_tracking_config.jl)
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
include("adaptive_subdivision.jl") #Adaptive domain subdivision for error-driven refinement
include("error_handling.jl") #Comprehensive error handling framework
include("validation.jl") #Unified validation framework (consolidates ValidationBoundaries, PipelineErrorBoundaries, PipelineDefenseIntegration)
# safe_wrappers.jl removed — fallback/retry mechanisms are forbidden (see AGENTS.md)
include("EnhancedMetrics.jl") #Enhanced statistics collection

# Export non-plotting functions that are always available
export points_in_hypercube, points_in_range

# GPU acceleration stub functions - implemented by GlobtimCUDAExt when CUDA.jl is loaded
"""
    gpu_available() -> Bool

Check if GPU acceleration is available (CUDA.jl loaded and functional GPU present).
Returns `false` when CUDA extension is not loaded.
"""
gpu_available() = false

"""
    gpu_memory_info() -> NamedTuple{(:total, :free, :used), Tuple{Int,Int,Int}}

Return GPU memory information in bytes.
Returns zeros when CUDA extension is not loaded.
"""
gpu_memory_info() = (total=0, free=0, used=0)

"""
    estimate_gpu_memory_requirement(n_subdomains, n_points, n_terms) -> Int

Estimate GPU memory requirement in bytes for batched processing of `n_subdomains`
subdomains, each with `n_points` grid points and `n_terms` polynomial terms.
"""
function estimate_gpu_memory_requirement(n_subdomains::Int, n_points::Int, n_terms::Int)
    # Vandermonde matrices: B * N * m * 8 bytes
    vandermonde_mem = n_subdomains * n_points * n_terms * 8
    # Gram matrices: B * m * m * 8 bytes
    gram_mem = n_subdomains * n_terms * n_terms * 8
    # RHS and solution vectors: B * m * 8 * 2
    vectors_mem = n_subdomains * n_terms * 8 * 2
    # Grid points: B * N * n_dim * 8 (assume n_dim ~ 4)
    grid_mem = n_subdomains * n_points * 4 * 8
    # f_values: B * N * 8
    fval_mem = n_subdomains * n_points * 8
    # Polynomial cache overhead
    cache_mem = 4 * 50 * 20 * 8

    return vandermonde_mem + gram_mem + vectors_mem + grid_mem + fval_mem + cache_mem
end

# Internal GPU functions - stubs overridden by GlobtimCUDAExt
function batched_vandermonde_gpu end
function batched_ls_solve_gpu end

# L2 norm functions (after l2_norm.jl is included)
export discrete_l2_norm_riemann

# Phase 2: Hessian analysis functions - only export main functions
export compute_hessians, classify_critical_points, compute_eigenvalue_stats

# Enhanced metrics collection - export module
export EnhancedMetrics
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
#     plot_discrete_l2,
#     plot_convergence_captured,
#     plot_filtered_y_distances,
#     cairo_plot_polyapprox_levelset,
#     plot_distance_statistics

# Level set data types (canonical definitions, used by GlobtimPlots)
export LevelSetData, VisualizationParameters

# Phase 3: Enhanced statistical tables and analysis - export main functions
export analyze_critical_points_with_tables,
    display_statistical_table,
    export_analysis_tables,
    create_statistical_summary,
    quick_table_preview,
    compute_type_specific_statistics,
    render_table,
    render_console_table,
    render_comparative_table

# Enhanced data structures - canonical result types
export OrthantResult, ToleranceResult, MultiToleranceResults, BFGSConfig, BFGSResult
export ValidationResult, CSVLoadResult, BoundaryResult, DefenseResult
export PolynomialApproximationResult, CriticalPointAnalysisResult
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

# Valley detection is implemented in GlobtimPostProcessing.ValleyWalking

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
function plot_discrete_l2 end
function plot_convergence_captured end
function plot_filtered_y_distances end
function plot_distance_statistics end


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



# Include PolynomialImports module for robust @polyvar support
include("PolynomialImports.jl")
using .PolynomialImports

# Re-export @polyvar macro for direct access
export @polyvar

# Export polynomial import utilities
export setup_polyvar, ensure_polyvar, create_polynomial_vars, test_polyvar_availability

# ModelRegistry - centralized model indexing
include("ModelRegistry.jl")
using .ModelRegistry

# Export ModelRegistry types and functions
export ModelInfo, get_model, list_models, validate_model_name, get_model_function, register_model!

# PathManager - unified path management
include("PathManager.jl")
using .PathManager

# Export PathManager functions
export PathConfig, reset_config!,
    get_project_root, get_results_root, get_src_dir, get_examples_dir,
    create_experiment_dir, get_experiment_path,
    validate_project_structure, validate_results_root,
    is_valid_objective_name, sanitize_objective_name,
    detect_environment, is_hpc_environment,
    ensure_directory, with_project_root,
    register_experiment, update_experiment_progress, finalize_experiment

# Advanced Interactive Visualization Functions - Core analysis
# Visualization exports removed - all plotting functionality moved to GlobtimPlots package
# For visualization, use: using GlobtimPlots
# See docs/VISUALIZATION.md for complete migration guide

# StandardExperiment - unified experiment template (Phase 2)
include("StandardExperiment.jl")
using .StandardExperiment

# Export StandardExperiment types and functions
export run_standard_experiment, DegreeResult, solve_and_transform

# SparsificationExperiment - polynomial sparsification analysis
include("SparsificationExperiment.jl")
using .SparsificationExperiment

# Export SparsificationExperiment types and functions
export SparsifiedVariant, SparsificationDegreeResult, run_sparsification_experiment

# ExperimentCLI - experiment configuration (re-export for downstream packages)
include("ExperimentCLI.jl")
using .ExperimentCLI

# Export ExperimentCLI types and functions (enables `using Globtim: ExperimentParams`)
export ExperimentParams, parse_experiment_args, validate_params

# TOML experiment pipeline configuration
include("config_loader.jl")
export ExperimentPipelineConfig, load_experiment_config, config_to_experiment_params

# ErrorCategorization - systematic error analysis
# Note: ErrorCategorization.jl is already included by validation.jl (line 36)
using .ErrorCategorization

# Export ErrorCategorization types and functions
export ErrorCategory, ErrorClassification, categorize_error, analyze_experiment_errors,
    generate_error_report, ERROR_TAXONOMY, SEVERITY_LEVELS, FIX_SUGGESTIONS

end
