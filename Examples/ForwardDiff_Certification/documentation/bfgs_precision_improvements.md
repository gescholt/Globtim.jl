# BFGS Precision Improvements for 4D Deuflhard Analysis

## Problem Analysis

The 4D Deuflhard composite function has extremely small minimum values:
- Global minimum: ~1.764e-06
- Other local minima: ~7.058e-06, ~2.824e-05, etc.

The current BFGS implementation in `analyze_critical_points` (lines 402-410 of refine.jl) uses default tolerances which may be insufficient for such small values.

## Current Implementation

```julia
res = Optim.optimize(
    f, x0, Optim.BFGS(), 
    Optim.Options(
        show_trace=false, 
        f_calls_limit=max_iters_in_optim,  # default: 100
    ),
)
```

## Proposed Improvements

### 1. Enhanced Convergence Parameters

```julia
# In deuflhard_4d_analysis.jl, modify the analyze_critical_points call:

# Add new precision parameters
const BFGS_G_TOL = 1e-12          # Gradient tolerance (default: 1e-8)
const BFGS_F_TOL = 1e-14          # Function value tolerance (default: 0.0)
const BFGS_X_TOL = 1e-10          # Parameter tolerance (default: 0.0)
const BFGS_MAX_ITERS = 200        # Maximum iterations (default: 100)
const BFGS_F_ABS_TOL = 1e-14     # Absolute function tolerance

# Modify the analyze_critical_points call
df_refined_4d, df_refined_minima_4d = analyze_critical_points(
    deuflhard_4d_composite, df_polynomial_4d, TR_4d,
    enable_hessian=true,
    hessian_tol_zero=1e-10,  # Tighten from 1e-8
    tol_dist=0.01,           # Tighten from 0.025
    verbose=false,
    max_iters_in_optim=BFGS_MAX_ITERS,
    # New parameters (need to be added to the function):
    bfgs_g_tol=BFGS_G_TOL,
    bfgs_f_tol=BFGS_F_TOL,
    bfgs_x_tol=BFGS_X_TOL,
    bfgs_f_abs_tol=BFGS_F_ABS_TOL
)
```

### 2. Modified analyze_critical_points Function

To support these parameters, modify the `analyze_critical_points` function signature and optimization call:

```julia
function analyze_critical_points(
    f::Function,
    df::DataFrame,
    TR::test_input;
    tol_dist=0.025,
    verbose=true,
    max_iters_in_optim=100,
    enable_hessian=true,
    hessian_tol_zero=1e-8,
    # New BFGS precision parameters
    bfgs_g_tol=1e-8,      # gradient tolerance
    bfgs_f_tol=0.0,       # function value tolerance
    bfgs_x_tol=0.0,       # parameter tolerance
    bfgs_f_abs_tol=0.0    # absolute function tolerance
)
    # ... existing code ...
    
    # Modified optimization call (around line 402):
    res = Optim.optimize(
        f, x0, Optim.BFGS(), 
        Optim.Options(
            show_trace=false,
            f_calls_limit=max_iters_in_optim,
            g_tol=bfgs_g_tol,
            f_tol=bfgs_f_tol,
            x_tol=bfgs_x_tol,
            f_abs_tol=bfgs_f_abs_tol,
            # Optional: add more iterations
            iterations=max_iters_in_optim
        ),
    )
```

### 3. Additional Precision Enhancements

#### A. Pre-conditioning for Small Values
```julia
# Scale the objective function for better numerical stability
function scaled_objective(scale_factor::Float64=1e6)
    return x -> scale_factor * deuflhard_4d_composite(x)
end

# Use scaled version for very small minima
if minimum(df_polynomial_4d.z) < 1e-4
    println("Using scaled objective for improved precision...")
    f_scaled = scaled_objective(1e6)
    # Use f_scaled in analyze_critical_points
end
```

#### B. Multi-stage Refinement
```julia
# First pass with moderate precision
df_refined_stage1, _ = analyze_critical_points(
    deuflhard_4d_composite, df_polynomial_4d, TR_4d,
    enable_hessian=false,  # Skip Hessian for speed
    max_iters_in_optim=100,
    bfgs_g_tol=1e-10
)

# Second pass with high precision on promising points
promising_mask = df_refined_stage1.z .< 1e-3
df_promising = df_refined_stage1[promising_mask, :]

df_refined_stage2, df_refined_minima_4d = analyze_critical_points(
    deuflhard_4d_composite, df_promising, TR_4d,
    enable_hessian=true,
    max_iters_in_optim=300,
    bfgs_g_tol=1e-14,
    bfgs_f_tol=1e-16,
    bfgs_x_tol=1e-12
)
```

### 4. Verification of Improved Precision

Add verification code to check the quality of refined points:

```julia
# After refinement, verify gradient norms
function verify_refinement_quality(f::Function, df_refined::DataFrame, tolerance::Float64=1e-10)
    println("\n=== Refinement Quality Verification ===")
    
    n_dims = count(col -> startswith(string(col), "x"), names(df_refined))
    grad_norms = Float64[]
    
    for i in 1:nrow(df_refined)
        if df_refined.converged[i]
            point = [df_refined[i, Symbol("y$j")] for j in 1:n_dims]
            grad = ForwardDiff.gradient(f, point)
            grad_norm = norm(grad)
            push!(grad_norms, grad_norm)
            
            if grad_norm > tolerance
                println("⚠️  Point $i: gradient norm = $(grad_norm) > tolerance")
            end
        end
    end
    
    println("Gradient norm statistics for converged points:")
    println("  • Min: $(minimum(grad_norms))")
    println("  • Max: $(maximum(grad_norms))")
    println("  • Mean: $(mean(grad_norms))")
    println("  • Points meeting tolerance: $(sum(grad_norms .< tolerance))/$(length(grad_norms))")
end

# Use after refinement
verify_refinement_quality(deuflhard_4d_composite, df_refined_4d, BFGS_G_TOL)
```

### 5. Alternative: Use TrustRegion for Better Stability

For extremely small function values, trust region methods can be more stable:

```julia
# Alternative optimization with TrustRegion
res = Optim.optimize(
    f, x0, 
    Optim.NewtonTrustRegion(),  # More stable for small values
    Optim.Options(
        show_trace=false,
        g_tol=1e-14,
        f_tol=1e-16,
        x_tol=1e-12,
        iterations=200
    )
)
```

### 6. Recommended Parameter Sets

#### For General Use:
```julia
const BFGS_PARAMS_STANDARD = (
    g_tol = 1e-10,
    f_tol = 1e-12,
    x_tol = 1e-8,
    max_iters = 150
)
```

#### For High Precision (small minima):
```julia
const BFGS_PARAMS_HIGH_PRECISION = (
    g_tol = 1e-14,
    f_tol = 1e-16,
    x_tol = 1e-12,
    f_abs_tol = 1e-16,
    max_iters = 300
)
```

#### For Ultra-High Precision:
```julia
const BFGS_PARAMS_ULTRA = (
    g_tol = 1e-16,
    f_tol = 1e-18,
    x_tol = 1e-14,
    f_abs_tol = 1e-18,
    max_iters = 500
)
```

## Implementation Steps

1. **Immediate**: Add precision constants to `deuflhard_4d_analysis.jl`
2. **Short-term**: Modify `refine.jl` to accept BFGS precision parameters
3. **Medium-term**: Implement multi-stage refinement strategy
4. **Long-term**: Create precision profiles for different problem types

## Expected Improvements

With these changes, we expect:
- More accurate location of critical points (within 1e-12 of true values)
- Better recovery rate of expected minima
- Reduced average distance to theoretical predictions
- More reliable gradient norm verification (< 1e-12)

## Testing the Improvements

```julia
# Compare before and after
println("Before: avg distance to expected = $(mean(distances_to_expected_minima))")
# Apply improvements...
println("After: avg distance to expected = $(mean(distances_to_expected_minima_new))")
println("Improvement factor: $(mean(distances_to_expected_minima) / mean(distances_to_expected_minima_new))")
```