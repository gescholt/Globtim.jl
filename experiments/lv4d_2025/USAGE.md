# LV4D Experiment Usage

## Basic Command

```bash
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl [OPTIONS]
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--GN` | Int | 16 | Grid nodes per dimension |
| `--degree-range` | String | "4:2:12" | Polynomial degrees (start:step:stop) |
| `--domain` | Float | 0.4 | Domain size (±value around center) |
| `--basis` | String | "chebyshev" | Basis type: "chebyshev" or "legendre" |
| `--seed` | Int | none | Random seed for p_true generation |
| `--p-true` | String | none | Explicit p_true (e.g., "0.2,0.3,0.5,0.6") |
| `--max-time` | Float | 300.0 | Max seconds per degree |
| `--output-dir` | String | auto | Custom output directory |

## Output Path Logic

### Default (no --output-dir)

```
$GLOBTIM_RESULTS_ROOT/lotka_volterra_4d/lv4d_GN{GN}_domain{domain}_seed{seed}_{timestamp}/
```

**Path resolution:**
1. Uses `GLOBTIM_RESULTS_ROOT` environment variable if set
2. Falls back to `{globtimcore_parent}/globtim_results/` if not set
3. Creates subdirectory: `lotka_volterra_4d/`
4. Experiment directory: `lv4d_GN16_domain0.4_seed42_20251021_103045/`

**Example:**
```bash
export GLOBTIM_RESULTS_ROOT=/scratch/user/results
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl --seed 42
# Output: /scratch/user/results/lotka_volterra_4d/lv4d_GN16_domain0.4_seed42_20251021_103045/
```

### Custom (with --output-dir)

Uses exact path provided:

```bash
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl --output-dir /tmp/my_experiment
# Output: /tmp/my_experiment/
```

## Examples

### Local run with defaults
```bash
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl
```

### HPC cluster run
```bash
export GLOBTIM_RESULTS_ROOT=/scratch/$USER/results
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \
    --GN 20 \
    --degree-range 4:2:18 \
    --seed 42
```

### Basis comparison
```bash
# Chebyshev
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl --basis chebyshev --seed 42

# Legendre
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl --basis legendre --seed 42
```

### Domain sweep
```bash
for d in 0.2 0.3 0.4 0.5; do
    julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \
        --domain $d --seed 42 --GN 16
done
```

## Output Files

```
output_directory/
├── results_summary.json              # Schema v1.2.0 with validation_stats
├── critical_points_deg_4.csv         # CSV with validation columns
├── critical_points_deg_6.csv
└── ...
```

## Environment Setup

Set output location (recommended for cluster):

```bash
# In ~/.bashrc or ~/.zshrc
export GLOBTIM_RESULTS_ROOT=$HOME/globtim_results

# Or per-session
export GLOBTIM_RESULTS_ROOT=/scratch/$USER/results
```
