# Critical Points Data Loss - Root Cause Analysis & Fix

**Date:** 2025-10-02
**Severity:** CRITICAL
**Status:** ✅ FIXED (with validation enforcement)

---

## Executive Summary

**Problem:** Critical points from experiments were being **silently discarded** due to overly aggressive domain filtering, resulting in complete data loss for yesterday's experiments.

**Root Cause:** Conditional CSV export (`if n_valid > 0`) combined with domain filtering that removed ALL critical points.

**Impact:** All experiments from Oct 1 that found critical points outside domain bounds lost their data.

**Solution:**
1. ✅ Unconditional CSV export (ALWAYS save critical points)
2. ✅ Validation hook to prevent future occurrences
3. ⏳ Template fixes (in progress)

---

## Technical Analysis

### What Happened

**Experiment:** `4dlv_param_recovery_GN=5_domain_size_param=0.3_max_time=60.0_20251001_131009`

```json
{
  "critical_points": 0,           // ❌ Reported as 0
  "critical_points_refined": 17   // ✅ Actually found 17 points!
}
```

**Data Flow:**
1. HomotopyContinuation finds 17 raw critical points ✅
2. Optim.jl refines all 17 points successfully ✅
3. Domain filter applied: `filter_points_to_domain(refined_points, [-0.3, 0.3]^4)`
4. **Result: 0 points** (all 17 outside domain) ❌
5. Conditional export: `if n_valid > 0` → **no CSV saved** ❌
6. **SILENT DATA LOSS** ❌

### Why This Violates Design Principles

From CLAUDE.md:
> "I don't want any fallbacks in the code -- I want to see errors when something is not working, not a fake version of it"

The code **silently failed** instead of:
- Saving the points anyway
- Warning the user loudly
- Erroring on missing data

---

## The Fix

### 1. Parameter Recovery Template (✅ FIXED)

**File:** `Examples/4DLV/parameter_recovery_experiment.jl`

**Before (lines 345-412):**
```julia
# Filter to domain
valid_critical_points = filter_points_to_domain(refined_points, domain_bounds)
n_valid = length(valid_critical_points)

if n_valid > 0  # ❌ CONDITIONAL - CAUSES DATA LOSS
    CSV.write("$output_dir/critical_points_deg_$degree.csv", df_critical)
else
    println("⚠️  Warning: ...No CSV file saved")  # ❌ SILENT FAILURE
end
```

**After (lines 345-432):**
```julia
# Process ALL critical points (no filtering for export)
n_converged = length(refined_points)

if n_converged == 0
    error("❌ CRITICAL: No critical points found")  # ✅ FAIL LOUDLY
end

# ALWAYS create DataFrame with ALL critical points
df_critical = DataFrame(
    theta1 = [refined_points[i][1] for i in 1:n_converged],
    # ... all points ...
)

# Mark in_domain status (for analysis, not deletion)
df_critical.in_domain = [all(domain_bounds[i][1] <= refined_points[j][i] <= domain_bounds[i][2] for i in 1:4) for j in 1:n_converged]

# UNCONDITIONAL save
CSV.write("$output_dir/critical_points_deg_$degree.csv", df_critical)  # ✅ ALWAYS
println("💾 Saved critical_points_deg_$degree.csv ($n_converged points)")
```

**Key Changes:**
- ✅ Unconditional CSV export
- ✅ Add `in_domain` column for post-analysis filtering
- ✅ Error loudly if no points found
- ✅ Report both total and in-domain counts
- ✅ Still report "best estimate" even if outside domain

**CSV Schema Update:**
```csv
theta1_raw,theta2_raw,theta3_raw,theta4_raw,theta1,theta2,theta3,theta4,objective_raw,objective,recovery_error,l2_approx_error,refinement_improvement,in_domain
```

New column: `in_domain` (boolean) - allows post-processing to filter if needed

---

### 2. Validation Hook (✅ NEW)

**File:** `tools/hpc/hooks/critical_points_validator.sh`

**Purpose:** Prevent future data loss by enforcing CSV export

**Trigger:** `post_experiment` (after completion)

**Validation:**
1. ❌ **CRITICAL FAILURE** if no `critical_points_deg_*.csv` files exist
2. ⚠️  **WARNING** if CSV files are empty or missing columns
3. ✅ **PASS** if valid CSV files found

**Exit Codes:**
- `0` = Validation passed
- `1` = Critical failure (experiment fails)
- `2` = Warning (experiment succeeds with warnings)

**Registration:** `hook_registry.json`
```json
{
  "critical_points_validator": {
    "priority": 21,
    "critical": true,
    "description": "MANDATORY validation - prevents silent data loss"
  }
}
```

**Test Results:**
```bash
# Failed experiment (no CSV)
$ ./critical_points_validator.sh hpc_results/4dlv_param_recovery.../
❌ CRITICAL VALIDATION FAILURE
No critical_points_deg_*.csv files found
EXIT CODE: 1

# Successful experiment
$ ./critical_points_validator.sh hpc_results/lv4d_float64_0.15.../
✓ Found 9 critical points CSV file(s)
  ✓ critical_points_deg_4.csv: 55 critical points
  ...
✅ Critical points validation PASSED
EXIT CODE: 0
```

---

## Templates Still Needing Fixes

### High Priority (Frequently Used)

**`Examples/minimal_4d_lv_test.jl` (lines 296-324)**
- Status: ❌ Still has conditional export
- Usage: Most common cluster test template
- Fix: Apply same pattern as parameter_recovery_experiment.jl

**`Examples/cluster_4d_lv_pipeline_test.jl`**
- Status: ❌ Needs verification
- Usage: Pipeline integration tests

**`Examples/tiny_4d_lv_cluster_test.jl`**
- Status: ❌ Needs verification
- Usage: Quick validation tests

### Medium Priority (Generated Experiments)

**`Examples/4DLV/experiments_2025_10_01/exp_*.jl` (12 files)**
- Status: ❌ All generated from template
- Fix: Regenerate from fixed template OR apply patch

### Low Priority (Legacy/Archive)

**`experiments/lotka_volterra_4d_study/configs_20250915_224434/lotka_volterra_4d_exp*.jl`**
- Status: ⏸️  Archived experiments
- Action: Document but don't fix (archive)

---

## Results Summary Schema Update

**Old Schema (v1.1.0):**
```json
{
  "critical_points": 0  // ❌ Ambiguous - means "in domain" not "total"
}
```

**New Schema (v1.1.1 proposal):**
```json
{
  "critical_points": 17,              // Total refined points saved to CSV
  "critical_points_in_domain": 0,     // Subset within domain bounds
  "best_estimate": [0.14, -0.09, ...],  // Always present (even if outside domain)
  "recovery_error": 0.02              // Always present
}
```

**Backwards Compatibility:**
- `critical_points` changes meaning (breaking change)
- Plotting code should use `critical_points_in_domain` for domain-filtered analysis
- Old experiments will show misleading counts

---

## Verification Checklist

### Cluster Environment ✅
- [x] CSV package installed (v0.10.15)
- [x] DataFrames available
- [x] Hook executable permissions
- [ ] Test experiment run on cluster

### Hook Integration ✅
- [x] Hook registered in `hook_registry.json`
- [x] Priority set correctly (21 - after metadata but before analysis)
- [x] Critical flag set
- [x] Tested on failed experiment (exit 1)
- [x] Tested on successful experiment (exit 0)

### Template Fixes ⏳
- [x] parameter_recovery_experiment.jl
- [ ] minimal_4d_lv_test.jl
- [ ] cluster_4d_lv_pipeline_test.jl
- [ ] tiny_4d_lv_cluster_test.jl

---

## Testing Protocol

### Local Test
```bash
cd /Users/ghscholt/GlobalOptim/globtimcore

# Run fixed experiment template
julia --project=. Examples/4DLV/parameter_recovery_experiment.jl \
  --domain=0.3 --GN=5 --degrees=4:4

# Verify CSV exists
ls hpc_results/4dlv_param_recovery_*/critical_points_deg_*.csv

# Validate with hook
tools/hpc/hooks/critical_points_validator.sh hpc_results/4dlv_param_recovery_*/
```

### Cluster Test
```bash
# Launch experiment
./scripts/test_session_tracking_launcher.sh

# After completion, validate
ssh scholten@r04n02 '
  cd /home/scholten/globtimcore
  tools/hpc/hooks/critical_points_validator.sh hpc_results/$(ls -t hpc_results | head -1)/
'
```

---

## Lessons Learned

### Design Anti-Patterns Identified

**1. Silent Failure on Data Loss**
- ❌ `if n_valid > 0` → skip save
- ✅ Always save, error if impossible

**2. Filtering Before Persistence**
- ❌ Filter → save filtered data
- ✅ Save all → filter in analysis

**3. Implicit Assumptions**
- ❌ "Points will be in domain"
- ✅ Expect edge cases, handle explicitly

### Best Practices Enforced

**1. Mandatory Validation**
- Hook enforces CSV existence
- Critical priority blocks pipeline

**2. Explicit Over Implicit**
- `in_domain` column vs silent filtering
- Clear distinction: total vs filtered counts

**3. Fail Loudly**
- `error()` when no points found
- Warnings escalate to user attention

---

## Migration Guide

### For Existing Experiments

**No action needed** - old experiments remain as-is, but:
- Understand `critical_points: 0` means "none in domain"
- Check JLD2 files for actual refined_points arrays

### For New Experiments

**Use fixed templates:**
```bash
# Parameter recovery
Examples/4DLV/parameter_recovery_experiment.jl

# General experiments (after fix applied)
Examples/minimal_4d_lv_test.jl
```

**Expect new CSV format:**
- `in_domain` column present
- All critical points included (not filtered)

### For Plotting Code

**Update to use new schema:**
```julia
# OLD
n_points = data["critical_points"]  # ❌ Ambiguous

# NEW
n_total = data["critical_points"]              # Total refined points
n_in_domain = data["critical_points_in_domain"]  # Filtered count

# For distance analysis, read CSV and filter by in_domain column
df = CSV.read("critical_points_deg_4.csv", DataFrame)
df_in_domain = filter(row -> row.in_domain, df)
```

---

## Impact Assessment

### Yesterday's Experiments (Oct 1, 2025)

**Affected Experiments:**
```
4dlv_param_recovery_GN=5_domain_size_param=0.3_max_time=60.0_20251001_131009  ❌ DATA LOST
4dlv_param_recovery_GN=5_domain_size_param=0.3_max_time=60.0_20251001_131234  ❌ DATA LOST
4dlv_param_recovery_GN=5_domain_size_param=0.3_max_time=60.0_20251001_131119  ❌ DATA LOST (incomplete)
```

**Can We Recover?**
- JLD2 files may contain refined_points arrays
- Check: `load("results_summary.jld2")["refined_points"]`
- If present, can reconstruct CSV manually

**Re-run Required?**
- Yes, to get validated results with fixed template
- Experiments run quickly (< 20s per degree)
- Use new template to ensure CSV export

---

## Next Steps

### Immediate (Today)
1. ✅ Fix parameter_recovery_experiment.jl
2. ✅ Create and register validation hook
3. ⏳ Fix minimal_4d_lv_test.jl
4. ⏳ Test locally with fixed templates
5. ⏳ Test on cluster with validation hook

### Short-term (This Week)
1. Fix remaining high-priority templates
2. Re-run yesterday's experiments with fixed templates
3. Update plotting code to handle new schema
4. Document new CSV format in CLUSTER_DATA_STANDARDS.md

### Long-term (October 2025)
1. Schema version bump to 1.1.1
2. Deprecation warning for old schema in plotting
3. Comprehensive template audit
4. Automated template validation in CI

---

## References

- **Fixed Template:** `Examples/4DLV/parameter_recovery_experiment.jl` (lines 345-432)
- **Validation Hook:** `tools/hpc/hooks/critical_points_validator.sh`
- **Hook Registry:** `tools/hpc/hooks/hook_registry.json` (line 155-165)
- **User Guidelines:** `~/.claude/CLAUDE.md` (no fallbacks, fail loudly)
- **Schema Docs:** `docs/CLUSTER_DATA_STANDARDS.md` (schema v1.1.0)
