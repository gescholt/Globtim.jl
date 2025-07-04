# Convergence Analysis Plots Documentation

This document describes the plots constructed by the 4D Deuflhard degree convergence analysis suite using the enhanced data structures and unified plotting functions.

## Overview

The convergence analysis generates visualization across three main scenarios:
1. **Full Domain Analysis** (01_full_domain.jl)
2. **Subdivided Fixed Degree Analysis** (02_subdivided_fixed.jl)
3. **Subdivided Adaptive Analysis** (03_subdivided_adaptive.jl)

## Enhanced Data Structure

All plotting functions work with the `EnhancedDegreeAnalysisResult` structure that extends the basic analysis results with comprehensive metrics for visualization:

```julia
struct EnhancedDegreeAnalysisResult
    # Core fields (from original DegreeAnalysisResult)
    degree, l2_norm, n_theoretical_points, n_computed_points, 
    n_successful_recoveries, success_rate, runtime_seconds, converged,
    computed_points, min_min_success_rate, min_min_distances
    
    # Enhanced fields for plotting
    all_critical_distances      # Distances to ALL theoretical points
    min_min_found_by_bfgs      # Which min+min required BFGS refinement
    min_min_within_tolerance   # Which min+min within initial tolerance
    point_classifications      # Type of each computed point
    theoretical_points         # All theoretical critical points
    subdomain_label           # Domain identifier (e.g., "0000", "full")
    bfgs_iterations          # Number of BFGS iterations per point
    function_values          # Function values at computed points
end
```

## Plot Types and Implementation Status

### 1. L²-Norm Convergence Plots ✅ IMPLEMENTED

**Function**: `plot_l2_convergence_dual_scale()`

**Input Data**: 
- Single domain: `DataFrame` with columns `[:degree, :l2_norm, :converged]`
- Multi-domain: `Dict{String,Vector{EnhancedDegreeAnalysisResult}}`

**Output Features**:
- **Dual-scale visualization** for multi-domain cases:
  - Left axis (blue): Individual subdomain curves
  - Right axis (red): Aggregated full domain curve (RMS of subdomains)
- **Single domain**: Standard log-scale plot
- Optional tolerance line for convergence reference
- Scatter points overlaid on curves for data visibility

**Usage**:
```julia
# Single domain
fig = plot_l2_convergence_dual_scale(df, 
    title="L² Convergence", 
    tolerance_line=0.0007)

# Multi-domain with dual scales
fig = plot_l2_convergence_dual_scale(subdomain_results,
    title="Multi-Domain Convergence",
    tolerance_line=0.0007,
    save_plots=true,
    plots_directory="outputs/")
```

### 2. Min+Min Distance Plots ✅ IMPLEMENTED

**Function**: `plot_min_min_distances_dual_scale()`

**Input Data**:
- Single domain: `Vector{EnhancedDegreeAnalysisResult}`
- Multi-domain: `Dict{String,Vector{EnhancedDegreeAnalysisResult}}`

**Output Features**:
- Plot both minimal distance (solid) and average distance (dashed) to min+min points
- Log-scale y-axis for distance visualization
- Optional tolerance line showing BFGS refinement threshold
- Multi-domain: Shows individual subdomain curves
- Handles missing min+min points gracefully

**Usage**:
```julia
fig = plot_min_min_distances_dual_scale(enhanced_results,
    title="Min+Min Distance Evolution",
    tolerance_line=0.001,  # BFGS tolerance
    save_plots=true,
    plots_directory="outputs/")
```

### 3. Critical Point Recovery Histogram ✅ IMPLEMENTED

**Function**: `plot_critical_point_recovery_histogram()`

**Input Data**:
- Single domain: `Vector{EnhancedDegreeAnalysisResult}`
- Multi-domain: `Dict{String,Vector{EnhancedDegreeAnalysisResult}}`

**Output Features**:
- 3-layer stacked histogram showing:
  1. **Total theoretical points** (blue, semi-transparent) - always 81
  2. **Successfully recovered points** (green) - matched within tolerance
  3. **Min+min points captured** (gold) - subset of successful
- Reference line at 9 for expected min+min count
- Percentage annotations for each layer
- Multi-domain: Aggregates all subdomains

**Usage**:
```julia
fig = plot_critical_point_recovery_histogram(enhanced_results,
    title="Critical Point Recovery",
    save_plots=true,
    plots_directory="outputs/")
```



### 4. Min+Min Capture Method Histogram ✅ IMPLEMENTED

**Function**: `plot_min_min_capture_methods()`

**Input Data**:
- Single domain: `Vector{EnhancedDegreeAnalysisResult}`
- Multi-domain: `Dict{String,Vector{EnhancedDegreeAnalysisResult}}`

**Output Features**:
- Grouped bar chart showing for each degree:
  - **Direct tolerance capture** (green) - found without refinement
  - **BFGS refinement capture** (orange) - required BFGS to locate
  - **Not found** (red) - min+min points not recovered
- Reference line at expected min+min count (9 for single domain, 45 for multi-domain)
- Legend explaining capture methods
- Option to show percentages or raw counts via `show_percentages` parameter
- Multi-domain: Shows aggregated totals with summary annotation

**Usage**:
```julia
fig = plot_min_min_capture_methods(enhanced_results,
    title="Min+Min Capture Analysis",
    show_percentages=false,  # true for percentage view
    save_plots=true,
    plots_directory="outputs/")
```

## Unified Plotting API

All plotting functions follow a consistent interface:

```julia
function plot_*(
    results;                    # Data input (DataFrame, Vector, or Dict)
    title::String="",          # Custom title
    tolerance_line=nothing,     # Optional reference line
    save_plots::Bool=false,     # Display (false) or save (true)
    plots_directory="plots"    # Output directory if saving
)
```

### Usage Examples

```julia
# 1. L²-norm convergence
fig1 = plot_l2_convergence_dual_scale(subdomain_results, 
    title="Convergence Analysis", tolerance_line=0.0007)

# 2. Min+min distances
fig2 = plot_min_min_distances_dual_scale(subdomain_results,
    title="Min+Min Distance Evolution", tolerance_line=0.001)

# 3. Critical point recovery
fig3 = plot_critical_point_recovery_histogram(enhanced_results,
    title="Point Recovery by Degree")

# 4. Min+min capture methods
fig4 = plot_min_min_capture_methods(enhanced_results,
    title="BFGS vs Direct Capture", show_percentages=false)
```

### Output Structure
```
outputs/
├── HH-MM/                     # Timestamped folder
│   ├── full_domain_*.png      # Single domain plots
│   ├── fixed_subdivision_*.png # Fixed degree subdivision plots
│   └── adaptive_subdivision_*.png # Adaptive subdivision plots
```

## Data Processing Pipeline

### 1. Basic Analysis → Enhanced Structure
```julia
# Convert basic results to enhanced format
enhanced = convert_to_enhanced(
    basic_result,               # DegreeAnalysisResult
    theoretical_points,         # All theoretical critical points
    min_min_indices,           # Indices of min+min points
    subdomain_label,           # e.g., "0000" or "full"
    bfgs_data=bfgs_info        # Optional BFGS refinement data
)
```

### 2. Multi-Domain Aggregation
```julia
# Collect statistics across subdomains
stats = collect_subdomain_statistics(subdomain_results)
# Returns: degrees, l2_norm_mean/std/min/max, min_dist_mean/std

# Aggregate results for single analysis
agg = aggregate_enhanced_results(results_vector)
# Returns: comprehensive metrics for plotting
```

### Subdivision Data Format
```julia
# For 16 subdomains of (+,-,+,-) orthant
all_results = Dict{String, Vector{DegreeAnalysisResult}}(
    "0000" => [result_deg2, result_deg3, ...],  # Binary encoding of subdomain
    "0001" => [result_deg2, result_deg3, ...],
    ...
    "1111" => [result_deg2, result_deg3, ...]
)
```

## Plot Descriptions

Each plot automatically generates textual descriptions via `PlotDescriptions.jl`:
- **L²-norm plots**: Convergence trends, tolerance achievement, degree ranges
- **Recovery plots**: Success rate patterns, min+min vs all points comparison
- **Distance plots**: Approximation quality, distance ranges, subdomain variations

## Configuration Parameters

### Analysis Parameters
```julia
const FIXED_DEGREES = [2, 3, 4, 5, 6]        # Degrees to test
const L2_TOLERANCE_REFERENCE = 1e-2          # Reference tolerance line
const MAX_RUNTIME_PER_SUBDOMAIN = 60         # Timeout per subdomain
const DISTANCE_TOLERANCE = 0.05              # Point matching threshold
```

### Visualization Parameters
```julia
# Multi-subdomain visualization
base_colors = [:blue, :red, :green, :purple, :orange, :brown]
line_styles = [:solid, :dash, :dot, :dashdot]
# Supports up to 24 unique combinations (6 × 4)
```

## Execution Commands

### Individual Examples
```bash
julia examples/01_full_domain.jl      # Single domain analysis
julia examples/02_subdivided_fixed.jl  # Fixed degree subdivisions
julia examples/03_subdivided_adaptive.jl # Adaptive subdivisions
```

### Batch Execution
```bash
julia run_all_examples.jl  # Run all three examples with shared output folder
```

## Performance Characteristics

### Computational Complexity
- **Full domain**: O(degree^4) per degree
- **Fixed subdivisions**: O(16 × degree^4) per degree
- **Adaptive subdivisions**: O(16 × variable_degree^4) per subdomain

### Runtime Expectations
- **Degree 2-4**: Seconds per analysis
- **Degree 5-6**: Tens of seconds per analysis
- **16 subdivisions**: 16× base runtime
- **Timeouts**: 60s per subdomain, 100s per full domain

## Quality Indicators

### Expected Patterns
1. **L²-norm**: Exponential decay with increasing degree
2. **Recovery rates**: Improvement then plateau
3. **Min+min distances**: Decreasing trend on average
4. **Subdivision variation**: Different convergence rates per subdomain

### Validation Checklist
- [ ] L²-norm plots show decreasing trends
- [ ] Recovery rates improve with degree
- [ ] Distance plots show convergence
- [ ] Subdivision plots show individual trajectories
- [ ] Annotations clearly explain visualization
- [ ] Output files saved to timestamped directories

---

## Implementation Files

### Core Modules
- `shared/EnhancedAnalysisUtilities.jl` - Enhanced data structures
- `shared/EnhancedPlottingUtilities.jl` - Unified plotting functions
- `shared/AnalysisUtilities.jl` - Basic analysis functions
- `shared/PlottingUtilities.jl` - Legacy plotting functions

### Example Scripts
- `examples/01_full_domain.jl` - Single domain analysis
- `examples/02_subdivided_fixed.jl` - Fixed degree subdivisions
- `examples/03_subdivided_adaptive.jl` - Adaptive subdivisions

## Implementation Summary

All four plotting functions have been successfully implemented in the enhanced plotting utilities module:

1. **L²-Norm Convergence** (`plot_l2_convergence_dual_scale`) - Dual-scale visualization for multi-domain analysis
2. **Min+Min Distance Analysis** (`plot_min_min_distances_dual_scale`) - Tracks minimal and average distances
3. **Critical Point Recovery** (`plot_critical_point_recovery_histogram`) - 3-layer stacked visualization
4. **Min+Min Capture Methods** (`plot_min_min_capture_methods`) - BFGS vs direct tolerance distinction

All functions:
- Support both single domain and multi-domain inputs
- Follow a unified API with consistent parameters
- Can display plots in windows or save to files
- Handle edge cases and missing data gracefully
- Are integrated into all three example scripts

**Created**: 2025-07-03  
**Updated**: 2025-07-04  
**Status**: ✅ All plotting functions implemented and integrated  
**Purpose**: Comprehensive degree convergence analysis for 4D Deuflhard function  
**Dependencies**: Globtim.jl, CairoMakie.jl, ForwardDiff.jl