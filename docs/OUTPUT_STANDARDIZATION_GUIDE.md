# Output Standardization Guide for Globtim Pipeline

## Executive Summary

**Goal**: Ensure all pipeline outputs contain complete, reproducible metadata for analysis and publication.

**Key Requirements**:
- ✅ True parameters (for parameter recovery)
- ✅ Computation times (detailed breakdown)
- ✅ Critical points (raw + refined)
- ✅ Complete system configuration
- ✅ Reproducibility metadata

**Status**: Schema v1.1.0 implemented ✅ - This guide documents best practices and remaining gaps.

**GitLab Issues**:
- [Issue #114](https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues/114): Pre-Launch Experiment Configuration Validation Hook
- [Issue #115](https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues/115): Add Environment Metadata Capture Module for Full Reproducibility

---

## 1. Complete Metadata Checklist

### ✅ Currently Captured (Schema v1.1.0)

**Top-Level Metadata**:
```json
{
  "schema_version": "1.1.0",           // ✅ Version tracking
  "experiment_id": "unique_id",        // ✅ DrWatson-style ID
  "experiment_type": "4dlv_param_rec", // ✅ Type classification
  "timestamp": "YYYYMMDD_HHMMSS",      // ✅ Execution time
  "total_time": 18.01,                 // ✅ Total wall time
  "success_rate": 1.0,                 // ✅ Success fraction
  "degrees_processed": 1               // ✅ Completion count
}
```

**Computational Parameters** (`params_dict`):
```json
{
  "GN": 5,                    // ✅ Grid samples per dimension
  "degree_range": [4, 5, 6],  // ✅ Polynomial degrees tested
  "domain_size_param": 0.3,   // ✅ Search domain size
  "max_time": 60.0            // ✅ Time limit per degree
}
```

**System Information** (`system_info`):
```json
{
  "dimension": 4,                              // ✅ Problem dimension
  "system_type": "lotka_volterra_4d",         // ✅ System type
  "true_parameters": [0.15, -0.1, 0.12, -0.08], // ✅ Ground truth
  "search_domain_center": [0, 0, 0, 0],        // ✅ Domain center
  "search_domain_size": 0.3,                   // ✅ Domain size
  "objective_function": "trajectory_misfit",   // ✅ Objective type
  "free_parameters": ["b[1,3]", ...],         // ✅ Parameter names
  "initial_populations": [5, 5, 5, 5],        // ✅ Initial conditions
  "fixed_growth_rates": [-0.5, 1.0, ...],     // ✅ Fixed parameters
  "time_span": [0, 15]                        // ✅ Integration interval
}
```

**Per-Degree Results** (`results_summary.degree_N`):
```json
{
  "status": "success",                       // ✅ Success/failure
  "l2_approx_error": 6.178e-9,              // ✅ Approximation quality
  "condition_number": 16.0,                  // ✅ Numerical stability
  "critical_points_raw": 17,                 // ✅ Pre-refinement count
  "critical_points_refined": 17,             // ✅ Post-refinement count
  "critical_points": 0,                      // ✅ In-domain count

  // Timing breakdown
  "total_computation_time": 18.01,           // ✅ Total time
  "polynomial_construction_time": 2.81,      // ✅ Fit time
  "critical_point_solving_time": 13.77,      // ✅ Solve time
  "refinement_time": 0.84,                   // ✅ Refinement time
  "critical_point_processing_time": 0.012,   // ✅ Processing time
  "file_io_time": 0.0,                       // ✅ I/O time

  // Refinement statistics
  "refinement_stats": {
    "converged": 17,           // ✅ Success count
    "failed": 0,               // ✅ Failure count
    "mean_improvement": 0.0,   // ✅ Avg improvement
    "max_improvement": 0.0,    // ✅ Max improvement
    "mean_iterations": 0.0     // ✅ Avg iterations
  },

  // Best solution (when points in domain)
  "best_estimate": [0.14, -0.09, ...],  // ✅ Best parameter estimate
  "best_objective": 0.0012,             // ✅ Best objective value
  "recovery_error": 0.023               // ✅ L2 distance to true params
}
```

### ⚠️ Currently Missing but Important

**1. Critical Points Data** - ⚠️ **CRITICAL GAP**
- **Problem**: CSV files only saved when `critical_points > 0` (points in domain)
- **Impact**: Lost data when all refined points are outside domain (17 refined points but 0 in-domain)
- **Example**: `4dlv_param_recovery_*` experiments have 17 refined points but no CSV saved

**Recommendation**: Always save critical points CSV with `in_domain` boolean column:
```csv
theta1_raw,theta2_raw,theta3_raw,theta4_raw,theta1,theta2,theta3,theta4,objective_raw,objective,recovery_error,refinement_improvement,in_domain,l2_approx_error
0.2,-0.15,0.18,-0.12,0.19,-0.14,0.17,-0.11,0.05,0.03,0.08,0.02,false,6.18e-9
```

**2. Computational Environment** - ⚠️ **REPRODUCIBILITY GAP**
- Julia version
- Package versions (Manifest.toml snapshot)
- Hardware (CPU model, RAM, architecture)
- Cluster node (for HPC runs)

**Recommendation**: Add `environment_info` top-level key:
```json
{
  "environment_info": {
    "julia_version": "1.11.6",
    "hostname": "r04n02",
    "cpu_model": "Intel(R) Xeon(R) CPU E5-2680 v4",
    "cpu_cores": 28,
    "total_ram_gb": 128,
    "os": "Linux 5.15.0",
    "package_manifest_hash": "sha256:abc123...",  // Hash of Manifest.toml
    "globtim_version": "0.1.0",
    "homotopycontinuation_version": "2.9.3"
  }
}
```

**3. Numerical Configuration** - ⚠️ **MINOR GAP**
- Floating point precision (Float64 vs BigFloat)
- Tolerance settings for HC.jl
- Refinement convergence criteria

**Recommendation**: Add to `params_dict`:
```json
{
  "numerical_config": {
    "precision": "Float64",
    "hc_tolerance": 1e-10,
    "refinement_tolerance": 1e-8,
    "max_refinement_iterations": 100
  }
}
```

**4. Data Provenance** - ⚠️ **MINOR GAP**
- Git commit hash of code used
- Command line arguments
- Parent experiment ID (if part of campaign)

**Recommendation**: Add `provenance` top-level key:
```json
{
  "provenance": {
    "git_commit": "b4e3686",
    "git_branch": "main",
    "command_line": "julia --project=. Examples/4DLV/parameter_recovery_experiment.jl --GN=5 --degrees=4:6",
    "launched_from": "local | cluster",
    "campaign_id": "robustness_study_20251001",  // Optional
    "parent_experiment_id": null  // Optional
  }
}
```

---

## 2. File Organization Standards

### Required Files

**Every experiment directory MUST contain:**

```
hpc_results/<experiment_id>/
├── results_summary.json        # ✅ REQUIRED - Complete metadata (Schema v1.1.0)
├── results_summary.jld2        # ✅ GENERATED - Binary format (DrWatson)
├── critical_points_deg_4.csv   # ⚠️ SHOULD EXIST - Currently missing when n_valid=0
├── critical_points_deg_5.csv   # ⚠️ SHOULD EXIST
├── critical_points_deg_6.csv   # ⚠️ SHOULD EXIST
└── true_trajectory.csv         # ✅ OPTIONAL - For parameter recovery only
```

### Optional but Recommended Files

```
hpc_results/<experiment_id>/
├── convergence_analysis.png    # Generated by post-processing
├── experiment.log              # Stdout/stderr capture from cluster
├── Manifest.toml.snapshot      # Package versions snapshot
├── git_info.txt                # Git commit, branch, diff status
└── performance_profile.json    # Memory usage, CPU time breakdown
```

---

## 3. Implementation Roadmap

**GitLab Issues Created**:
- ✅ [Issue #114](https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues/114): Pre-Launch Experiment Configuration Validation Hook (HIGH PRIORITY)
- ✅ [Issue #115](https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues/115): Environment Metadata Capture Module (MEDIUM PRIORITY)

### Phase 1: Critical Points Warning (COMPLETED ✅)

**Problem**: 17 refined critical points not saved when all outside domain.

**User Decision**: Keep current behavior (don't save), just add warning message.

**Solution Implemented** (Commit 223216a):

**Solution**: Modify `Examples/4DLV/parameter_recovery_experiment.jl`:

```julia
# Phase 5: Save results (ALWAYS save critical points if any refined)
if refinement_stats.converged > 0
    # Mark which points are in domain
    in_domain_mask = [pt in valid_critical_points for pt in refined_points]

    df_all_critical = DataFrame(
        # Raw critical points (before refinement)
        theta1_raw = [raw_points[i][1] for i in 1:length(refined_points)],
        theta2_raw = [raw_points[i][2] for i in 1:length(refined_points)],
        theta3_raw = [raw_points[i][3] for i in 1:length(refined_points)],
        theta4_raw = [raw_points[i][4] for i in 1:length(refined_points)],

        # Refined critical points (after refinement)
        theta1 = [refined_points[i][1] for i in 1:length(refined_points)],
        theta2 = [refined_points[i][2] for i in 1:length(refined_points)],
        theta3 = [refined_points[i][3] for i in 1:length(refined_points)],
        theta4 = [refined_points[i][4] for i in 1:length(refined_points)],

        # Objective values
        objective_raw = [trajectory_misfit_objective(raw_points[i]) for i in 1:length(refined_points)],
        objective = [trajectory_misfit_objective(refined_points[i]) for i in 1:length(refined_points)],

        # Recovery metrics
        recovery_error = [norm(refined_points[i] - THETA_TRUE) for i in 1:length(refined_points)],
        refinement_improvement = [abs(trajectory_misfit_objective(refined_points[i]) -
                                     trajectory_misfit_objective(raw_points[i])) for i in 1:length(refined_points)],

        # Domain membership (NEW)
        in_domain = in_domain_mask,

        # Quality metrics
        l2_approx_error = fill(l2_approx_error, length(refined_points))
    )

    CSV.write("$output_dir/critical_points_deg_$degree.csv", df_all_critical)
    println("💾 Saved $(length(refined_points)) critical points ($(sum(in_domain_mask)) in domain)")
end
```

**Testing**:
```bash
# Run parameter recovery with narrow domain
julia --project=. Examples/4DLV/parameter_recovery_experiment.jl --GN=5 --degrees=4:6 --domain=0.1

# Verify CSV files exist even when n_valid=0
ls hpc_results/4dlv_*/critical_points_deg_*.csv

# Check in_domain column
head -3 hpc_results/4dlv_*/critical_points_deg_4.csv
```

### Phase 2: Add Environment Metadata (MEDIUM PRIORITY)

**GitLab Issue**: [#115](https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues/115) - Complete implementation plan

**Summary**: Create `src/ExperimentMetadata.jl` module to capture:
- Julia version, package versions, hardware specs
- Git commit, branch, command line args
- Automatic integration with experiments

**Effort**: ~4 hours total

See Issue #115 for complete implementation code and testing plan.

**Original utility function reference** (now in Issue #115):

```julia
module ExperimentMetadata

using Pkg, Dates

"""
Capture complete computational environment metadata
"""
function capture_environment_info()
    return Dict(
        "julia_version" => string(VERSION),
        "hostname" => gethostname(),
        "cpu_model" => get_cpu_model(),
        "cpu_cores" => Sys.CPU_THREADS,
        "total_ram_gb" => round(Sys.total_memory() / 1e9, digits=2),
        "os" => string(Sys.KERNEL),
        "arch" => string(Sys.ARCH),
        "globtim_version" => get_package_version("Globtim"),
        "homotopycontinuation_version" => get_package_version("HomotopyContinuation"),
        "manifest_hash" => compute_manifest_hash()
    )
end

function get_cpu_model()
    if Sys.islinux()
        try
            return strip(read(`cat /proc/cpuinfo | grep "model name" | head -1 | cut -d: -f2`, String))
        catch
            return "unknown"
        end
    else
        return "unknown"
    end
end

function get_package_version(pkg_name::String)
    try
        deps = Pkg.dependencies()
        for (uuid, dep) in deps
            if dep.name == pkg_name
                return string(dep.version)
            end
        end
        return "unknown"
    catch
        return "unknown"
    end
end

function compute_manifest_hash()
    manifest_path = joinpath(dirname(@__DIR__), "Manifest.toml")
    if isfile(manifest_path)
        return bytes2hex(sha256(read(manifest_path)))
    else
        return "no_manifest"
    end
end

end # module
```

**Usage in experiments**:
```julia
using .ExperimentMetadata

# Add to results dictionary
results_dict["environment_info"] = capture_environment_info()
```

### Phase 3: Add Data Provenance (INCLUDED IN PHASE 2)

**GitLab Issue**: [#115](https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues/115) - Includes provenance tracking

**Summary**: Provenance tracking included in ExperimentMetadata module:
- Git commit hash, branch, status
- Command line arguments
- Launch context (local vs cluster)

**Note**: Originally separate phase, now integrated with Phase 2 (Issue #115).

**Reference utility function** (now in Issue #115):

```julia
function capture_provenance_info()
    return Dict(
        "git_commit" => get_git_commit(),
        "git_branch" => get_git_branch(),
        "git_status" => get_git_status(),
        "command_line" => join(ARGS, " "),
        "launched_from" => get_launch_context(),
        "timestamp_utc" => Dates.format(now(UTC), "yyyy-mm-dd HH:MM:SS")
    )
end

function get_git_commit()
    try
        return strip(read(`git rev-parse HEAD`, String))
    catch
        return "unknown"
    end
end

function get_git_branch()
    try
        return strip(read(`git rev-parse --abbrev-ref HEAD`, String))
    catch
        return "unknown"
    end
end

function get_git_status()
    try
        status = read(`git status --porcelain`, String)
        return isempty(strip(status)) ? "clean" : "modified"
    catch
        return "unknown"
    end
end

function get_launch_context()
    hostname = gethostname()
    if occursin("r04n02", hostname) || occursin("cluster", hostname)
        return "cluster"
    else
        return "local"
    end
end
```

---

## 4. Validation & Quality Checks

### Automated Validation Script

**Create** `scripts/validation/validate_experiment_output.jl`:

```julia
#!/usr/bin/env julia
"""
Validate experiment output completeness and schema compliance
"""

function validate_experiment(exp_dir::String)
    println("🔍 Validating: $(basename(exp_dir))")

    issues = []

    # Check 1: results_summary.json exists
    json_file = joinpath(exp_dir, "results_summary.json")
    if !isfile(json_file)
        push!(issues, "❌ Missing results_summary.json")
        return issues
    end

    data = JSON.parsefile(json_file)

    # Check 2: Schema version
    if !haskey(data, "schema_version")
        push!(issues, "⚠️  No schema_version field")
    elseif data["schema_version"] != "1.1.0"
        push!(issues, "⚠️  Schema version $(data["schema_version"]) != 1.1.0")
    end

    # Check 3: Required top-level fields
    required_fields = ["experiment_id", "timestamp", "params_dict", "results_summary"]
    for field in required_fields
        if !haskey(data, field)
            push!(issues, "❌ Missing required field: $field")
        end
    end

    # Check 4: Degree range >= 3
    if haskey(data, "params_dict") && haskey(data["params_dict"], "degree_range")
        deg_range = data["params_dict"]["degree_range"]
        if length(deg_range) < 3
            push!(issues, "⚠️  Only $(length(deg_range)) degrees (minimum 3 recommended)")
        end
    end

    # Check 5: Critical points CSVs
    if haskey(data, "results_summary")
        for (deg_key, result) in data["results_summary"]
            if haskey(result, "critical_points_refined") && result["critical_points_refined"] > 0
                degree = parse(Int, replace(string(deg_key), "degree_" => ""))
                csv_file = joinpath(exp_dir, "critical_points_deg_$degree.csv")
                if !isfile(csv_file)
                    push!(issues, "⚠️  Missing critical_points_deg_$degree.csv ($(result["critical_points_refined"]) refined points)")
                end
            end
        end
    end

    # Check 6: True parameters (for parameter recovery)
    if haskey(data, "experiment_type") && occursin("recovery", data["experiment_type"])
        if !haskey(data, "system_info") || !haskey(data["system_info"], "true_parameters")
            push!(issues, "❌ Parameter recovery experiment missing true_parameters")
        end
    end

    # Report
    if isempty(issues)
        println("✅ All checks passed")
    else
        println("Issues found:")
        for issue in issues
            println("  $issue")
        end
    end

    return issues
end

# Run validation
if length(ARGS) > 0
    validate_experiment(ARGS[1])
else
    println("Usage: julia validate_experiment_output.jl <experiment_dir>")
end
```

**Usage**:
```bash
# Validate single experiment
julia scripts/validation/validate_experiment_output.jl hpc_results/<exp_dir>/

# Validate all experiments
for dir in hpc_results/*/; do
    julia scripts/validation/validate_experiment_output.jl "$dir"
done
```

---

## 5. Best Practices Summary

### For Experiment Authors

**DO**:
- ✅ Use Schema v1.1.0 format
- ✅ Test minimum 3 degrees
- ✅ Save ALL refined critical points (not just in-domain)
- ✅ Include `true_parameters` for parameter recovery
- ✅ Capture detailed timing breakdown
- ✅ Document system type and configuration

**DON'T**:
- ❌ Skip saving critical points when `n_valid = 0`
- ❌ Use single-degree experiments for convergence analysis
- ❌ Omit `schema_version` field
- ❌ Save outputs without complete metadata

### For Cluster Operators

**DO**:
- ✅ Capture stdout/stderr to `experiment.log`
- ✅ Save Manifest.toml snapshot
- ✅ Record git commit hash
- ✅ Use DrWatson-style directory naming

**DON'T**:
- ❌ Overwrite existing experiment directories
- ❌ Run experiments without version control
- ❌ Launch campaigns without unique campaign IDs

### For Data Analysts

**DO**:
- ✅ Validate schema compliance before analysis
- ✅ Check for missing critical points CSVs
- ✅ Verify degree range >= 3 for convergence plots
- ✅ Document any schema deviations

**DON'T**:
- ❌ Assume all experiments have CSV files
- ❌ Mix schema versions without migration
- ❌ Ignore validation warnings

---

## 6. Migration Guide

### Updating Legacy Experiments

**For experiments missing Schema v1.1.0 fields:**

1. Identify legacy experiments:
```bash
jq -r 'select(.schema_version != "1.1.0") | .experiment_id' hpc_results/*/results_summary.json
```

2. Create migration script `scripts/migration/migrate_to_schema_v1_1_0.jl`

3. Archive legacy experiments:
```bash
mkdir -p hpc_results_archive_legacy_schema
mv <legacy_exp_dirs> hpc_results_archive_legacy_schema/
```

### Updating Experiment Scripts

**Checklist for each experiment script:**
- [ ] Add `schema_version = "1.1.0"` to output
- [ ] Save critical points even when `n_valid = 0`
- [ ] Include `in_domain` column in CSV
- [ ] Capture environment metadata
- [ ] Default degree range >= 3
- [ ] Complete timing breakdown
- [ ] System info for parameter recovery

---

## 7. Quick Reference

### Schema v1.1.0 Template

**Minimal valid output**:
```json
{
  "schema_version": "1.1.0",
  "experiment_id": "unique_id",
  "experiment_type": "type_string",
  "timestamp": "YYYYMMDD_HHMMSS",
  "params_dict": {
    "GN": 5,
    "degree_range": [4, 5, 6]
  },
  "results_summary": {
    "degree_4": {
      "status": "success",
      "l2_approx_error": 1e-9,
      "critical_points_refined": 17
    }
  }
}
```

### Validation One-Liner

```bash
# Quick check for schema compliance
jq '.schema_version, .params_dict.degree_range | length, (.results_summary | keys | length)' \
    hpc_results/*/results_summary.json
```

### Priority Implementation Order

1. **HIGH**: Fix critical points CSV gap (Phase 1)
2. **MEDIUM**: Add environment metadata (Phase 2)
3. **LOW**: Add provenance metadata (Phase 3)
4. **LOW**: Create validation script

---

## References

- Schema v1.1.0: Issue #109 (Critical Point Refinement)
- Data Standards: [CLUSTER_DATA_STANDARDS.md](CLUSTER_DATA_STANDARDS.md)
- DrWatson integration: Using `@dict` and `savename()`
- Current experiments: `Examples/4DLV/parameter_recovery_experiment.jl`
