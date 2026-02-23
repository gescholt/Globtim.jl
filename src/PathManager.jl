"""
PathManager.jl - Unified Path Management for Globtim

Consolidates functionality from 5 overlapping modules into a single, cohesive API:
- PathUtils.jl (project navigation)
- OutputPathManager.jl (output enforcement)
- ExperimentPaths.jl (hierarchical structure)
- ExperimentPathTracker.jl (experiment tracking)
- ExperimentOutputOrganizer.jl (batch management)

Design Principles:
1. Single source of truth for all path operations
2. Consistent variable naming (project_root, results_root, experiment_dir, objective_name)
3. HPC-aware with environment variable overrides
4. Strict validation, fail fast on misconfiguration
5. Security-first (prevent directory traversal)

Created: 2025-10-22
"""
module PathManager

using Dates
using JSON

export PathConfig,
    get_project_root, get_results_root, get_src_dir, get_examples_dir,
    create_experiment_dir, get_experiment_path,
    validate_project_structure, validate_results_root,
    is_valid_objective_name, sanitize_objective_name,
    detect_environment, is_hpc_environment,
    ensure_directory, with_project_root,
    register_experiment, update_experiment_progress, finalize_experiment,
    reset_config!  # For testing

# =============================================================================
# Configuration
# =============================================================================

"""
    PathConfig

Configuration structure for path management.

# Fields
- `project_root::String`: Absolute path to project root (contains Project.toml)
- `results_root::String`: Absolute path to results directory
- `environment::Symbol`: Environment type (`:hpc` or `:local`)

# Constructor
```julia
# Auto-detect (recommended)
config = PathConfig()

# Explicit configuration
config = PathConfig(
    project_root="/path/to/globtim",
    results_root="/path/to/results",
    environment=:local
)
```
"""
struct PathConfig
    project_root::String
    results_root::String
    environment::Symbol  # :hpc or :local

    function PathConfig(;
        project_root::Union{String,Nothing}=nothing,
        results_root::Union{String,Nothing}=nothing,
        environment::Union{Symbol,Nothing}=nothing
    )
        # Determine project root
        proj_root = if isnothing(project_root)
            _find_project_root()
        else
            abspath(project_root)
        end

        # Determine results root
        res_root = if isnothing(results_root)
            _find_results_root()
        else
            abspath(results_root)
        end

        # Determine environment
        env = if isnothing(environment)
            detect_environment()
        else
            environment in (:hpc, :local) || error("Invalid environment: $environment (must be :hpc or :local)")
            environment
        end

        new(proj_root, res_root, env)
    end
end

# Global configuration instance
const _CONFIG = Ref{Union{PathConfig,Nothing}}(nothing)

"""
    _get_config() -> PathConfig

Get or initialize global PathConfig.
"""
function _get_config()::PathConfig
    if isnothing(_CONFIG[])
        _CONFIG[] = PathConfig()
    end
    return _CONFIG[]
end

"""
    set_config!(config::PathConfig)

Override global PathConfig (mainly for testing).
"""
function set_config!(config::PathConfig)
    _CONFIG[] = config
end

"""
    reset_config!()

Reset global PathConfig to force re-initialization (mainly for testing).
"""
function reset_config!()
    _CONFIG[] = nothing
end

# =============================================================================
# Project Navigation
# =============================================================================

"""
    get_project_root() -> String

Get absolute path to project root (directory containing Project.toml).

Walks up from current source file location until finding Project.toml.
Can be overridden by setting `GLOBTIM_ROOT` environment variable.

# Returns
- Absolute path to project root

# Throws
- `ErrorException` if Project.toml cannot be found

# Example
```julia
root = get_project_root()  # e.g. "/path/to/globtim"
```

# Environment Variables
- `GLOBTIM_ROOT`: Override automatic detection (useful for HPC)
"""
function get_project_root()::String
    return _get_config().project_root
end

"""
    _find_project_root() -> String

Internal: Find project root by walking up directory tree.
"""
function _find_project_root()::String
    # Check environment variable override
    if haskey(ENV, "GLOBTIM_ROOT")
        root = ENV["GLOBTIM_ROOT"]
        if isdir(root) && isfile(joinpath(root, "Project.toml"))
            return abspath(root)
        else
            @warn "GLOBTIM_ROOT is set but invalid: $root (falling back to search)"
        end
    end

    # Walk up from current file location
    current = dirname(@__FILE__)  # Start from src/ directory
    max_iterations = 20
    iteration = 0

    while iteration < max_iterations
        # Check if Project.toml exists here
        if isfile(joinpath(current, "Project.toml"))
            return abspath(current)
        end

        # Move up one directory
        parent = dirname(current)

        # Check if we've reached filesystem root
        if parent == current
            error("""
                Could not find project root (no Project.toml found).
                Searched up to: $current

                Hint: Make sure you are running from within the Globtim project directory.
                Alternatively, set GLOBTIM_ROOT environment variable to the project root.
                """)
        end

        current = parent
        iteration += 1
    end

    error("Could not find project root after $max_iterations iterations (possible symlink loop?)")
end

"""
    get_results_root() -> String

Get absolute path to results directory root.

Determines where experiment results should be stored using precedence:
1. `GLOBTIM_RESULTS_ROOT` environment variable (if set and valid)
2. `joinpath(pwd(), "globtim_results")` (default fallback)

Directory is created if it doesn't exist. Write permissions are validated.

# Returns
- Absolute path to results root directory

# Throws
- `ErrorException` if results root cannot be determined or is not writable

# Example
```julia
results_root = get_results_root()  # e.g. "/path/to/globtim_results"
batch_dir = joinpath(results_root, "lotka_volterra_4d")
```

# Environment Variables
- `GLOBTIM_RESULTS_ROOT`: Override default results location
"""
function get_results_root()::String
    return _get_config().results_root
end

"""
    _find_results_root() -> String

Internal: Find results root with environment variable override.
"""
function _find_results_root()::String
    # Check for GLOBTIM_RESULTS_ROOT environment variable
    if haskey(ENV, "GLOBTIM_RESULTS_ROOT")
        results_root = ENV["GLOBTIM_RESULTS_ROOT"]
        results_root = abspath(results_root)

        # Create if doesn't exist
        if !isdir(results_root)
            try
                mkpath(results_root)
                @info "Created results root directory: $results_root"
            catch e
                error("""
                    GLOBTIM_RESULTS_ROOT is set but cannot be created: $results_root
                    Error: $e

                    Please check permissions or set GLOBTIM_RESULTS_ROOT to a valid path.
                    """)
            end
        end

        # Validate write permissions
        if !_is_writable(results_root)
            error("""
                GLOBTIM_RESULTS_ROOT exists but is not writable: $results_root

                Please check permissions or set GLOBTIM_RESULTS_ROOT to a writable directory.
                """)
        end

        return results_root
    end

    # Default: use globtim_results under current working directory
    results_root = abspath(joinpath(pwd(), "globtim_results"))

    # Create if doesn't exist
    if !isdir(results_root)
        try
            mkpath(results_root)
            @info "Created default results directory: $results_root (set GLOBTIM_RESULTS_ROOT to override)"
        catch e
            error("""
                Cannot create default results directory: $results_root
                Error: $e

                Please set GLOBTIM_RESULTS_ROOT environment variable to a writable location.
                """)
        end
    end

    # Validate write permissions
    if !_is_writable(results_root)
        error("""
            Default results directory exists but is not writable: $results_root

            Please set GLOBTIM_RESULTS_ROOT to a writable directory.
            """)
    end

    return results_root
end

"""
    get_src_dir() -> String

Get absolute path to src/ directory within the project.

# Returns
- Absolute path to src/ directory

# Example
```julia
src = get_src_dir()  # e.g. "/path/to/globtim/src"
```
"""
function get_src_dir()::String
    return joinpath(get_project_root(), "src")
end

"""
    get_examples_dir() -> String

Get absolute path to Examples/ directory within the project.

# Returns
- Absolute path to Examples/ directory

# Example
```julia
examples = get_examples_dir()  # e.g. "/path/to/globtim/Examples"
```
"""
function get_examples_dir()::String
    return joinpath(get_project_root(), "Examples")
end

# =============================================================================
# Experiment Path Creation
# =============================================================================

"""
    create_experiment_dir(objective_name::String, experiment_id::String=""; timestamp::DateTime=now()) -> String

Create and return experiment directory with hierarchical structure.

Structure: `\$GLOBTIM_RESULTS_ROOT/objective_name/experiment_id_YYYYMMDD_HHMMSS/`

If `experiment_id` is not provided, auto-generates as `exp_YYYYMMDD_HHMMSS`.

# Arguments
- `objective_name::String`: Objective function name (must be valid)
- `experiment_id::String`: Experiment identifier (optional, auto-generated if empty)
- `timestamp::DateTime`: Timestamp for directory name (default: current time)

# Returns
- Absolute path to created experiment directory

# Throws
- `ErrorException` if objective_name is invalid
- `ErrorException` if directory already exists
- `ErrorException` if directory creation fails

# Example
```julia
# Auto-generated ID
path = create_experiment_dir("lotka_volterra_4d")
# Returns: "/path/to/results/lotka_volterra_4d/exp_20251022_143022/"

# Custom ID
path = create_experiment_dir("lotka_volterra_4d", "recovery_exp_12")
# Returns: "/path/to/results/lotka_volterra_4d/recovery_exp_12_20251022_143022/"
```
"""
function create_experiment_dir(
    objective_name::String,
    experiment_id::String="";
    timestamp::DateTime=now()
)::String
    # Validate objective name
    if !is_valid_objective_name(objective_name)
        error("""
            Invalid objective_name: '$objective_name'

            Objective names must be:
            - Non-empty
            - Alphanumeric with underscores/hyphens only
            - No directory traversal (../, /)

            Example valid names: lotka_volterra_4d, rastrigin-10d, sphere_function
            """)
    end

    # Generate experiment_id if not provided
    if isempty(experiment_id)
        experiment_id = _generate_experiment_id(timestamp)
    else
        # Validate experiment_id
        if !_is_valid_experiment_id(experiment_id)
            error("""
                Invalid experiment_id: '$experiment_id'

                Experiment IDs must be:
                - Non-empty
                - Alphanumeric with underscores/hyphens only
                - No directory traversal
                """)
        end
    end

    # Build path
    path = get_experiment_path(objective_name, experiment_id; timestamp=timestamp)

    # Check if already exists
    if isdir(path)
        error("""
            Experiment directory already exists: '$path'

            This likely means:
            - The same experiment was run twice in the same second
            - You need to use a unique experiment_id

            Please use a different experiment_id or wait a second.
            """)
    end

    # Create directory
    try
        mkpath(path)
    catch e
        error("Failed to create experiment directory '$path': $e")
    end

    # Validate writable
    if !_is_writable(path)
        error("Experiment directory is not writable: '$path'")
    end

    @info "Created experiment directory" path=path objective=objective_name experiment_id=experiment_id

    return abspath(path)
end

"""
    get_experiment_path(objective_name::String, experiment_id::String; timestamp::DateTime=now()) -> String

Get experiment path WITHOUT creating it.

Useful for querying or checking if experiment exists before creation.

# Arguments
- `objective_name::String`: Objective function name
- `experiment_id::String`: Experiment identifier
- `timestamp::DateTime`: Timestamp for path (default: current time)

# Returns
- Absolute path (may not exist yet)

# Example
```julia
path = get_experiment_path("lotka_volterra_4d", "exp_test", timestamp=DateTime(2025, 10, 22, 14, 30))
# Returns path string without creating directory
```
"""
function get_experiment_path(
    objective_name::String,
    experiment_id::String;
    timestamp::DateTime=now()
)::String
    results_root = get_results_root()

    # Build hierarchical path
    timestamp_str = Dates.format(timestamp, "yyyymmdd_HHMMSS")
    dir_name = "$(experiment_id)_$(timestamp_str)"

    experiment_path = joinpath(
        results_root,
        objective_name,
        dir_name
    )

    return abspath(experiment_path)
end

"""
    _generate_experiment_id(timestamp::DateTime=now()) -> String

Internal: Generate unique experiment ID based on timestamp.
"""
function _generate_experiment_id(timestamp::DateTime=now())::String
    timestamp_str = Dates.format(timestamp, "yyyymmdd_HHMMSS")
    return "exp_$(timestamp_str)"
end

# =============================================================================
# Name Validation and Sanitization
# =============================================================================

"""
    is_valid_objective_name(name::String) -> Bool

Validate objective function name for use in paths.

Valid names must be:
- Non-empty
- Alphanumeric with underscores/hyphens only
- No directory traversal (../, /)

# Example
```julia
is_valid_objective_name("lotka_volterra_4d")  # true
is_valid_objective_name("has spaces")          # false
is_valid_objective_name("../../../etc")        # false
```
"""
function is_valid_objective_name(name::String)::Bool
    # Must be non-empty
    isempty(name) && return false

    # Check for directory traversal
    (contains(name, "..") || startswith(name, "/") || contains(name, "\\")) && return false

    # Must be alphanumeric with underscores/hyphens only
    return occursin(r"^[a-zA-Z0-9_-]+$", name)
end

"""
    _is_valid_experiment_id(id::String) -> Bool

Internal: Validate experiment ID for use in paths.
"""
function _is_valid_experiment_id(id::String)::Bool
    # Same validation as objective name
    return is_valid_objective_name(id)
end

"""
    sanitize_objective_name(name::String) -> String

Sanitize a name for safe use in filesystem paths.

Converts to lowercase, replaces special characters with underscores,
trims leading/trailing underscores, and collapses multiple underscores.

# Arguments
- `name::String`: Name to sanitize

# Returns
- Sanitized name safe for filesystem use

# Example
```julia
sanitize_objective_name("My Function 4D")  # "my_function_4d"
sanitize_objective_name("Extended Brusselator!")  # "extended_brusselator_"
sanitize_objective_name("  UPPERCASE  ")  # "uppercase"
```
"""
function sanitize_objective_name(name::String)::String
    # Convert to lowercase
    name_lower = lowercase(name)

    # Replace non-alphanumeric characters (except underscores) with underscores
    name_sanitized = replace(name_lower, r"[^a-z0-9_]" => "_")

    # Remove leading/trailing underscores
    name_sanitized = strip(name_sanitized, '_')

    # Collapse multiple consecutive underscores into single underscore
    name_sanitized = replace(name_sanitized, r"_+" => "_")

    return name_sanitized
end

# =============================================================================
# Validation Functions
# =============================================================================

"""
    validate_project_structure(project_root::String=get_project_root(); strict::Bool=false) -> Bool

Validate that project directory has required files and structure.

# Arguments
- `project_root::String`: Path to project root directory (default: auto-detect)
- `strict::Bool`: If true, treat warnings as errors (default: false)

# Returns
- `true` if validation passes

# Throws
- `ErrorException` if critical files are missing or path is invalid
"""
function validate_project_structure(
    project_root::String=get_project_root();
    strict::Bool=false
)::Bool
    # Check directory exists
    if !isdir(project_root)
        error("Project root does not exist: $project_root")
    end

    # Critical files (must exist)
    critical_files = [
        "Project.toml",
        "src",
        "Examples"
    ]

    # Important files (should exist, but not critical)
    important_files = [
        "Manifest.toml",
        "Examples/systems/",
        "test"
    ]

    errors = String[]
    warnings = String[]

    # Check critical files
    for file in critical_files
        path = joinpath(project_root, file)
        if !ispath(path)
            push!(errors, "Missing critical file/directory: $file")
        end
    end

    # Check important files
    for file in important_files
        path = joinpath(project_root, file)
        if !ispath(path)
            push!(warnings, "Missing recommended file/directory: $file")
        end
    end

    # Report errors
    if !isempty(errors)
        error_msg = """
            Project structure validation failed for: $project_root

            Critical issues:
            $(join("  - " .* errors, "\n"))
            """
        error(error_msg)
    end

    # Report warnings
    if !isempty(warnings)
        @warn """
            Project structure validation found issues:
            $(join("  - " .* warnings, "\n"))
            """

        if strict
            error("Validation failed in strict mode due to warnings")
        end
    end

    return true
end

"""
    validate_results_root(results_root::String=get_results_root()) -> Bool

Validate that results root directory is properly configured and writable.

# Arguments
- `results_root::String`: Path to results root (default: auto-detect)

# Returns
- `true` if validation passes

# Throws
- `ErrorException` if results root doesn't exist or is not writable
"""
function validate_results_root(results_root::String=get_results_root())::Bool
    if !isdir(results_root)
        error("Results root does not exist: $results_root")
    end

    if !_is_writable(results_root)
        error("Results root is not writable: $results_root")
    end

    return true
end

# =============================================================================
# Environment Detection
# =============================================================================

"""
    detect_environment() -> Symbol

Detect whether we're running on HPC or local machine.

Checks for:
- SLURM environment variables (SLURM_JOB_ID, SLURM_CLUSTER_NAME)
- Hostname patterns (r\\d+n\\d+, gpu\\d+, login\\d+, compute\\d+)

# Returns
- `:hpc` if running on HPC cluster
- `:local` if running on local machine

# Example
```julia
env = detect_environment()
if env == :hpc
    println("Running on HPC")
else
    println("Running locally")
end
```
"""
function detect_environment()::Symbol
    # Check for SLURM (most common HPC scheduler)
    if haskey(ENV, "SLURM_JOB_ID") || haskey(ENV, "SLURM_CLUSTER_NAME")
        return :hpc
    end

    # Check hostname patterns
    hostname = gethostname()
    if occursin(r"^(r\d+n\d+|gpu\d+|login\d+|compute\d+)", hostname)
        return :hpc
    end

    # Default to local
    return :local
end

"""
    is_hpc_environment() -> Bool

Check if currently running on HPC cluster.

# Returns
- `true` if on HPC, `false` if local

# Example
```julia
if is_hpc_environment()
    @info "Detected HPC environment, using specialized configuration"
end
```
"""
function is_hpc_environment()::Bool
    return detect_environment() == :hpc
end

# =============================================================================
# Directory Management
# =============================================================================

"""
    ensure_directory(path::String) -> String

Ensure directory exists, creating it if necessary.

# Arguments
- `path::String`: Path to directory (relative or absolute)

# Returns
- Absolute path to directory (guaranteed to exist)

# Example
```julia
dir = ensure_directory("results/experiments/test")
# Creates nested directories if needed, returns absolute path
```
"""
function ensure_directory(path::String)::String
    abs_path = abspath(path)

    if !isdir(abs_path)
        mkpath(abs_path)
    end

    return abs_path
end

"""
    with_project_root(f::Function) -> Any

Execute function with project root as current directory, then restore.

# Arguments
- `f::Function`: Function to execute (takes no arguments)

# Returns
- Result of function f

# Example
```julia
result = with_project_root() do
    # This runs with CWD = project root
    run(`julia --project=. test/runtests.jl`)
end
```
"""
function with_project_root(f::Function)
    original_dir = pwd()
    root = get_project_root()

    try
        cd(root)
        return f()
    finally
        cd(original_dir)
    end
end

# =============================================================================
# Experiment Tracking
# =============================================================================

"""
    register_experiment(output_dir::String, metadata::Dict{String, Any}) -> String

Register an experiment session at startup by creating .session_info.json file.

This establishes the session-directory linkage required for tracking.

# Arguments
- `output_dir::String`: Full path to experiment output directory
- `metadata::Dict{String, Any}`: Experiment parameters and configuration

# Returns
- Path to created `.session_info.json` file

# Example
```julia
exp_path = create_experiment_dir("lotka_volterra_4d")
metadata = Dict("GN" => 8, "degree_range" => [4, 12])
session_file = register_experiment(exp_path, metadata)
```
"""
function register_experiment(
    output_dir::String,
    metadata::Dict{String, Any}
)::String
    session_file = joinpath(output_dir, ".session_info.json")

    # Create session info with initial progress state
    data = Dict{String, Any}(
        "output_dir" => output_dir,
        "started_at" => now(),
        "status" => "running",
        "host" => gethostname(),
        "parameters" => metadata,
        "progress" => Dict{String, Any}(
            "percent_complete" => 0.0,
            "current_step" => 0,
            "total_steps" => 0,
            "last_heartbeat" => now()
        )
    )

    # Write to file
    open(session_file, "w") do io
        JSON.print(io, data, 2)
    end

    @info "Experiment session registered" session_file=session_file

    return session_file
end

"""
    update_experiment_progress(output_dir::String, completed::Int, total::Int; current_step_name::String="")

Update experiment progress by writing to .session_info.json heartbeat file.

Allows real-time monitoring of running experiments.

# Arguments
- `output_dir::String`: Full path to experiment output directory
- `completed::Int`: Number of completed steps
- `total::Int`: Total number of steps
- `current_step_name::String`: (Optional) Name of current step being executed

# Example
```julia
for (i, degree) in enumerate(degrees)
    # ... do computation ...
    update_experiment_progress(output_dir, i, length(degrees),
                               current_step_name="degree_\$degree")
end
```
"""
function update_experiment_progress(
    output_dir::String,
    completed::Int,
    total::Int;
    current_step_name::String=""
)
    session_file = joinpath(output_dir, ".session_info.json")

    if !isfile(session_file)
        @warn "Session info file not found, creating minimal version" session_file
        # Create minimal session info if missing
        data = Dict{String, Any}(
            "output_dir" => output_dir,
            "started_at" => now(),
            "status" => "running",
            "progress" => Dict{String, Any}()
        )
    else
        # Read existing data
        data = JSON.parsefile(session_file)
    end

    # Update progress
    data["progress"] = Dict{String, Any}(
        "percent_complete" => total > 0 ? round(100 * completed / total, digits=1) : 0.0,
        "current_step" => completed,
        "total_steps" => total,
        "last_heartbeat" => now()
    )

    if !isempty(current_step_name)
        data["progress"]["current_step_name"] = current_step_name
    end

    # Write back atomically
    open(session_file, "w") do io
        JSON.print(io, data, 2)
    end
end

"""
    finalize_experiment(output_dir::String, success::Bool, message::String="")

Mark experiment as completed or failed in .session_info.json.

Call this at the end of your experiment to record final status.

# Arguments
- `output_dir::String`: Full path to experiment output directory
- `success::Bool`: Whether experiment succeeded
- `message::String`: (Optional) Completion or error message

# Example
```julia
try
    # ... run experiment ...
    finalize_experiment(exp_path, true, "Completed successfully")
catch e
    finalize_experiment(exp_path, false, "Error: \$e")
    rethrow()
end
```
"""
function finalize_experiment(
    output_dir::String,
    success::Bool,
    message::String=""
)
    session_file = joinpath(output_dir, ".session_info.json")

    if !isfile(session_file)
        @warn "Cannot finalize - session info file not found" session_file
        return
    end

    # Read existing data
    data = JSON.parsefile(session_file)

    # Update status
    data["status"] = success ? "completed" : "failed"
    data["completed_at"] = now()

    if !isempty(message)
        data["completion_message"] = message
    end

    # Write back
    open(session_file, "w") do io
        JSON.print(io, data, 2)
    end

    @info "Experiment finalized" status=data["status"] output_dir=output_dir
end

# =============================================================================
# Internal Utilities
# =============================================================================

"""
    _is_writable(path::String) -> Bool

Internal: Test if directory is writable.
"""
function _is_writable(path::String)::Bool
    test_file = joinpath(path, ".write_test_$(rand(UInt32))")
    try
        touch(test_file)
        rm(test_file)
        return true
    catch e
        @debug "Directory not writable" path exception=(e, catch_backtrace())
        return false
    end
end

end # module PathManager
