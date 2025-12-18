# Automated Experiment Output Organization

**Status**: ✅ Active (October 2025)
**Module**: `ExperimentOutputOrganizer`
**Related**: `OutputPathManager`, `ExperimentCollector` (globtimpostprocessing)

## Overview

The `ExperimentOutputOrganizer` module provides **zero-config, automated** experiment output management that ensures all outputs follow the standardized structure required by `ExperimentCollector` for campaign discovery and batch analysis.

### Key Features

1. ✅ **Auto-creates objective directories** from `experiment_config.json`
2. ✅ **Validates paths before any file I/O**
3. ✅ **Fail-fast on misconfiguration** (no silent fallbacks)
4. ✅ **Compatible with HPC and local environments**
5. ✅ **Integrates with existing `OutputPathManager`**

## The Problem This Solves

### Before: Manual Directory Management ❌
```julia
# User had to:
results_root = ENV["GLOBTIM_RESULTS_ROOT"]
objective_dir = joinpath(results_root, "lotka_volterra_4d")
mkpath(objective_dir)  # Easy to forget!

timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
exp_dir = joinpath(objective_dir, "exp_$(timestamp)")
mkpath(exp_dir)

# Save config
config_path = joinpath(exp_dir, "experiment_config.json")
open(config_path, "w") do io
    JSON3.write(io, config)
end
```

**Issues**:
- Forgot to create objective directory → flat structure violation
- Inconsistent naming conventions
- No validation until analysis fails
- Duplicated code across experiments

### After: One-Line Automation ✅
```julia
using Globtim.ExperimentOutputOrganizer

config = Dict(
    "objective_name" => "lotka_volterra_4d",
    "GN" => 12,
    "degree_range" => [4, 12]
)

# Creates: $GLOBTIM_RESULTS_ROOT/lotka_volterra_4d/exp_20251016_161234/
exp_dir = validate_and_create_experiment_dir(config)

# Config already saved, directory validated, ready to write results!
```

## Quick Start Guide

### 1. Basic Usage (Recommended)

**Option A: Standalone (Lightweight)** - Only loads what you need:
```julia
# From globtimcore directory
include("src/ExperimentOutputOrganizer.jl")
using .ExperimentOutputOrganizer
```

**Option B: Via Globtim** - If you're already using Globtim:
```julia
using Globtim
using Globtim.ExperimentOutputOrganizer
```

Both options provide the same functionality. Use Option A for lightweight scripts
that only need output organization, and Option B when you're already using Globtim
for other features.

```julia
# Now use the module (same for both options)

# Your experiment configuration
config = Dict{String, Any}(
    "objective_name" => "lotka_volterra_4d",  # REQUIRED
    "GN" => 12,
    "degree_range" => [4, 12],
    "basis" => "chebyshev",
    "domain_range" => 0.1
)

# One call creates everything
exp_dir = validate_and_create_experiment_dir(config)

# exp_dir is now:
# $GLOBTIM_RESULTS_ROOT/lotka_volterra_4d/exp_20251016_161234/
#
# Structure:
# ✓ Objective directory created
# ✓ Experiment directory created
# ✓ Config file saved
# ✓ All paths validated

# Now save your results
results_path = joinpath(exp_dir, "results_summary.json")
# ... save results ...
```

### 2. Custom Experiment ID

```julia
# For batch experiments with meaningful IDs
config = Dict("objective_name" => "sphere_function")

exp_dir = validate_and_create_experiment_dir(
    config;
    experiment_id = "batch_sweep_deg10"
)

# Creates: $GLOBTIM_RESULTS_ROOT/sphere_function/batch_sweep_deg10_20251016_161234/
```

### 3. Manual Control (Advanced)

```julia
using Globtim.ExperimentOutputOrganizer
using Globtim.OutputPathManager

# Create organizer with custom config
org = ExperimentOrganizer(
    config = OutputPathConfig(
        results_root = "/custom/path",
        environment = :local
    ),
    auto_create_objective_dirs = true,
    track_batches = true
)

# Use custom organizer
exp_dir = validate_and_create_experiment_dir(config; organizer=org)
```

## API Reference

### Main Functions

#### `validate_and_create_experiment_dir`

**The primary function for all experiments.**

```julia
validate_and_create_experiment_dir(
    config::Dict{String, Any};
    organizer::Union{ExperimentOrganizer, Nothing} = nothing,
    experiment_id::Union{String, Nothing} = nothing
) -> String
```

**Arguments**:
- `config`: Dict that will be saved as `experiment_config.json`
  - **Must contain**: `"objective_name"` or `"template"` field
  - Can contain any other experiment parameters
- `organizer`: Optional custom `ExperimentOrganizer` (uses default if omitted)
- `experiment_id`: Optional experiment ID (auto-generated if omitted)

**Returns**: Absolute path to created experiment directory

**Throws**: Errors on:
- Missing `GLOBTIM_RESULTS_ROOT`
- Invalid objective name (must be alphanumeric with `_-` only)
- Directory already exists
- Permission issues

**Side effects**:
- Creates objective directory (if needed)
- Creates experiment directory
- Saves `experiment_config.json`

#### `ensure_objective_directory`

Low-level function to ensure an objective directory exists.

```julia
ensure_objective_directory(
    results_root::String,
    objective_name::String
) -> String
```

#### `validate_results_root_structure`

Validate and initialize the results root structure.

```julia
validate_results_root_structure(results_root::String) -> Bool
```

Creates `batches/` and `indices/` metadata directories if missing.

### Helper Functions

#### `extract_objective_from_config`

```julia
extract_objective_from_config(config_path::String) -> String
```

Extract objective name from an existing `experiment_config.json` file.

#### `extract_batch_name`

```julia
extract_batch_name(experiment_name::String) -> String
```

Extract batch base name by removing `_YYYYMMDD_HHMMSS` timestamp suffix.
Matches the logic in `ExperimentCollector.jl` for consistent batch detection.

## Directory Structure

### Standard Structure (Created Automatically)

```
$GLOBTIM_RESULTS_ROOT/
├── batches/                         # Batch metadata (auto-created)
├── indices/                         # Experiment indices (auto-created)
├── lotka_volterra_4d/              # Objective directory (auto-created)
│   ├── exp_20251016_143022/        # Experiment 1 (auto-created)
│   │   ├── experiment_config.json  # Saved automatically
│   │   ├── results_summary.json    # You save this
│   │   ├── critical_points_deg_*.csv
│   │   └── timing_report.txt
│   ├── exp_20251016_151234/        # Experiment 2
│   └── batch_sweep_20251016_160045/  # Custom ID
├── sphere_function/
│   └── ...
└── rastrigin_10d/
    └── ...
```

### Naming Conventions

**Objective directories**:
- Pattern: `{objective_name}/`
- Valid: `lotka_volterra_4d`, `rastrigin_10d`, `sphere-function`
- Invalid: `Lotka Volterra`, `test/exp`, `obj#1`

**Experiment directories**:
- Pattern: `{experiment_id}_{YYYYMMDD_HHMMSS}/`
- Default ID: `exp` (becomes `exp_20251016_143022`)
- Custom ID: `batch_sweep` (becomes `batch_sweep_20251016_143022`)

## Integration with Existing Code

### Replace Manual Path Construction

**Before** ❌:
```julia
exp_dir = mkpath(joinpath(ENV["GLOBTIM_RESULTS_ROOT"], "lotka_volterra_4d", "exp_$(timestamp)"))
```

**After** ✅:
```julia
exp_dir = validate_and_create_experiment_dir(config)
```

### Works with OutputPathManager

The organizer uses `OutputPathManager` internally, so all existing validations apply:

```julia
using Globtim.OutputPathManager
using Globtim.ExperimentOutputOrganizer

# Both use the same config
config = OutputPathConfig()

# Low-level (manual control)
metadata = ExperimentMetadata("lotka_volterra_4d", "exp_123")
path1 = create_experiment_directory(metadata)

# High-level (recommended)
config_dict = Dict("objective_name" => "lotka_volterra_4d")
path2 = validate_and_create_experiment_dir(config_dict, experiment_id="exp_123")

# Both create the same structure!
```

## Batch Experiment Workflow

For running multiple experiments in a batch:

```julia
using Globtim.ExperimentOutputOrganizer

# Shared configuration
base_config = Dict(
    "objective_name" => "lotka_volterra_4d",
    "basis" => "chebyshev",
    "domain_range" => 0.1
)

# Run batch with different parameters
for GN in [8, 12, 16]
    for deg_max in [8, 10, 12]
        # Merge parameters
        config = merge(base_config, Dict(
            "GN" => GN,
            "degree_range" => [4, deg_max]
        ))

        # Auto-creates with unique timestamp
        exp_dir = validate_and_create_experiment_dir(config)

        # Run experiment
        run_experiment(exp_dir, config)
    end
end

# All experiments automatically grouped by objective
# Ready for batch analysis with globtimpostprocessing!
```

## Error Handling

### Common Errors and Solutions

#### 1. Missing GLOBTIM_RESULTS_ROOT

```
ERROR: Output path not configured!

You must set GLOBTIM_RESULTS_ROOT environment variable.
```

**Solution**:
```bash
export GLOBTIM_RESULTS_ROOT=~/globtim_results
mkdir -p $GLOBTIM_RESULTS_ROOT
```

#### 2. Missing objective_name

```
ERROR: Config dict must contain 'objective_name' or 'template' field.
```

**Solution**: Add to your config:
```julia
config["objective_name"] = "lotka_volterra_4d"
```

#### 3. Invalid objective name

```
ERROR: Invalid objective name: 'Lotka Volterra 4D'

Objective names must be:
- Non-empty
- Alphanumeric with underscores/hyphens only
```

**Solution**: Use valid format:
```julia
config["objective_name"] = "lotka_volterra_4d"  # ✓ Valid
```

#### 4. Directory already exists

```
ERROR: Experiment directory already exists: '/path/to/exp_20251016_143022'

This likely means:
- The same experiment was run twice in the same second
- You need to use a unique experiment_id
```

**Solution**: Use custom ID or wait one second:
```julia
exp_dir = validate_and_create_experiment_dir(config, experiment_id="unique_id")
```

## Validation and Testing

### Validate Configuration

```julia
using Globtim.ExperimentOutputOrganizer

# Check if results_root is properly set up
validate_results_root_structure(ENV["GLOBTIM_RESULTS_ROOT"])
```

### Test Directory Creation (Without Side Effects)

```julia
using Globtim.OutputPathManager

# Get path without creating
metadata = ExperimentMetadata("test_objective", "test_exp")
path = get_experiment_output_path(metadata)
println("Would create: $path")
```

## Migration from Legacy Code

### Step 1: Identify Manual Path Construction

Search for:
```julia
mkpath(joinpath(...))
joinpath(ENV["GLOBTIM_RESULTS_ROOT"], ...)
```

### Step 2: Replace with Organizer

```julia
# OLD
exp_dir = joinpath(ENV["GLOBTIM_RESULTS_ROOT"], "lotka_volterra_4d",
                   "exp_$(Dates.format(now(), \"yyyymmdd_HHMMSS\"))")
mkpath(exp_dir)

# NEW
exp_dir = validate_and_create_experiment_dir(config)
```

### Step 3: Verify Structure

```bash
cd $GLOBTIM_RESULTS_ROOT
tree -L 2
```

Should show:
```
.
├── batches/
├── indices/
└── lotka_volterra_4d/
    ├── exp_20251016_143022/
    └── exp_20251016_151234/
```

## Best Practices

### ✅ DO

1. **Always include objective_name in config**
   ```julia
   config["objective_name"] = "lotka_volterra_4d"
   ```

2. **Use descriptive objective names**
   ```julia
   "lotka_volterra_4d"  # ✓ Good
   "lv4d"               # ⚠ Less clear
   "test"               # ❌ Too generic
   ```

3. **Use custom IDs for batch experiments**
   ```julia
   experiment_id = "deg_sweep_$(deg)_GN$(GN)"
   ```

4. **Call at the START of your experiment**
   ```julia
   exp_dir = validate_and_create_experiment_dir(config)
   # Now config is saved, proceed with experiment
   ```

### ❌ DON'T

1. **Don't manually create objective directories**
   ```julia
   mkpath(joinpath(results_root, objective_name))  # ❌ Automated now
   ```

2. **Don't use spaces or special characters in names**
   ```julia
   config["objective_name"] = "Test Experiment #1"  # ❌ Invalid
   ```

3. **Don't save config manually**
   ```julia
   # ❌ Config is already saved by validate_and_create_experiment_dir!
   open(joinpath(exp_dir, "experiment_config.json"), "w") do io
       JSON3.write(io, config)
   end
   ```

4. **Don't mix old and new path management**
   ```julia
   # Pick one approach and stick with it
   ```

## Troubleshooting

### Issue: Experiments not showing in globtimpostprocessing

**Check**:
1. Directory structure:
   ```bash
   cd $GLOBTIM_RESULTS_ROOT
   tree -L 2
   ```
   Should show `objective/experiment` hierarchy

2. Required files in each experiment:
   ```bash
   ls lotka_volterra_4d/exp_*/
   ```
   Must have:
   - `experiment_config.json` ✓ (created automatically)
   - `results_summary.json` (you save this)
   - `critical_points_deg_*.csv` (you save this)

3. Validation:
   ```julia
   using GlobtimPostProcessing.ExperimentCollector

   structure = detect_directory_structure(ENV["GLOBTIM_RESULTS_ROOT"])
   println("Structure: $structure")  # Should be "Hierarchical"

   batches = discover_batches(ENV["GLOBTIM_RESULTS_ROOT"])
   println("Found $(length(batches)) batches")
   ```

### Issue: Permission denied

```bash
# Check permissions
ls -la $GLOBTIM_RESULTS_ROOT

# Fix if needed
chmod -R u+w $GLOBTIM_RESULTS_ROOT
```

### Issue: Config validation errors

```julia
using Globtim.OutputPathManager

# Debug configuration
try
    cfg = get_output_config()
    @info "Config OK" cfg
catch e
    @error "Config error" exception=e
end
```

## Related Documentation

- [OUTPUT_STANDARDIZATION.md](OUTPUT_STANDARDIZATION.md) - Output file format specs
- [OUTPUT_PATH_STANDARDIZATION.md](OUTPUT_PATH_STANDARDIZATION.md) - Path structure details
- [RESULTS_ROOT_SETUP.md](RESULTS_ROOT_SETUP.md) - Environment setup
- [globtimpostprocessing/ExperimentCollector.jl](../../globtimpostprocessing/src/ExperimentCollector.jl) - Analysis integration

## Summary

**Use `validate_and_create_experiment_dir(config)` at the start of every experiment.**

That's it! The function:
- ✅ Creates objective directory
- ✅ Creates experiment directory
- ✅ Saves config file
- ✅ Validates everything
- ✅ Returns path for results

No more manual directory management, no more structural violations, no more missing experiments in analysis.
