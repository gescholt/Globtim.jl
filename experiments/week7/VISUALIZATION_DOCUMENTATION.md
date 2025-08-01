# Valley Walking Visualization Documentation

## Overview

The simplified valley walking visualization module provides clean, publication-ready plots for analyzing optimization trajectories. The main function `plot_valley_walk_simple` creates a 2-panel figure showing:

1. **Left panel**: 2D level sets of the objective function with the valley walking path
2. **Right panel**: Function values along the path showing optimization progress

## Main Visualization Function

### `plot_valley_walk_simple`

Creates a comprehensive 2-panel visualization of valley walking results.

```julia
fig = plot_valley_walk_simple(
    valley_results,      # Array of valley walking results
    objective_func,      # The objective function being minimized
    domain_bounds,       # Tuple (x_min, x_max, y_min, y_max)
    fig_size = (1200, 500),
    show_true_minimum = [1.0, 1.0],
    path_index = 1,
    colormap = :viridis,
    use_log_scale = true
)
```

#### Parameters

- **`valley_results`**: Array of valley walking results. Each result must contain:
  - `points`: Array of 2D points `[x₁, x₂]` along the path
  - `f_values`: Function values at each point
  - `start_point`: Starting point of the walk (optional)

- **`objective_func`**: Function `f(x)` where `x` is a 2D vector `[x₁, x₂]`

- **`domain_bounds`**: Tuple `(x_min, x_max, y_min, y_max)` defining the plotting region

#### Keyword Arguments

- **`fig_size`**: Figure dimensions in pixels `(width, height)`. Default: `(1200, 500)`
- **`show_true_minimum`**: Optional `[x, y]` coordinates of the true minimum to display as a gold star
- **`path_index`**: Which path to plot if multiple paths exist. Default: `1`
- **`colormap`**: Color scheme for level sets. Options: `:viridis`, `:plasma`, `:inferno`, etc.
- **`use_log_scale`**: Use logarithmic scale for function values. Default: `true`

#### Returns

A GLMakie `Figure` object that can be displayed or saved.

## Component Functions

### `plot_level_sets_with_path!`

Plots the 2D level sets with the optimization path on an existing axis.

```julia
plot_level_sets_with_path!(
    ax,                  # GLMakie Axis
    valley_result,       # Single valley walking result
    objective_func,      # Objective function
    domain_bounds,       # Domain bounds
    show_true_minimum = [1.0, 1.0],
    colormap = :viridis,
    use_log_scale = true,
    n_grid_points = 200,
    n_contours = 20,
    path_color = :red,
    path_linewidth = 4
)
```

#### Features
- Heatmap showing function values (optionally in log scale)
- White contour lines for better visibility
- Path shown as thick colored line
- Start point marked with circle
- End point marked with star
- Directional arrows along the path
- Optional true minimum shown as gold star

### `plot_function_values_along_path!`

Plots the function values along the optimization path.

```julia
plot_function_values_along_path!(
    ax,                  # GLMakie Axis
    valley_result,       # Valley walking result
    line_color = :blue,
    marker_color = :blue,
    linewidth = 3,
    markersize = 8,
    show_markers = true
)
```

#### Features
- Line plot of function values vs step number
- Optional markers at each evaluation point
- Annotations showing initial and final function values
- Machine precision line for log-scale plots
- Grid lines for better readability

### `plot_critical_points!`

Adds critical points from polynomial approximation to a 2D plot.

```julia
plot_critical_points!(
    ax,                  # GLMakie Axis
    df_critical_points,  # DataFrame with x1, x2 columns
    color = :red,
    markersize = 18,
    marker = :diamond,
    label = "Critical Points"
)
```

## Usage Examples

### Basic Usage

```julia
# Single valley walk
result = enhanced_valley_walk(rosenbrock_2d, [0.0, 0.0])

# Create visualization
fig = plot_valley_walk_simple(
    [result],
    rosenbrock_2d,
    (-2, 2, -1, 3),
    show_true_minimum = [1.0, 1.0]
)

# Display
display(fig)

# Save
GLMakie.save("valley_walk.png", fig, px_per_unit=2)
```

### Multiple Paths Comparison

```julia
# Run valley walks from different starting points
results = []
for x0 in starting_points
    result = enhanced_valley_walk(objective_func, x0)
    push!(results, result)
end

# Plot the best path
best_idx = argmin([r.f_values[end] for r in results])
fig = plot_valley_walk_simple(
    results,
    objective_func,
    domain_bounds,
    path_index = best_idx
)
```

### Custom Styling

```julia
# Create figure with custom settings
fig = plot_valley_walk_simple(
    valley_results,
    objective_func,
    domain_bounds,
    fig_size = (1600, 600),
    colormap = :plasma,
    use_log_scale = false  # Linear scale
)

# Access individual axes for further customization
ax_level = fig.content[1]    # Level set plot
ax_values = fig.content[3]   # Function values plot

# Add custom annotations
text!(ax_level, 0, 0, text="Custom Label", fontsize=16)
```

## Output Interpretation

### Level Set Plot (Left Panel)
- **Heatmap colors**: Function values (darker = lower values)
- **White contours**: Level curves of equal function value
- **Red path**: Valley walking trajectory
- **Circle marker**: Starting point
- **Star marker**: Ending point
- **Arrows**: Direction of movement
- **Gold star**: True minimum (if provided)

### Function Values Plot (Right Panel)
- **X-axis**: Step number in the optimization
- **Y-axis**: Function value f(x) (log or linear scale)
- **Blue line**: Function values along the path
- **Markers**: Individual evaluation points
- **Annotations**: Initial (f₀) and final (f_end) values
- **Dashed line**: Machine precision limit (for log scale)

## Best Practices

1. **Domain Selection**: Choose domain bounds that include both the starting point and expected minimum
2. **Log Scale**: Use log scale when function values span multiple orders of magnitude
3. **Grid Resolution**: Default 200x200 grid is suitable for most functions; increase for highly detailed landscapes
4. **Path Selection**: When multiple paths exist, plot the one reaching the lowest value
5. **File Saving**: Use `px_per_unit=2` for high-resolution output suitable for publications

## Troubleshooting

- **Empty plot**: Check that valley_results contains valid data
- **Path not visible**: Ensure path coordinates are within domain_bounds
- **Slow rendering**: Reduce n_grid_points for faster plotting
- **Log scale issues**: Function values must be positive; small negative values are clipped to 1e-16