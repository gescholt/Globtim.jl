"""
Environment Detection Module (Issue #136 Phase 1)

Automatically detects whether code is running on local machine or HPC cluster.

Detection Strategy (Priority Order):
1. SLURM_JOB_ID environment variable → HPC
2. Hostname contains "r04n02" → HPC
3. Default → Local

Author: GlobTim Project
Date: October 5, 2025
"""

module EnvironmentDetection

export detect_environment, is_hpc, is_local, get_environment_info

"""
    detect_environment(; _test_hostname=nothing) -> Symbol

Detect the execution environment automatically.

Returns:
- `:hpc` if running on HPC cluster
- `:local` if running on local machine

Detection criteria (in priority order):
1. SLURM_JOB_ID environment variable present → HPC
2. Hostname contains "r04n02" → HPC
3. HOSTNAME environment variable contains "r04n02" → HPC
4. Otherwise → Local

# Arguments
- `_test_hostname`: Internal parameter for testing. Do not use in production.

# Examples
```julia
env = detect_environment()
if env == :hpc
    println("Running on HPC cluster")
else
    println("Running on local machine")
end
```
"""
function detect_environment(; _test_hostname=nothing)::Symbol
    # Priority 1: Check for SLURM job environment
    if haskey(ENV, "SLURM_JOB_ID")
        return :hpc
    end

    # Priority 2: Check hostname (use injected value for testing, or real hostname)
    hostname = if _test_hostname !== nothing
        _test_hostname
    else
        gethostname()
    end

    if occursin("r04n02", lowercase(hostname))
        return :hpc
    end

    # Priority 3: Check HOSTNAME environment variable as fallback
    if haskey(ENV, "HOSTNAME")
        env_hostname = ENV["HOSTNAME"]
        if occursin("r04n02", lowercase(env_hostname))
            return :hpc
        end
    end

    # Default: local environment
    return :local
end

"""
    is_hpc() -> Bool

Convenience function to check if running on HPC cluster.

# Examples
```julia
if is_hpc()
    launch_on_hpc()
else
    launch_locally()
end
```
"""
function is_hpc()::Bool
    return detect_environment() == :hpc
end

"""
    is_local() -> Bool

Convenience function to check if running on local machine.

# Examples
```julia
if is_local()
    sync_to_hpc()
end
```
"""
function is_local()::Bool
    return detect_environment() == :local
end

"""
    get_environment_info() -> NamedTuple

Get detailed information about the detected environment.

Returns a NamedTuple with:
- `environment`: Symbol (:local or :hpc)
- `hostname`: String (system hostname)
- `has_slurm`: Bool (whether SLURM environment detected)
- `detection_reason`: String (explanation of detection)

# Examples
```julia
info = get_environment_info()
println("Environment: \$(info.environment)")
println("Reason: \$(info.detection_reason)")
```
"""
function get_environment_info()::NamedTuple
    has_slurm = haskey(ENV, "SLURM_JOB_ID")
    hostname = gethostname()
    env_hostname = get(ENV, "HOSTNAME", "")

    environment = detect_environment()

    # Determine detection reason
    detection_reason = if has_slurm
        "SLURM_JOB_ID environment variable detected"
    elseif occursin("r04n02", lowercase(hostname))
        "Hostname contains 'r04n02': $hostname"
    elseif occursin("r04n02", lowercase(env_hostname))
        "HOSTNAME environment variable contains 'r04n02': $env_hostname"
    else
        "No HPC indicators found, defaulting to local"
    end

    return (
        environment = environment,
        hostname = hostname,
        has_slurm = has_slurm,
        detection_reason = detection_reason
    )
end

end # module EnvironmentDetection
