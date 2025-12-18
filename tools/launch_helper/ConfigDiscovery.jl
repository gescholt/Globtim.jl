"""
Config Discovery Module (Issue #136 Phase 2)

Handles discovery and parsing of experiment configuration files.

Author: GlobTim Project
Date: October 5, 2025
"""

module ConfigDiscovery

using JSON

export LaunchConfig, load_master_config, validate_launch_config, discover_configs,
       get_experiment_script_paths, get_experiment_count

"""
    LaunchConfig

Structure representing a complete experiment launch configuration.

# Fields
- `study_name::String`: Name of the experiment study
- `total_experiments::Int`: Total number of experiments
- `script_paths::Vector{String}`: Paths to experiment Julia scripts
- `experiments::Vector{Dict{Symbol,Any}}`: Experiment-specific configurations
- `domain_ranges::Vector{Float64}`: Domain range parameters
- `parameters::Dict{Symbol,Any}`: Shared parameters across experiments
"""
struct LaunchConfig
    study_name::String
    total_experiments::Int
    script_paths::Vector{String}
    experiments::Vector{Dict{Symbol,Any}}
    domain_ranges::Vector{Float64}
    parameters::Dict{Symbol,Any}

    # Constructor that accepts keyword arguments
    function LaunchConfig(;
        study_name::String,
        total_experiments::Int,
        script_paths::Vector{String},
        experiments::Vector{Dict{Symbol,Any}},
        domain_ranges::Vector{Float64},
        parameters::Dict{Symbol,Any}
    )
        new(study_name, total_experiments, script_paths, experiments, domain_ranges, parameters)
    end

    # Positional constructor
    function LaunchConfig(
        study_name::String,
        total_experiments::Int,
        script_paths::Vector{String},
        experiments::Vector{Dict{Symbol,Any}},
        domain_ranges::Vector{Float64},
        parameters::Dict{Symbol,Any}
    )
        new(study_name, total_experiments, script_paths, experiments, domain_ranges, parameters)
    end
end

"""
    load_master_config(config_path::String) -> LaunchConfig

Load and parse a master configuration JSON file.

# Arguments
- `config_path`: Path to master_config.json file

# Returns
- `LaunchConfig` struct containing parsed configuration

# Throws
- `ErrorException` if file not found or invalid JSON

# Examples
```julia
config = load_master_config("experiments/lv4d_study/configs_20251005/master_config.json")
println("Study: \$(config.study_name)")
println("Experiments: \$(config.total_experiments)")
```
"""
function load_master_config(config_path::String)::LaunchConfig
    if !isfile(config_path)
        error("Config file not found: $config_path")
    end

    # Parse JSON file
    json_data = JSON.parsefile(config_path)

    # Convert JSON data to LaunchConfig struct
    # Convert experiments to have Symbol keys
    experiments = [
        Dict{Symbol,Any}(Symbol(k) => v for (k, v) in exp)
        for exp in get(json_data, "experiments", [])
    ]

    # Convert parameters to have Symbol keys
    parameters = Dict{Symbol,Any}(
        Symbol(k) => v
        for (k, v) in get(json_data, "parameters", Dict())
    )

    # Explicitly convert types from JSON
    script_paths = String[string(path) for path in get(json_data, "script_paths", [])]
    domain_ranges = Float64[float(r) for r in get(json_data, "domain_ranges", [])]

    return LaunchConfig(
        string(get(json_data, "study_name", "unknown")),
        Int(get(json_data, "total_experiments", 0)),
        script_paths,
        experiments,
        domain_ranges,
        parameters
    )
end

"""
    ValidationResult

Result of configuration validation.

# Fields
- `valid::Bool`: Whether config is valid
- `errors::Vector{String}`: List of validation errors (empty if valid)
"""
struct ValidationResult
    valid::Bool
    errors::Vector{String}
end

"""
    validate_launch_config(config::LaunchConfig) -> ValidationResult

Validate a launch configuration for consistency and completeness.

# Arguments
- `config`: LaunchConfig to validate

# Returns
- `ValidationResult` indicating if config is valid and any errors found

# Examples
```julia
result = validate_launch_config(config)
if !result.valid
    println("Validation errors:")
    for err in result.errors
        println("  - \$err")
    end
end
```
"""
function validate_launch_config(config::LaunchConfig)::ValidationResult
    errors = String[]

    # Check that script_paths is not empty
    if isempty(config.script_paths)
        push!(errors, "script_paths is empty - no experiments to launch")
    end

    # Check that total_experiments matches script_paths length
    if config.total_experiments != length(config.script_paths)
        push!(errors, "Mismatch: total_experiments ($(config.total_experiments)) != script_paths count ($(length(config.script_paths)))")
    end

    # Check that total_experiments matches experiments array length
    if config.total_experiments != length(config.experiments)
        push!(errors, "Mismatch: total_experiments ($(config.total_experiments)) != experiments array count ($(length(config.experiments)))")
    end

    # Check that all script paths end with .jl
    invalid_scripts = filter(p -> !endswith(p, ".jl"), config.script_paths)
    if !isempty(invalid_scripts)
        push!(errors, "Invalid script paths (must end with .jl): $(join(invalid_scripts, ", "))")
    end

    # Check that study_name is not empty
    if isempty(config.study_name)
        push!(errors, "study_name is empty")
    end

    return ValidationResult(isempty(errors), errors)
end

"""
    discover_configs(pattern::String) -> Vector{LaunchConfig}

Discover and load all master_config.json files matching a glob pattern.

# Arguments
- `pattern`: Glob pattern to match config files (e.g., "experiments/**/configs_*/master_config.json")

# Returns
- Vector of LaunchConfig structs for all discovered configs

# Examples
```julia
# Discover all configs in experiments directory
configs = discover_configs("experiments/**/master_config.json")
println("Found \$(length(configs)) configurations")
```
"""
function discover_configs(pattern::String)::Vector{LaunchConfig}
    configs = LaunchConfig[]

    # Extract the base directory from pattern (remove glob portions)
    # Pattern might be like: "/tmp/xyz/experiments/**/configs_*/master_config.json"
    # We need to find the first real directory
    parts = splitpath(pattern)
    base_dir = ""

    for i in 1:length(parts)
        part = parts[i]
        # Stop at first wildcard
        if occursin('*', part) || occursin('?', part)
            if i > 1
                base_dir = joinpath(parts[1:i-1]...)
            end
            break
        end
    end

    # If no base_dir found, pattern might be a direct path
    if isempty(base_dir)
        # Try the whole dirname if it's a direct path
        test_dir = dirname(pattern)
        if isdir(test_dir)
            base_dir = test_dir
        else
            # Pattern is invalid
            return configs
        end
    end

    # Make sure base_dir exists
    if !isdir(base_dir)
        return configs
    end

    pattern_name = basename(pattern)

    # Walk directory tree to find matching files
    try
        for (root, _dirs, files) in walkdir(base_dir)
            for file in files
                if file == pattern_name || occursin("master_config.json", file)
                    full_path = joinpath(root, file)
                    # Load config
                    try
                        config = load_master_config(full_path)
                        push!(configs, config)
                    catch e
                        @warn "Failed to load config from $full_path: $e"
                    end
                end
            end
        end
    catch e
        @warn "Error walking directory $base_dir: $e"
    end

    return configs
end

"""
    get_experiment_script_paths(config::LaunchConfig) -> Vector{String}

Extract experiment script paths from configuration.

# Arguments
- `config`: LaunchConfig struct

# Returns
- Vector of script file paths

# Examples
```julia
scripts = get_experiment_script_paths(config)
for script in scripts
    println("Script: \$script")
end
```
"""
function get_experiment_script_paths(config::LaunchConfig)::Vector{String}
    return config.script_paths
end

"""
    get_experiment_count(config::LaunchConfig) -> Int

Get the total number of experiments in configuration.

# Arguments
- `config`: LaunchConfig struct

# Returns
- Number of experiments

# Examples
```julia
count = get_experiment_count(config)
println("Will launch \$count experiments")
```
"""
function get_experiment_count(config::LaunchConfig)::Int
    return config.total_experiments
end

end # module ConfigDiscovery
