"""
Solver timeout utility for production use.

Guards `HC.solve()` (via the degree loop) and the msolve OS process against
indefinite hangs on hard polynomial systems during cluster runs.
"""

struct SolverTimeoutError <: Exception
    label::String
    seconds::Float64
end

function Base.showerror(io::IO, e::SolverTimeoutError)
    print(io, "SolverTimeoutError: '$(e.label)' exceeded $(e.seconds)s limit")
end

"""
    with_solver_timeout(f, seconds; label="solver") -> result

Run `f()` with a wall-clock timeout. Throws `SolverTimeoutError` if exceeded.

`seconds = nothing` is a no-op passthrough — zero overhead when no timeout is configured.

Uses `Threads.@spawn`. On timeout the spawned task is abandoned (not interrupted) —
injecting `InterruptException` into tasks that own child threads causes SIGABRT.
The zombie task runs to completion and discards its result; on cluster slurm kills
the whole job on wall-time anyway.

For the msolve OS process use the process-level kill path in `_solve_msolve` instead.
"""
function with_solver_timeout(
    f::Function,
    seconds::Union{Nothing,Real};
    label::String = "solver",
)
    seconds === nothing && return f()
    limit = Float64(seconds)
    ch = Channel{Tuple{Symbol,Any}}(1)

    # Do not store the task reference — we intentionally abandon it on timeout.
    # Calling schedule(t, InterruptException()) into a task that owns child threads
    # (e.g. Constructor's threaded grid evaluation) causes SIGABRT. The zombie thread
    # runs to completion and discards its result; on cluster slurm kills the whole job.
    Threads.@spawn begin
        try
            result = f()
            put!(ch, (:ok, result))
        catch e
            put!(ch, (:error, e))
        end
    end

    deadline = time() + limit
    while !isready(ch)
        if time() > deadline
            throw(SolverTimeoutError(label, limit))
        end
        sleep(0.05)
    end

    status, value = take!(ch)
    status == :ok ? value : throw(value)
end
