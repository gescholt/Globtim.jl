# ================================================================================
# Data Structures for Enhanced Analysis
# ================================================================================
#
# This file defines validated data structures for multi-tolerance convergence
# analysis, orthant decomposition, and publication-quality result management.
#
# Key Features:
# - Type-safe data structures with validation constructors
# - Support for multi-tolerance execution results
# - Orthant-based spatial analysis for 4D decomposition
# - Integration with Phase 2 Hessian analysis and Phase 3 statistics

"""
    OrthantResult

Stores comprehensive analysis results for a single orthant in 4D space.
Includes convergence metrics, spatial properties, and quality assessments.

# Fields
- `orthant_id::Int`: Orthant identifier (1-16 for 4D)
- `center::Vector{Float64}`: Center coordinates of the orthant
- `range_per_dim::Vector{Float64}`: Sampling range for each dimension
- `raw_point_count::Int`: Number of raw critical points found
- `bfgs_point_count::Int`: Number of points after BFGS refinement
- `success_rate::Float64`: Fraction of successful BFGS refinements
- `median_distance::Float64`: Median distance to expected minima
- `outlier_count::Int`: Number of points filtered as outliers
- `polynomial_degree::Int`: Polynomial degree used
- `computation_time::Float64`: Time in seconds for this orthant
"""
struct OrthantResult
    orthant_id::Int
    center::Vector{Float64}
    range_per_dim::Vector{Float64}
    raw_point_count::Int
    bfgs_point_count::Int
    success_rate::Float64
    median_distance::Float64
    outlier_count::Int
    polynomial_degree::Int
    computation_time::Float64

    # Validation constructor
    function OrthantResult(
        orthant_id,
        center,
        range_per_dim,
        raw_point_count,
        bfgs_point_count,
        success_rate,
        median_distance,
        outlier_count,
        polynomial_degree,
        computation_time,
    )
        @assert 1 <= orthant_id <= 16 "Orthant ID must be between 1 and 16 for 4D analysis"
        @assert length(center) == 4 "Center must be 4D for orthant analysis"
        @assert length(range_per_dim) == 4 "Range must be 4D for orthant analysis"
        @assert raw_point_count >= 0 "Raw point count must be non-negative"
        @assert bfgs_point_count >= 0 "BFGS point count must be non-negative"
        @assert 0.0 <= success_rate <= 1.0 "Success rate must be between 0 and 1"
        @assert median_distance >= 0.0 "Median distance must be non-negative"
        @assert outlier_count >= 0 "Outlier count must be non-negative"
        @assert polynomial_degree >= 1 "Polynomial degree must be positive"
        @assert computation_time >= 0.0 "Computation time must be non-negative"

        new(
            orthant_id,
            center,
            range_per_dim,
            raw_point_count,
            bfgs_point_count,
            success_rate,
            median_distance,
            outlier_count,
            polynomial_degree,
            computation_time,
        )
    end
end

"""
    ToleranceResult

Comprehensive results container for a single L²-norm tolerance level analysis.
Includes all metrics needed for convergence visualization and statistical analysis.

# Fields
- `tolerance::Float64`: L²-norm tolerance used
- `raw_distances::Vector{Float64}`: Distances before refinement
- `bfgs_distances::Vector{Float64}`: Distances after BFGS refinement
- `point_types::Vector{String}`: Classification of each point (minimum/maximum/saddle)
- `orthant_data::Vector{OrthantResult}`: Results for each orthant (16 for 4D)
- `polynomial_degrees::Vector{Int}`: Degrees used for each subdomain
- `sample_counts::Vector{Int}`: Sample counts for each subdomain
- `computation_time::Float64`: Total time for this tolerance level
- `success_rates::NamedTuple`: Success rates (raw, bfgs, combined)
"""
struct ToleranceResult
    tolerance::Float64
    raw_distances::Vector{Float64}
    bfgs_distances::Vector{Float64}
    point_types::Vector{String}
    orthant_data::Vector{OrthantResult}
    polynomial_degrees::Vector{Int}
    sample_counts::Vector{Int}
    computation_time::Float64
    success_rates::NamedTuple{(:raw, :bfgs, :combined),Tuple{Float64,Float64,Float64}}

    # Validation constructor
    function ToleranceResult(
        tolerance,
        raw_distances,
        bfgs_distances,
        point_types,
        orthant_data,
        polynomial_degrees,
        sample_counts,
        computation_time,
        success_rates,
    )
        @assert tolerance > 0 "Tolerance must be positive"
        @assert length(raw_distances) == length(bfgs_distances) == length(point_types) "Distance arrays must have equal length"
        @assert length(orthant_data) == 16 "Must have exactly 16 orthant results for 4D analysis"
        @assert all(>=(0), [success_rates.raw, success_rates.bfgs, success_rates.combined]) "Success rates must be non-negative"
        @assert all(<=(1), [success_rates.raw, success_rates.bfgs, success_rates.combined]) "Success rates must be ≤ 1"
        @assert length(polynomial_degrees) == length(sample_counts) "Polynomial degrees and sample counts must match"
        @assert computation_time >= 0.0 "Computation time must be non-negative"

        new(
            tolerance,
            raw_distances,
            bfgs_distances,
            point_types,
            orthant_data,
            polynomial_degrees,
            sample_counts,
            computation_time,
            success_rates,
        )
    end
end

"""
    MultiToleranceResults

Container for complete multi-tolerance convergence analysis results.
Designed for publication-quality visualization and statistical analysis.

# Fields
- `tolerance_sequence::Vector{Float64}`: Sequence of L²-tolerances analyzed
- `results_by_tolerance::Dict{Float64, ToleranceResult}`: Results keyed by tolerance
- `total_computation_time::Float64`: Total analysis time
- `analysis_timestamp::String`: When analysis was performed
- `function_name::String`: Name of analyzed function
- `domain_config::NamedTuple`: Domain configuration parameters
"""
struct MultiToleranceResults
    tolerance_sequence::Vector{Float64}
    results_by_tolerance::Dict{Float64,ToleranceResult}
    total_computation_time::Float64
    analysis_timestamp::String
    function_name::String
    domain_config::NamedTuple

    function MultiToleranceResults(
        tolerance_sequence,
        results_by_tolerance,
        total_computation_time,
        analysis_timestamp,
        function_name,
        domain_config,
    )
        @assert length(tolerance_sequence) >= 2 "Need at least 2 tolerance levels for convergence analysis"
        @assert all(t -> haskey(results_by_tolerance, t), tolerance_sequence) "All tolerances must have corresponding results"
        @assert issorted(tolerance_sequence, rev = true) "Tolerance sequence should be decreasing (coarser to finer)"
        @assert total_computation_time >= 0.0 "Total computation time must be non-negative"

        new(
            tolerance_sequence,
            results_by_tolerance,
            total_computation_time,
            analysis_timestamp,
            function_name,
            domain_config,
        )
    end
end

"""
    BFGSConfig

Configuration structure for enhanced BFGS refinement with hyperparameter tracking.

# Fields
- `standard_tolerance::Float64`: Standard gradient tolerance (default: 1e-8)
- `high_precision_tolerance::Float64`: High precision tolerance (default: 1e-12)
- `precision_threshold::Float64`: When to switch to high precision (default: 1e-6)
- `max_iterations::Int`: Maximum BFGS iterations (default: 100)
- `f_abs_tol::Float64`: Absolute function tolerance (default: 1e-20)
- `x_tol::Float64`: Parameter change tolerance (default: 1e-12)
- `show_trace::Bool`: Display optimization trace (default: false)
- `track_hyperparameters::Bool`: Enable detailed tracking (default: true)
"""
mutable struct BFGSConfig
    standard_tolerance::Float64
    high_precision_tolerance::Float64
    precision_threshold::Float64
    max_iterations::Int
    f_abs_tol::Float64
    x_tol::Float64
    show_trace::Bool
    track_hyperparameters::Bool

    function BFGSConfig(;
        standard_tolerance = 1e-8,
        high_precision_tolerance = 1e-12,
        precision_threshold = 1e-6,
        max_iterations = 100,
        f_abs_tol = 1e-20,
        x_tol = 1e-12,
        show_trace = false,
        track_hyperparameters = true,
    )
        new(
            standard_tolerance,
            high_precision_tolerance,
            precision_threshold,
            max_iterations,
            f_abs_tol,
            x_tol,
            show_trace,
            track_hyperparameters,
        )
    end
end

"""
    BFGSResult

Enhanced result structure for BFGS refinement with comprehensive tracking.

# Fields
- `initial_point::Vector{Float64}`: Starting point for refinement
- `refined_point::Vector{Float64}`: Final refined point
- `initial_value::Float64`: Function value at start
- `refined_value::Float64`: Function value after refinement
- `converged::Bool`: Whether optimization converged
- `iterations_used::Int`: Number of iterations performed
- `f_calls::Int`: Number of function evaluations
- `g_calls::Int`: Number of gradient evaluations
- `convergence_reason::Symbol`: Why optimization stopped
- `hyperparameters::BFGSConfig`: Configuration used
- `tolerance_used::Float64`: Actual tolerance applied
- `tolerance_selection_reason::String`: Why this tolerance was chosen
- `final_grad_norm::Float64`: Gradient norm at termination
- `point_improvement::Float64`: Distance between initial and refined points
- `value_improvement::Float64`: Function value improvement
- `orthant_label::String`: Orthant identifier
- `distance_to_expected::Float64`: Distance to expected minimum
- `optimization_time::Float64`: Time taken for refinement
"""
struct BFGSResult
    initial_point::Vector{Float64}
    refined_point::Vector{Float64}
    initial_value::Float64
    refined_value::Float64
    converged::Bool
    iterations_used::Int
    f_calls::Int
    g_calls::Int
    convergence_reason::Symbol
    hyperparameters::BFGSConfig
    tolerance_used::Float64
    tolerance_selection_reason::String
    final_grad_norm::Float64
    point_improvement::Float64
    value_improvement::Float64
    orthant_label::String
    distance_to_expected::Float64
    optimization_time::Float64
end

# Export the data structures
export OrthantResult, ToleranceResult, MultiToleranceResults, BFGSConfig, BFGSResult
