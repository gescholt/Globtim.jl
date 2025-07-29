# Globtim Plotting Functions Backend Requirements

## Overview
Globtim plotting functions are divided into two categories based on their backend requirements:
- **CairoMakie**: Static 2D plots, suitable for publication-quality figures and PDF export
- **GLMakie**: Interactive 3D plots, animations, and plots requiring GPU acceleration

## CairoMakie Functions
These functions require `CairoMakie.activate!()`:

### Core 2D Plotting Functions
- `cairo_plot_polyapprox_levelset()` - 2D contour plots with critical points
- `plot_discrete_l2()` - L2 norm plots
- `plot_convergence_analysis()` - Convergence analysis plots
- `capture_histogram()` - Histogram of captured vs uncaptured points
- `plot_convergence_captured()` - Convergence to captured points
- `plot_filtered_y_distances()` - Distance analysis plots
- `plot_distance_statistics()` - Statistical distance plots
- `create_legend_figure()` - Standalone legend figures
- `histogram_enhanced()` - Enhanced histogram with theoretical minimizers
- `histogram_minimizers_only()` - Histogram showing only minimizers

### Hessian Analysis Functions (work with both backends)
- `plot_hessian_norms()` - L2 norms of Hessian matrices
- `plot_condition_numbers()` - Condition numbers of Hessian matrices
- `plot_critical_eigenvalues()` - Critical eigenvalues visualization
- `plot_all_eigenvalues()` - Complete eigenvalue spectrum
- `plot_raw_vs_refined_eigenvalues()` - Comparison of eigenvalues

## GLMakie Functions
These functions require `GLMakie.activate!()`:

### 3D Visualization Functions
- `plot_polyapprox_3d()` - 3D surface plots with critical points
- `plot_polyapprox_rotate()` - 3D plot with rotation animation
- `plot_polyapprox_animate()` - Animated 3D visualization
- `plot_polyapprox_animate2()` - Alternative animation style
- `plot_polyapprox_flyover()` - Flyover animation

### Level Set Functions (in LevelSetViz.jl)
- `plot_level_set()` - Interactive level set visualization
- `plot_polyapprox_levelset()` - Basic level set plot (different from cairo version!)
- `plot_polyapprox_levelset_2D()` - 2D level set visualization

### Error Analysis Functions
- `plot_error_function_1D_with_critical_points()` - 1D error function plots
- `plot_error_function_2D_with_critical_points()` - 2D error function with gradient arrows

## Important Notes
1. **Never mix backends**: Always use the appropriate `activate!()` call before plotting
2. **Function name confusion**: 
   - `cairo_plot_polyapprox_levelset()` (CairoMakie) vs `plot_polyapprox_levelset()` (GLMakie)
   - These are different functions with different signatures!
3. **Saving figures**: 
   - CairoMakie: Best for PDF, PNG export with `save()`
   - GLMakie: Better for interactive viewing, can save screenshots

## Usage Pattern
```julia
# For static 2D plots
using CairoMakie
CairoMakie.activate!()
fig = cairo_plot_polyapprox_levelset(...)
# save("output.pdf", fig)

# For 3D/interactive plots
using GLMakie
GLMakie.activate!()
fig = plot_polyapprox_3d(...)
# save("output.png", fig)
```