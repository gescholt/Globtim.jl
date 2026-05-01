# Getting Started

This guide walks you through the basic usage of Globtim.jl for finding all local minima of continuous functions.

## Basic Workflow

**See:** `Examples/hpc_minimal_2d_example.jl`

The typical Globtim workflow consists of five steps:

| Step | Function | Purpose |
|------|----------|---------|
| 1 | `TestInput(f, dim=2, ...)` | Define problem domain |
| 2 | `Constructor(TR, degree)` | Build polynomial approximation |
| 3 | `solve_polynomial_system(x, pol)` | Find critical points |
| 4 | `process_crit_pts(solutions, f, TR)` | Filter to valid solutions |
| 5 | `analyze_critical_points(f, df, TR)` | Refine and classify |

### 1. Define the Problem

```julia
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
```

### 2. Find Critical Points

```julia
pol = Constructor(TR, 8)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, pol)
df = process_crit_pts(solutions, f, TR)
```

### 3. Refine and Classify

```julia
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
```

---

## Domain Specification

**Uniform scaling** (square/cube domain):
```julia
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=1.0)  # [-1,1]²
```

**Non-uniform scaling** (rectangular domain):
```julia
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=[2.0, 1.0])  # [-2,2]×[-1,1]
```

**See:** `Examples/domain_sweep_demo.jl`

---

## Polynomial Degree Selection

For smooth functions, higher polynomial degrees generally improve approximation but increase computation:

```julia
pol = Constructor(TR, degree)  # degree = 4, 6, 8, 10, ...
```

Check approximation quality: `pol.nrm` returns L²-norm error.

---

## Precision Parameters

**See:** `Examples/sparsification_demo.jl`

| Precision | Relative cost | Arithmetic | Best For |
|-----------|---------------|------------|----------|
| `Float64Precision` | 1.0× | ~15 digits | **General use (default)** |
| `AdaptivePrecision` | 1.2× | Float64 + BigFloat coefficients | Coefficient analysis, sparsification |
| `RationalPrecision` | 5-10× | Exact arithmetic | Exact evaluations + symbolic solver (msolve) |
| `BigFloatPrecision` | 3-8× | ~77 digits (256 bits) | Research |

**Usage:**
```julia
pol = Constructor(TR, 8, precision=AdaptivePrecision)
```

### AdaptivePrecision with Sparsification

```julia
pol = Constructor(TR, 10, precision=AdaptivePrecision)
@polyvar x[1:2]
mono_poly = to_exact_monomial_basis(pol, variables=x)
analysis = analyze_coefficient_distribution(mono_poly)
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, analysis.suggested_thresholds[1])
```

### High-Dimensional Problems

**See:** `Examples/high_dimensional_demo.jl`

For dimension ≥ 4:
- Use `AdaptivePrecision` for good accuracy/performance balance
- Use coefficient truncation to manage polynomial complexity
- Monitor memory usage with higher degrees

### HPC Cluster Usage

```julia
pol = Constructor(TR, 8, precision=AdaptivePrecision, verbose=0)
```

- `Float64Precision`: Fastest, lowest memory; sufficient for most cases
- `AdaptivePrecision`: Higher coefficient precision; useful for sparsification workflows
- Avoid `RationalPrecision` for large-scale computations

---

## Built-in Test Functions

| Function | Dimension | Description |
|----------|-----------|-------------|
| `Deuflhard` | 2D | Challenging with multiple minima |
| `Rastrigin` | nD | Classic multimodal benchmark |
| `HolderTable` | 2D | 4 symmetric global minima |
| `tref_3d` | 3D | Highly oscillatory |
| `Beale`, `Rosenbrock`, `Branin` | 2D | Standard benchmarks |

**Usage:**
```julia
f = Deuflhard
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
```

---

## Next Steps

- [Examples](examples.md) - Runnable example files
- [Precision Parameters](precision_parameters.md) - Detailed precision documentation
- [Core Algorithm](core_algorithm.md) - Mathematical foundations
- [Critical Point Analysis](critical_point_analysis.md) - Advanced refinement
- [Sparsification](sparsification.md) - Polynomial complexity reduction
- [GlobtimPostProcessing](https://github.com/gescholt/globtimpostprocessing) - Refine critical points to high accuracy, campaign analysis
- [GlobtimPlots](globtimplots.md) - Visualize experiments and results
- [API Reference](api_reference.md) - Complete function documentation
