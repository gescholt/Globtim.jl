# ================================================================================
# Function Value Error Analysis
# ================================================================================
#
# This module provides comprehensive function value error analysis capabilities
# for comparing theoretical critical points with computed critical points.
#
# Key Features:
# - Function value computation and comparison
# - Relative and absolute error metrics
# - Statistical error analysis across point types
# - Convergence analysis for multi-tolerance studies
# - Integration with enhanced BFGS refinement results

using DataFrames
using Statistics
using LinearAlgebra
using ForwardDiff

"""
    FunctionValueError

Stores detailed error metrics for a single critical point comparison.
"""
struct FunctionValueError
    theoretical_point::Vector{Float64}
    computed_point::Vector{Float64}
    theoretical_value::Float64
    computed_value::Float64
    absolute_error::Float64
    relative_error::Float64
    point_type::Symbol
    distance_to_theoretical::Float64
    gradient_norm_theoretical::Float64
    gradient_norm_computed::Float64
end

"""
    ErrorMetrics

Aggregated error metrics for a collection of critical points.
"""
struct ErrorMetrics
    mean_absolute_error::Float64
    mean_relative_error::Float64
    median_absolute_error::Float64
    median_relative_error::Float64
    max_absolute_error::Float64
    max_relative_error::Float64
    std_absolute_error::Float64
    std_relative_error::Float64
    n_points::Int
    success_rate::Float64
end

"""
    evaluate_function_values(points::Vector{Vector{Float64}}, f::Function)

Evaluate function f at all points and return values.

# Arguments
- `points`: Vector of points (each point is a vector)
- `f`: Function to evaluate

# Returns
- Vector of function values
"""
function evaluate_function_values(points::Vector{Vector{Float64}}, f::Function)
    return [f(p) for p in points]
end

"""
    compute_function_value_errors(theoretical_points::Vector{Vector{Float64}},
                                computed_points::Vector{Vector{Float64}},
                                f::Function;
                                match_threshold::Float64 = 0.1,
                                compute_gradients::Bool = true)

Compute detailed function value errors between theoretical and computed critical points.

# Arguments
- `theoretical_points`: Known theoretical critical points
- `computed_points`: Computed critical points from polynomial approximation
- `f`: Objective function
- `match_threshold`: Maximum distance for point matching (default: 0.1)
- `compute_gradients`: Whether to compute gradient norms (default: true)

# Returns
- Vector{FunctionValueError}: Detailed error information for each matched pair
"""
function compute_function_value_errors(
    theoretical_points::Vector{Vector{Float64}},
    computed_points::Vector{Vector{Float64}},
    f::Function;
    match_threshold::Float64 = 0.1,
    compute_gradients::Bool = true,
    point_types::Union{Vector{Symbol}, Nothing} = nothing
)
    errors = FunctionValueError[]

    # Match each theoretical point to its closest computed point
    for (i, theo_pt) in enumerate(theoretical_points)
        if isempty(computed_points)
            continue
        end

        # Find closest computed point
        distances = [norm(theo_pt - comp_pt) for comp_pt in computed_points]
        min_idx = argmin(distances)
        min_dist = distances[min_idx]

        # Only match if within threshold
        if min_dist <= match_threshold
            comp_pt = computed_points[min_idx]

            # Evaluate function values
            f_theo = f(theo_pt)
            f_comp = f(comp_pt)

            # Compute errors
            abs_err = abs(f_comp - f_theo)
            rel_err = abs(f_theo) > 1e-10 ? abs_err / abs(f_theo) : abs_err

            # Compute gradient norms if requested
            grad_norm_theo = 0.0
            grad_norm_comp = 0.0
            if compute_gradients
                try
                    grad_theo = ForwardDiff.gradient(f, theo_pt)
                    grad_norm_theo = norm(grad_theo)
                    grad_comp = ForwardDiff.gradient(f, comp_pt)
                    grad_norm_comp = norm(grad_comp)
                catch e
                    @debug "Gradient computation failed" exception=(e, catch_backtrace())
                    grad_norm_theo = NaN
                    grad_norm_comp = NaN
                end
            end

            # Determine point type
            ptype =
                point_types !== nothing && i <= length(point_types) ? point_types[i] :
                :unknown

            push!(
                errors,
                FunctionValueError(
                    theo_pt,
                    comp_pt,
                    f_theo,
                    f_comp,
                    abs_err,
                    rel_err,
                    ptype,
                    min_dist,
                    grad_norm_theo,
                    grad_norm_comp
                )
            )
        end
    end

    return errors
end

"""
    compute_error_metrics(errors::Vector{FunctionValueError})

Compute aggregated error metrics from a collection of function value errors.

# Arguments
- `errors`: Vector of FunctionValueError structs

# Returns
- ErrorMetrics: Aggregated statistical metrics
"""
function compute_error_metrics(errors::Vector{FunctionValueError})
    if isempty(errors)
        return ErrorMetrics(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0.0)
    end

    abs_errors = [e.absolute_error for e in errors]
    rel_errors = [e.relative_error for e in errors]

    # Filter out infinite relative errors
    finite_rel_errors = filter(isfinite, rel_errors)

    return ErrorMetrics(
        mean(abs_errors),
        isempty(finite_rel_errors) ? Inf : mean(finite_rel_errors),
        median(abs_errors),
        isempty(finite_rel_errors) ? Inf : median(finite_rel_errors),
        maximum(abs_errors),
        isempty(finite_rel_errors) ? Inf : maximum(finite_rel_errors),
        std(abs_errors),
        isempty(finite_rel_errors) ? 0.0 : std(finite_rel_errors),
        length(errors),
        1.0  # Success rate placeholder
    )
end

"""
    analyze_errors_by_type(errors::Vector{FunctionValueError})

Analyze function value errors grouped by critical point type.

# Arguments
- `errors`: Vector of FunctionValueError structs

# Returns
- Dict{Symbol, ErrorMetrics}: Error metrics for each point type
"""
function analyze_errors_by_type(errors::Vector{FunctionValueError})
    metrics_by_type = Dict{Symbol, ErrorMetrics}()

    # Group errors by point type
    for ptype in unique(e.point_type for e in errors)
        type_errors = filter(e -> e.point_type == ptype, errors)
        if !isempty(type_errors)
            metrics_by_type[ptype] = compute_error_metrics(type_errors)
        end
    end

    return metrics_by_type
end

"""
    create_error_analysis_dataframe(errors::Vector{FunctionValueError})

Create a DataFrame with detailed error analysis results.

# Arguments
- `errors`: Vector of FunctionValueError structs

# Returns
- DataFrame: Detailed error analysis table
"""
function create_error_analysis_dataframe(errors::Vector{FunctionValueError})
    if isempty(errors)
        return DataFrame()
    end

    n_dims = length(errors[1].theoretical_point)

    # Create base DataFrame
    df = DataFrame(
        point_type = [e.point_type for e in errors],
        theoretical_value = [e.theoretical_value for e in errors],
        computed_value = [e.computed_value for e in errors],
        absolute_error = [e.absolute_error for e in errors],
        relative_error = [e.relative_error for e in errors],
        distance_to_theoretical = [e.distance_to_theoretical for e in errors],
        grad_norm_theoretical = [e.gradient_norm_theoretical for e in errors],
        grad_norm_computed = [e.gradient_norm_computed for e in errors]
    )

    # Add coordinate columns
    for i in 1:n_dims
        df[!, Symbol("theo_x$i")] = [e.theoretical_point[i] for e in errors]
        df[!, Symbol("comp_x$i")] = [e.computed_point[i] for e in errors]
    end

    return df
end

"""
    convergence_analysis(tolerance_results::Dict{Float64, Vector{FunctionValueError}})

Analyze convergence of function value errors across multiple tolerance levels.

# Arguments
- `tolerance_results`: Dictionary mapping tolerance values to error vectors

# Returns
- DataFrame: Convergence analysis with columns for tolerance, metrics, and rates
"""
function convergence_analysis(tolerance_results::Dict{Float64, Vector{FunctionValueError}})
    analysis_data = []

    sorted_tolerances = sort(collect(keys(tolerance_results)), rev = true)

    for (i, tol) in enumerate(sorted_tolerances)
        errors = tolerance_results[tol]
        metrics = compute_error_metrics(errors)

        # Compute convergence rate if not first tolerance
        conv_rate_abs = NaN
        conv_rate_rel = NaN
        if i > 1
            prev_tol = sorted_tolerances[i - 1]
            prev_metrics = compute_error_metrics(tolerance_results[prev_tol])

            # Convergence rate: log(error_new/error_old) / log(tol_new/tol_old)
            if prev_metrics.mean_absolute_error > 0 && metrics.mean_absolute_error > 0
                conv_rate_abs =
                    log(metrics.mean_absolute_error / prev_metrics.mean_absolute_error) /
                    log(tol / prev_tol)
            end

            if prev_metrics.mean_relative_error > 0 && metrics.mean_relative_error > 0
                conv_rate_rel =
                    log(metrics.mean_relative_error / prev_metrics.mean_relative_error) /
                    log(tol / prev_tol)
            end
        end

        push!(
            analysis_data,
            (
                tolerance = tol,
                n_matched_points = metrics.n_points,
                mean_absolute_error = metrics.mean_absolute_error,
                mean_relative_error = metrics.mean_relative_error,
                max_absolute_error = metrics.max_absolute_error,
                max_relative_error = metrics.max_relative_error,
                convergence_rate_absolute = conv_rate_abs,
                convergence_rate_relative = conv_rate_rel
            )
        )
    end

    return DataFrame(analysis_data)
end

"""
    integrate_with_bfgs_results(df::DataFrame, f::Function, 
                               theoretical_points::Vector{Vector{Float64}};
                               theoretical_types::Vector{Symbol} = Symbol[])

Integrate function value error analysis with BFGS refinement results.

# Arguments
- `df`: DataFrame with BFGS refinement results (must have y1, y2, ... columns)
- `f`: Objective function
- `theoretical_points`: Known theoretical critical points
- `theoretical_types`: Point types for theoretical points

# Returns
- DataFrame: Enhanced DataFrame with function value error columns
"""
function integrate_with_bfgs_results(
    df::DataFrame,
    f::Function,
    theoretical_points::Vector{Vector{Float64}};
    theoretical_types::Vector{Symbol} = Symbol[]
)

    # Extract dimension
    n_dims = count(col -> startswith(string(col), "y"), names(df))

    # Extract refined points
    refined_points = Vector{Vector{Float64}}()
    for i in 1:nrow(df)
        if df[i, :converged]
            point = [df[i, Symbol("y$j")] for j in 1:n_dims]
            push!(refined_points, point)
        end
    end

    # Compute function value errors
    errors = compute_function_value_errors(
        theoretical_points,
        refined_points,
        f;
        point_types = theoretical_types
    )

    # Add error metrics to DataFrame
    df[!, :has_theoretical_match] = falses(nrow(df))
    df[!, :function_value_error] = fill(NaN, nrow(df))
    df[!, :relative_function_error] = fill(NaN, nrow(df))
    df[!, :distance_to_theoretical] = fill(NaN, nrow(df))

    # Match errors back to DataFrame rows
    for err in errors
        # Find the row with matching refined point
        for i in 1:nrow(df)
            if df[i, :converged]
                refined_pt = [df[i, Symbol("y$j")] for j in 1:n_dims]
                if norm(refined_pt - err.computed_point) < 1e-10
                    df[i, :has_theoretical_match] = true
                    df[i, :function_value_error] = err.absolute_error
                    df[i, :relative_function_error] = err.relative_error
                    df[i, :distance_to_theoretical] = err.distance_to_theoretical
                    break
                end
            end
        end
    end

    return df
end

# Export all functions
export FunctionValueError,
    ErrorMetrics,
    evaluate_function_values,
    compute_function_value_errors,
    compute_error_metrics,
    analyze_errors_by_type,
    create_error_analysis_dataframe,
    convergence_analysis,
    integrate_with_bfgs_results
