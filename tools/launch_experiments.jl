#!/usr/bin/env julia

"""
Launch Experiments - Unified HPC and Local Experiment Launcher

Handles deployment, file transfer, process management, and monitoring for experiments.

Usage:
    julia tools/launch_experiments.jl --config configs_*/master_config.json
    julia tools/launch_experiments.jl --config config.json --target hpc
    julia tools/launch_experiments.jl --config config.json --target local
"""

using ArgParse
using JSON
using Dates

# Load BatchManifest for status tracking
# Determine the path to BatchManifest.jl relative to this script
const SCRIPT_DIR = @__DIR__
const BATCH_MANIFEST_PATH = joinpath(dirname(SCRIPT_DIR), "src", "BatchManifest.jl")
include(BATCH_MANIFEST_PATH)
using .BatchManifest
using .BatchManifest: ExperimentEntry, Manifest

# ============================================================================
# Data Structures
# ============================================================================

"""
Configuration for launching experiments.

Fields:
- config_dir: Directory containing experiment configuration
- target: Launch target (:local or :hpc)
- hpc_host: HPC hostname (e.g., "r04n02")
- hpc_user: HPC username
- experiment_scripts: List of experiment scripts to launch
"""
struct LaunchConfig
    config_dir::String
    target::Symbol
    hpc_host::String
    hpc_user::String
    experiment_scripts::Vector{String}
end

# ============================================================================
# Environment Detection
# ============================================================================

"""
    detect_environment() -> Symbol

Detect whether we're running on HPC or local machine.

Returns:
- :hpc if running on HPC cluster (SLURM detected or HPC hostname)
- :local otherwise

Detection criteria:
1. SLURM_JOB_ID environment variable exists → HPC
2. Hostname matches HPC pattern (r04n02, gpu01, etc.) → HPC
3. Otherwise → local
"""
function detect_environment()
    # Check for SLURM environment
    if haskey(ENV, "SLURM_JOB_ID")
        return :hpc
    end

    # Check hostname for HPC patterns
    hostname = gethostname()
    if hostname_is_hpc(hostname)
        return :hpc
    end

    return :local
end

"""
    hostname_is_hpc(hostname::String) -> Bool

Check if hostname matches HPC cluster patterns.

Common HPC patterns:
- r04n02, r04n03, etc. (compute nodes)
- gpu01, gpu02, etc. (GPU nodes)
- login01, login02, etc. (login nodes)
"""
function hostname_is_hpc(hostname::String)
    hpc_patterns = [
        r"^r\d+n\d+",      # r04n02, r05n01, etc.
        r"^gpu\d+",        # gpu01, gpu02, etc.
        r"^login\d+",      # login01, login02, etc.
        r"^compute\d+",    # compute01, etc.
    ]

    return any(pattern -> occursin(pattern, hostname), hpc_patterns)
end

# ============================================================================
# CLI Argument Parsing
# ============================================================================

"""
    parse_commandline(args=ARGS) -> Dict

Parse command-line arguments for experiment launcher.

Required arguments:
- --config, -c: Path to master_config.json

Optional arguments:
- --target, -t: Launch target (auto/local/hpc), default: auto
- --hpc-host: HPC hostname, default: r04n02
- --hpc-user: HPC username, default: \$USER
"""
function parse_commandline(args=ARGS)
    s = ArgParseSettings(
        description = "Launch experiments locally or on HPC cluster",
        version = "0.1.0",
        add_version = true
    )

    @add_arg_table! s begin
        "--config", "-c"
            help = "Path to master_config.json"
            required = true
        "--target", "-t"
            help = "Launch target: auto, local, or hpc"
            default = "auto"
        "--hpc-host"
            help = "HPC hostname"
            default = "r04n02"
        "--hpc-user"
            help = "HPC username"
            default = get(ENV, "USER", "scholten")
    end

    return parse_args(args, s)
end

# ============================================================================
# Batch Manifest Management
# ============================================================================

"""
    load_batch_manifest_if_exists(config_dir::String) -> Union{Manifest, Nothing}

Load batch manifest from config directory if it exists.

Returns:
- Manifest if batch_manifest.json exists
- nothing if no manifest found
"""
function load_batch_manifest_if_exists(config_dir::String)
    manifest_path = joinpath(config_dir, "batch_manifest.json")
    if isfile(manifest_path)
        return load_batch_manifest(config_dir)
    end
    return nothing
end

"""
    update_manifest_for_launch!(manifest::Manifest, experiment_id::String, config_dir::String)

Mark experiment as running in manifest and save to disk.
"""
function update_manifest_for_launch!(manifest::Manifest, experiment_id::String, config_dir::String)
    updated_manifest = update_experiment_status!(manifest, experiment_id, "running")
    save_batch_manifest(updated_manifest, config_dir)
    return updated_manifest
end

# ============================================================================
# Local Launch
# ============================================================================

"""
    launch_local(config::LaunchConfig) -> Vector{Int}

Launch experiments locally as background processes.

For each experiment:
1. Create log file path (script.jl → script.log)
2. Launch julia process in background
3. Redirect stdout/stderr to log file
4. Capture and return process ID
5. Update batch manifest status if available

Returns vector of PIDs for launched processes.
"""
function launch_local(config::LaunchConfig)
    @info "Launching $(length(config.experiment_scripts)) experiments locally"

    # Load batch manifest if it exists
    manifest = load_batch_manifest_if_exists(config.config_dir)

    pids = Int[]

    for script in config.experiment_scripts
        exp_name = basename(script)
        log_file = replace(script, ".jl" => ".log")

        @info "Launching $exp_name..."

        # Launch in background with output redirection
        # Use shell redirection to capture both stdout and stderr properly
        cmd = `sh -c "julia $script > $log_file 2>&1"`
        proc = run(cmd, wait=false)

        pid = getpid(proc)
        push!(pids, pid)

        @info "  ✓ Started with PID $pid"

        # Update manifest if available
        if !isnothing(manifest)
            # Extract experiment_id from script name
            # Assumes script format: some_name_expN.jl -> exp_N
            exp_id_match = match(r"exp(\d+)", exp_name)
            if !isnothing(exp_id_match)
                exp_id = "exp_$(exp_id_match.captures[1])"
                try
                    manifest = update_manifest_for_launch!(manifest, exp_id, config.config_dir)
                    @info "  ✓ Updated manifest: $exp_id -> running"
                catch e
                    @warn "Failed to update manifest for $exp_id: $e"
                end
            end
        end
    end

    @info "All experiments launched locally"
    return pids
end

# ============================================================================
# HPC Launch
# ============================================================================

"""
    launch_hpc(config::LaunchConfig)

Launch experiments on HPC cluster.

Workflow:
1. Sync files to cluster (rsync)
2. Launch experiments via SSH
3. Verify all processes started
4. Print monitoring commands
"""
function launch_hpc(config::LaunchConfig)
    @info "Deploying to HPC: $(config.hpc_host)"

    # 1. Sync files
    sync_to_hpc(config)

    # 2. Launch experiments
    launch_remote_experiments(config)

    # 3. Verify
    verify_experiments_running(config)

    # 4. Print monitoring info
    print_monitoring_info(config)
end

"""
    sync_to_hpc(config::LaunchConfig)

Sync experiment files to HPC cluster using rsync.

Syncs:
1. Config directory
2. Setup scripts
"""
function sync_to_hpc(config::LaunchConfig)
    remote_base = "$(config.hpc_user)@$(config.hpc_host):globtimcore/experiments/"

    @info "Syncing experiment configs to HPC..."
    run(`rsync -avz --progress $(config.config_dir) $remote_base`)

    @info "Syncing experiment scripts to HPC..."
    # Sync the parent directory of config_dir (which contains the scripts)
    # This handles both test fixtures and real experiments
    scripts_dir = dirname(config.config_dir)
    if occursin("fixtures", scripts_dir)
        # For test fixtures, sync the whole fixtures directory
        run(`rsync -avz --progress $(scripts_dir) $remote_base`)
    else
        # For real experiments, sync all .jl files from the scripts directory
        scripts_dir_name = basename(scripts_dir)
        remote_scripts_dir = "$(remote_base)$(scripts_dir_name)/"
        # Use shell to expand wildcard
        run(`sh -c "rsync -avz --progress $(scripts_dir)/*.jl $remote_scripts_dir"`)
    end

    @info "File sync complete"
end

"""
    launch_remote_experiments(config::LaunchConfig)

Launch experiments on HPC via SSH with nohup.

For each experiment:
1. Construct SSH command with cd to correct directory
2. Use nohup for background execution
3. Redirect output to log file
4. Add small delay to avoid overwhelming SSH
"""
function launch_remote_experiments(config::LaunchConfig)
    @info "Launching $(length(config.experiment_scripts)) experiments on HPC"

    config_dir_name = basename(config.config_dir)
    scripts_dir = dirname(config.config_dir)

    # Determine remote directory structure and script locations
    if occursin("fixtures", scripts_dir)
        # For test fixtures: scripts are in ../mock_scripts, run from mock_config
        remote_config_dir = "globtimcore/experiments/fixtures/$config_dir_name"
        remote_base_dir = "globtimcore/experiments/fixtures"
    else
        # For real experiments: scripts and configs are in same directory
        experiment_name = basename(scripts_dir)
        remote_config_dir = "globtimcore/experiments/$experiment_name/$config_dir_name"
        remote_base_dir = "globtimcore/experiments/$experiment_name"
    end

    for script in config.experiment_scripts
        exp_name = basename(script)
        log_file = replace(exp_name, ".jl" => ".log")

        # Determine the remote script path - use absolute path from home directory
        local_rel_script = relpath(script, config.config_dir)
        remote_script_abs = joinpath("\$HOME", remote_base_dir, local_rel_script)

        @info "Launching $exp_name on HPC..."

        # Construct SSH command - run from config dir, but reference script with absolute path
        remote_cmd = """
        cd $remote_config_dir &&
        nohup julia $remote_script_abs > $log_file 2>&1 &
        """

        ssh_target = "$(config.hpc_user)@$(config.hpc_host)"
        run(`ssh $ssh_target $remote_cmd`)

        @info "  ✓ Launched $exp_name"

        # Small delay to avoid overwhelming SSH
        sleep(1)
    end

    @info "All experiments launched on HPC"
end

"""
    verify_experiments_running(config::LaunchConfig) -> Bool

Verify that experiments are running on HPC.

Checks process count via SSH ps command.

Returns true if expected number of processes are running.
"""
function verify_experiments_running(config::LaunchConfig)
    @info "Verifying experiments started..."

    sleep(5)  # Give processes time to start

    # Check running processes - look for any julia processes
    ssh_target = "$(config.hpc_user)@$(config.hpc_host)"
    ps_cmd = "ps aux | grep 'julia' | grep -v grep | wc -l"

    result = read(`ssh $ssh_target $ps_cmd`, String)
    count = parse(Int, strip(result))

    expected = length(config.experiment_scripts)

    if count >= expected
        @info "✅ All $expected experiments running on HPC"
        return true
    else
        @warn "⚠️  Only $count/$expected experiments running - check logs"
        return false
    end
end

"""
    print_monitoring_info(config::LaunchConfig)
    print_monitoring_info(io::IO, config::LaunchConfig)

Print monitoring commands for user to check experiment status.

Provides commands for:
- Viewing logs
- Checking running processes
- Downloading results
"""
function print_monitoring_info(io::IO, config::LaunchConfig)
    config_dir_name = basename(config.config_dir)
    scripts_dir = dirname(config.config_dir)
    ssh_target = "$(config.hpc_user)@$(config.hpc_host)"

    # Determine remote directory structure
    if occursin("fixtures", scripts_dir)
        remote_dir = "globtimcore/experiments/fixtures/$config_dir_name"
    else
        experiment_name = basename(scripts_dir)
        remote_dir = "globtimcore/experiments/$experiment_name/$config_dir_name"
    end

    println(io, "\n" * "="^60)
    println(io, "EXPERIMENT MONITORING")
    println(io, "="^60)

    println(io, "\nCheck logs:")
    println(io, "  ssh $ssh_target 'tail -20 $remote_dir/*.log'")

    println(io, "\nCheck running processes:")
    println(io, "  ssh $ssh_target \"ps aux | grep 'julia' | grep -v grep\"")

    println(io, "\nDownload results:")
    println(io, "  rsync -avz $ssh_target:$remote_dir/ ./results/")

    println(io, "\n" * "="^60)
end

function print_monitoring_info(config::LaunchConfig)
    print_monitoring_info(stdout, config)
end

# ============================================================================
# Main Orchestration
# ============================================================================

"""
    launch_experiments(config::LaunchConfig)

Main entry point for launching experiments.

Routes to local or HPC launch based on config.target.
"""
function launch_experiments(config::LaunchConfig)
    @info "Launch configuration:" config.target config.config_dir

    if config.target == :local
        launch_local(config)
    elseif config.target == :hpc
        launch_hpc(config)
    else
        error("Invalid target: $(config.target). Must be :local or :hpc")
    end
end

# ============================================================================
# Main Entry Point (when run as script)
# ============================================================================

function main()
    args = parse_commandline()

    # Determine target
    target_str = args["target"]
    target = if target_str == "auto"
        detect_environment()
    else
        Symbol(target_str)
    end

    # Validate config exists
    config_path = args["config"]
    if !isfile(config_path)
        error("Config file not found: $config_path")
    end

    config_dir = dirname(abspath(config_path))

    # Try to load batch manifest first (new standard)
    manifest_path = joinpath(config_dir, "batch_manifest.json")
    experiment_scripts = String[]

    if isfile(manifest_path)
        @info "Loading experiment scripts from batch manifest"
        manifest = load_batch_manifest(config_dir)

        # Extract scripts from manifest
        for exp in manifest.experiments
            script_path = joinpath(config_dir, exp.script_path)
            if isfile(script_path)
                push!(experiment_scripts, script_path)
            else
                @warn "Script not found: $script_path (referenced in manifest)"
            end
        end

        @info "Found $(length(experiment_scripts)) experiments in batch manifest (batch_id: $(manifest.batch_id))"
    else
        # Fallback to old master_config.json format
        @info "No batch manifest found, trying master_config.json"
        config_data = JSON.parsefile(config_path)

        # Extract experiment scripts from config
        if haskey(config_data, "campaigns")
            for campaign in config_data["campaigns"]
                if haskey(campaign, "experiments")
                    for exp in campaign["experiments"]
                        if haskey(exp, "script")
                            script_path = joinpath(config_dir, exp["script"])
                            push!(experiment_scripts, script_path)
                        end
                    end
                end
            end
        elseif haskey(config_data, "script_paths")
            # Alternative format: direct script_paths array
            for script in config_data["script_paths"]
                push!(experiment_scripts, script)
            end
        end
    end

    if isempty(experiment_scripts)
        error("No experiment scripts found in config: $config_path")
    end

    # Create launch config
    launch_config = LaunchConfig(
        config_dir,
        target,
        args["hpc-host"],
        args["hpc-user"],
        experiment_scripts
    )

    # Launch!
    launch_experiments(launch_config)
end

# Run main if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
