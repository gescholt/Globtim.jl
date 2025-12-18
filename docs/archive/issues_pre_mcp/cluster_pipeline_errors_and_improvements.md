# Cluster Pipeline Errors and Improvement Proposals

**Date**: 2025-09-30
**Context**: Cluster experiment campaign (7 new experiments, 24 total analyzed)
**Success Rate**: 95.8% (46/48 computations successful)

---

## 🔴 Critical Errors Encountered

### ERROR 1: Collection Script - Wrong Include Paths
**Location**: `scripts/analysis/collect_cluster_experiments.jl:25,33,37,40`
**Issue**: All module includes used wrong relative paths (`src/` instead of `../../src/`)

**Impact**: Collection script completely non-functional
**Root Cause**: Script assumes execution from wrong directory or expects different project structure

**Fix Applied**:
```julia
# Before
include("src/PostProcessing.jl")
include("src/ErrorCategorization.jl")
include("src/DefensiveCSV.jl")
include("src/AdaptiveFormatCSV.jl")

# After
include("../../src/PostProcessing.jl")
include("../../src/ErrorCategorization.jl")
include("../../src/DefensiveCSV.jl")
include("../../src/AdaptiveFormatCSV.jl")
```

**Proposal #1**: Use DrWatson's `projectdir()` for portable paths
```julia
include(projectdir("src", "PostProcessing.jl"))
include(projectdir("src", "ErrorCategorization.jl"))
include(projectdir("src", "DefensiveCSV.jl"))
include(projectdir("src", "AdaptiveFormatCSV.jl"))
```

**Related**: GitLab Issue - DrWatson Integration Enhancement (documented in `docs/issues/drwatson_enhancement_proposal.md`)

---

### ERROR 2: Experiment Failures - Missing Imports
**Location**: 2 experiment runs failed during cluster execution
**Failures**:
1. `UndefVarError(:TensorRep, Globtim)` - Missing `using Globtim.TensorRep`
2. `UndefVarError(:mean, Main)` - Missing `using Statistics`

**Impact**: 2/48 computations failed (4.2% failure rate)
**Root Cause**: Incomplete imports in experiment script

**Fix Required**: Add missing imports to `Examples/minimal_4d_lv_test.jl`
```julia
using Statistics  # For mean() in refinement stats
using Globtim.TensorRep  # If using TensorRep functionality
```

**Proposal #2**: Add import validation test
- Create smoke test that loads experiment script without running it
- Verify all required functions are accessible
- Run as CI check before cluster deployment

---

### ERROR 3: JSON Schema Inconsistency
**Location**: Result validation found inconsistent JSON structure across experiments
**Old Format** (5 experiments, pre-Sept 30):
```json
{
  "parameters": {...},
  "results": {...},
  "summary": {...}
}
```

**New Format** (19 experiments, Sept 30+):
```json
{
  "params_dict": {...},
  "results_summary": {...},
  "success_rate": 1.0,
  "total_time": 58.6
}
```

**Impact**: Collection script must handle both formats defensively
**Root Cause**: Schema evolved but old results not migrated

**Proposal #3**: Implement schema versioning and migration
```julia
function normalize_experiment_json(data::Dict)
    # Detect schema version
    version = get(data, "schema_version", "1.0.0")

    if version == "1.0.0"
        # Migrate old format to new format
        return Dict(
            "schema_version" => "1.1.0",
            "params_dict" => data["parameters"],
            "results_summary" => data["results"],
            ...
        )
    end

    return data
end
```

**Proposal #4**: Add explicit schema_version to ALL output
- Currently only saved in JLD2, not always in JSON
- Make schema_version top-level required field
- Document schema changes in CHANGELOG

---

### ERROR 4: Missing Critical Point Data in JLD2
**Location**: All JLD2 files missing `raw_critical_points` and `refined_critical_points` arrays
**Expected** (Schema v1.1.0):
```julia
Dict(
    "raw_critical_points" => [...],      # HC.jl output coordinates
    "refined_critical_points" => [...],  # Optim.jl refined coordinates
    "refinement_stats" => {...}
)
```

**Actual**:
```julia
Dict(
    "results_summary" => Dict(
        "degree_4" => Dict(
            "critical_points_raw" => 3,      # Only counts, not coordinates
            "critical_points_refined" => 3,
            "refinement_stats" => {...}
        )
    )
)
```

**Impact**: Cannot perform post-hoc analysis on actual critical point locations
**Root Cause**: Code computes `raw_points` and `refined_points` locally but never saves them

**Proposal #5**: Save actual critical point arrays
```julia
# In minimal_4d_lv_test.jl, add to results_summary:
results_summary["degree_$degree"]["raw_critical_points_data"] = raw_points
results_summary["degree_$degree"]["refined_critical_points_data"] = refined_points

# Or save separately for large datasets:
jldsave("$output_dir/critical_points_deg_$degree.jld2";
    raw=raw_points,
    refined=refined_points,
    convergence=refinement_results
)
```

**Trade-off**: Disk space vs. reproducibility
- Small experiments (deg 4-7): Save full point arrays (~KB per degree)
- Large experiments (deg 8+): Save only top-N by objective value or filtered by domain

---

## ⚠️ Non-Critical Issues

### Issue 1: Shell Wildcard Expansion in Remote SCP
**Command**: `scp scholten@r04n02:/path/to/minimal_*`
**Error**: `no matches found: scholten@r04n02:/path/to/minimal_*`
**Root Cause**: Local shell tries to expand wildcards before SSH

**Workaround Used**: `rsync` with include patterns
```bash
rsync -avz scholten@r04n02:/home/scholten/globtimcore/hpc_results/ \
    globtimcore/hpc_results/ \
    --include='minimal_4d_lv_test_*/**' \
    --include='minimal_4d_lv_test_*' \
    --exclude='*'
```

**Proposal #6**: Standardize on rsync for all cluster transfers
- More reliable wildcard handling
- Supports incremental sync (faster for repeated downloads)
- Better progress reporting
- Document in `scripts/cluster/README.md`

---

### Issue 2: Missing CriticalPointRefinement.jl on Cluster
**Error**: `SystemError: opening file "/home/scholten/globtimcore/src/CriticalPointRefinement.jl": No such file or directory`
**Root Cause**: Local repo had newer files than cluster

**Fix Applied**: `scp src/CriticalPointRefinement.jl scholten@r04n02:/home/scholten/globtimcore/src/`

**Proposal #7**: Automated cluster sync before experiment launch
```bash
# In launch_4d_lv_campaign.sh, add pre-flight sync:
echo "📦 Syncing codebase to cluster..."
rsync -avz --exclude='hpc_results/' \
    src/ Examples/ scripts/ Project.toml \
    scholten@r04n02:/home/scholten/globtimcore/

echo "✅ Cluster sync complete"
```

**Proposal #8**: Add version check in experiment scripts
```julia
# At start of minimal_4d_lv_test.jl
@assert @isdefined(refine_critical_points_batch) "Missing CriticalPointRefinement.jl - sync codebase"
@assert hasmethod(mean, (Vector{Float64},)) "Missing Statistics import"
```

---

### Issue 3: GitLab API Script Failure
**Context**: Attempted to create GitLab issue via `enhanced-gitlab-api.sh`
**Error**: `jq: invalid JSON text passed to --argjson` and `{"error":"title is missing"}`
**Root Cause**: Argument parsing issues in bash script

**Workaround**: Created markdown documentation instead
**Status**: Low priority - markdown approach works well for documentation

**Proposal #9**: Deprecate `enhanced-gitlab-api.sh` or fix argument parsing
- If rarely used: document that markdown is preferred approach
- If frequently used: debug jq command and add test suite
- Consider switching to `gh` CLI or `glab` CLI instead of custom bash

---

## 🎯 Performance Analysis Insights

### Timing Breakdown (from successful experiments)
- **Polynomial Construction**: 0.02s - 2.8s (highly variable based on GN)
- **Critical Point Solving**: 5.5s - 54s (dominates runtime, 80-95%)
- **Refinement**: Included in solving time (need separate tracking)
- **File I/O**: <0.001s (negligible)

**Proposal #10**: Optimize critical point solving phase
- Profile HomotopyContinuation.jl to identify bottlenecks
- Consider parallel solving for multiple degrees
- Investigate adaptive timeout based on problem size

### Domain Size Impact
- `domain=0.1`: Mean 8.6s per computation
- `domain=0.15`: Mean 19.8s per computation
- `domain=0.2`: Mean 28.6s per computation
- `domain=0.5`: Mean 9.9s per computation (fewer critical points found)

**Observation**: Runtime scales non-linearly with domain size, likely due to critical point count

### Grid Resolution (GN) Impact
- `GN=4` (256 grid points): 16.3s (degree 3)
- `GN=5` (625 grid points): 17-53s (degree 4-5)
- `GN=6` (1296 grid points): 22s (degree 4-6)
- `GN=8` (4096 grid points): 20s (degree 4-7, small domain)

**Observation**: GN=8 with small domain (0.1) is faster than GN=5 with large domain (0.15)

**Proposal #11**: Create performance model for parameter selection
```julia
function estimate_runtime(GN::Int, degree::Int, domain::Float64)
    # Empirical model from cluster data
    base_time = GN^1.5 * degree^2 * domain^1.8
    return base_time  # Returns estimated seconds
end
```

---

## 📊 Success Rate Analysis

**Overall**: 95.8% (46/48 computations)

**By Degree**:
- Degree 3: 100% (1/1)
- Degree 4: 91.3% (21/23) ← Both failures here
- Degree 5: 100% (18/18)
- Degree 6: 100% (4/4)
- Degree 7: 100% (2/2)

**Conclusion**: Degree 4 has lower reliability, likely due to import errors in specific runs (not mathematical failures)

---

## 🚀 Recommended Action Items (Priority Order)

### Priority 1: Immediate Fixes (Required for next cluster run)
1. ✅ Fix include paths in collection script (DONE)
2. ⬜ Add missing imports to `minimal_4d_lv_test.jl`
3. ⬜ Add automated cluster sync to launch script

### Priority 2: Data Completeness (Schema v1.1.0)
4. ⬜ Save raw and refined critical point arrays to JLD2
5. ⬜ Make `schema_version` mandatory in JSON output
6. ⬜ Document schema changes in project CHANGELOG

### Priority 3: Reliability Improvements
7. ⬜ Create smoke test for experiment script imports
8. ⬜ Add version/import checks at script startup
9. ⬜ Standardize on rsync for cluster transfers

### Priority 4: Developer Experience
10. ⬜ Implement DrWatson `projectdir()` for portable paths
11. ⬜ Create schema migration utility for old results
12. ⬜ Document cluster workflow in `scripts/cluster/README.md`

### Priority 5: Future Enhancements
13. ⬜ Build performance model for runtime estimation
14. ⬜ Profile and optimize HomotopyContinuation.jl phase
15. ⬜ Deprecate or fix `enhanced-gitlab-api.sh`

---

## 📝 Related Documentation

- **DrWatson Integration**: `docs/issues/drwatson_enhancement_proposal.md`
- **Schema v1.1.0 Spec**: See `Examples/minimal_4d_lv_test.jl:334-343`
- **Collection Script**: `scripts/analysis/collect_cluster_experiments.jl`
- **Launch Script**: `scripts/launch_4d_lv_campaign.sh`

---

## 🔬 Experiment Campaign Summary

**Date**: 2025-09-30
**Total Experiments**: 7 new (24 total analyzed)
**Compute Time**: 10.3 minutes total
**Data Generated**:
- 48 degree computations across parameter space
- 7 JLD2 files with Git provenance
- 7 JSON summaries for human review
- 5 legacy CSV files from old runs

**Parameter Space Covered**:
- GN: {5, 6, 8}
- Degrees: {3, 4, 5, 6, 7}
- Domains: {0.1, 0.15, 0.2, 0.5}
- Total combinations tested: 48

**Key Finding**: Pipeline is robust (95.8% success) with clear error modes (import failures, not mathematical failures)