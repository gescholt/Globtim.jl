# Visualization

Globtim provides comprehensive visualization capabilities through extension packages. These functions become available when you load CairoMakie or GLMakie.

## Setup

```julia
using Globtim
using CairoMakie  # or GLMakie for interactive plots

# Run your analysis first
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
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

## Eigenvalue Spectrum Plots

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

## Customization Options

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

### Saving Plots

Export in various formats:

```julia
# High-resolution PNG
save("plot.png", fig, px_per_unit=2)

# Vector format
save("plot.pdf", fig)
save("plot.svg", fig)
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

## Combined Visualizations

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

## Plotting Tips

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

### Animation (GLMakie)

Create animations showing eigenvalue evolution:

```julia
using GLMakie

# Animate eigenvalue changes
points = Observable(1:10)
fig = Figure()
ax = Axis(fig[1, 1])

on(points) do range
    # Update plot based on point range
    # ... plotting code ...
end

# Create animation
record(fig, "eigenvalue_evolution.mp4", 1:nrow(df_enhanced)) do i
    points[] = 1:i
end
```