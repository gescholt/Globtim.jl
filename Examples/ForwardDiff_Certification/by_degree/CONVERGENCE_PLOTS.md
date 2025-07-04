# L²-Norm Convergence Analysis Plots

This document describes the construction and usage of L²-norm convergence plots in the 4D Deuflhard degree analysis suite.

## Overview

The convergence analysis generates two primary visualization types:
1. **L²-Norm Convergence Plot**: Shows polynomial approximation quality vs degree
2. **Recovery Rates Plot**: Shows critical point capture success vs degree

## Plot Construction

### 1. L²-Norm Convergence Plot

**Function**: `plot_l2_convergence(degree_results)`

**Visual Specifications**:
- **Style**: Purple scatterlines (signature Globtim style matching DeJong notebooks)
- **Markers**: 8px circles with 2px connecting lines
- **Axes**: 
  - X-axis: "Polynomial Degree" (linear scale)
  - Y-axis: "L²-Norm" (log₁₀ scale)
- **Reference Line**: Red dashed horizontal line at `L2_TOLERANCE_TIGHT`
- **Grid**: Enabled for both X and Y axes
- **Figure Size**: 800×600 pixels

**Data Source**: 
- X-values: Polynomial degrees from `DEGREE_MIN` to `DEGREE_MAX`
- Y-values: `pol.nrm` values extracted from Constructor output

**Interpretation**:
- **Decreasing trend**: Indicates convergence as degree increases
- **Below red line**: L²-norm tolerance achieved
- **Plateau**: Further degree increases yield diminishing returns

### 2. Recovery Rates Plot

**Function**: `plot_recovery_rates(degree_results)`

**Visual Specifications**:
- **Blue line**: All critical points success rate (%)
- **Red line**: Min+min points only success rate (%)
- **Reference line**: Gray dashed line at 90% success threshold
- **Markers**: 8px circles with 2px connecting lines
- **Figure Size**: 800×600 pixels

**Data Source**:
- Success rates computed from distance-based matching against theoretical points
- Distance threshold: `DISTANCE_TOLERANCE = 0.05`

**Interpretation**:
- **Blue line trend**: Overall critical point recovery performance
- **Red line trend**: Performance for global minima (min+min tensor products)
- **Above gray line**: Achieving 90% success rate benchmark

## Usage Patterns

### Running the Analysis
```julia
# Execute the full analysis
include("deuflhard_4d_full_domain.jl")
```

### Plot Display
- Plots display in separate windows (no file saving by default)
- Interactive zoom and pan available in plot windows
- Close windows manually when analysis is complete

### Customization Options

**Degree Range**:
```julia
const DEGREE_MIN = 2
const DEGREE_MAX = 10    # Adjust as needed
```

**Tolerance Settings**:
```julia
const L2_TOLERANCE_TIGHT = 5e-3     # L²-norm convergence target
const DISTANCE_TOLERANCE = 0.05    # Critical point matching threshold
```

**Computational Parameters**:
```julia
const MAX_RUNTIME_PER_DEGREE = 100  # Timeout per degree (seconds)
GN = 20                             # Sample count parameter
```

## Integration with Globtim Ecosystem

### Color Scheme Consistency
- **Purple**: Standard L²-norm convergence plots (matches DeJong notebooks)
- **Blue/Red**: Success rate differentiation (all points vs min+min)
- **Gray**: Reference thresholds and guidelines

### Data Flow Integration
```julia
TR = test_input() → Constructor() → pol.nrm → L²-norm plot
solutions → process_crit_pts() → distance analysis → recovery plot
```

### Performance Characteristics
- **Degree 2-6**: Fast execution (seconds per degree)
- **Degree 7-10**: Moderate execution (tens of seconds per degree)
- **Degree 10+**: Extended execution (consider timeout settings)

## Quality Assurance

### Expected Convergence Patterns
1. **L²-norm**: Exponential decay with increasing degree
2. **Recovery rates**: Improvement then plateau around degrees 6-8
3. **Min+min performance**: Often better than overall rates

### Troubleshooting
- **Flat L²-norm**: Check `GN` sample count, may need increase
- **Poor recovery**: Verify `DISTANCE_TOLERANCE` appropriateness
- **Timeouts**: Increase `MAX_RUNTIME_PER_DEGREE` for higher degrees

### Validation Checklist
- [ ] L²-norm shows decreasing trend
- [ ] Recovery rates improve with degree
- [ ] No excessive timeouts or failures
- [ ] Plots display correctly in windows

## Technical Notes

### Polynomial Construction
- **Basis**: Chebyshev polynomials (optimal for [-1,1]⁴ domain)
- **Precision**: Standard floating-point precision
- **Domain**: Full [-1,1]⁴ hypercube (no subdivision)

### Critical Point Analysis
- **Solver**: Polynomial system solver via `solve_polynomial_system()`
- **Theoretical Points**: Tensor products of 2D Deuflhard critical points
- **Classification**: Hessian eigenvalue analysis (min, max, saddle types)

### Statistical Measures
- **Success Rate**: Fraction of theoretical points recovered within tolerance
- **Min+Min Rate**: Success rate for global minima specifically
- **Median Distance**: Robust measure of approximation quality

## Future Extensions

This framework supports:
- Multi-basis comparisons (Chebyshev vs Legendre)
- Different tolerance sweeps
- Alternative distance metrics
- Extended degree ranges
- Computational scaling analysis

---

**File**: `deuflhard_4d_full_domain.jl`  
**Created**: 2025-07-03  
**Purpose**: L²-norm convergence analysis for 4D Deuflhard function  
**Dependencies**: Globtim.jl, CairoMakie.jl, ForwardDiff.jl