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
| **[GlobtimPostProcessing](https://github.com/gescholt/globtimpostprocessing)** | Refinement, validation, parameter recovery, campaign analysis | [GitHub](https://github.com/gescholt/globtimpostprocessing) |
| **[GlobtimPlots](https://github.com/gescholt/globtimplots)** | Visualization (CairoMakie/GLMakie) for experiments and campaigns | [GitHub](https://github.com/gescholt/globtimplots) |

```
Globtim (experiments) --> GlobtimPostProcessing (analysis) --> GlobtimPlots (visualization)
```

Install companion packages:
```julia
pkg> add GlobtimPostProcessing
pkg> add GlobtimPlots
```
