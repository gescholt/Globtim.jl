"""
ExperimentDataLoader Module

Handles loading and parsing experiment data from various sources:
- JSON summary files (results_summary.json)
- Parameter files (experiment_params.json)
- CSV critical points files
- System metadata extraction

Usage:
    include("src/ExperimentDataLoader.jl")
    using .ExperimentDataLoader

    data = load_experiment_data("hpc_results/exp_dir")
    system_info = get_system_info(data)
    true_params = get_true_params(data)
"""
module ExperimentDataLoader

using JSON
using CSV
using DataFrames

export load_experiment_data,
       get_system_info,
       get_true_params,
       load_critical_points,
       collect_experiment_directories

"""
    load_experiment_data(experiment_dir::String) -> Dict

Load experiment results from directory, including:
- results_summary.json (main results)
- experiment_params.json (true parameters for recovery)

Returns combined dictionary with all experiment data.
"""
function load_experiment_data(experiment_dir::String)
    if !isdir(experiment_dir)
        error("Directory not found: $experiment_dir")
    end

    # Load JSON summary
    json_file = joinpath(experiment_dir, "results_summary.json")
    if !isfile(json_file)
        error("results_summary.json not found in $experiment_dir")
    end

    data = JSON.parsefile(json_file)

    # Load experiment_params.json for true_params (ground truth)
    params_file = joinpath(experiment_dir, "experiment_params.json")
    if isfile(params_file)
        params_data = JSON.parsefile(params_file)
        if haskey(params_data, "true_params")
            data["true_params"] = params_data["true_params"]
        end
    end

    return data
end

"""
    get_system_info(data::Dict) -> Union{Dict, Nothing}

Extract system metadata from experiment data.
Returns nothing if system_info not found.
"""
function get_system_info(data::Dict)
    if haskey(data, "system_info")
        return data["system_info"]
    end

    @warn "No system_info found in experiment data - results may be incomplete"
    return nothing
end

"""
    get_true_params(data::Dict) -> Union{Vector{Float64}, Nothing}

Extract ground truth parameters from experiment data.
These are the target parameters for parameter recovery experiments.
Returns nothing if true_params not found.
"""
function get_true_params(data::Dict)
    if haskey(data, "true_params")
        return convert(Vector{Float64}, data["true_params"])
    end
    return nothing
end

"""
    load_critical_points(experiment_dir::String, degree::Int) -> Union{DataFrame, Nothing}

Load critical points CSV file for a specific degree.
Returns nothing if file not found or empty.

Note: CSV files are only saved when critical points exist within the search domain.
If refined critical points were found but all are outside domain bounds, no CSV is saved.
Check results_summary.json for critical_points_refined vs critical_points counts.
"""
function load_critical_points(experiment_dir::String, degree::Int)
    csv_file = joinpath(experiment_dir, "critical_points_deg_$degree.csv")

    if !isfile(csv_file)
        # Check if results_summary explains why CSV is missing
        results_file = joinpath(experiment_dir, "results_summary.json")
        if isfile(results_file)
            try
                data = JSON.parsefile(results_file)
                degree_key = "degree_$degree"
                if haskey(data, "results_summary") && haskey(data["results_summary"], degree_key)
                    result = data["results_summary"][degree_key]
                    refined = get(result, "critical_points_refined", 0)
                    in_domain = get(result, "critical_points", 0)

                    if refined > 0 && in_domain == 0
                        @info "Degree $degree: $refined refined critical points found, but all outside domain bounds. No CSV saved (by design)."
                    else
                        @warn "No critical points file for degree $degree"
                    end
                else
                    @warn "No critical points file for degree $degree"
                end
            catch
                @warn "No critical points file for degree $degree"
            end
        else
            @warn "No critical points file for degree $degree"
        end
        return nothing
    end

    df = CSV.read(csv_file, DataFrame)

    if nrow(df) == 0
        @warn "Empty critical points file for degree $degree"
        return nothing
    end

    return df
end

"""
    collect_experiment_directories(base_dir::String = "hpc_results") -> Vector{String}

Scan for experiment directories in the specified base directory.
Returns vector of full paths to experiment directories.

TODO: Add SSH collection functionality for remote clusters.
"""
function collect_experiment_directories(base_dir::String = "hpc_results")
    local_path = joinpath(pwd(), base_dir)

    if !isdir(local_path)
        @warn "Directory not found: $local_path"
        return String[]
    end

    # Find experiment directories
    all_dirs = readdir(local_path)
    dirs = filter(d -> occursin("minimal_4d_lv_test_", d), all_dirs)

    # Convert to full paths
    dirs = [joinpath(base_dir, d) for d in dirs]
    sort!(dirs)

    println("📂 Found $(length(dirs)) experiment directories")
    return dirs
end

end # module