# Guide for Replacing Custom Functions with Globtim Routines

## Overview
This guide shows how to replace the two wrapper functions with direct Globtim calls.

## 1. Replacing `fit_polynomial_and_find_critical_points`

### Original Function Call
```julia
result = fit_polynomial_and_find_critical_points(error_func, config, degree; verbose=true)
```

### Direct Globtim Replacement
```julia
# Step 1: Sample the objective function
TR = Globtim.test_input(
    error_func,
    dim = config.n,
    center = config.p_center,
    sample_range = config.sample_range,
    GN = config.GN,
    tolerance = nothing  # IMPORTANT: Disable automatic degree increase
)

# Step 2: Construct polynomial approximation
pol = Globtim.Constructor(TR, degree,
                         basis = config.basis,
                         precision = config.precision)

# Step 3: Find critical points
@polyvar x[1:config.n]
solutions = Globtim.solve_polynomial_system(
    x, config.n, degree, pol.coeffs;
    basis = pol.basis,
    precision = pol.precision,
    normalized = config.basis == :legendre,
    power_of_two_denom = pol.power_of_two_denom
)

# Step 4: Process critical points to get DataFrame
df_critical = Globtim.process_crit_pts(solutions, error_func, TR)

# Step 5: (Optional) Refine and classify critical points
df_refined = nothing
df_min = nothing
try
    df_refined, df_min = Globtim.analyze_critical_points(
        error_func, 
        copy(df_critical), 
        TR, 
        tol_dist=0.001,
        enable_hessian=true
    )
catch e
    # Handle missing Optim.jl or other errors
    println("Critical point refinement skipped: $e")
end

# Build result structure (if needed)
result = (
    n_critical_points = nrow(df_critical),
    condition_number = pol.cond_vandermonde,
    l2_error = pol.nrm,
    critical_points = df_critical,
    critical_points_refined = df_refined,
    minima_refined = df_min,
    polynomial = pol,
    test_input = TR
)
```

## 2. Replacing `find_best_critical_point`

### Original Function Call
```julia
best_point, best_f_value = find_best_critical_point(df_critical_points, error_func)
```

### Direct Replacement Options

#### Option A: Simple DataFrame Operation (Recommended)
```julia
# Direct replacement using the critical points DataFrame
if !isempty(df_critical_points)
    # Find row with minimum function value
    best_idx = argmin(df_critical_points.z)
    best_row = df_critical_points[best_idx, :]
    
    # Extract coordinates
    n_dims = count(name -> startswith(String(name), "x"), names(df_critical_points))
    best_point = [best_row[Symbol("x$i")] for i in 1:n_dims]
    best_f_value = best_row.z
else
    best_point = nothing
    best_f_value = Inf
end
```

#### Option B: Using Refined Minima from `analyze_critical_points`
```julia
# If you already have df_min from analyze_critical_points
if !isnothing(df_min) && !isempty(df_min)
    # df_min is already sorted by function value
    n_dims = count(name -> startswith(String(name), "x"), names(df_min))
    best_point = [df_min[1, Symbol("x$i")] for i in 1:n_dims]
    best_f_value = df_min[1, :value]  # Note: column name is 'value', not 'z'
else
    best_point = nothing
    best_f_value = Inf
end
```

## Key Differences to Note

1. **Column Names**:
   - `process_crit_pts` output: Uses column `z` for function values
   - `analyze_critical_points` output: Uses column `value` for function values

2. **Error Handling**:
   - `analyze_critical_points` requires Optim.jl
   - Always wrap in try-catch if package availability is uncertain

3. **Performance**:
   - Direct DataFrame operations (Option A) are faster
   - `analyze_critical_points` provides refined positions but is more expensive

## Migration Example

### Before (Using Custom Functions)
```julia
# Test polynomial degrees
for test_config in degree_configs
    result = fit_polynomial_and_find_critical_points(
        objective_func, config, test_config.degree; verbose=verbose
    )
    
    # Find best critical point
    best_point, best_value = find_best_critical_point(
        result.critical_points, objective_func
    )
    
    # Use results...
end
```

### After (Using Globtim Directly)
```julia
# Test polynomial degrees
for test_config in degree_configs
    # Create test input and polynomial
    TR = Globtim.test_input(objective_func, dim=config.n, center=config.p_center,
                           sample_range=config.sample_range, GN=test_config.samples,
                           tolerance=nothing)
    pol = Globtim.Constructor(TR, test_config.degree, basis=config.basis,
                             precision=config.precision)
    
    # Find critical points
    @polyvar x[1:config.n]
    solutions = Globtim.solve_polynomial_system(x, config.n, test_config.degree, pol.coeffs;
                                               basis=pol.basis, precision=pol.precision,
                                               normalized=(config.basis == :legendre),
                                               power_of_two_denom=pol.power_of_two_denom)
    df_critical = Globtim.process_crit_pts(solutions, objective_func, TR)
    
    # Find best critical point
    if !isempty(df_critical)
        best_idx = argmin(df_critical.z)
        best_point = [df_critical[best_idx, Symbol("x$i")] for i in 1:config.n]
        best_value = df_critical[best_idx, :z]
    else
        best_point = nothing
        best_value = Inf
    end
    
    # Use results...
end
```

## Advantages of Direct Globtim Usage

1. **Transparency**: Clear what each step does
2. **Flexibility**: Can customize each step
3. **No Redundancy**: Avoids wrapper overhead
4. **Better Error Handling**: Can handle failures at each step
5. **Access to Internals**: Direct access to intermediate results

## When to Keep Wrappers

Consider keeping wrapper functions if:
- The calling code is used in many places
- You need consistent error handling
- You want to hide implementation details
- You plan to extend functionality beyond Globtim