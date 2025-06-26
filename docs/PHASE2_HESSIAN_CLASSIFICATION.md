# Phase 2: Hessian-Based Critical Point Classification

## Overview
Phase 2 extends the enhanced statistics (Phase 1) by computing Hessian matrices at each critical point using ForwardDiff.jl and classifying critical points based on the eigenvalue structure of the Hessian.

## Mathematical Background

### Critical Point Classification via Hessian Analysis
For a function f: ℝⁿ → ℝ, at a critical point x* where ∇f(x*) = 0, the Hessian matrix H = ∇²f(x*) determines the local behavior:

- **Local Minimum**: H is positive definite (all eigenvalues > 0)
- **Local Maximum**: H is negative definite (all eigenvalues < 0)  
- **Saddle Point**: H is indefinite (mixed positive/negative eigenvalues)
- **Degenerate**: H is singular (at least one eigenvalue = 0)

### Eigenvalue-Based Classification
```julia
eigenvals = eigvals(H)
if all(λ -> λ > tol_pos, eigenvals)
    return :minimum
elseif all(λ -> λ < -tol_neg, eigenvals)
    return :maximum
elseif any(λ -> abs(λ) < tol_zero, eigenvals)
    return :degenerate
else
    return :saddle
end
```

## Implementation Plan

### 1. Core Hessian Computation Function
**File**: `src/hessian_analysis.jl` (new file)

```julia
"""
    compute_hessians(f::Function, points::Matrix{Float64})::Vector{Matrix{Float64}}

Compute Hessian matrices at specified points using ForwardDiff automatic differentiation.

# Arguments
- f: Objective function to analyze
- points: Matrix where each row is a point (n_points × n_dims)

# Returns
Vector{Matrix{Float64}}: Hessian matrix for each point
"""
function compute_hessians(f::Function, points::Matrix{Float64})::Vector{Matrix{Float64}}
    n_points, n_dims = size(points)
    hessians = Vector{Matrix{Float64}}(undef, n_points)
    
    for i = 1:n_points
        try
            point = points[i, :]
            H = ForwardDiff.hessian(f, point)
            hessians[i] = H
        catch e
            # Fallback for points where Hessian computation fails
            hessians[i] = fill(NaN, n_dims, n_dims)
        end
    end
    
    return hessians
end
```

### 2. Critical Point Classification Function
```julia
"""
    classify_critical_points(hessians::Vector{Matrix{Float64}}; 
                           tol_zero=1e-8, tol_pos=1e-8, tol_neg=1e-8)::Vector{Symbol}

Classify critical points based on Hessian eigenvalue structure.

# Arguments
- hessians: Vector of Hessian matrices
- tol_zero: Tolerance for zero eigenvalues (degeneracy detection)
- tol_pos: Tolerance for positive eigenvalues
- tol_neg: Tolerance for negative eigenvalues

# Returns
Vector{Symbol}: Classification for each point (:minimum, :maximum, :saddle, :degenerate, :error)
"""
function classify_critical_points(hessians::Vector{Matrix{Float64}}; 
                                tol_zero=1e-8, tol_pos=1e-8, tol_neg=1e-8)::Vector{Symbol}
    n_points = length(hessians)
    classifications = Vector{Symbol}(undef, n_points)
    
    for i = 1:n_points
        H = hessians[i]
        
        # Check for NaN matrices (computation failed)
        if any(isnan, H)
            classifications[i] = :error
            continue
        end
        
        try
            eigenvals = eigvals(Symmetric(H))  # Use Symmetric for better numerical stability
            
            # Count eigenvalue signs
            n_positive = count(λ -> λ > tol_pos, eigenvals)
            n_negative = count(λ -> λ < -tol_neg, eigenvals)
            n_zero = count(λ -> abs(λ) < tol_zero, eigenvals)
            n_dims = length(eigenvals)
            
            if n_zero > 0
                classifications[i] = :degenerate
            elseif n_positive == n_dims
                classifications[i] = :minimum
            elseif n_negative == n_dims
                classifications[i] = :maximum
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

### 3. Eigenvalue Statistics Function
```julia
"""
    compute_eigenvalue_stats(hessians::Vector{Matrix{Float64}})::DataFrame

Compute detailed eigenvalue statistics for each Hessian matrix.

# Returns
DataFrame with columns:
- eigenvalue_min: Smallest eigenvalue
- eigenvalue_max: Largest eigenvalue  
- condition_number: Ratio of largest to smallest absolute eigenvalue
- determinant: Determinant of Hessian
- trace: Trace of Hessian
"""
function compute_eigenvalue_stats(hessians::Vector{Matrix{Float64}})::DataFrame
    n_points = length(hessians)
    
    eigenvalue_min = Vector{Float64}(undef, n_points)
    eigenvalue_max = Vector{Float64}(undef, n_points)
    condition_number = Vector{Float64}(undef, n_points)
    determinant = Vector{Float64}(undef, n_points)
    trace = Vector{Float64}(undef, n_points)
    
    for i = 1:n_points
        H = hessians[i]
        
        if any(isnan, H)
            eigenvalue_min[i] = NaN
            eigenvalue_max[i] = NaN
            condition_number[i] = NaN
            determinant[i] = NaN
            trace[i] = NaN
            continue
        end
        
        try
            eigenvals = eigvals(Symmetric(H))
            eigenvalue_min[i] = minimum(eigenvals)
            eigenvalue_max[i] = maximum(eigenvals)
            
            # Condition number (ratio of largest to smallest absolute eigenvalue)
            abs_eigenvals = abs.(eigenvals)
            condition_number[i] = maximum(abs_eigenvals) / minimum(abs_eigenvals)
            
            determinant[i] = det(H)
            trace[i] = tr(H)
            
        catch e
            eigenvalue_min[i] = NaN
            eigenvalue_max[i] = NaN
            condition_number[i] = NaN
            determinant[i] = NaN
            trace[i] = NaN
        end
    end
    
    return DataFrame(
        eigenvalue_min = eigenvalue_min,
        eigenvalue_max = eigenvalue_max,
        condition_number = condition_number,
        determinant = determinant,
        trace = trace
    )
end
```

### 4. Integration with analyze_critical_points
**File**: `src/refine.jl` (modify existing function)

Add Phase 2 enhancements after Phase 1 statistics:

```julia
# === PHASE 2 ENHANCEMENTS: Hessian-Based Classification ===
if verbose
    println("\n=== Computing Hessian-Based Classification ===\")
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

# 2. Classify critical points
if verbose
    println("Classifying critical points...")
end
classifications = classify_critical_points(hessians)
df[!, :critical_point_type] = classifications

# 3. Compute eigenvalue statistics
if verbose
    println("Computing eigenvalue statistics...")
end
eigenvalue_stats = compute_eigenvalue_stats(hessians)
for col in names(eigenvalue_stats)
    df[!, Symbol("hessian_$col")] = eigenvalue_stats[!, col]
end

# 4. Hessian analysis for minimizers (if any)
if nrow(df_min) > 0
    if verbose
        println("Computing Hessian analysis for minimizers...")
    end
    min_points = Matrix{Float64}(undef, nrow(df_min), n_dims)
    for i = 1:n_dims
        min_points[:, i] = df_min[!, Symbol("x$i")]
    end
    min_hessians = compute_hessians(f, min_points)
    min_classifications = classify_critical_points(min_hessians)
    min_eigenvalue_stats = compute_eigenvalue_stats(min_hessians)
    
    df_min[!, :critical_point_type] = min_classifications
    for col in names(min_eigenvalue_stats)
        df_min[!, Symbol("hessian_$col")] = min_eigenvalue_stats[!, col]
    end
end
```

## Testing Plan

### 1. Unit Tests
**File**: `test/test_hessian_analysis.jl` (new file)

Test cases:
- Simple quadratic functions with known Hessian properties
- Rastringin function at known critical points
- Edge cases (singular matrices, computation failures)
- Performance benchmarks

### 2. Integration Tests
**File**: `Examples/test_phase2_hessian_classification.jl` (new file)

Complete workflow test:
- Setup Rastringin 3D problem
- Run Phase 1 + Phase 2 analysis
- Verify classification results
- Display enhanced statistics

### 3. Example Notebooks
Update existing notebooks:
- `Examples/Notebooks/Ratstrigin_3.ipynb`
- Add new examples showcasing classification results

## Documentation Updates

### 1. Column Documentation
Add to documentation strings:

**Critical Points DataFrame (Phase 2 additions):**
- `critical_point_type` - Classification: :minimum, :maximum, :saddle, :degenerate, :error
- `hessian_eigenvalue_min` - Smallest eigenvalue of Hessian matrix
- `hessian_eigenvalue_max` - Largest eigenvalue of Hessian matrix  
- `hessian_condition_number` - Condition number of Hessian matrix
- `hessian_determinant` - Determinant of Hessian matrix
- `hessian_trace` - Trace of Hessian matrix

**Minimizers DataFrame (Phase 2 additions):**
- Same Hessian-based columns as critical points

### 2. CLAUDE.md Updates
Add Phase 2 information to the development guide.

## Performance Considerations

1. **Memory Usage**: Hessian matrices are n×n, so memory scales as O(n²) per point
2. **Computation Cost**: Hessian computation is more expensive than gradient
3. **Numerical Stability**: Use `Symmetric(H)` for eigenvalue computation
4. **Error Handling**: Graceful fallback for computation failures

## Expected Outcomes

1. **Enhanced Critical Point Analysis**: Clear classification of all critical points
2. **Improved Minimizer Validation**: Verify that detected minimizers are true local minima
3. **Saddle Point Detection**: Identify transition states and saddle points
4. **Numerical Diagnostics**: Condition numbers and eigenvalue ranges for stability analysis

## File Structure
```
src/
├── hessian_analysis.jl          # New: Core Hessian functions
├── refine.jl                    # Modified: Integration with Phase 1
└── Globtim.jl                   # Modified: Export new functions

test/
└── test_hessian_analysis.jl     # New: Unit tests

Examples/
├── test_phase2_hessian_classification.jl  # New: Integration test
└── Notebooks/
    └── Ratstrigin_3.ipynb       # Modified: Phase 2 examples

docs/
└── PHASE2_HESSIAN_CLASSIFICATION.md  # This file
```

## Dependencies
- ForwardDiff.jl (already used in Phase 1)
- LinearAlgebra (for eigenvalue computation)
- No additional dependencies required

## Success Criteria
1. All tests pass
2. Rastringin function correctly classifies known minima
3. Performance acceptable for typical problem sizes
4. Documentation complete and examples working
5. Numerical stability verified across different function types

---

## Enhanced Phase 2 Plan: Complete Eigenvalue Analysis & Visualization

### Additional Features (User Requirements)

#### 1. Complete Eigenvalue Storage
Store all eigenvalues for each Hessian matrix, not just min/max statistics:

```julia
"""
    store_all_eigenvalues(hessians::Vector{Matrix{Float64}})::Vector{Vector{Float64}}

Store all eigenvalues for each Hessian matrix for detailed analysis.

# Returns
Vector{Vector{Float64}}: All eigenvalues for each Hessian matrix
"""
function store_all_eigenvalues(hessians::Vector{Matrix{Float64}})::Vector{Vector{Float64}}
    n_points = length(hessians)
    all_eigenvalues = Vector{Vector{Float64}}(undef, n_points)
    
    for i = 1:n_points
        H = hessians[i]
        
        if any(isnan, H)
            n_dims = size(H, 1)
            all_eigenvalues[i] = fill(NaN, n_dims)
            continue
        end
        
        try
            eigenvals = eigvals(Symmetric(H))
            all_eigenvalues[i] = sort(eigenvals)  # Sort for consistency
        catch e
            n_dims = size(H, 1)
            all_eigenvalues[i] = fill(NaN, n_dims)
        end
    end
    
    return all_eigenvalues
end
```

#### 2. Specialized Eigenvalue Tracking for Minima/Maxima
Track the smallest positive eigenvalue for minima and largest negative eigenvalue for maxima:

```julia
"""
    extract_critical_eigenvalues(classifications::Vector{Symbol}, 
                                all_eigenvalues::Vector{Vector{Float64}})::
                                Tuple{Vector{Float64}, Vector{Float64}}

Extract critical eigenvalues for minima and maxima classification.

# Returns
Tuple{Vector{Float64}, Vector{Float64}}: 
- smallest_positive_eigenvals: For minima (smallest positive eigenvalue)
- largest_negative_eigenvals: For maxima (largest negative eigenvalue)
"""
function extract_critical_eigenvalues(classifications::Vector{Symbol}, 
                                     all_eigenvalues::Vector{Vector{Float64}})
    n_points = length(classifications)
    smallest_positive_eigenvals = Vector{Float64}(undef, n_points)
    largest_negative_eigenvals = Vector{Float64}(undef, n_points)
    
    for i = 1:n_points
        eigenvals = all_eigenvalues[i]
        classification = classifications[i]
        
        # Initialize with NaN
        smallest_positive_eigenvals[i] = NaN
        largest_negative_eigenvals[i] = NaN
        
        if any(isnan, eigenvals) || classification == :error
            continue
        end
        
        # For minima: find smallest positive eigenvalue
        if classification == :minimum
            positive_eigenvals = filter(λ -> λ > 1e-12, eigenvals)
            if !isempty(positive_eigenvals)
                smallest_positive_eigenvals[i] = minimum(positive_eigenvals)
            end
        end
        
        # For maxima: find largest negative eigenvalue
        if classification == :maximum
            negative_eigenvals = filter(λ -> λ < -1e-12, eigenvals)
            if !isempty(negative_eigenvals)
                largest_negative_eigenvals[i] = maximum(negative_eigenvals)
            end
        end
    end
    
    return smallest_positive_eigenvals, largest_negative_eigenvals
end
```

#### 3. Hessian Norm Computation
Compute L2 norm (Frobenius norm) of each Hessian matrix:

```julia
"""
    compute_hessian_norms(hessians::Vector{Matrix{Float64}})::Vector{Float64}

Compute L2 (Frobenius) norm of each Hessian matrix.

# Returns
Vector{Float64}: ||H||_F for each Hessian matrix
"""
function compute_hessian_norms(hessians::Vector{Matrix{Float64}})::Vector{Float64}
    n_points = length(hessians)
    hessian_norms = Vector{Float64}(undef, n_points)
    
    for i = 1:n_points
        H = hessians[i]
        
        if any(isnan, H)
            hessian_norms[i] = NaN
            continue
        end
        
        try
            hessian_norms[i] = norm(H, 2)  # Frobenius norm
        catch e
            hessian_norms[i] = NaN
        end
    end
    
    return hessian_norms
end
```

#### 4. Visualization Functions
Create comprehensive plotting functions for Hessian analysis:

```julia
"""
Plotting functions for Hessian analysis visualization.
Requires CairoMakie or GLMakie backend.
"""

function plot_hessian_norms(df::DataFrame; backend=:cairo)
    if backend == :cairo
        using CairoMakie
    else
        using GLMakie
    end
    
    fig = Figure(resolution=(800, 600))
    ax = Axis(fig[1, 1], 
              xlabel="Critical Point Index", 
              ylabel="Hessian L2 Norm",
              title="L2 Norm of Hessian Matrices")
    
    # Color by classification if available
    if :critical_point_type in names(df)
        for (i, classification) in enumerate(unique(df.critical_point_type))
            mask = df.critical_point_type .== classification
            scatter!(ax, findall(mask), df.hessian_norm[mask], 
                    label=string(classification), markersize=8)
        end
        axislegend(ax)
    else
        scatter!(ax, 1:nrow(df), df.hessian_norm, markersize=8)
    end
    
    return fig
end

function plot_condition_numbers(df::DataFrame; backend=:cairo)
    if backend == :cairo
        using CairoMakie
    else
        using GLMakie
    end
    
    fig = Figure(resolution=(800, 600))
    ax = Axis(fig[1, 1], 
              xlabel="Critical Point Index", 
              ylabel="Condition Number (log scale)",
              title="Condition Numbers of Hessian Matrices",
              yscale=log10)
    
    # Filter out NaN and infinite values
    valid_indices = findall(x -> isfinite(x) && x > 0, df.hessian_condition_number)
    
    if :critical_point_type in names(df)
        for (i, classification) in enumerate(unique(df.critical_point_type))
            mask = (df.critical_point_type .== classification) .& 
                   [i in valid_indices for i in 1:nrow(df)]
            indices = findall(mask)
            if !isempty(indices)
                scatter!(ax, indices, df.hessian_condition_number[indices], 
                        label=string(classification), markersize=8)
            end
        end
        axislegend(ax)
    else
        scatter!(ax, valid_indices, df.hessian_condition_number[valid_indices], markersize=8)
    end
    
    return fig
end

function plot_critical_eigenvalues(df::DataFrame; backend=:cairo)
    if backend == :cairo
        using CairoMakie
    else
        using GLMakie
    end
    
    fig = Figure(resolution=(1200, 500))
    
    # Plot 1: Smallest positive eigenvalues for minima
    ax1 = Axis(fig[1, 1], 
               xlabel="Minimum Index", 
               ylabel="Smallest Positive Eigenvalue",
               title="Smallest Positive Eigenvalues (Minima)")
    
    minima_mask = df.critical_point_type .== :minimum
    minima_indices = findall(minima_mask)
    valid_minima = findall(x -> isfinite(x) && x > 0, df.smallest_positive_eigenval[minima_mask])
    
    if !isempty(valid_minima)
        scatter!(ax1, valid_minima, df.smallest_positive_eigenval[minima_mask][valid_minima], 
                color=:blue, markersize=10)
        # Add horizontal line at machine epsilon for reference
        hlines!(ax1, [1e-12], color=:red, linestyle=:dash, label="Numerical Zero")
        axislegend(ax1)
    end
    
    # Plot 2: Largest negative eigenvalues for maxima
    ax2 = Axis(fig[1, 2], 
               xlabel="Maximum Index", 
               ylabel="Largest Negative Eigenvalue",
               title="Largest Negative Eigenvalues (Maxima)")
    
    maxima_mask = df.critical_point_type .== :maximum
    maxima_indices = findall(maxima_mask)
    valid_maxima = findall(x -> isfinite(x) && x < 0, df.largest_negative_eigenval[maxima_mask])
    
    if !isempty(valid_maxima)
        scatter!(ax2, valid_maxima, df.largest_negative_eigenval[maxima_mask][valid_maxima], 
                color=:red, markersize=10)
        # Add horizontal line at negative machine epsilon for reference
        hlines!(ax2, [-1e-12], color=:red, linestyle=:dash, label="Numerical Zero")
        axislegend(ax2)
    end
    
    return fig
end
```

#### 5. Integration with analyze_critical_points (Extended)
Enhanced integration that includes all new features:

```julia
# === PHASE 2 ENHANCEMENTS: Complete Hessian Analysis ===
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
classifications = classify_critical_points(hessians)
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
# Note: This creates a large data structure, consider serialization for storage
df_metadata = Dict("all_eigenvalues" => all_eigenvalues)
```

#### 6. Visualization Integration
Add plotting calls to test files and examples:

```julia
# In test files and examples, add visualization section:
println("\n=== Phase 2 Visualization ===")

# Plot Hessian norms
fig_norms = plot_hessian_norms(df_enhanced)
display(fig_norms)

# Plot condition numbers  
fig_condition = plot_condition_numbers(df_enhanced)
display(fig_condition)

# Plot critical eigenvalues
fig_eigenvals = plot_critical_eigenvalues(df_enhanced)
display(fig_eigenvals)

# Save plots if needed
save("hessian_norms.png", fig_norms)
save("condition_numbers.png", fig_condition)
save("critical_eigenvalues.png", fig_eigenvals)
```

### Updated File Structure
```
src/
├── hessian_analysis.jl          # Enhanced: All new Hessian functions
├── hessian_visualization.jl     # New: Plotting functions
├── refine.jl                    # Modified: Complete integration
└── Globtim.jl                   # Modified: Export all functions

Examples/
├── test_phase2_hessian_complete.jl  # New: Complete feature test
└── Notebooks/
    └── Ratstrigin_3_hessian.ipynb  # New: Hessian analysis notebook
```

### Enhanced Column Documentation

**Critical Points DataFrame (Complete Phase 2):**
- `critical_point_type` - Classification: :minimum, :maximum, :saddle, :degenerate, :error
- `smallest_positive_eigenval` - Smallest positive eigenvalue (for minima validation)
- `largest_negative_eigenval` - Largest negative eigenvalue (for maxima validation)
- `hessian_norm` - L2 (Frobenius) norm of Hessian matrix
- `hessian_eigenvalue_min` - Smallest eigenvalue of Hessian matrix
- `hessian_eigenvalue_max` - Largest eigenvalue of Hessian matrix  
- `hessian_condition_number` - Condition number of Hessian matrix
- `hessian_determinant` - Determinant of Hessian matrix
- `hessian_trace` - Trace of Hessian matrix

**Metadata:**
- `all_eigenvalues` - Complete eigenvalue vectors for each Hessian (stored separately)

This enhanced plan provides complete eigenvalue analysis, specialized tracking for minima/maxima, comprehensive visualization, and detailed numerical diagnostics for Hessian matrices.