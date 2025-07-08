# Degree Convergence Analysis Examples

## Overview

This directory contains the enhanced implementation for analyzing polynomial degree convergence and local minimizer recovery for the 4D Deuflhard function.

## Current Implementation

### `degree_convergence_analysis_enhanced_v2.jl`

The latest implementation with significant improvements:

1. **Focus on true minimizers** - Tracks 9 local minimizers from CSV file instead of theoretical tensor products
2. **Enhanced statistics** - Quartile-based distance metrics for robust analysis
3. **Global comparison** - Side-by-side analysis of subdivided vs global approximation
4. **Improved visualizations** - Shaded quartile bands and cleaner plots
5. **Better recovery metrics** - Per-subdomain accuracy tracking

## Usage

### From run_all_examples.jl:
```julia
const DEGREES = [2, 3, 4, 5, 6]
const GN = 16

include("examples/degree_convergence_analysis_enhanced_v2.jl")
summary_df, distance_data = run_enhanced_analysis_v2(DEGREES, GN, analyze_global=true)
```

### Direct execution:
```julia
julia degree_convergence_analysis_enhanced_v2.jl
```

### Custom parameters:
```julia
summary_df, distance_data = run_enhanced_analysis_v2(
    [2, 3, 4, 5, 6, 7, 8],  # degrees to test
    16,                     # grid points per dimension
    output_dir = "custom_output",
    threshold = 0.2,        # recovery distance threshold
    analyze_global = true   # include global comparison
)
```

## Key Functions

- `load_true_minimizers()` - Loads the 9 true minimizers from CSV file
- `compute_enhanced_distance_stats()` - Calculates quartile-based distance statistics
- `compute_minimizer_recovery()` - Tracks recovery with per-subdomain accuracy
- `analyze_global_domain()` - Runs global approximation for comparison
- `run_enhanced_analysis_v2()` - Main analysis function
- `create_enhanced_plots_v2()` - Generates enhanced visualizations

## Output

Results are saved to `outputs/enhanced_v2_HH-MM/`:
- `enhanced_distance_convergence.png` - Distance plot with quartile bands and global comparison
- `enhanced_l2_convergence.png` - L²-norm convergence with individual subdomain traces
- `recovery_overview.png` - Clean recovery rate visualization
- `summary.csv` - Comprehensive statistics by polynomial degree
- `recovery_degree_N.csv` - Per-subdomain recovery details for each degree

## Legacy Files

Previous implementations have been archived. See `CLEANUP_PLAN_2025.md` for details.