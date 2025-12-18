# Lotka-Volterra 4D Experiment Template (2025)

Modern, unified template for 4D Lotka-Volterra parameter recovery experiments using StandardExperiment.jl with Schema v1.2.0 validation.

## Features

- **Single entry point**: One Julia script, all parameters configurable via command-line
- **Schema v1.2.0 compliant**: Automatic ForwardDiff validation included
  - Gradient norm verification (spurious critical point detection)
  - Hessian-based classification (minimum/maximum/saddle)
  - Distinct local minima detection
  - Enhanced CSV output with validation columns
  - JSON output with `validation_stats`
- **Flexible basis selection**: Choose between Chebyshev (default) or Legendre polynomials
- **Reproducible**: Random seed control for p_true generation
- **Best practices**: Uses `GLOBTIM_RESULTS_ROOT` environment variable

## Quick Start

```bash
# Basic usage (Chebyshev basis, default settings)
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl

# Custom configuration
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \
    --GN 16 \
    --degree-range 4:2:12 \
    --domain 0.4 \
    --seed 42

# Compare Chebyshev vs Legendre basis
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \
    --basis legendre \
    --GN 12 \
    --degree-range 4:2:10
```

## Command-Line Arguments

| Argument         | Type    | Default        | Description                                      |
|------------------|---------|----------------|--------------------------------------------------|
| `--GN`           | Int     | 16             | Grid nodes per dimension (samples)               |
| `--degree-range` | String  | `"4:2:12"`     | Polynomial degrees as `start:step:stop`          |
| `--domain`       | Float64 | 0.4            | Domain size around center (±value)               |
| `--basis`        | String  | `"chebyshev"`  | Polynomial basis (`chebyshev` or `legendre`)     |
| `--seed`         | Int?    | `nothing`      | Random seed for p_true generation                |
| `--p-true`       | String? | `nothing`      | Explicit p_true as comma-separated (e.g., `0.2,0.3,0.5,0.6`) |
| `--output-dir`   | String? | `nothing`      | Custom output directory (default: `GLOBTIM_RESULTS_ROOT/lotka_volterra_4d/`) |
| `--max-time`     | Float64 | 300.0          | Maximum time per degree (seconds)                |

## Output Structure

### Directory Layout
```
$GLOBTIM_RESULTS_ROOT/lotka_volterra_4d/
└── lv4d_GN16_domain0.4_seed42_20251021_103045/
    ├── results_summary.json          # Schema v1.2.0 with validation_stats
    ├── critical_points_deg_4.csv     # CSV with validation columns
    ├── critical_points_deg_6.csv
    └── ...
```

### CSV Columns (Enhanced for v1.2.0)

**Raw polynomial critical points:**
- `theta1_raw`, `theta2_raw`, `theta3_raw`, `theta4_raw`

**BFGS-refined points:**
- `theta1`, `theta2`, `theta3`, `theta4`

**Objective values:**
- `objective_raw`, `objective`

**Validation columns (NEW in v1.2.0):**
- `gradient_norm`: ||∇f|| for gradient verification
- `is_spurious`: `true` if gradient_norm >= tolerance (not a true critical point)
- `classification`: Hessian classification (`minimum`, `maximum`, `saddle`, `degenerate`, `error`)
- `eigenvalue_min`, `eigenvalue_max`: Hessian eigenvalue range
- `hessian_condition_number`: Condition number of Hessian
- `determinant`: Determinant of Hessian

**Recovery metrics:**
- `l2_approx_error`: L2 approximation error
- `recovery_error`: ||θ - θ_true|| (if true_params provided)
- `refinement_improvement`: Objective improvement from refinement

### JSON Schema v1.2.0

```json
{
  "schema_version": "1.2.0",
  "experiment_id": "lv4d_GN16_domain0.4_seed42_20251021_103045",
  "experiment_type": "4d_lotka_volterra",
  "system_info": {
    "system_type": "lotka_volterra_4d",
    "dimension": 4,
    "domain_center": [0.224, 0.273, 0.473, 0.578],
    "domain_size": 0.4,
    "known_equilibrium": [0.2, 0.3, 0.5, 0.6],
    "objective_function": "squared_system_residual"
  },
  "results_summary": {
    "degree_4": {
      "critical_points": 12,
      "validation_stats": {
        "gradient_tol": 1e-6,
        "critical_verified": 10,
        "critical_spurious": 2,
        "gradient_norm_mean": 3.2e-7,
        "classifications": {
          "minimum": 8,
          "maximum": 1,
          "saddle": 3
        },
        "distinct_local_minima": 3,
        "minima_cluster_sizes": [5, 3, 2]
      }
    }
  }
}
```

## Use Cases

### 1. Domain Size Sweep
```bash
for domain in 0.2 0.3 0.4 0.5; do
    julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \
        --domain $domain \
        --seed 42 \
        --GN 16
done
```

### 2. Basis Comparison
```bash
# Chebyshev
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \
    --basis chebyshev --seed 42 --output-dir /tmp/cheb_basis

# Legendre
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \
    --basis legendre --seed 42 --output-dir /tmp/leg_basis
```

### 3. HPC Cluster Run
```bash
# Set environment variable for cluster results location
export GLOBTIM_RESULTS_ROOT=/path/to/cluster/results

# Launch experiment
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \
    --GN 20 \
    --degree-range 4:2:18 \
    --max-time 600
```

## Analysis

View results using globtimpostprocessing:

```julia
using Pkg
Pkg.activate("globtimpostprocessing")

include("globtimpostprocessing/analyze_experiments.jl")

# Analyze single experiment
analyze_single_experiment("/path/to/lv4d_GN16_domain0.4_seed42_20251021_103045")

# View validation stats
display_validation_stats("/path/to/lv4d_GN16_domain0.4_seed42_20251021_103045")
```

## Migration from Legacy Templates

**Replaced directories** (archived in `experiments/_archived/`):
- `lv4d_campaign_2025/` - Old campaign scripts with shell launchers
- `lv4d_loss_comparison_2025/` - Loss function comparison experiments

**Key improvements:**
- ✅ Single Julia entry point (no shell scripts)
- ✅ StandardExperiment.jl integration
- ✅ Schema v1.2.0 with validation
- ✅ Command-line parameter control
- ✅ Basis selection support
- ✅ Automatic spurious critical point detection

## Environment Setup

Ensure `GLOBTIM_RESULTS_ROOT` is set:

```bash
# Add to ~/.bashrc or ~/.zshrc
export GLOBTIM_RESULTS_ROOT=$HOME/globtim_results

# Or set per-session
export GLOBTIM_RESULTS_ROOT=/scratch/user/results  # HPC cluster
```

## Notes

- Default p_center: `[0.224, 0.273, 0.473, 0.578]` (empirically chosen)
- Default p_true generation: Random within 80% of domain (if --seed provided)
- Gradient tolerance for spurious detection: `1e-6`
- Distinct minima clustering: Spatial distance < `1e-3` AND objective difference < `1e-6`

## Related Documentation

- [Experiment Schema v1.2.0](../../EXPERIMENT_SCHEMA.md)
- [StandardExperiment.jl](../../src/StandardExperiment.jl)
- [Analysis Tools](../../../globtimpostprocessing/analyze_experiments.jl)
