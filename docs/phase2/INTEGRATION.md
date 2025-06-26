# Phase 2 Integration Guide

## Integration with analyze_critical_points

Phase 2 enhances the existing `analyze_critical_points` function in `src/refine.jl` with Hessian-based classification.

### Integration Architecture

```
analyze_critical_points(f, df, TR)
├── Phase 1: Enhanced Statistics
│   ├── Spatial clustering
│   ├── Function value analysis
│   ├── Gradient computation
│   └── Nearest neighbor analysis
└── Phase 2: Hessian Analysis
    ├── Hessian computation
    ├── Eigenvalue analysis
    ├── Critical point classification
    └── Numerical diagnostics
```

### Modified Function Signature

```julia
function analyze_critical_points(f::Function, df::DataFrame, TR::test_input; 
                                tol_dist=0.025, verbose=false, 
                                enable_hessian=true, hessian_tol_zero=1e-8)
```

**New Parameters:**
- `enable_hessian=true`: Enable/disable Phase 2 Hessian analysis
- `hessian_tol_zero=1e-8`: Tolerance for detecting degenerate critical points

### Integration Implementation

```julia
# === PHASE 2 ENHANCEMENTS: Complete Hessian Analysis ===
if enable_hessian
    if verbose
        println("\n=== Computing Complete Hessian Analysis ===")
    end
    
    # 1. Compute Hessian matrices at critical points
    if verbose
        println("Computing Hessian matrices...")
    end
    points_matrix = Matrix{Float64}(undef, nrow(df), n_dims)
    for i = 1:n_dims
        points_matrix[:, i] = df[!, Symbol("x$i")]
    end
    hessians = compute_hessians(f, points_matrix)
    
    # 2. Store all eigenvalues
    if verbose
        println("Computing all eigenvalues...")
    end
    all_eigenvalues = store_all_eigenvalues(hessians)
    
    # 3. Classify critical points
    if verbose
        println("Classifying critical points...")
    end
    classifications = classify_critical_points(hessians, tol_zero=hessian_tol_zero)
    df[!, :critical_point_type] = classifications
    
    # 4. Extract critical eigenvalues for minima/maxima
    if verbose
        println("Extracting critical eigenvalues...")
    end
    smallest_pos_eigenvals, largest_neg_eigenvals = extract_critical_eigenvalues(classifications, all_eigenvalues)
    df[!, :smallest_positive_eigenval] = smallest_pos_eigenvals
    df[!, :largest_negative_eigenval] = largest_neg_eigenvals
    
    # 5. Compute Hessian norms
    if verbose
        println("Computing Hessian norms...")
    end
    hessian_norms = compute_hessian_norms(hessians)
    df[!, :hessian_norm] = hessian_norms
    
    # 6. Compute standard eigenvalue statistics
    if verbose
        println("Computing eigenvalue statistics...")
    end
    eigenvalue_stats = compute_eigenvalue_stats(hessians)
    for col in names(eigenvalue_stats)
        df[!, Symbol("hessian_$col")] = eigenvalue_stats[!, col]
    end
    
    # 7. Store all eigenvalues as metadata (for advanced analysis)
    df_metadata = Dict("all_eigenvalues" => all_eigenvalues)
    
    # 8. Hessian analysis for minimizers (if any)
    if nrow(df_min) > 0
        if verbose
            println("Computing Hessian analysis for minimizers...")
        end
        min_points = Matrix{Float64}(undef, nrow(df_min), n_dims)
        for i = 1:n_dims
            min_points[:, i] = df_min[!, Symbol("x$i")]
        end
        min_hessians = compute_hessians(f, min_points)
        min_all_eigenvalues = store_all_eigenvalues(min_hessians)
        min_classifications = classify_critical_points(min_hessians, tol_zero=hessian_tol_zero)
        min_smallest_pos, min_largest_neg = extract_critical_eigenvalues(min_classifications, min_all_eigenvalues)
        min_hessian_norms = compute_hessian_norms(min_hessians)
        min_eigenvalue_stats = compute_eigenvalue_stats(min_hessians)
        
        df_min[!, :critical_point_type] = min_classifications
        df_min[!, :smallest_positive_eigenval] = min_smallest_pos
        df_min[!, :largest_negative_eigenval] = min_largest_neg
        df_min[!, :hessian_norm] = min_hessian_norms
        for col in names(min_eigenvalue_stats)
            df_min[!, Symbol("hessian_$col")] = min_eigenvalue_stats[!, col]
        end
    end
    
    if verbose
        println("Phase 2 Hessian analysis complete!")
    end
end
```

### Column Additions

Phase 2 adds the following columns to the enhanced DataFrame:

#### Core Classification
- `critical_point_type::Symbol`: :minimum, :maximum, :saddle, :degenerate, :error

#### Specialized Eigenvalues
- `smallest_positive_eigenval::Float64`: Smallest positive eigenvalue (for minima validation)
- `largest_negative_eigenval::Float64`: Largest negative eigenvalue (for maxima validation)

#### Hessian Properties
- `hessian_norm::Float64`: L2 (Frobenius) norm of Hessian matrix
- `hessian_eigenvalue_min::Float64`: Smallest eigenvalue
- `hessian_eigenvalue_max::Float64`: Largest eigenvalue
- `hessian_condition_number::Float64`: Condition number κ(H)
- `hessian_determinant::Float64`: Determinant det(H)
- `hessian_trace::Float64`: Trace tr(H)

#### Metadata
- `all_eigenvalues`: Complete eigenvalue vectors (stored in metadata dict)

### Backward Compatibility

Phase 2 integration maintains full backward compatibility:

```julia
# Phase 1 only (existing behavior)
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=false)

# Phase 1 + Phase 2 (new default)
df_enhanced, df_min = analyze_critical_points(f, df, TR)  # enable_hessian=true by default
```

### Integration Testing

Test the integration with:

```julia
using Test

@testset "Phase 2 Integration" begin
    f = Rastringin
    TR = test_input(f, dim=2)
    pol = Constructor(TR, 8)
    @polyvar x[1:2]
    real_pts = solve_polynomial_system(x, 2, 8, pol.coeffs)
    df = process_crit_pts(real_pts, f, TR)
    
    # Test Phase 2 enabled
    df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
    @test :critical_point_type in names(df_enhanced)
    @test :hessian_norm in names(df_enhanced)
    
    # Test Phase 2 disabled
    df_phase1, df_min_phase1 = analyze_critical_points(f, df, TR, enable_hessian=false)
    @test !(:critical_point_type in names(df_phase1))
end
```

### Performance Impact

Phase 2 adds computational overhead:
- **Hessian computation**: O(n²) per point
- **Eigenvalue computation**: O(n³) per point
- **Memory usage**: O(n²) per point for Hessian storage

Consider disabling for large-scale problems:
```julia
# For performance-critical applications
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=false)
```

### Error Handling

Phase 2 integration includes robust error handling:
- Graceful fallback when Hessian computation fails
- NaN propagation for invalid eigenvalues
- Proper error classification for degenerate cases

### Migration Guide

To migrate existing code:

1. **No changes required**: Existing calls continue to work
2. **Access new features**: Use new column names in DataFrame
3. **Disable if needed**: Set `enable_hessian=false` for performance
4. **Visualization**: Use new plotting functions on enhanced DataFrame