# GlobtimPlots

GlobtimPlots is a companion package for publication-quality visualizations from Globtim experiments.

**Pipeline**: Globtim (experiments) → GlobtimPostProcessing (analysis) → GlobtimPlots (visualization)

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/gescholt/GlobtimPlots.jl")
```

## Backend Selection

| Backend | Use Case | Output |
|---------|----------|--------|
| CairoMakie | Publication figures, batch processing, HPC | PDF, PNG, SVG |
| GLMakie | Interactive exploration, presentations | Window, animations |

```julia
using GlobtimPlots

# Static backend (recommended for publications)
CairoMakie.activate!()

# Interactive backend (for exploration)
# using GLMakie
# GLMakie.activate!()
```

!!! note
    GLMakie requires a display. Use CairoMakie on headless servers/HPC.

## Workflow

### 1. Run Globtim Experiment

```julia
using Globtim, DynamicPolynomials

f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8, precision=AdaptivePrecision)

@polyvar x[1:2]
solutions = solve_polynomial_system(x, pol)
df = process_crit_pts(solutions, f, TR)
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
```

### 2. Visualize Results

```julia
using GlobtimPlots
CairoMakie.activate!()

# Critical point scatter plot
fig = plot_critical_points(df_min)
save("critical_points.pdf", fig)

# Level set visualization
fig = create_level_set_visualization(pol, TR, solutions)
save("levelset.png", fig)

# Convergence analysis (from degree sweep)
degrees = [4, 6, 8, 10, 12]
l2_errors = [Constructor(TR, d, precision=AdaptivePrecision).nrm for d in degrees]
fig = plot_convergence_analysis(degrees, l2_errors)
save("convergence.pdf", fig)
```

### 3. Campaign Comparison

For comparing multiple experiments:

```julia
using GlobtimPostProcessing

campaign = load_campaign_results("hpc_results/")
fig = create_campaign_comparison_plot(campaign)
save("campaign_comparison.pdf", fig)
```

## Key Functions

### Level Set Visualization

```julia
create_level_set_visualization(pol, TR, solutions)  # 3D level set surface
plot_polyapprox_levelset(pol, TR)                   # 2D contour plot
create_level_set_animation(pol, TR, "output.mp4")   # Rotating animation
```

### Convergence Analysis

```julia
plot_convergence_analysis(degrees, l2_errors)       # L2 error vs degree
plot_discrete_l2(results_dict)                      # Discrete L2 comparison
```

### Critical Points

```julia
plot_critical_points(df)                            # Scatter plot
plot_hessian_norms(df)                              # Hessian norm distribution
plot_critical_eigenvalues(df)                       # Eigenvalue spectrum
plot_condition_numbers(df)                          # Condition number plot
```

### Campaign Comparison

```julia
create_experiment_plots(result)                     # Single experiment suite
create_campaign_comparison_plot(campaign)           # Multi-experiment comparison
```

### RL Training (GlobTimRL)

```julia
plot_training_progress(metrics)                     # Loss/reward curves
create_training_dashboard(metrics)                  # Full dashboard
plot_action_ratio_evolution(history)                # Policy changes over time
plot_state_action_heatmap(policy_data)              # State-action visualization
```

### Subdivision Trees

```julia
plot_subdivision_tree(tree)                         # Adaptive refinement tree
```

### 1D Approximation

```julia
plot_1d_polynomial_approximation(f, pol, domain)    # 1D function + polynomial
plot_1d_comparison(f, pols, domain)                 # Compare multiple degrees
```

## Quick Reference

| Function | Purpose |
|----------|---------|
| `create_level_set_visualization` | 3D level set surface with critical points |
| `plot_convergence_analysis` | L2 error convergence plot |
| `plot_critical_points` | Critical point scatter plot |
| `create_campaign_comparison_plot` | Compare multiple experiments |
| `create_training_dashboard` | RL training metrics dashboard |
| `plot_subdivision_tree` | Visualize adaptive refinement tree |
| `plot_1d_polynomial_approximation` | 1D function approximation comparison |

## Export Options

All plotting functions return Makie `Figure` objects:

```julia
# Vector formats (recommended for publications)
save("figure.pdf", fig)
save("figure.svg", fig)

# Raster formats
save("figure.png", fig)

# High-DPI output
save("figure.png", fig; px_per_unit=2)
```
