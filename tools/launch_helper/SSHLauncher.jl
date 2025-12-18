"""
SSH Launcher Module (Issue #136 Phase 4)

Handles SSH-based remote experiment launching with nohup.

Author: GlobTim Project
Date: October 5, 2025
"""

module SSHLauncher

export LaunchConfig, LaunchResult, LaunchPlan, ValidationResult,
       generate_ssh_command, generate_nohup_command, generate_ssh_launch_command,
       launch_experiments_hpc, build_launch_plan, get_launch_commands,
       validate_launch_config, script_to_logfile, should_throttle,
       get_remote_script_path, get_experiment_count

"""
    LaunchConfig

Configuration for remote experiment launching.

# Fields
- `host::String`: Remote host in format "user@hostname"
- `scripts::Vector{String}`: Experiment script paths (relative to remote_base_dir)
- `remote_base_dir::String`: Remote base directory
- `throttle_seconds::Float64`: Delay between launches to avoid overwhelming SSH
- `dry_run::Bool`: If true, only generate commands without executing
"""
struct LaunchConfig
    host::String
    scripts::Vector{String}
    remote_base_dir::String
    throttle_seconds::Float64
    dry_run::Bool

    function LaunchConfig(;
        host::String,
        scripts::Vector{String},
        remote_base_dir::String,
        throttle_seconds::Float64 = 1.0,
        dry_run::Bool = false
    )
        new(host, scripts, remote_base_dir, throttle_seconds, dry_run)
    end
end

"""
    LaunchResult

Result of launch operation.

# Fields
- `success::Bool`: Whether launch succeeded
- `dry_run::Bool`: Whether this was a dry run
- `commands_generated::Int`: Number of commands generated
- `experiments_launched::Int`: Number of experiments launched (0 for dry run)
- `operations::Vector{Dict{Symbol,Any}}`: List of launch operations
"""
struct LaunchResult
    success::Bool
    dry_run::Bool
    commands_generated::Int
    experiments_launched::Int
    operations::Vector{Dict{Symbol,Any}}

    function LaunchResult(;
        success::Bool,
        dry_run::Bool,
        commands_generated::Int,
        experiments_launched::Int,
        operations::Vector{Dict{Symbol,Any}} = Dict{Symbol,Any}[]
    )
        new(success, dry_run, commands_generated, experiments_launched, operations)
    end
end

"""
    LaunchPlan

Plan of launch operations to execute.

# Fields
- `operations::Vector{Dict{Symbol,Any}}`: List of planned launch operations
"""
struct LaunchPlan
    operations::Vector{Dict{Symbol,Any}}
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
    generate_ssh_command(; host, remote_command) -> Cmd

Generate an SSH command.

# Arguments
- `host::String`: Remote host in format "user@hostname"
- `remote_command::String`: Command to execute remotely

# Returns
- `Cmd`: SSH command ready to execute

# Examples
```julia
cmd = generate_ssh_command(
    host = "user@r04n02",
    remote_command = "ls -l"
)
```
"""
function generate_ssh_command(;
    host::String,
    remote_command::String
)::Cmd
    return Cmd(["ssh", host, remote_command])
end

"""
    generate_nohup_command(; script_path, log_file, working_dir) -> String

Generate a nohup command string for background execution.

# Arguments
- `script_path::String`: Path to Julia script
- `log_file::String`: Path to log file
- `working_dir::String`: Working directory

# Returns
- `String`: nohup command string

# Examples
```julia
cmd_str = generate_nohup_command(
    script_path = "/path/to/exp.jl",
    log_file = "/path/to/exp.log",
    working_dir = "/path/to/"
)
```
"""
function generate_nohup_command(;
    script_path::String,
    log_file::String,
    working_dir::String
)::String
    # Build command: cd to working dir, then nohup julia script > log 2>&1 &
    return "cd $(working_dir) && nohup julia $(script_path) > $(log_file) 2>&1 &"
end

"""
    generate_ssh_launch_command(; host, script_path, log_file, working_dir) -> Cmd

Generate combined SSH + nohup command for remote launch.

# Arguments
- `host::String`: Remote host in format "user@hostname"
- `script_path::String`: Path to Julia script (relative to working_dir)
- `log_file::String`: Path to log file (relative to working_dir)
- `working_dir::String`: Working directory on remote host

# Returns
- `Cmd`: SSH command that launches script with nohup

# Examples
```julia
cmd = generate_ssh_launch_command(
    host = "user@r04n02",
    script_path = "exp1.jl",
    log_file = "exp1.log",
    working_dir = "/home/user/experiments/"
)
```
"""
function generate_ssh_launch_command(;
    host::String,
    script_path::String,
    log_file::String,
    working_dir::String
)::Cmd
    nohup_cmd = generate_nohup_command(
        script_path = script_path,
        log_file = log_file,
        working_dir = working_dir
    )

    return generate_ssh_command(
        host = host,
        remote_command = nohup_cmd
    )
end

"""
    build_launch_plan(config::LaunchConfig) -> LaunchPlan

Build a plan of launch operations from configuration.

# Arguments
- `config::LaunchConfig`: Launch configuration

# Returns
- `LaunchPlan`: Planned launch operations

# Examples
```julia
plan = build_launch_plan(config)
println("Will launch \$(length(plan.operations)) experiments")
```
"""
function build_launch_plan(config::LaunchConfig)::LaunchPlan
    operations = Dict{Symbol,Any}[]

    for script in config.scripts
        # Generate log file path from script path
        log_file = script_to_logfile(script)

        # Get full remote paths
        remote_script = get_remote_script_path(config, script)
        remote_log = get_remote_script_path(config, log_file)
        remote_dir = dirname(remote_script)

        # Extract just the filename for the nohup command
        script_name = basename(script)
        log_name = basename(log_file)

        # Generate launch command
        cmd = generate_ssh_launch_command(
            host = config.host,
            script_path = script_name,
            log_file = log_name,
            working_dir = remote_dir
        )

        op = Dict{Symbol,Any}(
            :script => script,
            :log_file => log_file,
            :remote_script => remote_script,
            :remote_log => remote_log,
            :command => cmd,
            :description => "Launch $(basename(script))"
        )

        push!(operations, op)
    end

    return LaunchPlan(operations)
end

"""
    launch_experiments_hpc(config::LaunchConfig) -> LaunchResult

Launch experiments on HPC cluster via SSH.

# Arguments
- `config::LaunchConfig`: Launch configuration

# Returns
- `LaunchResult`: Result of launch operation

# Examples
```julia
config = LaunchConfig(
    host = "user@r04n02",
    scripts = ["exp1.jl", "exp2.jl"],
    remote_base_dir = "/remote/experiments/",
    throttle_seconds = 1.0,
    dry_run = false
)

result = launch_experiments_hpc(config)
if result.success
    println("Launched \$(result.experiments_launched) experiments")
end
```
"""
function launch_experiments_hpc(config::LaunchConfig)::LaunchResult
    # Validate configuration
    validation = validate_launch_config(config)
    if !validation.valid
        return LaunchResult(
            success = false,
            dry_run = config.dry_run,
            commands_generated = 0,
            experiments_launched = 0,
            operations = Dict{Symbol,Any}[]
        )
    end

    # Build launch plan
    plan = build_launch_plan(config)

    if config.dry_run
        # Dry run: return plan without executing
        return LaunchResult(
            success = true,
            dry_run = true,
            commands_generated = length(plan.operations),
            experiments_launched = 0,
            operations = plan.operations
        )
    end

    # Execute launch operations
    experiments_launched = 0
    for (i, op) in enumerate(plan.operations)
        try
            # Execute SSH command
            run(op[:command])
            experiments_launched += 1

            # Throttle between launches (except after last one)
            if i < length(plan.operations) && should_throttle(config)
                sleep(config.throttle_seconds)
            end

        catch e
            @warn "Failed to launch $(op[:script])" exception=e
            return LaunchResult(
                success = false,
                dry_run = false,
                commands_generated = length(plan.operations),
                experiments_launched = experiments_launched,
                operations = plan.operations
            )
        end
    end

    return LaunchResult(
        success = true,
        dry_run = false,
        commands_generated = length(plan.operations),
        experiments_launched = experiments_launched,
        operations = plan.operations
    )
end

"""
    get_launch_commands(config::LaunchConfig) -> Vector{Cmd}

Get list of SSH launch commands that would be executed.

# Arguments
- `config::LaunchConfig`: Launch configuration

# Returns
- `Vector{Cmd}`: List of SSH launch commands

# Examples
```julia
commands = get_launch_commands(config)
for cmd in commands
    println(cmd)
end
```
"""
function get_launch_commands(config::LaunchConfig)::Vector{Cmd}
    plan = build_launch_plan(config)
    return [op[:command] for op in plan.operations]
end

"""
    validate_launch_config(config::LaunchConfig) -> ValidationResult

Validate a launch configuration.

# Arguments
- `config::LaunchConfig`: Configuration to validate

# Returns
- `ValidationResult`: Validation result with errors if invalid

# Examples
```julia
validation = validate_launch_config(config)
if !validation.valid
    for err in validation.errors
        println("Error: \$err")
    end
end
```
"""
function validate_launch_config(config::LaunchConfig)::ValidationResult
    errors = String[]

    # Check scripts list is not empty
    if isempty(config.scripts)
        push!(errors, "Scripts list is empty - no experiments to launch")
    end

    # Check host format includes user@
    if !occursin('@', config.host)
        push!(errors, "Host must be in format 'user@hostname': $(config.host)")
    end

    # Check remote base dir is absolute path
    if !startswith(config.remote_base_dir, '/')
        push!(errors, "Remote base directory must be absolute path: $(config.remote_base_dir)")
    end

    # Check all scripts end with .jl
    invalid_scripts = filter(s -> !endswith(s, ".jl"), config.scripts)
    if !isempty(invalid_scripts)
        push!(errors, "Invalid script paths (must end with .jl): $(join(invalid_scripts, ", "))")
    end

    # Check throttle is non-negative
    if config.throttle_seconds < 0.0
        push!(errors, "Throttle seconds must be non-negative: $(config.throttle_seconds)")
    end

    return ValidationResult(isempty(errors), errors)
end

"""
    script_to_logfile(script::String) -> String

Convert a script path to a log file path.

# Arguments
- `script::String`: Script path (e.g., "path/to/exp1.jl")

# Returns
- `String`: Log file path (e.g., "path/to/exp1.log")

# Examples
```julia
log = script_to_logfile("configs_20251005/exp1.jl")
# Returns: "configs_20251005/exp1.log"
```
"""
function script_to_logfile(script::String)::String
    # Replace .jl extension with .log
    if endswith(script, ".jl")
        return script[1:end-3] * ".log"
    else
        return script * ".log"
    end
end

"""
    should_throttle(config::LaunchConfig) -> Bool

Check if throttling should be applied between launches.

# Arguments
- `config::LaunchConfig`: Launch configuration

# Returns
- `Bool`: true if throttle_seconds > 0

# Examples
```julia
if should_throttle(config)
    sleep(config.throttle_seconds)
end
```
"""
function should_throttle(config::LaunchConfig)::Bool
    return config.throttle_seconds > 0.0
end

"""
    get_remote_script_path(config::LaunchConfig, script::String) -> String

Get full remote path for a script.

# Arguments
- `config::LaunchConfig`: Launch configuration
- `script::String`: Script path (relative)

# Returns
- `String`: Full remote path

# Examples
```julia
remote_path = get_remote_script_path(config, "configs/exp1.jl")
# Returns: "/home/user/experiments/configs/exp1.jl"
```
"""
function get_remote_script_path(config::LaunchConfig, script::String)::String
    # Join remote base dir with script path
    return joinpath(config.remote_base_dir, script)
end

"""
    get_experiment_count(config::LaunchConfig) -> Int

Get the number of experiments that will be launched.

# Arguments
- `config::LaunchConfig`: Launch configuration

# Returns
- `Int`: Number of experiments

# Examples
```julia
count = get_experiment_count(config)
println("Will launch \$count experiments")
```
"""
function get_experiment_count(config::LaunchConfig)::Int
    return length(config.scripts)
end

end # module SSHLauncher
