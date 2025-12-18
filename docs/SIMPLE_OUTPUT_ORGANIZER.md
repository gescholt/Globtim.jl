# Simple Output Organizer - Integration Guide

**Purpose**: Replace manual path construction in experiment scripts with automatic, validated organization.

## The Problem

Current experiment scripts (like `run_lv4d_experiment.jl`) use manual path construction:

```julia
# OLD WAY - Manual and error-prone
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
results_base = IS_LOCAL ? "local_results" : "hpc_results"
results_dir = joinpath(results_base, "lv4d_GN$(GN)_deg$(DEGREE_MIN)-$(DEGREE_MAX)_domain$(DOMAIN_RANGE)_$(timestamp)")
mkpath(results_dir)
```

**Problems**:
- ❌ Flat structure (`hpc_results/experiment/`) violates hierarchy requirements
- ❌ No objective name grouping
- ❌ Not compatible with `ExperimentCollector` batch analysis
- ❌ Hardcoded path logic duplicated across scripts

## The Solution

**SimpleOutputOrganizer** - One function, automatic organization:

```julia
# NEW WAY - Automatic and validated
include("src/SimpleOutputOrganizer.jl")
using .SimpleOutputOrganizer

config = Dict(
    "objective_name" => "lotka_volterra_4d",  # REQUIRED
    "GN" => 16,
    "degree_range" => [4, 18],
    "domain_range" => 0.3
)

exp_dir = create_experiment_dir(config)
# Returns: $GLOBTIM_RESULTS_ROOT/lotka_volterra_4d/exp_20251016_161234/
```

## Quick Start

### 1. Load the Module (Standalone - No Globtim Needed)

```julia
# At the top of your experiment script
include(joinpath(@__DIR__, "../../src/SimpleOutputOrganizer.jl"))
using .SimpleOutputOrganizer
```

**Or** if you're already using Globtim:
```julia
using Globtim
# Module is automatically available (once integrated)
```

### 2. Create Experiment Directory

```julia
# Prepare configuration dictionary
config = Dict{String, Any}(
    "objective_name" => "lotka_volterra_4d",  # REQUIRED
    # Add all your experiment parameters
    "GN" => 16,
    "degree_min" => 4,
    "degree_max" => 18,
    "basis" => "chebyshev",
    "domain_range" => 0.3
)

# Create directory (auto-creates hierarchy, saves config)
exp_dir = create_experiment_dir(config)

# Now save your results
results_path = joinpath(exp_dir, "results_summary.json")
# ... save results ...
```

### 3. That's It!

The function:
- ✅ Creates `$GLOBTIM_RESULTS_ROOT/objective_name/` (if needed)
- ✅ Creates `exp_YYYYMMDD_HHMMSS/` with unique timestamp
- ✅ Saves `experiment_config.json` automatically
- ✅ Returns absolute path for saving results
- ✅ Validates everything

## API Reference

### `create_experiment_dir(config; experiment_id="exp") -> String`

**Arguments**:
- `config::Dict`: Experiment configuration (must contain `"objective_name"`)
- `experiment_id::String`: Optional custom ID (default: `"exp"`)

**Returns**: Absolute path to created experiment directory

**Side effects**:
- Creates objective directory (if needed)
- Creates experiment directory
- Saves `experiment_config.json`

**Example**:
```julia
config = Dict("objective_name" => "sphere_function", "GN" => 8)
exp_dir = create_experiment_dir(config)
# → /path/to/globtim_results/sphere_function/exp_20251016_161234/
```

**With custom ID**:
```julia
exp_dir = create_experiment_dir(config; experiment_id="batch_01")
# → /path/to/globtim_results/sphere_function/batch_01_20251016_161234/
```

### `get_results_root() -> String`

Get the results root directory from `GLOBTIM_RESULTS_ROOT` environment variable.

**Returns**: Absolute path to results root

**Throws**: Error if `GLOBTIM_RESULTS_ROOT` not set or directory doesn't exist

## Migrating Existing Experiments

### Example: `run_lv4d_experiment.jl`

**Before** (lines 74-77):
```julia
# Configuration from arguments
const DOMAIN_RANGE = args["domain"]
const GN = args["GN"]
const DEGREE_MIN = args["deg-min"]
const DEGREE_MAX = args["deg-max"]
const BASIS = Symbol(args["basis"])

# OLD - Manual path construction
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
results_base = IS_LOCAL ? "local_results" : "hpc_results"
results_dir = joinpath(results_base, "lv4d_GN$(GN)_deg$(DEGREE_MIN)-$(DEGREE_MAX)_domain$(DOMAIN_RANGE)_$(timestamp)")
mkpath(results_dir)
```

**After**:
```julia
# Add at top of file
include(joinpath(@__DIR__, "../../src/SimpleOutputOrganizer.jl"))
using .SimpleOutputOrganizer

# Configuration from arguments
const DOMAIN_RANGE = args["domain"]
const GN = args["GN"]
const DEGREE_MIN = args["deg-min"]
const DEGREE_MAX = args["deg-max"]
const BASIS = Symbol(args["basis"])

# NEW - Automatic organization
config = Dict{String, Any}(
    "objective_name" => "lotka_volterra_4d",
    "GN" => GN,
    "degree_min" => DEGREE_MIN,
    "degree_max" => DEGREE_MAX,
    "domain_range" => DOMAIN_RANGE,
    "basis" => string(BASIS),
    "p_true" => P_TRUE,
    "p_center" => P_CENTER,
    "ic" => IC,
    "time_interval" => TIME_INTERVAL,
    "num_points" => NUM_POINTS
)

exp_dir = create_experiment_dir(config)
```

**Rest of the script unchanged** - just use `exp_dir` instead of `results_dir`.

## Batch Experiments

For running multiple experiments in a batch:

```julia
include("src/SimpleOutputOrganizer.jl")
using .SimpleOutputOrganizer

base_config = Dict("objective_name" => "sphere_function")

# Run sweep
for GN in [8, 12, 16]
    for deg_max in [8, 10, 12]
        config = merge(base_config, Dict("GN" => GN, "degree_max" => deg_max))

        exp_dir = create_experiment_dir(config)

        # Run experiment
        run_experiment(exp_dir, config)
    end
end

# All experiments automatically organized:
# $GLOBTIM_RESULTS_ROOT/
# └── sphere_function/
#     ├── exp_20251016_161234/  (GN=8, deg=8)
#     ├── exp_20251016_161235/  (GN=8, deg=10)
#     ├── exp_20251016_161236/  (GN=8, deg=12)
#     └── ...
```

## Error Handling

### Missing `GLOBTIM_RESULTS_ROOT`

```
ERROR: GLOBTIM_RESULTS_ROOT environment variable not set!

Set it with:
    export GLOBTIM_RESULTS_ROOT=~/globtim_results
    mkdir -p $GLOBTIM_RESULTS_ROOT
```

**Solution**:
```bash
export GLOBTIM_RESULTS_ROOT=~/globtim_results
mkdir -p $GLOBTIM_RESULTS_ROOT
```

### Missing `objective_name`

```
ERROR: Config must contain 'objective_name' or 'template' field
```

**Solution**: Add to config:
```julia
config["objective_name"] = "lotka_volterra_4d"
```

### Invalid `objective_name`

```
ERROR: Invalid objective_name: 'Lotka Volterra 4D' (use only alphanumeric, _, -)
```

**Solution**: Use valid format:
```julia
config["objective_name"] = "lotka_volterra_4d"  # ✓ Valid
```

## Testing

Run integration tests:
```bash
cd globtimcore
julia --project=. test/test_simple_output_organizer.jl
```

Tests verify:
- ✅ Directory hierarchy creation
- ✅ Config file saving
- ✅ Unique timestamp handling
- ✅ Batch experiment workflow
- ✅ ExperimentCollector compatibility

## Comparison: Simple vs Complex

We created two versions:

| Feature | SimpleOutputOrganizer | ExperimentOutputOrganizer |
|---------|----------------------|---------------------------|
| **Lines of code** | 140 | 300+ |
| **Dependencies** | Dates, JSON3 | Many |
| **Complexity** | Minimal | High |
| **Use case** | 99% of experiments | Advanced scenarios |
| **Recommendation** | ✅ **Use this** | ⚠️ Only if you need it |

**Use SimpleOutputOrganizer** unless you need:
- Custom OutputPathConfig
- Batch metadata tracking
- Migration helpers
- Advanced validation

For normal experiments: **Simple is better**.

## Summary

**Replace these 5 lines**:
```julia
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
results_base = IS_LOCAL ? "local_results" : "hpc_results"
results_dir = joinpath(results_base, "lv4d_GN$(GN)_...")
mkpath(results_dir)
# Save config manually...
```

**With these 2 lines**:
```julia
config = Dict("objective_name" => "lotka_volterra_4d", "GN" => GN, ...)
exp_dir = create_experiment_dir(config)
```

**Result**:
- ✅ Correct hierarchy
- ✅ Auto-saved config
- ✅ Compatible with analysis tools
- ✅ Less code
- ✅ Fewer bugs

**Next Steps**:
1. Set `GLOBTIM_RESULTS_ROOT` environment variable
2. Update your experiment script (see migration example)
3. Run and verify structure with `tree $GLOBTIM_RESULTS_ROOT`
4. Results automatically discovered by `globtimpostprocessing`!
