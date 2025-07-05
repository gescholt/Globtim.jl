# Changes and Configuration Guide for Degree Convergence Examples

## Overview
This document summarizes all changes made to the degree convergence analysis examples and provides guidance on adjustable parameters for future experiments.

## Recent Changes (2025-07-04)

### 1. **Visualization Improvements**

#### Connected Trajectories
- Fixed disconnected nodes in L2-norm plots by sorting data by degree before plotting
- Changed from `scatterlines!` to `lines!` for proper trajectory connections

#### Multi-Subdomain Visualization Strategy
- Implemented comprehensive visualization for displaying all 16 subdomain trajectories:
  - 6 base colors: blue, red, green, purple, orange, brown
  - 4 line styles: solid, dash, dot, dashdot
  - Total: 24 unique combinations for distinguishing subdomains
  - Individual trajectories: thin lines (1.0 width) with 60% transparency
  - Average trajectory: thick black line (3.0 width) on top

#### Legends and Annotations
- Added legends to recovery rate plots explaining all lines
- Updated plot annotations to describe visualization approach
- Removed titles from figures (as per requirements)

#### Adaptive Display Ranges
- Min+min distance plots now use adaptive y-axis limits:
  - `ymin = minimum * 0.5`
  - `ymax = maximum * 2.0`
- Tolerance lines only display when within visible range

### 2. **Plot Descriptions Module**
- Created `PlotDescriptions.jl` module for generating textual plot descriptions
- Descriptions output to console instead of on figures
- All examples now import and use plot descriptions

### 3. **Output Directory Structure**
- Consolidated outputs to single timestamped folders (HH-MM format)
- All three examples share the same output directory per run

## Configurable Parameters

### Global Parameters (in each example file)

```julia
# Polynomial degree settings
const MAX_DEGREE = 6        # Maximum polynomial degree to test
const STARTING_DEGREE = 2   # Starting degree for analysis

# Tolerance settings
const L2_TOLERANCE = 1e-2   # L²-norm tolerance for polynomial approximation
const DIST_TOLERANCE = 0.1  # Distance tolerance for visualization

# Domain settings
const CENTER = [0.0, 0.0, 0.0, 0.0]  # Center of approximation domain
const SAMPLE_RANGE = 0.5              # Sampling range from center

# Output settings
const SAVE_PLOTS = true     # Whether to save plots to files
const SHOW_PLOTS = false    # Whether to display plots in windows
```

### Subdivision-Specific Parameters

#### Example 02 (Fixed Degree):
```julia
# Subdivision settings
const SUBDIVISIONS_PER_DIM = 2  # Number of subdivisions per dimension (2^4 = 16 total)
const FIT_DEGREE = 4            # Fixed polynomial degree for all subdivisions
```

#### Example 03 (Adaptive):
```julia
# Adaptive settings
const SUBDIVISIONS_PER_DIM = 2  # Number of subdivisions per dimension
const ADAPTIVE_TOLERANCE = 0.05 # Tolerance for adaptive degree selection
```

### Visualization Parameters (in PlottingUtilities.jl)

```julia
# Color scheme
base_colors = [:blue, :red, :green, :purple, :orange, :brown]
line_styles = [:solid, :dash, :dot, :dashdot]

# Line properties
subdomain_linewidth = 1.0      # Width for individual trajectories
average_linewidth = 3.0        # Width for average line
subdomain_alpha = 0.6          # Transparency for individual trajectories

# Plot aesthetics
grid_visible = true
grid_alpha = 0.3
```

### Analysis Parameters (in AnalysisUtilities.jl)

```julia
# BFGS optimization settings
const BFGS_TOLERANCE = 1e-8
const MAX_ITERATIONS = 1000

# Critical point classification
const EIGENVALUE_TOLERANCE = 1e-6  # For determining definiteness
const DISTANCE_THRESHOLD = 1e-10    # For identifying duplicate points
```

## How to Adjust for Different Experiments

### 1. **Change Function or Domain**
```julia
# In example files, modify:
f = deuflhard_4d_composite  # Change to different test function
const CENTER = [0.0, 0.0, 0.0, 0.0]  # Adjust center point
const SAMPLE_RANGE = 0.5             # Adjust domain size
```

### 2. **Modify Convergence Criteria**
```julia
# For tighter approximations:
const L2_TOLERANCE = 1e-3    # Decrease for higher accuracy
const MAX_DEGREE = 8         # Increase for better approximation

# For faster computation:
const L2_TOLERANCE = 1e-1    # Increase for lower accuracy
const MAX_DEGREE = 5         # Decrease for faster analysis
```

### 3. **Adjust Subdivision Strategy**
```julia
# For finer subdivision:
const SUBDIVISIONS_PER_DIM = 3  # Creates 3^4 = 81 subdomains

# For coarser subdivision:
const SUBDIVISIONS_PER_DIM = 1  # Creates 1^4 = 1 subdomain (effectively none)
```

### 4. **Customize Visualization**
```julia
# In PlottingUtilities.jl, modify color schemes:
base_colors = [:viridis, :plasma, :inferno, :magma, :cividis, :twilight]

# Change line styles:
line_styles = [:solid, :dash]  # Fewer styles for cleaner look

# Adjust transparency:
subdomain_alpha = 0.8  # Less transparent for darker lines
```

### 5. **Output Customization**
```julia
# Change output format:
const OUTPUT_FORMAT = "pdf"  # Instead of "png"

# Disable plot saving:
const SAVE_PLOTS = false

# Enable interactive display:
const SHOW_PLOTS = true
```

## Running the Examples

### Individual Examples
```bash
julia Examples/ForwardDiff_Certification/by_degree/examples/01_full_domain.jl
julia Examples/ForwardDiff_Certification/by_degree/examples/02_subdivided_fixed.jl
julia Examples/ForwardDiff_Certification/by_degree/examples/03_subdivided_adaptive.jl
```

### All Examples
```bash
julia Examples/ForwardDiff_Certification/by_degree/run_all_examples.jl
```

### Testing Visualizations
```bash
julia Examples/ForwardDiff_Certification/by_degree/test_improved_visualizations.jl
```

## Key Implementation Details

### Data Flow
1. **Analysis**: Each example generates `DegreeAnalysisResult` objects
2. **Plotting**: Results passed to plotting functions in `PlottingUtilities.jl`
3. **Description**: Text descriptions generated by `PlotDescriptions.jl`
4. **Output**: Plots saved to timestamped directory, descriptions to console

### Critical Functions
- `analyze_by_degree()`: Main analysis loop in each example
- `plot_subdivision_*()`: Visualization functions for multi-subdomain data
- `describe_*()`: Text description generators for each plot type

## Future Enhancements

1. **Performance Optimization**
   - Parallel processing for subdomain analysis
   - Caching of polynomial evaluations

2. **Additional Visualizations**
   - 3D projections of 4D critical points
   - Animation of convergence progression
   - Heatmaps of approximation quality

3. **Extended Analysis**
   - Condition number tracking
   - Basis function comparison (Chebyshev vs Legendre)
   - Sensitivity analysis of parameters

## Troubleshooting

### Common Issues
1. **Memory Usage**: Reduce `MAX_DEGREE` or `SUBDIVISIONS_PER_DIM`
2. **Plot Clarity**: Adjust `subdomain_alpha` or reduce number of subdomains shown
3. **Convergence**: Check `L2_TOLERANCE` is achievable for given `MAX_DEGREE`

### Debug Mode
Add verbose output by modifying:
```julia
const VERBOSE = true  # Add to example files
# Then add conditional prints throughout analysis
```