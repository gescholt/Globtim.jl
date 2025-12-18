# Visualization Guide for globtimcore

## ⚠️ Breaking Change (October 2025): Visualization Removed

**globtimcore NO LONGER contains any visualization code or dependencies.**

All visualization has been migrated to:
- **GlobtimPlots package** - All plotting code, Makie dependencies
- **globtim_results/examples/visualization** - Visualization examples

## Migration Summary

**Removed from globtimcore:**
- ❌ `GLMakie`, `ColorSchemes`, `Colors` dependencies
- ❌ `VisualizationFramework.jl`, `InteractiveVizCore.jl`, `SafeVisualization.jl`
- ❌ `InteractiveViz.jl`, `AlgorithmViz.jl`
- ❌ `valley_walking_demo.jl`, `advanced_analysis_core_demo.jl` (moved to globtim_results)
- ❌ Exports: `InteractiveVizConfig`, `AlgorithmTracker`, visualization functions

**Moved to:**
- ✅ **GlobtimPlots** - All plotting functionality
- ✅ **globtim_results/examples/visualization/** - Example scripts

## Why This Separation?

1. **HPC Compatibility**: globtimcore runs on clusters without display servers
2. **Lightweight Dependencies**: Core computations don't require GUI packages
3. **Reproducibility**: Experiment outputs are independent of visualization
4. **Flexibility**: Multiple plotting backends without affecting core package

## Workflow

```
┌─────────────────────────────────┐
│        1. Run Experiment        │
│         (globtimcore)           │
│                                 │
│  julia experiment.jl            │
│                                 │
│  → Outputs: JSON, CSV, JLD2     │
└────────────┬────────────────────┘
             │
             │ Data files
             │
             ▼
┌─────────────────────────────────┐
│      2. Visualize Results       │
│        (globtimplots)           │
│                                 │
│  cd ../globtimplots             │
│  julia plot_results.jl          │
│                                 │
│  → Outputs: PNG, PDF, SVG       │
└─────────────────────────────────┘
```

## Quick Start

### 1. Run Your Experiment (globtimcore)

```bash
cd globtimcore
julia --project=. experiments/my_experiment.jl
```

**Output location:** `hpc_results/experiment_name_timestamp/`

**Files created:**
- `results_summary.json` - Main results and metrics
- `results_summary.jld2` - DrWatson format with Git provenance
- `critical_points_deg_*.csv` - Critical points per degree
- `experiment_params.json` - Configuration details

### 2. Visualize Results (globtimplots)

```bash
cd ../globtimplots
julia --project=. examples/plot_experiment_results.jl \\
    ../globtimcore/hpc_results/experiment_name_timestamp/
```

**Output:** `output_plots/experiment_name_analysis.png`

## Text-Based Visualization (No GUI)

For terminal/SSH environments, globtimcore includes **text-only** visualization:

```bash
cd globtimcore
julia --project=. scripts/analysis/visualize_cluster_results.jl \\
    hpc_results/experiment_dir/
```

This uses ASCII art in the terminal (no plotting packages required).

## Standard Output Format

All globtimcore experiments should output this structure:

```
hpc_results/experiment_name_timestamp/
├── results_summary.json       ← Required for plotting
├── results_summary.jld2        ← Optional (DrWatson)
├── critical_points_deg_*.csv   ← Per-degree results
└── experiment_params.json      ← Optional metadata
```

### results_summary.json Format

```json
{
  "results_summary": {
    "degree_3": {
      "l2_approx_error": 1.33e-08,
      "total_computation_time": 58.01,
      "critical_points": 1,
      "condition_number": 8.0,
      "status": "success"
    },
    "degree_4": { ... }
  }
}
```

This format is what globtimplots expects.

## Available Visualization Tools

### In globtimplots Package

1. **Standard 4-panel plot**
   ```bash
   julia --project=. examples/plot_experiment_results.jl <exp_dir>
   ```
   - L2 approximation error
   - Computation time
   - Critical points distribution
   - Condition numbers

2. **Multi-experiment comparison**
   ```bash
   julia --project=. examples/plot_comparison.jl <exp1> <exp2> <exp3>
   ```

3. **Interactive exploration** (GLMakie)
   ```julia
   using GLMakie
   # ... interactive 3D plots
   ```

4. **Publication-quality static plots** (CairoMakie)
   ```julia
   using CairoMakie
   # ... high-DPI PNG/PDF output
   ```

### In globtimcore Package (Text-Only)

1. **Terminal ASCII visualization**
   ```bash
   julia --project=. scripts/analysis/visualize_cluster_results.jl <exp_dir>
   ```
   - No GUI required
   - SSH/HPC compatible
   - Text-based charts

## Common Tasks

### Task 1: Visualize Single Experiment

```bash
# 1. Run experiment
cd globtimcore
julia --project=. experiments/lv4d_experiment.jl

# 2. Create plots
cd ../globtimplots
julia --project=. examples/plot_experiment_results.jl \\
    ../globtimcore/hpc_results/experiment_*/
```

### Task 2: Batch Process Multiple Experiments

```bash
cd globtimplots
for exp in ../globtimcore/hpc_results/exp_*/; do
    julia --project=. examples/plot_experiment_results.jl "$exp"
done
```

### Task 3: Quick Check (No Plotting)

```bash
cd globtimcore
julia --project=. -e '
using JSON
results = JSON.parsefile("hpc_results/experiment_dir/results_summary.json")
for (k, v) in results["results_summary"]
    println("$k: $(v["status"]) - L2=$(v["l2_approx_error"])")
end
'
```

## Data Collection from HPC

If experiments run on cluster:

```bash
cd globtimcore
julia --project=. scripts/analysis/collect_cluster_experiments.jl
```

This downloads results via SSH to local machine, then visualize in globtimplots.

## Documentation

### For Visualization Details

See **globtimplots documentation**:
- [`globtimplots/README.md`](../../globtimplots/README.md) - Quick start and overview
- [`globtimplots/docs/PLOTTING_WORKFLOW.md`](../../globtimplots/docs/PLOTTING_WORKFLOW.md) - Complete workflow guide

### For Experiment Design

See **globtimcore documentation**:
- `docs/EXPERIMENTS.md` - Experiment structure
- `docs/OUTPUT_FORMAT.md` - Data format specifications
- `Examples/` - Example experiments

## Troubleshooting

### "Package CairoMakie not found"

**Cause:** Trying to use plotting from globtimcore

**Solution:** Switch to globtimplots:
```bash
cd ../globtimplots
julia --project=.  # Activates correct environment
```

### "No display available" (SSH)

**Options:**

1. **Use text visualization** (in globtimcore):
   ```bash
   julia --project=. scripts/analysis/visualize_cluster_results.jl <exp_dir>
   ```

2. **Generate static plots** (in globtimplots with CairoMakie):
   ```julia
   using CairoMakie  # NOT GLMakie
   # ... create plots
   save("output.png", fig)  # Don't use display()
   ```

3. **Download data and plot locally**:
   ```bash
   # On HPC: collect results
   cd globtimcore
   julia --project=. scripts/analysis/collect_cluster_experiments.jl

   # Locally: visualize
   cd globtimplots
   julia --project=. examples/plot_experiment_results.jl <exp_dir>
   ```

### "results_summary.json not found"

**Cause:** Experiment didn't complete or output directory wrong

**Solution:** Check experiment status:
```bash
ls -la hpc_results/experiment_dir/
# Should see results_summary.json and CSV files
```

## Design Guidelines

When creating new experiments in globtimcore:

1. ✅ **DO** output standardized JSON/CSV format
2. ✅ **DO** use DrWatson's `tagsave()` for JLD2
3. ✅ **DO** include all metrics in `results_summary.json`
4. ❌ **DON'T** add plotting packages to globtimcore dependencies
5. ❌ **DON'T** create visualization code in globtimcore experiments
6. ❌ **DON'T** use `display()` or GUI functions in globtimcore

## Example: Complete Workflow

```bash
# ============================================
# Step 1: Run Experiment (globtimcore)
# ============================================
cd globtimcore
julia --project=. Examples/4DLV/parameter_recovery_experiment.jl

# Experiment runs, outputs to:
# hpc_results/4dlv_recovery_GN=16_domain_size_param=0.4_20251004_123456/

# ============================================
# Step 2: Quick Text Check (globtimcore)
# ============================================
julia --project=. scripts/analysis/visualize_cluster_results.jl \\
    hpc_results/4dlv_recovery_GN=16_domain_size_param=0.4_20251004_123456/

# Shows ASCII plots in terminal

# ============================================
# Step 3: Generate Publication Plots (globtimplots)
# ============================================
cd ../globtimplots

# Install if first time
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Create visualization
julia --project=. examples/plot_experiment_results.jl \\
    ../globtimcore/hpc_results/4dlv_recovery_GN=16_domain_size_param=0.4_20251004_123456/

# Output: output_plots/4dlv_recovery_GN=16_domain_size_param=0.4_20251004_123456_analysis.png
```

## Summary

| Package | Contains | Used For |
|---------|----------|----------|
| **globtimcore** | Mathematical algorithms, experiments | Computation, data generation |
| **globtimplots** | CairoMakie, GLMakie, plotting tools | Visualization, plots |

**Remember:** Always run plotting from `globtimplots`, not `globtimcore`.

## Quick Reference

| Task | Location | Command |
|------|----------|---------|
| Run experiment | globtimcore | `julia --project=. experiments/exp.jl` |
| Text visualization | globtimcore | `julia --project=. scripts/analysis/visualize_cluster_results.jl <dir>` |
| **Static plots** | **globtimplots** | `julia --project=. examples/plot_experiment_results.jl <dir>` |
| **Interactive plots** | **globtimplots** | `julia --project=. examples/plot_interactive.jl <dir>` |
| Comparison plots | globtimplots | `julia --project=. examples/plot_comparison.jl <dirs...>` |

---

**For complete visualization documentation, see [`globtimplots/docs/PLOTTING_WORKFLOW.md`](../../globtimplots/docs/PLOTTING_WORKFLOW.md)**
