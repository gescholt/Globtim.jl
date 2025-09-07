#!/usr/bin/env julia

"""
Advanced Analysis Core Demo

Demonstrates the core analysis functions from Issue #50 implementation.
Tests the computational foundation without requiring GLMakie visualization.

Features tested:
- Algorithm tracking and performance analysis
- Hessian eigenvalue analysis for valley detection  
- Convergence metrics computation
- Multi-algorithm performance comparison
- Gradient field data generation

Usage: julia Examples/advanced_analysis_core_demo.jl
"""

using Pkg
Pkg.activate(".")

using Globtim
using LinearAlgebra
using ForwardDiff  
using Printf
using Statistics

println("🧮 Advanced Analysis Core Demo")
println("=" ^ 50)

# Test function: a complex 2D optimization landscape with valleys
function demo_objective(x)
    x1, x2 = x[1], x[2] 
    # Multi-modal function with clear valley structure
    return (x1^2 + x2^2 - 1)^2 + 0.05 * (sin(8*x1) + cos(8*x2))
end

println("🎯 Test function: f(x) = (x₁² + x₂² - 1)² + 0.05(sin(8x₁) + cos(8x₂))")
println("   Expected: Valleys along unit circle with high-frequency noise")

# Test core analysis functions
println("\n🔧 Testing core analysis functions...")

# Create algorithm trackers
println("\n📊 Creating algorithm trackers...")
valley_tracker = AlgorithmTracker("Valley Walking", :blue)
bfgs_tracker = AlgorithmTracker("BFGS", :green)
gd_tracker = AlgorithmTracker("Gradient Descent", :red)

println("  ✓ Created 3 algorithm trackers")

# Test points along the valley and off-valley
test_points = [
    [1.0, 0.0],      # On unit circle (valley)
    [0.0, 1.0],      # On unit circle (valley) 
    [-0.707, 0.707], # On unit circle (valley)
    [0.5, 0.5],      # Off valley
    [1.5, 0.5],      # Far off valley
]

println("\n🔍 Testing Hessian eigenvalue analysis...")
for (i, point) in enumerate(test_points)
    println("  Point $i: [$(point[1]), $(point[2])]")
    
    # Perform Hessian analysis
    hess_analysis = hessian_eigenvalue_analysis(demo_objective, point)
    
    function_value = demo_objective(point)
    gradient = ForwardDiff.gradient(demo_objective, point)
    gradient_norm = norm(gradient)
    
    println("    f(x) = ", @sprintf("%.6f", function_value))
    println("    ‖∇f(x)‖ = ", @sprintf("%.6f", gradient_norm))
    println("    Valley dimension: $(hess_analysis.valley_dimension)")
    println("    Min |eigenvalue|: ", @sprintf("%.2e", minimum(abs.(hess_analysis.eigenvalues))))
    println("    Max |eigenvalue|: ", @sprintf("%.2e", maximum(abs.(hess_analysis.eigenvalues))))
    println("    Condition number: ", @sprintf("%.2e", hess_analysis.condition_number))
    
    # Determine if it's a valley point
    if hess_analysis.valley_dimension > 0 && gradient_norm < 0.1
        println("    → Valley point detected! ✓")
    else
        println("    → Not a valley point")
    end
    println()
end

# Test algorithm tracking with simulated optimization runs
println("🚀 Simulating algorithm runs for performance analysis...")

algorithms = [
    ("Valley Walking", valley_tracker, 1.0),
    ("BFGS", bfgs_tracker, 1.2),
    ("Gradient Descent", gd_tracker, 0.8)
]

# Simulate 10 iterations for each algorithm
n_iterations = 10
for (name, tracker, speed_factor) in algorithms
    println("  Simulating $name algorithm...")
    
    # Start from off-valley point
    current_pos = [1.2, 0.3]
    
    for iter in 1:n_iterations
        # Compute gradient and function value
        gradient = ForwardDiff.gradient(demo_objective, current_pos)
        func_val = demo_objective(current_pos)
        step_size = 0.05 * speed_factor * (1.0 + 0.1 * randn()) # Add noise
        
        # Update tracker
        update_algorithm_tracker!(tracker, current_pos, gradient, step_size, func_val)
        
        # Simulate optimization step (simple gradient descent)
        current_pos = current_pos - step_size * gradient
        
        # Add momentum enhancement tracking
        momentum_enhanced_tracking(tracker, current_pos)
    end
    
    println("    ✓ Completed $n_iterations iterations")
end

# Analyze convergence for each algorithm
println("\n📈 Convergence analysis results:")
for (name, tracker, _) in algorithms
    metrics = analyze_convergence(tracker)
    
    println("  $name:")
    println("    Iterations: $(metrics.iteration)")
    println("    Final f(x): ", @sprintf("%.6f", metrics.function_value))
    println("    Final ‖∇f(x)‖: ", @sprintf("%.2e", metrics.gradient_norm))
    println("    Final step size: ", @sprintf("%.4f", metrics.step_size))
    println("    Total distance: ", @sprintf("%.4f", metrics.distance_from_start))
    println("    Momentum magnitude: ", @sprintf("%.4f", metrics.momentum_magnitude))
    println("    Convergence rate: ", @sprintf("%.2e", metrics.convergence_rate))
    println()
end

# Multi-algorithm performance comparison
println("🏁 Algorithm performance comparison:")
trackers_dict = Dict(
    "Valley Walking" => valley_tracker,
    "BFGS" => bfgs_tracker, 
    "Gradient Descent" => gd_tracker
)

comparison_metrics = algorithm_performance_comparison(trackers_dict)

println("  Performance Summary:")
for (alg_name, metrics) in comparison_metrics
    println("    $alg_name:")
    println("      Convergence iterations: ", @sprintf("%.1f", metrics["convergence_iterations"]))
    println("      Path efficiency: ", @sprintf("%.3f", metrics["path_efficiency"]))  
    println("      Final function value: ", @sprintf("%.6f", metrics["final_function_value"]))
    println("      Average step size: ", @sprintf("%.4f", metrics["average_step_size"]))
    println("      Gradient reduction: ", @sprintf("%.2e", metrics["gradient_reduction_factor"]))
    println()
end

# Test gradient field data generation
println("🌊 Testing gradient field data generation...")
gradient_data = create_gradient_field_data(demo_objective, (-1.5, 1.5), (-1.5, 1.5), density=12)

println("  ✓ Generated gradient field data:")
println("    Grid points: $(length(gradient_data.points))")
println("    Average gradient magnitude: ", @sprintf("%.4f", mean(gradient_data.magnitudes)))
println("    Max gradient magnitude: ", @sprintf("%.4f", maximum(gradient_data.magnitudes)))

# Show some gradient field samples
println("\n  Sample gradient vectors:")
for i in 1:min(5, length(gradient_data.points))
    point = gradient_data.points[i]
    direction = gradient_data.directions[i] 
    magnitude = gradient_data.magnitudes[i]
    
    println("    Point: [$(point[1]), $(point[2])] → Direction: [$(direction[1]), $(direction[2])], Magnitude: ", @sprintf("%.4f", magnitude))
end

# Test configuration
println("\n⚙️  Testing visualization configuration...")
config = InteractiveVizConfig(
    figure_size = (1600, 1200),
    show_convergence_metrics = true,
    show_gradient_field = true,
    enable_click_to_set = true,
    enable_algorithm_racing = true,
    contour_levels = 25
)

println("  ✓ Configuration created:")
println("    Figure size: $(config.figure_size)")
println("    Contour levels: $(config.contour_levels)")
println("    Algorithm racing: $(config.enable_algorithm_racing)")
println("    Interactive features: $(config.enable_click_to_set)")

println("\n✅ Core Analysis Functions Test Complete!")
println("=" ^ 50)

println("\n🎉 Issue #50 Core Implementation Summary:")
println("✓ Algorithm tracking and performance metrics")
println("✓ Hessian eigenvalue analysis for valley detection")
println("✓ Multi-algorithm performance comparison") 
println("✓ Convergence analysis and momentum tracking")
println("✓ Gradient field data generation")
println("✓ Interactive visualization configuration system")

println("\n💡 Next steps:")
println("• Load GLMakie to access full interactive visualization features")
println("• Use the GLMakie extension for real-time interactive displays")
println("• Integrate with existing valley walking algorithms")

println("\n🚀 Advanced Interactive Visualization Framework Ready!")