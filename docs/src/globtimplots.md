# GlobtimPlots

GlobtimPlots is Globtim's visualization layer - a Makie wrapper providing custom plotting functions for polynomial approximation and critical point analysis.

## Package Role

GlobtimPlots is **not a standalone package**. It is designed specifically for Globtim visualization needs:

- **Makie wrapper** - Uses CairoMakie/GLMakie as the backend for all plots
- **Globtim-specific** - Provides plot recipes tailored to polynomial approximation workflows
- **Future integration** - Will become an actual dependency of Globtim when the API stabilizes

**Pipeline**: Globtim (experiments) → GlobtimPostProcessing (analysis) → GlobtimPlots (visualization)

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

## Basic Workflow

```julia
using Globtim, DynamicPolynomials, GlobtimPlots
CairoMakie.activate!()

# 1. Run experiment
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)

@polyvar x[1:2]
solutions = solve_polynomial_system(x, pol)
df = process_crit_pts(solutions, f, TR)
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# 2. Visualize
fig = plot_critical_points(df_min)
save("critical_points.pdf", fig)
```

## Hessian Analysis Plots

### Hessian Norms

Visualize the Frobenius norm of Hessian matrices:

```julia
fig = plot_hessian_norms(df_enhanced)
save("hessian_norms.png", fig)
```

This scatter plot shows ||H||_F for each critical point, colored by type (minimum, maximum, saddle).

### Condition Numbers

Analyze numerical stability:

```julia
fig = plot_condition_numbers(df_enhanced)
```

Displays log-scale condition numbers κ(H) = |λ_max|/|λ_min|. High values indicate potential numerical issues.

### Critical Eigenvalues

Validate minima and maxima:

```julia
fig = plot_critical_eigenvalues(df_enhanced)
```

Shows:
- Left: Smallest positive eigenvalues for minima
- Right: Largest negative eigenvalues for maxima

## Eigenvalue Spectrum

### All Eigenvalues

Comprehensive eigenvalue visualization:

```julia
# Sort by magnitude (preserves signs)
fig1 = plot_all_eigenvalues(f, df_enhanced, sort_by=:magnitude)

# Sort by absolute value
fig2 = plot_all_eigenvalues(f, df_enhanced, sort_by=:abs_magnitude)

# Sort by eigenvalue spread
fig3 = plot_all_eigenvalues(f, df_enhanced, sort_by=:spread)
```

Features:
- Separate subplots for each critical point type
- Vertical alignment with dotted connections
- Color coding by point index

### Raw vs Refined Comparison

Compare eigenvalues before and after BFGS refinement:

```julia
# Default: ordered by point distance
fig = plot_raw_vs_refined_eigenvalues(f, df_raw, df_enhanced)

# Order by function value difference
fig = plot_raw_vs_refined_eigenvalues(f, df_raw, df_enhanced,
                                     sort_by=:function_value_diff)

# Order by eigenvalue norm difference
fig = plot_raw_vs_refined_eigenvalues(f, df_raw, df_enhanced,
                                     sort_by=:eigenvalue_diff)
```

## Level Sets & Convergence

### Level Set Visualization

```julia
create_level_set_visualization(pol, TR, solutions)  # 3D level set surface
plot_polyapprox_levelset(pol, TR)                   # 2D contour plot
create_level_set_animation(pol, TR, "output.mp4")   # Rotating animation
```

### Convergence Analysis

```julia
degrees = [4, 6, 8, 10, 12]
l2_errors = [Constructor(TR, d).nrm for d in degrees]
fig = plot_convergence_analysis(degrees, l2_errors)
save("convergence.pdf", fig)
```

## Campaign & RL Functions

### Campaign Comparison

```julia
using GlobtimPostProcessing

campaign = load_campaign_results("hpc_results/")
fig = create_campaign_comparison_plot(campaign)
save("campaign_comparison.pdf", fig)
```

### RL Training (GlobTimRL)

```julia
plot_training_progress(metrics)                     # Loss/reward curves
create_training_dashboard(metrics)                  # Full dashboard
plot_action_ratio_evolution(history)                # Policy changes over time
plot_state_action_heatmap(policy_data)              # State-action visualization
```

### Other Plots

```julia
plot_subdivision_tree(tree)                         # Adaptive refinement tree
plot_1d_polynomial_approximation(f, pol, domain)    # 1D function + polynomial
```

## Customization

### Color Schemes

All plots support custom color schemes:

```julia
fig = plot_hessian_norms(df_enhanced,
    colors=Dict(
        :minimum => :blue,
        :maximum => :red,
        :saddle => :green,
        :degenerate => :orange
    )
)
```

### Figure Properties

Adjust figure size and resolution:

```julia
fig = plot_condition_numbers(df_enhanced,
    size=(800, 600),
    fontsize=14,
    markersize=10
)
```

### Combined Visualizations

Create multi-panel figures:

```julia
fig = Figure(resolution=(1200, 800))

# Hessian norms
ax1 = Axis(fig[1, 1], title="Hessian Norms")
plot_hessian_norms!(ax1, df_enhanced)

# Condition numbers
ax2 = Axis(fig[1, 2], title="Condition Numbers")
plot_condition_numbers!(ax2, df_enhanced)

# Critical eigenvalues
ax3 = Axis(fig[2, 1:2], title="Critical Eigenvalues")
plot_critical_eigenvalues!(ax3, df_enhanced)

save("combined_analysis.png", fig)
```

## Interactive Features (GLMakie)

When using GLMakie, plots become interactive:

```julia
using GLMakie

fig = plot_all_eigenvalues(f, df_enhanced)
# - Zoom with mouse wheel
# - Pan by dragging
# - Reset with double-click
```

### Animation

Create animations showing eigenvalue evolution:

```julia
using GLMakie

# Animate eigenvalue changes
points = Observable(1:10)
fig = Figure()
ax = Axis(fig[1, 1])

on(points) do range
    # Update plot based on point range
end

# Create animation
record(fig, "eigenvalue_evolution.mp4", 1:nrow(df_enhanced)) do i
    points[] = 1:i
end
```

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

## Tips

### Large Datasets

For many critical points:

```julia
# Filter to specific types
df_minima = filter(row -> row.critical_point_type == :minimum, df_enhanced)
fig = plot_hessian_norms(df_minima)
```

### Publication Quality

```julia
# Set theme for publication
set_theme!(
    fontsize=16,
    resolution=(800, 600),
    Axis=(
        spinewidth=1.5,
        xgridwidth=0.5,
        ygridwidth=0.5
    )
)

fig = plot_condition_numbers(df_enhanced)
save("publication_figure.pdf", fig)

# Reset theme
set_theme!()
```

## Quick Reference

| Function | Purpose |
|----------|---------|
| `plot_critical_points` | Critical point scatter plot |
| `plot_hessian_norms` | Hessian norm distribution |
| `plot_condition_numbers` | Condition number plot |
| `plot_critical_eigenvalues` | Eigenvalue spectrum |
| `plot_all_eigenvalues` | Full eigenvalue visualization |
| `create_level_set_visualization` | 3D level set surface |
| `plot_convergence_analysis` | L2 error convergence |
| `create_campaign_comparison_plot` | Multi-experiment comparison |
| `create_training_dashboard` | RL training metrics |
| `plot_subdivision_tree` | Adaptive refinement tree |
