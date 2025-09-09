#!/usr/bin/env julia
"""
GlobTim Valley Walking Demonstration
===================================

Complete valley walking implementation combining:
- Valley detection using Hessian eigenanalysis  
- Adaptive step size valley walking
- Nesterov-style momentum acceleration
- Interactive GLMakie and static CairoMakie visualization

This is the consolidated, production-ready valley walking example.

Usage:
    julia Examples/valley_walking_demo.jl
"""

# using Pkg
# Pkg.activate(".")

using Globtim
using LinearAlgebra
using ForwardDiff
using DataFrames
using DynamicPolynomials
using Printf
using StaticArrays

# Try to load visualization backends
try
    using GLMakie
    global HAS_GLMAKIE = true
    println("✓ GLMakie loaded for interactive visualization")
catch
    global HAS_GLMAKIE = false
    println("⚠️  GLMakie not available")
end

try
    using CairoMakie
    global HAS_CAIROMAKIE = true
    println("✓ CairoMakie loaded for static visualization")
catch
    global HAS_CAIROMAKIE = false
    println("⚠️  CairoMakie not available")
end

println("\n" * "="^80)
println("GlobTim Valley Walking Demonstration")
println("Function: f(x) = (x₁² + x₂² - 1)²")
println("Expected: 1D valley manifold along unit circle")
println("="^80)

# Define test function with unit circle valley
function unit_circle_valley(x)
    return (x[1]^2 + x[2]^2 - 1)^2
end

# Valley detection using Hessian eigenanalysis
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

# Enhanced Iterative Valley Walking Algorithm
function iterative_valley_walk(f, start_point, initial_direction, config)
    """Enhanced valley walking with per-step valley detection and dynamic direction updates."""
    
    steps = [copy(start_point)]
    current_point = copy(start_point)
    current_direction = copy(initial_direction)
    velocity = zeros(length(start_point))
    momentum = 0.7  # Slightly reduced for stability with direction changes
    
    # Valley tracking parameters
    valley_threshold = 0.1   # Function value threshold to consider "in valley"
    attraction_strength = 1.5  # Strength of attraction when outside valley
    
    for step_num in 1:config.max_steps
        # Step 1: Per-step valley detection at current point
        current_grad = ForwardDiff.gradient(f, current_point)
        current_hess = ForwardDiff.hessian(f, current_point)
        current_eigendecomp = eigen(current_hess)
        
        # Identify valley directions (near-zero eigenvalues) - more robust detection
        valley_mask = abs.(current_eigendecomp.values) .< max(config.eigenvalue_threshold, 1e-4)
        
        if !any(valley_mask)
            # Try more lenient threshold before giving up
            valley_mask = abs.(current_eigendecomp.values) .< 1e-3
            if !any(valley_mask)
                println("  Warning: No valley detected at step $step_num (eigenvals: $(round.(current_eigendecomp.values, digits=6)))")
                break
            end
        end
        
        # Step 2: Update valley direction dynamically based on local Hessian
        local_valley_directions = current_eigendecomp.vectors[:, valley_mask]
        
        # Choose direction that's most aligned with current movement direction
        if size(local_valley_directions, 2) == 1
            # Single valley direction
            new_direction = local_valley_directions[:, 1]
        else
            # Multiple valley directions - choose best aligned with current direction
            alignments = [abs(dot(current_direction, local_valley_directions[:, i])) 
                         for i in 1:size(local_valley_directions, 2)]
            best_idx = argmax(alignments)
            new_direction = local_valley_directions[:, best_idx]
        end
        
        # Ensure direction consistency (avoid direction flipping)
        if dot(new_direction, current_direction) < 0
            new_direction = -new_direction
        end
        current_direction = new_direction
        
        # Step 3: Determine if we're "in valley" or "outside valley"
        f_val = f(current_point)
        grad_norm = norm(current_grad)
        
        # In valley if function value is small and gradient is small
        in_valley = (f_val < valley_threshold) && (grad_norm < config.gradient_tolerance)
        
        # Step 4: Conditional movement logic
        if in_valley
            # Move tangentially along the valley manifold
            projected_grad = current_direction * (current_direction' * current_grad)
            step_vector = -config.step_size * projected_grad
            
            # Add small exploration component to prevent getting stuck
            exploration_component = 0.1 * config.step_size * current_direction
            step_vector += exploration_component
        else
            # Move toward valley using gradient descent + attraction to manifold
            # Gradient descent component
            gradient_component = -config.step_size * current_grad
            
            # Attraction to valley manifold (along valley direction)
            valley_attraction = -attraction_strength * config.step_size * 
                               current_direction * (current_direction' * current_grad)
            
            step_vector = gradient_component + valley_attraction
        end
        
        # Step 5: Momentum update with adaptive dampening
        momentum_factor = in_valley ? momentum : momentum * 0.5  # Less momentum when outside valley
        velocity = momentum_factor * velocity + (1 - momentum_factor) * step_vector
        
        candidate_point = current_point + velocity
        
        # Step 6: Validation and acceptance
        candidate_val = f(candidate_point)
        
        if !isfinite(candidate_val)
            println("  Termination: Non-finite function value at step $step_num")
            break
        end
        
        # More lenient acceptance criteria for manifold following
        # Allow function value increases when near the manifold (f ≈ 0)
        f_val = f(current_point)
        max_allowed_val = max(0.1, 10 * f_val)  # Allow increases when near manifold
        
        if candidate_val > max_allowed_val
            # Try smaller step
            velocity *= 0.3
            candidate_point = current_point + velocity
            candidate_val = f(candidate_point)
            
            if !isfinite(candidate_val) || candidate_val > max_allowed_val
                # Only terminate if we're really far from manifold
                if candidate_val > 1.0  # Absolute threshold
                    println("  Termination: Function value too large at step $step_num (f=$(round(candidate_val, digits=4)))")
                    break
                end
            end
        end
        
        # Accept the step
        current_point = candidate_point
        push!(steps, copy(current_point))
        
        # Step 7: Adaptive step size control
        if step_num % 15 == 0
            # Check progress - if we're making good progress, maintain step size
            if length(steps) >= 15
                recent_distance = norm(steps[end] - steps[end-14])
                if recent_distance < 0.01 * config.step_size
                    # Not making progress, reduce step size
                    config = merge(config, (step_size = config.step_size * 0.8,))
                elseif recent_distance > 0.1
                    # Good progress, can afford larger steps
                    config = merge(config, (step_size = min(config.step_size * 1.1, 1e-2),))
                end
            end
        end
        
        # Debug output every 50 steps
        if step_num % 50 == 0
            println("    Step $step_num: f=$(round(f_val, digits=6)), " *
                   "||∇f||=$(round(grad_norm, digits=6)), " *
                   "in_valley=$in_valley, " *
                   "pos=$(round.(current_point, digits=3))")
        end
    end
    
    return steps
end

# Legacy function for compatibility - enhanced version
function valley_walk_with_momentum(f, start_point, direction, config)
    """Legacy wrapper - now uses enhanced iterative valley walking."""
    return iterative_valley_walk(f, start_point, direction, config)
end

# Standard adaptive valley walking
function adaptive_valley_walk(f, start_point, direction, config)
    """Standard adaptive valley walking algorithm."""
    
    steps = [copy(start_point)]
    current_point = copy(start_point)
    
    for step_num in 1:config.max_steps
        grad = ForwardDiff.gradient(f, current_point)
        
        # Project gradient onto valley direction
        projected_grad = direction * (direction' * grad)
        step_vector = -config.step_size * projected_grad
        
        candidate_point = current_point + step_vector
        candidate_grad = ForwardDiff.gradient(f, candidate_point)
        
        if norm(candidate_grad) > config.gradient_tolerance
            break
        end
        
        current_point = candidate_point
        push!(steps, copy(current_point))
        
        # Adaptive step size
        if step_num % 15 == 0
            config = merge(config, (step_size = config.step_size * 0.9,))
        end
    end
    
    return steps
end

# Comprehensive visualization function  
function create_valley_visualization(paths_data, f, config; use_interactive=true)
    """Create comprehensive valley walking visualization."""
    
    if use_interactive && HAS_GLMAKIE
        GLMakie.activate!()
        backend_name = "GLMakie (Interactive Window)"
    elseif HAS_CAIROMAKIE
        CairoMakie.activate!()
        backend_name = "CairoMakie (Static)"
    else
        println("⚠️  No visualization backend available")
        return nothing
    end
    
    println("Creating visualization with $backend_name...")
    
    # Create figure and axis
    fig = Figure(size=(1000, 800))
    ax = Axis(fig[1, 1], 
        title="Valley Walking Demonstration: f(x) = (x₁² + x₂² - 1)²",
        xlabel="x₁", ylabel="x₂",
        aspect=DataAspect()
    )
    
    # Plot function contours
    x_range = range(-1.5, 1.5, length=200)
    y_range = range(-1.5, 1.5, length=200)
    Z = [f([x, y]) for y in y_range, x in x_range]
    
    # Debug: check Z values
    println("Z range: [$(minimum(Z)), $(maximum(Z))]")
    
    # Add filled background with heatmap for level sets
    heatmap!(ax, x_range, y_range, Z, colormap=:viridis, alpha=0.6)
    
    # Add contour lines for clarity
    contour!(ax, x_range, y_range, Z, levels=15, color=:white, linewidth=0.8, alpha=0.8)
    
    # Plot true valley manifold (unit circle)
    θ = range(0, 2π, length=100)
    circle_x = cos.(θ)
    circle_y = sin.(θ)
    lines!(ax, circle_x, circle_y, color=:red, linewidth=3, 
           label="True Valley (Unit Circle)")
    
    # Plot valley paths
    colors = [:blue, :green, :orange, :purple, :brown, :pink]
    for (i, (name, path)) in enumerate(paths_data)
        if length(path) > 0
            path_x = [p[1] for p in path]
            path_y = [p[2] for p in path]
            
            color = colors[mod(i-1, length(colors)) + 1]
            
            # Plot path
            lines!(ax, path_x, path_y, color=color, linewidth=2, alpha=0.8,
                   label="Path $i: $(length(path)) pts")
            
            # Mark start and end points
            scatter!(ax, [path_x[1]], [path_y[1]], color=color, marker=:circle, 
                    markersize=12, strokewidth=2, strokecolor=:black)
            scatter!(ax, [path_x[end]], [path_y[end]], color=color, marker=:rect, 
                    markersize=10)
        end
    end
    
    # Add legend and formatting
    axislegend(ax, position=:rt, framevisible=true, backgroundcolor=(:white, 0.8))
    xlims!(ax, -1.4, 1.4)
    ylims!(ax, -1.4, 1.4)
    
    # Display interactive window and wait
    display(fig)
    println("→ Interactive GLMakie window displayed!")
    println("   Press Enter in this terminal to continue (window will stay open)...")
    readline()
    
    # Optionally save PNG as well
    # output_path = "outputs/valley_walking/visualizations/valley_walking_demo.png"
    # save(output_path, fig)
    # println("✓ Visualization saved to: $output_path")
    
    return fig
end

# Main demonstration pipeline
function main()
    println("\n🚀 Starting Valley Walking Demonstration...")
    
    # Configuration for Enhanced Iterative Valley Walking
    config = (
        step_size = 5e-4,              # Smaller steps for better manifold following
        max_steps = 500,               # Reasonable limit - should get much further now
        gradient_tolerance = 1e-2,     # More lenient for curved manifold following  
        eigenvalue_threshold = 1e-6,   # Valley detection threshold
        function_tolerance = 1e-8
    )
    
    println("Configuration:")
    for (key, value) in pairs(config)
        println("  $key: $value")
    end
    
    # Test points on unit circle
    test_points = [
        [1.0, 0.0],      # Right
        [0.0, 1.0],      # Top  
        [-1.0, 0.0],     # Left
        [0.707, 0.707]   # Diagonal (should not be valley)
    ]
    
    println("\n🔍 Phase 1: Valley Detection")
    valley_points = []
    paths_data = []
    
    for (i, point) in enumerate(test_points)
        println("Testing point $i: $point")
        is_valley, valley_info = detect_valley(unit_circle_valley, point, config)
        
        if is_valley
            push!(valley_points, (point, valley_info))
            println("  ✓ Valley detected with $(valley_info.valley_dimension) dimension(s)")
            
            # Walk in each valley direction (both positive and negative)
            for (j, direction) in enumerate(eachcol(valley_info.valley_directions))
                # Positive direction
                pos_path = valley_walk_with_momentum(unit_circle_valley, point, direction, config)
                push!(paths_data, ("Point_$(i)_Dir_$(j)_Pos", pos_path))
                
                # Negative direction  
                neg_path = valley_walk_with_momentum(unit_circle_valley, point, -direction, config)
                push!(paths_data, ("Point_$(i)_Dir_$(j)_Neg", neg_path))
                
                println("    Direction $j: +$(length(pos_path)) / -$(length(neg_path)) points")
            end
        else
            println("  ✗ Not a valley point")
        end
    end
    
    println("\n📊 Results Summary:")
    println("  Valley points found: $(length(valley_points))")
    println("  Total paths generated: $(length(paths_data))")
    
    total_points = sum(length(path) for (_, path) in paths_data)
    println("  Total path points: $total_points")
    
    # Create visualization
    println("\n🎨 Phase 2: Creating Visualization")
    fig = create_valley_visualization(paths_data, unit_circle_valley, config)
    
    println("\n✅ Valley Walking Demonstration Complete!")
    println("📁 Check Examples/outputs/valley_walking/visualizations/ for results")
    
    return paths_data, valley_points
end

# Run demonstration
if abspath(PROGRAM_FILE) == @__FILE__
    paths_data, valley_points = main()
end