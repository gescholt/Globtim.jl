# Critical Point Refinement - Phase 2 Tasks

How can we elegantly display how the domain was subdivided. Are there parameters to adjust -- can they adjust themselves by iteration ? It would be nice to have some trees to display which variable was split (with color for each variable) and branch length proportional for where we cut (on the `(-1,1) scale ) ? 

**Ideas: Adaptive Domain Subdivision**

*Context*: When the L2 approximation error exceeds tolerance on a domain, we subdivide and approximate on smaller subdomains. The standard approach splits each dimension in half, but this is suboptimal.

**Core Insight**: Instead of fixed bisection, search for the optimal cut location along each dimension by estimating the combined L2 error on both resulting subdomains.

**Approach**:
1. **Scan cut locations**: For each candidate cut position along an edge, estimate $\|f - w_{d,S_1}\|_{L_2}$ and $\|f - w_{d,S_2}\|_{L_2}$ where $S = S_1 \cup S_2$
2. **Choose optimal cut**: Select the position that minimizes total error (or balances error across subdomains)
3. **Efficiency considerations**:
   - Pre-compute matrices that can be reused across cut positions
   - Use sparse Chebyshev samples (~2× number of coefficients) instead of full grids
   - Evaluate cuts in parallel before constructing full approximants

**Parallelization Strategy**:
- **Independent subdomains**: Once a domain is split, both child subdomains can be processed in parallel
- **Tree-based parallelism**: Subdivision creates a binary tree structure; use work-stealing or task-based parallelism (Julia's `Threads.@spawn` or `Distributed`)
- **Batch processing**: Accumulate subdomains at the same tree level and process as a batch
- **GPU potential**: Vandermonde matrix construction and L2 error estimation are embarrassingly parallel across subdomains

**Two-Phase Subdivision Strategy**:

*Phase 1 - Coarse balancing pass*:
- Use a moderate polynomial degree (not too high) - fast to compute
- Goal: Subdivide until all subdomains have *relatively even* L2 approximation errors
- Tolerance is "good but not tight" - we're distributing work, not achieving final accuracy
- Stopping criterion: max(error_i) / min(error_i) < threshold (e.g., 2-3x)

*Phase 2 - Accuracy refinement*:
- Once subdomains are balanced, increase polynomial degree uniformly
- Or apply tighter tolerance and continue subdividing where needed
- Balanced starting point ensures parallel efficiency (no stragglers)

*Rationale*: Balancing first prevents wasted computation on already-easy regions while hard regions remain under-resolved. The parallel workload becomes more uniform.

*Gradient Boosting Analogy*: This resembles gradient boosted methods - each subdivision iteration focuses computational effort on the "residual" (high-error subdomains), iteratively reducing the worst errors first rather than uniformly refining everywhere.

**Statistical Approaches for Cut Selection**:

When choosing where to subdivide a domain based on L2 approximation error (using LS-polynomial of fixed degree), statistical methods could guide the decision:

*Potential approaches to research*:
- **Gaussian Process regression**: Model error surface over cut positions; uncertainty estimates could guide exploration vs exploitation
- **Bayesian optimization**: Treat optimal cut search as black-box optimization with expensive function evaluations
- **Cross-validation estimates**: Use k-fold CV on Chebyshev nodes to estimate generalization error for each candidate cut
- **Bootstrapping**: Resample function evaluations to get confidence intervals on L2 error estimates
- **Sequential design of experiments**: Adaptively choose where to sample the function based on current approximation quality (e.g., D-optimal, A-optimal designs)

*Key questions requiring research*:
- What statistical tools are available in Julia for these approaches? (GaussianProcesses.jl, BayesianOptimization.jl, etc.)
- How do these methods scale with dimension?
- Can we leverage structure of polynomial approximation (Vandermonde matrices, tensor-product basis) within statistical methods?
- What is the computational overhead vs simply evaluating all candidate cuts?

**Open Questions**:
- How many subdivisions are needed to reach L2 tolerance?
- What is the distribution of optimal cuts in normalized $[-1,1]$ space?
- How to efficiently track subdomain centers and half-lengths across recursive subdivisions?
- What is the optimal granularity for parallel tasks (too fine = overhead, too coarse = load imbalance)?

**Connection to ML Milestone**: This relates to "Direction 1: RL-Guided Adaptive Mesh Refinement" in `docs/milestones/MACHINE_LEARNING_INTEGRATION.md`, where an RL agent could learn optimal subdivision policies. 

**Status**: ✅ **COMPLETE** (2025-11-23)

**Assigned To**: Agent working in globtimcore repository

**Dependencies**: Phase 1 (globtimpostprocessing) ✅ COMPLETE

**Completion Summary**: All tasks completed successfully. See commits 44c601a through 99e46c0.

## Overview

Phase 2 removes critical point refinement from globtimcore and updates StandardExperiment to export only raw critical points. Refinement is now handled by globtimpostprocessing as a separate post-processing step.

**Breaking Changes**: Yes - this is a MAJOR update to StandardExperiment.jl

## Task List

### Task 1: Delete Old Refinement Module ❌ DELETE FILE

**File**: `src/CriticalPointRefinement.jl` (285 lines)

**Action**:
```bash
rm /Users/ghscholt/GlobalOptim/globtimcore/src/CriticalPointRefinement.jl
```

**Verification**:
- [ ] File no longer exists
- [ ] No references to this file in any other source files

**Rationale**: This module has been reorganized and moved to globtimpostprocessing (4 new modules, 969 lines total).

---

### Task 2: Update StandardExperiment.jl - Remove Refinement Code

**File**: `src/StandardExperiment.jl`

This is the MAJOR task with ~200 lines of changes across multiple sections.

#### 2a. Remove Refinement Import (Lines ~75-79)

**Current Code** (REMOVE):
```julia
# Critical point refinement (local optimization)
if haskey(ENV, "ENABLE_REFINEMENT") && ENV["ENABLE_REFINEMENT"] == "true"
    include("CriticalPointRefinement.jl")
    using .CriticalPointRefinement
end
```

**Action**: Delete these lines entirely

---

#### 2b. Remove Refinement Call (Lines ~400-451)

**Current Code** (REMOVE entire block):
```julia
# Refine critical points using local optimization
println("\nRefining critical points...")
if haskey(ENV, "ENABLE_REFINEMENT") && ENV["ENABLE_REFINEMENT"] == "true"
    refinement_results = refine_critical_points_batch(
        func,
        critical_points_raw;
        method = Optim.NelderMead(),
        max_time = 60.0,
        f_abstol = 1e-6,
        show_progress = true
    )

    # Process refinement results
    converged_indices = findall(r -> r.converged, refinement_results)
    critical_points_array = [refinement_results[i].refined for i in converged_indices]
    # ... more refinement processing
else
    # No refinement - use raw points
    critical_points_array = critical_points_raw
end
```

**New Code** (REPLACE with simple assignment):
```julia
# Export raw critical points only (refinement is now in globtimpostprocessing)
critical_points_array = critical_points_raw
n_critical_points = length(critical_points_array)

println("Found $n_critical_points raw critical points at degree $degree")
```

---

#### 2c. Remove Post-Refinement Validation (Lines ~453-474)

**Current Code** (REMOVE):
```julia
# Validation after refinement
for (i, cp) in enumerate(critical_points_array)
    grad_norm = norm(gradient(func, cp))
    if grad_norm > 1e-6
        @warn "Refined critical point $i has large gradient norm: $grad_norm"
    end
end
```

**Action**: Delete validation block (now handled in globtimpostprocessing if needed)

---

#### 2d. Update CSV Export - Rename File and Remove Refined Columns

**Current Code** (Lines ~563-570):
```julia
csv_filename = joinpath(output_dir, "critical_points_deg_$(degree).csv")
df = DataFrame(
    index = 1:length(critical_points_array),
    [Symbol("p$i") => [cp[i] for cp in critical_points_array] for i in 1:dimension]...,
    objective_raw = raw_values,
    objective = refined_values,
    refinement_improvement = improvements
)
CSV.write(csv_filename, df)
```

**New Code** (REPLACE):
```julia
# Export raw critical points (add '_raw' suffix for globtimpostprocessing)
csv_filename = joinpath(output_dir, "critical_points_raw_deg_$(degree).csv")
df = DataFrame(
    index = 1:length(critical_points_array),
    [Symbol("p$i") => [cp[i] for cp in critical_points_array] for i in 1:dimension]...,
    objective = [func(cp) for cp in critical_points_array]
)
CSV.write(csv_filename, df)
```

**Key Changes**:
- Filename: `critical_points_deg_X.csv` → `critical_points_raw_deg_X.csv`
- Columns: Remove `objective_raw`, `refinement_improvement`
- Column rename: `objective` now contains raw objective values (not refined)

---

#### 2e. Update Variable Names Throughout

**Search and Replace**:
- `refined_points` → `critical_points_array` (already raw points)
- `n_converged` → `n_critical_points`
- `refinement_improvement` → DELETE (no longer tracked)
- `raw_values` → `objective_values`

**Affected Lines**: ~500-700 (many print statements, result struct, etc.)

---

#### 2f. Update DegreeResult Struct (Lines ~95-117)

**Current Fields** (REMOVE):
```julia
struct DegreeResult
    degree::Int
    n_raw::Int
    n_converged::Int
    n_failed::Int
    refinement_stats::Dict{String, Any}
    # ...
end
```

**New Fields** (SIMPLIFIED):
```julia
struct DegreeResult
    degree::Int
    n_critical_points::Int
    critical_points::Vector{Vector{Float64}}
    objective_values::Vector{Float64}
    solve_time::Float64
    output_dir::String
    # Remove all refinement-related fields
end
```

---

### Task 3: Add 1-Argument Function Support

**File**: `src/StandardExperiment.jl` (Lines ~314-332)

**Action**: Add automatic function signature detection

**Current Code** (if `problem_params` is required):
```julia
# Create wrapped function
func = x -> objective_function(x, problem_params)
```

**New Code** (auto-detect 1-arg vs 2-arg):
```julia
# Detect function signature and create wrapper if needed
# Support both 1-arg (Dynamic_objectives) and 2-arg (legacy)
n_args = length(methods(objective_function).ms[1].sig.parameters) - 1

func = if n_args == 1
    # 1-argument function (e.g., Dynamic_objectives pattern)
    if problem_params !== nothing
        @warn "problem_params provided but objective_function takes 1 argument - ignoring params"
    end
    objective_function
elseif n_args == 2
    # 2-argument function (legacy pattern)
    if problem_params === nothing
        error("2-argument objective function requires problem_params")
    end
    x -> objective_function(x, problem_params)
else
    error("Objective function must accept 1 or 2 arguments, got $n_args")
end
```

**Rationale**: Dynamic_objectives uses 1-arg functions. This eliminates the need for wrapper functions in application code.

---

### Task 4: Update Exports and Documentation

#### 4a. Update Docstrings

**File**: `src/StandardExperiment.jl` (function docstring)

Add to `run_standard_experiment()` docstring:
```julia
# Returns
A result object containing:
- `output_dir::String`: Path to experiment results
- `critical_points::Vector{Vector{Float64}}`: Raw critical points
- `objective_values::Vector{Float64}`: Objective values at critical points
- `degree::Int`: Polynomial degree used
- `solve_time::Float64`: Time to solve HomotopyContinuation

# Notes
- Critical points are NOT refined (refinement moved to globtimpostprocessing)
- CSV exported as `critical_points_raw_deg_X.csv` for post-processing
- For refinement, use: `GlobtimPostProcessing.refine_experiment_results(output_dir, objective_func)`
```

#### 4b. Update Module Exports

**File**: `src/Globtim.jl`

**Check**: Ensure `CriticalPointRefinement` is NOT exported
```julia
# DO NOT export refinement functions (moved to GlobtimPostProcessing)
# export refine_critical_points, refine_critical_points_batch  # ❌ REMOVE IF PRESENT
```

---

### Task 5: Update Tests

**File**: `test/runtests.jl` (or relevant test file)

Update tests to expect:
- CSV filename with `_raw` suffix
- No `refinement_improvement` column
- Struct fields: `n_critical_points` instead of `n_converged`

**Example Test Update**:
```julia
@testset "StandardExperiment CSV Output" begin
    result = run_standard_experiment(...)

    # Check raw CSV exists
    csv_file = joinpath(result.output_dir, "critical_points_raw_deg_$(result.degree).csv")
    @test isfile(csv_file)

    # Check CSV structure
    df = CSV.read(csv_file, DataFrame)
    @test "objective" in names(df)
    @test !("refinement_improvement" in names(df))  # Should NOT exist
    @test !("objective_raw" in names(df))  # Should NOT exist

    # Check result struct
    @test hasfield(typeof(result), :n_critical_points)
    @test !hasfield(typeof(result), :n_converged)  # Should NOT exist
end
```

---

### Task 6: Remove Environment Variable Check

**Search**: `ENV["ENABLE_REFINEMENT"]`

**Action**: Remove ALL occurrences - refinement is always disabled in globtimcore now

**Rationale**: Refinement is no longer optional in globtimcore (it's moved to separate package)

---

## Verification Checklist

After completing all tasks, verify:

### Code Cleanup
- [ ] `src/CriticalPointRefinement.jl` deleted
- [ ] No `using .CriticalPointRefinement` in any file
- [ ] No `refine_critical_points_batch()` calls in StandardExperiment.jl
- [ ] No `ENV["ENABLE_REFINEMENT"]` checks anywhere
- [ ] No imports or exports of refinement functions

### CSV Output
- [ ] CSV filename: `critical_points_raw_deg_X.csv` (includes `_raw`)
- [ ] CSV columns: `index`, `p1`, `p2`, ..., `objective` (NO `objective_raw`, NO `refinement_improvement`)

### Function Signature Support
- [ ] 1-arg functions work without wrapper: `f(p::Vector{Float64})`
- [ ] 2-arg functions still work: `f(p, params)` with `problem_params` provided
- [ ] Error message if function has wrong number of arguments

### Struct Updates
- [ ] `DegreeResult` has `n_critical_points` field
- [ ] `DegreeResult` does NOT have `n_converged`, `n_failed`, `refinement_stats` fields
- [ ] Result object can be passed to globtimpostprocessing for refinement

### Package Still Works
- [ ] `using Globtim` precompiles without errors
- [ ] Can run `StandardExperiment` and get CSV output
- [ ] CSV can be loaded by globtimpostprocessing

---

## Testing Strategy

### Unit Tests (globtimcore only)
```julia
using Pkg
Pkg.activate("/Users/ghscholt/GlobalOptim/globtimcore")
using Globtim

# Test 1: Module loads without refinement
@assert !isdefined(Globtim, :refine_critical_points)
@assert !isdefined(Globtim, :CriticalPointRefinement)

# Test 2: Run simple experiment
function sphere(p::Vector{Float64})
    return sum(p.^2)
end

result = run_standard_experiment(
    sphere,
    [(-5.0, 5.0), (-5.0, 5.0)],
    StandardExperimentConfig(max_degree=6)
)

# Test 3: Check CSV output
csv_file = joinpath(result.output_dir, "critical_points_raw_deg_$(result.degree).csv")
@assert isfile(csv_file)

df = CSV.read(csv_file, DataFrame)
@assert "objective" in names(df)
@assert !("refinement_improvement" in names(df))

# Test 4: Check result struct
@assert hasfield(typeof(result), :n_critical_points)
@assert result.n_critical_points > 0

println("✅ All globtimcore Phase 2 tests passed!")
```

### Integration Test (with globtimpostprocessing)
```julia
# After Phase 2 complete, test full pipeline
using Globtim, GlobtimPostProcessing

# Step 1: Run experiment (globtimcore)
result_core = run_standard_experiment(sphere, bounds, config)

# Step 2: Refine (globtimpostprocessing)
result_refined = refine_experiment_results(
    result_core.output_dir,
    sphere,
    ode_refinement_config()
)

@assert result_refined.n_raw == result_core.n_critical_points
@assert result_refined.n_converged <= result_refined.n_raw
@assert result_refined.mean_improvement >= 0

println("✅ End-to-end pipeline test passed!")
```

---

## Breaking Changes Summary

**For Users of globtimcore**:

1. **CSV filename changed**:
   - Old: `critical_points_deg_18.csv`
   - New: `critical_points_raw_deg_18.csv`

2. **CSV columns removed**:
   - No more `objective_raw`
   - No more `refinement_improvement`
   - `objective` now contains raw values (not refined)

3. **Result struct changed**:
   - `n_converged` → `n_critical_points`
   - `n_failed` field removed
   - `refinement_stats` field removed

4. **Refinement moved to separate package**:
   - Must now explicitly call `GlobtimPostProcessing.refine_experiment_results()`
   - See `globtimpostprocessing/REFINEMENT_PHASE1_STATUS.md` for usage

5. **Environment variable removed**:
   - `ENV["ENABLE_REFINEMENT"]` no longer used

**Migration Guide** (for existing scripts):
```julia
# OLD CODE (before Phase 2):
using Globtim
ENV["ENABLE_REFINEMENT"] = "true"
result = run_standard_experiment(objective, bounds, config)
# Refinement happened automatically

# NEW CODE (after Phase 2):
using Globtim, GlobtimPostProcessing
result_raw = run_standard_experiment(objective, bounds, config)
result_refined = refine_experiment_results(
    result_raw.output_dir,
    objective,
    ode_refinement_config()
)
# Refinement is explicit, separate step
```

---

## Estimated Impact

**Lines Changed**: ~250-300 lines across:
- `src/StandardExperiment.jl`: ~200 lines modified/removed
- `src/Globtim.jl`: ~5 lines (exports)
- `test/runtests.jl`: ~20 lines (test updates)
- `src/CriticalPointRefinement.jl`: 285 lines DELETED

**Time Estimate**: 2-3 hours for careful implementation and testing

**Risk Level**: MEDIUM-HIGH (breaking changes to main API)

---

## Dependencies

**Before Starting**:
- ✅ Phase 1 (globtimpostprocessing) must be complete

**After Completion**:
- Phase 3 (Dynamic_objectives integration guide) can proceed
- End-to-end testing can be performed

---

## Contact

For questions about Phase 2 implementation, see:
- `/Users/ghscholt/GlobalOptim/docs/API_DESIGN_REFINEMENT.md` (design spec)
- `/Users/ghscholt/GlobalOptim/docs/REFINEMENT_MIGRATION_COORDINATION.md` (coordination)
- `/Users/ghscholt/GlobalOptim/globtimpostprocessing/REFINEMENT_PHASE1_STATUS.md` (Phase 1 details)

---

**Status**: Ready for implementation. All tasks are well-defined with code examples and verification steps.
