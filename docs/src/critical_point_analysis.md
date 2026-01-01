# Critical Point Analysis

## Overview

Critical point analysis is performed **after** the polynomial approximation step has identified candidate critical points by solving ∇p(x) = 0. These polynomial critical points are approximate locations that need to be refined and classified on the original objective function.

The analysis proceeds in two steps:

1. **Refinement**: Each polynomial critical point serves as a starting point for local optimization (BFGS) on the original function f(x), converging to a true critical point

2. **Classification**: The Hessian matrix at each refined point is computed using automatic differentiation ([ForwardDiff.jl](https://juliadiff.org/ForwardDiff.jl/stable/)), and eigenvalue analysis determines whether the point is a minimum, maximum, saddle, or degenerate

ForwardDiff.jl provides efficient forward-mode automatic differentiation for computing exact gradients and Hessians without numerical approximation errors.

> **Note:** For comprehensive campaign analysis, statistical reporting, and result aggregation across multiple experiments, see [GlobtimPostProcessing](https://gitlab.com/globaloptim/globtimpostprocessing). The `analyze_critical_points` function documented here provides basic refinement and classification for individual experiments.

## Hessian-Based Classification

The `analyze_critical_points` function computes the Hessian at each refined critical point and classifies it based on eigenvalue analysis:

```julia
df_enhanced, df_min = analyze_critical_points(
    f, df, TR,
    enable_hessian=true,      # Enable classification
    hessian_tol_zero=1e-8    # Zero eigenvalue tolerance
)
```

### Classification Types

Critical points are classified based on Hessian eigenvalues:

- **`:minimum`** - All eigenvalues > `hessian_tol_zero` (positive definite)
- **`:maximum`** - All eigenvalues < -`hessian_tol_zero` (negative definite)
- **`:saddle`** - Mixed positive and negative eigenvalues
- **`:degenerate`** - At least one eigenvalue ≈ 0
- **`:error`** - Hessian computation failed

### Eigenvalue Analysis

For each critical point, the following metrics are computed:

```julia
# Key eigenvalue metrics
df_enhanced.hessian_eigenvalue_min      # Smallest eigenvalue
df_enhanced.hessian_eigenvalue_max      # Largest eigenvalue
df_enhanced.hessian_condition_number    # κ(H) = |λ_max|/|λ_min|
df_enhanced.hessian_determinant         # det(H)
df_enhanced.hessian_trace              # tr(H)
df_enhanced.hessian_norm               # ||H||_F (Frobenius norm)
```

### Special Eigenvalues

For minima and maxima validation:

```julia
# For minima: smallest positive eigenvalue
df_enhanced.smallest_positive_eigenval

# For maxima: largest negative eigenvalue  
df_enhanced.largest_negative_eigenval
```

## Enhanced Statistics

Beyond Hessian analysis, additional statistics are computed:

### Spatial Analysis

```julia
# Spatial clustering
df_enhanced.region_id                   # Spatial region assignment
df_enhanced.nearest_neighbor_dist       # Distance to nearest critical point

# Function value clustering
df_enhanced.function_value_cluster      # Similar function values
```

### Convergence Quality

```julia
# Refinement metrics
df_enhanced.gradient_norm              # ||∇f|| at critical point
df_enhanced.steps                      # BFGS iterations used
df_enhanced.converged                  # Convergence success
df_enhanced.point_improvement          # ||x_refined - x_initial||
df_enhanced.value_improvement          # |f(x_refined) - f(x_initial)|
```

### Basin Analysis

For the unique minimizers in `df_min`:

```julia
# Basin of attraction statistics
df_min.basin_points                    # Number of converging points
df_min.average_convergence_steps       # Mean BFGS iterations
df_min.region_coverage_count          # Spatial regions covered
df_min.gradient_norm_at_min          # Gradient verification
```

## Statistical Tables

Generate comprehensive reports with:

```julia
df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(
    f, df, TR,
    enable_hessian=true,
    show_tables=true,
    table_types=[:minimum, :saddle, :maximum]
)
```

### Table Contents

Each table includes:
- Point coordinates and function values
- Eigenvalue statistics
- Condition numbers
- Convergence metrics
- Distance measurements

### Export Options

```julia
# Export to different formats
write_tables_to_csv(tables, "results.csv")
write_tables_to_latex(tables, "results.tex")
write_tables_to_markdown(tables, "results.md")
```

## Advanced Options

### Custom Tolerances

Fine-tune the analysis with specific tolerances:

```julia
df_enhanced, df_min = analyze_critical_points(
    f, df, TR,
    tol_dist=0.01,              # Tighter clustering
    bfgs_g_tol=1e-10,          # Higher precision
    bfgs_f_abstol=1e-12,       # Function tolerance
    hessian_tol_zero=1e-10     # Eigenvalue threshold
)
```

### Performance Mode

For large problems, disable Hessian analysis:

```julia
# Basic analysis only (faster)
df_basic, df_min = analyze_critical_points(
    f, df, TR,
    enable_hessian=false  # Skip eigenvalue computation
)
```

### Verbose Output

Track progress with detailed output:

```julia
df_enhanced, df_min = analyze_critical_points(
    f, df, TR,
    verbose=true  # Show progress messages
)
```

## Interpreting Results

### Quality Indicators

Good critical points typically have:
- `gradient_norm` < 1e-6
- `converged` = true
- `hessian_condition_number` < 1e6
- Consistent classification between raw and refined points

### Warning Signs

Potential issues indicated by:
- Large `point_improvement` values (poor initial approximation)
- `degenerate` classification (numerical instability)
- High condition numbers (ill-conditioned Hessian)
- Failed convergence within domain

### Basin Structure

The `df_min` DataFrame reveals the optimization landscape:
- Large `basin_points`: Strong attractor
- High `region_coverage_count`: Wide basin
- Low `average_convergence_steps`: Smooth basin