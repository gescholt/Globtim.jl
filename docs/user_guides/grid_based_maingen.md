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

### Anisotropic Grid (Full Support)
```julia
# Generate anisotropic grid with different points per dimension
grid_aniso = generate_anisotropic_grid([5, 10], basis=:chebyshev)

# Convert to matrix format
grid_vec = vec(grid_aniso)  # Flatten the array
grid_matrix = convert_to_matrix_grid(grid_vec)

# MainGenerate automatically detects anisotropic structure
pol = MainGenerate(f, 2, grid_matrix, 0.1, 0.99, 1.0, 1.0)
# Output: "Detected anisotropic grid structure - using enhanced algorithm"
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

While anisotropic grids are now fully supported through the enhanced `lambda_vandermonde_anisotropic` function, best performance is achieved with tensor product grids where:
- All unique x-coordinates pair with all unique y-coordinates (and z-coordinates in 3D)
- Non-tensor product grids are supported but may have reduced performance

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

## Advanced Features

### Automatic Anisotropic Detection

MainGenerate now automatically detects when a grid has different nodes per dimension and routes to the appropriate Vandermonde construction:

```julia
# The system automatically detects this is anisotropic
grid = [
    -0.8660  -0.5000;  # 3 unique x-values
     0.0000  -0.5000;  # 2 unique y-values
     0.8660  -0.5000;
    -0.8660   0.5000;
     0.0000   0.5000;
     0.8660   0.5000
]
pol = MainGenerate(f, 2, grid, 0.1, 0.99, 1.0, 1.0, verbose=1)
# Output: "Detected anisotropic grid structure - using enhanced algorithm"
```

### Constructor Integration

The Constructor function also supports pre-generated grids:

```julia
# Traditional usage
pol_iso = Constructor(TR, 10)

# With anisotropic grid
grid_aniso = generate_anisotropic_grid([15, 6], basis=:chebyshev)
grid_matrix = convert_to_matrix_grid(vec(grid_aniso))
pol_aniso = Constructor(TR, 0, grid=grid_matrix)  # degree ignored when grid provided
```

## Future Enhancements

- Mixed basis support (e.g., Chebyshev in x, Legendre in y)
- Adaptive degree inference for anisotropic grids
- Support for sparse and adaptive grids
- Integration with external mesh generators

## See Also

- [Anisotropic Lambda Vandermonde Guide](anisotropic_lambda_vandermonde.md)
- [Anisotropic Grids Documentation](../anisotropic_grids.md)
- [MainGenerate API Reference](../api/main_generate.md)
- [Grid Generation Functions](../api/grid_generation.md)
