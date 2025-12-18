"""
BatchManifest - Formal batch experiment tracking and management.

Provides structures and functions for:
- Creating and saving batch manifests
- Tracking experiment status (pending/running/completed/failed)
- Validating batch completeness
- Detecting and reporting errors in batch experiments
- Integration with postprocessing infrastructure

# Key Types
- `BatchManifest`: Complete batch metadata and experiment list
- `ExperimentEntry`: Individual experiment tracking record
- `BatchValidation`: Results of batch completeness validation
- `ErrorReport`: Detailed error information for failed experiments

# Usage

```julia
# Create a new batch manifest
manifest = BatchManifest(
    "lv4d_2025_10_09",
    "parameter_sweep",
    now(),
    3,
    [exp1, exp2, exp3],
    Dict("param" => "value"),
    "pending"
)

# Save to disk
save_batch_manifest(manifest, "experiments/batches/lv4d_2025_10_09")

# Load from disk
loaded = load_batch_manifest("experiments/batches/lv4d_2025_10_09")

# Update experiment status
update_experiment_status!(manifest, "exp_1", "running")
update_experiment_status!(manifest, "exp_1", "completed")

# Validate batch completeness
validation = validate_batch_completeness(manifest, results_dir)

# Detect errors
errors = identify_batch_errors(manifest, results_dir)
```
"""
module BatchManifest

using Dates
using JSON3
using StructTypes

export save_batch_manifest, load_batch_manifest
export update_experiment_status!, validate_batch_completeness
export identify_batch_errors, get_batch_summary
export discover_experiment_directory

# Type definitions

"""
    ExperimentEntry

Tracks metadata and status for a single experiment within a batch.

# Fields
- `experiment_id::String`: Unique identifier (e.g., "exp_1")
- `script_path::String`: Path to experiment script
- `config_path::String`: Path to experiment configuration
- `output_dir::String`: Path to results output directory
- `status::String`: Current status: "pending", "running", "completed", "failed"
- `start_time::Union{DateTime, Nothing}`: When experiment started (nothing if not started)
- `end_time::Union{DateTime, Nothing}`: When experiment finished (nothing if not finished)
- `error::Union{String, Nothing}`: Error message if failed (nothing if successful)
"""
struct ExperimentEntry
    experiment_id::String
    script_path::String
    config_path::String
    output_dir::String
    status::String
    start_time::Union{DateTime, Nothing}
    end_time::Union{DateTime, Nothing}
    error::Union{String, Nothing}

    function ExperimentEntry(
        experiment_id::String,
        script_path::String,
        config_path::String,
        output_dir::String,
        status::String,
        start_time::Union{DateTime, Nothing}=nothing,
        end_time::Union{DateTime, Nothing}=nothing,
        error::Union{String, Nothing}=nothing
    )
        # Validate status
        valid_statuses = ["pending", "running", "completed", "failed"]
        if !(status in valid_statuses)
            throw(ArgumentError("Invalid status '$status'. Must be one of: $(join(valid_statuses, ", "))"))
        end

        new(experiment_id, script_path, config_path, output_dir, status, start_time, end_time, error)
    end
end

# JSON3 serialization for ExperimentEntry
StructTypes.StructType(::Type{ExperimentEntry}) = StructTypes.Struct()

"""
    Manifest

Complete metadata and tracking for a batch of related experiments.

# Fields
- `batch_id::String`: Unique batch identifier (e.g., "lv4d_2025_10_09")
- `batch_type::String`: Type of batch (e.g., "parameter_sweep", "convergence_study")
- `created_at::DateTime`: Timestamp when batch was created
- `total_experiments::Int`: Total number of experiments in batch
- `experiments::Vector{ExperimentEntry}`: List of all experiments in batch
- `batch_params::Dict{String, Any}`: Batch-level parameters and metadata
- `status::String`: Overall batch status: "pending", "running", "complete", "failed"
"""
struct Manifest
    batch_id::String
    batch_type::String
    created_at::DateTime
    total_experiments::Int
    experiments::Vector{ExperimentEntry}
    batch_params::Dict{String, Any}
    status::String

    function Manifest(
        batch_id::String,
        batch_type::String,
        created_at::DateTime,
        total_experiments::Int,
        experiments::Vector{ExperimentEntry},
        batch_params::Dict{String, Any},
        status::String
    )
        # Validate status
        valid_statuses = ["pending", "running", "complete", "failed"]
        if !(status in valid_statuses)
            throw(ArgumentError("Invalid batch status '$status'. Must be one of: $(join(valid_statuses, ", "))"))
        end

        # Validate experiment count
        if length(experiments) != total_experiments
            throw(ArgumentError("Experiment count mismatch: total_experiments=$total_experiments but got $(length(experiments)) experiments"))
        end

        new(batch_id, batch_type, created_at, total_experiments, experiments, batch_params, status)
    end
end

# JSON3 serialization for Manifest
StructTypes.StructType(::Type{Manifest}) = StructTypes.Struct()

"""
    BatchValidation

Results of batch completeness validation.

# Fields
- `total_experiments::Int`: Total experiments expected
- `complete_experiments::Int`: Number with valid results
- `missing_experiments::Vector{String}`: IDs of missing/incomplete experiments
- `is_complete::Bool`: Whether batch is fully complete
"""
struct BatchValidation
    total_experiments::Int
    complete_experiments::Int
    missing_experiments::Vector{String}
    is_complete::Bool
end

"""
    ErrorReport

Detailed error information for a failed experiment.

# Fields
- `experiment_id::String`: ID of failed experiment
- `error_type::String`: Type of error (e.g., "missing_output", "invalid_json")
- `error_message::String`: Detailed error description
- `stack_trace::Union{String, Nothing}`: Stack trace if available
- `failed_at::DateTime`: When error was detected
- `degree_at_failure::Union{Int, Nothing}`: Polynomial degree when failure occurred (if applicable)
"""
struct ErrorReport
    experiment_id::String
    error_type::String
    error_message::String
    stack_trace::Union{String, Nothing}
    failed_at::DateTime
    degree_at_failure::Union{Int, Nothing}
end

# Core functions

"""
    save_batch_manifest(manifest::Manifest, batch_dir::String)

Save batch manifest to disk as JSON.

The manifest is saved to `\$batch_dir/batch_manifest.json`.

# Arguments
- `manifest`: The Manifest to save
- `batch_dir`: Directory where batch data is stored

# Examples
```julia
save_batch_manifest(manifest, "experiments/batches/lv4d_2025_10_09")
# Creates: experiments/batches/lv4d_2025_10_09/batch_manifest.json
```
"""
function save_batch_manifest(manifest::Manifest, batch_dir::String)
    mkpath(batch_dir)
    manifest_path = joinpath(batch_dir, "batch_manifest.json")

    open(manifest_path, "w") do io
        JSON3.pretty(io, manifest)
    end

    return manifest_path
end

"""
    load_batch_manifest(batch_dir::String) -> Manifest

Load batch manifest from disk.

Reads `\$batch_dir/batch_manifest.json` and reconstructs the Manifest.

# Arguments
- `batch_dir`: Directory containing batch_manifest.json

# Returns
- Manifest instance

# Throws
- SystemError if manifest file doesn't exist
- JSON3.Error if manifest is malformed
"""
function load_batch_manifest(batch_dir::String)
    manifest_path = joinpath(batch_dir, "batch_manifest.json")

    if !isfile(manifest_path)
        throw(SystemError("Batch manifest not found: $manifest_path"))
    end

    data = JSON3.read(read(manifest_path, String))

    # Convert string timestamps back to DateTime
    created_at = DateTime(data.created_at)

    # Reconstruct ExperimentEntry objects
    experiments = [
        ExperimentEntry(
            exp.experiment_id,
            exp.script_path,
            exp.config_path,
            exp.output_dir,
            exp.status,
            isnothing(exp.start_time) ? nothing : DateTime(exp.start_time),
            isnothing(exp.end_time) ? nothing : DateTime(exp.end_time),
            exp.error
        )
        for exp in data.experiments
    ]

    # Convert batch_params properly (JSON3 returns objects with Symbol keys)
    batch_params_dict = Dict{String, Any}()
    for (k, v) in pairs(data.batch_params)
        batch_params_dict[String(k)] = v
    end

    return Manifest(
        String(data.batch_id),
        String(data.batch_type),
        created_at,
        data.total_experiments,
        experiments,
        batch_params_dict,
        String(data.status)
    )
end

"""
    update_experiment_status!(manifest::Manifest, experiment_id::String, new_status::String; error::Union{String, Nothing}=nothing)

Update the status of an experiment in the batch manifest.

Creates a new Manifest with updated experiment entry (manifests are immutable).

# Arguments
- `manifest`: Current Manifest
- `experiment_id`: ID of experiment to update
- `new_status`: New status ("pending", "running", "completed", "failed")
- `error`: Optional error message (for failed status)

# Returns
- New Manifest with updated experiment

# Examples
```julia
# Start experiment
manifest = update_experiment_status!(manifest, "exp_1", "running")

# Complete experiment
manifest = update_experiment_status!(manifest, "exp_1", "completed")

# Mark as failed with error
manifest = update_experiment_status!(manifest, "exp_1", "failed",
                                     error="ODE solver diverged")
```
"""
function update_experiment_status!(manifest::Manifest,
                                   experiment_id::String,
                                   new_status::String;
                                   error::Union{String, Nothing}=nothing)
    idx = findfirst(e -> e.experiment_id == experiment_id, manifest.experiments)

    if isnothing(idx)
        throw(ArgumentError("Experiment '$experiment_id' not found in batch '$(manifest.batch_id)'"))
    end

    exp = manifest.experiments[idx]

    # Update timestamps based on status transition
    start_time = exp.start_time
    end_time = exp.end_time

    if new_status == "running" && isnothing(start_time)
        start_time = now()
    end

    if new_status in ["completed", "failed"] && isnothing(end_time)
        end_time = now()
    end

    # Create updated experiment entry
    updated_exp = ExperimentEntry(
        exp.experiment_id,
        exp.script_path,
        exp.config_path,
        exp.output_dir,
        new_status,
        start_time,
        end_time,
        error
    )

    # Create new experiments vector with updated entry
    updated_experiments = copy(manifest.experiments)
    updated_experiments[idx] = updated_exp

    # Determine overall batch status
    statuses = [e.status for e in updated_experiments]
    batch_status = if any(s -> s == "failed", statuses)
        "failed"  # If any failed, batch is failed
    elseif all(s -> s == "completed", statuses)
        "complete"  # If all completed, batch is complete
    elseif any(s -> s in ["running", "completed"], statuses)
        "running"  # If any are running or completed (but not all completed), batch is running
    else
        "pending"  # All pending
    end

    # Return new Manifest
    return Manifest(
        manifest.batch_id,
        manifest.batch_type,
        manifest.created_at,
        manifest.total_experiments,
        updated_experiments,
        manifest.batch_params,
        batch_status
    )
end

"""
    discover_experiment_directory(exp::ExperimentEntry, results_dir::String) -> Union{String, Nothing}

Discover the actual output directory for an experiment, handling dynamic timestamp patterns.

If `output_dir` contains Julia string interpolation patterns (e.g., `\$(Dates.format(...))`),
this function attempts to find matching directories in `results_dir` using pattern matching.

# Arguments
- `exp`: ExperimentEntry to find directory for
- `results_dir`: Root directory containing experiment results

# Returns
- Absolute path to discovered directory, or `nothing` if not found

# Examples
```julia
# Manifest says: "hpc_results/lotka_volterra_4d_exp1_range0.4_\$(Dates.format(...))"
# Actual dir: "hpc_results/lotka_volterra_4d_exp1_range0.4_20251009_153430"
actual_dir = discover_experiment_directory(exp, "globtimcore/hpc_results")
# Returns: "globtimcore/hpc_results/lotka_volterra_4d_exp1_range0.4_20251009_153430"
```
"""
function discover_experiment_directory(exp::ExperimentEntry, results_dir::String)
    # First try the literal path from manifest
    exp_dir = joinpath(results_dir, basename(exp.output_dir))
    if isdir(exp_dir)
        return exp_dir
    end

    # Check if output_dir contains dynamic patterns
    if occursin("\$(", exp.output_dir)
        # Extract the pattern before the dynamic part
        # e.g., "hpc_results/lotka_volterra_4d_exp1_range0.4_$(Dates...)"
        # becomes "lotka_volterra_4d_exp1_range0.4_"
        pattern_match = match(r"([^/]+)_\$\(Dates\.format", exp.output_dir)

        if !isnothing(pattern_match)
            prefix = pattern_match.captures[1] * "_"

            # Search for directories matching this pattern
            if isdir(results_dir)
                for entry in readdir(results_dir)
                    if startswith(entry, prefix)
                        candidate_dir = joinpath(results_dir, entry)
                        if isdir(candidate_dir)
                            return candidate_dir
                        end
                    end
                end
            end
        end
    end

    # Also try just using experiment_id as fallback
    exp_dir_by_id = joinpath(results_dir, exp.experiment_id)
    if isdir(exp_dir_by_id)
        return exp_dir_by_id
    end

    return nothing
end

"""
    validate_batch_completeness(manifest::Manifest, results_dir::String) -> BatchValidation

Validate that all experiments in the batch have complete results.

Checks for:
- Experiment output directories exist (handles dynamic timestamp patterns)
- results_summary.json files present and valid
- CSV files present (optional check)

# Arguments
- `manifest`: Manifest to validate
- `results_dir`: Root directory containing experiment results

# Returns
- BatchValidation with completeness information
"""
function validate_batch_completeness(manifest::Manifest, results_dir::String)
    complete_count = 0
    missing_ids = String[]

    for exp in manifest.experiments
        # Try to discover actual directory (handles dynamic timestamps)
        exp_dir = discover_experiment_directory(exp, results_dir)

        # Check if output directory exists
        if isnothing(exp_dir) || !isdir(exp_dir)
            push!(missing_ids, exp.experiment_id)
            continue
        end

        # Check if results_summary.json exists
        results_file = joinpath(exp_dir, "results_summary.json")
        if !isfile(results_file)
            push!(missing_ids, exp.experiment_id)
            continue
        end

        # Try to parse JSON (basic validation)
        try
            JSON3.read(read(results_file, String))
            complete_count += 1
        catch
            push!(missing_ids, exp.experiment_id)
        end
    end

    return BatchValidation(
        manifest.total_experiments,
        complete_count,
        missing_ids,
        complete_count == manifest.total_experiments
    )
end

"""
    identify_batch_errors(manifest::Manifest, results_dir::String) -> Vector{ErrorReport}

Identify and categorize all errors in a batch.

Detects:
- Missing output directories
- Missing results files
- Invalid/malformed JSON
- Execution errors (from error.log files)

# Arguments
- `manifest`: Manifest to check
- `results_dir`: Root directory containing experiment results

# Returns
- Vector of ErrorReport for each failed experiment
"""
function identify_batch_errors(manifest::Manifest, results_dir::String)
    errors = ErrorReport[]

    for exp in manifest.experiments
        # Try to discover actual directory (handles dynamic timestamps)
        exp_dir = discover_experiment_directory(exp, results_dir)

        # Check for missing output directories
        if isnothing(exp_dir) || !isdir(exp_dir)
            push!(errors, ErrorReport(
                exp.experiment_id,
                "missing_output",
                "Output directory not found. Expected pattern: $(exp.output_dir)",
                nothing,
                now(),
                nothing
            ))
            continue
        end

        # Check for incomplete results
        results_file = joinpath(exp_dir, "results_summary.json")
        if !isfile(results_file)
            push!(errors, ErrorReport(
                exp.experiment_id,
                "missing_results",
                "results_summary.json not found",
                nothing,
                now(),
                nothing
            ))
            continue
        end

        # Check for invalid JSON
        try
            JSON3.read(read(results_file, String))
        catch e
            push!(errors, ErrorReport(
                exp.experiment_id,
                "invalid_json",
                "JSON parse error in results_summary.json: $(string(e))",
                nothing,
                now(),
                nothing
            ))
            continue
        end

        # Check for error log files
        error_file = joinpath(exp_dir, "error.log")
        if isfile(error_file)
            error_content = read(error_file, String)
            push!(errors, ErrorReport(
                exp.experiment_id,
                "execution_error",
                error_content,
                nothing,
                now(),
                nothing
            ))
        end
    end

    return errors
end

"""
    get_batch_summary(manifest::Manifest) -> Dict

Get a summary of batch status.

# Returns
Dictionary with:
- `batch_id`: Batch identifier
- `total_experiments`: Total experiment count
- `pending`: Count of pending experiments
- `running`: Count of running experiments
- `completed`: Count of completed experiments
- `failed`: Count of failed experiments
- `status`: Overall batch status
"""
function get_batch_summary(manifest::Manifest)
    statuses = [e.status for e in manifest.experiments]

    return Dict(
        "batch_id" => manifest.batch_id,
        "total_experiments" => manifest.total_experiments,
        "pending" => count(s -> s == "pending", statuses),
        "running" => count(s -> s == "running", statuses),
        "completed" => count(s -> s == "completed", statuses),
        "failed" => count(s -> s == "failed", statuses),
        "status" => manifest.status
    )
end

end # module
