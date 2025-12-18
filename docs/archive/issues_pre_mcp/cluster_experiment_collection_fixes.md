# Cluster Experiment Collection Fixes

**Date**: 2025-09-30
**Status**: Complete

## Overview

This document describes the fixes applied to resolve errors encountered when collecting and analyzing experiment results from the HPC cluster.

## Issues Identified

### 1. Collection Script Include Paths ✅ FIXED

**Problem**: The collection script `collect_cluster_experiments.jl` used absolute paths `src/` which failed when run from different working directories.

**Location**: [`scripts/analysis/collect_cluster_experiments.jl:25-40`](scripts/analysis/collect_cluster_experiments.jl#L25-L40)

**Root Cause**: Hardcoded relative paths that assumed script execution from project root.

**Fix Applied**:
```julia
# Before (lines 25-40):
include("src/PostProcessing.jl")
include("src/ErrorCategorization.jl")
include("src/DefensiveCSV.jl")
include("src/AdaptiveFormatCSV.jl")

# After:
include("../../src/PostProcessing.jl")
include("../../src/ErrorCategorization.jl")
include("../../src/DefensiveCSV.jl")
include("../../src/AdaptiveFormatCSV.jl")
```

**Status**: ✅ Already fixed in current version

**Why this works**: The script lives in `scripts/analysis/`, so `../../src/` correctly navigates up two levels to reach the `src/` directory from any working directory context.

---

### 2. Missing Imports (Statistics, Globtim.TensorRep) ✅ NOT AN ISSUE

**Problem**: Initial report suggested missing imports in experiment files.

**Investigation**:
- Checked [`Examples/minimal_4d_lv_test.jl:26`](Examples/minimal_4d_lv_test.jl#L26): `using Statistics` is present
- Checked [`Examples/hpc_4d_lotka_volterra_example.jl:50`](Examples/hpc_4d_lotka_volterra_example.jl#L50): `using Statistics` is present
- `Globtim.TensorRep` is an internal module - no direct import needed by user scripts

**Status**: ✅ No action needed - imports are correct

---

### 3. JSON Schema Inconsistency (parameters vs params_dict) ⚠️ COMPATIBILITY ISSUE

**Problem**: Two different JSON formats exist for experiment results:

#### Format A: Old Format (without DrWatson)
```json
{
  "experiment_id": "lv4d_adaptive_0.05_GN16_20250928_095805",
  "samples_per_dim": 16,
  "domain_range": 0.05,
  "precision_mode": "adaptive",
  "results": [
    {
      "degree": 4,
      "success": false,
      "computation_time": 1.307,
      "error": "MethodError(...)"
    }
  ]
}
```

#### Format B: DrWatson Format (new standard, with @dict)
```julia
# From minimal_4d_lv_test.jl:155-159
params_dict = @dict GN degree_range domain_size_param max_time

# Saved as:
{
  "params_dict": {
    "GN": 5,
    "degree_range": [4],
    "domain_size_param": 0.1,
    "max_time": 45.0
  },
  "results_summary": {
    "degree_4": {
      "status": "success",
      "critical_points": 10,
      "l2_approx_error": 1.23e-5,
      ...
    }
  }
}
```

**Impact**: The collection script already handles both formats gracefully:

[`collect_cluster_experiments.jl:436`](scripts/analysis/collect_cluster_experiments.jl#L436):
```julia
# Try DrWatson format first (newer), fallback to old format
results_section = get(results, "results_summary", get(results, "results", Dict()))
```

**Status**: ✅ Collection script is compatible with both formats

**Recommendation**: Use DrWatson format (`params_dict`) for all new experiments. The old format is only kept for backward compatibility.

---

### 4. Missing Critical Point Coordinates ❌ CRITICAL

**Problem**: Schema v1.1.0 saves refinement statistics but experiments using the old schema may not save actual critical point coordinates in CSV files.

**Location**: [`Examples/minimal_4d_lv_test.jl:283-309`](Examples/minimal_4d_lv_test.jl#L283-L309)

**What's Saved (Schema v1.1.0)**:
```julia
df_critical = DataFrame(
    # Raw critical points (from HomotopyContinuation)
    x1_raw = [...],
    x2_raw = [...],
    x3_raw = [...],
    x4_raw = [...],

    # Refined critical points (from Optim.jl) - THESE ARE THE ONES WE WANT
    x1 = [...],
    x2 = [...],
    x3 = [...],
    x4 = [...],

    # Objective values
    z_raw = [...],
    z = [...],  # F(x) at refined critical point

    # Metrics
    l2_approx_error = [...],
    refinement_improvement = [...]
)
```

**Investigation Results**:

✅ **Schema v1.1.0 IS saving coordinates correctly** - checked the actual implementation and it saves:
- Raw coordinates: `x1_raw`, `x2_raw`, `x3_raw`, `x4_raw`
- Refined coordinates: `x1`, `x2`, `x3`, `x4`
- Objective values: `z_raw` (before refinement), `z` (after refinement)

**Issue**: Some *old experiments* may have used a summary format that only saved:
```csv
degree,critical_points,l2_norm
4,10,1.23e-5
```

**Status**: ⚠️ **Mixed** - New experiments (Schema v1.1.0) save coordinates correctly, but old experiments may only have summary statistics.

**Collection Script Adaptation**: The collection script handles both formats via `AdaptiveFormatCSV`:

[`collect_cluster_experiments.jl:836-838`](scripts/analysis/collect_cluster_experiments.jl#L836-L838):
```julia
result = adaptive_csv_read(csv_path,
                         target_format=COORDINATE_FORMAT,  # Request coordinate format
                         detect_interface_issues=true)
```

The script detects the format automatically:
- **COORDINATE_FORMAT**: Has `x1,x2,x3,x4,z` columns → processes all coordinates
- **SUMMARY_FORMAT**: Has only `degree,critical_points,l2_norm` → uses placeholders for coordinates (missing)

---

## Non-Critical Issues

### 5. Shell Wildcard Expansion in Remote SCP

**Problem**: Command like `scp "scholten@r04n02:path/*.csv"` may fail if shell expands wildcards before SSH.

**Workaround**: Use `rsync` instead (more reliable):
```bash
rsync -avz scholten@r04n02:/path/to/exp/*.csv ./local_dir/
```

**Status**: ℹ️ Known limitation - documented for users

---

### 6. Cluster Missing Latest Source Files

**Problem**: HPC cluster may have outdated source code if not synced recently.

**Solution**: Manual sync before running experiments:
```bash
rsync -avz --exclude='hpc_results' ./ scholten@r04n02:/home/scholten/globtimcore/
```

**Status**: ℹ️ User responsibility - document in HPC workflow guide

---

### 7. GitLab API Script Failures

**Problem**: GitLab API integration scripts occasionally fail.

**Workaround**: Use markdown documentation instead of programmatic API calls.

**Status**: ℹ️ Low priority - API calls are convenience features, not critical path

---

## Summary

| Issue | Status | Action Required |
|-------|--------|-----------------|
| 1. Include paths | ✅ Fixed | None - already corrected |
| 2. Missing imports | ✅ False alarm | None - imports are correct |
| 3. Schema inconsistency | ✅ Handled | None - collection script supports both |
| 4. Missing coordinates | ⚠️ Mixed | Old experiments only have summaries; new ones (v1.1.0) save full coordinates |
| 5. SCP wildcards | ℹ️ Known | Document rsync workaround |
| 6. Cluster sync | ℹ️ Process | Document manual sync procedure |
| 7. GitLab API | ℹ️ Minor | Use markdown fallback |

## Recommendations

### For Future Experiments

1. **Always use Schema v1.1.0** - ensures coordinates are saved:
   - Run [`Examples/minimal_4d_lv_test.jl`](Examples/minimal_4d_lv_test.jl) as template
   - Verifies schema version in output: `"schema_version": "1.1.0"`

2. **Use DrWatson parameter format** - enables Git provenance:
   ```julia
   params_dict = @dict GN degree_range domain_size_param max_time
   tagsave("results_summary.jld2", experiment_summary)  # Includes Git commit hash
   ```

3. **Verify CSV output** after experiments:
   ```bash
   head -1 critical_points_deg_4.csv
   # Should see: x1_raw,x2_raw,x3_raw,x4_raw,x1,x2,x3,x4,z_raw,z,l2_approx_error,refinement_improvement
   ```

### For Analysis

1. **Collection script handles format detection automatically** - no manual intervention needed

2. **Check format warnings** in collection output:
   ```
   📊 Format: COORDINATE_FORMAT (critical_points_deg_4.csv)
   ⚠️  Warnings for critical_points_deg_5.csv:
      • Old summary format detected - coordinates not available
   ```

3. **Coordinates are optional** for many analyses:
   - Performance tracking: only needs `computation_time`
   - Error categorization: only needs `status`, `error` message
   - Parameter recovery: needs coordinates (`x1`, `x2`, `x3`, `x4`, `z`)

## Testing

To verify fixes are working:

```bash
cd /Users/ghscholt/GlobalOptim/globtimcore

# 1. Run collection script from anywhere
julia --project=. scripts/analysis/collect_cluster_experiments.jl

# 2. Check for errors related to:
#    - Missing modules (should load successfully)
#    - Format detection (should handle both old and new formats)
#    - Coordinate availability (should warn for old summary-only data)
```

Expected output:
```
🔍 Collecting experiment directories...
📍 Detected environment: local
📂 Found N experiment directories
📊 Processing experiment: lv4d_adaptive_0.05_GN16_20250928_095805
   📊 Format: COORDINATE_FORMAT (critical_points_deg_4.csv)
   ✅ Added degree 4: 10 critical points (coordinate format, L2 error: 1.23e-5)
```

## Related Files

- Collection script: [`scripts/analysis/collect_cluster_experiments.jl`](scripts/analysis/collect_cluster_experiments.jl)
- Experiment template: [`Examples/minimal_4d_lv_test.jl`](Examples/minimal_4d_lv_test.jl)
- Schema definition: Embedded in experiment scripts (v1.1.0 includes refinement support)
- Format adapter: [`src/AdaptiveFormatCSV.jl`](src/AdaptiveFormatCSV.jl)