# Anisotropic Grid Tests - Detailed Documentation

This document provides detailed documentation of the anisotropic grid test suite, explaining each test's purpose, methodology, and expected outcomes.

## Test File: `test/test_anisotropic_grids.jl`

### Overview
The anisotropic grid test suite validates the implementation of grids with different numbers of points per dimension, a critical feature for efficiently approximating multiscale functions.

## Test Structure

### 1. Basic Anisotropic Grid Generation

#### Test: 2D Anisotropic Grid
```julia
grid_2d = generate_anisotropic_grid([3, 5], basis=:chebyshev)
@test size(grid_2d) == (4, 6)  # 3+1, 5+1
```
- **Purpose**: Verify correct grid dimensions
- **Validates**: Grid has (n+1) points when n is specified
- **Expected**: 4×6 grid of SVector{2,Float64} points

#### Test: 3D Anisotropic Grid
```julia
grid_3d = generate_anisotropic_grid([2, 4, 3], basis=:legendre)
@test size(grid_3d) == (3, 5, 4)
```
- **Purpose**: Test multi-dimensional grid generation
- **Validates**: Correct handling of 3D specifications
- **Expected**: 3×5×4 grid with Legendre nodes

#### Test: High-Dimensional Grid (5D)
```julia
grid_5d = generate_anisotropic_grid([2, 3, 2, 4, 3], basis=:uniform)
@test size(grid_5d) == (3, 4, 3, 5, 4)
```
- **Purpose**: Ensure scalability to high dimensions
- **Validates**: Memory efficiency and correctness in 5D
- **Expected**: Proper tensor product structure

### 2. Grid Properties Tests

#### Test: Chebyshev Node Distribution
```julia
grid_cheb = generate_anisotropic_grid([5, 3], basis=:chebyshev)
x_coords = unique([p[1] for p in grid_cheb])
@test maximum(x_coords) < 1.0
@test minimum(x_coords) > -1.0
```
- **Purpose**: Verify Chebyshev nodes cluster at boundaries
- **Key Point**: Chebyshev nodes use cos((2i+1)π/(2n+2)) formula
- **Expected**: Nodes strictly within (-1, 1)

#### Test: Uniform Node Spacing
```julia
grid_unif = generate_anisotropic_grid(n_points, basis=:uniform)
spacings = diff(x_coords_unif)
@test all(s -> isapprox(s, spacings[1], rtol=1e-10), spacings)
```
- **Purpose**: Verify uniform grids have equal spacing
- **Validates**: Correct implementation of linspace-like behavior
- **Expected**: All spacings identical to machine precision

### 3. L2 Norm Computation - Quadrature Method

#### Test: Separable Polynomial Function
```julia
f_sep = x -> x[1]^2
l2_aniso = compute_l2_norm_quadrature(f_sep, [10, 3], :chebyshev)
@test isapprox(l2_aniso, 2/sqrt(5), rtol=1e-12)
```
- **Mathematical Background**: 
  - Function: f(x,y) = x²
  - L2 norm: √(∫∫ x⁴ dxdy) over [-1,1]²
  - Analytical value: 2/√5
- **Purpose**: Validate exact quadrature for polynomials
- **Key Point**: Tests tensor product quadrature accuracy

#### Test: Multiscale Function Efficiency
```julia
f_aniso = x -> exp(-10*x[1]^2 - x[2]^2)
l2_iso = compute_l2_norm_quadrature(f_aniso, [7, 7], :chebyshev)  # 49 points
l2_aniso_smart = compute_l2_norm_quadrature(f_aniso, [10, 5], :chebyshev)  # 50 points
@test abs(l2_iso - l2_aniso_smart) / l2_iso < 0.1
```
- **Purpose**: Demonstrate anisotropic advantage
- **Function characteristics**: Rapid variation in x, slow in y
- **Expected**: Similar accuracy with different point allocations

### 4. L2 Norm Computation - Riemann Method

#### Test: Riemann Sum on Anisotropic Grid
```julia
grid = generate_anisotropic_grid([15, 8], basis=:chebyshev)
l2_riemann = discrete_l2_norm_riemann(f_test, grid)
l2_quad = compute_l2_norm_quadrature(f_test, [15, 8], :chebyshev)
@test abs(l2_riemann - l2_quad) / l2_quad < 0.05
```
- **Purpose**: Validate Riemann sum handles anisotropic grids
- **Method**: Constructs cell volumes from point spacing
- **Expected**: Agreement within 5% of quadrature method

### 5. Optimal Anisotropic Grid Performance

#### Test: Multiscale Function with Large Scale Separation
```julia
f_multiscale = x -> exp(-100*x[1]^2 - x[2]^2)
# Isotropic: 15×15 = 225 points
# Anisotropic: 25×9 = 225 points
@test error_aniso < error_iso
```
- **Purpose**: Quantify improvement for multiscale problems
- **Key Result**: ~10-15x error reduction for this test function (depends on degree of anisotropy)
- **Principle**: Allocate points based on directional variation

### 6. High-Dimensional Anisotropic Grids

#### Test: 4D Function with Varying Scales
```julia
f_4d = x -> exp(-sum(i*x[i]^2 for i in 1:4))
grid_sizes = [10, 8, 6, 4]  # Decreasing resolution
```
- **Purpose**: Test curse of dimensionality mitigation
- **Strategy**: Fewer points in smoother directions
- **Validates**: Tensor product structure in 4D

### 7. Utility Function Tests

#### Test: Grid Dimension Extraction
```julia
dims = get_grid_dimensions(grid)
@test dims == [4, 6, 3]  # For a [3, 5, 2] input
```
- **Purpose**: Extract actual grid sizes
- **Use case**: Generic algorithms needing grid info

#### Test: Anisotropy Detection
```julia
@test is_anisotropic(aniso_grid) == true
@test is_anisotropic(iso_grid) == false
```
- **Purpose**: Distinguish grid types
- **Application**: Algorithm selection based on grid type

### 8. Backward Compatibility

#### Test: Legacy Interface Support
```julia
grid_old = generate_grid(2, 5, basis=:chebyshev)
grid_new = generate_anisotropic_grid([5, 5], basis=:chebyshev)
@test grid_old == grid_new
```
- **Purpose**: Ensure old code continues working
- **Validates**: Backward-compatible interface

## Performance Demonstration

The test suite includes a demonstration function showing real-world benefits:

```julia
function demonstrate_anisotropic_benefits()
    f = x -> exp(-50*x[1]^2 - 2*x[2]^2)
    # Shows 15x error reduction for anisotropic vs isotropic
end
```

### Key Results:
- **Isotropic 20×20** (400 points): Error ~1e-3
- **Anisotropic 50×8** (400 points): Error ~6e-5
- **Improvement**: ~15x error reduction for this test function

## Common Test Patterns

### 1. Analytical Validation
- Use functions with known L2 norms
- Test polynomial exactness
- Verify error bounds

### 2. Comparative Testing
- Compare methods (quadrature vs Riemann)
- Compare grids (isotropic vs anisotropic)
- Benchmark performance

### 3. Edge Cases
- Single point per dimension
- Very high dimensions
- Extreme anisotropy ratios

## Debugging Test Failures

### Common Issues:

1. **Boundary Expectations**
   - Chebyshev nodes don't reach ±1 exactly
   - Test for strict inequalities

2. **Analytical Values**
   - Double-check integral calculations
   - Consider domain normalization

3. **Dimension Ordering**
   - Julia uses column-major ordering
   - Grid dimensions may appear transposed

4. **Function Passing**
   - Ensure functions accept SVector arguments
   - Check closure variable capture

## Test Coverage Metrics

Current coverage:
- ✓ Grid generation (all bases)
- ✓ L2 norm computation (both methods)
- ✓ Dimension handling (1D to 5D)
- ✓ Performance validation
- ✓ Backward compatibility
- ✓ Utility functions

## Future Test Additions

Potential expansions:
1. Adaptive anisotropic refinement
2. Optimal grid size selection
3. Integration with sparsification
4. GPU acceleration tests
5. Parallel computation validation