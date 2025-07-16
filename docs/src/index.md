# Globtim.jl Documentation

Welcome to the documentation for Globtim.jl, a Julia package for global optimization of continuous functions via polynomial approximation.

## Overview

Globtim finds **all local minima** of continuous functions over compact domains using Chebyshev/Legendre polynomial approximation and critical point analysis.

## Installation

```julia
julia> ]
pkg> add Globtim
```

## Quick Start

```julia
using Globtim, DynamicPolynomials, DataFrames

# Define problem
f = Deuflhard  # Built-in test function
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

# Step 1: Polynomial approximation and critical point finding
pol = Constructor(TR, 8)  # Degree 8 approximation
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Step 2: Enhanced analysis with automatic classification
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
```

## API Reference

```@autodocs
Modules = [Globtim]
```