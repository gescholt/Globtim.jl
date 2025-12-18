"""
Process Verification Module (Issue #136 Phase 5)

Handles remote process verification and monitoring on HPC cluster.

Author: GlobTim Project
Date: October 5, 2025
"""

module ProcessVerification

export VerificationConfig, VerificationResult,
       parse_process_list, verify_process_count, generate_ps_command,
       generate_remote_ps_command, verify_processes, is_hpc_accessible,
       matches_pattern, count_matching_processes, filter_processes,
       get_process_pids

"""
    VerificationConfig

Configuration for process verification.

# Fields
- `host::String`: Remote host in format "user@hostname"
- `pattern::String`: Pattern to match in process command
- `expected_count::Int`: Expected number of matching processes
- `timeout_seconds::Float64`: Timeout for verification
"""
struct VerificationConfig
    host::String
    pattern::String
    expected_count::Int
    timeout_seconds::Float64

    function VerificationConfig(;
        host::String,
        pattern::String,
        expected_count::Int,
        timeout_seconds::Float64 = 30.0
    )
        new(host, pattern, expected_count, timeout_seconds)
    end
end

"""
    VerificationResult

Result of process verification.

# Fields
- `success::Bool`: Whether verification succeeded
- `found_count::Int`: Number of processes found
- `expected_count::Int`: Number of processes expected
- `processes::Vector{Dict{Symbol,String}}`: List of found processes
- `message::String`: Human-readable result message
"""
struct VerificationResult
    success::Bool
    found_count::Int
    expected_count::Int
    processes::Vector{Dict{Symbol,String}}
    message::String

    function VerificationResult(;
        success::Bool,
        found_count::Int,
        expected_count::Int,
        processes::Vector{Dict{Symbol,String}},
        message::String
    )
        new(success, found_count, expected_count, processes, message)
    end
end

"""
    parse_process_list(ps_output::String) -> Vector{Dict{Symbol,String}}

Parse output from ps command into structured process list.

# Arguments
- `ps_output::String`: Raw output from ps aux | grep command

# Returns
- `Vector{Dict{Symbol,String}}`: List of processes with :user, :pid, :command fields

# Examples
```julia
ps_output = \"\"\"
user1  12345  julia exp1.jl
user2  12346  julia exp2.jl
\"\"\"

processes = parse_process_list(ps_output)
# Returns: [Dict(:user => "user1", :pid => "12345", :command => "julia exp1.jl"), ...]
```
"""
function parse_process_list(ps_output::String)::Vector{Dict{Symbol,String}}
    processes = Dict{Symbol,String}[]

    for line in split(ps_output, '\n')
        line = strip(line)
        if isempty(line)
            continue
        end

        # Parse ps aux format: USER PID %CPU %MEM ... COMMAND
        # We care about USER (field 1), PID (field 2), and COMMAND (field 11+)
        parts = split(line)
        if length(parts) >= 11
            user = parts[1]
            pid = parts[2]
            # Command is everything from field 11 onwards
            command = join(parts[11:end], " ")

            push!(processes, Dict{Symbol,String}(
                :user => user,
                :pid => pid,
                :command => command
            ))
        end
    end

    return processes
end

"""
    verify_process_count(processes, expected) -> Bool

Verify that the number of processes matches expected count.

# Arguments
- `processes::Vector{Dict{Symbol,String}}`: List of processes
- `expected::Int`: Expected count

# Returns
- `Bool`: true if count matches

# Examples
```julia
if verify_process_count(processes, expected=3)
    println("All 3 processes are running")
end
```
"""
function verify_process_count(processes::Vector{Dict{Symbol,String}}, expected::Int)::Bool
    return length(processes) == expected
end

"""
    generate_ps_command(; pattern) -> Cmd

Generate a ps command to list processes matching a pattern.

# Arguments
- `pattern::String`: Pattern to grep for

# Returns
- `Cmd`: ps command with grep

# Examples
```julia
cmd = generate_ps_command(pattern="julia lotka")
run(cmd)
```
"""
function generate_ps_command(; pattern::String)::Cmd
    # ps aux | grep pattern | grep -v grep
    return Cmd([
        "sh", "-c",
        "ps aux | grep '$(pattern)' | grep -v grep"
    ])
end

"""
    generate_remote_ps_command(; host, pattern) -> Cmd

Generate an SSH command to list remote processes.

# Arguments
- `host::String`: Remote host in format "user@hostname"
- `pattern::String`: Pattern to grep for

# Returns
- `Cmd`: SSH command that runs ps remotely

# Examples
```julia
cmd = generate_remote_ps_command(
    host = "user@r04n02",
    pattern = "julia"
)
```
"""
function generate_remote_ps_command(; host::String, pattern::String)::Cmd
    remote_cmd = "ps aux | grep '$(pattern)' | grep -v grep"
    return Cmd(["ssh", host, remote_cmd])
end

"""
    verify_processes(config::VerificationConfig) -> VerificationResult

Verify that expected processes are running on remote host.

# Arguments
- `config::VerificationConfig`: Verification configuration

# Returns
- `VerificationResult`: Verification result

# Examples
```julia
config = VerificationConfig(
    host = "user@r04n02",
    pattern = "julia lotka",
    expected_count = 3,
    timeout_seconds = 30.0
)

result = verify_processes(config)
if result.success
    println("All processes verified!")
end
```
"""
function verify_processes(config::VerificationConfig)::VerificationResult
    try
        # Generate and run remote ps command
        cmd = generate_remote_ps_command(
            host = config.host,
            pattern = config.pattern
        )

        # Run command and capture output
        ps_output = read(cmd, String)

        # Parse process list
        processes = parse_process_list(ps_output)
        found_count = length(processes)

        # Check if count matches expected
        success = verify_process_count(processes, config.expected_count)

        # Generate message
        message = if success
            "All $(config.expected_count) processes running"
        else
            "Only $(found_count)/$(config.expected_count) processes running"
        end

        return VerificationResult(
            success = success,
            found_count = found_count,
            expected_count = config.expected_count,
            processes = processes,
            message = message
        )

    catch e
        # Failed to verify (SSH error, etc.)
        return VerificationResult(
            success = false,
            found_count = 0,
            expected_count = config.expected_count,
            processes = Dict{Symbol,String}[],
            message = "Verification failed: $(e)"
        )
    end
end

"""
    is_hpc_accessible(host::String) -> Bool

Check if HPC host is accessible via SSH.

# Arguments
- `host::String`: Remote host in format "user@hostname"

# Returns
- `Bool`: true if accessible

# Examples
```julia
if is_hpc_accessible("user@r04n02")
    println("HPC is accessible")
end
```
"""
function is_hpc_accessible(host::String)::Bool
    try
        # Try a simple SSH command (echo test)
        cmd = Cmd(["ssh", host, "echo test"])
        result = read(cmd, String)
        return occursin("test", result)
    catch
        return false
    end
end

"""
    matches_pattern(process::Dict{Symbol,String}, pattern::String) -> Bool

Check if a process matches a pattern.

# Arguments
- `process::Dict{Symbol,String}`: Process info
- `pattern::String`: Pattern to match

# Returns
- `Bool`: true if process command contains pattern

# Examples
```julia
if matches_pattern(process, "julia")
    println("This is a Julia process")
end
```
"""
function matches_pattern(process::Dict{Symbol,String}, pattern::String)::Bool
    return occursin(pattern, process[:command])
end

"""
    count_matching_processes(processes, pattern) -> Int

Count processes that match a pattern.

# Arguments
- `processes::Vector{Dict{Symbol,String}}`: List of processes
- `pattern::String`: Pattern to match

# Returns
- `Int`: Count of matching processes

# Examples
```julia
julia_count = count_matching_processes(processes, "julia")
println("Found \$julia_count Julia processes")
```
"""
function count_matching_processes(
    processes::Vector{Dict{Symbol,String}},
    pattern::String
)::Int
    return count(p -> matches_pattern(p, pattern), processes)
end

"""
    filter_processes(processes; pattern=nothing, user=nothing) -> Vector{Dict{Symbol,String}}

Filter processes by pattern and/or user.

# Arguments
- `processes::Vector{Dict{Symbol,String}}`: List of processes
- `pattern::Union{String,Nothing}`: Optional pattern to match in command
- `user::Union{String,Nothing}`: Optional user to match

# Returns
- `Vector{Dict{Symbol,String}}`: Filtered processes

# Examples
```julia
julia_processes = filter_processes(processes, pattern="julia")
user_processes = filter_processes(processes, user="scholten")
```
"""
function filter_processes(
    processes::Vector{Dict{Symbol,String}};
    pattern::Union{String,Nothing} = nothing,
    user::Union{String,Nothing} = nothing
)::Vector{Dict{Symbol,String}}
    filtered = processes

    if pattern !== nothing
        filtered = filter(p -> matches_pattern(p, pattern), filtered)
    end

    if user !== nothing
        filtered = filter(p -> p[:user] == user, filtered)
    end

    return filtered
end

"""
    get_process_pids(processes) -> Vector{String}

Extract PIDs from process list.

# Arguments
- `processes::Vector{Dict{Symbol,String}}`: List of processes

# Returns
- `Vector{String}`: List of PIDs

# Examples
```julia
pids = get_process_pids(processes)
println("PIDs: \$(join(pids, ", "))")
```
"""
function get_process_pids(processes::Vector{Dict{Symbol,String}})::Vector{String}
    return [p[:pid] for p in processes]
end

end # module ProcessVerification
