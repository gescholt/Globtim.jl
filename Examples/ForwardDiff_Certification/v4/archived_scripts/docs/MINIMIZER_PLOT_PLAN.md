# Plan: Minimizer-Focused Distance Evolution Plot

## Objective
Create a new plot variant of `v4_critical_point_distance_evolution` that focuses exclusively on the 9 minimizers, with individual curve labeling to distinguish between similar-looking convergence patterns.

## Key Requirements
1. **Filter to show only minimizers** (9 out of 25 critical points)
2. **Add curve labels 1-9** directly on the plot
3. **Improve visual clarity** to distinguish between curves that look very similar

## Implementation Plan

### 1. Create New Function: `plot_minimizer_distance_evolution`

Location: Add to `V4PlottingEnhanced.jl`

```julia
function plot_minimizer_distance_evolution(subdomain_tables::Dict{String, DataFrame},
                                         degrees::Vector{Int};
                                         output_dir::Union{String, Nothing} = nothing)
```

### 2. Key Implementation Details

#### A. Data Processing
- Filter subdomain tables to include only rows where `type == "min"`
- Sort minimizers by their average distance (or initial distance) for consistent numbering
- Assign labels 1-9 to each minimizer

#### B. Visual Enhancements
- **Larger figure size**: `(1200, 800)` for better visibility
- **Color palette**: Use 9 distinct colors from a perceptually uniform colormap
- **Line styles**: Vary both color and line style (solid, dashed, dotted) if needed
- **Direct labeling**: Add text labels at the end of each curve

#### C. Plot Features
- Keep log scale on y-axis for distance
- Add grid for better readability
- Thicker lines (linewidth=3) for better visibility
- Markers at data points to show actual computed values

### 3. Labeling Strategy

Two options for labeling:

**Option A: End-of-line labels**
```julia
# Add label at the last point of each curve
text!(ax, last_degree + 0.1, last_distance, 
      text = string(i),
      fontsize = 14,
      color = curve_color)
```

**Option B: Smart label placement**
- Find the position where curves are most separated
- Place labels to minimize overlap
- Use `Makie.Label` with background for readability

### 4. Color Scheme

Use a categorical color palette with high contrast:
```julia
minimizer_colors = [
    :blue, :red, :green, :orange, :purple,
    :brown, :pink, :olive, :cyan
]
```

Or use a perceptually uniform colormap:
```julia
colors = distinguishable_colors(9, [RGB(1,1,1), RGB(0,0,0)], dropseed=true)
```

### 5. Additional Features

#### A. Minimizer Information Table
Create a small table showing:
- Label (1-9)
- Subdomain location
- Final distance achieved
- Convergence rate

#### B. Interactive Elements (Optional)
- Hover to highlight specific curve
- Click to show minimizer coordinates

### 6. Integration with Existing Code

The function will:
1. Reuse the same data structure as `plot_critical_point_distance_evolution`
2. Be called from `run_v4_enhanced` after the standard plots
3. Save output as `v4_minimizer_distance_evolution.png`

### 7. Example Usage

```julia
# In run_v4_enhanced function
plot_minimizer_distance_evolution(
    subdomain_tables_v4,
    degrees,
    output_dir = output_dir
)
```

## Implementation Steps

1. **Copy and modify** the existing `plot_critical_point_distance_evolution` function
2. **Add filtering logic** to extract only minimizers
3. **Implement labeling system** with consistent minimizer numbering
4. **Test with small degree set** (e.g., [3,4,5]) to verify labeling
5. **Fine-tune visual parameters** based on output

## Expected Benefits

1. **Clearer visualization** of individual minimizer convergence
2. **Easy identification** of which minimizers converge fastest/slowest
3. **Better understanding** of convergence patterns across subdomains
4. **Publication-ready** focused plot for analysis

## Potential Challenges

1. **Label overlap**: May need smart placement algorithm
2. **Color distinction**: 9 colors need to be clearly distinguishable
3. **Curve overlap**: Some minimizers may have very similar convergence
   - Solution: Add slight vertical offset or use transparency

## Next Steps

After implementing the basic version:
1. Add minimizer coordinate display (as subplot or table)
2. Create companion plot showing convergence rates
3. Add export functionality for minimizer tracking data