"""
    test_functions.jl

Collection of test objective functions for valley walking experiments.
Includes both analytical test functions and ODE-based error functions.
"""

using DynamicPolynomials
using LinearAlgebra

# ============================================================================
# ANALYTICAL TEST FUNCTIONS
# ============================================================================

"""
    rosenbrock_2d(x)

2D Rosenbrock function with valley structure.
- Global minimum at [1, 1] with f(1,1) = 0
- Valley follows: y ≈ x²
"""
function rosenbrock_2d(x)
    return (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
end

"""
    rosenbrock_3d(x)

3D Rosenbrock function extended with valley structure.
- Valley follows: y ≈ x², z ≈ y²
"""
function rosenbrock_3d(x)
    return (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2 + (x[3] - x[2]^2)^2
end

"""
    simple_valley_3d(x)

Simple valley function in 3D.
- Valley is the parabola z = x² + y²
"""
function simple_valley_3d(x)
    return x[1]^2 + x[2]^2 + (x[3] - x[1]^2 - x[2]^2)^2
end

"""
    himmelblau(x)

Himmelblau's function - multiple local minima.
- Four identical local minima at:
  - [3.0, 2.0]
  - [-2.805118, 3.131312]
  - [-3.779310, -3.283186]
  - [3.584428, -1.848126]
- All with f(x*) = 0
"""
function himmelblau(x)
    return (x[1]^2 + x[2] - 11)^2 + (x[1] + x[2]^2 - 7)^2
end

"""
    beale(x)

Beale function - sharp, narrow valley.
- Global minimum at [3, 0.5] with f(3, 0.5) = 0
- Challenging due to narrow curved valley
"""
function beale(x)
    return (1.5 - x[1] + x[1]*x[2])^2 + 
           (2.25 - x[1] + x[1]*x[2]^2)^2 + 
           (2.625 - x[1] + x[1]*x[2]^3)^2
end

"""
    get_test_function_info(func_name::Symbol)

Get information about a test function including its true minimum/minima.
"""
function get_test_function_info(func_name::Symbol)
    info = Dict(
        :rosenbrock_2d => (
            func = rosenbrock_2d,
            true_minima = [[1.0, 1.0]],
            domain = (-2, 3, -1, 3),
            description = "2D Rosenbrock with valley y ≈ x²"
        ),
        :rosenbrock_3d => (
            func = rosenbrock_3d,
            true_minima = [[1.0, 1.0, 1.0]],
            domain = (-2, 3, -1, 3, -1, 3),
            description = "3D Rosenbrock with valley"
        ),
        :himmelblau => (
            func = himmelblau,
            true_minima = [[3.0, 2.0], [-2.805118, 3.131312], 
                          [-3.779310, -3.283186], [3.584428, -1.848126]],
            domain = (-5, 5, -5, 5),
            description = "Himmelblau's function with 4 minima"
        ),
        :beale => (
            func = beale,
            true_minima = [[3.0, 0.5]],
            domain = (-4.5, 4.5, -4.5, 4.5),
            description = "Beale function with narrow valley"
        )
    )
    
    return get(info, func_name, nothing)
end

# ============================================================================
# ODE-BASED ERROR FUNCTIONS
# ============================================================================

"""
    create_lotka_volterra_error_function(; kwargs...)

Create an error function for Lotka-Volterra parameter estimation.

# Keyword Arguments
- `true_params = [1.0, 1.0]`: True parameter values
- `initial_conditions = [100.0, 100.0]`: Initial conditions for ODE
- `time_interval = [0.0, 1.0]`: Time interval for simulation
- `num_points = 100`: Number of time points
- `distance_metric = L2_norm`: Distance metric to use

# Returns
Error function that takes parameter vector and returns distance to true trajectory.
"""
function create_lotka_volterra_error_function(;
    true_params = [1.0, 1.0],
    initial_conditions = [100.0, 100.0],
    time_interval = [0.0, 1.0],
    num_points = 100,
    distance_metric = nothing)
    
    # This is a placeholder - you would need to implement the actual
    # ODE solving and error computation based on your existing code
    function error_func(params)
        # Simplified error function for demonstration
        # In practice, this would solve the ODE and compare trajectories
        return sum((params .- true_params).^2)
    end
    
    return error_func
end

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

"""
    evaluate_on_grid(func, x_range, y_range)

Evaluate a 2D function on a grid.
"""
function evaluate_on_grid(func, x_range, y_range)
    return [func([x, y]) for y in y_range, x in x_range]
end

"""
    find_function_minimum(func, x0; method=:lbfgs)

Find a local minimum of the function starting from x0.
Uses Optim.jl if available.
"""
function find_function_minimum(func, x0; method=:lbfgs)
    # Placeholder - would use Optim.jl in practice
    # For now, just return the starting point
    return x0
end