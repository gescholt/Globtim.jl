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
         (Chebyshev fit)     (HomotopyContinuation)
```

For functions that vary on different scales in different regions, Globtim uses **adaptive subdivision** to build piecewise polynomial approximations that maintain accuracy everywhere.

## Installation

```julia
julia> ]
pkg> add Globtim
```

### Optional Dependencies
- **For visualization**: `add CairoMakie` or `add GLMakie`
- **For exact solving**: Install [Msolve](https://msolve.lip6.fr/)

## Getting Started

To see Globtim in action, run the demo script:

```bash
julia --project=. examples/quick_subdivision_demo.jl
```

This tests adaptive subdivision on multiple functions (sphere, Rosenbrock, Rastrigin) and shows the algorithm's behavior.

For a detailed walkthrough, see [Getting Started](getting_started.md).

## Key Features

### Anisotropic Grid Support
- Generate grids with different numbers of points per dimension
- Optimize point allocation for multiscale functions
- Achieve up to 15x better accuracy for the same computational cost
- Support for Chebyshev, Legendre, and uniform node distributions

See [Anisotropic Grids Guide](anisotropic_grids_guide.md) for details.

### Enhanced L²-Norm Computation
- Quadrature-based L²-norm using orthogonal polynomials
- Support for anisotropic grids in all norm computations
- High-accuracy integration for smooth functions
- Efficient tensor product quadrature

### Polynomial Sparsification and Exact Arithmetic
- Convert polynomials to exact monomial basis
- Intelligently sparsify polynomials by removing small coefficients
- Track L²-norm preservation during sparsification
- Analyze tradeoffs between sparsity and approximation quality

See [Polynomial Sparsification](sparsification.md) for details.

### Exact Polynomial Conversion
- Convert from orthogonal bases to monomial form
- Support for exact rational arithmetic
- Symbolic manipulation capabilities
- Integration with computer algebra systems

See [Exact Polynomial Conversion](exact_conversion.md) for details.

## Testing

Comprehensive test suite with detailed documentation:
- [Test Documentation Overview](test_documentation.md) - Complete test suite guide
- [Test Running Guide](test_running_guide.md) - How to run tests effectively
- [Anisotropic Grid Tests](anisotropic_grid_tests.md) - Detailed test explanations

## Contents

```@contents
Pages = ["getting_started.md", "core_algorithm.md", "polynomial_approximation.md", "solvers.md", "critical_point_analysis.md", "anisotropic_grids_guide.md", "sparsification.md", "exact_conversion.md", "grid_formats.md", "test_documentation.md", "test_running_guide.md", "anisotropic_grid_tests.md", "api_reference.md", "examples.md", "visualization.md"]
Depth = 2
```