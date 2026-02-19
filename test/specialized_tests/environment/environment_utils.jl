"""
Environment-Aware Utility Functions for Cross-Environment Path Resolution

Provides robust environment detection and path translation capabilities
for cross-environment deployment between local development and HPC environments.

# Required Environment Variables

Configure the following ENV variables for your environment:

- `GLOBTIM_LOCAL_HOME`     — Local home directory (e.g. "/Users/yourname")
- `GLOBTIM_LOCAL_PROJECT`  — Local project directory (e.g. "/Users/yourname/globtim")
- `GLOBTIM_HPC_USER`       — HPC username
- `GLOBTIM_HPC_HOST`       — HPC hostname
- `GLOBTIM_HPC_HOME`       — HPC home directory (e.g. "/home/youruser")
- `GLOBTIM_HPC_PROJECT`    — HPC project directory (e.g. "/home/youruser/globtim")
- `GLOBTIM_HPC_NFS_HOME`   — HPC NFS home directory (e.g. "/stornext/snfs3/home/youruser")

Date: September 2025
Issue: #40 - Environment-Aware Path Resolution System for HPC Deployments
"""

# NOTE: These tests require specific HPC environment configuration. See ENV vars above.

module EnvironmentUtils

export detect_environment, auto_detect_environment, translate_path,
    get_project_directory, resolve_cross_environment_path, resolve_hook_path,
    generate_ssh_command, generate_scp_command, generate_experiment_collection_command,
    resolve_hook_config

using JSON

# ---------------------------------------------------------------------------
# ENV helpers — error if not set
# ---------------------------------------------------------------------------

function _require_env(key::String)::String
    val = get(ENV, key, "")
    if isempty(val)
        error("Required environment variable '$key' is not set. " *
              "See environment_utils.jl header for configuration instructions.")
    end
    return val
end

function _get_env(key::String, default::String="")::String
    return get(ENV, key, default)
end

# Convenience accessors
_local_home()       = _require_env("GLOBTIM_LOCAL_HOME")
_local_project()    = _require_env("GLOBTIM_LOCAL_PROJECT")
_hpc_user()         = _require_env("GLOBTIM_HPC_USER")
_hpc_host()         = _require_env("GLOBTIM_HPC_HOST")
_hpc_home()         = _require_env("GLOBTIM_HPC_HOME")
_hpc_project()      = _require_env("GLOBTIM_HPC_PROJECT")
_hpc_nfs_home()     = _require_env("GLOBTIM_HPC_NFS_HOME")

"""
    detect_environment(base_path::String) -> Symbol

Detect environment type based on filesystem path patterns.

Returns:
- `:local` - Local development environment
- `:hpc` - HPC cluster environment
- `:hpc_nfs` - HPC with NFS storage
- `:unknown` - Unrecognized environment
"""
function detect_environment(base_path::String)::Symbol
    if isempty(base_path) || !isabspath(base_path)
        return :unknown
    end

    hpc_home = _hpc_home()
    hpc_project = _hpc_project()

    # HPC environment patterns
    if startswith(base_path, hpc_project) ||
       startswith(base_path, hpc_home)
        return :hpc
    end

    # HPC NFS storage patterns
    hpc_nfs_home = _hpc_nfs_home()
    if startswith(base_path, hpc_nfs_home)
        return :hpc_nfs
    end

    # Local patterns
    local_project = _local_project()
    local_home = _local_home()
    if startswith(base_path, local_project) ||
       startswith(base_path, local_home)
        return :local
    end

    return :unknown
end

"""
    auto_detect_environment() -> Symbol

Auto-detect current environment by checking for characteristic directories.
"""
function auto_detect_environment()::Symbol
    # Check for HPC directories
    hpc_project = _hpc_project()
    hpc_home = _hpc_home()

    for path in [hpc_project, hpc_home]
        if isdir(path)
            return :hpc
        end
    end

    # Check for NFS storage
    hpc_nfs_home = _hpc_nfs_home()
    if isdir(hpc_nfs_home)
        return :hpc_nfs
    end

    # Check for local
    local_project = _local_project()
    local_home = _local_home()
    for path in [local_project, local_home]
        if isdir(path)
            return :local
        end
    end

    return :unknown
end

"""
    translate_path(path::String, from_env::Symbol, to_env::Symbol) -> String

Translate filesystem paths between environments.

# Arguments
- `path`: The path to translate
- `from_env`: Source environment (`:local`, `:hpc`, `:hpc_nfs`)
- `to_env`: Target environment (`:local`, `:hpc`, `:hpc_nfs`)

# Returns
Translated path string, or original path if translation not applicable.
"""
function translate_path(path::String, from_env::Symbol, to_env::Symbol)::String
    # Handle edge cases
    if isempty(path) || from_env == to_env
        return path
    end

    # Only translate absolute paths that match known patterns
    if !isabspath(path)
        return path
    end

    local_home = _local_home()
    local_project = _local_project()
    hpc_home = _hpc_home()
    hpc_project = _hpc_project()
    hpc_nfs_home = _hpc_nfs_home()

    # Define translation mappings
    local_to_hpc_mappings = [
        (local_project, hpc_project),
        ("$(local_home)/.julia", "$(hpc_home)/.julia"),
        (local_home, hpc_home)
    ]

    hpc_to_local_mappings = [
        (hpc_project, local_project),
        ("$(hpc_home)/.julia", "$(local_home)/.julia"),
        (hpc_home, local_home)
    ]

    # Apply appropriate translation
    if from_env == :local && to_env == :hpc
        for (local_prefix, hpc_prefix) in local_to_hpc_mappings
            if startswith(path, local_prefix)
                return replace(path, local_prefix => hpc_prefix, count = 1)
            end
        end
    elseif from_env == :hpc && to_env == :local
        for (hpc_prefix, local_prefix) in hpc_to_local_mappings
            if startswith(path, hpc_prefix)
                return replace(path, hpc_prefix => local_prefix, count = 1)
            end
        end
    elseif from_env == :hpc_nfs
        # First translate NFS to regular HPC, then to target
        nfs_to_hpc = replace(path, hpc_nfs_home => hpc_home)
        if nfs_to_hpc != path
            return translate_path(nfs_to_hpc, :hpc, to_env)
        end
    elseif to_env == :hpc_nfs
        # First translate to regular HPC, then to NFS
        hpc_path = translate_path(path, from_env, :hpc)
        if startswith(hpc_path, hpc_home)
            return replace(
                hpc_path,
                hpc_home => hpc_nfs_home,
                count = 1
            )
        end
    end

    # No translation applied - return original path
    return path
end

"""
    get_project_directory(env::Symbol) -> String

Get the project directory path for the specified environment.
"""
function get_project_directory(env::Symbol)::String
    if env == :local
        return _local_project()
    elseif env == :hpc
        return _hpc_project()
    elseif env == :hpc_nfs
        return joinpath(_hpc_nfs_home(), basename(_hpc_project()))
    else
        return ""
    end
end

"""
    resolve_cross_environment_path(relative_path::String, from_env::Symbol, to_env::Symbol) -> String

Resolve a relative path to absolute path in target environment.
"""
function resolve_cross_environment_path(
    relative_path::String,
    from_env::Symbol,
    to_env::Symbol
)::String
    if isabspath(relative_path)
        return translate_path(relative_path, from_env, to_env)
    end

    # Build absolute path in target environment
    target_project_dir = get_project_directory(to_env)
    if isempty(target_project_dir)
        return relative_path
    end

    return joinpath(target_project_dir, relative_path)
end

"""
    resolve_hook_path(hook_path::String, from_env::Symbol, to_env::Symbol) -> String

Resolve hook path for cross-environment execution.
"""
function resolve_hook_path(hook_path::String, from_env::Symbol, to_env::Symbol)::String
    if isabspath(hook_path)
        return translate_path(hook_path, from_env, to_env)
    else
        # Relative path - resolve against project directory
        return resolve_cross_environment_path(hook_path, from_env, to_env)
    end
end

"""
    generate_ssh_command(command_type::String; kwargs...) -> Dict{String,String}

Generate SSH commands for common operations.
"""
function generate_ssh_command(command_type::String; kwargs...)::Dict{String, String}
    project_dir = get(kwargs, :project_dir, _hpc_project())
    user = _hpc_user()
    host = _hpc_host()

    if command_type == "list_experiments"
        pattern = get(kwargs, :pattern, "lotka_volterra_4d_exp*")
        command = "cd $project_dir && ls -1d hpc_results/$pattern | sort"
        full_command = "ssh $(user)@$(host) \"$command\""

        return Dict(
            "command" => command,
            "full_command" => full_command,
            "project_dir" => project_dir,
            "pattern" => pattern
        )
    elseif command_type == "check_status"
        session_name = get(kwargs, :session_name, "experiment")
        command = "tmux list-sessions | grep $session_name"
        full_command = "ssh $(user)@$(host) \"$command\""

        return Dict(
            "command" => command,
            "full_command" => full_command,
            "session_name" => session_name
        )
    else
        error("Unknown command type: $command_type")
    end
end

"""
    generate_scp_command(source::String, destination::String) -> String

Generate SCP command for file transfer.
"""
function generate_scp_command(source::String, destination::String)::String
    return "scp $source $destination"
end

"""
    generate_experiment_collection_command(from_env::Symbol, to_env::Symbol, date_pattern::String) -> String

Generate SSH command for collecting experiment results.
"""
function generate_experiment_collection_command(
    from_env::Symbol,
    to_env::Symbol,
    date_pattern::String
)::String
    if to_env != :hpc
        error("Currently only supports collecting FROM HPC environment")
    end

    project_dir = get_project_directory(to_env)
    pattern = "lotka_volterra_4d_exp*_$date_pattern*"

    ssh_info = generate_ssh_command("list_experiments",
        project_dir = project_dir,
        pattern = pattern)

    return ssh_info["full_command"]
end

"""
    resolve_hook_config(config::Dict, from_env::Symbol, to_env::Symbol) -> Dict

Resolve hook configuration with environment-aware path translation.
"""
function resolve_hook_config(config::Dict, from_env::Symbol, to_env::Symbol)::Dict
    resolved_config = Dict{String, Any}()

    # Copy all original config entries
    for (key, value) in config
        resolved_config[string(key)] = value
    end

    if haskey(config, "path")
        resolved_path = resolve_hook_path(string(config["path"]), from_env, to_env)
        resolved_config["resolved_path"] = resolved_path
        resolved_config["original_path"] = string(config["path"])
        resolved_config["translation"] = Dict{String, Any}(
            "from_env" => string(from_env),
            "to_env" => string(to_env),
            "translated" => resolved_path != string(config["path"])
        )
    end

    return resolved_config
end

end # module EnvironmentUtils
