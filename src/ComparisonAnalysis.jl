"""
Comparison Analysis Module for @globtimcore

This module provides infrastructure for comparing experiment outputs across different parameters.
It handles file discovery, data loading, and preparation for comparative analysis and plotting.

Key features:
- Dynamic experiment discovery
- Parameter-based grouping
- Data loading and validation
- Comparison-ready data structures
"""
module ComparisonAnalysis

using CSV, DataFrames, JSON, Statistics, Dates
using Printf

export ExperimentComparison, discover_experiments, load_comparison_data
export group_by_parameter, prepare_comparison_plots

"""
    ExperimentComparison

Structure to hold comparison data across experiments.

Fields:
- `experiments`: Dictionary mapping experiment_id to experiment metadata
- `parameter_groups`: Dictionary mapping parameter values to experiment lists
- `comparison_data`: Combined DataFrame with all experimental data
- `metrics`: Summary metrics for each experiment group
"""
struct ExperimentComparison
    experiments::Dict{String, Dict{String, Any}}
    parameter_groups::Dict{Any, Vector{String}}
    comparison_data::DataFrame
    metrics::Dict{String, Dict{String, Float64}}
end

"""
    discover_experiments(search_path::String = ".") -> Dict{String, Dict{String, Any}}

Discover all experiment directories and extract their metadata.

Returns a dictionary mapping experiment_id to experiment metadata including:
- path: full path to experiment directory
- parameters: experiment parameters from results_summary.json
- degrees: available polynomial degrees
- data_files: list of available critical point CSV files
"""
function discover_experiments(search_path::String = ".")
    experiments = Dict{String, Dict{String, Any}}()

    println("🔍 Discovering experiments in: $search_path")

    for (root, dirs, files) in walkdir(search_path)
        # Skip hidden directories and analysis directories
        if contains(root, "/.") || contains(root, "parameter_analysis")
            continue
        end

        # Look for directories with results_summary.json
        if "results_summary.json" in files
            summary_file = joinpath(root, "results_summary.json")

            try
                summary_data = JSON.parsefile(summary_file)
                # Extract degree-specific CSV files
                csv_files = filter(f -> endswith(f, ".csv") && contains(f, "critical_points"), files)
                degrees = []
                for csv_file in csv_files
                    if occursin(r"deg_(\d+)", csv_file)
                        degree_match = match(r"deg_(\d+)", csv_file)
                        push!(degrees, parse(Int, degree_match.captures[1]))
                    end
                end
                sort!(degrees)

                experiments[basename(root)] = Dict(
                    "path" => root,
                    "parameters" => get(summary_data, "parameters", Dict()),
                    "degrees" => degrees,
                    "data_files" => csv_files,
                    "summary" => summary_data,
                    "timestamp" => get(summary_data, "timestamp", "unknown")
                )

                println("   ✅ Found: $(basename(root)) (degrees: $degrees)")

            catch e
                println("   ⚠️  Failed to parse: $summary_file - $e")
            end
        end
    end

    println("📊 Discovered $(length(experiments)) experiments")
    return experiments
end

"""
    load_comparison_data(experiments::Dict, degrees::Vector{Int} = Int[]) -> DataFrame

Load critical point data from all discovered experiments.

Parameters:
- `experiments`: Dictionary from discover_experiments()
- `degrees`: Specific degrees to load (empty = load all available)

Returns a combined DataFrame with columns:
- experiment_id, degree, x1, x2, x3, x4, z (L2 norm)
- domain_size, timestamp (from experiment parameters)
"""
function load_comparison_data(experiments::Dict, degrees::Vector{Int} = Int[])
    all_data = DataFrame()

    println("📈 Loading comparison data...")

    for (exp_id, exp_info) in experiments
        exp_path = exp_info["path"]
        available_degrees = exp_info["degrees"]

        # Filter degrees if specified
        target_degrees = isempty(degrees) ? available_degrees : intersect(degrees, available_degrees)

        for degree in target_degrees
            csv_file = joinpath(exp_path, "critical_points_deg_$(degree).csv")

            if isfile(csv_file)
                try
                    df = CSV.read(csv_file, DataFrame)

                    # Add metadata columns
                    df[!, :experiment_id] .= exp_id
                    df[!, :degree] .= degree
                    df[!, :domain_size] .= get(exp_info["parameters"], "domain_size", missing)
                    df[!, :timestamp] .= exp_info["timestamp"]

                    all_data = vcat(all_data, df)
                    println("   ✅ Loaded: $exp_id degree $degree ($(nrow(df)) points)")

                catch e
                    println("   ⚠️  Failed to load: $csv_file - $e")
                end
            else
                println("   ❌ Missing: $csv_file")
            end
        end
    end

    println("📊 Total data points loaded: $(nrow(all_data))")
    return all_data
end

"""
    group_by_parameter(comparison_data::DataFrame, parameter::Symbol) -> Dict

Group experiments by a specific parameter value.

Parameters:
- `comparison_data`: DataFrame from load_comparison_data()
- `parameter`: Column name to group by (e.g., :degree, :domain_size)

Returns dictionary mapping parameter values to experiment subsets.
"""
function group_by_parameter(comparison_data::DataFrame, parameter::Symbol)
    if parameter ∉ names(comparison_data)
        error("Parameter '$parameter' not found in data columns: $(names(comparison_data))")
    end

    grouped = Dict()
    for group in groupby(comparison_data, parameter)
        param_value = first(group[!, parameter])
        grouped[param_value] = group
    end

    return grouped
end

"""
    prepare_comparison_plots(comparison_data::DataFrame) -> Dict{String, DataFrame}

Prepare data structures optimized for plotting comparisons.

Returns dictionary with plotting-ready datasets:
- "degree_comparison": L2 norms vs degrees for each experiment
- "domain_comparison": Performance vs domain size
- "experiment_summary": Overall statistics per experiment
"""
function prepare_comparison_plots(comparison_data::DataFrame)
    plot_data = Dict{String, DataFrame}()

    # Degree comparison data
    degree_data = combine(groupby(comparison_data, [:experiment_id, :degree])) do sdf
        DataFrame(
            mean_l2 = mean(sdf.z),
            std_l2 = std(sdf.z),
            min_l2 = minimum(sdf.z),
            max_l2 = maximum(sdf.z),
            n_points = nrow(sdf),
            domain_size = first(sdf.domain_size)
        )
    end
    plot_data["degree_comparison"] = degree_data

    # Domain size comparison (if multiple domain sizes available)
    if length(unique(skipmissing(comparison_data.domain_size))) > 1
        domain_data = combine(groupby(comparison_data, [:domain_size, :degree])) do sdf
            DataFrame(
                mean_l2 = mean(sdf.z),
                std_l2 = std(sdf.z),
                n_experiments = length(unique(sdf.experiment_id)),
                n_points = nrow(sdf)
            )
        end
        plot_data["domain_comparison"] = domain_data
    end

    # Experiment summary
    summary_data = combine(groupby(comparison_data, :experiment_id)) do sdf
        DataFrame(
            degrees_tested = length(unique(sdf.degree)),
            total_points = nrow(sdf),
            mean_l2_overall = mean(sdf.z),
            best_l2 = minimum(sdf.z),
            worst_l2 = maximum(sdf.z),
            domain_size = first(sdf.domain_size),
            timestamp = first(sdf.timestamp)
        )
    end
    plot_data["experiment_summary"] = summary_data

    return plot_data
end

"""
    create_experiment_comparison(search_path::String = "."; degrees::Vector{Int} = Int[]) -> ExperimentComparison

Complete workflow to discover, load, and organize experiment data for comparison.

Parameters:
- `search_path`: Root directory to search for experiments
- `degrees`: Specific degrees to analyze (empty = all available)

Returns ExperimentComparison structure ready for analysis and plotting.
"""
function create_experiment_comparison(search_path::String = "."; degrees::Vector{Int} = Int[])
    println("🚀 Creating experiment comparison analysis...")
    println("="^60)

    # Step 1: Discover experiments
    experiments = discover_experiments(search_path)

    if isempty(experiments)
        println("❌ No experiments found in $search_path")
        return ExperimentComparison(Dict(), Dict(), DataFrame(), Dict())
    end

    # Step 2: Load comparison data
    comparison_data = load_comparison_data(experiments, degrees)

    if nrow(comparison_data) == 0
        println("❌ No data loaded from experiments")
        return ExperimentComparison(experiments, Dict(), DataFrame(), Dict())
    end

    # Step 3: Group by parameters
    parameter_groups = Dict()

    # Group by degree
    if :degree in names(comparison_data)
        degree_groups = group_by_parameter(comparison_data, :degree)
        parameter_groups["degree"] = degree_groups
    end

    # Group by domain size (if available)
    if :domain_size in names(comparison_data) && !all(ismissing.(comparison_data.domain_size))
        domain_groups = group_by_parameter(comparison_data, :domain_size)
        parameter_groups["domain_size"] = domain_groups
    end

    # Step 4: Calculate metrics
    metrics = Dict{String, Dict{String, Float64}}()
    for (exp_id, exp_data) in groupby(comparison_data, :experiment_id)
        exp_id_str = first(exp_data.experiment_id)
        metrics[exp_id_str] = Dict(
            "mean_l2" => mean(exp_data.z),
            "std_l2" => std(exp_data.z),
            "best_l2" => minimum(exp_data.z),
            "total_points" => Float64(nrow(exp_data)),
            "degrees_count" => Float64(length(unique(exp_data.degree)))
        )
    end

    println("\n✅ Comparison analysis complete!")
    println("   Experiments: $(length(experiments))")
    println("   Total data points: $(nrow(comparison_data))")
    println("   Parameter groups: $(keys(parameter_groups))")

    return ExperimentComparison(experiments, parameter_groups, comparison_data, metrics)
end

end # module ComparisonAnalysis