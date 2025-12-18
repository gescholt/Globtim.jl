# ODE Warning Suppression

## Overview

When running optimization with ODE-based objective functions (e.g., parameter recovery experiments), the DifferentialEquations.jl solver can produce many warnings during parameter space exploration. These warnings occur when certain parameter combinations lead to numerical instability:

**Note**: As of 2025-10-14, the codebase uses **NelderMead (gradient-free optimization)** by default for robustness with ODE-based objectives, avoiding the need for automatic differentiation through ODE solves.

```
┌ Warning: At t=7.548527380329381, dt was forced below floating point epsilon
│ 8.881784197001252e-16, and step error estimate = 2.050529468896692e-40.
│ Aborting. There is either an error in your model specification or the true
│ solution is unstable (or the true solution can not be represented in the
│ precision of Float64).
└ @ SciMLBase ~/.julia/packages/SciMLBase/YE7xF/src/integrator_interface.jl:657
```

## Solution

We suppress these warnings at two levels:

### 1. ODE Solving Level

In `Examples/systems/DynamicalSystems.jl`, the `sample_data` function wraps the ODE solve call:

```julia
problem.p.tunable .= p_true
old_logger = Logging.global_logger()
Logging.global_logger(Logging.SimpleLogger(stderr, Logging.Error))
local solution_true
try
    solution_true = ModelingToolkit.solve(problem, solver, saveat = sampling_times;
                                         abstol, reltol, verbose=false, maxiters=1000000)
finally
    Logging.global_logger(old_logger)
end
```

**Location:** [DynamicalSystems.jl:298-306](../Examples/systems/DynamicalSystems.jl)

### 2. Optimization Level

In `src/refine.jl`, both optimization calls are wrapped with warning suppression and use **gradient-free optimization**:

**Critical point refinement** (around line 421):
```julia
res = Logging.with_logger(Logging.NullLogger()) do
    Optim.optimize(f, x0, Optim.NelderMead(), ...)
end
```

**Adaptive precision optimization** (around line 781):
```julia
result = Logging.with_logger(Logging.NullLogger()) do
    Optim.optimize(objective_function, point, Optim.NelderMead(), ...)
end
```

**Location:** [refine.jl:422-435 and 777-791](../src/refine.jl)

### 3. Critical Point Refinement Module

In `src/CriticalPointRefinement.jl`, gradient-free optimization is used by default:

```julia
function refine_critical_point(
    objective_func,
    initial_point::Vector{Float64};
    method = NelderMead(),  # Default: gradient-free
    f_tol::Float64 = 1e-8,
    x_tol::Float64 = 1e-8
)
    # ... refinement logic
end
```

**Location:** [CriticalPointRefinement.jl:90-147](../src/CriticalPointRefinement.jl)

## How It Works

1. **Save current logger**: Store the global logger before suppression
2. **Set Error-only logger**: Replace with a logger that only shows Error-level messages
3. **Run optimization**: Execute the optimization/ODE solve
4. **Restore logger**: Always restore the original logger (even if errors occur)

## Benefits

- **Cleaner output**: No flood of warning messages during parameter exploration
- **Preserved error reporting**: Actual errors are still shown
- **Thread-safe**: Each optimization properly manages its own logger state
- **Automatic cleanup**: `finally` block ensures logger restoration

## When to Use

This suppression is appropriate when:
- Exploring parameter space where some combinations naturally fail
- Running batch experiments with many optimization runs
- The code already handles ODE failures gracefully (returns `NaN`, catches exceptions)

## When NOT to Use

Do not suppress warnings when:
- Debugging a specific ODE model
- Investigating why optimization fails
- Developing new objective functions

## Alternative: Manual Control

For scripts that need manual control, use the `ODEWarningSuppression` module:

```julia
using Globtim.ODEWarningSuppression

suppress_ode_warnings()
# ... your code ...
restore_ode_warnings()

# Or use the macro:
@suppress_ode_warnings begin
    result = my_optimization(...)
end
```

**Location:** [src/ODEWarningSuppression.jl](../src/ODEWarningSuppression.jl)

## Gradient-Free Optimization (2025-10-14 Update)

### Why NelderMead Instead of BFGS?

For ODE-based parameter recovery, gradient-free optimization is preferred:

**BFGS Issues:**
- Requires gradients via automatic differentiation (ForwardDiff.jl)
- AD through ODE solvers is expensive (dual number propagation)
- Each gradient evaluation = differentiated ODE solve
- Fails when ODE solver encounters stiff regions
- Not robust to numerical noise in objective function

**NelderMead Advantages:**
- ✅ No gradients needed - uses only function evaluations
- ✅ Robust to ODE solver failures during exploration
- ✅ Works well with noisy/stiff objective landscapes
- ✅ Fewer ODE solves per iteration (~2 vs 5 for BFGS)
- ✅ Widely proven for parameter fitting problems

### Performance Comparison

For 4D Lotka-Volterra parameter recovery:

| Method | Gradient? | ODE solves/iter | Robustness | Typical convergence |
|--------|-----------|-----------------|------------|---------------------|
| BFGS | Yes (AD) | 5 (1 + 4 grad) | Low ⚠️ | Fast (if no failures) |
| NelderMead | No | ~2-3 | High ✅ | Moderate |

### Alternative: Using BFGS for Smooth Problems

If your objective function is smooth and cheap to evaluate (not ODE-based), you can override the default:

```julia
# Use BFGS for smooth, non-ODE objectives
result = refine_critical_point(smooth_objective, point; method=BFGS())

# Or in refine.jl, change the method manually
res = Optim.optimize(f, x0, Optim.BFGS(), Optim.Options(...))
```

## Implementation Date

Initial: 2025-10-14 (Warning suppression)
Updated: 2025-10-14 (Switch to gradient-free optimization)

## Related Issues

- Parameter recovery experiments producing excessive warnings
- HPC runs with large log files due to ODE warnings
- Stiff ODE systems causing "Interrupted. Larger maxiters needed" errors
- BFGS failures during parameter space exploration
