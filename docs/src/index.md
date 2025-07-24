# Globtim.jl Documentation

[![Run Tests](https://github.com/gescholt/globtim.jl/actions/workflows/test.yml/badge.svg)](https://github.com/gescholt/globtim.jl/actions/workflows/test.yml)
[![Julia 1.11](https://img.shields.io/badge/julia-1.11+-blue.svg)](https://julialang.org/downloads/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Global optimization of continuous functions via polynomial approximation**

Globtim finds **all local minima** of continuous functions over compact domains using Chebyshev/Legendre polynomial approximation and critical point analysis.

## Overview

Globtim.jl provides a comprehensive framework for global optimization through:

1. **Polynomial Approximation**: High-accuracy approximation using Chebyshev/Legendre polynomials
2. **Critical Point Finding**: Systematic identification of all stationary points
3. **Hessian Analysis**: Classification and validation of critical points
4. **Statistical Assessment**: Quality metrics and convergence analysis

## Installation

```julia
julia> ]
pkg> add Globtim
```

### Optional Dependencies
- **For visualization**: `add CairoMakie` or `add GLMakie`
- **For exact solving**: Install [Msolve](https://msolve.lip6.fr/)

## Quick Start

```julia
using Globtim, DynamicPolynomials, DataFrames

# Define problem
f = Deuflhard  # Built-in test function
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

# Step 1: Polynomial approximation
pol = Constructor(TR, 8)  # Degree 8 approximation
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Step 2: Enhanced analysis
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
```

## New Features

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

## Testing

Comprehensive test suite with detailed documentation:
- [Test Documentation Overview](test_documentation.md) - Complete test suite guide
- [Test Running Guide](test_running_guide.md) - How to run tests effectively
- [Anisotropic Grid Tests](anisotropic_grid_tests.md) - Detailed test explanations

## Contents

```@contents
Pages = ["getting_started.md", "core_algorithm.md", "critical_point_analysis.md", "anisotropic_grids_guide.md", "sparsification.md", "test_documentation.md", "test_running_guide.md", "anisotropic_grid_tests.md", "api_reference.md", "examples.md", "visualization.md"]
Depth = 2
```