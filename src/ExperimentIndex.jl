module ExperimentIndex

"""
Experiment Index Management System
==================================

Provides indexing and search functionality for HPC experiment results.

Features:
- Parameter hashing for duplicate detection
- Computation index with fast lookup
- Parameter grouping index
- Search/query interface
- Integration with experiment pipeline

Author: GlobTim Project
Date: October 6, 2025
"""

using JSON
using Dates
using SHA

export ComputationIndex, ParameterIndex, ComputationEntry, ParameterGroup
export compute_parameter_hash
export initialize_index, load_index, save_index
export load_parameter_index, save_parameter_index
export add_computation!, update_computation!
export add_parameter_group!
export find_duplicates
export search_computations, get_computation, list_recent_computations
export extract_indexable_parameters, generate_computation_id

# ============================================================================
# Data Structures
# ============================================================================

"""
Entry for a single computation in the index
"""
Base.@kwdef struct ComputationEntry
    computation_id::String
    path::String
    experiment_name::String
    timestamp::DateTime
    status::String
    parameters_hash::String
    parameters::Dict{String, Any}
    runtime::Float64
    metadata::Dict{String, Any}
end

"""
Group of computations with identical parameters
"""
struct ParameterGroup
    parameters_hash::String
    parameters::Dict{String, Any}
    computation_ids::Vector{String}
    latest_computation_id::String
    first_seen::DateTime
    last_seen::DateTime
end

"""
Main computation index
"""
mutable struct ComputationIndex
    computations::Dict{String, ComputationEntry}
    last_updated::DateTime
    total_computations::Int
end

# Constructor
ComputationIndex() = ComputationIndex(Dict{String, ComputationEntry}(), now(), 0)

"""
Parameter-based index for grouping computations
"""
mutable struct ParameterIndex
    parameter_groups::Dict{String, ParameterGroup}
end

# Constructor
ParameterIndex() = ParameterIndex(Dict{String, ParameterGroup}())

# ============================================================================
# Parameter Hashing
# ============================================================================

"""
    compute_parameter_hash(parameters::Dict) -> String

Compute a deterministic SHA256 hash of experiment parameters.
Returns a string in format "sha256:hash_value".

The hash is computed from a canonical JSON representation, ensuring:
- Key order independence
- Deterministic output for identical parameters
- Handles nested dictionaries and arrays
"""
function compute_parameter_hash(parameters::Dict)
    # Convert to canonical JSON (sorted keys)
    canonical_json = JSON.json(parameters, 2)  # Pretty print for consistency

    # Sort the JSON keys to ensure determinism
    parsed = JSON.parse(canonical_json)
    sorted_json = JSON.json(sort_dict_recursively(parsed))

    # Compute SHA256 hash
    hash_bytes = sha256(sorted_json)
    hash_hex = bytes2hex(hash_bytes)

    return "sha256:$(hash_hex)"
end

"""
Recursively sort dictionary keys for canonical representation
"""
function sort_dict_recursively(obj)
    if obj isa Dict
        # Sort by key (convert to string for comparison to handle mixed types)
        sorted_pairs = sort(collect(obj), by = pair -> string(pair.first))
        sorted = OrderedDict(sorted_pairs)
        return OrderedDict(k => sort_dict_recursively(v) for (k, v) in sorted)
    elseif obj isa Array
        return [sort_dict_recursively(item) for item in obj]
    else
        return obj
    end
end

# Use OrderedDict for sorting
using DataStructures: OrderedDict

# ============================================================================
# Index Management
# ============================================================================

"""
    initialize_index(index_file::String) -> ComputationIndex

Initialize a new computation index. Creates the file if it doesn't exist.
"""
function initialize_index(index_file::String)
    if isfile(index_file)
        return load_index(index_file)
    else
        index = ComputationIndex()
        save_index(index, index_file)
        return index
    end
end

"""
    load_index(index_file::String) -> ComputationIndex

Load computation index from JSON file.
"""
function load_index(index_file::String)
    if !isfile(index_file)
        error("Index file not found: $index_file")
    end

    data = JSON.parsefile(index_file)

    # Reconstruct computations
    computations = Dict{String, ComputationEntry}()
    for (comp_id, comp_data) in data["computations"]
        entry = ComputationEntry(
            comp_id,
            comp_data["path"],
            comp_data["experiment_name"],
            DateTime(comp_data["timestamp"]),
            comp_data["status"],
            comp_data["parameters_hash"],
            comp_data["parameters"],
            comp_data["runtime"],
            get(comp_data, "metadata", Dict{String, Any}())
        )
        computations[comp_id] = entry
    end

    index = ComputationIndex(
        computations,
        DateTime(data["last_updated"]),
        data["total_computations"]
    )

    return index
end

"""
    save_index(index::ComputationIndex, index_file::String)

Save computation index to JSON file.
"""
function save_index(index::ComputationIndex, index_file::String)
    # Update timestamp
    index.last_updated = now()

    # Convert to dictionary
    data = Dict(
        "computations" => Dict(
            comp_id => Dict(
                "path" => entry.path,
                "experiment_name" => entry.experiment_name,
                "timestamp" => string(entry.timestamp),
                "status" => entry.status,
                "parameters_hash" => entry.parameters_hash,
                "parameters" => entry.parameters,
                "runtime" => entry.runtime,
                "metadata" => entry.metadata
            )
            for (comp_id, entry) in index.computations
        ),
        "last_updated" => string(index.last_updated),
        "total_computations" => index.total_computations
    )

    # Ensure directory exists
    mkpath(dirname(index_file))

    # Write to file
    open(index_file, "w") do io
        JSON.print(io, data, 2)
    end
end

"""
    add_computation!(index::ComputationIndex, entry::ComputationEntry)

Add a new computation to the index.
"""
function add_computation!(index::ComputationIndex, entry::ComputationEntry)
    if haskey(index.computations, entry.computation_id)
        @warn "Computation ID already exists: $(entry.computation_id). Use update_computation! to modify."
        return
    end

    index.computations[entry.computation_id] = entry
    index.total_computations = length(index.computations)
    index.last_updated = now()
end

"""
    update_computation!(index::ComputationIndex, entry::ComputationEntry)

Update an existing computation in the index.
"""
function update_computation!(index::ComputationIndex, entry::ComputationEntry)
    index.computations[entry.computation_id] = entry
    index.last_updated = now()
end

# ============================================================================
# Parameter Index Management
# ============================================================================

"""
    load_parameter_index(index_file::String) -> ParameterIndex

Load parameter index from JSON file.
"""
function load_parameter_index(index_file::String)
    if !isfile(index_file)
        error("Parameter index file not found: $index_file")
    end

    data = JSON.parsefile(index_file)

    parameter_groups = Dict{String, ParameterGroup}()
    for (hash, group_data) in data["parameter_groups"]
        group = ParameterGroup(
            hash,
            group_data["parameters"],
            group_data["computation_ids"],
            group_data["latest_computation_id"],
            DateTime(group_data["first_seen"]),
            DateTime(group_data["last_seen"])
        )
        parameter_groups[hash] = group
    end

    return ParameterIndex(parameter_groups)
end

"""
    save_parameter_index(param_index::ParameterIndex, index_file::String)

Save parameter index to JSON file.
"""
function save_parameter_index(param_index::ParameterIndex, index_file::String)
    data = Dict(
        "parameter_groups" => Dict(
            hash => Dict(
                "parameters" => group.parameters,
                "computation_ids" => group.computation_ids,
                "latest_computation_id" => group.latest_computation_id,
                "first_seen" => string(group.first_seen),
                "last_seen" => string(group.last_seen)
            )
            for (hash, group) in param_index.parameter_groups
        )
    )

    # Ensure directory exists
    mkpath(dirname(index_file))

    # Write to file
    open(index_file, "w") do io
        JSON.print(io, data, 2)
    end
end

"""
    add_parameter_group!(param_index::ParameterIndex, hash::String,
                         parameters::Dict, computation_id::String)

Add a computation to a parameter group or create a new group.
"""
function add_parameter_group!(param_index::ParameterIndex, hash::String,
                              parameters::Dict, computation_id::String)
    if haskey(param_index.parameter_groups, hash)
        # Update existing group
        group = param_index.parameter_groups[hash]
        push!(group.computation_ids, computation_id)

        # Create updated group
        updated_group = ParameterGroup(
            group.parameters_hash,
            group.parameters,
            group.computation_ids,
            computation_id,  # Latest is the one we just added
            group.first_seen,
            now()
        )
        param_index.parameter_groups[hash] = updated_group
    else
        # Create new group
        group = ParameterGroup(
            hash,
            parameters,
            [computation_id],
            computation_id,
            now(),
            now()
        )
        param_index.parameter_groups[hash] = group
    end
end

# ============================================================================
# Duplicate Detection
# ============================================================================

"""
    find_duplicates(index::ComputationIndex, parameters::Dict;
                    days_threshold::Int=30) -> Vector{ComputationEntry}

Find computations with identical parameters within the specified time window.

# Arguments
- `index`: The computation index to search
- `parameters`: Parameters to match
- `days_threshold`: Only consider computations from the last N days (default: 30)

# Returns
Vector of ComputationEntry objects with matching parameters
"""
function find_duplicates(index::ComputationIndex, parameters::Dict;
                        days_threshold::Int=30)
    target_hash = compute_parameter_hash(parameters)
    cutoff_date = now() - Day(days_threshold)

    duplicates = ComputationEntry[]

    for (comp_id, entry) in index.computations
        if entry.parameters_hash == target_hash && entry.timestamp >= cutoff_date
            push!(duplicates, entry)
        end
    end

    # Sort by timestamp (most recent first)
    sort!(duplicates, by = e -> e.timestamp, rev=true)

    return duplicates
end

# ============================================================================
# Search and Query Interface
# ============================================================================

"""
    search_computations(index::ComputationIndex; kwargs...) -> Vector{ComputationEntry}

Search computations with various criteria.

# Keyword Arguments
- `experiment_name::String`: Filter by experiment name
- `status::String`: Filter by status (SUCCESS, FAILED, etc.)
- `after::DateTime`: Only results after this date
- `before::DateTime`: Only results before this date

# Returns
Vector of matching ComputationEntry objects
"""
function search_computations(index::ComputationIndex;
                            experiment_name::Union{String, Nothing}=nothing,
                            status::Union{String, Nothing}=nothing,
                            after::Union{DateTime, Nothing}=nothing,
                            before::Union{DateTime, Nothing}=nothing)
    results = ComputationEntry[]

    for (comp_id, entry) in index.computations
        # Apply filters
        if experiment_name !== nothing && entry.experiment_name != experiment_name
            continue
        end

        if status !== nothing && entry.status != status
            continue
        end

        if after !== nothing && entry.timestamp < after
            continue
        end

        if before !== nothing && entry.timestamp > before
            continue
        end

        push!(results, entry)
    end

    # Sort by timestamp (most recent first)
    sort!(results, by = e -> e.timestamp, rev=true)

    return results
end

"""
    get_computation(index::ComputationIndex, computation_id::String) -> Union{ComputationEntry, Nothing}

Get a computation by its ID.
"""
function get_computation(index::ComputationIndex, computation_id::String)
    return get(index.computations, computation_id, nothing)
end

"""
    list_recent_computations(index::ComputationIndex; limit::Int=10) -> Vector{ComputationEntry}

List the most recent computations.
"""
function list_recent_computations(index::ComputationIndex; limit::Int=10)
    results = collect(values(index.computations))
    sort!(results, by = e -> e.timestamp, rev=true)
    return results[1:min(limit, length(results))]
end

# ============================================================================
# Integration Utilities
# ============================================================================

"""
    extract_indexable_parameters(config::Dict) -> Dict

Extract parameters that should be indexed from experiment config.

Excludes metadata fields like experiment_id, created_at, description.
"""
function extract_indexable_parameters(config::Dict)
    # List of metadata fields to exclude
    metadata_fields = Set([
        "experiment_id", "created_at", "description",
        "timestamp", "computation_id", "path"
    ])

    indexable = Dict{String, Any}()

    for (key, value) in config
        if !(key in metadata_fields)
            indexable[key] = value
        end
    end

    return indexable
end

"""
    generate_computation_id(config::Dict) -> String

Generate a unique 8-character computation ID from config.
"""
function generate_computation_id(config::Dict)
    # Use timestamp and experiment_id to create a unique ID
    timestamp_str = get(config, "created_at", string(now()))
    exp_id = get(config, "experiment_id", 0)

    # Create a hash and take first 8 characters
    hash_input = "$(timestamp_str)_$(exp_id)_$(rand())"
    hash_hex = bytes2hex(sha256(hash_input))

    return lowercase(hash_hex[1:8])
end

end # module ExperimentIndex
