"""
ExperimentIndexIntegration
===========================

Integration module for hooking the experiment index into the pipeline.

This module provides convenience functions to:
- Index experiments before execution
- Check for duplicates and warn users
- Update index after experiment completion
- Provide CLI interface for searching

Author: GlobTim Project
Date: October 6, 2025
"""

include("ExperimentIndex.jl")
using .ExperimentIndex

using JSON
using Dates

export check_and_index_experiment, update_experiment_status
export search_experiments_cli, list_recent_experiments_cli

# Default index locations
const DEFAULT_INDEX_DIR = "experiments/indices"
const COMPUTATION_INDEX_FILE = "computation_index.json"
const PARAMETER_INDEX_FILE = "parameter_index.json"

"""
    get_index_files(; project_root=nothing) -> (String, String)

Get the paths to the index files, creating directories if needed.
"""
function get_index_files(; project_root=nothing)
    if project_root === nothing
        # Try to determine project root
        try
            # Try to load PathUtils module if not already loaded
            if !isdefined(@__MODULE__, :PathUtils)
                include(joinpath(@__DIR__, "PathUtils.jl"))
                project_root = Main.PathUtils.get_project_root()
            else
                project_root = PathUtils.get_project_root()
            end
        catch
            project_root = dirname(dirname(@__FILE__))
        end
    end

    index_dir = joinpath(project_root, DEFAULT_INDEX_DIR)
    mkpath(index_dir)

    comp_index_file = joinpath(index_dir, COMPUTATION_INDEX_FILE)
    param_index_file = joinpath(index_dir, PARAMETER_INDEX_FILE)

    return (comp_index_file, param_index_file)
end

"""
    check_and_index_experiment(config::Dict;
                               experiment_name::String,
                               experiment_path::String,
                               warn_duplicates::Bool=true,
                               index_dir::Union{String,Nothing}=nothing) -> (Bool, String, Vector{ComputationEntry})

Check for duplicate experiments and add to index.

Returns:
- (has_duplicates, computation_id, duplicate_entries)

If warn_duplicates is true and duplicates are found, prints a warning message.
"""
function check_and_index_experiment(config::Dict;
                                   experiment_name::String,
                                   experiment_path::String,
                                   warn_duplicates::Bool=true,
                                   index_dir::Union{String,Nothing}=nothing)
    # Get index files
    comp_index_file, param_index_file = if index_dir !== nothing
        (joinpath(index_dir, COMPUTATION_INDEX_FILE),
         joinpath(index_dir, PARAMETER_INDEX_FILE))
    else
        get_index_files()
    end

    # Load or initialize indices
    comp_index = initialize_index(comp_index_file)
    param_index = if isfile(param_index_file)
        load_parameter_index(param_index_file)
    else
        ParameterIndex()
    end

    # Extract indexable parameters
    params = extract_indexable_parameters(config)
    param_hash = compute_parameter_hash(params)

    # Check for duplicates
    duplicates = find_duplicates(comp_index, params, days_threshold=30)

    # Generate computation ID
    comp_id = generate_computation_id(config)

    # Create entry with PENDING status
    entry = ComputationEntry(
        computation_id = comp_id,
        path = experiment_path,
        experiment_name = experiment_name,
        timestamp = now(),
        status = "PENDING",
        parameters_hash = param_hash,
        parameters = params,
        runtime = 0.0,
        metadata = Dict("config_created_at" => get(config, "created_at", string(now())))
    )

    # Add to indices
    add_computation!(comp_index, entry)
    add_parameter_group!(param_index, param_hash, params, comp_id)

    # Save indices
    save_index(comp_index, comp_index_file)
    save_parameter_index(param_index, param_index_file)

    # Warn if duplicates found
    if warn_duplicates && !isempty(duplicates)
        println("\n⚠️  Warning: Found $(length(duplicates)) experiment(s) with identical parameters in the last 30 days:")
        for (i, dup) in enumerate(duplicates[1:min(3, length(duplicates))])
            age_days = Dates.value(now() - dup.timestamp) ÷ (1000 * 60 * 60 * 24)
            println("   $(i). $(dup.computation_id) - $(dup.status) - $(age_days) days ago")
            println("      Path: $(dup.path)")
        end
        if length(duplicates) > 3
            println("   ... and $(length(duplicates) - 3) more")
        end
        println("\n   Consider reusing existing results or modifying parameters.")
        println("   New computation ID: $(comp_id)\n")
    end

    return (!isempty(duplicates), comp_id, duplicates)
end

"""
    update_experiment_status(computation_id::String;
                            status::String,
                            runtime::Float64=0.0,
                            metadata::Dict=Dict(),
                            index_dir::Union{String,Nothing}=nothing)

Update the status of an experiment in the index.

Typical status values: "RUNNING", "SUCCESS", "FAILED", "TIMEOUT"
"""
function update_experiment_status(computation_id::String;
                                  status::String,
                                  runtime::Float64=0.0,
                                  metadata::Dict=Dict(),
                                  index_dir::Union{String,Nothing}=nothing)
    # Get index file
    comp_index_file, _ = if index_dir !== nothing
        (joinpath(index_dir, COMPUTATION_INDEX_FILE),
         joinpath(index_dir, PARAMETER_INDEX_FILE))
    else
        get_index_files()
    end

    # Load index
    comp_index = load_index(comp_index_file)

    # Get existing entry
    existing = get_computation(comp_index, computation_id)
    if existing === nothing
        @warn "Computation ID not found in index: $computation_id"
        return
    end

    # Create updated entry
    updated_entry = ComputationEntry(
        computation_id = existing.computation_id,
        path = existing.path,
        experiment_name = existing.experiment_name,
        timestamp = existing.timestamp,
        status = status,
        parameters_hash = existing.parameters_hash,
        parameters = existing.parameters,
        runtime = runtime,
        metadata = merge(existing.metadata, metadata)
    )

    # Update index
    update_computation!(comp_index, updated_entry)

    # Save index
    save_index(comp_index, comp_index_file)

    println("✅ Updated experiment $computation_id: status=$status, runtime=$(runtime)s")
end

"""
    search_experiments_cli(; kwargs...)

CLI interface for searching experiments.

Example usage:
```julia
search_experiments_cli(experiment_name="lotka_volterra_4d", status="SUCCESS")
```
"""
function search_experiments_cli(; kwargs...)
    comp_index_file, _ = get_index_files()

    if !isfile(comp_index_file)
        println("No experiments indexed yet.")
        return
    end

    comp_index = load_index(comp_index_file)

    results = search_computations(comp_index; kwargs...)

    if isempty(results)
        println("No experiments found matching criteria.")
        return
    end

    println("\n📊 Found $(length(results)) experiment(s):\n")
    for (i, result) in enumerate(results)
        age_days = Dates.value(now() - result.timestamp) ÷ (1000 * 60 * 60 * 24)
        println("$(i). $(result.computation_id) - $(result.experiment_name)")
        println("   Status: $(result.status) | Runtime: $(round(result.runtime, digits=2))s")
        println("   Created: $(age_days) days ago")
        println("   Path: $(result.path)")
        println()
    end
end

"""
    list_recent_experiments_cli(; limit::Int=10)

List the most recent experiments.
"""
function list_recent_experiments_cli(; limit::Int=10)
    comp_index_file, _ = get_index_files()

    if !isfile(comp_index_file)
        println("No experiments indexed yet.")
        return
    end

    comp_index = load_index(comp_index_file)

    results = list_recent_computations(comp_index, limit=limit)

    println("\n📊 $(length(results)) most recent experiment(s):\n")
    for (i, result) in enumerate(results)
        age_days = Dates.value(now() - result.timestamp) ÷ (1000 * 60 * 60 * 24)
        status_emoji = result.status == "SUCCESS" ? "✅" : result.status == "FAILED" ? "❌" : "⏳"

        println("$(i). $status_emoji $(result.computation_id) - $(result.experiment_name)")
        println("   Status: $(result.status) | Runtime: $(round(result.runtime, digits=2))s")
        println("   Created: $(age_days) days ago")
        println()
    end
end

"""
    get_experiment_details(computation_id::String)

Get detailed information about a specific experiment.
"""
function get_experiment_details(computation_id::String)
    comp_index_file, _ = get_index_files()

    if !isfile(comp_index_file)
        println("No experiments indexed yet.")
        return nothing
    end

    comp_index = load_index(comp_index_file)
    result = get_computation(comp_index, computation_id)

    if result === nothing
        println("Experiment not found: $computation_id")
        return nothing
    end

    age_days = Dates.value(now() - result.timestamp) ÷ (1000 * 60 * 60 * 24)

    println("\n📊 Experiment Details: $(result.computation_id)\n")
    println("Name:        $(result.experiment_name)")
    println("Status:      $(result.status)")
    println("Runtime:     $(round(result.runtime, digits=2))s")
    println("Created:     $(result.timestamp) ($(age_days) days ago)")
    println("Path:        $(result.path)")
    println("\nParameters:")
    for (k, v) in sort(collect(result.parameters), by=x->string(x.first))
        println("  $k: $v")
    end

    if !isempty(result.metadata)
        println("\nMetadata:")
        for (k, v) in sort(collect(result.metadata), by=x->string(x.first))
            println("  $k: $v")
        end
    end

    return result
end

