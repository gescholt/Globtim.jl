# API Reference

The primary public API of Globtim, rendered from the in-source docstrings. Use the search box
(top-left) to jump to a specific entry; the full list is in the [Index](#Index) at the bottom.

```@contents
Pages = ["api_reference.md"]
Depth = 2
```

## Problem setup

```@docs
TestInput
Constructor
```

## Critical-point solving

```@docs
solve_polynomial_system
process_crit_pts
```

`analyze_critical_points(f, df, TR; enable_hessian=true, tol_dist=0.025)` runs BFGS refinement and
(optionally) Hessian-based classification over the critical points in `df`, returning
`(df_enhanced, df_min)`. Enhanced statistical tables and CSV/Markdown/LaTeX export are provided by
[GlobtimPostProcessing](https://github.com/gescholt/GlobtimPostProcessing.jl), which consumes the
`df_enhanced` DataFrame.

## Subdivision & refinement

```@docs
adaptive_refine
two_phase_refine
enhanced_bfgs_refinement
refine_with_enhanced_bfgs
determine_convergence_reason
```

## Critical-point analysis

```@docs
classify_critical_points
compute_hessians
analyze_basins
```

## Polynomial evaluation & error

```@docs
evaluate
gradient
relative_l2_error
```

## Sparsification & exact conversion

```@docs
sparsify_polynomial
analyze_sparsification_tradeoff
truncate_polynomial_adaptive
to_exact_monomial_basis
exact_polynomial_coefficients
```

## Grid construction

```@docs
generate_grid
generate_anisotropic_grid
```

## L²-norm computation

```@docs
compute_l2_norm
compute_l2_norm_quadrature
integrate_monomial
```

## Precision types

Every Globtim polynomial carries a `precision::PrecisionType` field. `Constructor` computes Float64
coefficients and defaults to `Float64Precision`; the exact/symbolic paths (`to_exact_monomial_basis`,
`exact_polynomial_coefficients`, the msolve backend) use `RationalPrecision`.

| Type | Coefficient / arithmetic | Best for |
|------|--------------------------|----------|
| `Float64Precision` | `Float64` | Fast numerical work (**default**) |
| `AdaptivePrecision` | `Float64` raw, `BigFloat` monomial | Coefficient analysis, sparsification |
| `RationalPrecision` | `Rational{BigInt}` | Exact arithmetic, symbolic solver (msolve) |
| `BigFloatPrecision` | `BigFloat` | Maximum precision |

## Export

Statistical-table rendering and CSV/Markdown/LaTeX export live in
[GlobtimPostProcessing](https://github.com/gescholt/GlobtimPostProcessing.jl) via
`export_analysis_tables`. Globtim itself exports critical-point data through the DataFrame columns of
`df_enhanced` / `df_min` (write with `CSV.write` as needed).

## Index

```@index
Pages = ["api_reference.md"]
```
