"""
Test timeout utilities for Globtim.

Provides `with_timeout` to guard test blocks against hanging.

# Configuration
- `GLOBTIM_TEST_TIMEOUT_MULTIPLIER`: multiply all timeouts (default "1.0")
  Set to "2.0" on slow CI machines, "0" to disable timeouts entirely.
"""

struct TimeoutError <: Exception
    label::String
    seconds::Float64
end

function Base.showerror(io::IO, e::TimeoutError)
    print(io, "TimeoutError: '$(e.label)' exceeded $(e.seconds)s limit")
end

"""
    with_timeout(f, seconds; label="operation") -> result

Run `f()` with a wall-clock timeout. Throws `TimeoutError` if exceeded.

Uses a separate `Task`; on timeout the task receives `InterruptException`.
Note: this cannot interrupt foreign (C/Fortran) blocking calls, but it
will interrupt pure-Julia compute loops and most HomotopyContinuation work.

Set ENV["GLOBTIM_TEST_TIMEOUT_MULTIPLIER"] = "0" to disable all timeouts.
"""
function with_timeout(f::Function, seconds::Real; label::String="operation")
    mult_str = get(ENV, "GLOBTIM_TEST_TIMEOUT_MULTIPLIER", "1.0")
    multiplier = parse(Float64, mult_str)

    # Multiplier of 0 disables timeouts
    if multiplier == 0.0
        return f()
    end

    limit = seconds * multiplier
    ch = Channel{Tuple{Symbol, Any}}(1)

    t = Threads.@spawn begin
        try
            result = f()
            put!(ch, (:ok, result))
        catch e
            put!(ch, (:error, e))
        end
    end

    # Poll for completion — simple and robust
    deadline = time() + limit
    while !isready(ch)
        if time() > deadline
            # Try to interrupt the task
            try; schedule(t, InterruptException(); error=true); catch; end
            # Give it a moment to clean up
            sleep(0.5)
            throw(TimeoutError(label, limit))
        end
        sleep(0.25)
    end

    status, value = take!(ch)
    if status == :ok
        return value
    else
        throw(value)  # Re-throw the original exception
    end
end
