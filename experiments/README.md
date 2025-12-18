# Globtim Experiments

This directory contains experiment templates and configurations for running global optimization and parameter recovery studies using the Globtim package.

## Directory Structure

```
experiments/
├── README.md                  # This file - overview of all experiments
├── daisy_ex3_4d_study/        # DAISY Example 3 model (4D parameter recovery)
├── lv4d_2025/                 # Lotka-Volterra 4D experiments (modern template)
├── generated/                 # Auto-generated experiment scripts
└── _archived/                 # Deprecated/old experiments (not actively maintained)
```

## Active Experiments

### 1. DAISY Example 3 (4D Parameter Recovery)

**Directory:** `daisy_ex3_4d_study/`

**Purpose:** Parameter recovery for the DAISY Example 3 ODE system using polynomial approximation and critical point finding.

**Model Details:**
- 4D ODE system with parameters: p1, p3, p4, p6
- True parameters: [0.2, 0.3, 0.5, 0.6]
- Uses `define_daisy_ex3_model_4D` from `Dynamic_objectives` package

**Key Scripts:**
- `setup_experiments.jl` - Main experiment setup
- `validate_environment.jl` - HPC environment validation
- `quick_validation.jl` - Quick sanity checks

**Documentation:** See `daisy_ex3_4d_study/README_IMPORTANT.md`

**Note:** This directory was previously misnamed "lotka_volterra_4d_study" - it has been corrected to reflect the actual model used.

---

### 2. Lotka-Volterra 4D (Modern Template)

**Directory:** `lv4d_2025/`

**Purpose:** Modern, unified template for 4D Lotka-Volterra parameter recovery using StandardExperiment.jl with Schema v1.2.0 validation.

**Features:**
- Single Julia entry point with command-line arguments
- Schema v1.2.0 compliant (ForwardDiff gradient/Hessian validation)
- Spurious critical point detection
- Distinct local minima identification
- Flexible basis selection (Chebyshev/Legendre)
- Automatic results export with validation columns

**Quick Start:**
```bash
# Basic usage
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl

# Custom configuration
julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \
    --GN 16 \
    --degree-range 4:2:12 \
    --domain 0.4 \
    --seed 42
```

**Documentation:** See `lv4d_2025/README.md`

---

### 3. Generated Experiments

**Directory:** `generated/`

**Purpose:** Auto-generated experiment scripts created from templates (typically via MCP tools or automation).

**Usage:**
- Generated files follow naming pattern: `{experiment_type}_deg{min}-{max}_domain{size}_GN{gridnodes}_{timestamp}.jl`
- **Do not edit manually** - regenerate from templates instead
- Files are git-ignored and can be safely deleted

**Documentation:** See `generated/README.md`

---

## Experiment Workflow

### Standard Workflow

1. **Choose/Create Template**
   - Use existing template (e.g., `lv4d_2025/`) or create new one
   - Templates should use StandardExperiment.jl for consistency

2. **Configure Parameters**
   - Set domain size, grid resolution (GN), polynomial degrees
   - Define objective function and true parameters (if known)

3. **Run Experiment**
   - Local testing: Use small GN and limited degrees
   - HPC cluster: Use full configuration with `GLOBTIM_RESULTS_ROOT` set

4. **Results Location**
   - Results saved to `$GLOBTIM_RESULTS_ROOT/{experiment_type}/`
   - Each run creates timestamped directory with unique experiment_id

5. **Analysis**
   - Use `globtimpostprocessing` package for analysis
   - Use `globtimplots` package for visualization

### Best Practices

#### Environment Setup

```bash
# Set results directory (add to ~/.bashrc or ~/.zshrc)
export GLOBTIM_RESULTS_ROOT=$HOME/globtim_results

# For HPC cluster
export GLOBTIM_RESULTS_ROOT=/scratch/$USER/results
```

#### Experiment Design

- **Start small:** Test locally with GN=4-6, degree=4 before full runs
- **Use seeds:** Always specify `--seed` for reproducibility
- **Document true parameters:** If known, include in experiment metadata
- **Validate environment:** Run validation scripts before large campaigns

#### Results Management

- **Use unique experiment_ids:** Automatically generated with timestamps
- **Export metadata:** Always save experiment configuration as JSON
- **Track provenance:** Include git commit hash in results metadata

## Creating New Experiments

### Option 1: Use Existing Template

Recommended for similar experiments (e.g., different ODE systems with same structure).

```bash
# Copy and modify lv4d_2025 template
cp -r experiments/lv4d_2025 experiments/my_ode_system_2025
cd experiments/my_ode_system_2025

# Edit lv4d_experiment.jl:
# - Change objective function
# - Update domain/parameters
# - Adjust experiment_type identifier
```

### Option 2: Create from Scratch

For novel experiment types:

```julia
# experiments/my_new_experiment/setup.jl

using Globtim
using Globtim.StandardExperiment

# Define objective function
function my_objective(params::Vector{Float64})
    # Your objective here
    return loss_value
end

# Create experiment configuration
config = ExperimentConfig(
    objective_function = my_objective,
    dimension = 4,
    domain_center = [0.0, 0.0, 0.0, 0.0],
    domain_size = 0.5,
    grid_nodes = 16,
    polynomial_degrees = 4:2:12,
    basis = :chebyshev
)

# Run experiment
results = run_standard_experiment(config)
```

### Option 3: Use MCP Generation Tools

For batch generation from templates:

```julia
# Via MCP server
using MCPGlobtim

# Generate experiment from template
generate_experiment_script(
    template = "lv4d",
    parameters = Dict(
        "domain_range" => 0.4,
        "GN" => 16,
        "degree_min" => 4,
        "degree_max" => 12
    ),
    output_dir = "experiments/generated/"
)
```

## Experiment Schema

All experiments should produce Schema v1.2.0-compliant output:

### Required Files

1. **results_summary.json** - Experiment metadata and results summary
2. **critical_points_deg_*.csv** - Critical points for each polynomial degree
3. **experiment_config.json** - Full experiment configuration

### JSON Schema (v1.2.0)

```json
{
  "schema_version": "1.2.0",
  "experiment_id": "unique_experiment_id",
  "experiment_type": "parameter_recovery",
  "system_info": {
    "system_type": "ode_system",
    "dimension": 4,
    "domain_center": [0.0, 0.0, 0.0, 0.0],
    "domain_size": 0.4
  },
  "polynomial_config": {
    "basis": "chebyshev",
    "degrees": [4, 6, 8, 10, 12],
    "grid_nodes": 16
  },
  "results_summary": {
    "degree_4": {
      "critical_points": 12,
      "validation_stats": {
        "gradient_tol": 1e-6,
        "critical_verified": 10,
        "critical_spurious": 2,
        "classifications": {
          "minimum": 8,
          "maximum": 1,
          "saddle": 3
        },
        "distinct_local_minima": 3
      }
    }
  }
}
```

### CSV Columns (Enhanced)

**Critical Points CSV:**
- Raw polynomial critical points: `theta1_raw`, `theta2_raw`, ...
- BFGS-refined points: `theta1`, `theta2`, ...
- Objective values: `objective_raw`, `objective`
- **Validation columns (v1.2.0):**
  - `gradient_norm` - Gradient magnitude at point
  - `is_spurious` - Boolean flag for spurious critical points
  - `classification` - Hessian-based classification (minimum/maximum/saddle)
  - `eigenvalue_min`, `eigenvalue_max` - Hessian eigenvalue range
  - `hessian_condition_number` - Conditioning of Hessian
- Recovery metrics: `l2_approx_error`, `recovery_error`, `refinement_improvement`

## Common Analysis Tasks

### 1. View Experiment Results

```julia
using Pkg
Pkg.activate("globtimpostprocessing")

include("globtimpostprocessing/analyze_experiments.jl")

# Analyze single experiment
analyze_single_experiment("/path/to/experiment_directory")
```

### 2. Compare Multiple Experiments

```julia
# Compare domain sweep
compare_experiments([
    "lv4d_domain0.2_20251021_100000",
    "lv4d_domain0.3_20251021_100100",
    "lv4d_domain0.4_20251021_100200"
])
```

### 3. Plot Critical Points

```julia
using Pkg
Pkg.activate("globtimplots")
using GlobtimPlots
using CairoMakie

# Load results
results = load_experiment_results("/path/to/experiment")

# Create plot
fig = plot_critical_points(results, degree=8)
save("critical_points_deg8.pdf", fig)
```

### 4. Extract Best Critical Point

```julia
# Find critical point closest to true parameters
best_point = find_best_recovery(
    results,
    true_params = [0.2, 0.3, 0.5, 0.6]
)

println("Best recovery: $(best_point.theta)")
println("Distance from true: $(best_point.recovery_error)")
```

## Troubleshooting

### Issue: Experiment hangs during polynomial solving

**Cause:** High degree polynomials with large grid (GN)

**Solution:**
- Reduce GN or degree temporarily
- Use `--max-time` argument to set timeout
- Check HomotopyContinuation solver settings

### Issue: No critical points found

**Causes:**
- Domain doesn't contain critical points
- Polynomial degree too low
- Grid resolution (GN) too coarse

**Solutions:**
- Increase domain size
- Try higher polynomial degrees
- Increase grid resolution (GN)
- Verify objective function implementation

### Issue: All critical points classified as "spurious"

**Cause:** Gradient tolerance too strict or objective function issues

**Solutions:**
- Check objective function gradient implementation
- Adjust gradient tolerance in validation
- Verify ForwardDiff compatibility

### Issue: Results not saving to expected location

**Cause:** `GLOBTIM_RESULTS_ROOT` not set or incorrect

**Solution:**
```bash
# Check current setting
echo $GLOBTIM_RESULTS_ROOT

# Set correctly
export GLOBTIM_RESULTS_ROOT=/path/to/results

# Verify directory exists and is writable
mkdir -p $GLOBTIM_RESULTS_ROOT
```

## Migration from Legacy Experiments

Legacy experiments in `_archived/` are **deprecated** and should not be used for new work.

**Key changes in modern templates:**

| Aspect | Legacy | Modern (2025) |
|--------|--------|---------------|
| Entry point | Multiple shell scripts | Single Julia file with CLI args |
| Configuration | Hardcoded in scripts | Command-line arguments |
| Schema | Pre-v1.0 or none | Schema v1.2.0 with validation |
| Validation | Manual/absent | Automatic ForwardDiff validation |
| Basis | Chebyshev only | Chebyshev or Legendre |
| Results | Custom format | Standardized JSON/CSV |

**Migration steps:**
1. Identify experiment type in `_archived/`
2. Use corresponding modern template (e.g., `lv4d_2025/`)
3. Extract configuration parameters from legacy scripts
4. Run modern template with equivalent parameters
5. Validate results match (within numerical tolerance)

## Related Documentation

### Core Package Documentation
- [Globtim Core](../README.md) - Main package documentation
- [StandardExperiment.jl](../src/StandardExperiment.jl) - Standard experiment interface
- [Experiment Schema v1.2.0](../EXPERIMENT_SCHEMA.md) - Output format specification

### Related Packages
- [globtimpostprocessing](../../globtimpostprocessing/) - Results analysis
- [globtimplots](../../globtimplots/) - Visualization tools
- [Dynamic_objectives](https://git.mpi-cbg.de/globaloptim/dynamic_objectives) - ODE models

### Specific Experiments
- [DAISY Example 3](daisy_ex3_4d_study/README_IMPORTANT.md) - DAISY model experiments
- [Lotka-Volterra 4D](lv4d_2025/README.md) - LV4D modern template
- [Generated Experiments](generated/README.md) - Auto-generated scripts

## Contributing

When adding new experiments:

1. **Create descriptive directory name:** Use format `{model}_{year}/` (e.g., `pendulum_2025/`)
2. **Include README.md:** Document purpose, usage, and configuration
3. **Use StandardExperiment.jl:** Follow established patterns for consistency
4. **Validate schema compliance:** Ensure output follows Schema v1.2.0
5. **Add validation script:** Include environment/setup validation
6. **Document true parameters:** If known, include in metadata
7. **Update this README:** Add entry to "Active Experiments" section

## Support

For issues or questions:

1. Check this README and experiment-specific documentation
2. Review [globtimcore issues](https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues)
3. Create new issue with `experiment::` label if needed

## Version History

- **2025-10-24:** Created comprehensive experiments README (Issue #196)
- **2025-10-21:** Added lv4d_2025 modern template with Schema v1.2.0
- **2025-10-11:** Renamed lotka_volterra_4d_study to daisy_ex3_4d_study (Issue #141)
- **2025-10-08:** Identified and documented DAISY model misidentification
