# API Reference

> **Note:** As of v1.2.0, the public API has been streamlined to include only essential functions.

## Main Functions

### Problem Setup

#### `TestInput`
Create test input specification for optimization problems.

```julia
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
```

#### `Constructor`
Build polynomial approximation with precision control.

**Signature:**
```julia
Constructor(T::TestInput, degree; precision=AdaptivePrecision, basis=:chebyshev, verbose=0, grid=nothing)
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `T` | `TestInput` | Problem specification |
| `degree` | `Int` | Polynomial degree |
| `precision` | `PrecisionType` | `Float64Precision`, `AdaptivePrecision`, `RationalPrecision`, `BigFloatPrecision` |
| `basis` | `Symbol` | `:chebyshev` or `:legendre` |
| `verbose` | `Int` | 0=quiet, 1=basic, 2=detailed |
| `grid` | `Matrix` | Optional pre-generated grid |

**Returns:** `ApproxPoly` with fields `coeffs`, `nrm`, `precision`

→ `Examples/hpc_minimal_2d_example.jl`

---

#### `solve_polynomial_system`
Find critical points by solving ∇p(x) = 0.

```julia
solutions = solve_polynomial_system(x, pol)  # Convenience method
solutions = solve_polynomial_system(x, dim, degree, coeffs)  # Explicit parameters
```

Accepts `solver=:hc` (default) or `:msolve`, plus `start_system` (polyhedral homotopy),
`sparsify_threshold`, and `search_bounds` (box restriction; certified for msolve). See
[Solvers → Advanced Options](solvers.md#Advanced-Options) for details.

#### `process_crit_pts`
Process and filter critical point solutions.

```julia
df = process_crit_pts(solutions, f, TR)
```

---

### Analysis Functions

#### `analyze_critical_points`
Comprehensive critical point analysis with BFGS refinement.

```julia
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true, verbose=true, tol_dist=0.025)
```

> Enhanced statistical tables (rendering and CSV/Markdown/LaTeX export) are provided by
> the [GlobtimPostProcessing](https://github.com/gescholt/GlobtimPostProcessing.jl)
> package, which consumes the `df_enhanced` DataFrame returned above — see its
> `export_analysis_tables`.

---

## Polynomial Approximation

| Function | Purpose |
|----------|---------|
| `lambda_vandermonde(grid, degree)` | Construct the Chebyshev/Legendre Vandermonde matrix |

---

## Critical Point Analysis

| Function | Purpose |
|----------|---------|
| `compute_hessians(f, points)` | Compute Hessian matrices |
| `classify_critical_points(hessians)` | Classify based on eigenvalues |
| `compute_hessian_norms(df)` | Calculate Frobenius norms |
| `analyze_basins(df)` | Analyze basins of attraction |

---

## BFGS Refinement

| Function | Purpose |
|----------|---------|
| `enhanced_bfgs_refinement(f, x0)` | BFGS with hyperparameter tracking |
| `refine_with_enhanced_bfgs(f, df)` | Apply BFGS to DataFrame |
| `determine_convergence_reason(result)` | Analyze convergence |

---

## Precision Control

### Precision Types

| Type | Coefficient Type | Best For |
|------|-----------------|----------|
| `Float64Precision` | `Float64` | Fast computation |
| `AdaptivePrecision` | `Float64` (raw), `BigFloat` (monomial) | Recommended default |
| `RationalPrecision` | `Rational{BigInt}` | Exact arithmetic |
| `BigFloatPrecision` | `BigFloat` | Maximum precision |

→ `Examples/sparsification_demo.jl`

---

## Sparsification

| Function | Purpose |
|----------|---------|
| `to_exact_monomial_basis(pol, variables=x)` | Convert to monomial basis |
| `analyze_coefficient_distribution(poly)` | Analyze for truncation |
| `truncate_polynomial_adaptive(poly, threshold)` | Smart truncation |
| `sparsify_polynomial(pol, threshold)` | Zero small coefficients |
| `verify_truncation_quality(original, truncated, domain)` | Verify L²-norm preservation |

**Usage pattern:**
```julia
mono_poly = to_exact_monomial_basis(pol, variables=x)
analysis = analyze_coefficient_distribution(mono_poly)
truncated, stats = truncate_polynomial_adaptive(mono_poly, analysis.suggested_thresholds[1])
```

---

## Grid Generation

| Function | Purpose |
|----------|---------|
| `generate_grid(n, dim)` | Isotropic grid |
| `generate_anisotropic_grid([n1, n2, ...])` | Different points per dimension |
| `grid_to_matrix(grid)` | Convert to matrix format |
| `is_anisotropic(grid)` | Check grid type |

→ `Examples/anisotropic_grid_demo.jl`

---

## L²-Norm Computation

| Function | Purpose |
|----------|---------|
| `compute_l2_norm(poly, domain)` | L²-norm over domain |
| `compute_l2_norm_quadrature(f, poly, domain)` | Using quadrature |
| `discrete_l2_norm_riemann(values, grid)` | Riemann sum approximation |
| `integrate_monomial(exponents, domain)` | Analytic monomial integration |

---

## Export Functions

Statistical-table rendering and export live in
[GlobtimPostProcessing](https://github.com/gescholt/GlobtimPostProcessing.jl):
`export_analysis_tables(tables, name, output_dir; formats=[:csv, :markdown, :latex])`.

Globtim itself exports critical-point data via the standard DataFrame columns of
`df_enhanced` / `df_min` (write with `CSV.write` as needed).

---

## Types

### Core Types

| Type | Description |
|------|-------------|
| `TestInput` | Problem specification |
| `ApproxPoly` | Polynomial approximation with `coeffs`, `nrm`, `precision` |
| `BFGSConfig` | BFGS configuration |
| `BFGSResult` | BFGS results |
| `BoxDomain{T}` | Domain [-a,a]ⁿ for L²-norm |

### Precision Types

```julia
# Available values
Float64Precision, AdaptivePrecision, RationalPrecision, BigFloatPrecision
```

---

## Built-in Test Functions

### 2D Functions
`Deuflhard`, `HolderTable`, `Ackley`, `camel`, `shubert`

### 3D Functions
`tref_3d`

### n-Dimensional Functions
`Rastrigin`, `alpine1`, `alpine2`, `Csendes`

---

## Help System

```julia
julia> ?TestInput
julia> ?analyze_critical_points
```

---

## See Also

- [GlobtimPostProcessing](https://github.com/gescholt/GlobtimPostProcessing.jl) - Refinement, gradient validation, parameter recovery, campaign analysis
- [GlobtimPlots](https://github.com/gescholt/GlobtimPlots.jl) - Visualization functions for experiments and campaigns
