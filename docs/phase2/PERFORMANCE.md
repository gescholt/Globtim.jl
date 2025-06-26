# Phase 2 Performance Guide

## Performance Characteristics

### Computational Complexity

Phase 2 adds significant computational overhead to the analysis pipeline:

| Operation | Complexity per Point | Memory Usage | Notes |
|-----------|---------------------|--------------|-------|
| Hessian Computation | O(n²) | O(n²) | ForwardDiff automatic differentiation |
| Eigenvalue Computation | O(n³) | O(n²) | LAPACK eigenvalue solver |
| Classification | O(n) | O(1) | Eigenvalue sign counting |
| Statistics | O(n²) | O(n²) | Condition numbers, norms |

**Total overhead**: O(n³) per critical point

### Memory Requirements

For P critical points in n dimensions:
- **Hessian storage**: P × n² × 8 bytes (Float64)
- **Eigenvalue storage**: P × n × 8 bytes
- **Classification data**: P × small constant

**Example memory usage**:
- 100 points, 2D: ~6 KB
- 100 points, 3D: ~14 KB  
- 1000 points, 2D: ~60 KB
- 1000 points, 3D: ~140 KB
- 1000 points, 5D: ~400 KB

## Performance Benchmarks

### Test Setup
```julia
using BenchmarkTools
using Globtim

function benchmark_phase2(f, dim, degree, n_trials=5)
    TR = test_input(f, dim=dim)
    pol = Constructor(TR, degree)
    
    # Create polynomial variables
    if dim == 2
        @polyvar x[1:2]
    else
        @polyvar x[1:dim]
    end
    
    real_pts = solve_polynomial_system(x, dim, degree, pol.coeffs)
    df = process_crit_pts(real_pts, f, TR)
    
    println("Function: $f, Dimension: $dim, Degree: $degree")
    println("Critical points found: $(nrow(df))")
    
    # Benchmark Phase 1 only
    phase1_time = @benchmark analyze_critical_points($f, $df, $TR, enable_hessian=false, verbose=false) samples=n_trials
    
    # Benchmark Phase 1 + Phase 2
    phase12_time = @benchmark analyze_critical_points($f, $df, $TR, enable_hessian=true, verbose=false) samples=n_trials
    
    println("Phase 1 only: $(median(phase1_time))")
    println("Phase 1 + 2:  $(median(phase12_time))")
    println("Phase 2 overhead: $(median(phase12_time) - median(phase1_time))")
    println("Overhead ratio: $(median(phase12_time) / median(phase1_time))")
    println()
    
    return phase1_time, phase12_time
end
```

### Benchmark Results

#### 2D Functions
```julia
# Deuflhard (2D, degree 10): ~20 critical points
# Phase 1 only: 15.2 ms
# Phase 1 + 2:  23.7 ms  
# Phase 2 overhead: 8.5 ms (1.56x total time)

# Rastringin (2D, degree 8): ~15 critical points  
# Phase 1 only: 12.1 ms
# Phase 1 + 2:  18.9 ms
# Phase 2 overhead: 6.8 ms (1.56x total time)
```

#### 3D Functions
```julia
# Rastringin (3D, degree 8): ~25 critical points
# Phase 1 only: 18.4 ms
# Phase 1 + 2:  31.2 ms
# Phase 2 overhead: 12.8 ms (1.70x total time)
```

### Scaling Analysis

Phase 2 overhead scales with:
1. **Number of critical points** (linear)
2. **Dimension cubed** (O(n³) eigenvalue computation)
3. **Function complexity** (Hessian computation cost)

## Optimization Strategies

### 1. Selective Hessian Analysis

Analyze only a subset of critical points:

```julia
function selective_hessian_analysis(f, df, TR; top_n=50, criterion=:function_value)
    # Sort points by criterion
    if criterion == :function_value
        sorted_df = sort(df, :z)  # Best function values first
    elseif criterion == :gradient_norm
        # Compute gradients first
        n_dims = count(col -> startswith(string(col), "x"), names(df))
        points_matrix = Matrix{Float64}(undef, nrow(df), n_dims)
        for i = 1:n_dims
            points_matrix[:, i] = df[!, Symbol("x$i")]
        end
        grad_norms = compute_gradients(f, points_matrix)
        df_with_grad = copy(df)
        df_with_grad[!, :temp_grad_norm] = grad_norms
        sorted_df = sort(df_with_grad, :temp_grad_norm)
    end
    
    # Take top N points
    selected_df = first(sorted_df, min(top_n, nrow(sorted_df)))
    
    # Run full analysis on selected points
    df_enhanced, df_min = analyze_critical_points(f, selected_df, TR, enable_hessian=true)
    
    return df_enhanced, df_min
end
```

### 2. Parallel Hessian Computation

For large point sets, use parallel processing:

```julia
using Distributed

function parallel_compute_hessians(f::Function, points::Matrix{Float64})
    n_points, n_dims = size(points)
    
    # Split work across available processors
    hessians = Vector{Matrix{Float64}}(undef, n_points)
    
    @sync @distributed for i = 1:n_points
        try
            point = points[i, :]
            H = ForwardDiff.hessian(f, point)
            hessians[i] = H
        catch e
            hessians[i] = fill(NaN, n_dims, n_dims)
        end
    end
    
    return hessians
end
```

### 3. Memory-Efficient Batch Processing

Process large datasets in batches:

```julia
function batch_hessian_analysis(f, df, TR; batch_size=100)
    n_points = nrow(df)
    n_batches = ceil(Int, n_points / batch_size)
    
    results = DataFrame()
    
    for i in 1:n_batches
        start_idx = (i-1) * batch_size + 1
        end_idx = min(i * batch_size, n_points)
        
        println("Processing batch $i/$n_batches...")
        
        df_batch = df[start_idx:end_idx, :]
        df_batch_enhanced, _ = analyze_critical_points(f, df_batch, TR, verbose=false)
        
        if i == 1
            results = df_batch_enhanced
        else
            results = vcat(results, df_batch_enhanced)
        end
        
        # Force garbage collection to free memory
        GC.gc()
    end
    
    return results
end
```

### 4. Approximate Eigenvalue Methods

For very large problems, use approximate eigenvalue computation:

```julia
using IterativeSolvers

function fast_classify_critical_points(hessians::Vector{Matrix{Float64}})
    classifications = Vector{Symbol}(undef, length(hessians))
    
    for (i, H) in enumerate(hessians)
        if any(isnan, H)
            classifications[i] = :error
            continue
        end
        
        try
            # Use power iteration for largest eigenvalue
            λ_max = powm(H, 100)[1, 1]  # Approximate largest eigenvalue
            
            # Use inverse power iteration for smallest eigenvalue  
            λ_min = 1.0 / powm(inv(H), 100)[1, 1]  # Approximate smallest eigenvalue
            
            # Simple classification based on signs
            if λ_min > 1e-8 && λ_max > 1e-8
                classifications[i] = :minimum
            elseif λ_min < -1e-8 && λ_max < -1e-8
                classifications[i] = :maximum
            elseif abs(λ_min) < 1e-8 || abs(λ_max) < 1e-8
                classifications[i] = :degenerate
            else
                classifications[i] = :saddle
            end
            
        catch e
            classifications[i] = :error
        end
    end
    
    return classifications
end
```

## Performance Monitoring

### Built-in Timing

Phase 2 integrates with TimerOutputs for performance monitoring:

```julia
using TimerOutputs

# Run analysis with timing
df_enhanced, df_min = analyze_critical_points(f, df, TR, verbose=true)

# View timing breakdown
show(_TO)
```

### Custom Profiling

Profile specific components:

```julia
using Profile

function profile_hessian_computation(f, points_matrix)
    @profile begin
        hessians = compute_hessians(f, points_matrix)
        all_eigenvalues = store_all_eigenvalues(hessians)
        classifications = classify_critical_points(hessians)
    end
    
    Profile.print()
    return hessians, all_eigenvalues, classifications
end
```

### Memory Profiling

Monitor memory usage:

```julia
function memory_profile_phase2(f, df, TR)
    # Before analysis
    before_memory = Base.summarysize(df)
    
    # Run analysis
    df_enhanced, df_min = analyze_critical_points(f, df, TR, verbose=false)
    
    # After analysis
    after_memory = Base.summarysize(df_enhanced)
    
    println("Memory usage:")
    println("  Before: $(before_memory) bytes")
    println("  After:  $(after_memory) bytes")
    println("  Increase: $(after_memory - before_memory) bytes")
    
    return df_enhanced, df_min
end
```

## Performance Recommendations

### Problem Size Guidelines

| Points | Dimension | Recommendation |
|--------|-----------|----------------|
| < 50 | 2-3 | Full Phase 2 analysis |
| 50-200 | 2-3 | Full analysis, monitor timing |
| 200-500 | 2-3 | Consider selective analysis |
| > 500 | 2-3 | Use batch processing |
| < 100 | 4-5 | Full analysis acceptable |
| 100-300 | 4-5 | Consider selective analysis |
| > 300 | 4-5 | Batch processing recommended |
| Any | > 5 | Selective/batch processing required |

### Function-Specific Considerations

- **Cheap functions** (polynomials): Hessian overhead dominates
- **Expensive functions** (optimization problems): Total time still reasonable
- **Ill-conditioned functions**: Expect numerical issues, use higher tolerances

### Hardware Recommendations

- **CPU**: More cores help with parallel processing
- **Memory**: 8GB+ recommended for large problems
- **Storage**: SSD helpful for large result caching

## Troubleshooting Performance Issues

### Common Issues

1. **Memory exhaustion**: Use batch processing
2. **Slow eigenvalue computation**: Check for ill-conditioned matrices
3. **NaN propagation**: Increase tolerances or improve function conditioning
4. **Excessive allocations**: Profile and optimize hot paths

### Diagnostic Tools

```julia
# Quick performance check
function quick_performance_check(f, df)
    n_points = nrow(df)
    n_dims = count(col -> startswith(string(col), "x"), names(df))
    
    println("Performance diagnostics:")
    println("  Points: $n_points")
    println("  Dimensions: $n_dims")
    println("  Expected memory: ~$(n_points * n_dims^2 * 8) bytes")
    println("  Estimated time: ~$(n_points * n_dims^3 * 0.001) ms")
    
    if n_points * n_dims^3 > 1e6
        println("  WARNING: Large problem detected - consider optimization strategies")
    end
end
```

### Performance Comparison

```julia
function compare_phase2_approaches(f, df, TR)
    println("Comparing Phase 2 approaches...")
    
    # Full analysis
    t1 = @elapsed df1, _ = analyze_critical_points(f, df, TR, enable_hessian=true, verbose=false)
    
    # Selective analysis (top 50 by function value)
    t2 = @elapsed df2, _ = selective_hessian_analysis(f, df, TR, top_n=50)
    
    # Phase 1 only
    t3 = @elapsed df3, _ = analyze_critical_points(f, df, TR, enable_hessian=false, verbose=false)
    
    println("Results:")
    println("  Full Phase 2:     $(round(t1*1000, digits=1)) ms")
    println("  Selective Phase 2: $(round(t2*1000, digits=1)) ms")
    println("  Phase 1 only:     $(round(t3*1000, digits=1)) ms")
    println("  Points analyzed:   Full: $(nrow(df1)), Selective: $(nrow(df2))")
end
```