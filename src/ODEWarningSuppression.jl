"""
Module to suppress ODE solver warnings globally.

This module provides utilities to suppress DifferentialEquations.jl warnings
that occur during parameter space exploration when some parameter combinations
lead to numerical issues.

Usage:
    using Globtim
    using Globtim.ODEWarningSuppression

    suppress_ode_warnings()
    # ... your code that uses ODE solvers ...
    restore_ode_warnings()

Or use the macro for automatic restoration:
    @suppress_ode_warnings begin
        # ... your code ...
    end
"""
module ODEWarningSuppression

using Logging

export suppress_ode_warnings, restore_ode_warnings, @suppress_ode_warnings

# Store the original logger
const _original_logger = Ref{Union{Nothing,AbstractLogger}}(nothing)

"""
    suppress_ode_warnings()

Suppress all Warning-level log messages globally.
Only Error-level messages will be displayed.
Call `restore_ode_warnings()` to restore normal logging.
"""
function suppress_ode_warnings()
    if isnothing(_original_logger[])
        _original_logger[] = Logging.global_logger()
    end
    Logging.global_logger(Logging.SimpleLogger(stderr, Logging.Error))
    return nothing
end

"""
    restore_ode_warnings()

Restore the original logging configuration.
"""
function restore_ode_warnings()
    if !isnothing(_original_logger[])
        Logging.global_logger(_original_logger[])
        _original_logger[] = nothing
    end
    return nothing
end

"""
    @suppress_ode_warnings expr

Execute `expr` with ODE warnings suppressed, then automatically restore normal logging.

# Example
```julia
@suppress_ode_warnings begin
    result = optimize_function(f, bounds)
end
```
"""
macro suppress_ode_warnings(expr)
    quote
        suppress_ode_warnings()
        try
            $(esc(expr))
        finally
            restore_ode_warnings()
        end
    end
end

end # module
