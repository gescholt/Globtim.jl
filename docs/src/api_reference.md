# API Reference

> **Note:** As of v1.1.2, the public API has been streamlined to include only essential functions.

## Main Functions

### Problem Setup

#### `test_input`
Create test input specification for optimization problems.

```julia
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
```

#### `Constructor`
Build polynomial approximation with precision control.

**Signature:**
```julia
Constructor(T::test_input, degree; precision=AdaptivePrecision, basis=:chebyshev, verbose=0, grid=nothing)
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `T` | `test_input` | Problem specification |
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

#### `analyze_critical_points_with_tables`
Enhanced analysis with statistical tables.

```julia
df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(f, df, TR, show_tables=true)
```

→ `Examples/hierarchical_experiment_example.jl`

---

## Polynomial Approximation

| Function | Purpose |
|----------|---------|
| `chebyshev_extrema(n)` | Generate Chebyshev extrema points |
| `chebyshev_polys(x, n)` | Evaluate Chebyshev polynomials |
| `grid_sample(TR, n)` | Create sampling grid |
| `sample_objective_on_grid(f, grid)` | Evaluate objective on grid |
| `lambda_vandermonde(grid, degree)` | Construct Vandermonde matrix |

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

| Function | Output Format |
|----------|---------------|
| `write_tables_to_csv(tables, path)` | CSV |
| `write_tables_to_latex(tables, path)` | LaTeX |
| `write_tables_to_markdown(tables, path)` | Markdown |

---

## Types

### Core Types

| Type | Description |
|------|-------------|
| `test_input` | Problem specification |
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
julia> ?test_input
julia> ?analyze_critical_points
```
