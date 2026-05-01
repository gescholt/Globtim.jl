# Grid Formats in Globtim

This document explains the two grid representations used in Globtim.

## Overview

Globtim uses two different grid formats:

1. **Array{SVector} format** - Natural Julia arrays of static vectors (from [StaticArrays.jl](https://github.com/JuliaArrays/StaticArrays.jl))
2. **Matrix format** - Traditional matrix representation required for linear algebra operations

## Array{SVector} Format

This is the natural output from `generate_grid`:

```julia
grid = generate_grid(2, 10, basis=:chebyshev)
# Returns: 11×11 Array{SVector{2,Float64},2}
```

**Characteristics:**
- Each element is an `SVector{N,Float64}` representing a point
- N-dimensional array structure preserves grid topology
- Efficient for point-wise function evaluation
- Natural for Julia's multiple dispatch

**Used for:**
- Function evaluation at grid points
- Grid traversal and manipulation
- Discrete L²-norm computation

**Example:**

```julia
f = x -> sum(x.^2)
grid = generate_grid(2, 10)
values = map(f, reshape(grid, :))
```

## Matrix Format

Required for Vandermonde matrix construction. Convert using `grid_to_matrix`:

```julia
matrix_grid = grid_to_matrix(grid)
# Returns: 121×2 Matrix{Float64}
```

**Characteristics:**
- Each row represents a point
- Each column represents a dimension
- Compatible with BLAS operations
- Required by `lambda_vandermonde`

**Used for:**
- Vandermonde matrix construction
- Linear algebra operations
- Polynomial basis evaluation

**Example:**

```julia
grid = generate_grid(2, 10, basis=:chebyshev)
matrix_grid = grid_to_matrix(grid)
Lambda = SupportGen(2, 5)
V = lambda_vandermonde(Lambda, matrix_grid, basis=:chebyshev)
```

The `ApproxPoly` type stores grids in matrix format:

```julia
pol = Constructor(TR, 10, basis=:chebyshev)
# pol.grid is already in matrix format
V = lambda_vandermonde(Lambda, pol.grid, basis=pol.basis)
```
