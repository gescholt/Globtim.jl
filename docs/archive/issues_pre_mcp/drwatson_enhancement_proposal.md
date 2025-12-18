# Issue: Enhance DrWatson integration for experiment management and result aggregation

**Labels:** enhancement, infrastructure, experiment-management
**Created:** 2025-09-30

## Overview

We currently use DrWatson for basic parameter tracking (`@dict`, `savename()`, `tagsave()`) but aren't leveraging its full experiment management capabilities.

## Current DrWatson Usage

✅ **Already Implemented:**
- `@dict` for parameter dictionaries
- `savename()` for parameter-based filenames
- `tagsave()` for Git provenance (commit hash tracking)
- Structured output directories in `hpc_results/`

❌ **Missing Features:**
- `projectdir()` / `datadir()` for portable paths
- `collect_results!()` for aggregating experiment databases
- `dict_list()` for parameter sweep generation
- Result filtering and querying across experiments

## Motivation

With the 4D L.V. campaign now running 7+ experiments in parallel, we need:
1. **Automated result collection** across multiple experiment runs
2. **Database-style querying** to filter by parameters (GN, degree, domain size)
3. **Reproducible experiment tracking** with proper path management
4. **Easy comparison** of results across parameter sweeps

## Proposed Implementation

### 1. Use `projectdir()` and `datadir()` for Portable Paths

```julia
using DrWatson
@quickactivate "Globtim"

# Replace hardcoded paths
output_dir = datadir("experiments", "lv4d_campaign", savename(params_dict))
```

### 2. Implement Result Aggregation with `collect_results!()`

```julia
# Collect all experiment results into a single DataFrame
results_df = collect_results!(datadir("experiments", "lv4d_campaign"))

# Query and filter
filter(row -> row[:GN] == 5 && row[:success_rate] == 1.0, results_df)
```

### 3. Generate Parameter Sweeps with `dict_list()`

```julia
# Replace manual parameter specification
param_sweep = dict_list(Dict(
    :GN => [5, 6, 8],
    :degree_range => [4:5, 4:6, 4:7],
    :domain_size => [0.1, 0.15, 0.2]
))
```

### 4. Create Analysis Scripts

- `scripts/analysis/aggregate_lv4d_results.jl` - collect and merge all experiments
- `scripts/analysis/query_experiments.jl` - interactive result querying
- `scripts/analysis/compare_parameter_sweeps.jl` - visualization across parameters

## Benefits

1. **Reproducibility**: All paths relative to project root
2. **Scalability**: Easy to manage 100+ experiments
3. **Analysis**: Query results like a database
4. **Integration**: Works seamlessly with existing `tagsave()` workflow

## References

- DrWatson docs: https://juliadynamics.github.io/DrWatson.jl/stable/
- Current campaign: 7 experiments running (launched 2025-09-30)
- Related files: `Examples/minimal_4d_lv_test.jl`, `scripts/launch_4d_lv_campaign.sh`

## Acceptance Criteria

- [ ] All experiment scripts use `projectdir()`/`datadir()` for paths
- [ ] `collect_results!()` script aggregates all L.V. 4D experiments
- [ ] Parameter sweeps defined with `dict_list()`
- [ ] Documentation for DrWatson workflow in `docs/`
- [ ] Example notebook showing result querying and comparison