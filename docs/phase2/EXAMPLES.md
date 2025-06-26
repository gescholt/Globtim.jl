# Phase 2 Examples

## Basic Usage

### Simple 2D Function Analysis

```julia
using Globtim
using DynamicPolynomials
using CairoMakie

# Define function
f = Deuflhard  # Has multiple critical points

# Setup problem
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 10)

# Solve for critical points
@polyvar x[1:2]
real_pts = solve_polynomial_system(x, 2, 10, pol.coeffs)
df = process_crit_pts(real_pts, f, TR)

# Run Phase 1 + Phase 2 analysis
df_enhanced, df_min = analyze_critical_points(f, df, TR, verbose=true)

# Examine results
println("Found $(nrow(df_enhanced)) critical points")
println("Classifications:")
println(combine(groupby(df_enhanced, :critical_point_type), nrow => :count))
```

### Rastringin 3D Analysis

```julia
# Higher-dimensional example
f = Rastringin
TR = test_input(f, dim=3, center=[0.0, 0.0, 0.0], sample_range=1.0)
pol = Constructor(TR, 8)  # Lower degree for 3D

@polyvar x[1:3]
real_pts = solve_polynomial_system(x, 3, 8, pol.coeffs)
df = process_crit_pts(real_pts, f, TR)

# Phase 2 analysis
df_enhanced, df_min = analyze_critical_points(f, df, TR, verbose=true)

# Examine minima specifically
minima_df = df_enhanced[df_enhanced.critical_point_type .== :minimum, :]
println("Found $(nrow(minima_df)) minima")
println("Smallest positive eigenvalues:")
println(minima_df.smallest_positive_eigenval)
```

## Visualization Examples

### Complete Visualization Suite

```julia
using CairoMakie

# Run analysis
f = HolderTable
TR = test_input(f, dim=2)
pol = Constructor(TR, 12)
@polyvar x[1:2]
real_pts = solve_polynomial_system(x, 2, 12, pol.coeffs)
df = process_crit_pts(real_pts, f, TR)
df_enhanced, df_min = analyze_critical_points(f, df, TR)

# Create all Phase 2 plots
fig_norms = plot_hessian_norms(df_enhanced)
fig_condition = plot_condition_numbers(df_enhanced)
fig_eigenvals = plot_critical_eigenvalues(df_enhanced)

# Display
display(fig_norms)
display(fig_condition)
display(fig_eigenvals)

# Save
save("holder_norms.png", fig_norms)
save("holder_condition.png", fig_condition)
save("holder_eigenvals.png", fig_eigenvals)
```

### Custom Analysis

```julia
# Custom function with known behavior
function quadratic_2d(x)
    return (x[1] - 1)^2 + 2*(x[2] + 0.5)^2
end

TR = test_input(quadratic_2d, dim=2, center=[1.0, -0.5], sample_range=2.0)
pol = Constructor(TR, 6)
@polyvar x[1:2]
real_pts = solve_polynomial_system(x, 2, 6, pol.coeffs)
df = process_crit_pts(real_pts, quadratic_2d, TR)
df_enhanced, df_min = analyze_critical_points(quadratic_2d, df, TR, verbose=true)

# Should find exactly one minimum at (1, -0.5)
println("Critical points found:")
for row in eachrow(df_enhanced)
    println("Point: ($(row.x1), $(row.x2)), Type: $(row.critical_point_type)")
end
```

## Advanced Analysis

### Eigenvalue Distribution Analysis

```julia
# Extract all eigenvalues for distribution analysis
function analyze_eigenvalue_distribution(f, dim, degree)
    TR = test_input(f, dim=dim)
    pol = Constructor(TR, degree)
    
    # Create polynomial variables
    if dim == 2
        @polyvar x[1:2]
    elseif dim == 3
        @polyvar x[1:3]
    else
        @polyvar x[1:dim]
    end
    
    real_pts = solve_polynomial_system(x, dim, degree, pol.coeffs)
    df = process_crit_pts(real_pts, f, TR)
    df_enhanced, df_min = analyze_critical_points(f, df, TR)
    
    # Extract points matrix for Hessian computation
    points_matrix = Matrix{Float64}(undef, nrow(df_enhanced), dim)
    for i = 1:dim
        points_matrix[:, i] = df_enhanced[!, Symbol("x$i")]
    end
    
    # Get all eigenvalues
    hessians = compute_hessians(f, points_matrix)
    all_eigenvalues = store_all_eigenvalues(hessians)
    
    return df_enhanced, all_eigenvalues
end

# Analyze multiple functions
functions = [Deuflhard, HolderTable, Rastringin]
results = []

for f in functions
    println("Analyzing $(f)...")
    df, eigenvals = analyze_eigenvalue_distribution(f, 2, 10)
    push!(results, (f, df, eigenvals))
    
    # Quick summary
    classifications = combine(groupby(df, :critical_point_type), nrow => :count)
    println("Classifications: $classifications")
    println("Total eigenvalues: $(sum(length.(eigenvals)))")
    println()
end
```

### Batch Processing Example

```julia
function process_test_suite()
    # Define test functions
    test_functions = [
        (Deuflhard, 2, 10),
        (HolderTable, 2, 12),
        (Rastringin, 2, 8),
        (CrossInTray, 2, 10),
        (Ackley, 2, 8)
    ]
    
    results = Dict()
    
    for (f, dim, degree) in test_functions
        println("Processing $(f) (dim=$dim, degree=$degree)...")
        
        try
            TR = test_input(f, dim=dim)
            pol = Constructor(TR, degree)
            
            # Create variables based on dimension
            if dim == 2
                @polyvar x[1:2]
            else
                @polyvar x[1:dim]
            end
            
            real_pts = solve_polynomial_system(x, dim, degree, pol.coeffs)
            df = process_crit_pts(real_pts, f, TR)
            df_enhanced, df_min = analyze_critical_points(f, df, TR)
            
            # Store results
            results[f] = (
                critical_points = nrow(df_enhanced),
                minima = count(df_enhanced.critical_point_type .== :minimum),
                maxima = count(df_enhanced.critical_point_type .== :maximum),
                saddles = count(df_enhanced.critical_point_type .== :saddle),
                degenerate = count(df_enhanced.critical_point_type .== :degenerate),
                errors = count(df_enhanced.critical_point_type .== :error),
                avg_condition_number = mean(filter(isfinite, df_enhanced.hessian_condition_number))
            )
            
            println("  Found $(results[f].critical_points) critical points")
            println("  Minima: $(results[f].minima), Maxima: $(results[f].maxima), Saddles: $(results[f].saddles)")
            
        catch e
            println("  Error processing $(f): $e")
            results[f] = nothing
        end
        println()
    end
    
    return results
end

# Run the test suite
test_results = process_test_suite()
```

## Performance Examples

### Large-Scale Analysis

```julia
# For functions with many critical points
function efficient_large_scale_analysis(f, dim, degree)
    println("Starting large-scale analysis...")
    
    # Use lower precision for initial pass
    TR = test_input(f, dim=dim, sample_range=2.0)
    pol = Constructor(TR, degree)
    
    # Time the critical point finding
    @time begin
        if dim == 2
            @polyvar x[1:2]
        else
            @polyvar x[1:dim]
        end
        real_pts = solve_polynomial_system(x, dim, degree, pol.coeffs)
        df = process_crit_pts(real_pts, f, TR)
    end
    
    println("Found $(nrow(df)) critical points")
    
    # Time the Phase 2 analysis
    @time begin
        df_enhanced, df_min = analyze_critical_points(f, df, TR, verbose=true)
    end
    
    return df_enhanced
end

# Test with different degrees
for degree in [8, 10, 12, 15]
    println("Testing degree $degree:")
    df = efficient_large_scale_analysis(Rastringin, 2, degree)
    println("Results: $(nrow(df)) points, $(count(df.critical_point_type .== :minimum)) minima")
    println()
end
```

### Memory-Efficient Processing

```julia
# For memory-constrained environments
function memory_efficient_analysis(f, dim, degree, batch_size=50)
    TR = test_input(f, dim=dim)
    pol = Constructor(TR, degree)
    
    if dim == 2
        @polyvar x[1:2]
    else
        @polyvar x[1:dim]
    end
    
    real_pts = solve_polynomial_system(x, dim, degree, pol.coeffs)
    df = process_crit_pts(real_pts, f, TR)
    
    # Process in batches to control memory usage
    n_points = nrow(df)
    n_batches = ceil(Int, n_points / batch_size)
    
    results = DataFrame()
    
    for i in 1:n_batches
        start_idx = (i-1) * batch_size + 1
        end_idx = min(i * batch_size, n_points)
        
        println("Processing batch $i/$n_batches (points $start_idx:$end_idx)")
        
        df_batch = df[start_idx:end_idx, :]
        df_batch_enhanced, _ = analyze_critical_points(f, df_batch, TR, verbose=false)
        
        if i == 1
            results = df_batch_enhanced
        else
            results = vcat(results, df_batch_enhanced)
        end
        
        # Force garbage collection
        GC.gc()
    end
    
    return results
end

# Use for large problems
df_large = memory_efficient_analysis(Rastringin, 3, 10, batch_size=25)
```

## Debugging Examples

### Diagnosing Classification Issues

```julia
function debug_classification(f, point)
    # Manually compute Hessian at a specific point
    H = ForwardDiff.hessian(f, point)
    eigenvals = eigvals(Symmetric(H))
    
    println("Point: $point")
    println("Function value: $(f(point))")
    println("Hessian matrix:")
    display(H)
    println("Eigenvalues: $eigenvals")
    println("Condition number: $(cond(H))")
    println("Determinant: $(det(H))")
    
    # Manual classification
    n_positive = count(λ -> λ > 1e-8, eigenvals)
    n_negative = count(λ -> λ < -1e-8, eigenvals)
    n_zero = count(λ -> abs(λ) < 1e-8, eigenvals)
    
    if n_zero > 0
        classification = :degenerate
    elseif n_positive == length(eigenvals)
        classification = :minimum
    elseif n_negative == length(eigenvals)
        classification = :maximum
    else
        classification = :saddle
    end
    
    println("Classification: $classification")
    return H, eigenvals, classification
end

# Debug specific points
debug_classification(Deuflhard, [0.0, 0.0])
debug_classification(Rastringin, [0.0, 0.0])
```

### Validation Against Known Results

```julia
# Test against functions with known critical points
function validate_known_function()
    # Simple quadratic with known minimum at origin
    f_quad(x) = x[1]^2 + x[2]^2
    
    TR = test_input(f_quad, dim=2, center=[0.0, 0.0], sample_range=2.0)
    pol = Constructor(TR, 4)  # Low degree sufficient for quadratic
    
    @polyvar x[1:2]
    real_pts = solve_polynomial_system(x, 2, 4, pol.coeffs)
    df = process_crit_pts(real_pts, f_quad, TR)
    df_enhanced, df_min = analyze_critical_points(f_quad, df, TR, verbose=true)
    
    # Should find exactly one minimum near origin
    println("Results for quadratic function x₁² + x₂²:")
    println("Number of critical points: $(nrow(df_enhanced))")
    println("Number of minima: $(count(df_enhanced.critical_point_type .== :minimum))")
    
    if nrow(df_enhanced) > 0
        closest_to_origin = argmin([row.x1^2 + row.x2^2 for row in eachrow(df_enhanced)])
        best_point = df_enhanced[closest_to_origin, :]
        println("Closest point to origin: ($(best_point.x1), $(best_point.x2))")
        println("Classification: $(best_point.critical_point_type)")
        println("Smallest positive eigenvalue: $(best_point.smallest_positive_eigenval)")
    end
end

validate_known_function()
```