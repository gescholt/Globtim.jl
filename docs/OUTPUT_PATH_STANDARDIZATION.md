# Output Path Standardization - Enforced System

**Status**: ✅ ENFORCED (Mandatory for all experiments)
**Created**: 2025-10-16
**Replaces**: Ad-hoc output directory patterns

## Overview

All GlobTim experiments **MUST** use the standardized output path system. This eliminates:
- ❌ Mixed directory structures (hierarchical vs flat)
- ❌ Hardcoded `hpc_results/`, `local_results/`, `test_results/`
- ❌ Experiments writing to arbitrary locations
- ❌ Portability issues between HPC and local environments

## Quick Start

### 1. Initial Setup (One-Time)

```bash
cd globtimcore
./scripts/setup_results_root.sh

# This will:
# - Create ~/globtim_results (or /scratch/$USER/globtim_results on HPC)
# - Add GLOBTIM_RESULTS_ROOT to your shell config
# - Create standard directory structure
```

**Restart your shell** or run:
```bash
source ~/.bashrc  # or ~/.zshrc
```

Verify:
```bash
echo $GLOBTIM_RESULTS_ROOT
# Should show: /Users/yourname/globtim_results (or /scratch/$USER/globtim_results)
```

### 2. Writing Experiments

**Use the standardized path creation:**

```julia
using .OutputPathManager

# Define experiment metadata
metadata = ExperimentMetadata(
    "lotka_volterra_4d",  # Objective name (hierarchical folder)
    "param_recovery_exp1"; # Experiment ID (optional, auto-generated if omitted)
    params_dict = Dict("GN" => 8, "domain_size" => 0.1)
)

# Create output directory
output_dir = create_experiment_directory(metadata)
# Returns: $GLOBTIM_RESULTS_ROOT/lotka_volterra_4d/param_recovery_exp1_20251016_143022/
```

**Result directory structure:**
```
$GLOBTIM_RESULTS_ROOT/
└── lotka_volterra_4d/              # Objective-based hierarchy
    ├── param_recovery_exp1_20251016_143022/
    │   ├── results_summary.json
    │   ├── critical_points_deg_4.csv
    │   ├── critical_points_deg_5.csv
    │   └── critical_points_deg_6.csv
    ├── param_recovery_exp2_20251016_151534/
    └── baseline_test_20251017_090123/
```

### 3. Running Experiments

The `StandardExperiment` module **automatically validates** output paths:

```julia
using .StandardExperiment
using .OutputPathManager

# Create metadata
metadata = ExperimentMetadata(
    "lotka_volterra_4d",
    "test_run";
    params_dict = Dict("GN" => 5)
)

# Get standardized output directory
output_dir = create_experiment_directory(metadata)

# Run experiment (automatically validates output configuration)
result = run_standard_experiment(
    objective_function = my_objective,
    problem_params = (α=1.2, β=0.8, γ=1.5, δ=0.7),
    domain_bounds = [(1.775, 1.975), (1.4, 1.6), (0.0, 0.2), (0.0, 0.2)],
    experiment_config = config,
    output_dir = output_dir,
    metadata = Dict(
        "objective_name" => "lotka_volterra_4d",
        "experiment_type" => "parameter_recovery"
    )
)
```

## Architecture

### Core Module: OutputPathManager.jl

Located at: `src/OutputPathManager.jl`

**Key features:**
- ✅ **Strict enforcement**: No fallbacks - fails loudly if misconfigured
- ✅ **Environment detection**: Automatic HPC vs local detection
- ✅ **Validation**: Path validation at creation time
- ✅ **Hierarchical organization**: By objective function name
- ✅ **Legacy detection**: Warns about non-standard paths

**API:**

```julia
# Configuration (auto-initialized on first use)
validate_output_configuration()  # Fails if GLOBTIM_RESULTS_ROOT not set

# Create experiment directories
metadata = ExperimentMetadata("objective_name", "experiment_id")
output_dir = create_experiment_directory(metadata)

# Get path without creating
path = get_experiment_output_path(metadata)

# Migration helpers
new_path = migrate_to_standard_path(legacy_path, "objective_name")
warning = get_legacy_path_warning(some_path)
```

### Directory Naming Rules

**Valid objective names:**
- ✅ `lotka_volterra_4d`
- ✅ `parameter_recovery`
- ✅ `challenging-test-01`
- ❌ `lotka volterra` (spaces not allowed)
- ❌ `test/experiment` (slashes not allowed)

**Valid experiment IDs:**
- ✅ `exp_baseline`
- ✅ `param-recovery-01`
- ✅ `test_run_v2`
- ❌ `exp@baseline` (special characters not allowed)

**Auto-generated IDs:**
- Format: `exp_YYYYMMDD_HHMMSS`
- Example: `exp_20251016_143022`

## Standard Directory Structure

```
$GLOBTIM_RESULTS_ROOT/
├── lotka_volterra_4d/                  # Objective-based organization
│   ├── exp_20251016_143022/
│   │   ├── results_summary.json        # Schema v1.1.0
│   │   ├── results_summary.jld2        # DrWatson format
│   │   ├── critical_points_deg_4.csv
│   │   ├── critical_points_deg_5.csv
│   │   ├── critical_points_deg_6.csv
│   │   ├── experiment_config.json      # Optional
│   │   └── timing_report.txt           # Optional
│   └── exp_20251016_151534/
├── parameter_recovery/
│   └── ...
├── batches/                            # Batch manifests
│   └── lv4d_sweep_20251016/
│       ├── batch_manifest.json
│       └── ...
└── indices/                            # Experiment indices
    ├── computation_index.json
    └── batch_index.json
```

## Environment Configuration

### Local Development

```bash
export GLOBTIM_RESULTS_ROOT=~/globtim_results
mkdir -p $GLOBTIM_RESULTS_ROOT
```

### HPC Cluster

```bash
# Use scratch space for better performance
export GLOBTIM_RESULTS_ROOT=/scratch/$USER/globtim_results
mkdir -p $GLOBTIM_RESULTS_ROOT
```

**Add to `~/.bashrc` or `~/.zshrc`:**
```bash
export GLOBTIM_RESULTS_ROOT=~/globtim_results  # or /scratch/$USER/globtim_results
```

### Environment Detection

The system automatically detects the environment:

**HPC Detection** (any of):
- `SLURM_JOB_ID` environment variable set
- `SLURM_CLUSTER_NAME` environment variable set
- Hostname matches: `r##n##`, `gpu##`, `login##`, `compute##`

**Local Detection:**
- Default if none of the above

## Migration from Legacy Paths

### Identifying Legacy Patterns

**Legacy patterns** (now deprecated):
```
❌ globtimcore/hpc_results/lv4d_GN10_deg4-6_domain0.1_20251016_115902/
❌ globtimcore/local_results/experiment_20251015_093245/
❌ globtimcore/test_results/lotka_volterra_test/
```

**Standard patterns** (required):
```
✅ $GLOBTIM_RESULTS_ROOT/lotka_volterra_4d/exp_20251016_143022/
✅ $GLOBTIM_RESULTS_ROOT/parameter_recovery/baseline_test_20251016_151534/
```

### Automatic Warning System

When using `StandardExperiment.run_standard_experiment()`, legacy paths trigger warnings:

```
⚠ WARNING: Legacy path pattern detected!
Path: globtimcore/hpc_results/lv4d_GN10_deg4-6_domain0.1_20251016_115902

This does not follow the standardized hierarchical structure.
Please use OutputPathManager.create_experiment_directory() instead.

See docs/OUTPUT_PATH_STANDARDIZATION.md for migration guide.
```

### Manual Migration

```julia
using .OutputPathManager

# Convert legacy path to standard path
legacy_path = "hpc_results/lv4d_GN10_deg4-6_domain0.1_20251016_115902"
new_path = migrate_to_standard_path(legacy_path, "lotka_volterra_4d")

# Manually move files
mv(legacy_path, new_path)
```

### Batch Migration Script

For migrating many experiments:

```bash
# TODO: Create migration script
# cd globtimcore
# ./scripts/migrate_legacy_results.sh
```

## Enforcement Rules

### 1. GLOBTIM_RESULTS_ROOT is Mandatory

**Before:**
```julia
# ❌ This will FAIL
output_dir = "hpc_results/my_experiment"
```

**After:**
```julia
# ✅ This is REQUIRED
# GLOBTIM_RESULTS_ROOT must be set in environment
# The system fails loudly if not configured
```

**Error message when not set:**
```
ERROR: Output path not configured!

You must set GLOBTIM_RESULTS_ROOT environment variable.

For local development:
    export GLOBTIM_RESULTS_ROOT=~/globtim_results
    mkdir -p $GLOBTIM_RESULTS_ROOT

For HPC:
    export GLOBTIM_RESULTS_ROOT=/scratch/$USER/globtim_results
    mkdir -p $GLOBTIM_RESULTS_ROOT

See docs/RESULTS_ROOT_SETUP.md for details.
```

### 2. No Fallbacks - Fail Fast

The system **NEVER** falls back to:
- ❌ Project-local directories
- ❌ Current working directory
- ❌ Default paths

**This is intentional** - we want experiments to fail immediately if misconfigured, not silently write to unexpected locations.

### 3. Hierarchical Organization Only

All experiments MUST use:
```
$GLOBTIM_RESULTS_ROOT/{objective_name}/{experiment_id}_{timestamp}/
```

Flat structures like this are **REJECTED**:
```
❌ $GLOBTIM_RESULTS_ROOT/lv4d_GN10_deg4-6_domain0.1_20251016_115902/
```

### 4. StandardExperiment Integration

`StandardExperiment.run_standard_experiment()` automatically:
1. Validates `GLOBTIM_RESULTS_ROOT` is set
2. Checks for legacy path patterns
3. Warns if non-standard structure detected
4. Creates standard directory structure

## Validation Checklist

Before running experiments, verify:

```bash
# 1. Environment variable is set
echo $GLOBTIM_RESULTS_ROOT
# Should show: /Users/yourname/globtim_results (or similar)

# 2. Directory exists and is writable
ls -la $GLOBTIM_RESULTS_ROOT
touch $GLOBTIM_RESULTS_ROOT/.test && rm $GLOBTIM_RESULTS_ROOT/.test

# 3. Standard subdirectories exist
ls $GLOBTIM_RESULTS_ROOT
# Should show: batches/ indices/ and objective folders

# 4. Julia can validate configuration
julia --project=. -e 'using .OutputPathManager; validate_output_configuration()'
```

## Examples

### Example 1: Simple Experiment

```julia
using .OutputPathManager
using .StandardExperiment

# Create output directory
metadata = ExperimentMetadata("simple_test", "baseline")
output_dir = create_experiment_directory(metadata)

# Run experiment
result = run_standard_experiment(
    objective_function = x -> sum(x.^2),
    problem_params = (),
    domain_bounds = [(-1.0, 1.0), (-1.0, 1.0)],
    experiment_config = config,
    output_dir = output_dir,
    metadata = Dict("objective_name" => "simple_test")
)
```

### Example 2: Parameter Recovery

```julia
using .OutputPathManager

# Define true parameters
true_params = [1.875, 1.5, 0.1, 0.1]

# Create experiment metadata with parameters tracked
metadata = ExperimentMetadata(
    "lotka_volterra_4d",
    "param_recovery_baseline";
    params_dict = Dict(
        "GN" => 8,
        "domain_size" => 0.1,
        "true_params" => true_params
    )
)

output_dir = create_experiment_directory(metadata)

# Run experiment with recovery error tracking
result = run_standard_experiment(
    objective_function = lv4d_objective,
    problem_params = (α=1.2, β=0.8, γ=1.5, δ=0.7),
    domain_bounds = compute_domain_bounds(true_params, 0.1),
    experiment_config = config,
    output_dir = output_dir,
    metadata = Dict(
        "objective_name" => "lotka_volterra_4d",
        "experiment_type" => "parameter_recovery",
        "true_params" => true_params
    ),
    true_params = true_params  # Enables recovery_error calculation
)
```

### Example 3: Batch Experiments

```julia
using .OutputPathManager

batch_id = "lv4d_domain_sweep_$(Dates.format(now(), "yyyymmdd"))"
domain_sizes = [0.05, 0.1, 0.15, 0.2]

for (i, domain_size) in enumerate(domain_sizes)
    metadata = ExperimentMetadata(
        "lotka_volterra_4d",
        "$(batch_id)_exp$(i)";
        params_dict = Dict("domain_size" => domain_size, "batch_id" => batch_id)
    )

    output_dir = create_experiment_directory(metadata)

    result = run_standard_experiment(
        objective_function = lv4d_objective,
        problem_params = params,
        domain_bounds = compute_domain_bounds(true_params, domain_size),
        experiment_config = config,
        output_dir = output_dir,
        metadata = Dict(
            "objective_name" => "lotka_volterra_4d",
            "batch_id" => batch_id,
            "domain_size" => domain_size
        )
    )
end
```

## Troubleshooting

### Error: "GLOBTIM_RESULTS_ROOT not set"

**Solution:**
```bash
./scripts/setup_results_root.sh
source ~/.bashrc  # or ~/.zshrc
```

### Error: "Directory not writable"

**Solution:**
```bash
chmod -R u+w $GLOBTIM_RESULTS_ROOT
# Or on HPC:
chmod -R u+w /scratch/$USER/globtim_results
```

### Warning: "Legacy path pattern detected"

**Solution:** Update experiment script to use `OutputPathManager`:
```julia
# Before (legacy)
output_dir = "hpc_results/my_experiment"

# After (standard)
metadata = ExperimentMetadata("my_objective", "my_experiment")
output_dir = create_experiment_directory(metadata)
```

### Error: "Experiment directory already exists"

This means you ran the same experiment twice in the same second.

**Solution:** Use unique experiment IDs:
```julia
metadata = ExperimentMetadata("objective_name", "unique_id_$(rand(1000:9999))")
```

## Related Documentation

- **Setup Guide**: [RESULTS_ROOT_SETUP.md](RESULTS_ROOT_SETUP.md)
- **Output Schema**: [OUTPUT_STANDARDIZATION_GUIDE.md](OUTPUT_STANDARDIZATION_GUIDE.md)
- **Batch System**: [BatchManifest.jl](../src/BatchManifest.jl)
- **Standard Experiment**: [StandardExperiment.jl](../src/StandardExperiment.jl)

## Summary

✅ **DO THIS:**
1. Run `./scripts/setup_results_root.sh` once
2. Use `OutputPathManager.create_experiment_directory()` for all experiments
3. Let `StandardExperiment` handle validation automatically
4. Organize experiments by objective function name

❌ **DON'T DO THIS:**
1. Don't hardcode `hpc_results/` or `local_results/`
2. Don't create flat directory structures
3. Don't bypass `GLOBTIM_RESULTS_ROOT`
4. Don't use arbitrary output directories

**This system is now ENFORCED - all experiments must comply.**
