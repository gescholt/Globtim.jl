# Phase 2 API Documentation

## Core Functions

### `compute_hessians(f::Function, points::Matrix{Float64})::Vector{Matrix{Float64}}`

Compute Hessian matrices at specified points using ForwardDiff automatic differentiation.

**Arguments:**
- `f`: Objective function to analyze
- `points`: Matrix where each row is a point (n_points × n_dims)

**Returns:**
- `Vector{Matrix{Float64}}`: Hessian matrix for each point

**Example:**
```julia
points = [1.0 2.0; 3.0 4.0]  # 2 points in 2D
hessians = compute_hessians(f, points)
# Returns vector of 2×2 Hessian matrices
```

### `classify_critical_points(hessians::Vector{Matrix{Float64}}; kwargs...)::Vector{Symbol}`

Classify critical points based on Hessian eigenvalue structure.

**Arguments:**
- `hessians`: Vector of Hessian matrices
- `tol_zero=1e-8`: Tolerance for zero eigenvalues (degeneracy detection)
- `tol_pos=1e-8`: Tolerance for positive eigenvalues
- `tol_neg=1e-8`: Tolerance for negative eigenvalues

**Returns:**
- `Vector{Symbol}`: Classification for each point
  - `:minimum`: All eigenvalues positive
  - `:maximum`: All eigenvalues negative
  - `:saddle`: Mixed positive/negative eigenvalues
  - `:degenerate`: At least one eigenvalue ≈ 0
  - `:error`: Computation failed

**Example:**
```julia
classifications = classify_critical_points(hessians)
# Returns [:minimum, :saddle, :maximum, ...]
```

### `store_all_eigenvalues(hessians::Vector{Matrix{Float64}})::Vector{Vector{Float64}}`

Store all eigenvalues for each Hessian matrix for detailed analysis.

**Returns:**
- `Vector{Vector{Float64}}`: All eigenvalues for each Hessian matrix (sorted)

**Example:**
```julia
all_eigenvalues = store_all_eigenvalues(hessians)
# Returns [[-2.1, 1.3], [0.5, 2.7], ...] for 2D case
```

### `extract_critical_eigenvalues(classifications, all_eigenvalues)`

Extract critical eigenvalues for minima and maxima classification.

**Arguments:**
- `classifications::Vector{Symbol}`: Point classifications
- `all_eigenvalues::Vector{Vector{Float64}}`: All eigenvalue vectors

**Returns:**
- `Tuple{Vector{Float64}, Vector{Float64}}`: 
  - `smallest_positive_eigenvals`: For minima (smallest positive eigenvalue)
  - `largest_negative_eigenvals`: For maxima (largest negative eigenvalue)

**Example:**
```julia
smallest_pos, largest_neg = extract_critical_eigenvalues(classifications, all_eigenvalues)
# Returns (NaN for non-minima, smallest positive for minima), 
#         (largest negative for maxima, NaN for non-maxima)
```

### `compute_hessian_norms(hessians::Vector{Matrix{Float64}})::Vector{Float64}`

Compute L2 (Frobenius) norm of each Hessian matrix.

**Returns:**
- `Vector{Float64}`: ||H||_F for each Hessian matrix

**Mathematical Definition:**
||H||_F = √(Σᵢⱼ |Hᵢⱼ|²)

**Example:**
```julia
norms = compute_hessian_norms(hessians)
# Returns [4.2, 3.1, 5.7, ...] - scalar norm for each matrix
```

### `compute_eigenvalue_stats(hessians::Vector{Matrix{Float64}})::DataFrame`

Compute detailed eigenvalue statistics for each Hessian matrix.

**Returns:**
DataFrame with columns:
- `eigenvalue_min`: Smallest eigenvalue
- `eigenvalue_max`: Largest eigenvalue  
- `condition_number`: κ(H) = |λₘₐₓ|/|λₘᵢₙ|
- `determinant`: det(H)
- `trace`: tr(H)

**Example:**
```julia
stats = compute_eigenvalue_stats(hessians)
# Returns DataFrame with numerical properties of each Hessian
```

## Visualization Functions

### `plot_hessian_norms(df::DataFrame; backend=:cairo)`

Create scatter plot of Hessian L2 norms, colored by critical point classification.

**Arguments:**
- `df`: DataFrame with `hessian_norm` column
- `backend`: `:cairo` (static) or `:gl` (interactive)

**Returns:**
- `Figure`: Makie figure object

### `plot_condition_numbers(df::DataFrame; backend=:cairo)`

Create log-scale scatter plot of Hessian condition numbers.

**Arguments:**
- `df`: DataFrame with `hessian_condition_number` column
- `backend`: `:cairo` (static) or `:gl` (interactive)

**Returns:**
- `Figure`: Makie figure object

### `plot_critical_eigenvalues(df::DataFrame; backend=:cairo)`

Create dual plot showing critical eigenvalues for minima and maxima.

**Arguments:**
- `df`: DataFrame with `smallest_positive_eigenval` and `largest_negative_eigenval` columns
- `backend`: `:cairo` (static) or `:gl` (interactive)

**Returns:**
- `Figure`: Makie figure with two subplots

## Error Handling

All functions include robust error handling:

- **NaN matrices**: Returned when Hessian computation fails
- **Singular matrices**: Handled gracefully in eigenvalue computation
- **Numerical instability**: Detected via condition number analysis
- **Invalid inputs**: Proper error messages and fallback values

## Type Stability

All functions are designed for type stability:
- Consistent return types
- Proper type annotations
- Minimal allocations in hot paths
- StaticArrays compatibility for small dimensions

## Performance Considerations

- **Memory usage**: O(n²) per point for Hessian storage
- **Computation cost**: O(n²) per point for Hessian, O(n³) for eigenvalues
- **Batch processing**: Vectorized operations where possible
- **Caching**: Consider storing eigenvalues separately for large datasets