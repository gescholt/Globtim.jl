"""
Trend Analysis Module for Globtim

This module provides functionality for analyzing quality trends over time,
leveraging DrWatson's experiment tracking and Git provenance.

Created for Issue #22: Quality Control System - Temporal Trend Analysis

Key features:
- Quality metric trends over time (L2 norms, condition numbers)
- Success rate evolution
- Git commit-based code version tracking
- Regression detection
"""
module TrendAnalysis

using DataFrames, JSON, Statistics, Dates, Printf

# Include HistoricalAnalysis for experiment discovery
include("HistoricalAnalysis.jl")
using .HistoricalAnalysis
export HistoricalAnalysis

export compute_quality_trends, detect_quality_regression, temporal_success_rate_analysis
export extract_git_info, group_experiments_by_time

"""
    compute_quality_trends(experiments::Dict; parameter_filter=nothing) -> DataFrame

Compute quality trends over time for experiments matching parameter filter.

# Arguments
- `experiments::Dict`: Dictionary of experiments from `discover_experiments()`
- `parameter_filter::Union{Nothing,Dict}`: Optional parameter filter, e.g., Dict("GN" => 16, "domain_size" => 0.1)

# Returns
- `DataFrame`: Temporal quality trends with columns:
  - timestamp: Experiment timestamp
  - GN, domain_size, precision: Parameter values
  - avg_l2_norm: Average L2 norm for successful results
  - avg_condition_number: Average condition number
  - success_rate: Success rate for this experiment
  - total_results: Total number of results
"""
function compute_quality_trends(experiments::Dict; parameter_filter=nothing)
    trend_data = []

    for (exp_id, exp_info) in experiments
        summary = exp_info["summary"]

        # Extract parameters
        params = HistoricalAnalysis.extract_parameters(summary)

        # Apply parameter filter if provided
        if parameter_filter !== nothing
            skip = false
            for (key, val) in parameter_filter
                if get(params, key, nothing) != val
                    skip = true
                    break
                end
            end
            skip && continue
        end

        # Get timestamp
        timestamp = parse_timestamp(summary)
        timestamp === nothing && continue  # Skip if no valid timestamp

        # Get results
        results = HistoricalAnalysis.get_results(summary)
        results === nothing && continue
        results_vec = isa(results, AbstractVector) ? results : collect(values(results))
        isempty(results_vec) && continue

        # Calculate quality metrics
        successes = filter(r -> get(r, "success", false), results_vec)
        success_rate = length(successes) / length(results_vec)

        # Extract L2 norms and condition numbers from successful results
        l2_norms = [get(r, "L2_norm", NaN) for r in successes if haskey(r, "L2_norm")]
        condition_numbers = [get(r, "condition_number", NaN) for r in successes if haskey(r, "condition_number")]

        avg_l2 = !isempty(l2_norms) ? mean(filter(!isnan, l2_norms)) : missing
        avg_cond = !isempty(condition_numbers) ? mean(filter(!isnan, condition_numbers)) : missing

        push!(trend_data, Dict(
            "experiment_id" => exp_id,
            "timestamp" => timestamp,
            "GN" => get(params, "GN", missing),
            "domain_size" => get(params, "domain_size", missing),
            "precision" => get(params, "precision", "unknown"),
            "avg_l2_norm" => avg_l2,
            "avg_condition_number" => avg_cond,
            "success_rate" => success_rate,
            "total_results" => length(results_vec),
            "successful_results" => length(successes)
        ))
    end

    isempty(trend_data) && return DataFrame()

    df = DataFrame(trend_data)

    # Sort by timestamp
    sort!(df, :timestamp)

    return df
end

"""
    temporal_success_rate_analysis(experiments::Dict, time_window::Period=Month(1)) -> DataFrame

Analyze how success rates change over time windows.

# Arguments
- `experiments::Dict`: Dictionary of experiments
- `time_window::Period`: Time window for aggregation (default: 1 month)

# Returns
- `DataFrame`: Success rates aggregated by time windows
"""
function temporal_success_rate_analysis(experiments::Dict, time_window::Period=Month(1))
    # First compute all trends
    trends_df = compute_quality_trends(experiments)
    isempty(trends_df) && return DataFrame()

    # Group by parameter combination and time window
    trends_df.time_window = map(trends_df.timestamp) do ts
        # Round down to time window
        floor(ts, time_window)
    end

    # Aggregate by time window and parameters
    grouped = groupby(trends_df, [:time_window, :GN, :domain_size, :precision])

    # Safe mean function
    safe_mean(x) = begin
        sk = collect(skipmissing(x))
        isempty(sk) ? missing : mean(sk)
    end

    agg_df = combine(grouped,
        :success_rate => mean => :avg_success_rate,
        :avg_l2_norm => safe_mean => :mean_l2_norm,
        :avg_condition_number => safe_mean => :mean_condition_number,
        :total_results => sum => :total_experiments,
        nrow => :experiment_count
    )

    sort!(agg_df, :time_window)

    return agg_df
end

"""
    detect_quality_regression(baseline_df::DataFrame, current_df::DataFrame; threshold=0.2) -> Vector{String}

Detect quality regressions by comparing current metrics to baseline.

# Arguments
- `baseline_df::DataFrame`: Historical baseline metrics
- `current_df::DataFrame`: Current experiment metrics
- `threshold::Float64`: Regression threshold (default: 20% degradation)

# Returns
- `Vector{String}`: List of detected regressions with descriptions
"""
function detect_quality_regression(baseline_df::DataFrame, current_df::DataFrame; threshold=0.2)
    regressions = String[]

    # Check if we have matching parameter combinations
    for baseline_row in eachrow(baseline_df)
        # Find matching current experiments (handle missing values)
        matches = filter(row ->
            isequal(row.GN, baseline_row.GN) &&
            isequal(row.domain_size, baseline_row.domain_size) &&
            isequal(row.precision, baseline_row.precision),
            current_df
        )

        isempty(matches) && continue

        current_row = first(matches)

        # Compare success rates
        if baseline_row.success_rate > 0
            success_change = (baseline_row.success_rate - current_row.success_rate) / baseline_row.success_rate
            if success_change > threshold
                push!(regressions, @sprintf("Success rate regression for GN=%s, domain=%s, precision=%s: %.1f%% → %.1f%% (%.1f%% decrease)",
                    baseline_row.GN, baseline_row.domain_size, baseline_row.precision,
                    baseline_row.success_rate * 100, current_row.success_rate * 100,
                    success_change * 100))
            end
        end

        # Compare L2 norms (lower is better, so increase is regression)
        if !ismissing(baseline_row.avg_l2_norm) && !ismissing(current_row.avg_l2_norm)
            l2_change = (current_row.avg_l2_norm - baseline_row.avg_l2_norm) / baseline_row.avg_l2_norm
            if l2_change > threshold
                push!(regressions, @sprintf("L2 norm regression for GN=%s, domain=%s, precision=%s: %.2e → %.2e (%.1f%% increase)",
                    baseline_row.GN, baseline_row.domain_size, baseline_row.precision,
                    baseline_row.avg_l2_norm, current_row.avg_l2_norm,
                    l2_change * 100))
            end
        end

        # Compare condition numbers (lower is better)
        if !ismissing(baseline_row.avg_condition_number) && !ismissing(current_row.avg_condition_number)
            cond_change = (current_row.avg_condition_number - baseline_row.avg_condition_number) / baseline_row.avg_condition_number
            if cond_change > threshold
                push!(regressions, @sprintf("Condition number regression for GN=%s, domain=%s, precision=%s: %.2e → %.2e (%.1f%% increase)",
                    baseline_row.GN, baseline_row.domain_size, baseline_row.precision,
                    baseline_row.avg_condition_number, current_row.avg_condition_number,
                    cond_change * 100))
            end
        end
    end

    return regressions
end

"""
    extract_git_info(jld2_file::String) -> Union{Dict,Nothing}

Extract Git provenance information from DrWatson-saved JLD2 file.

# Arguments
- `jld2_file::String`: Path to .jld2 file saved with `tagsave()`

# Returns
- `Dict` with Git info (commit, branch, dirty status) or `nothing` if not available
"""
function extract_git_info(jld2_file::String)
    # This would require JLD2 package - placeholder for now
    # In practice: load JLD2 file, check for _DrWatson_gitcommit, _DrWatson_gitbranch, etc.
    return nothing
end

"""
    group_experiments_by_time(experiments::Dict, time_bins::Vector{DateTime}) -> Dict

Group experiments into time bins for temporal comparison.

# Arguments
- `experiments::Dict`: Dictionary of experiments
- `time_bins::Vector{DateTime}`: Time bin boundaries

# Returns
- `Dict`: Mapping time_bin => Vector{experiment_id}
"""
function group_experiments_by_time(experiments::Dict, time_bins::Vector{DateTime})
    groups = Dict{DateTime, Vector{String}}()

    for bin_time in time_bins
        groups[bin_time] = String[]
    end

    for (exp_id, exp_info) in experiments
        timestamp = parse_timestamp(exp_info["summary"])
        timestamp === nothing && continue

        # Find appropriate time bin
        for (i, bin_time) in enumerate(time_bins)
            if i == length(time_bins) || timestamp < time_bins[i + 1]
                push!(groups[bin_time], exp_id)
                break
            end
        end
    end

    return groups
end

# ============================================================================
# Helper Functions
# ============================================================================

"""Parse timestamp from experiment summary"""
function parse_timestamp(summary::Dict)
    # Try ISO8601 format first (completion_time)
    if haskey(summary, "completion_time")
        try
            return DateTime(summary["completion_time"])
        catch
        end
    end

    # Try yyyymmdd_HHMMSS format (timestamp field)
    if haskey(summary, "timestamp")
        ts_str = summary["timestamp"]
        try
            # Parse format like "20250929_202559"
            return DateTime(ts_str, "yyyymmdd_HHMMSS")
        catch
        end
    end

    return nothing
end

end # module
