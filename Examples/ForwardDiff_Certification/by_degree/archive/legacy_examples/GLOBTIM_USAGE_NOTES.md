# Key Notes on Using Globtim for Subdomain Analysis

## Critical Insights

### 1. Coordinate Systems
- **Polynomial space**: [-1,1]^n (where polynomial approximation occurs)
- **Actual domain**: Defined by `center` and `sample_range` in `test_input`
- **Transformation**: `actual = sample_range * normalized + center`

### 2. Tolerance vs Fixed Grid
```julia
# With fixed grid (GN specified) - NO tolerance adaptation
TR = test_input(..., GN = 16)  # Tolerance ignored, degree stays fixed

# Without fixed grid - Automatic degree adaptation
TR = test_input(..., tolerance = 0.001)  # Degree increases until L²-norm < tolerance
```

### 3. Critical Point Processing
```julia
# Manual approach (requires transformation):
crit_pts_normalized = solve_polynomial_system(...)  # Returns [-1,1]^n points
actual_pts = [range .* pt .+ center for pt in crit_pts_normalized]

# Recommended approach (automatic transformation):
df_crit = process_crit_pts(
    solve_polynomial_system(...),
    objective_function,
    TR
)
# Returns DataFrame with points already in actual domain coordinates
```

### 4. Domain Specification for Subdomains
```julia
# For each subdomain:
TR = test_input(
    objective,
    center = subdomain.center,      # e.g., [0.2, -0.8, 0.2, -0.8]
    sample_range = subdomain.range,  # e.g., 0.3
    ...
)
# This defines domain: [center - range, center + range] in each dimension
```

### 5. L²-norm Interpretation
- Measures approximation error: `||p(x) - f(x)||₂` over the domain
- Computed on a grid of `GN^dim` points
- Lower values = better approximation
- Typical good values: 1e-3 to 1e-6

## Common Pitfalls to Avoid

1. **Mixing coordinate systems**: Always know whether points are in [-1,1]^n or actual domain
2. **Forgetting transformation**: Critical points from `solve_polynomial_system` need transformation
3. **Misunderstanding tolerance**: It only works when GN is not specified
4. **Wrong domain checks**: Ensure subdomain bounds match the coordinate system of points

## Best Practices

1. Use `process_crit_pts` for automatic coordinate handling
2. Set fixed GN for consistent comparisons across degrees
3. Verify recovered points match known theoretical minimizers
4. Check that L²-norm decreases with increasing degree
5. Use subdomain.center and subdomain.range directly in test_input