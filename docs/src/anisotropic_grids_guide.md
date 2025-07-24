# Anisotropic Grids User Guide

## Introduction

Anisotropic grids allow you to use different numbers of quadrature points in each dimension, enabling more efficient approximation of functions that vary at different rates along different axes. This guide explains how to use anisotropic grids in Globtim.

## Why Use Anisotropic Grids?

Consider approximating a function like `f(x,y) = exp(-100x² - y²)`. This function:
- Changes rapidly in the x-direction (due to the factor 100)
- Changes slowly in the y-direction

Using an isotropic grid wastes computational resources by placing unnecessary points in the y-direction. An anisotropic grid can achieve the same accuracy with fewer total points by allocating more points where the function varies rapidly.

## Basic Usage

### Generating Anisotropic Grids

```julia
using Globtim

# Create a 2D anisotropic grid with 20 points in x, 10 in y
grid = generate_anisotropic_grid([19, 9], basis=:chebyshev)
# Results in a 20×10 grid (input n gives n+1 points)

# 3D anisotropic grid
grid_3d = generate_anisotropic_grid([30, 20, 10], basis=:legendre)
# Results in a 31×21×11 grid

# High-dimensional grids work the same way
grid_5d = generate_anisotropic_grid([10, 8, 6, 4, 2], basis=:uniform)
```

### Available Basis Types

- **`:chebyshev`** - Chebyshev nodes (default), cluster at boundaries
- **`:legendre`** - Uniform spacing (Legendre-Gauss-Lobatto nodes)  
- **`:uniform`** - True uniform spacing including endpoints

### Computing L² Norms

Anisotropic grids work seamlessly with both L²-norm computation methods:

```julia
# Define a test function
f = x -> exp(-50*x[1]^2 - 2*x[2]^2)

# Method 1: Quadrature-based (more accurate)
l2_quad = compute_l2_norm_quadrature(f, [40, 15], :chebyshev)

# Method 2: Riemann sum (works with pre-generated grids)
grid = generate_anisotropic_grid([40, 15], basis=:chebyshev)
l2_riemann = discrete_l2_norm_riemann(f, grid)
```

## Practical Examples

### Example 1: Multiscale Function

```julia
# Function with different scales
f_multiscale = x -> sin(20*x[1]) * exp(-x[2]^2)

# Poor choice: isotropic grid
l2_iso = compute_l2_norm_quadrature(f_multiscale, [25, 25], :chebyshev)
# Uses 26×26 = 676 points

# Better choice: anisotropic grid
l2_aniso = compute_l2_norm_quadrature(f_multiscale, [40, 15], :chebyshev)
# Uses 41×16 = 656 points, but more accurate!
```

### Example 2: Choosing Grid Sizes

```julia
# Function that varies as exp(-a₁x₁² - a₂x₂² - ... - aₙxₙ²)
# Rule of thumb: grid_size[i] ∝ √(a[i])

# For f(x,y,z) = exp(-100x² - 25y² - 4z²)
# Relative scales: √100:√25:√4 = 10:5:2
grid_sizes = [40, 20, 8]  # Proportional allocation

l2 = compute_l2_norm_quadrature(
    x -> exp(-100*x[1]^2 - 25*x[2]^2 - 4*x[3]^2),
    grid_sizes,
    :chebyshev
)
```

### Example 3: Performance Comparison

```julia
using BenchmarkTools

f = x -> exp(-50*x[1]^2 - 2*x[2]^2)

# Reference value
l2_ref = compute_l2_norm_quadrature(f, [200, 200], :chebyshev)

# Compare different strategies
configs = [
    ([30, 30], "Isotropic 30×30"),
    ([50, 18], "Anisotropic 50×18"),
    ([60, 15], "Anisotropic 60×15")
]

for (grid_size, name) in configs
    l2 = compute_l2_norm_quadrature(f, grid_size, :chebyshev)
    error = abs(l2 - l2_ref)
    total = prod(grid_size .+ 1)
    println("$name ($total points): error = $error")
end
```

## Utility Functions

### Checking Grid Properties

```julia
# Get dimensions of an existing grid
grid = generate_anisotropic_grid([10, 20, 30])
dims = get_grid_dimensions(grid)  # Returns [11, 21, 31]

# Check if a grid is anisotropic
is_aniso = is_anisotropic(grid)  # Returns true
```

### Backward Compatibility

The old isotropic interface still works:

```julia
# Old way (isotropic)
grid_iso = generate_grid(2, 20, basis=:chebyshev)  # 2D, 21×21 grid

# Equivalent anisotropic call
grid_aniso = generate_anisotropic_grid([20, 20], basis=:chebyshev)

# These produce identical grids
@assert grid_iso == grid_aniso
```

## Best Practices

1. **Analyze your function first**: Understand where it varies rapidly
   ```julia
   # Quick visual check in 2D
   f = x -> your_function(x)
   x = range(-1, 1, 100)
   y = range(-1, 1, 100)
   z = [f([xi, yi]) for xi in x, yi in y]
   heatmap(x, y, z)  # Look for directional variation
   ```

2. **Start with moderate anisotropy**: Begin with ratios like 2:1 or 3:1
   ```julia
   # Conservative start
   grid_sizes = [30, 15]  # 2:1 ratio
   
   # More aggressive if function supports it
   grid_sizes = [50, 10]  # 5:1 ratio
   ```

3. **Validate your choice**: Compare with high-resolution reference
   ```julia
   l2_ref = compute_l2_norm_quadrature(f, [100, 100], :chebyshev)
   l2_test = compute_l2_norm_quadrature(f, your_grid_sizes, :chebyshev)
   rel_error = abs(l2_test - l2_ref) / l2_ref
   println("Relative error: $(rel_error * 100)%")
   ```

4. **Consider total point budget**: Anisotropic grids shine when points are limited
   ```julia
   total_points = 1000
   # Isotropic: ~31×31
   # Anisotropic options: 50×19, 40×24, 60×16, etc.
   ```

## Advanced Topics

### Adaptive Grid Selection

For automatic grid size selection based on function behavior:

```julia
function estimate_directional_variation(f, n_dims; n_samples=100)
    variations = zeros(n_dims)
    
    for d in 1:n_dims
        # Sample along dimension d
        for _ in 1:n_samples
            x = randn(n_dims) .* 0.5  # Random point
            h = 0.01
            x_plus = copy(x); x_plus[d] += h
            x_minus = copy(x); x_minus[d] -= h
            
            # Finite difference approximation
            deriv = (f(x_plus) - f(x_minus)) / (2h)
            variations[d] += abs(deriv)
        end
    end
    
    return variations / n_samples
end

# Use variations to guide grid sizes
variations = estimate_directional_variation(f, 3)
base_size = 20
grid_sizes = round.(Int, base_size * sqrt.(variations / minimum(variations)))
```

### Integration with Polynomial Approximation

Anisotropic grids can be used with polynomial approximation:

```julia
# Generate anisotropic grid for sampling
grid = generate_anisotropic_grid([40, 20], basis=:chebyshev)

# Convert to matrix format for polynomial fitting
points_matrix = grid_to_matrix(grid)

# Use in polynomial approximation workflow
# ... (see main documentation for polynomial approximation)
```

## Common Pitfalls

1. **Over-anisotropy**: Too extreme ratios can miss features
   ```julia
   # Bad: might miss y-direction features
   grid_sizes = [100, 5]  # 20:1 ratio
   
   # Better: more balanced
   grid_sizes = [50, 10]  # 5:1 ratio
   ```

2. **Wrong direction**: Ensure more points go where function varies more
   ```julia
   # Check your allocation is correct
   f = x -> exp(-10*x[1]^2 - 100*x[2]^2)
   # Here y varies MORE, so need more points in y!
   grid_sizes = [20, 40]  # More in y
   ```

3. **Dimension ordering**: Remember Julia's column-major ordering
   ```julia
   grid = generate_anisotropic_grid([10, 20])
   size(grid)  # Returns (11, 21), not (21, 11)
   ```

## Performance Tips

1. **Reuse grids**: Generate once, use multiple times
   ```julia
   grid = generate_anisotropic_grid([50, 25], basis=:chebyshev)
   l2_f1 = discrete_l2_norm_riemann(f1, grid)
   l2_f2 = discrete_l2_norm_riemann(f2, grid)
   ```

2. **Batch operations**: Process multiple functions together
   ```julia
   functions = [f1, f2, f3, f4]
   grid_spec = [40, 20]
   l2_norms = [compute_l2_norm_quadrature(f, grid_spec, :chebyshev) 
               for f in functions]
   ```

3. **Choose appropriate basis**: 
   - Chebyshev: Best for smooth functions
   - Uniform: Simple, predictable
   - Legendre: Good general choice

## Summary

Anisotropic grids provide a powerful tool for efficient function approximation when functions have different scales in different directions. Key benefits:

- **Efficiency**: Same accuracy with fewer points
- **Flexibility**: Adapt to function behavior
- **Simplicity**: Easy to use with existing tools
- **Scalability**: Works in any dimension

Start with moderate anisotropy ratios and validate against high-resolution references to ensure accuracy.