"""
Test script to demonstrate the gradient tolerance logic in valley walking.
We'll use a function with a valley structure to show the algorithm switching
between gradient descent and valley walking.
"""

using Pkg; Pkg.activate(@__DIR__)

using Revise
using Globtim
using LinearAlgebra
using ForwardDiff
using Printf

include("valley_walking_utils.jl")

# Create a test function with a valley
# This function has a quadratic valley along y=x with steep walls
function valley_function(x)
    # Valley along y = x
    valley_distance = (x[1] - x[2])^2
    # Quadratic along the valley direction
    valley_progress = (x[1] + x[2])^2 / 4
    
    return 100 * valley_distance + valley_progress
end

# Test from different starting points
test_points = [
    [2.0, 1.9],      # Near the valley, small gradient
    [5.0, 4.8],      # Near the valley, larger gradient
    [2.0, 0.0],      # Away from valley, large gradient
    [0.1, 0.1],      # In the valley, near minimum
]

println("="^80)
println("TESTING GRADIENT TOLERANCE LOGIC")
println("="^80)

for (i, x0) in enumerate(test_points)
    println("\n" * "-"^60)
    println("Test $i: Starting from $(x0)")
    println("-"^60)
    
    # Compute initial gradient and Hessian
    g0 = ForwardDiff.gradient(valley_function, x0)
    H0 = ForwardDiff.hessian(valley_function, x0)
    λ0, _ = eigen(H0)
    
    println("Initial state:")
    println("  f(x0) = $(round(valley_function(x0), digits=6))")
    println("  ||gradient|| = $(round(norm(g0), digits=6))")
    println("  Min eigenvalue = $(round(minimum(abs.(λ0)), digits=6))")
    
    # Run valley walking with verbose output
    points, eigenvals, f_vals, step_types = enhanced_valley_walk(
        valley_function, x0;
        n_steps = 20,
        step_size = 0.05,
        ε_null = 1e-4,
        gradient_step_size = 0.01,
        rank_deficiency_threshold = 1e-3,
        gradient_norm_tolerance = 0.1,  # Higher tolerance for demonstration
        verbose = true
    )
    
    # Summary
    n_valley = count(s -> s == "valley", step_types)
    n_gradient = count(s -> s == "gradient", step_types)
    
    println("\nSummary:")
    println("  Final point: $(round.(points[end], digits=4))")
    println("  Final f: $(round(f_vals[end], digits=6))")
    println("  Valley steps: $n_valley, Gradient steps: $n_gradient")
end

# Now test with a true saddle point function
println("\n" * "="^80)
println("TESTING WITH SADDLE POINT FUNCTION")
println("="^80)

# Saddle function: f(x,y) = x^2 - y^2
saddle_function(x) = x[1]^2 - x[2]^2

# Start near the saddle point
x0_saddle = [0.01, 0.01]

println("\nStarting from near saddle point: $(x0_saddle)")

# Compute initial state
g0 = ForwardDiff.gradient(saddle_function, x0_saddle)
H0 = ForwardDiff.hessian(saddle_function, x0_saddle)
λ0, V0 = eigen(H0)

println("Initial state:")
println("  f(x0) = $(round(saddle_function(x0_saddle), digits=6))")
println("  ||gradient|| = $(round(norm(g0), digits=6))")
println("  Eigenvalues = $(round.(λ0, digits=6))")
println("  Min |eigenvalue| = $(round(minimum(abs.(λ0)), digits=6))")

# Run valley walking
points, eigenvals, f_vals, step_types = enhanced_valley_walk(
    saddle_function, x0_saddle;
    n_steps = 30,
    step_size = 0.1,
    ε_null = 1e-6,
    gradient_step_size = 0.05,
    rank_deficiency_threshold = 0.5,  # Saddle has one positive, one negative eigenvalue
    gradient_norm_tolerance = 0.05,
    verbose = true
)

# Summary
n_valley = count(s -> s == "valley", step_types)
n_gradient = count(s -> s == "gradient", step_types)

println("\nSummary:")
println("  Final point: $(round.(points[end], digits=4))")
println("  Final f: $(round(f_vals[end], digits=6))")
println("  Valley steps: $n_valley, Gradient steps: $n_gradient")