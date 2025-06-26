# DataFrame Column Reference

This document provides a comprehensive reference for all DataFrame columns produced by Globtim's critical point analysis functions.

## Core Critical Point Columns

These columns are always present in DataFrames returned by `process_crit_pts()`:

### Coordinate Columns
- `x1, x2, ..., xn`: Original critical point coordinates in the domain
- `z`: Function value at the critical point

### Metadata Columns  
- `value`: Function value (same as `z`, maintained for compatibility)
- `captured`: Boolean indicating if point was captured during analysis

## Phase 1 Enhanced Statistics

These columns are added by `analyze_critical_points()` regardless of the `enable_hessian` setting:

### Refined Coordinates
- `y1, y2, ..., yn`: BFGS-refined coordinates (improved precision)

### Optimization Status
- `close`: Boolean indicating if point is close to domain boundary
- `steps`: Number of BFGS optimization steps taken
- `converged`: Boolean indicating if BFGS optimization converged successfully

### Clustering and Proximity
- `region_id`: Spatial cluster identifier for nearby critical points
- `function_value_cluster`: Cluster identifier for points with similar function values
- `nearest_neighbor_dist`: Euclidean distance to nearest neighboring critical point

### Gradient Analysis
- `gradient_norm`: L2 norm of the gradient vector at the critical point

## Phase 2 Hessian Classification

These columns are added when `analyze_critical_points()` is called with `enable_hessian=true`:

### Critical Point Classification
- `critical_point_type`: Mathematical classification of the critical point
  - `:minimum`: All eigenvalues > `hessian_tol_zero` (local minimum)
  - `:maximum`: All eigenvalues < -`hessian_tol_zero` (local maximum)  
  - `:saddle`: Mixed positive and negative eigenvalues (saddle point)
  - `:degenerate`: At least one eigenvalue ≈ 0 (degenerate critical point)
  - `:error`: Hessian computation failed

### Validation Eigenvalues
- `smallest_positive_eigenval`: Smallest positive eigenvalue (for minima validation)
  - Contains actual value for `:minimum` points
  - Contains `NaN` for non-minimum points
- `largest_negative_eigenval`: Largest negative eigenvalue (for maxima validation)
  - Contains actual value for `:maximum` points
  - Contains `NaN` for non-maximum points

### Hessian Matrix Properties
- `hessian_norm`: L2 (Frobenius) norm of the Hessian matrix
  - Mathematical definition: ||H||_F = √(Σᵢⱼ |Hᵢⱼ|²)
  - Always positive, measures "size" of the Hessian
- `hessian_eigenvalue_min`: Smallest eigenvalue of the Hessian matrix
- `hessian_eigenvalue_max`: Largest eigenvalue of the Hessian matrix

### Numerical Stability Metrics
- `hessian_condition_number`: Condition number of the Hessian matrix
  - Mathematical definition: κ(H) = |λₘₐₓ|/|λₘᵢₙ|
  - Higher values indicate numerical instability
  - May be `Inf` for singular matrices
- `hessian_determinant`: Determinant of the Hessian matrix
  - Product of all eigenvalues
  - Sign indicates orientation of critical point
- `hessian_trace`: Trace of the Hessian matrix
  - Sum of all eigenvalues
  - Sum of diagonal elements of Hessian

## Column Usage Examples

### Basic Analysis
```julia
# Proper initialization
using Pkg; using Revise 
Pkg.activate(joinpath(@__DIR__, "../"))  # Adjust path as needed
using Globtim; using DynamicPolynomials, DataFrames

# Check which columns are available
println("Available columns: ", names(df))

# Filter by critical point type
minima_df = df[df.critical_point_type .== :minimum, :]
saddle_df = df[df.critical_point_type .== :saddle, :]
```

### Validation and Quality Assessment
```julia
# Check convergence quality
converged_points = df[df.converged, :]
println("Convergence rate: ", mean(df.converged))

# Analyze numerical stability
unstable_points = df[df.hessian_condition_number .> 1e12, :]
println("Potentially unstable points: ", nrow(unstable_points))
```

### Eigenvalue Analysis
```julia
# Extract valid positive eigenvalues for minima
minima_mask = df.critical_point_type .== :minimum
valid_min_eigenvals = filter(!isnan, df.smallest_positive_eigenval[minima_mask])
println("Minima eigenvalue range: ", extrema(valid_min_eigenvals))

# Extract valid negative eigenvalues for maxima  
maxima_mask = df.critical_point_type .== :maximum
valid_max_eigenvals = filter(!isnan, df.largest_negative_eigenval[maxima_mask])
println("Maxima eigenvalue range: ", extrema(valid_max_eigenvals))
```

### Clustering Analysis
```julia
# Analyze spatial clustering
cluster_sizes = combine(groupby(df, :region_id), nrow => :count)
println("Cluster size distribution:")
println(cluster_sizes)

# Find isolated points
isolated_points = df[df.nearest_neighbor_dist .> 0.1, :]
```

## Missing Values and Error Handling

### NaN Values
- **Validation eigenvalues**: `NaN` for inappropriate critical point types
- **Condition numbers**: `NaN` for matrices with zero eigenvalues
- **Failed computations**: `NaN` when numerical computation fails

### Infinite Values
- **Condition numbers**: `Inf` for singular matrices (zero smallest eigenvalue)

### Error Classification
- **`:error` type**: Assigned when Hessian computation completely fails
- **All Phase 2 columns**: Set to `NaN` when classification is `:error`

## Performance Considerations

### Memory Usage
- **Phase 1 columns**: O(n) additional memory for n critical points
- **Phase 2 columns**: O(n) additional memory (Hessian matrices not stored in DataFrame)

### Computation Cost
- **Phase 1**: O(n×m) where m is dimension
- **Phase 2**: O(n×m²) for Hessian computation, O(n×m³) for eigenvalue decomposition

## Column Evolution

### Version History
- **Phase 1**: Enhanced statistics and clustering (current)
- **Phase 2**: Hessian-based classification and eigenvalue analysis (current)

### Backward Compatibility
All columns from previous versions are maintained. New columns are added without modifying existing column semantics.

## Related Functions

### Column Producers
- `process_crit_pts()`: Produces core columns
- `analyze_critical_points()`: Adds Phase 1 and optionally Phase 2 columns

### Column Consumers
- `plot_hessian_norms()`: Uses `hessian_norm` and `critical_point_type`
- `plot_condition_numbers()`: Uses `hessian_condition_number` and `critical_point_type`
- `plot_critical_eigenvalues()`: Uses validation eigenvalue columns

### Analysis Utilities
- `combine(groupby(df, :critical_point_type), nrow => :count)`: Classification summary
- `filter(!isnan, df.column_name)`: Remove invalid values
- `df[df.converged, :]`: Filter by convergence status