# Examples

This page demonstrates Globtim features with inline examples and visual results.

> **Note:** Standalone example scripts are being prepared for a future release.

---

## Test Function Gallery

Visual examples of Globtim finding critical points on standard benchmark functions.

### Deuflhard
![Deuflhard Function](assets/plots/deuflhard.png)

### Holder Table
![Holder Table Function](assets/plots/holder_table.pdf)

### Beale
![Beale Function](assets/plots/beale.pdf)

### Branin
![Branin Function](assets/plots/branin.pdf)

---

## Basic 2D Workflow

**Core API sequence:**

| Step | API Call |
|------|----------|
| 1. Define problem | `TestInput(f, dim=2, center=[0.0,0.0], sample_range=1.2)` |
| 2. Build polynomial | `Constructor(TR, degree)` |
| 3. Find critical pts | `solve_polynomial_system(x, pol)` |
| 4. Process solutions | `process_crit_pts(solutions, f, TR)` |
| 5. Analyze & classify | `analyze_critical_points(f, df, TR, enable_hessian=true)` |

---

## Custom Objective Functions

Define any function accepting a vector `x` and returning a scalar:

```julia
my_function(x) = (x[1]^2 - 1)^2 + (x[2]^2 - 1)^2 + 0.1*sin(10*x[1]*x[2])
```

---

## Statistical Analysis with Tables

**API pattern:**
```julia
df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(f, df, TR, show_tables=true)
```

Export options: `write_tables_to_csv()`, `write_tables_to_markdown()`, `write_tables_to_latex()`

---

## High-Dimensional Problems (3D/4D)

**Tips:**
- Use `AdaptivePrecision` for accuracy/performance balance
- Reduce polynomial degree as dimension increases (4D → degree 4-6)
- Disable Hessian analysis for faster results: `enable_hessian=false`

---

## Domain Exploration

Test different domain sizes to find all critical points:

```julia
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=r)      # uniform
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=[2.0, 1.0])  # rectangular
```

---

## Visualization

For plotting critical points and convergence analysis, use the [GlobtimPlots](https://github.com/gescholt/globtimplots) package:

```julia
using GlobtimPlots
fig = plot_critical_points(df_enhanced)
fig = plot_convergence(results)
```

See the [GlobtimPlots documentation](globtimplots.md) for available plot types.

For post-experiment analysis (refinement, parameter recovery, campaign comparison), use [GlobtimPostProcessing](https://github.com/gescholt/globtimpostprocessing).

---

## Polynomial Degree Comparison

Compare Chebyshev vs Legendre bases and analyze how polynomial degree affects approximation quality and critical point discovery. See the [Polynomial Approximation](polynomial_approximation.md) page for theoretical background.

---

## 1D Functions with Scalar Input

Works with functions like `sin`, `cos` that expect scalar input:

```julia
f = x -> sin(3x) + 0.1*x^2
TR = TestInput(f, dim=1, center=[0.0], sample_range=π)
```

---

## Basin Analysis

Analyze convergence basins for critical points. The `df_min` DataFrame includes:
- `basin_points` - Number of points converging to this minimum
- `average_convergence_steps` - Mean BFGS iterations
- `region_coverage_count` - Spatial coverage metric

---

## Next Steps

- [Getting Started](getting_started.md) - Basic concepts and setup
- [API Reference](api_reference.md) - Complete function documentation
- [Precision Parameters](precision_parameters.md) - Numerical precision options
- [Sparsification](sparsification.md) - Polynomial complexity reduction
