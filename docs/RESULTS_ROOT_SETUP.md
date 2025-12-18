# GLOBTIM_RESULTS_ROOT - Centralized Results Directory Setup

**Created:** 2025-10-09
**Issue:** #145
**Status:** ✅ Implemented

---

## Overview

The `GLOBTIM_RESULTS_ROOT` environment variable provides centralized, validated path resolution for experiment results. This prevents hardcoded paths, improves portability, and enables consistent results organization across local and HPC environments.

**Key Benefits:**
- ✅ No more hardcoded relative paths (`hpc_results/...`)
- ✅ Works consistently from any working directory
- ✅ Automatic path validation and directory creation
- ✅ Write permission checks before experiments start
- ✅ Clear separation between code and results

---

## Quick Start

### 1. Set Environment Variable

Add to your shell configuration (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
# Set results root directory
export GLOBTIM_RESULTS_ROOT="$HOME/globtim_results"
```

**For HPC environments:**
```bash
# Use scratch space or project directory
export GLOBTIM_RESULTS_ROOT="/scratch/$USER/globtim_results"
```

### 2. Verify Setup

```julia
julia> using Pkg; Pkg.activate("/path/to/globtimcore")
julia> include("src/PathUtils.jl")
julia> using .PathUtils
julia> get_results_root()
"/Users/yourname/GlobalOptim/globtim_results"
```

### 3. Run Experiments

Experiments will now automatically store results in the centralized location:

```bash
cd globtimcore/experiments/daisy_ex3_4d_study
julia --project=../../ setup_experiments.jl
```

Results will be organized as:
```
$GLOBTIM_RESULTS_ROOT/
├── batches/
│   └── lv4d_20251009/
│       ├── exp_1_range0.4_120453/
│       ├── exp_2_range0.8_120454/
│       ├── exp_3_range1.2_120455/
│       └── exp_4_range1.6_120456/
└── indices/
    ├── computation_index.json
    └── batch_index.json
```

---

## Implementation Details

### Function: `get_results_root()`

**Location:** `src/PathUtils.jl`

**Resolution order:**
1. **`GLOBTIM_RESULTS_ROOT` environment variable** (if set)
   - Validates directory exists or can be created
   - Checks write permissions
   - Returns absolute path

2. **Fallback to `GlobalOptim/globtim_results`** (default)
   - Uses parent directory of project root
   - Creates directory if needed
   - Validates write permissions
   - Keeps results alongside code repos but in separate directory

**Example usage in experiment scripts:**

```julia
using .PathUtils

# Get centralized results root
results_root = get_results_root()

# Create batch directory
batch_name = "lv4d_$(Dates.format(now(), "yyyymmdd"))"
batch_dir = joinpath(results_root, "batches", batch_name)

# Create experiment-specific results directory
experiment_id = 1
results_dir = joinpath(batch_dir, "exp_$(experiment_id)_$(timestamp)")
mkpath(results_dir)
```

---

## Recommended Directory Structure

```
$GLOBTIM_RESULTS_ROOT/
├── batches/                          # Organized by batch name
│   ├── lv4d_20251009/               # Batch: Lotka-Volterra 4D study
│   │   ├── batch_manifest.json      # Batch metadata (future)
│   │   ├── exp_1_range0.4_120453/   # Individual experiment results
│   │   │   ├── experiment_config.json
│   │   │   ├── experiment_results.json
│   │   │   ├── degree_4_results.csv
│   │   │   ├── degree_5_results.csv
│   │   │   └── ...
│   │   ├── exp_2_range0.8_120454/
│   │   └── ...
│   │
│   ├── param_sweep_20251010/        # Another batch
│   │   └── ...
│   │
│   └── adaptive_test_20251011/      # Yet another batch
│       └── ...
│
└── indices/                          # Cross-batch tracking (future)
    ├── computation_index.json       # All computations with metadata
    └── batch_index.json             # All batches with status
```

---

## Migration Guide

### Existing Experiments

**Old approach (hardcoded relative path):**
```julia
results_dir = "hpc_results/experiment_$(id)_$(timestamp)"
mkpath(results_dir)
```

**New approach (centralized):**
```julia
using .PathUtils

results_root = get_results_root()
batch_name = "my_study_$(Dates.format(now(), "yyyymmdd"))"
batch_dir = joinpath(results_root, "batches", batch_name)
results_dir = joinpath(batch_dir, "exp_$(id)_$(timestamp)")
mkpath(results_dir)
```

### Updated Experiment Templates

The following files have been updated to use `get_results_root()`:
- `experiments/daisy_ex3_4d_study/setup_experiments.jl` (line 154-159)
- `experiments/daisy_ex3_4d_study/setup_single_exp_GN6.jl` (line 146-152)

**All future experiment setup scripts should follow this pattern.**

---

## Testing

### Automated Tests

Comprehensive test suite in `test/test_pathutils.jl`:

```bash
cd globtimcore
julia --project=. test/test_pathutils.jl
```

**Test coverage:**
- ✅ Environment variable resolution
- ✅ Fallback to `$HOME/globtim_results`
- ✅ Directory creation and validation
- ✅ Write permission checks
- ✅ Error handling for invalid paths
- ✅ Recommended directory structure creation

### Manual Testing

Test the setup interactively:

```julia
using Pkg
Pkg.activate(".")

include("src/PathUtils.jl")
using .PathUtils

# Test basic resolution
results_root = get_results_root()
println("Results root: ", results_root)
println("Exists: ", isdir(results_root))
println("Writable: ", iswritable(results_root))

# Test batch directory creation
using Dates
batch_name = "test_batch_$(Dates.format(now(), "yyyymmdd"))"
batch_dir = joinpath(results_root, "batches", batch_name)
mkpath(batch_dir)
println("Created batch directory: ", batch_dir)

# Cleanup
rm(batch_dir, recursive=true)
```

---

## Troubleshooting

### Issue: "Cannot determine results root directory"

**Cause:** Neither `GLOBTIM_RESULTS_ROOT` nor `HOME` environment variables are set.

**Solution:**
```bash
export GLOBTIM_RESULTS_ROOT="/path/to/your/results"
```

---

### Issue: "GLOBTIM_RESULTS_ROOT exists but is not writable"

**Cause:** The specified directory has incorrect permissions.

**Solution:**
```bash
chmod u+w $GLOBTIM_RESULTS_ROOT
# Or set to a different directory
export GLOBTIM_RESULTS_ROOT="$HOME/globtim_results"
```

---

### Issue: Results appearing in unexpected location

**Cause:** `GLOBTIM_RESULTS_ROOT` is set to a different path than expected.

**Debugging:**
```bash
echo $GLOBTIM_RESULTS_ROOT
# Check what Julia sees
julia -e 'println(get(ENV, "GLOBTIM_RESULTS_ROOT", "NOT SET"))'
```

---

### Issue: Permission denied when creating directories

**Cause:** Parent directory doesn't exist or isn't writable.

**Solution:**
```bash
# Ensure parent directory exists and is writable
mkdir -p $(dirname $GLOBTIM_RESULTS_ROOT)
chmod u+w $(dirname $GLOBTIM_RESULTS_ROOT)
```

---

## HPC-Specific Configuration

### SLURM Job Scripts

Include in your SLURM submission script:

```bash
#!/bin/bash
#SBATCH --job-name=globtim_exp
#SBATCH --output=logs/%j.out
#SBATCH --error=logs/%j.err

# Set results root to scratch space
export GLOBTIM_RESULTS_ROOT="/scratch/$USER/globtim_results"

# Run experiment
julia --project=/path/to/globtimcore experiments/my_experiment/run.jl
```

### Cluster-Specific Locations

**Recommended locations by cluster type:**

| Cluster | Recommended Path | Reason |
|---------|-----------------|--------|
| Local workstation | `$HOME/globtim_results` | Persistent, backed up |
| HPC scratch | `/scratch/$USER/globtim_results` | Fast I/O, large quota |
| HPC project space | `/projects/myproject/globtim_results` | Shared, persistent |
| Cloud storage | `/mnt/s3bucket/globtim_results` | Long-term archival |

---

## Future Enhancements

### Planned Features

1. **Batch manifest integration** (Issue #135)
   - Automatic batch metadata generation
   - Batch-level status tracking
   - Integration with `BatchManifest.jl`

2. **Results discovery utilities**
   - `find_batch_results(batch_name)` helper
   - Cross-batch search and aggregation
   - Automatic index updates

3. **Archival and cleanup tools**
   - `archive_batch(batch_name, dest)` for long-term storage
   - `cleanup_incomplete_batches()` for failed experiments
   - Retention policies

4. **Integration with postprocessing**
   - Automatic discovery of batch results
   - Unified results loading across tools
   - Standardized metadata queries

---

## Related Documentation

- **Issue #145:** [P1] Standardize Output Path Resolution with GLOBTIM_RESULTS_ROOT
- **Issue #135:** PathUtils module implementation
- `src/PathUtils.jl` - Implementation source code
- `test/test_pathutils.jl` - Test suite
- `EXPERIMENT_INFRASTRUCTURE_REVIEW.md` - Overall infrastructure analysis

---

## Summary

The `GLOBTIM_RESULTS_ROOT` system provides:

✅ **Portability** - Works across local and HPC environments
✅ **Safety** - Validates paths and permissions before execution
✅ **Organization** - Centralized, structured results storage
✅ **Maintainability** - Single environment variable to configure
✅ **Reproducibility** - Consistent paths regardless of working directory

**Next steps:**
1. Set `GLOBTIM_RESULTS_ROOT` in your environment
2. Re-run experiment setup scripts (they'll use the new system)
3. Update any custom experiment scripts to use `get_results_root()`
4. Run tests to verify setup: `julia --project=. test/test_pathutils.jl`

---

**Document Version:** 1.0
**Last Updated:** 2025-10-09
**Maintainer:** GlobTim Infrastructure Team
