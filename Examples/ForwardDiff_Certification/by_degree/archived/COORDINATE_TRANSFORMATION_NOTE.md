# Important Note on Coordinate Transformations in Globtim

## Overview
When using Globtim with subdomains, it's crucial to understand the coordinate transformation between the normalized polynomial space and the actual domain space.

## Coordinate Systems

### 1. Normalized Space: [-1,1]^n
- The polynomial approximation is constructed in this space
- `solve_polynomial_system` returns critical points in this space
- All polynomial operations occur in this normalized domain

### 2. Actual Domain Space
- Defined by `center` and `sample_range` in the `test_input` structure
- The actual domain is: `[center - sample_range, center + sample_range]` in each dimension
- Theoretical points and function evaluations use this space

## Transformation Formula
```julia
actual_point = sample_range * normalized_point + center
```

Where:
- `normalized_point` ∈ [-1,1]^n (from polynomial solver)
- `actual_point` is in the real domain coordinates
- `sample_range` can be scalar or vector (per-dimension scaling)

## Critical Implementation Details

### When constructing the approximant:
```julia
TR = test_input(
    objective_function,
    dim = 4,
    center = subdomain.center,      # e.g., [0.25, -0.5, 0.25, -0.5]
    sample_range = subdomain.range,  # e.g., 0.3
    ...
)
```

### After solving for critical points:
```julia
# Critical points are in [-1,1]^n space
crit_pts_normalized = solve_polynomial_system(x, n, degree, coeffs)

# Must transform to actual coordinates
crit_pts_actual = [sample_range .* pt .+ center for pt in crit_pts_normalized]

# Then check if in subdomain
crit_pts_in_subdomain = filter(pt -> is_in_subdomain(pt, subdomain), crit_pts_actual)
```

## Common Pitfalls

1. **Forgetting the transformation**: Directly using normalized critical points for distance calculations or subdomain checks will give incorrect results.

2. **Inconsistent coordinate systems**: Mixing normalized and actual coordinates when computing distances to theoretical points.

3. **Domain filtering**: The `process_crit_pts` function in Globtim automatically filters to [-1,1]^n and transforms points, but manual processing requires explicit transformation.

## Verification
To verify correct implementation:
1. Check that critical points after transformation fall within expected subdomain bounds
2. Distances to theoretical points should decrease with increasing polynomial degree
3. The number of recovered critical points should be consistent with theoretical expectations