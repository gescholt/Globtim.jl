# Anisotropic Grid Support in Globtim

## Overview

Globtim now supports true anisotropic grids through an enhanced `lambda_vandermonde` implementation. This allows polynomial approximation on grids with different Chebyshev or Legendre nodes per dimension, enabling more efficient approximation of functions with different length scales in different directions.

## Key Features

### Automatic Detection
The system automatically detects whether a grid is anisotropic and uses the appropriate algorithm:
- **Isotropic grids**: Use the original optimized implementation
- **Anisotropic grids**: Use the new dimension-wise algorithm

### Full Integration
Anisotropic support is seamlessly integrated into:
- `MainGenerate`: Accepts anisotropic grids via Matrix{Float64} input
- `Constructor`: New `grid` parameter for pre-generated grids
- `lambda_vandermonde`: Enhanced wrapper with automatic routing

## Usage Examples

### Basic Usage with MainGenerate

```julia
using Globtim

# Function with different scales in x and y
f = x -> exp(-100*x[1]^2 - x[2]^2)

# Create anisotropic grid: more points in x where function varies rapidly
grid = generate_anisotropic_grid([20, 8], basis=:chebyshev)
grid_matrix = convert_to_matrix_grid(vec(grid))

# Use with MainGenerate
pol = MainGenerate(f, 2, grid_matrix, 0.1, 0.99, 1.0, 1.0)
println("Approximation error: ", pol.nrm)
```

### Using Constructor with Anisotropic Grids

```julia
# Create test input
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)

# Traditional usage (isotropic)
pol_iso = Constructor(TR, 10)

# Anisotropic grid usage
grid_aniso = generate_anisotropic_grid([15, 6], basis=:chebyshev)
grid_matrix = convert_to_matrix_grid(vec(grid_aniso))
pol_aniso = Constructor(TR, 0, grid=grid_matrix)  # degree ignored when grid provided

println("Isotropic error: ", pol_iso.nrm)
println("Anisotropic error: ", pol_aniso.nrm)
```

### Grid Analysis Tools

```julia
# Analyze grid structure
grid = generate_anisotropic_grid([10, 5, 3], basis=:legendre)
grid_matrix = convert_to_matrix_grid(vec(grid))

# Check if anisotropic
@show is_grid_anisotropic(grid_matrix)  # true

# Detailed analysis
info = analyze_grid_structure(grid_matrix)
println("Unique points per dimension: ", [length(pts) for pts in info.unique_points_per_dim])
println("Maintains tensor product: ", info.is_tensor_product)
```

## When to Use Anisotropic Grids

Anisotropic grids are beneficial when:
1. **Function has different length scales**: e.g., `exp(-100*x^2 - y^2)`
2. **Domain is rectangular with different aspect ratios**
3. **Known directional behavior**: e.g., boundary layers in PDEs
4. **Optimization problems**: Different parameter sensitivities

## Performance Considerations

### Benefits
- **Efficiency**: Fewer total points for same accuracy
- **Flexibility**: Adapt grid to function behavior
- **Memory**: Reduced storage for suitable problems

### Trade-offs
- **Setup cost**: Grid analysis adds overhead
- **Best for tensor products**: Non-tensor grids have limitations
- **Conditioning**: May vary compared to isotropic grids

## Implementation Details

### Grid Structure Requirements
1. **Matrix format**: Each row is a point in n-dimensional space
2. **Tensor product preferred**: Best performance and compatibility
3. **Node ordering**: Automatic detection and indexing

### Type Support
The implementation maintains type stability for:
- `Float64`, `Float32`: Standard floating point
- `Rational{Int}`: Exact rational arithmetic
- `BigFloat`: Arbitrary precision

### Algorithm Selection
```julia
# Force anisotropic algorithm (useful for testing)
V = lambda_vandermonde(Lambda, S, force_anisotropic=true)

# Automatic selection (default)
V = lambda_vandermonde(Lambda, S)  # Detects grid type
```

## Best Practices

1. **Grid Generation**
   ```julia
   # Match grid to function behavior
   # More points where function varies rapidly
   grid = generate_anisotropic_grid([30, 10], basis=:chebyshev)
   ```

2. **Validation**
   ```julia
   # Always validate custom grids
   validate_grid(grid_matrix, n_dims, basis=:chebyshev)
   ```

3. **Performance Testing**
   ```julia
   # Compare isotropic vs anisotropic
   t_iso = @elapsed pol_iso = Constructor(TR, 10)
   t_aniso = @elapsed pol_aniso = Constructor(TR, 0, grid=grid_matrix)
   ```

## Limitations

### Current Limitations
1. **Degree inference**: Based on total points, may not be optimal
2. **Mixed bases**: Cannot use Chebyshev in x, Legendre in y (yet)
3. **Scattered grids**: Best results with tensor product structure

### Future Enhancements
- Per-dimension basis selection
- Adaptive degree inference
- Full scattered grid support

## Examples for Specific Applications

### Example 1: Gaussian with Different Scales
```julia
# Function: exp(-a*x^2 - b*y^2) with a >> b
f = x -> exp(-50*x[1]^2 - 2*x[2]^2)

# Anisotropic grid matches function
grid = generate_anisotropic_grid([15, 7], basis=:chebyshev)
```

### Example 2: Boundary Layer Problem
```julia
# Sharp variation near x=0
f = x -> tanh(100*x[1]) + sin(π*x[2])

# More points near x=0
# (Custom grid generation needed for non-uniform spacing)
```

### Example 3: Multi-scale Optimization
```julia
# Rosenbrock-like with different scales
f = x -> (1 - x[1])^2 + 100*(x[2] - x[1]^2)^2

# More resolution in y-direction
grid = generate_anisotropic_grid([10, 20], basis=:chebyshev)
```

## API Reference

### Core Functions
- `lambda_vandermonde_anisotropic`: Anisotropic Vandermonde construction
- `is_grid_anisotropic`: Check if grid has different nodes per dimension
- `analyze_grid_structure`: Detailed grid analysis
- `AnisotropicGridInfo`: Structure storing grid information

### Integration Points
- `MainGenerate(..., grid::Matrix{Float64}, ...)`: Direct grid input
- `Constructor(..., grid=grid_matrix)`: Grid parameter
- `lambda_vandermonde(..., force_anisotropic=true)`: Algorithm control

## See Also
- [Grid-Based MainGenerate Guide](grid_based_maingen.md)
- [Anisotropic Grids Documentation](../anisotropic_grids.md)
- [Phase 2 Implementation Details](../development/phase2_lambda_vandermonde_breakdown.md)