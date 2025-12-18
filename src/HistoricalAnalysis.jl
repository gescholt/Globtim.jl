"""
Historical Analysis Module for Globtim

This module provides functionality for aggregating success rates and quality metrics
across multiple experiments to build a historical performance database.

Created for Issue #22: Quality Control System - Success Rate Tracking

Key features:
- Success rate aggregation by parameter combinations
- Historical trend analysis
- Parameter combination performance comparison
"""
module HistoricalAnalysis

using DataFrames, JSON, Statistics, Dates, Printf, CSV

# Re-export ComparisonAnalysis for convenience
include("ComparisonAnalysis.jl")
using .ComparisonAnalysis
export ComparisonAnalysis

export aggregate_success_rates, build_parameter_success_map, load_historical_data
export save_historical_database, query_success_rate

"""
    aggregate_success_rates(experiments::Dict) -> DataFrame

Aggregate success rates across multiple experiments grouped by parameter combinations.

# Arguments
- `experiments::Dict`: Dictionary of experiments from `discover_experiments()`

# Returns
- `DataFrame`: Aggregated success rates with columns:
  - GN: Samples per dimension
  - domain_size: Domain range parameter
  - precision: Precision mode (adaptive, float64, etc.)
  - total_experiments: Total number of experiment runs
  - total_successes: Total successful runs
  - avg_success_rate: Average success rate
  - last_updated: Timestamp of most recent experiment

# Example
```julia
experiments = discover_experiments("hpc_results")
success_rates = aggregate_success_rates(experiments)
```
"""
function aggregate_success_rates(experiments::Dict)
    success_data = []

    for (exp_id, exp_info) in experiments
        summary = exp_info["summary"]

        # Extract parameters
        params = extract_parameters(summary)

        # Get results
        results = get_results(summary)

        if results !== nothing && !isempty(results)
            results_vec = isa(results, AbstractVector) ? results : collect(values(results))

            total_count = length(results_vec)
            success_count = count(r -> get(r, "success", false), results_vec)
            success_rate = total_count > 0 ? success_count / total_count : 0.0

            # Extract quality metrics from successful results
            successes = filter(r -> get(r, "success", false), results_vec)
            avg_l2_norm = !isempty(successes) && any(r -> haskey(r, "L2_norm"), successes) ?
                mean([get(r, "L2_norm", NaN) for r in successes if haskey(r, "L2_norm")]) : missing

            avg_condition = !isempty(successes) && any(r -> haskey(r, "condition_number"), successes) ?
                mean([get(r, "condition_number", NaN) for r in successes if haskey(r, "condition_number")]) : missing

            push!(success_data, Dict(
                "experiment_id" => exp_id,
                "GN" => get(params, "GN", missing),
                "domain_size" => get(params, "domain_size", missing),
                "precision" => get(params, "precision", "unknown"),
                "total_count" => total_count,
                "success_count" => success_count,
                "success_rate" => success_rate,
                "avg_l2_norm" => avg_l2_norm,
                "avg_condition_number" => avg_condition,
                "timestamp" => get(summary, "completion_time", get(summary, "timestamp", "unknown"))
            ))
        end
    end

    if isempty(success_data)
        return DataFrame()
    end

    df = DataFrame(success_data)

    # Aggregate by parameter combinations
    grouped = groupby(df, [:GN, :domain_size, :precision])

    # Safe mean function that handles empty collections
    safe_mean(x) = begin
        sk = collect(skipmissing(x))
        isempty(sk) ? missing : mean(sk)
    end

    agg_df = combine(grouped,
        :total_count => sum => :total_experiments,
        :success_count => sum => :total_successes,
        :success_rate => mean => :avg_success_rate,
        :avg_l2_norm => safe_mean => :mean_l2_norm,
        :avg_condition_number => safe_mean => :mean_condition_number,
        :timestamp => maximum => :last_updated
    )

    # Calculate actual success rate from counts
    agg_df.success_rate_actual = agg_df.total_successes ./ agg_df.total_experiments

    return agg_df
end

"""
    build_parameter_success_map(agg_df::DataFrame) -> Dict

Build a lookup dictionary mapping parameter combinations to success rates.

# Arguments
- `agg_df::DataFrame`: Aggregated success rates from `aggregate_success_rates()`

# Returns
- `Dict`: Mapping (GN, domain_size, precision) => success_rate
"""
function build_parameter_success_map(agg_df::DataFrame)
    success_map = Dict{Tuple{Any, Any, String}, Float64}()

    for row in eachrow(agg_df)
        key = (row.GN, row.domain_size, row.precision)
        success_map[key] = row.success_rate_actual
    end

    return success_map
end

"""
    load_historical_data(search_path::String = ".") -> DataFrame

Discover experiments and aggregate historical success rates.

# Arguments
- `search_path::String`: Root directory to search for experiments

# Returns
- `DataFrame`: Aggregated historical success rates
"""
function load_historical_data(search_path::String = ".")
    experiments = discover_experiments(search_path)
    return aggregate_success_rates(experiments)
end

"""
    save_historical_database(agg_df::DataFrame, output_file::String)

Save aggregated historical data to a file.

# Arguments
- `agg_df::DataFrame`: Aggregated success rates
- `output_file::String`: Output file path (supports .csv, .json)
"""
function save_historical_database(agg_df::DataFrame, output_file::String)
    if endswith(output_file, ".csv")
        CSV.write(output_file, agg_df)
        println("💾 Saved historical database to: $output_file")
    elseif endswith(output_file, ".json")
        # Convert to JSON-friendly format
        data = Dict(
            "generated_at" => string(now()),
            "total_parameter_combinations" => nrow(agg_df),
            "success_rates" => [Dict(pairs(row)) for row in eachrow(agg_df)]
        )
        open(output_file, "w") do io
            JSON.print(io, data, 2)
        end
        println("💾 Saved historical database to: $output_file")
    else
        error("Unsupported file format: $output_file (use .csv or .json)")
    end
end

"""
    query_success_rate(success_map::Dict, GN, domain_size, precision::String) -> Float64

Query success rate for a specific parameter combination.

# Returns
- Success rate (0.0-1.0) or `missing` if not found
"""
function query_success_rate(success_map::Dict, GN, domain_size, precision::String)
    key = (GN, domain_size, precision)
    return get(success_map, key, missing)
end

# ============================================================================
# Helper Functions
# ============================================================================

"""Extract parameters from experiment summary"""
function extract_parameters(summary::Dict)
    params = Dict{String, Any}()

    if haskey(summary, "samples_per_dim")
        params["GN"] = summary["samples_per_dim"]
    elseif haskey(summary, "GN")
        params["GN"] = summary["GN"]
    end

    if haskey(summary, "domain_range")
        params["domain_size"] = summary["domain_range"]
    elseif haskey(summary, "domain_size_param")
        params["domain_size"] = summary["domain_size_param"]
    end

    if haskey(summary, "precision_mode")
        params["precision"] = summary["precision_mode"]
    else
        params["precision"] = "unknown"
    end

    return params
end

"""Get results from experiment summary (handles different schema versions)"""
function get_results(summary::Dict)
    # Try direct results field first
    if haskey(summary, "results")
        return summary["results"]
    end

    # Try nested results_summary
    if haskey(summary, "results_summary") && haskey(summary["results_summary"], "results")
        return summary["results_summary"]["results"]
    end

    return nothing
end

end # module
