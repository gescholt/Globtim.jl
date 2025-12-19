# GlobtimPostProcessing Integration Guide

## Overview

GlobtimPostProcessing refines raw critical point *candidates* from Globtim's polynomial approximation into verified critical points with high numerical accuracy (~1e-12).

**Pipeline**: Globtim (candidates) → GlobtimPostProcessing (refinement) → GlobtimPlots (visualization)

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/gescholt/GlobtimPostProcessing.jl")
```

## Workflow

### 1. Run Globtim Experiment

Globtim produces these output files:
```
experiment_dir/
├── critical_points_deg_4.csv      # Raw critical point candidates
├── critical_points_deg_6.csv
├── critical_points_deg_8.csv
├── experiment_config.json         # Experiment parameters
└── results_summary.json           # Summary metrics
```

### 2. Load and Analyze Results

```julia
using GlobtimPostProcessing

# Load single experiment
result = load_experiment_results("path/to/experiment_dir")

# Access critical points (DataFrame)
df = result.critical_points
println("Found $(nrow(df)) critical points")

# Load multiple experiments (campaign)
campaign = load_campaign_results("path/to/hpc_results")
```

### 3. Refine Critical Points

```julia
# Define YOUR objective function (same one used in Globtim)
function my_objective(p)
    # Your cost function here
    return cost
end

# Refine all critical points
refined = refine_experiment_results(
    "path/to/experiment_dir",
    my_objective,
    ode_refinement_config()  # Use for ODE-based problems
)

# Access results
println("Converged: $(refined.n_converged)/$(refined.n_raw)")
println("Best value: $(refined.best_refined_value)")
```

### 4. Quality Diagnostics

```julia
# Check L2 approximation quality
quality = check_l2_quality("path/to/experiment_dir")

# Validate critical points (gradient should be ~0)
validation = validate_critical_points(df, my_objective)
```

## Data Format

**Critical points CSV** (x1, x2, ..., xN are coordinates, z is objective value):
```csv
x1,x2,x3,x4,z
0.694,0.283,0.456,0.789,10.35
```

**experiment_config.json**:
```json
{
  "dimension": 4,
  "GN": 16,
  "domain_range": 0.4,
  "p_true": [0.2, 0.3, 0.5, 0.6]
}
```

## Key Functions

| Function | Purpose |
|----------|---------|
| `load_experiment_results(dir)` | Load single experiment |
| `load_campaign_results(dir)` | Load multiple experiments |
| `refine_experiment_results(dir, f, config)` | Refine critical points |
| `validate_critical_points(df, f)` | Verify ||∇f|| ≈ 0 |
| `check_l2_quality(dir)` | L2 approximation assessment |
| `generate_report(result, stats)` | Generate text report |

## Configuration Presets

```julia
# For ODE parameter estimation problems
config = ode_refinement_config()

# For algebraic/analytic functions
config = RefinementConfig(
    method = Optim.BFGS(),
    gradient_method = :forwarddiff
)
```

## Notes

- GlobtimPostProcessing performs analysis only (no plotting)
- For visualization, use GlobtimPlots with the refined results
- Critical point refinement requires YOUR objective function to be defined
