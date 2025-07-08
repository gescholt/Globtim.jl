# L²-Norm Data Flow Documentation

This document explains how the L²-norm approximation errors are computed and visualized in the 4D Deuflhard convergence analysis examples.

## Overview

The L²-norm plots show **actual computed approximation errors** from polynomial approximations of the 4D Deuflhard composite function. Each data point represents a real computational result, not theoretical or synthetic data.

## Data Flow Architecture

```
┌─────────────────────┐
│ 4D Deuflhard        │
│ Composite Function  │
│ f(x₁,x₂,x₃,x₄)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Polynomial          │
│ Approximation       │
│ (Globtim)          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ L²-Norm Error       │
│ Calculation         │
│ pol.nrm            │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Analysis Results    │
│ DegreeAnalysisResult│
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Visualization       │
│ CairoMakie Plots   │
└─────────────────────┘
```

## Detailed Data Flow

### 1. Function Definition (`Common4DDeuflhard.jl`)
```julia
function deuflhard_4d_composite(x::AbstractVector)::Float64
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end
```
- Tensor product of two 2D Deuflhard functions
- Evaluated at sample points for polynomial fitting

### 2. Polynomial Construction (`AnalysisUtilities.jl`)
```julia
# Create polynomial approximation
TR = test_input(f, dim=4, center=center, sample_range=range, GN=gn)
pol = Constructor(TR, degree, basis=basis, verbose=false)
```
- `test_input`: Generates sample points and function values
- `Constructor`: Builds polynomial approximation using least squares
- `GN_FIXED = 10`: Controls sample density

### 3. L²-Norm Computation
```julia
pol.nrm  # This is the actual L²-norm approximation error
```
- Computed internally by Globtim during polynomial construction
- Represents: `||f - p||_L²` where `f` is the true function and `p` is the polynomial
- Calculated using numerical integration over the domain

### 4. Result Storage (`DegreeAnalysisResult`)
```julia
return DegreeAnalysisResult(
    actual_degree,
    pol.nrm,  # L²-norm stored here
    length(theoretical_points),
    length(computed_points),
    metrics.n_successful_recoveries,
    metrics.success_rate,
    runtime,
    converged,
    computed_points,
    metrics.min_min_success_rate
)
```

### 5. Adaptive Algorithm (`03_subdivided_adaptive.jl`)
For each of the 16 subdomains:
1. Start with degree 2
2. Compute polynomial approximation
3. Extract L²-norm error
4. If error > tolerance, increase degree
5. Repeat until convergence or max degree reached
6. Store all intermediate results

### 6. Visualization (`PlottingUtilities.jl`)
```julia
# For each subdomain's results
degrees = [r.degree for r in results]
l2_norms = [r.l2_norm for r in results]  # Actual computed errors

# Plot with log scale
scatterlines!(ax, valid_degrees, valid_l2_norms, 
           color = colors[color_idx], markersize = 6, linewidth = 1.5)
```

## Key Properties of the L²-Norm Data

1. **Real Computational Results**: Every point on the plot represents an actual polynomial approximation computed by Globtim
2. **Domain-Specific**: Each subdomain has its own approximation challenges, reflected in different convergence rates
3. **Monotonic Decrease**: L²-norm generally decreases with increasing polynomial degree (better approximation)
4. **Convergence Threshold**: The horizontal reference line shows the target tolerance (default: 1e-2)

## Example Data Point

For subdomain "0101" at degree 4:
1. Globtim constructs a degree-4 polynomial using 10⁴ sample points
2. The polynomial coefficients are computed via least squares
3. The L²-norm error between polynomial and true function is calculated
4. Result: `pol.nrm = 8.395e+00` (actual value from computation)
5. This becomes one point on the convergence plot

## Output Files

The computed data is saved in multiple formats:
- **PNG Plots**: Visual representation of convergence
- **CSV Files**: Raw numerical data for further analysis
- **Summary Tables**: Key statistics printed to console

All outputs are based on actual computational results, making them suitable for publication and further research.