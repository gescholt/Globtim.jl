# Grid Formats in Globtim

This document explains the two grid representations used in Globtim and how to work with them.

## Overview

Globtim uses two different grid formats for different purposes:

1. **Array{SVector} format** - Natural Julia arrays of static vectors
2. **Matrix format** - Traditional matrix representation required for linear algebra operations

## Grid Formats

### Array{SVector} Format

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

### Matrix Format

Required for Vandermonde matrix construction:

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

## Conversion Utilities

### grid_to_matrix

Convert from Array{SVector} to Matrix format:

```julia
grid = generate_grid(2, 10, basis=:chebyshev)
matrix = grid_to_matrix(grid)
```

### ensure_matrix_format

Automatically handle both formats:

```julia
# Works with either format
matrix = ensure_matrix_format(grid_or_matrix)
```

### matrix_to_grid

Convert back to Array{SVector} format:

```julia
grid = matrix_to_grid(matrix, dim)
```

### get_grid_info

Query information about any grid:

```julia
info = get_grid_info(grid)
# Returns: (format=:svector_array, n_points=121, dim=2, is_regular=true)
```

## Usage Examples

### Function Evaluation

Use Array{SVector} format directly:

```julia
f = x -> sum(x.^2)
grid = generate_grid(2, 10)
values = map(f, reshape(grid, :))
```

### Vandermonde Matrix Construction

Convert to matrix format first:

```julia
grid = generate_grid(2, 10, basis=:chebyshev)
matrix_grid = grid_to_matrix(grid)
Lambda = SupportGen(2, 5)
V = lambda_vandermonde(Lambda, matrix_grid, basis=:chebyshev)
```

### Working with ApproxPoly

The `ApproxPoly` type stores grids in matrix format:

```julia
pol = Constructor(TR, 10, basis=:chebyshev)
# pol.grid is already in matrix format
V = lambda_vandermonde(Lambda, pol.grid, basis=pol.basis)
```

## Best Practices

1. **Let functions handle conversion**: Use `ensure_matrix_format` in functions that need matrix format
2. **Preserve original format**: Don't convert unnecessarily - each format has its advantages
3. **Document expectations**: Clearly state which format your functions expect
4. **Use type annotations**: Help catch format mismatches early

## Why Two Formats?

**Historical reasons:**
- Early Globtim used matrix format exclusively
- Julia's StaticArrays provide better performance for point operations
- Grid generation evolved to use SVector for efficiency

**Technical reasons:**
- Array{SVector} is more natural for Julia's type system
- Matrix format is required for BLAS/LAPACK compatibility
- Different algorithms work better with different representations

## Migration Guide

If you have code expecting one format:

```julia
# Old code expecting matrix
function my_function(grid::Matrix)
    # ...
end

# Updated to handle both
function my_function(grid)
    matrix_grid = ensure_matrix_format(grid)
    # ...
end
```
