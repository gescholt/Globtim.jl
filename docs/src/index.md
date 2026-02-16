# Globtim.jl Documentation

[![Julia 1.11](https://img.shields.io/badge/julia-1.11+-blue.svg)](https://julialang.org/downloads/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Global optimization of continuous functions via polynomial approximation**

## The Problem

Finding all local minima of a continuous function over a bounded domain is fundamentally hard. Standard optimization algorithms (gradient descent, BFGS, etc.) find *one* local minimum from a given starting point—but how do you know there isn't a better one elsewhere?

## The Approach

Globtim solves this by replacing your function with a polynomial approximation. Why polynomials?

1. **Smooth functions are well-approximated by polynomials** — Chebyshev and Legendre expansions converge rapidly for smooth functions
2. **Polynomial critical points can be found exactly** — Setting ∇p(x) = 0 gives a polynomial system, which has finitely many solutions that can be computed using homotopy continuation
3. **Refinement recovers true minima** — Each polynomial critical point seeds a local optimization (BFGS) on the original function

The result: a systematic way to find *all* local minima, not just the nearest one.

## Algorithm Overview

```
f(x)  →  Polynomial p(x)  →  Solve ∇p = 0  →  Refine with BFGS  →  All minima
         (Chebyshev fit)     (numerical or exact)
```

| ![Step 1](assets/plots/hero_step1_sample.pdf) | ![Step 2](assets/plots/hero_step2_polynomial.pdf) | ![Step 3](assets/plots/hero_step3_minima.pdf) |
|:--:|:--:|:--:|

For functions that vary on different scales in different regions, Globtim uses **adaptive subdivision** to build piecewise polynomial approximations that maintain accuracy everywhere.

## Installation

```julia
julia> ]
pkg> add Globtim
```

### Additional Dependencies
- **Visualization**: `add CairoMakie` or `add GLMakie`
- **Exact solving**: Install [msolve](https://msolve.lip6.fr/) (symbolic method based on Gröbner basis computations)

## Getting Started

To see Globtim in action, run the demo script:

```bash
julia --project=. examples/quick_subdivision_demo.jl
```

This tests adaptive subdivision on multiple functions (sphere, Rosenbrock, Rastrigin) and shows the algorithm's behavior.

For a detailed walkthrough, see [Getting Started](getting_started.md).

## Ecosystem

Globtim is part of a three-package ecosystem for global optimization:

| Package | Description | Repository |
|:--------|:------------|:-----------|
| **Globtim** | Core polynomial approximation and critical point finding | [GitHub](https://github.com/gescholt/Globtim.jl) |
| **[GlobtimPostProcessing](https://github.com/gescholt/globtimpostprocessing)** | Refinement, validation, parameter recovery, campaign analysis | [GitHub](https://github.com/gescholt/globtimpostprocessing) |
| **[GlobtimPlots](https://github.com/gescholt/globtimplots)** | Visualization (CairoMakie/GLMakie) for experiments and campaigns | [GitHub](https://github.com/gescholt/globtimplots) |

```
Globtim (experiments) -> GlobtimPostProcessing (analysis) -> GlobtimPlots (visualization)
```

Install companion packages:
```julia
pkg> add GlobtimPostProcessing
pkg> add GlobtimPlots
```
