# Grid-Based MainGenerate User Guide

## Overview

As of the latest update, `MainGenerate` now supports pre-generated grids as input. This allows for more control over the polynomial approximation process and can improve performance when working with multiple functions on the same grid.

## Basic Usage

### Traditional Usage (Degree-Based)
```julia
using Globtim

f = x -> exp(-sum(x.^2))
n = 2  # dimension
d = (:one_d_for_all, 5)  # degree 5 in all dimensions

pol = MainGenerate(f, n, d, 0.1, 0.99, 1.0, 1.0)
```

### New Grid-Based Usage
```julia
using Globtim

f = x -> exp(-sum(x.^2))
n = 2  # dimension

# Create your own grid (must be Matrix{Float64})
# Each row is a point in n-dimensional space
grid = [
    -0.7071  -0.7071;
     0.7071  -0.7071;
    -0.7071   0.7071;
     0.7071   0.7071
]

pol = MainGenerate(f, n, grid, 0.1, 0.99, 1.0, 1.0)
```

## Using with Standard Grid Generators

### Isotropic Grid
```julia
# Generate a standard Chebyshev grid
n_dims = 2
grid_size = 10
grid = generate_grid(n_dims, grid_size, basis=:chebyshev)

# Convert to matrix format
grid_matrix = reduce(vcat, map(x -> x', reshape(grid, :)))

# Use with MainGenerate
pol = MainGenerate(f, n_dims, grid_matrix, 0.1, 0.99, 1.0, 1.0)
```

### Anisotropic Grid (Limited Support)
```julia
# Generate anisotropic grid
grid_aniso = generate_anisotropic_grid([5, 10], basis=:chebyshev)

# Convert to matrix format
grid_vec = vec(grid_aniso)  # Flatten the array
grid_matrix = convert_to_matrix_grid(grid_vec)

# Note: Currently requires tensor product structure
# See limitations section below
```

## Benefits

1. **Performance**: Skip grid generation when using the same grid for multiple functions
2. **Control**: Use custom grid points for specific applications
3. **Flexibility**: Integrate with external grid generation tools

## Example: Performance Improvement

```julia
# Generate grid once
grid = generate_grid(3, 15, basis=:chebyshev)
grid_matrix = reduce(vcat, map(x -> x', reshape(grid, :)))

# Use for multiple functions
f1 = x -> sin(sum(x))
f2 = x -> exp(-norm(x)^2)
f3 = x -> prod(cos.(π * x))

pol1 = MainGenerate(f1, 3, grid_matrix, 0.1, 0.99, 1.0, 1.0)
pol2 = MainGenerate(f2, 3, grid_matrix, 0.1, 0.99, 1.0, 1.0)
pol3 = MainGenerate(f3, 3, grid_matrix, 0.1, 0.99, 1.0, 1.0)
```

## Current Limitations

### Tensor Product Requirement

The current implementation requires grids to maintain a tensor product structure. This means:
- All unique x-coordinates must pair with all unique y-coordinates (and z-coordinates in 3D)
- True anisotropic grids with different node distributions per dimension are not yet supported

### Degree Inference

When providing a grid, MainGenerate infers the polynomial degree as:
```julia
degree = round(Int, n_points^(1/n_dims)) - 1
```

This assumes a roughly uniform distribution of points.

## Grid Format Requirements

1. **Type**: Must be `Matrix{Float64}`
2. **Shape**: Each row is a point, columns are coordinates
3. **Range**: Points should be in [-1, 1] for Chebyshev/Legendre bases
4. **Structure**: Must form a tensor product (for now)

## Conversion Utilities

```julia
# Convert from Vector{SVector} to Matrix
grid_matrix = convert_to_matrix_grid(grid_vector)

# Convert from Matrix to Vector{SVector}
grid_vector = convert_to_svector_grid(grid_matrix)

# Validate grid before use
validate_grid(grid_matrix, n_dims, basis=:chebyshev)
```

## Best Practices

1. **Validation**: Always validate custom grids before use
2. **Basis Consistency**: Ensure grid points match the intended basis (Chebyshev/Legendre)
3. **Reuse**: Generate grids once and reuse for multiple functions
4. **Size**: Balance grid size with polynomial degree for optimal results

## Future Enhancements

- Full support for anisotropic grids with different nodes per dimension
- Automatic degree optimization based on grid structure
- Support for sparse and adaptive grids
- Integration with external mesh generators

## See Also

- [Anisotropic Grids Documentation](../anisotropic_grids.md)
- [MainGenerate API Reference](../api/main_generate.md)
- [Grid Generation Functions](../api/grid_generation.md)