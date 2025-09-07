"""
    InteractiveViz.jl

Advanced Interactive Visualization Framework for Mathematical Algorithms
Implements Issue #50: Advanced Interactive Visualization Features

Core Features:
- Real-time algorithm analysis with convergence metrics
- Dynamic gradient vector field visualization
- Multi-algorithm comparison interface
- Interactive parameter exploration
- Educational tools with step-by-step analysis

Author: GlobTim Team
Date: September 2025
"""

using StaticArrays
using LinearAlgebra
using DataStructures
using Parameters
using Statistics
using ForwardDiff

# GLMakie is optional - loaded through extension system
# Define interface that will be implemented in GLMakie extension

# Export main types and functions
export InteractiveVizConfig, AlgorithmTracker, ConvergenceMetrics
export create_interactive_viz, update_visualization, analyze_convergence
export gradient_field_viz, hessian_eigenvalue_viz, momentum_vector_viz
export multi_algorithm_comparison, parameter_exploration_interface

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
    create_interactive_viz(objective_function, config::InteractiveVizConfig)

Create the main interactive visualization interface with all advanced features.
This is a stub function - actual implementation provided by GLMakie extension.
"""
function create_interactive_viz(objective_function, config::InteractiveVizConfig = InteractiveVizConfig())
    error("Interactive visualization requires GLMakie. Please load GLMakie before using this function.")
    
    # Main optimization landscape (large central panel)
    ax_main = Axis(fig[1:2, 1:3], 
                   title = "Interactive Optimization Landscape",
                   xlabel = "x₁", ylabel = "x₂")
    
    # Convergence metrics panel (right side)
    ax_convergence = Axis(fig[1, 4], 
                         title = "Convergence Analysis",
                         xlabel = "Iteration", ylabel = "Function Value")
    
    # Gradient analysis panel
    ax_gradient = Axis(fig[2, 4],
                      title = "Gradient Analysis", 
                      xlabel = "Iteration", ylabel = "Gradient Norm")
    
    # Algorithm comparison panel (bottom)
    ax_comparison = Axis(fig[3, 1:2],
                        title = "Algorithm Comparison",
                        xlabel = "Iteration", ylabel = "Performance Score")
    
    # Control panel space (bottom right)
    control_grid = GridLayout(fig[3, 3:4])
    
    # Initialize visualization components
    viz_state = Dict(
        :fig => fig,
        :axes => (main = ax_main, conv = ax_convergence, grad = ax_gradient, comp = ax_comparison),
        :trackers => Dict{String, AlgorithmTracker}(),
        :objective => objective_function,
        :config => config,
        :observables => create_observables(),
        :contour_plot => nothing,
        :gradient_field => nothing
    )
    
    # Set up base visualization elements
    setup_base_visualization!(viz_state)
    setup_interactive_controls!(viz_state, control_grid)
    
    return viz_state
end

"""
Create observables for reactive updates
"""
function create_observables()
    return Dict(
        :current_point => Observable(Point2f(0.0, 0.0)),
        :show_gradients => Observable(true),
        :show_momentum => Observable(true),
        :algorithm_speed => Observable(1.0),
        :contour_opacity => Observable(0.6),
        :selected_algorithms => Observable(String[])
    )
end

"""
Set up the base visualization with contours and coordinate system
"""
function setup_base_visualization!(viz_state)
    ax_main = viz_state[:axes].main
    objective = viz_state[:objective]
    config = viz_state[:config]
    
    # Create coordinate grid for contour plotting
    x_range = range(-2.0, 2.0, length = 100)
    y_range = range(-2.0, 2.0, length = 100)
    
    # Evaluate function over grid
    Z = [objective([x, y]) for x in x_range, y in y_range]
    
    # Create contour plot with customizable levels
    contour_plot = contour!(ax_main, x_range, y_range, Z, 
                           levels = config.contour_levels,
                           alpha = viz_state[:observables][:contour_opacity])
    
    viz_state[:contour_plot] = contour_plot
    
    # Set up click-to-set functionality
    if config.enable_click_to_set
        setup_click_interaction!(viz_state)
    end
end

"""
Set up interactive click-to-set starting points
"""
function setup_click_interaction!(viz_state)
    ax_main = viz_state[:axes].main
    current_point = viz_state[:observables][:current_point]
    
    # Create marker for current point
    current_marker = scatter!(ax_main, current_point,
                             color = :red, markersize = 15, 
                             marker = :circle, strokewidth = 2)
    
    # Set up mouse click event
    on(events(viz_state[:fig]).mousebutton) do event
        if event.button == Mouse.left && event.action == Mouse.press
            # Get click position in data coordinates
            pos = mouseposition(ax_main.scene)
            current_point[] = Point2f(pos[1], pos[2])
            
            # Trigger algorithm restart from new position
            restart_algorithms_from_point!(viz_state, [pos[1], pos[2]])
        end
    end
end

"""
Set up interactive control panel with sliders and toggles
"""
function setup_interactive_controls!(viz_state, grid)
    config = viz_state[:config]
    obs = viz_state[:observables]
    
    # Algorithm speed control
    Label(grid[1, 1], "Algorithm Speed:")
    speed_slider = Slider(grid[1, 2], range = 0.1:0.1:5.0, startvalue = 1.0)
    connect!(obs[:algorithm_speed], speed_slider.value)
    
    # Gradient field toggle
    Label(grid[2, 1], "Show Gradients:")
    grad_toggle = Toggle(grid[2, 2], active = true)
    connect!(obs[:show_gradients], grad_toggle.active)
    
    # Momentum vector toggle
    Label(grid[3, 1], "Show Momentum:")
    momentum_toggle = Toggle(grid[3, 2], active = true)
    connect!(obs[:show_momentum], momentum_toggle.active)
    
    # Contour opacity control
    Label(grid[4, 1], "Contour Opacity:")
    opacity_slider = Slider(grid[4, 2], range = 0.0:0.1:1.0, startvalue = 0.6)
    connect!(obs[:contour_opacity], opacity_slider.value)
    
    # Algorithm selection (for multi-algorithm comparison)
    if config.enable_algorithm_racing
        Label(grid[5, 1], "Active Algorithms:")
        algorithm_menu = Menu(grid[5, 2], 
                             options = ["Valley Walking", "Momentum Enhanced", "Adaptive Step"],
                             default = "Valley Walking")
    end
end

"""
    add_algorithm_tracker!(viz_state, tracker::AlgorithmTracker)

Add a new algorithm to track in the visualization.
"""
function add_algorithm_tracker!(viz_state, tracker::AlgorithmTracker)
    viz_state[:trackers][tracker.name] = tracker
    
    # Set up visualization elements for this tracker
    setup_tracker_visualization!(viz_state, tracker)
end

"""
Set up visualization elements for a specific algorithm tracker
"""
function setup_tracker_visualization!(viz_state, tracker::AlgorithmTracker)
    ax_main = viz_state[:axes].main
    
    # Create trajectory line (initially empty)
    trajectory_observable = Observable(Point2f[])
    lines!(ax_main, trajectory_observable, 
           color = tracker.color, linewidth = 2, alpha = viz_state[:config].trajectory_alpha)
    
    # Create current position marker
    current_pos_observable = Observable(Point2f(0.0, 0.0))
    scatter!(ax_main, current_pos_observable,
             color = tracker.color, markersize = 12, marker = :circle)
    
    # Store observables for updates
    tracker_viz = Dict(
        :trajectory => trajectory_observable,
        :current_pos => current_pos_observable,
        :gradient_arrows => nothing,
        :momentum_arrow => nothing
    )
    
    # Add to visualization state
    if !haskey(viz_state, :tracker_viz)
        viz_state[:tracker_viz] = Dict{String, Any}()
    end
    viz_state[:tracker_viz][tracker.name] = tracker_viz
end

"""
    update_algorithm_tracker!(tracker::AlgorithmTracker, position::Vector{Float64}, 
                             gradient::Vector{Float64}, step_size::Float64)

Update algorithm tracker with new iteration data.
"""
function update_algorithm_tracker!(tracker::AlgorithmTracker, position::Vector{Float64}, 
                                  gradient::Vector{Float64}, step_size::Float64)
    # Add new data
    push!(tracker.positions, copy(position))
    push!(tracker.gradients, copy(gradient))
    push!(tracker.step_sizes, step_size)
    
    # Compute function value
    # Note: This would need to be passed in or computed via the objective function
    # For now, we'll leave it as a placeholder
    
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
    update_visualization!(viz_state)

Update all visualization elements with current algorithm states.
"""
function update_visualization!(viz_state)
    for (name, tracker) in viz_state[:trackers]
        update_tracker_visualization!(viz_state, name, tracker)
    end
    
    update_convergence_analysis!(viz_state)
    update_gradient_analysis!(viz_state)
    update_comparison_metrics!(viz_state)
end

"""
Update visualization elements for a specific tracker
"""
function update_tracker_visualization!(viz_state, name::String, tracker::AlgorithmTracker)
    if haskey(viz_state, :tracker_viz) && haskey(viz_state[:tracker_viz], name)
        tracker_viz = viz_state[:tracker_viz][name]
        
        # Update trajectory
        if !isempty(tracker.positions)
            trajectory_points = [Point2f(pos[1], pos[2]) for pos in tracker.positions]
            tracker_viz[:trajectory][] = trajectory_points
            
            # Update current position
            current_pos = tracker.positions[end]
            tracker_viz[:current_pos][] = Point2f(current_pos[1], current_pos[2])
        end
        
        # Update gradient arrows if enabled
        obs = viz_state[:observables]
        if obs[:show_gradients][] && !isempty(tracker.gradients)
            update_gradient_arrows!(viz_state, name, tracker)
        end
        
        # Update momentum arrow if enabled
        if obs[:show_momentum][] && !isempty(tracker.current_momentum)
            update_momentum_arrow!(viz_state, name, tracker)
        end
    end
end

"""
Update gradient vector field visualization
"""
function update_gradient_arrows!(viz_state, name::String, tracker::AlgorithmTracker)
    # This would create/update gradient arrow visualization
    # Implementation would depend on specific requirements
    # For now, placeholder for the interface
end

"""
Update momentum vector visualization
"""
function update_momentum_arrow!(viz_state, name::String, tracker::AlgorithmTracker)
    # This would create/update momentum arrow visualization
    # Implementation would depend on specific requirements
    # For now, placeholder for the interface
end

"""
Update convergence analysis panel
"""
function update_convergence_analysis!(viz_state)
    ax_conv = viz_state[:axes].conv
    
    # Clear previous plots
    empty!(ax_conv)
    
    # Plot convergence for each algorithm
    for (name, tracker) in viz_state[:trackers]
        if !isempty(tracker.function_values)
            iterations = 1:length(tracker.function_values)
            lines!(ax_conv, iterations, tracker.function_values,
                   color = tracker.color, label = name, linewidth = 2)
        end
    end
    
    # Add legend if multiple algorithms
    if length(viz_state[:trackers]) > 1
        axislegend(ax_conv, position = :rt)
    end
end

"""
Update gradient analysis panel
"""
function update_gradient_analysis!(viz_state)
    ax_grad = viz_state[:axes].grad
    
    # Clear previous plots
    empty!(ax_grad)
    
    # Plot gradient norms for each algorithm
    for (name, tracker) in viz_state[:trackers]
        if !isempty(tracker.gradients)
            iterations = 1:length(tracker.gradients)
            gradient_norms = [norm(grad) for grad in tracker.gradients]
            lines!(ax_grad, iterations, log10.(gradient_norms .+ 1e-16),
                   color = tracker.color, label = name, linewidth = 2)
        end
    end
    
    ax_grad.ylabel = "log₁₀(Gradient Norm)"
end

"""
Update algorithm comparison metrics
"""
function update_comparison_metrics!(viz_state)
    ax_comp = viz_state[:axes].comp
    
    # This would implement performance comparison visualization
    # Metrics could include: convergence rate, efficiency, robustness
    # For now, placeholder for the interface
end

"""
    restart_algorithms_from_point!(viz_state, point::Vector{Float64})

Restart all tracked algorithms from a new starting point.
"""
function restart_algorithms_from_point!(viz_state, point::Vector{Float64})
    for (name, tracker) in viz_state[:trackers]
        # Clear previous data
        empty!(tracker.positions)
        empty!(tracker.gradients)
        empty!(tracker.step_sizes)
        empty!(tracker.function_values)
        
        # Reset counters
        tracker.iteration_count = 0
        tracker.total_distance = 0.0
        tracker.convergence_rate = 0.0
        tracker.current_momentum = Float64[]
        
        # Set new starting point
        push!(tracker.positions, copy(point))
        
        # This would trigger algorithm restart
        # Implementation would depend on specific algorithm integration
    end
end

"""
    create_gradient_field_viz(objective_function, x_range, y_range; density=10)

Create a gradient vector field visualization overlay.
"""
function create_gradient_field_viz(objective_function, x_range, y_range; density=10)
    # Create grid points
    x_points = range(x_range[1], x_range[2], length = density)
    y_points = range(y_range[1], y_range[2], length = density)
    
    points = []
    directions = []
    
    for x in x_points, y in y_points
        point = [x, y]
        gradient = ForwardDiff.gradient(objective_function, point)
        
        # Normalize gradient for visualization
        grad_norm = norm(gradient)
        if grad_norm > 1e-12
            direction = -gradient / grad_norm  # Point toward decrease
            push!(points, Point2f(x, y))
            push!(directions, Vec2f(direction[1], direction[2]))
        end
    end
    
    return (points = points, directions = directions)
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

# Additional utility functions for educational and research features would go here
# This provides the core framework for Issue #50 implementation