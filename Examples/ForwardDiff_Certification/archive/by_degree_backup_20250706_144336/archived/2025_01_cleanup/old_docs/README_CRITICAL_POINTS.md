# Critical Point Processing in ForwardDiff Certification Examples

## Important Notes on Critical Point Extraction

### 1. DataFrame Column Names
The `process_crit_pts` function returns a DataFrame with the following columns:
- `x1, x2, ..., xn`: Coordinates of critical points (in actual domain coordinates)
- `z`: Function value at each critical point

**Common Mistake**: The function value column is named `:z`, NOT `:function_value`.

```julia
# WRONG
println("Function value: ", row.function_value)  # Will error!

# CORRECT
println("Function value: ", row.z)
```

### 2. Coordinate Systems and Transformations

Critical points undergo the following transformation pipeline:

1. **Polynomial Solver Output**: Points in normalized domain [-1,1]^n
2. **process_crit_pts Filtering**: Filters to keep points within [-1,1]^n
3. **Coordinate Transformation**: Transforms to actual domain using:
   ```
   actual_point = TR.sample_range * normalized_point + TR.center
   ```

Example for subdomain with center=[0.5, -0.5, 0.5, -0.5] and range=0.3:
- Normalized point (0,0,0,0) → Actual point (0.5, -0.5, 0.5, -0.5)
- Normalized point (1,1,1,1) → Actual point (0.8, -0.2, 0.8, -0.2)

### 3. Critical Point Extraction Pattern

```julia
# Standard pattern for extracting critical points
df_crit = process_crit_pts(
    solve_polynomial_system(x, dim, degree, pol.coeffs),
    function_to_evaluate,
    TR  # test_input with center and sample_range
)

# Extract points from DataFrame
for row in eachrow(df_crit)
    pt = [row[Symbol("x$i")] for i in 1:dim]  # Points in actual coordinates
    fval = row.z                               # Function value
    # Process point...
end
```

### 4. Subdomain Analysis

When checking if points belong to a subdomain:
- Points from `process_crit_pts` are already in actual coordinates
- Use `is_point_in_subdomain(pt, subdomain)` directly
- No additional coordinate transformation needed

### 5. Common Pitfalls to Avoid

1. **Don't assume normalized coordinates**: Points from `process_crit_pts` are already transformed
2. **Use correct column names**: `:z` for function values, not `:function_value`
3. **Handle tuple degrees**: `pol.degree` might be a tuple like `(:one_d_for_all, 4)`
   ```julia
   actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
   ```

### 6. Verification Example

To verify critical point extraction for a specific subdomain:

```julia
# Get critical points
df_crit = process_crit_pts(
    solve_polynomial_system(x, 4, actual_degree, pol.coeffs),
    deuflhard_4d_composite,
    TR
)

# Count points in subdomain
subdomain_points = []
for row in eachrow(df_crit)
    pt = [row[Symbol("x$i")] for i in 1:4]
    if is_point_in_subdomain(pt, subdomain)
        push!(subdomain_points, pt)
    end
end

println("Found $(length(subdomain_points)) points in subdomain $(subdomain.label)")
```

## Binary Subdomain Labeling

The (+,-,+,-) orthant is divided into 16 subdomains with binary labels:
- Full orthant: [-0.1,1.1] × [-1.1,0.1] × [-0.1,1.1] × [-1.1,0.1]
- Binary labels: 0000 to 1111
- In each dimension: 0 = lower half, 1 = upper half

Example: Subdomain "1010" means:
- Dimension 1: upper half of [-0.1,1.1] → [0.5,1.1]
- Dimension 2: lower half of [-1.1,0.1] → [-1.1,-0.5]
- Dimension 3: upper half of [-0.1,1.1] → [0.5,1.1]
- Dimension 4: lower half of [-1.1,0.1] → [-1.1,-0.5]

## Distribution Table Interpretation

When you see output like:
```
Binary Label │ Total Points │ Min │ S+S │ S+M │ M+S │ M+M
    1010     │     16      │  9  │  1  │  3  │  3  │  9
```

This means subdomain "1010" contains:
- 16 total critical points (out of 25 theoretical points)
- 9 minimizers (min+min type)
- Various other critical point types

The "16" is the count of points, NOT related to the 16 total subdomains.