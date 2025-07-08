# Minimizer-Focused Distance Evolution Plot

## Overview

The new `plot_minimizer_distance_evolution` function creates a focused visualization showing only the 9 theoretical minimizers of the 4D Deuflhard function, addressing the issue where some convergence curves were too close together to distinguish in the full 25-point plot.

## Features

### 1. Main Plot (`v4_minimizer_distance_evolution.png`)
- **Size**: 1200x800 pixels for better visibility
- **Content**: Distance evolution curves for only the 9 minimizers
- **Labeling**: Each curve is labeled 1-9 directly on the plot
- **Colors**: 9 distinct colors (blue, red, green, orange, purple, brown, pink, olive, cyan)
- **Markers**: Data points are marked with scatter points for clarity
- **Grid**: Dashed grid lines for better readability
- **Threshold**: Recovery threshold line at 0.1

### 2. Information Table (`v4_minimizer_info_table.png`)
- **Size**: 600x400 pixels
- **Content**: Tabular display showing:
  - Label (1-9, color-coded to match the plot)
  - Subdomain location
  - Theoretical point ID
  - Final distance achieved

## Implementation Details

### Minimizer Numbering
The minimizers are numbered 1-9 based on their final distance (smallest to largest), ensuring consistent ordering across different runs.

### Visual Design
- **Line width**: 3 pixels for better visibility
- **Marker size**: 10 pixels
- **Label font**: Bold, size 16
- **Label placement**: To the right of the last data point

### Data Processing
1. Filters subdomain tables to extract only `type == "min"` rows
2. Excludes "AVERAGE" rows
3. Collects distance data for each degree
4. Sorts by final distance for consistent numbering

## Usage

The plot is automatically generated when running `run_v4_enhanced()`:

```julia
results = run_v4_enhanced(degrees=[3,4,5,6], GN=30)
```

## Benefits

1. **Clarity**: Individual minimizer convergence patterns are now clearly visible
2. **Identification**: Easy to track specific minimizers across degrees
3. **Analysis**: Can identify which minimizers converge fastest/slowest
4. **Publication-ready**: Clean, focused visualization suitable for papers

## Example Output Structure

```
outputs/enhanced_HH-MM/
├── v4_critical_point_distance_evolution.png  # Original 25-point plot
├── v4_minimizer_distance_evolution.png       # NEW: 9 minimizer plot
├── v4_minimizer_info_table.png              # NEW: Minimizer information
└── ... (other plots)
```

## Future Enhancements

1. **Interactive tooltips**: Show coordinates on hover (if using GLMakie)
2. **Convergence rate annotation**: Add slope information
3. **Subdomain grouping**: Option to color by subdomain instead of individual minimizer