"""
HPC File Sync Module (Issue #136 Phase 3)

Handles file synchronization to HPC cluster using rsync.

Author: GlobTim Project
Date: October 5, 2025
"""

module HPCSync

export SyncConfig, SyncResult, SyncPlan, SyncProgress, ValidationResult,
       generate_rsync_command, sync_to_hpc, build_sync_plan, get_sync_commands,
       validate_sync_config, get_remote_config_path, estimate_transfer_size,
       progress_percentage

"""
    SyncConfig

Configuration for HPC file synchronization.

# Fields
- `local_config_dir::String`: Local configuration directory path
- `local_scripts_dir::String`: Local scripts directory path
- `remote_host::String`: Remote host in format "user@hostname"
- `remote_base_dir::String`: Remote base directory path
- `dry_run::Bool`: If true, only generate commands without executing
"""
struct SyncConfig
    local_config_dir::String
    local_scripts_dir::String
    remote_host::String
    remote_base_dir::String
    dry_run::Bool

    # Constructor with keyword arguments
    function SyncConfig(;
        local_config_dir::String,
        local_scripts_dir::String,
        remote_host::String,
        remote_base_dir::String,
        dry_run::Bool = false
    )
        new(local_config_dir, local_scripts_dir, remote_host, remote_base_dir, dry_run)
    end
end

"""
    SyncResult

Result of a sync operation.

# Fields
- `success::Bool`: Whether sync succeeded
- `dry_run::Bool`: Whether this was a dry run
- `commands_generated::Int`: Number of commands generated
- `files_transferred::Int`: Number of files transferred (0 for dry run)
- `operations::Vector{Dict{Symbol,Any}}`: List of sync operations performed
"""
struct SyncResult
    success::Bool
    dry_run::Bool
    commands_generated::Int
    files_transferred::Int
    operations::Vector{Dict{Symbol,Any}}

    function SyncResult(;
        success::Bool,
        dry_run::Bool,
        commands_generated::Int,
        files_transferred::Int,
        operations::Vector{Dict{Symbol,Any}} = Dict{Symbol,Any}[]
    )
        new(success, dry_run, commands_generated, files_transferred, operations)
    end
end

"""
    SyncPlan

Plan of sync operations to execute.

# Fields
- `operations::Vector{Dict{Symbol,Any}}`: List of planned sync operations
"""
struct SyncPlan
    operations::Vector{Dict{Symbol,Any}}
end

"""
    SyncProgress

Progress tracking for file synchronization.

# Fields
- `current_file::String`: Currently transferring file
- `files_completed::Int`: Number of files completed
- `total_files::Int`: Total number of files
- `bytes_transferred::Int`: Bytes transferred so far
- `total_bytes::Int`: Total bytes to transfer
"""
struct SyncProgress
    current_file::String
    files_completed::Int
    total_files::Int
    bytes_transferred::Int
    total_bytes::Int

    function SyncProgress(;
        current_file::String,
        files_completed::Int,
        total_files::Int,
        bytes_transferred::Int,
        total_bytes::Int
    )
        new(current_file, files_completed, total_files, bytes_transferred, total_bytes)
    end
end

"""
    ValidationResult

Result of configuration validation.

# Fields
- `valid::Bool`: Whether config is valid
- `errors::Vector{String}`: List of validation errors
"""
struct ValidationResult
    valid::Bool
    errors::Vector{String}
end

"""
    generate_rsync_command(; src, dest, progress=true, delete=false) -> Cmd

Generate an rsync command for file synchronization.

# Arguments
- `src::String`: Source path
- `dest::String`: Destination path (can include remote host)
- `progress::Bool`: Show progress during transfer
- `delete::Bool`: Delete extraneous files from destination

# Returns
- `Cmd`: rsync command ready to execute

# Examples
```julia
cmd = generate_rsync_command(
    src = "/local/configs/",
    dest = "user@host:/remote/experiments/"
)
```
"""
function generate_rsync_command(;
    src::String,
    dest::String,
    progress::Bool = true,
    delete::Bool = false
)::Cmd
    args = ["rsync", "-avz"]

    if progress
        push!(args, "--progress")
    end

    if delete
        push!(args, "--delete")
    end

    push!(args, src)
    push!(args, dest)

    return Cmd(args)
end

"""
    build_sync_plan(config::SyncConfig) -> SyncPlan

Build a plan of sync operations from configuration.

# Arguments
- `config::SyncConfig`: Sync configuration

# Returns
- `SyncPlan`: Planned sync operations

# Examples
```julia
plan = build_sync_plan(config)
println("Will execute \$(length(plan.operations)) operations")
```
"""
function build_sync_plan(config::SyncConfig)::SyncPlan
    operations = Dict{Symbol,Any}[]

    # Operation 1: Sync config directory
    config_basename = basename(rstrip(config.local_config_dir, '/'))
    remote_config_dest = "$(config.remote_host):$(config.remote_base_dir)"

    config_op = Dict{Symbol,Any}(
        :src => config.local_config_dir,
        :dest => remote_config_dest,
        :description => "config directory",
        :command => generate_rsync_command(
            src = config.local_config_dir,
            dest = remote_config_dest
        )
    )
    push!(operations, config_op)

    # Operation 2: Sync scripts directory (if different from config dir)
    if config.local_scripts_dir != config.local_config_dir
        scripts_op = Dict{Symbol,Any}(
            :src => config.local_scripts_dir,
            :dest => remote_config_dest,
            :description => "scripts directory",
            :command => generate_rsync_command(
                src = config.local_scripts_dir,
                dest = remote_config_dest
            )
        )
        push!(operations, scripts_op)
    end

    return SyncPlan(operations)
end

"""
    sync_to_hpc(config::SyncConfig) -> SyncResult

Synchronize files to HPC cluster.

# Arguments
- `config::SyncConfig`: Sync configuration

# Returns
- `SyncResult`: Result of sync operation

# Examples
```julia
config = SyncConfig(
    local_config_dir = "/local/configs/",
    local_scripts_dir = "/local/scripts/",
    remote_host = "user@r04n02",
    remote_base_dir = "/remote/experiments/",
    dry_run = true
)

result = sync_to_hpc(config)
if result.success
    println("Sync complete: \$(result.files_transferred) files transferred")
end
```
"""
function sync_to_hpc(config::SyncConfig)::SyncResult
    # Validate configuration first
    validation = validate_sync_config(config)
    if !validation.valid
        return SyncResult(
            success = false,
            dry_run = config.dry_run,
            commands_generated = 0,
            files_transferred = 0,
            operations = Dict{Symbol,Any}[]
        )
    end

    # Build sync plan
    plan = build_sync_plan(config)

    if config.dry_run
        # Dry run: just return the plan without executing
        return SyncResult(
            success = true,
            dry_run = true,
            commands_generated = length(plan.operations),
            files_transferred = 0,
            operations = plan.operations
        )
    end

    # Execute sync operations
    files_transferred = 0
    for op in plan.operations
        try
            run(op[:command])
            files_transferred += 1  # Simplified - would count actual files in production
        catch e
            @warn "Sync operation failed: $(op[:description])" exception=e
            return SyncResult(
                success = false,
                dry_run = false,
                commands_generated = length(plan.operations),
                files_transferred = files_transferred,
                operations = plan.operations
            )
        end
    end

    return SyncResult(
        success = true,
        dry_run = false,
        commands_generated = length(plan.operations),
        files_transferred = files_transferred,
        operations = plan.operations
    )
end

"""
    get_sync_commands(config::SyncConfig) -> Vector{Cmd}

Get list of rsync commands that would be executed.

# Arguments
- `config::SyncConfig`: Sync configuration

# Returns
- `Vector{Cmd}`: List of rsync commands

# Examples
```julia
commands = get_sync_commands(config)
for cmd in commands
    println(cmd)
end
```
"""
function get_sync_commands(config::SyncConfig)::Vector{Cmd}
    plan = build_sync_plan(config)
    return [op[:command] for op in plan.operations]
end

"""
    validate_sync_config(config::SyncConfig) -> ValidationResult

Validate a sync configuration.

# Arguments
- `config::SyncConfig`: Configuration to validate

# Returns
- `ValidationResult`: Validation result with errors if invalid

# Examples
```julia
validation = validate_sync_config(config)
if !validation.valid
    for err in validation.errors
        println("Error: \$err")
    end
end
```
"""
function validate_sync_config(config::SyncConfig)::ValidationResult
    errors = String[]

    # Check local directories exist
    if !isdir(config.local_config_dir)
        push!(errors, "Local config directory does not exist: $(config.local_config_dir)")
    end

    if !isdir(config.local_scripts_dir)
        push!(errors, "Local scripts directory does not exist: $(config.local_scripts_dir)")
    end

    # Check remote host format
    if !occursin('@', config.remote_host)
        push!(errors, "Remote host must be in format 'user@hostname': $(config.remote_host)")
    end

    # Check remote base dir is absolute path
    if !startswith(config.remote_base_dir, '/')
        push!(errors, "Remote base directory must be absolute path: $(config.remote_base_dir)")
    end

    return ValidationResult(isempty(errors), errors)
end

"""
    get_remote_config_path(config::SyncConfig) -> String

Get the full remote path where config will be synced.

# Arguments
- `config::SyncConfig`: Sync configuration

# Returns
- `String`: Remote path including hostname

# Examples
```julia
remote_path = get_remote_config_path(config)
println("Files will be synced to: \$remote_path")
```
"""
function get_remote_config_path(config::SyncConfig)::String
    config_basename = basename(rstrip(config.local_config_dir, '/'))
    return "$(config.remote_host):$(config.remote_base_dir)$(config_basename)"
end

"""
    TransferSizeInfo

Information about transfer size estimation.

# Fields
- `total_files::Int`: Total number of files
- `total_bytes::Int`: Total bytes to transfer
- `human_readable::String`: Human-readable size (e.g., "1.5 MB")
"""
struct TransferSizeInfo
    total_files::Int
    total_bytes::Int
    human_readable::String
end

"""
    estimate_transfer_size(config::SyncConfig) -> TransferSizeInfo

Estimate the total size of files to transfer.

# Arguments
- `config::SyncConfig`: Sync configuration

# Returns
- `TransferSizeInfo`: Size estimation

# Examples
```julia
size_info = estimate_transfer_size(config)
println("Will transfer \$(size_info.total_files) files (\$(size_info.human_readable))")
```
"""
function estimate_transfer_size(config::SyncConfig)::TransferSizeInfo
    total_files = 0
    total_bytes = 0

    # Count files in config directory
    for (root, dirs, files) in walkdir(config.local_config_dir)
        for file in files
            total_files += 1
            file_path = joinpath(root, file)
            try
                total_bytes += stat(file_path).size
            catch
                # Skip files we can't stat
            end
        end
    end

    # Count files in scripts directory if different
    if config.local_scripts_dir != config.local_config_dir
        for (root, dirs, files) in walkdir(config.local_scripts_dir)
            for file in files
                total_files += 1
                file_path = joinpath(root, file)
                try
                    total_bytes += stat(file_path).size
                catch
                    # Skip files we can't stat
                end
            end
        end
    end

    # Format human-readable size
    human_readable = if total_bytes < 1024
        "$(total_bytes) bytes"
    elseif total_bytes < 1024^2
        "$(round(total_bytes / 1024, digits=1)) KB"
    elseif total_bytes < 1024^3
        "$(round(total_bytes / 1024^2, digits=1)) MB"
    else
        "$(round(total_bytes / 1024^3, digits=2)) GB"
    end

    return TransferSizeInfo(total_files, total_bytes, human_readable)
end

"""
    progress_percentage(progress::SyncProgress) -> Float64

Calculate percentage complete for sync progress.

# Arguments
- `progress::SyncProgress`: Current progress

# Returns
- `Float64`: Percentage complete (0.0 to 100.0)

# Examples
```julia
pct = progress_percentage(progress)
println("Progress: \$(round(pct, digits=1))%")
```
"""
function progress_percentage(progress::SyncProgress)::Float64
    if progress.total_files == 0
        return 0.0
    end
    return (progress.files_completed / progress.total_files) * 100.0
end

end # module HPCSync
