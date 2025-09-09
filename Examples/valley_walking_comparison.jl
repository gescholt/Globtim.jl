#!/usr/bin/env julia
"""
Valley Walking Algorithm Comparison
===================================

Compare the old fixed-direction approach vs the new iterative valley tracking.
This script tests both algorithms and provides side-by-side results.
"""

using Globtim
using LinearAlgebra
using ForwardDiff
using Printf

# Test function: unit circle valley
function unit_circle_valley(x)
    return (x[1]^2 + x[2]^2 - 1)^2
end

# Valley detection (shared between both algorithms)
function detect_valley(f, point, config)
    grad = ForwardDiff.gradient(f, point)
    hess = ForwardDiff.hessian(f, point)
    eigenvals = eigvals(hess)
    
    grad_norm = norm(grad)
    valley_dimension = sum(abs.(eigenvals) .< config.eigenvalue_threshold)
    is_valley = grad_norm < config.gradient_tolerance && valley_dimension > 0
    
    if is_valley
        eigendecomp = eigen(hess)
        valley_mask = abs.(eigendecomp.values) .< config.eigenvalue_threshold
        valley_directions = eigendecomp.vectors[:, valley_mask]
        
        return true, (
            valley_dimension = valley_dimension,
            valley_directions = valley_directions,
            eigenvalues = eigenvals,
            gradient_norm = grad_norm
        )
    else
        return false, nothing
    end
end

# OLD ALGORITHM: Fixed direction approach
function old_valley_walk(f, start_point, direction, config)
    """Original fixed-direction valley walking (for comparison)."""
    
    steps = [copy(start_point)]
    current_point = copy(start_point)
    
    for step_num in 1:min(config.max_steps, 100)  # Limit for comparison
        grad = ForwardDiff.gradient(f, current_point)
        
        # FIXED direction (this is the limitation)
        projected_grad = direction * (direction' * grad)
        step_vector = -config.step_size * projected_grad
        
        candidate_point = current_point + step_vector
        candidate_grad = ForwardDiff.gradient(f, candidate_point)
        
        # Strict termination criteria (this causes early termination)
        if norm(candidate_grad) > config.gradient_tolerance
            break
        end
        
        current_point = candidate_point
        push!(steps, copy(current_point))
    end
    
    return steps
end

# NEW ALGORITHM: Enhanced iterative valley tracking
function enhanced_valley_walk(f, start_point, initial_direction, config)
    """Enhanced valley walking with per-step valley detection and dynamic direction updates."""
    
    steps = [copy(start_point)]
    current_point = copy(start_point)
    current_direction = copy(initial_direction)
    velocity = zeros(length(start_point))
    momentum = 0.7
    
    # Valley tracking parameters
    valley_threshold = 0.1
    attraction_strength = 1.5
    
    for step_num in 1:config.max_steps
        # Step 1: Per-step valley detection
        current_grad = ForwardDiff.gradient(f, current_point)
        current_hess = ForwardDiff.hessian(f, current_point)
        current_eigendecomp = eigen(current_hess)
        
        # More robust valley detection
        valley_mask = abs.(current_eigendecomp.values) .< max(config.eigenvalue_threshold, 1e-4)
        
        if !any(valley_mask)
            valley_mask = abs.(current_eigendecomp.values) .< 1e-3
            if !any(valley_mask)
                break
            end
        end
        
        # Step 2: Update valley direction dynamically
        local_valley_directions = current_eigendecomp.vectors[:, valley_mask]
        
        if size(local_valley_directions, 2) == 1
            new_direction = local_valley_directions[:, 1]
        else
            alignments = [abs(dot(current_direction, local_valley_directions[:, i])) 
                         for i in 1:size(local_valley_directions, 2)]
            best_idx = argmax(alignments)
            new_direction = local_valley_directions[:, best_idx]
        end
        
        # Ensure direction consistency
        if dot(new_direction, current_direction) < 0
            new_direction = -new_direction
        end
        current_direction = new_direction
        
        # Step 3: Conditional movement logic
        f_val = f(current_point)
        grad_norm = norm(current_grad)
        in_valley = (f_val < valley_threshold) && (grad_norm < config.gradient_tolerance)
        
        if in_valley
            # Move tangentially along valley manifold
            projected_grad = current_direction * (current_direction' * current_grad)
            step_vector = -config.step_size * projected_grad
            exploration_component = 0.1 * config.step_size * current_direction
            step_vector += exploration_component
        else
            # Move toward valley with attraction
            gradient_component = -config.step_size * current_grad
            valley_attraction = -attraction_strength * config.step_size * 
                               current_direction * (current_direction' * current_grad)
            step_vector = gradient_component + valley_attraction
        end
        
        # Step 4: Momentum update
        momentum_factor = in_valley ? momentum : momentum * 0.5
        velocity = momentum_factor * velocity + (1 - momentum_factor) * step_vector
        candidate_point = current_point + velocity
        
        # Step 5: Lenient validation
        candidate_val = f(candidate_point)
        
        if !isfinite(candidate_val)
            break
        end
        
        f_val = f(current_point)
        max_allowed_val = max(0.1, 10 * f_val)
        
        if candidate_val > max_allowed_val
            velocity *= 0.3
            candidate_point = current_point + velocity
            candidate_val = f(candidate_point)
            
            if !isfinite(candidate_val) || candidate_val > max_allowed_val
                if candidate_val > 1.0
                    break
                end
            end
        end
        
        # Accept step
        current_point = candidate_point
        push!(steps, copy(current_point))
    end
    
    return steps
end

function compare_algorithms()
    println("🔬 Valley Walking Algorithm Comparison")
    println("=" ^ 80)
    
    # Configuration
    config = (
        step_size = 5e-4,
        max_steps = 200,
        gradient_tolerance = 1e-2,
        eigenvalue_threshold = 1e-6,
        function_tolerance = 1e-8
    )
    
    println("Configuration:")
    for (key, value) in pairs(config)
        println("  $key: $value")
    end
    
    # Test point
    test_point = [1.0, 0.0]
    is_valley, valley_info = detect_valley(unit_circle_valley, test_point, config)
    
    if !is_valley
        println("❌ Test point not detected as valley!")
        return
    end
    
    direction = valley_info.valley_directions[:, 1]
    println("\n📍 Testing from point: $test_point")
    println("🧭 Initial direction: $(round.(direction, digits=4))")
    
    # Test OLD algorithm
    println("\n🔄 Testing OLD Algorithm (Fixed Direction)...")
    old_path_pos = old_valley_walk(unit_circle_valley, test_point, direction, config)
    old_path_neg = old_valley_walk(unit_circle_valley, test_point, -direction, config)
    
    # Test NEW algorithm  
    println("🚀 Testing NEW Algorithm (Iterative Valley Tracking)...")
    new_path_pos = enhanced_valley_walk(unit_circle_valley, test_point, direction, config)
    new_path_neg = enhanced_valley_walk(unit_circle_valley, test_point, -direction, config)
    
    # Results comparison
    println("\n📊 COMPARISON RESULTS")
    println("=" ^ 50)
    
    old_total = length(old_path_pos) + length(old_path_neg)
    new_total = length(new_path_pos) + length(new_path_neg)
    improvement = round(new_total / old_total, digits=2)
    
    println("OLD Algorithm (Fixed Direction):")
    println("  Positive direction: $(length(old_path_pos)) points")
    println("  Negative direction: $(length(old_path_neg)) points")
    println("  TOTAL: $old_total points")
    
    println("\nNEW Algorithm (Iterative Valley Tracking):")
    println("  Positive direction: $(length(new_path_pos)) points")
    println("  Negative direction: $(length(new_path_neg)) points")
    println("  TOTAL: $new_total points")
    
    println("\n🎯 IMPROVEMENT: $(improvement)x more points!")
    
    # Analysis of endpoints
    println("\n🎯 PATH ANALYSIS")
    println("-" ^ 30)
    
    if length(old_path_pos) > 1
        old_end = old_path_pos[end]
        old_distance = norm(old_end - test_point)
        println("OLD final position: $(round.(old_end, digits=4)) (distance: $(round(old_distance, digits=4)))")
    end
    
    if length(new_path_pos) > 1
        new_end = new_path_pos[end]
        new_distance = norm(new_end - test_point)
        println("NEW final position: $(round.(new_end, digits=4)) (distance: $(round(new_distance, digits=4)))")
    end
    
    return (
        old_results = (pos=old_path_pos, neg=old_path_neg, total=old_total),
        new_results = (pos=new_path_pos, neg=new_path_neg, total=new_total),
        improvement_factor = improvement
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    results = compare_algorithms()
end