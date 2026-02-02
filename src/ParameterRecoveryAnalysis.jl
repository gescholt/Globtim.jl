"""
ParameterRecoveryAnalysis Module

Analyzes parameter recovery experiments by computing:
- Distances from critical points to ground truth parameters
- Convergence metrics across polynomial degrees
- L2 approximation errors and condition numbers

This module is designed for inverse problem experiments where we
attempt to recover true system parameters from trajectory data.

Usage:
    include("src/ParameterRecoveryAnalysis.jl")
    using .ParameterRecoveryAnalysis

    metrics = extract_metrics(experiment_dir, data, true_params)
    distances = compute_distances_to_true(experiment_dir, degree, true_params)
"""
module ParameterRecoveryAnalysis

using Statistics
using ..ExperimentDataLoader

export compute_distances_to_true,
       extract_metrics,
       get_convergence_summary

"""
    compute_distances_to_true(experiment_dir::String, degree::Int, true_params::Vector) -> Union{NamedTuple, Nothing}

Compute distances from critical points to ground truth parameters.

For parameter recovery experiments, critical points should converge to
the true parameters as polynomial degree increases.

# Returns
NamedTuple with:
- min_distance: minimum distance to true_params
- mean_distance: mean distance across all critical points
- n_points: number of critical points found

Returns nothing if no critical points found for this degree.
"""
function compute_distances_to_true(experiment_dir::String, degree::Int, true_params::Vector)
    df = ExperimentDataLoader.load_critical_points(experiment_dir, degree)

    if df === nothing
        return nothing
    end

    # Compute distance from each critical point to true parameters
    distances = Float64[]
    for row in eachrow(df)
        point = [row.x1, row.x2, row.x3, row.x4]
        dist = sqrt(sum((point .- true_params).^2))
        push!(distances, dist)
    end

    return (
        min_distance = minimum(distances),
        mean_distance = mean(distances),
        n_points = length(distances)
    )
end

"""
    extract_metrics(experiment_dir::String, data::Dict, true_params::Union{Vector, Nothing}) -> NamedTuple

Extract all convergence metrics across polynomial degrees:
- L2 approximation errors
- Condition numbers (numerical stability)
- Distances to ground truth parameters (if available)

# Returns
NamedTuple with vectors sorted by degree:
- degrees: polynomial degrees tested
- l2_norms: L2 approximation errors
- condition_numbers: condition numbers of coefficient matrices
- min_distances: minimum distances to true_params
- mean_distances: mean distances to true_params
"""
function extract_metrics(experiment_dir::String, data::Dict, true_params::Union{Vector, Nothing})
    degrees = Int[]
    l2_norms = Float64[]
    condition_numbers = Float64[]
    min_distances = Float64[]
    mean_distances = Float64[]

    # Get results_summary from either old or new format
    results = if haskey(data, "results_summary")
        data["results_summary"]
    elseif haskey(data, "results")
        data["results"]
    else
        error("Cannot find results in JSON data")
    end

    for (key, value) in results
        # Parse degree from key like "degree_4"
        deg_match = match(r"degree_(\d+)", string(key))
        if deg_match === nothing
            continue
        end
        degree = parse(Int, deg_match.captures[1])

        # Get L2 norm
        l2_norm = if haskey(value, "l2_approx_error")
            value["l2_approx_error"]
        else
            @warn "No l2_approx_error for degree $degree"
            NaN
        end

        # Get condition number
        cond_num = if haskey(value, "condition_number")
            value["condition_number"]
        else
            NaN
        end

        # Compute distances to true parameters (ground truth for parameter recovery)
        if true_params !== nothing
            dist_result = compute_distances_to_true(experiment_dir, degree, true_params)
            if dist_result !== nothing
                push!(min_distances, dist_result.min_distance)
                push!(mean_distances, dist_result.mean_distance)
            else
                push!(min_distances, NaN)
                push!(mean_distances, NaN)
            end
        else
            push!(min_distances, NaN)
            push!(mean_distances, NaN)
        end

        push!(degrees, degree)
        push!(l2_norms, l2_norm)
        push!(condition_numbers, cond_num)
    end

    # Sort by degree
    perm = sortperm(degrees)

    return (
        degrees = degrees[perm],
        l2_norms = l2_norms[perm],
        condition_numbers = condition_numbers[perm],
        min_distances = min_distances[perm],
        mean_distances = mean_distances[perm]
    )
end

"""
    get_convergence_summary(metrics::NamedTuple, true_params::Union{Vector, Nothing}) -> Dict

Generate summary statistics for convergence analysis:
- Best degree for L2 approximation
- Best degree for numerical stability
- Best degree for parameter recovery (if true_params available)

Returns dictionary with summary information.
"""
function get_convergence_summary(metrics::NamedTuple, true_params::Union{Vector, Nothing})
    summary = Dict{String, Any}()

    # Best L2 norm
    if !all(isnan, metrics.l2_norms)
        best_l2_idx = argmin(metrics.l2_norms)
        summary["best_l2"] = (
            degree = metrics.degrees[best_l2_idx],
            value = metrics.l2_norms[best_l2_idx]
        )
    end

    # Best condition number
    if !all(isnan, metrics.condition_numbers)
        best_cond_idx = argmin(metrics.condition_numbers)
        summary["best_condition"] = (
            degree = metrics.degrees[best_cond_idx],
            value = metrics.condition_numbers[best_cond_idx]
        )
    end

    # Best parameter recovery
    if true_params !== nothing && !all(isnan, metrics.min_distances)
        best_dist_idx = argmin(metrics.min_distances)
        summary["best_recovery"] = (
            degree = metrics.degrees[best_dist_idx],
            distance = metrics.min_distances[best_dist_idx]
        )
        summary["true_params"] = true_params
    end

    return summary
end

end # module