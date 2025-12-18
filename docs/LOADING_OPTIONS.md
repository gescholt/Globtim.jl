# Loading Options for ExperimentOutputOrganizer

**TL;DR: For output organization, use standalone. You only need Globtim if the SAME script does optimization.**

The `ExperimentOutputOrganizer` module can be loaded in two ways, depending on your needs.

## Option A: Standalone (Lightweight) ✅ **Recommended for simple scripts**

**Use when**: You only need output organization, not the full Globtim module.

**Advantages**:
- ⚡ **Fast**: Loads in ~1 second (vs ~6 seconds for full Globtim)
- 📦 **Minimal dependencies**: Only requires `Dates` and `JSON3`
- 🎯 **Focused**: Only output management functions

**Usage**:
```julia
# From anywhere in globtimcore project
include("src/ExperimentOutputOrganizer.jl")
using .ExperimentOutputOrganizer

# Now use it
config = Dict("objective_name" => "lotka_volterra_4d")
exp_dir = validate_and_create_experiment_dir(config)
```

**Works in**:
- Standalone scripts
- HPC batch jobs that don't need Globtim functions
- Testing and validation scripts
- Post-processing tools

## Option B: Via Globtim ✅ **Recommended when using other Globtim features**

**Use when**: Your script already uses Globtim for optimization, polynomial construction, etc.

**Advantages**:
- 🔗 **Integrated**: Everything in one package
- 🎯 **Consistent**: Same precompilation, same environment
- 📚 **Complete**: Access to all Globtim functionality

**Usage**:
```julia
using Globtim
using Globtim.ExperimentOutputOrganizer

# Now use it (same API as Option A)
config = Dict("objective_name" => "lotka_volterra_4d")
exp_dir = validate_and_create_experiment_dir(config)
```

**Works in**:
- Full experiment scripts using Globtim functions
- Interactive analysis sessions
- Complex workflows mixing optimization and output management

## Comparison

| Feature | Standalone | Via Globtim |
|---------|-----------|-------------|
| **Load time** | ~1 second | ~6 seconds |
| **Memory** | Low | Higher |
| **Dependencies** | Minimal | Full Globtim |
| **API** | Identical | Identical |
| **Use case** | Simple output scripts | Full experiments |

## Examples

### Example 1: Simple HPC Job (Standalone)
```julia
#!/usr/bin/env julia
# hpc_job.jl - Just saves results, doesn't do optimization

include("src/ExperimentOutputOrganizer.jl")
using .ExperimentOutputOrganizer
using JSON3

config = Dict(
    "objective_name" => "sphere_function",
    "job_id" => ENV["SLURM_JOB_ID"]
)

exp_dir = validate_and_create_experiment_dir(config)

# Load pre-computed results and save
results = JSON3.read(ARGS[1])
open(joinpath(exp_dir, "results_summary.json"), "w") do io
    JSON3.write(io, results)
end
```

### Example 2: Full Experiment (Via Globtim)
```julia
#!/usr/bin/env julia
# full_experiment.jl - Does optimization + saves results

using Globtim
using Globtim.ExperimentOutputOrganizer

# Use Globtim functions
f = Sphere(4)
grid = generate_grid(...)
approx = construct_chebyshev_approx(f, grid, ...)

# Save with organized output
config = Dict("objective_name" => "sphere_function", "GN" => 12)
exp_dir = validate_and_create_experiment_dir(config)

# Save results
# ...
```

## Which Should I Use?

**Use Standalone if**:
- ✅ Script only organizes/validates output
- ✅ Running lightweight HPC job
- ✅ Want fastest possible startup
- ✅ Don't need any Globtim functions

**Use Via Globtim if**:
- ✅ Already using `Globtim` functions
- ✅ Don't care about 5 second startup difference
- ✅ Want everything precompiled together
- ✅ Interactive REPL sessions

## Testing Both

```julia
# Verify standalone works
@time begin
    include("src/ExperimentOutputOrganizer.jl")
    using .ExperimentOutputOrganizer
end
# Should be ~1 second

# Verify via Globtim works
@time begin
    using Globtim
    using Globtim.ExperimentOutputOrganizer
end
# Should be ~6 seconds (first time) or instant (if already loaded)
```

## Summary

Both options provide **identical functionality** - the only difference is loading time and dependencies. Choose based on your script's needs:

- **Lightweight output-only scripts** → Standalone
- **Full experiments with optimization** → Via Globtim

The API is the same either way! 🎉
