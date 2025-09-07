"""
    InteractiveVizCore.jl

Core data structures and analysis functions for Issue #50 Advanced Interactive Visualization.
These functions work without GLMakie dependencies and provide the computational foundation
for the interactive visualization features.

Author: GlobTim Team  
Date: September 2025
"""

using StaticArrays
using LinearAlgebra
using DataStructures
using Parameters
using Statistics
using ForwardDiff

# Export main types and analysis functions
export InteractiveVizConfig, AlgorithmTracker, ConvergenceMetrics
export analyze_convergence, hessian_eigenvalue_analysis, momentum_enhanced_tracking
export algorithm_performance_comparison, update_algorithm_tracker!
export create_gradient_field_data

"""
Configuration for interactive visualization features
"""
@with_kw struct InteractiveVizConfig
    # Display settings
    figure_size::Tuple{Int,Int} = (1400, 1000)
    update_interval::Float64 = 0.05  # seconds between updates
    max_history::Int = 1000  # maximum points to track
    
    # Algorithm analysis
    show_convergence_metrics::Bool = true
    show_gradient_field::Bool = true
    show_momentum_vectors::Bool = true
    show_hessian_analysis::Bool = false
    
    # Interaction features
    enable_click_to_set::Bool = true
    enable_runtime_params::Bool = true
    enable_algorithm_racing::Bool = false
    
    # Visualization style
    trajectory_alpha::Float64 = 0.7
    gradient_arrow_scale::Float64 = 0.1
    momentum_arrow_scale::Float64 = 0.2
    contour_levels::Int = 20
end

"""
Real-time algorithm performance tracking
"""
mutable struct AlgorithmTracker
    # Algorithm identification
    name::String
    color::Symbol
    
    # Trajectory data
    positions::Vector{Vector{Float64}}
    function_values::Vector{Float64}
    gradients::Vector{Vector{Float64}}
    step_sizes::Vector{Float64}
    
    # Performance metrics
    iteration_count::Int
    convergence_rate::Float64
    total_distance::Float64
    current_momentum::Vector{Float64}
    
    # Hessian analysis (if available)
    eigenvalues::Vector{Vector{Float64}}
    valley_dimensions::Vector{Int}
    
    function AlgorithmTracker(name::String, color::Symbol = :blue)
        new(name, color, 
            Vector{Vector{Float64}}(),
            Float64[], Vector{Vector{Float64}}(), Float64[],
            0, 0.0, 0.0, Float64[],
            Vector{Vector{Float64}}(), Int[])
    end
end

"""
Convergence analysis metrics for real-time display
"""
struct ConvergenceMetrics
    iteration::Int
    function_value::Float64
    gradient_norm::Float64
    step_size::Float64
    convergence_rate::Float64
    distance_from_start::Float64
    momentum_magnitude::Float64
    valley_dimension::Int
    dominant_eigenvalues::Vector{Float64}
end

"""
    update_algorithm_tracker!(tracker::AlgorithmTracker, position::Vector{Float64}, 
                             gradient::Vector{Float64}, step_size::Float64, function_value::Float64)

Update algorithm tracker with new iteration data.
"""
function update_algorithm_tracker!(tracker::AlgorithmTracker, position::Vector{Float64}, 
                                  gradient::Vector{Float64}, step_size::Float64, 
                                  function_value::Float64 = NaN)
    # Add new data
    push!(tracker.positions, copy(position))
    push!(tracker.gradients, copy(gradient))
    push!(tracker.step_sizes, step_size)
    
    if !isnan(function_value)
        push!(tracker.function_values, function_value)
    end
    
    # Update performance metrics
    tracker.iteration_count += 1
    
    if length(tracker.positions) > 1
        # Calculate distance traveled
        prev_pos = tracker.positions[end-1]
        current_pos = tracker.positions[end]
        distance = norm(current_pos - prev_pos)
        tracker.total_distance += distance
        
        # Estimate convergence rate (simplified)
        if length(tracker.function_values) >= 2
            prev_val = tracker.function_values[end-1]
            current_val = tracker.function_values[end]
            if prev_val != 0.0
                tracker.convergence_rate = abs(current_val - prev_val) / abs(prev_val)
            end
        end
    end
    
    # Update momentum (exponential moving average of recent steps)
    if length(tracker.positions) >= 2
        recent_step = position - tracker.positions[end-1]
        alpha = 0.9  # momentum decay factor
        if isempty(tracker.current_momentum)
            tracker.current_momentum = recent_step
        else
            tracker.current_momentum = alpha * tracker.current_momentum + (1-alpha) * recent_step
        end
    end
end

"""
    analyze_convergence(tracker::AlgorithmTracker) -> ConvergenceMetrics

Analyze convergence properties of an algorithm tracker.
"""
function analyze_convergence(tracker::AlgorithmTracker)
    if tracker.iteration_count == 0
        return ConvergenceMetrics(0, NaN, NaN, NaN, NaN, NaN, NaN, 0, Float64[])
    end
    
    # Get latest metrics
    iteration = tracker.iteration_count
    function_value = isempty(tracker.function_values) ? NaN : tracker.function_values[end]
    gradient_norm = isempty(tracker.gradients) ? NaN : norm(tracker.gradients[end])
    step_size = isempty(tracker.step_sizes) ? NaN : tracker.step_sizes[end]
    convergence_rate = tracker.convergence_rate
    distance_from_start = tracker.total_distance
    momentum_magnitude = isempty(tracker.current_momentum) ? NaN : norm(tracker.current_momentum)
    
    # Hessian analysis (if available)
    valley_dimension = isempty(tracker.valley_dimensions) ? 0 : tracker.valley_dimensions[end]
    dominant_eigenvals = isempty(tracker.eigenvalues) ? Float64[] : tracker.eigenvalues[end]
    
    return ConvergenceMetrics(
        iteration, function_value, gradient_norm, step_size,
        convergence_rate, distance_from_start, momentum_magnitude,
        valley_dimension, dominant_eigenvals
    )
end

"""
    hessian_eigenvalue_analysis(objective_function, point::Vector{Float64})

Perform Hessian eigenvalue analysis at a given point for valley detection.
"""
function hessian_eigenvalue_analysis(objective_function, point::Vector{Float64})
    # Compute Hessian using ForwardDiff
    hessian = ForwardDiff.hessian(objective_function, point)
    
    # Eigenvalue decomposition
    eigenvals, eigenvecs = eigen(hessian)
    
    # Sort by eigenvalue magnitude
    sorted_indices = sortperm(abs.(eigenvals))
    sorted_eigenvals = eigenvals[sorted_indices]
    sorted_eigenvecs = eigenvecs[:, sorted_indices]
    
    # Valley detection: count near-zero eigenvalues
    eigenval_threshold = 1e-6
    near_zero_count = sum(abs.(sorted_eigenvals) .< eigenval_threshold)
    
    return (
        eigenvalues = sorted_eigenvals,
        eigenvectors = sorted_eigenvecs,
        valley_dimension = near_zero_count,
        condition_number = maximum(abs.(sorted_eigenvals)) / maximum(abs.(sorted_eigenvals[abs.(sorted_eigenvals) .> 1e-12]))
    )
end

"""
    momentum_enhanced_tracking(tracker::AlgorithmTracker, new_position::Vector{Float64})

Enhanced momentum tracking for momentum-based optimization methods.
"""
function momentum_enhanced_tracking(tracker::AlgorithmTracker, new_position::Vector{Float64})
    if length(tracker.positions) >= 2
        # Compute velocity (recent step)
        prev_pos = tracker.positions[end-1]
        current_velocity = new_position - prev_pos
        
        # Update momentum with exponential moving average
        beta = 0.9  # momentum decay factor
        if isempty(tracker.current_momentum)
            tracker.current_momentum = current_velocity
        else
            tracker.current_momentum = beta * tracker.current_momentum + (1-beta) * current_velocity
        end
        
        # Compute acceleration (change in velocity)
        if length(tracker.positions) >= 3
            prev_prev_pos = tracker.positions[end-2]
            prev_velocity = prev_pos - prev_prev_pos
            acceleration = current_velocity - prev_velocity
            
            # Store acceleration information (could be used for adaptive methods)
            if !hasfield(typeof(tracker), :acceleration_history)
                # We can add this to the struct later if needed
                # tracker.acceleration_history = Vector{Vector{Float64}}()
            end
            # push!(tracker.acceleration_history, acceleration)
        end
    end
end

"""
    algorithm_performance_comparison(trackers::Dict{String, AlgorithmTracker})

Generate performance comparison metrics for multiple algorithms.
"""
function algorithm_performance_comparison(trackers::Dict{String, AlgorithmTracker})
    comparison_metrics = Dict{String, Dict{String, Float64}}()
    
    for (name, tracker) in trackers
        metrics = Dict{String, Float64}()
        
        # Convergence speed (iterations to reach target)
        if !isempty(tracker.function_values)
            # Find iteration where function value drops below threshold
            target_threshold = minimum(tracker.function_values) * 10.0  # 10x above minimum
            convergence_iter = findfirst(val -> val <= target_threshold, tracker.function_values)
            metrics["convergence_iterations"] = convergence_iter === nothing ? Inf : Float64(convergence_iter)
        else
            metrics["convergence_iterations"] = Inf
        end
        
        # Path efficiency (straight-line distance vs. actual path length)
        if length(tracker.positions) >= 2
            straight_distance = norm(tracker.positions[end] - tracker.positions[1])
            path_efficiency = straight_distance / max(tracker.total_distance, 1e-12)
            metrics["path_efficiency"] = path_efficiency
        else
            metrics["path_efficiency"] = 0.0
        end
        
        # Final function value
        metrics["final_function_value"] = isempty(tracker.function_values) ? Inf : tracker.function_values[end]
        
        # Average step size
        metrics["average_step_size"] = isempty(tracker.step_sizes) ? 0.0 : mean(tracker.step_sizes)
        
        # Gradient norm reduction
        if length(tracker.gradients) >= 2
            initial_grad_norm = norm(tracker.gradients[1])
            final_grad_norm = norm(tracker.gradients[end])
            metrics["gradient_reduction_factor"] = initial_grad_norm / max(final_grad_norm, 1e-16)
        else
            metrics["gradient_reduction_factor"] = 1.0
        end
        
        comparison_metrics[name] = metrics
    end
    
    return comparison_metrics
end

"""
    create_gradient_field_data(objective_function, x_range, y_range; density=10)

Create gradient vector field data for visualization (does not require GLMakie).
"""
function create_gradient_field_data(objective_function, x_range, y_range; density=10)
    # Create grid points
    x_points = range(x_range[1], x_range[2], length = density)
    y_points = range(y_range[1], y_range[2], length = density)
    
    points = []
    directions = []
    magnitudes = []
    
    for x in x_points, y in y_points
        point = [x, y]
        gradient = ForwardDiff.gradient(objective_function, point)
        
        # Store gradient information
        grad_norm = norm(gradient)
        if grad_norm > 1e-12
            direction = -gradient / grad_norm  # Point toward decrease
            push!(points, [x, y])
            push!(directions, direction)
            push!(magnitudes, grad_norm)
        end
    end
    
    return (points = points, directions = directions, magnitudes = magnitudes)
end

# These functions will be implemented in the GLMakie extension
# Stub functions for interface compatibility
function create_interactive_viz end
function update_visualization end
function gradient_field_viz end
function hessian_eigenvalue_viz end
function momentum_vector_viz end
function multi_algorithm_comparison end
function parameter_exploration_interface end