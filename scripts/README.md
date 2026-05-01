# Globtim Scripts

## Multi-Package Setup

These scripts are part of the **Globtim** package but require additional packages
to run experiments. The experiment pipeline uses three packages together:

| Package | Role | Required for |
|---------|------|-------------|
| **Globtim** | Core polynomial approximation + HomotopyContinuation | All scripts |
| **Dynamic_objectives** | ODE model definitions, catalogues, screening | ODE experiments |
| **GlobtimPostProcessing** | Refinement, Newton analysis, capture metrics | Post-processing |

Install all three as dev dependencies before running:

```julia
using Pkg
Pkg.develop(path="globtim")
Pkg.develop(path="Dynamic_objectives")
Pkg.develop(path="globtimpostprocessing")
Pkg.instantiate()
```

---

## Experiment Pipeline

| Script | Purpose | Usage |
|--------|---------|-------|
| `run_experiment.jl` | Run Globtim CP recovery from TOML config | `julia --project=. globtim/scripts/run_experiment.jl config.toml` |
| `postprocess_experiment.jl` | Re-run analysis on saved results | `julia --project=. globtim/scripts/postprocess_experiment.jl results_dir/ --all` |

Run `--help` on `run_experiment.jl` or `postprocess_experiment.jl` for full options.

See [docs/EXPERIMENT_CONFIG_REFERENCE.md](../../docs/EXPERIMENT_CONFIG_REFERENCE.md) for the TOML config schema.

---

## Running Experiments

### Analytical Benchmarks (no ODE solver needed)

```bash
julia --project=. globtim/scripts/run_experiment.jl examples/configs/ackley_3d.toml
julia --project=. globtim/scripts/run_experiment.jl examples/configs/*.toml
julia --project=. globtim/scripts/run_experiment.jl --dry-run examples/configs/*.toml
```

### ODE Paper Experiments

The experiment configs live in `Dynamic_objectives/paper/configs/`. Run from the repo root:

```bash
# Run a single paper experiment
julia --project=. globtim/scripts/run_experiment.jl Dynamic_objectives/paper/configs/lv2d.toml

# Run all paper experiments
julia --project=. globtim/scripts/run_experiment.jl Dynamic_objectives/paper/configs/*.toml

# Dry-run (validate configs without executing)
julia --project=. globtim/scripts/run_experiment.jl --dry-run Dynamic_objectives/paper/configs/*.toml

# Re-analyze saved results
julia --project=. globtim/scripts/postprocess_experiment.jl results/lv2d/ --all
```

See `Dynamic_objectives/paper/README.md` for the full experiment list and config reference.

---

## Directory Contents

```
globtim/scripts/
├── run_experiment.jl          # Experiment pipeline CLI
├── postprocess_experiment.jl  # Post-processing CLI
└── README.md                  # This file
```
