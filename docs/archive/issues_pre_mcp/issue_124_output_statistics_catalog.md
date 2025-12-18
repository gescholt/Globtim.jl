# Issue #124: Output Statistics Catalog

**Date:** 2025-10-03
**Related Files:**
- Test specification: [test_experiment_metadata_tracking.jl](../../test/test_experiment_metadata_tracking.jl)
- Configuration: [parameter_tracking_config.jl](../../src/parameter_tracking_config.jl)

## Overview

This document catalogs recommended output statistics for metadata-driven experiment tracking. The plotting infrastructure should automatically generate these statistics based on experiment `enabled_tracking` labels.

## Design Principle

> **Tracking parameters affect experiment execution to enable data collection.**
> **Visualization parameters are post-processing concerns and discover experiments via labels.**

## Tracking Labels and Output Statistics

### 1. Polynomial Approximation Quality
**Label:** `"polynomial_quality"`

**Statistics:**
- L2-norm of approximation error vs degree
- Condition number of Vandermonde matrix vs degree
- Coefficient sparsity (% nonzero) vs degree
- Maximum coefficient magnitude vs degree
- Relative coefficient decay rate
- Grid point count vs polynomial dimension

**Visualizations:**
- L2 error convergence plot (log scale)
- Condition number heatmap (degree × dimension)
- Sparsity pattern visualization
- Coefficient magnitude distribution

---

### 2. Convergence Tracking
**Label:** `"convergence_tracking"`

**Statistics:**
- Gradient norm reduction per iteration
- Function value improvement per iteration
- Average convergence rate (linear/quadratic indicator)
- Number of iterations to threshold tolerance
- Success rate across all critical points
- Final gradient norm statistics (min/max/mean/median)

**Visualizations:**
- Gradient norm vs iteration (log scale)
- Function value vs iteration
- Convergence rate classification histogram
- Success rate by point type (min/max/saddle)

---

### 3. Hessian Eigenvalue Analysis
**Label:** `"hessian_eigenvalues"`

**Statistics:**
- Eigenvalue spectrum statistics (min/max/condition)
- Hessian definiteness classification (pos-def/neg-def/indefinite)
- Number of positive/negative/zero eigenvalues
- Spectral gap (difference between largest eigenvalues)
- Eigenvalue concentration (ratio of largest to smallest)
- Frequency of each point type (min/max/saddle)

**Visualizations:**
- Eigenvalue spectrum plot (sorted)
- Hessian definiteness pie chart
- Eigenvalue distribution histogram
- Min index vs eigenvalue magnitude scatter

---

### 4. Distance to Known Solutions
**Label:** `"distance_to_solutions"`

**Statistics:**
- Euclidean distance to global minimum
- Distance reduction per refinement iteration
- Convergence basin identification (clustering)
- Percentage of points within ε-ball of solutions
- Mean/median distance statistics by point type
- Distance vs gradient norm correlation

**Visualizations:**
- Distance vs iteration trajectory
- Convergence basin clustering (2D projection)
- Distance distribution histogram
- Distance vs gradient norm scatter

---

### 5. Gradient Norm Tracking
**Label:** `"gradient_norms"`

**Statistics:**
- Initial vs final gradient norm statistics
- Gradient norm reduction factor (geometric mean)
- Percentage achieving numerical zero gradient
- Gradient norm vs function value correlation
- Component-wise gradient statistics (max component)
- Tolerance achievement rate

**Visualizations:**
- Gradient norm convergence curves
- Initial vs final gradient scatter
- Gradient norm distribution (before/after refinement)
- Per-dimension gradient contribution

---

### 6. Sparsification Metrics
**Label:** `"sparsification_tracking"`

**Statistics:**
- Sparsity percentage vs threshold
- L2 error increase due to sparsification
- Compression ratio achieved
- Memory savings estimate
- Retained coefficient locations (pattern analysis)
- Sparsification efficiency (error/sparsity tradeoff)

**Visualizations:**
- Sparsity vs L2 error Pareto front
- Coefficient retention heatmap (multi-index)
- Compression ratio vs threshold
- Sparsity pattern visualization (2D/3D slices)

---

### 7. Performance Profiling
**Label:** `"performance_metrics"`

**Statistics:**
- Total computation time breakdown (construction/solve/refinement)
- Time per degree scaling analysis
- Memory usage peak and average
- Matrix construction time vs polynomial size
- Solver time vs problem dimension
- Refinement time per critical point

**Visualizations:**
- Time breakdown stacked bar chart
- Time vs degree scaling plot (log-log)
- Memory usage timeline
- Performance comparison across functions

---

### 8. Critical Point Distribution
**Label:** `"critical_point_statistics"`

**Statistics:**
- Count by type (minima/maxima/saddle points)
- Spatial distribution statistics (clustering, dispersion)
- Function value range at critical points
- Average distance between critical points
- Density in parameter space regions
- Symmetry detection in critical point locations

**Visualizations:**
- Critical point scatter plot (2D/3D projections)
- Type distribution pie chart
- Function value at critical points histogram
- Spatial density heatmap

---

### 9. Multi-Dimensional Analysis
**Label:** `"dimensional_scaling"`

**Statistics:**
- Polynomial size vs dimension (theoretical vs actual)
- Critical point count vs dimension
- Computation time vs dimension scaling
- Success rate vs dimension
- Effective dimension reduction (active subspace)
- Coordinate importance ranking

**Visualizations:**
- Scaling plots (dimension × metric)
- Active subspace visualization
- Coordinate sensitivity analysis
- Dimension vs performance matrix

---

### 10. Tolerance Sensitivity Analysis
**Label:** `"tolerance_sensitivity"`

**Statistics:**
- Number of critical points vs gradient tolerance
- Function value agreement vs matching tolerance
- Refinement success rate vs tolerance
- Numerical stability indicators
- Condition number sensitivity
- Recommended tolerance ranges

**Visualizations:**
- Critical point count vs tolerance
- Tolerance sweep convergence curves
- Stability region identification
- Recommended tolerance bands

---

### 11. Error and Residual Tracking
**Label:** `"error_tracking"`

**Statistics:**
- Polynomial residual at sample points
- Function value error (polynomial vs true)
- Gradient approximation error
- Hessian approximation error (if true Hessian known)
- Error distribution statistics
- Convergence order estimation

**Visualizations:**
- Error vs degree convergence plot
- Residual heatmap in parameter space
- Error distribution histogram
- Convergence order estimation plot

---

### 12. Experiment Comparison Metadata
**Label:** `"experiment_comparison"`

**Statistics:**
- Success rate comparison across experiments
- Relative performance rankings
- Parameter sensitivity identification
- Configuration impact analysis
- Best configuration recommendations
- Statistical significance of differences

**Visualizations:**
- Comparison bar charts (side-by-side)
- Parameter sensitivity tornado plots
- Configuration performance heatmap
- Statistical confidence intervals

---

## Implementation Guidelines

For each tracking label, the plotting infrastructure should:

1. **Auto-detect available statistics** based on `enabled_tracking` labels
2. **Generate appropriate visualizations** matching the data type
3. **Compute summary tables** with key metrics
4. **Export statistics** in machine-readable format (JSON/CSV)
5. **Create comparative views** when multiple experiments share labels
6. **Generate text summaries** for quick interpretation
7. **Validate data quality** before computing statistics
8. **Handle missing data gracefully** with clear warnings

## Integration Points

### In `AnalysisParams` (parameter_tracking_config.jl)
Add tracking activation flags:
```julia
struct AnalysisParams
    enable_hessian::Bool
    tol_dist::Float64
    sparsification::Union{SparsificationParams, Nothing}

    # NEW: Tracking activation flags
    track_convergence::Bool
    track_gradient_norms::Bool
    track_distance_to_solutions::Bool
    track_sparsification_metrics::Bool
    track_performance_metrics::Bool
    track_error_tracking::Bool
end
```

### In Experiment Results
Add metadata fields:
```julia
result = Dict(
    "experiment_id" => "...",
    "enabled_tracking" => ["gradient_norms", "hessian_eigenvalues"],
    "tracking_capabilities" => ["gradient_norms", "hessian_eigenvalues", "convergence_tracking"],
    "data" => Dict(
        "gradient_norms" => [...],
        "hessian_eigenvalues" => [...]
    )
)
```

### In PostProcessing Module
Implement label-to-statistics mapping:
```julia
function compute_statistics_for_label(label::String, data::Dict)
    if label == "gradient_norms"
        return compute_gradient_statistics(data)
    elseif label == "hessian_eigenvalues"
        return compute_hessian_statistics(data)
    # ... etc
    end
end
```

## Example Workflow

```julia
# 1. Configure experiment with tracking
config = ExperimentConfig(
    analysis_params = AnalysisParams(
        enable_hessian = true,
        track_gradient_norms = true,
        track_convergence = true
    )
)

# 2. Run experiment (stores tracked data)
result = run_globtim_experiment(config)

# 3. Post-process: discover what's available
available_stats = discover_available_statistics(result)
# => ["gradient_norms", "convergence_tracking", "hessian_eigenvalues"]

# 4. Generate visualizations based on labels
plots = generate_plots_from_labels(result, available_stats)
# => gradient_convergence.png, hessian_spectrum.png, etc.
```

## Next Steps

1. Remove `save_plots` from `OutputSettings`
2. Add tracking flags to `AnalysisParams`
3. Implement `enabled_tracking` metadata in experiment results
4. Create label-to-statistics mapping in PostProcessing
5. Update plotting infrastructure to read labels
6. Add tests validating the complete workflow

---

**See also:**
- [Test Specification](../../test/test_experiment_metadata_tracking.jl) - Defines desired final states
- [PostProcessing Module](../../src/PostProcessing.jl) - Statistics computation
- [Visualization Framework](../../src/VisualizationFramework.jl) - Plotting infrastructure
