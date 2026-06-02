# Examples

This page demonstrates Globtim features with inline examples and visual results.

## Runnable demo scripts

Self-contained scripts ship in the [`examples/`](https://github.com/gescholt/Globtim.jl/tree/main/examples) directory. Run any of them from a project that has Globtim installed (e.g. `julia examples/custom_function_demo.jl`):

| Script | What it shows |
|---|---|
| `custom_function_demo.jl` | Define a custom 2D objective, build the polynomial approximation, find critical points |
| `quick_subdivision_demo.jl` | Adaptive subdivision on sphere / Rosenbrock / Rastrigin / anisotropic |
| `domain_sweep_demo.jl` | Sweep over domain sizes for a fixed objective |
| `high_dimensional_demo.jl` | 3D / 4D scaling behaviour |
| `scalar_function_demo.jl` | 1D scalar functions |
| `sparsification_demo.jl` | Polynomial coefficient sparsification |
| `anisotropic_grid_demo.jl` | Anisotropic Chebyshev / Legendre grids |

For an end-to-end tour across all three packages (find → refine → plot), see the
[Ecosystem Walkthrough](ecosystem_walkthrough.md).

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

The enhanced statistics and table rendering/export live in the
[GlobtimPostProcessing](https://github.com/gescholt/GlobtimPostProcessing.jl)
package, which consumes the `df_enhanced` DataFrame produced by
`analyze_critical_points`:

```julia
using GlobtimPostProcessing
# render statistical tables and export to CSV / Markdown / LaTeX
export_analysis_tables(tables, "critical_point_analysis", output_dir; formats=[:csv, :markdown, :latex])
```

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

For plotting the polynomial level set with critical points overlaid, use the
[GlobtimPlots](globtimplots.md) package. Load a Makie backend (`CairoMakie` for
static files, `GLMakie` for interactive windows) **before** calling any plot function:

```julia
using GlobtimPlots
using CairoMakie

apol = adapt_polynomial_data(pol)   # adapt globtim objects for plotting
ainp = adapt_problem_input(TR)
fig = cairo_plot_polyapprox_levelset(apol, ainp, df_enhanced, df_min)
CairoMakie.save("levelset.png", fig)
```

See the [GlobtimPlots documentation](globtimplots.md) for the full set of plot types
(Morse spectra, subdivision partitions, convergence sweeps).

For post-experiment analysis (refinement, parameter recovery, campaign comparison),
use [GlobtimPostProcessing](https://github.com/gescholt/GlobtimPostProcessing.jl).

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
