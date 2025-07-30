"""
    valley_walking_utils.jl

Utility functions for valley walking algorithms.
Provides enhanced valley walking with adaptive strategy switching.
"""

using ForwardDiff
using LinearAlgebra
using Random

"""
    enhanced_valley_walk(f, x0; kwargs...)

Enhanced valley walking that combines:
1. Gradient descent while the gradient is substantial
2. Valley walking when gradient is small AND Hessian is nearly rank deficient
3. Small gradient steps or termination when gradient is small but Hessian is well-conditioned

# Arguments
- `f`: Objective function to minimize
- `x0`: Starting point

# Keyword Arguments
- `n_steps = 15`: Number of steps to take
- `step_size = 0.01`: Step size for valley walking
- `ε_null = 1e-6`: Threshold for identifying valley directions
- `gradient_step_size = 0.005`: Step size for gradient descent
- `rank_deficiency_threshold = 1e-6`: Threshold for switching strategies
- `gradient_norm_tolerance = 1e-6`: Threshold below which gradient is considered small
- `verbose = true`: Print progress information

# Returns
- `points`: Array of points along trajectory
- `eigenvalues`: Minimum eigenvalue at each step
- `f_values`: Function values along trajectory
- `step_types`: Type of step taken at each iteration ("valley" or "gradient")
"""
function enhanced_valley_walk(f, x0; 
                              n_steps = 15, 
                              step_size = 0.01, 
                              ε_null = 1e-6,
                              gradient_step_size = 0.005, 
                              rank_deficiency_threshold = 1e-6,
                              gradient_norm_tolerance = 1e-6,
                              verbose = true)
    
    # Initialize storage
    points = [copy(x0)]
    eigenvalues = Float64[]
    f_values = [f(x0)]
    step_types = String[]
    
    x = copy(x0)
    n = length(x0)
    
    # Check initial point
    g_initial = ForwardDiff.gradient(f, x0)
    H_initial = ForwardDiff.hessian(f, x0)
    λ_initial = eigvals(H_initial)
    
    # If we're already at a minimum (small gradient and positive definite Hessian), stop immediately
    if norm(g_initial) < gradient_norm_tolerance && all(λ_initial .> rank_deficiency_threshold)
        if verbose
            println("Already at a local minimum:")
            println("  Gradient norm: $(norm(g_initial))")
            println("  Min eigenvalue: $(minimum(λ_initial)) (positive definite)")
            println("  Stopping immediately.")
        end
        # Return single point trajectory
        return [x0], [minimum(λ_initial)], [f(x0)], String[]
    end
    
    for step in 1:n_steps
        # Compute gradient and Hessian
        g = ForwardDiff.gradient(f, x)
        H = ForwardDiff.hessian(f, x)
        
        # Eigendecomposition to analyze Hessian structure
        λ, V = eigen(H)
        min_eigenval = minimum(abs.(λ))
        push!(eigenvalues, min_eigenval)
        
        # Calculate gradient norm
        gradient_norm = norm(g)
        
        # Current function value
        f_current = f(x)
        
        # Decide strategy based on gradient norm and Hessian conditioning
        if gradient_norm > gradient_norm_tolerance
            # GRADIENT DESCENT: While gradient is substantial
            push!(step_types, "gradient")
            x_new = gradient_step(f, x, g, gradient_step_size)
        elseif min_eigenval < rank_deficiency_threshold
            # VALLEY WALKING: Small gradient AND rank-deficient Hessian
            push!(step_types, "valley")
            x_new = valley_step(f, x, g, H, λ, V, step_size, ε_null)
        else
            # CONVERGED or SMALL STEPS: Small gradient but full-rank Hessian
            if verbose
                println("Small gradient (||g|| = $(round(gradient_norm, digits=8))) with full-rank Hessian")
                println("  Min eigenvalue = $(round(min_eigenval, digits=8))")
            end
            
            # Take a very small gradient step or terminate
            if step < n_steps  # Don't terminate on last step to maintain consistent output
                push!(step_types, "gradient")
                x_new = gradient_step(f, x, g, gradient_step_size * 0.1)  # Reduced step size
            else
                break  # Converged
            end
        end
        
        # Accept new point
        x = copy(x_new)
        push!(points, copy(x))
        push!(f_values, f(x))
        
        # Progress info
        if verbose
            println("Step $step ($(step_types[end])): f = $(round(f_values[end], digits=12)), ||g|| = $(round(gradient_norm, digits=8))")
        end
        
        # Check for convergence - if at a minimum with positive definite Hessian, STOP
        if gradient_norm < gradient_norm_tolerance && all(λ .> rank_deficiency_threshold)
            if verbose
                println("Converged to local minimum at step $step:")
                println("  Gradient norm: $gradient_norm")
                println("  Min eigenvalue: $min_eigenval (positive definite)")
                println("  Function value: $f_current")
            end
            # Stop the algorithm - we're at a minimum
            break
        end
    end
    
    return points, eigenvalues, f_values, step_types
end

"""
    valley_step(f, x, g, H, λ, V, step_size, ε_null)

Perform a single valley walking step.
When the gradient is small and the Hessian is rank-deficient, walk in the 
direction of the eigenvector associated with the smallest eigenvalue.
"""
function valley_step(f, x, g, H, λ, V, step_size, ε_null)
    # Identify valley directions (null/near-null space)
    valley_mask = abs.(λ) .< ε_null
    valley_indices = findall(valley_mask)
    
    if isempty(valley_indices)
        # Use direction of smallest eigenvalue (as requested)
        valley_indices = [argmin(abs.(λ))]
    end
    
    # Get valley tangent space
    V_valley = V[:, valley_indices]
    
    # Choose direction in valley
    g_valley = V_valley' * g
    if norm(g_valley) > 1e-10
        # Move down gradient within valley
        direction_valley = -g_valley / norm(g_valley)
    else
        # Random direction in valley if gradient is orthogonal
        direction_valley = randn(length(valley_indices))
        direction_valley = direction_valley / norm(direction_valley)
    end
    
    # Convert back to ambient space
    direction = V_valley * direction_valley
    
    # Take valley step
    x_new = x + step_size * direction
    
    # Project back to valley using Newton steps in normal directions
    x_new = project_to_valley(f, x_new, ε_null)
    
    return x_new
end

"""
    project_to_valley(f, x, ε_null; max_iters=3)

Project point back to valley using Newton steps in normal directions.
"""
function project_to_valley(f, x, ε_null; max_iters=3)
    x_new = copy(x)
    
    for _ in 1:max_iters
        g_proj = ForwardDiff.gradient(f, x_new)
        H_proj = ForwardDiff.hessian(f, x_new)
        λ_proj, V_proj = eigen(H_proj)
        
        # Identify normal directions (high curvature)
        normal_mask = abs.(λ_proj) .> ε_null
        if !any(normal_mask)
            break  # Already in valley
        end
        
        # Project gradient onto normal space
        V_normal = V_proj[:, normal_mask]
        λ_normal = λ_proj[normal_mask]
        g_normal = V_normal' * g_proj
        
        # Newton step in normal directions only
        δ = -V_normal * (g_normal ./ (λ_normal .+ 1e-10))
        
        # Update with line search
        α = 1.0
        f_current = f(x_new)
        for _ in 1:5
            x_test = x_new + α * δ
            if f(x_test) < f_current
                x_new = x_test
                break
            end
            α *= 0.5
        end
        
        # Check convergence
        if norm(α * δ) < 1e-10
            break
        end
    end
    
    return x_new
end

"""
    gradient_step(f, x, g, step_size)

Perform a gradient descent step with line search.
"""
function gradient_step(f, x, g, step_size)
    if norm(g) > 1e-12
        direction = -g / norm(g)
        
        # Line search for step size
        α = step_size
        f_current = f(x)
        x_new = x
        
        for _ in 1:10
            x_test = x + α * direction
            f_test = f(x_test)
            if f_test < f_current
                x_new = x_test
                break
            end
            α *= 0.7
        end
        
        # If no improvement, take small step anyway
        if x_new == x
            x_new = x + 0.001 * direction
        end
    else
        # Gradient is very small, take tiny random step
        x_new = x + 1e-6 * randn(length(x))
    end
    
    return x_new
end

"""
    analyze_valley_results(valley_results)

Analyze and summarize valley walking results.

Returns a DataFrame with summary statistics for each path.
"""
function analyze_valley_results(valley_results)
    summary_data = []
    
    for (i, result) in enumerate(valley_results)
        n_valley = count(s -> s == "valley", result.step_types)
        n_gradient = count(s -> s == "gradient", result.step_types)
        
        push!(summary_data, (
            path_id = i,
            start_point = result.start_point,
            end_point = result.points[end],
            initial_f = result.f_values[1],
            final_f = result.f_values[end],
            f_decrease = result.f_values[1] - result.f_values[end],
            path_length = length(result.points),
            valley_steps = n_valley,
            gradient_steps = n_gradient,
            min_eigenvalue = minimum(result.eigenvalues)
        ))
    end
    
    return summary_data
end

# Note: find_best_critical_point function has been removed
# Use direct DataFrame operations instead: argmin(df.z) to find best point