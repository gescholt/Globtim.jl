# Lambda Vandermonde Tensor Product Limitation

## Overview

The current implementation of `lambda_vandermonde` in `ApproxConstruct.jl` has a fundamental limitation: it assumes that the grid has the same unique points in each dimension (tensor product structure).

## The Issue

In `lambda_vandermonde` (line 119 of `ApproxConstruct.jl`):
```julia
# Get unique points (they're the same for each dimension)
unique_points = unique(S[:, 1])
```

This line extracts unique points only from the first dimension and assumes they are the same for all dimensions. This works for tensor product grids but fails for true anisotropic grids where different dimensions have different node distributions.

## Impact

This limitation means that while MainGenerate can now accept grid inputs, these grids must maintain a tensor product structure. True anisotropic grids with different Chebyshev/Legendre nodes per dimension will cause errors.

### Example of Working Grid
```julia
# Tensor product grid - same points in each dimension
n = 5
points = [cos((2i + 1) * π / (2 * n)) for i = 0:n-1]
grid = Matrix{Float64}(undef, n^2, 2)
idx = 1
for i in 1:n, j in 1:n
    grid[idx, 1] = points[i]
    grid[idx, 2] = points[j]
    idx += 1
end
```

### Example of Non-Working Grid
```julia
# True anisotropic grid - different points per dimension
nx, ny = 5, 10
x_points = [cos((2i + 1) * π / (2 * nx)) for i = 0:nx-1]
y_points = [cos((2i + 1) * π / (2 * ny)) for i = 0:ny-1]
# This will fail in lambda_vandermonde
```

## Workarounds

1. **Use tensor product grids**: Even with different numbers of points per dimension, ensure all unique coordinate values appear in all dimensions.

2. **Grid subsampling**: Create a larger tensor product grid and subsample it to approximate anisotropic behavior.

3. **Wait for full implementation**: A proper fix would require rewriting `lambda_vandermonde` to handle different basis nodes per dimension.

## Future Work

To fully support anisotropic grids, the following changes are needed:

1. Modify `lambda_vandermonde` to track unique points per dimension
2. Update the polynomial evaluation logic to handle mixed node types
3. Extend the Lambda support generation for true anisotropic cases
4. Add comprehensive tests for non-tensor-product grids

## Related Issues

- #38: Document lambda_vandermonde tensor product limitation
- #12: Create integration guide for anisotropic grids with polynomial approximation

## References

- `src/ApproxConstruct.jl`: Contains the `lambda_vandermonde` implementation
- `test/test_maingen_grid_functionality.jl`: Tests demonstrating the limitation