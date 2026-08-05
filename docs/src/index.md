# Globtim.jl Documentation

[![Julia 1.11](https://img.shields.io/badge/julia-1.11+-blue.svg)](https://julialang.org/downloads/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Global optimization of continuous functions via polynomial approximation**

## The Problem

Finding all local minima of a continuous function over a bounded domain is fundamentally hard. Standard optimization algorithms (gradient descent, BFGS, etc.) find *one* local minimum from a given starting point — but how do you know there isn't a better one elsewhere?

## The Approach

Globtim solves this by replacing your function with a polynomial approximation. Why polynomials?

1. **Smooth functions are well-approximated by polynomials** — Chebyshev and Legendre bases provide well-conditioned polynomial approximations whose accuracy improves with degree for smooth functions
2. **Polynomial critical points can be enumerated** — Setting ∇p(x) = 0 gives a polynomial system with finitely many solutions (bounded by Bezout's theorem), which can be computed numerically via homotopy continuation or exactly via symbolic methods
3. **Refinement on the original function** — Each polynomial critical point seeds a local optimization (BFGS) on the original function, which can converge to a nearby true critical point

The result: a systematic search for local minima across the entire domain, not just the nearest one.

The method comes with a **global-capture guarantee**: for Morse functions on a compact domain, the returned points provably contain and separate *every* local minimizer at the target precision (with high probability), under an explicit degree/sample/noise trade-off. This is established in the foundational paper — see [Citation](#Citation).

## Algorithm Overview

```
f(x)  -->  Polynomial p(x)  -->  Solve grad(p) = 0  -->  Refine with BFGS  -->  Candidate minima
           (Chebyshev/Legendre)   (HomotopyContinuation.jl)
```

### Challenging 1D function — multi-frequency oscillations at varying polynomial degrees:

![1D Comparison](assets/1D_comparison.png)

### Styblinski-Tang 2D — classic test function with polynomial approximation:

![Styblinski-Tang](assets/styblinski_tang_comparison.png)

For functions that vary on different scales in different regions, Globtim uses **adaptive subdivision** to build piecewise polynomial approximations that maintain accuracy everywhere.

## Installation

```julia
julia> ]
pkg> add Globtim
```

### Additional Dependencies
- **Visualization**: `add CairoMakie` or `add GLMakie`
- **Exact solving**: Install [msolve](https://msolve.lip6.fr/) (symbolic method based on Groebner basis computations)

## Getting Started

For a detailed walkthrough, see [Getting Started](getting_started.md).

## Ecosystem

Globtim is part of a three-package ecosystem for global optimization:

| Package | Description | Repository |
|:--------|:------------|:-----------|
| **Globtim** | Core polynomial approximation and critical point finding | [GitHub](https://github.com/gescholt/Globtim.jl) |
| **[GlobtimPostProcessing](https://github.com/gescholt/GlobtimPostProcessing.jl)** | Refinement, validation, parameter recovery, campaign analysis | [GitHub](https://github.com/gescholt/GlobtimPostProcessing.jl) |
| **[GlobtimPlots](https://github.com/gescholt/GlobtimPlots.jl)** | Visualization (CairoMakie/GLMakie) for experiments and campaigns | [GitHub](https://github.com/gescholt/GlobtimPlots.jl) |

```
Globtim (experiments) --> GlobtimPostProcessing (analysis) --> GlobtimPlots (visualization)
```

Install companion packages:
```julia
pkg> add GlobtimPostProcessing
pkg> add GlobtimPlots
```

## Citation

Globtim implements the algorithm introduced in:

> Safey El Din, M., Scholten, G., & Trélat, E. (2026). *Probabilistic algorithm for computing all local minimizers of Morse functions on a compact domain*. **Mathematics of Control, Signals, and Systems**. [doi:10.1007/s00498-026-00441-3](https://doi.org/10.1007/s00498-026-00441-3). Free access: [HAL hal-05160251](https://hal.sorbonne-universite.fr/hal-05160251v2).

If you use Globtim in your research, please cite this paper:

```bibtex
@article{safeyeldin2026probabilistic,
  author  = {Safey El Din, Mohab and Scholten, Georgy and Tr{\'e}lat, Emmanuel},
  title   = {Probabilistic algorithm for computing all local minimizers of {Morse} functions on a compact domain},
  journal = {Mathematics of Control, Signals, and Systems},
  year    = {2026},
  doi     = {10.1007/s00498-026-00441-3},
  note    = {Free access: HAL hal-05160251, https://hal.sorbonne-universite.fr/hal-05160251v2},
}
```
