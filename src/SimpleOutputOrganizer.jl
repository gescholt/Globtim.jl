"""
SimpleOutputOrganizer.jl - Minimal experiment output path management

SINGLE PURPOSE: Create properly organized experiment directories.

Replaces manual:
    results_dir = joinpath("hpc_results", "exp_\$(timestamp)")
    mkpath(results_dir)

With automatic:
    exp_dir = create_experiment_dir(config)

Ensures compliance with globtim_results structure:
    \$GLOBTIM_RESULTS_ROOT/
    └── {objective_name}/
        └── {experiment_id}_{timestamp}/
"""
module SimpleOutputOrganizer

using Dates
using JSON3

export create_experiment_dir, get_results_root

"""
    get_results_root() -> String

Get the results root directory from environment or default to repo-relative path.

If GLOBTIM_RESULTS_ROOT is not set, defaults to:
  {repo_root}/globtim_results/

This makes local development easier while still allowing HPC deployments
to use custom paths via environment variable.
"""
function get_results_root()::String
    # Check environment variable first (for HPC/custom deployments)
    if haskey(ENV, "GLOBTIM_RESULTS_ROOT")
        root = ENV["GLOBTIM_RESULTS_ROOT"]

        if !isdir(root)
            error("GLOBTIM_RESULTS_ROOT directory does not exist: $root")
        end

        return abspath(root)
    end

    # Default to repo-relative path
    # From src/SimpleOutputOrganizer.jl -> globtimcore/ -> GlobalOptim/
    repo_root = dirname(dirname(@__DIR__))
    default_root = joinpath(repo_root, "globtim_results")

    # Create directory if it doesn't exist
    if !isdir(default_root)
        @info "Creating default results directory" path=default_root
        mkpath(default_root)
    end

    return abspath(default_root)
end

"""
    create_experiment_dir(config::Dict{String, Any}; experiment_id::String="") -> String

Create organized experiment directory and save config.

# Arguments
- `config`: Dict with experiment configuration (must contain "objective_name")
- `experiment_id`: Optional custom ID (default: "exp")

# Returns
- Absolute path to created experiment directory

# Example
```julia
config = Dict(
    "objective_name" => "lotka_volterra_4d",
    "GN" => 16,
    "degree_range" => [4, 18]
)

exp_dir = create_experiment_dir(config)
# Returns: /path/to/globtim_results/lotka_volterra_4d/exp_20251016_161234/

# Now save results:
open(joinpath(exp_dir, "results_summary.json"), "w") do io
    JSON3.write(io, results)
end
```
"""
function create_experiment_dir(
    config::Dict;
    experiment_id::String = "exp"
)::String
    # 1. Get results root
    results_root = get_results_root()

    # 2. Extract objective name
    objective_name = if haskey(config, "objective_name")
        config["objective_name"]
    elseif haskey(config, "template")
        config["template"]
    else
        error("Config must contain 'objective_name' or 'template' field")
    end

    # Validate objective name (alphanumeric, underscores, hyphens only)
    if !occursin(r"^[a-zA-Z0-9_-]+$", objective_name)
        error("Invalid objective_name: '$objective_name' (use only alphanumeric, _, -)")
    end

    # 3. Create objective directory
    objective_dir = joinpath(results_root, objective_name)
    if !isdir(objective_dir)
        @info "Creating objective directory" path=objective_dir
        mkpath(objective_dir)
    end

    # 4. Create experiment directory with timestamp
    # Ensure unique timestamp (wait if needed)
    exp_dir = ""
    for attempt in 1:10
        timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
        exp_name = "$(experiment_id)_$(timestamp)"
        exp_dir = joinpath(objective_dir, exp_name)

        if !isdir(exp_dir)
            break
        end

        # Wait 1 second for unique timestamp
        if attempt < 10
            sleep(1)
        else
            error("Could not create unique experiment directory after 10 attempts")
        end
    end

    mkpath(exp_dir)
    @info "Created experiment directory" path=exp_dir

    # 5. Save config file
    config_path = joinpath(exp_dir, "experiment_config.json")
    open(config_path, "w") do io
        JSON3.pretty(io, config)
    end

    return abspath(exp_dir)
end

end # module
