# Julia 1.12 World Age Warning Fix

## Problem

Julia 1.12 emits world age warnings when `DynamicalSystems.jl` is loaded via `include()`:

```
WARNING: Detected access to binding `DynamicalSystems.define_daisy_ex3_model_4D`
in a world prior to its definition world.
```

## Root Cause

1. Julia parses the entire script and compiles it (creates "world age 1")
2. During execution, `include("DynamicalSystems.jl")` loads the module (creates "world age 2")
3. The `export` statements in DynamicalSystems create bindings in world age 2
4. Julia detects that the compiled code references bindings from a future world age

## Solution

**Move the `include()` to the very beginning of the script**, before `Pkg.activate()` and all other code.

This ensures:
- DynamicalSystems is loaded during the initial parse/compile phase
- All bindings are created in the same world age
- No warnings are emitted

### Code Pattern

```julia
#!/usr/bin/env julia
"""Docstring..."""

# CRITICAL: Load DynamicalSystems FIRST
const SCRIPT_DIR = @__DIR__
const PROJECT_ROOT = abspath(joinpath(SCRIPT_DIR, "..", ".."))
include(joinpath(PROJECT_ROOT, "Examples", "systems", "DynamicalSystems.jl"))

# Now load everything else
using Pkg
Pkg.activate(PROJECT_ROOT)
# ... rest of the script
```

## Testing

Run the minimal test:
```bash
julia --project=. experiments/lv4d_2025/test_loading.jl
```

Expected output: No warnings, all tests pass.

Run the full experiment:
```bash
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl --GN 6 --degree-range 4:5 --domain 0.1 --basis chebyshev --seed 42
```

Expected output: No world age warnings during startup.

## Long-Term Fix

Convert `Examples/systems/DynamicalSystems.jl` into a proper precompiled package:

1. Create `Examples/systems/DynamicalSystems/` directory
2. Add `Project.toml` with dependencies
3. Move module code to `src/DynamicalSystems.jl`
4. Add to Globtim as a dependency or local package
5. Use normal `using DynamicalSystems` instead of `include()`

This eliminates the need for runtime `include()` and all world age concerns.

## References

- Julia 1.12 world age semantics: https://julialang.org/blog/2023/12/julia-1.10-highlights/#world_age
- GitHub Issue: TBD (create issue for long-term fix)
