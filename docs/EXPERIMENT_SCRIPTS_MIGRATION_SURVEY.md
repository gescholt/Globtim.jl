# Experiment Scripts Migration Survey
**Date:** 2025-10-20
**Purpose:** Identify which experiment scripts need migration to StandardExperiment.jl (v1.1.0 format)

## Summary

**Total experiment scripts:** 20
**Using OLD API (process_crit_pts):** 9 scripts
**Using NEW API (StandardExperiment):** 0 scripts
**Test/validation scripts:** 11 scripts

## Migration Required: Active Experiment Scripts (9 files)

### 1. Template System
- **File:** `tools/mcp/templates/lv4d_template.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** **CRITICAL** - generates all new experiments
- **Impact:** High - all MCP-generated experiments use old format
- **Lines:** ~550 lines

### 2. LV4D Campaign 2025 (4 files)
All scripts in `experiments/lv4d_campaign_2025/`:

#### `run_lv4d_experiment.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** HIGH - main campaign experiment runner
- **Used by:** Recent experiments (Oct 2025)

#### `launch_deg18_experiment.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** HIGH - degree 18 experiments
- **Used by:** Template as base_script reference

#### `launch_deg12_domain_sweep.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** HIGH - domain sweep studies

#### `basis_comparison_experiment.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** MEDIUM - basis comparison studies

### 3. LV4D Loss Comparison 2025 (2 files)
All scripts in `experiments/lv4d_loss_comparison_2025/`:

#### `run_constrained_lv_log_loss.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** HIGH - log-scale loss experiments
- **Used by:** Recent constrained experiments (Oct 20, 2025)

#### `run_constrained_lv_raw_loss.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** HIGH - raw loss experiments
- **Used by:** Recent constrained experiments (Oct 20, 2025)

### 4. Generated Experiments (1 file)
- **File:** `experiments/generated/lv4d_deg4-12_domain0.1_GN12_20251016_134239.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** LOW - auto-generated from old template
- **Note:** Will be replaced when template updated

### 5. Legacy Studies (2 files)
From `experiments/daisy_ex3_4d_study/`:

#### `setup_experiments.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** LOW - legacy study setup

#### `setup_single_exp_GN6.jl`
- **Status:** ❌ OLD API (process_crit_pts)
- **Priority:** LOW - legacy single experiment

## No Migration Needed: Test/Validation Scripts (11 files)

### Test Scripts (6 files)
- `experiments/lv4d_campaign_2025/test_degree4_only.jl`
- `experiments/lv4d_campaign_2025/test_standard_experiment.jl` ✅ Already uses StandardExperiment!
- `experiments/lv4d_loss_comparison_2025/test_constrained_lv_model.jl`
- `experiments/lv4d_loss_comparison_2025/test_generalized_lv_model.jl`
- `experiments/daisy_ex3_4d_study/quick_validation.jl`
- `experiments/daisy_ex3_4d_study/simple_validation.jl`

### Setup/Validation Scripts (5 files)
- `experiments/lv4d_campaign_2025/collect_campaign_results.jl`
- `experiments/lv4d_campaign_2025/launch_lv4d_dummy.jl`
- `experiments/daisy_ex3_4d_study/setup_experiments_with_index.jl`
- `experiments/daisy_ex3_4d_study/validate_environment.jl`
- `experiments/daisy_ex3_4d_study/validate_setup.jl`

## Migration Priority

### Phase 1: CRITICAL (Template)
1. ✅ **`tools/mcp/templates/lv4d_template.jl`** - Update to StandardExperiment
   - Archive old version to `tools/mcp/templates/archive/lv4d_template_v1.0_OLD.jl`
   - Update to use StandardExperiment.jl
   - Generate v1.1.0 format with refinement data

### Phase 2: HIGH Priority (Active Campaign Scripts - 6 files)
2. **`experiments/lv4d_campaign_2025/run_lv4d_experiment.jl`**
3. **`experiments/lv4d_campaign_2025/launch_deg18_experiment.jl`**
4. **`experiments/lv4d_campaign_2025/launch_deg12_domain_sweep.jl`**
5. **`experiments/lv4d_loss_comparison_2025/run_constrained_lv_log_loss.jl`**
6. **`experiments/lv4d_loss_comparison_2025/run_constrained_lv_raw_loss.jl`**

### Phase 3: MEDIUM Priority (1 file)
7. **`experiments/lv4d_campaign_2025/basis_comparison_experiment.jl`**

### Phase 4: LOW Priority (Legacy - 3 files)
8. `experiments/generated/lv4d_deg4-12_domain0.1_GN12_20251016_134239.jl` (regenerate from new template)
9. `experiments/daisy_ex3_4d_study/setup_experiments.jl`
10. `experiments/daisy_ex3_4d_study/setup_single_exp_GN6.jl`

## Expected Impact

### After Template Migration
- **New experiments:** All MCP-generated experiments will use v1.1.0 format
- **CSV output:** Include both raw and refined critical points (12 columns vs 5)
- **JSON output:** Include refinement_stats and schema_version fields
- **Backward compatibility:** Old experiments still readable, new validation tests pass

### After Campaign Scripts Migration
- **Future runs:** All active experiment campaigns will generate v1.1.0 data
- **Data quality:** Refinement statistics available for all new results
- **Analysis:** Can track refinement convergence and quality metrics

## StandardExperiment.jl API Reference

### Old API (process_crit_pts)
```julia
# Polynomial construction
pol = Constructor(TR, (:one_d_for_all, degree), basis=:chebyshev)

# Solve for critical points
real_pts, (pol_sys, system, nsols) = solve_polynomial_system(...)

# Process critical points (OLD)
df_critical = process_crit_pts(real_pts, error_func, TR)

# Save manually
CSV.write("critical_points_deg_$degree.csv", df_critical)
```

### New API (StandardExperiment)
```julia
using .StandardExperiment

# Configuration
config = ExperimentConfig(
    GN = 12,
    degree_range = 4:2:12,
    domain_size = 0.1,
    max_time = 300.0
)

# System definition
system_def = SystemDefinition(
    dimension = 4,
    objective_function = error_func,
    domain_bounds = [...],
    true_params = p_true,
    metadata = Dict(...)
)

# Run experiment (handles everything)
result = run_standard_experiment(config, system_def, output_dir)

# Automatically generates:
# - critical_points_deg_N.csv (with refinement columns)
# - results_summary.json (with schema v1.1.0)
# - All timing and quality metrics
```

## Related Issues
- **Issue #110:** Extend Experiment Schema v1.1.0 for Refinement Data
- **Issue #109:** Add Optim.jl Refinement Pipeline for Critical Points

## Next Steps
1. Update template (Phase 1) ✅ PRIORITY
2. Test template generates v1.1.0 output correctly
3. Migrate active campaign scripts (Phase 2)
4. Update documentation with migration guide
5. Close Issue #110 when validation tests added
