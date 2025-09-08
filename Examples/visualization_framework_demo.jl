#!/usr/bin/env julia

"""
Visualization Framework Demo

Demonstrates the extensible visualization framework implemented for Issue #67.
Shows how to prepare data and create plots with graceful fallback when Makie unavailable.

Usage:
    julia Examples/visualization_framework_demo.jl
    julia Examples/visualization_framework_demo.jl --save-plots

Features demonstrated:
- L2-norm vs polynomial degree analysis
- Parameter space visualization (1D, 2D, high-dimensional)  
- Algorithm convergence trajectory comparison
- Graceful fallback to text analysis
- Extensible plugin architecture

Author: GlobTim Team
Date: September 2025
"""

using Pkg
Pkg.activate(".")

using Printf
using Random
using Statistics
using LinearAlgebra
using Dates

# Load the visualization framework
include("../src/VisualizationFramework.jl")
using .VisualizationFramework

# Try to load Makie for full plotting capabilities
try
    using CairoMakie, GLMakie
    println("✅ Makie plotting available")
    # Load the extension manually for demo purposes
    include("../ext/GlobtimVisualizationFrameworkExt.jl")
    using .GlobtimVisualizationFrameworkExt
catch e
    println("⚠️  Makie not available - will use text fallback: $e")
end

"""
Generate synthetic experiment data for L2-degree analysis demo.
"""
function generate_synthetic_l2_degree_data(n_experiments=20)
    Random.seed!(42)
    
    experiments = []
    dimensions = [2, 3, 4]
    degrees = 2:8
    
    for _ in 1:n_experiments
        dim = rand(dimensions)
        deg = rand(degrees)
        
        # Simulate L2 norm that generally improves with higher degree
        # but has some noise and dimensional complexity effects
        base_l2 = 10.0^(-deg + rand() * 2 - 1)  # Base improvement with degree
        dim_penalty = dim^1.5  # Higher dimensions are harder
        noise_factor = 10.0^(rand() * 2 - 1)  # Random noise
        
        l2_norm = base_l2 * dim_penalty * noise_factor
        
        # Condition number generally increases with degree and dimension
        condition_number = 10.0^(2 + deg/2 + dim/3 + rand())
        
        # Sample count scales with dimension and degree
        samples_per_dim = 10 + deg * 2
        total_samples = samples_per_dim^dim
        
        experiment = Dict(
            "dimension" => dim,
            "degree" => deg,
            "L2_norm" => l2_norm,
            "condition_number" => condition_number,
            "total_samples" => total_samples,
            "basis" => "monomial",
            "sample_range" => [-1.0, 1.0]
        )
        
        push!(experiments, experiment)
    end
    
    return experiments
end

"""
Generate synthetic parameter space data for visualization demo.
"""
function generate_parameter_space_data(n_points=100, dimension=2)
    Random.seed!(123)
    
    if dimension == 1
        # 1D: Simple quadratic with minimum
        x = range(-3, 3, length=n_points)
        points = reshape(collect(x), :, 1)
        function_values = [(xi - 1.0)^2 + 0.5 for xi in x]
    elseif dimension == 2
        # 2D: Rosenbrock-like function
        x = 4 * rand(n_points) .- 2  # Range [-2, 2]
        y = 4 * rand(n_points) .- 2
        points = [x y]
        function_values = [100*(y[i] - x[i]^2)^2 + (1 - x[i])^2 for i in 1:n_points]
    else
        # High-dimensional: Sphere function with noise
        points = 2 * rand(n_points, dimension) .- 1  # Range [-1, 1]
        function_values = [sum(points[i, :].^2) + 0.1*randn() for i in 1:n_points]
    end
    
    return points, function_values
end

"""
Generate synthetic algorithm convergence data for demo.
"""
function generate_convergence_data()
    Random.seed!(456)
    
    algorithms = ["Gradient Descent", "Adam", "BFGS"]
    trackers = Dict{String, Any}()
    
    for (i, name) in enumerate(algorithms)
        n_iters = 50 + rand(1:50)  # Variable convergence length
        
        # Generate 2D trajectory starting from random point
        start_point = 2 * randn(2)
        positions = [start_point]
        
        # Simulate convergence toward origin with different characteristics
        current = copy(start_point)
        momentum = zeros(2)
        
        for iter in 1:n_iters
            # Different algorithm behaviors
            if name == "Gradient Descent"
                # Simple gradient step with decay
                step = -0.1 * current * (0.95)^iter + 0.05 * randn(2)
            elseif name == "Adam"
                # Momentum-based with adaptive step
                gradient = current + 0.1 * randn(2)
                momentum = 0.9 * momentum + 0.1 * gradient
                step = -0.05 * momentum
            else  # BFGS
                # Faster convergence with larger steps initially
                adaptive_rate = 0.2 * exp(-iter/20)
                step = -adaptive_rate * current + 0.02 * randn(2)
            end
            
            current += step
            push!(positions, copy(current))
        end
        
        # Generate corresponding function values (decreasing with some noise)
        function_values = [sum(pos.^2) + 0.1*abs(randn()) for pos in positions]
        
        # Create tracker-like structure
        tracker = Dict(
            "positions" => positions,
            "function_values" => function_values,
            "name" => name
        )
        
        trackers[name] = tracker
    end
    
    return trackers
end

"""
Demonstration of L2-norm vs degree analysis.
"""
function demo_l2_degree_analysis(save_plots=false)
    println("\n" * "="^60)
    println("🔬 L2-Norm vs Polynomial Degree Analysis Demo")
    println("="^60)
    
    # Generate synthetic experiment data
    experiments = generate_synthetic_l2_degree_data(25)
    println("Generated $(length(experiments)) synthetic experiments")
    
    # Prepare visualization data
    data = prepare_l2_degree_plot_data(experiments)
    println("✅ Data preparation complete")
    
    # Configure plot
    config = PlotConfig(
        title = "Synthetic L2-Norm vs Polynomial Degree Study",
        figure_size = (1400, 1000),
        save_path = save_plots ? "l2_degree_demo.png" : nothing,
        color_scheme = :viridis
    )
    
    # Render plot (works with or without Makie)
    println("📊 Rendering L2-degree analysis plot...")
    plot = render_plot(data, config)
    
    if plot !== nothing
        println("✅ Plot rendered successfully")
    else
        println("📝 Text analysis provided (plotting packages unavailable)")
    end
    
    return data, plot
end

"""
Demonstration of parameter space visualization.
"""
function demo_parameter_space_analysis(save_plots=false)
    println("\n" * "="^60)
    println("🎯 Parameter Space Visualization Demo")
    println("="^60)
    
    # Demo 1D parameter space
    println("\n📈 1D Parameter Space:")
    points_1d, values_1d = generate_parameter_space_data(50, 1)
    data_1d = prepare_parameter_space_data(points_1d, values_1d, 
                                         dimension_labels=["parameter"])
    
    config_1d = PlotConfig(
        title = "1D Parameter Space Analysis",
        save_path = save_plots ? "param_space_1d_demo.png" : nothing
    )
    
    plot_1d = render_plot(data_1d, config_1d)
    
    # Demo 2D parameter space
    println("\n📈 2D Parameter Space:")
    points_2d, values_2d = generate_parameter_space_data(200, 2)
    data_2d = prepare_parameter_space_data(points_2d, values_2d,
                                         dimension_labels=["x₁", "x₂"])
    
    config_2d = PlotConfig(
        title = "2D Parameter Space Analysis",
        save_path = save_plots ? "param_space_2d_demo.png" : nothing,
        color_scheme = :plasma
    )
    
    plot_2d = render_plot(data_2d, config_2d)
    
    # Demo high-dimensional parameter space
    println("\n📈 5D Parameter Space:")
    points_5d, values_5d = generate_parameter_space_data(300, 5)
    data_5d = prepare_parameter_space_data(points_5d, values_5d)
    
    config_5d = PlotConfig(
        title = "5D Parameter Space Analysis",
        save_path = save_plots ? "param_space_5d_demo.png" : nothing
    )
    
    plot_5d = render_plot(data_5d, config_5d)
    
    return [(data_1d, plot_1d), (data_2d, plot_2d), (data_5d, plot_5d)]
end

"""
Demonstration of convergence trajectory visualization.
"""
function demo_convergence_analysis(save_plots=false)
    println("\n" * "="^60)
    println("🏃 Algorithm Convergence Trajectory Demo")
    println("="^60)
    
    # Generate synthetic convergence data
    trackers = generate_convergence_data()
    println("Generated convergence data for $(length(trackers)) algorithms")
    
    # Prepare visualization data
    data = prepare_convergence_data(trackers)
    println("✅ Data preparation complete")
    
    # Configure plot
    config = PlotConfig(
        title = "Multi-Algorithm Convergence Comparison",
        figure_size = (1200, 800),
        save_path = save_plots ? "convergence_demo.png" : nothing,
        show_legend = true
    )
    
    # Render plot
    println("📊 Rendering convergence trajectory plot...")
    plot = render_plot(data, config)
    
    if plot !== nothing
        println("✅ Convergence plot rendered successfully")
    else  
        println("📝 Text analysis provided (plotting packages unavailable)")
    end
    
    return data, plot
end

"""
Demonstrate the plugin architecture and extensibility.
"""
function demo_extensibility()
    println("\n" * "="^60)
    println("🔧 Plugin Architecture & Extensibility Demo")
    println("="^60)
    
    # Show available renderers
    println("📋 Available renderers:")
    for data_type in [L2DegreeAnalysisData, ParameterSpaceData, ConvergenceTrajectoryData]
        renderers = get_available_renderers(data_type)
        println("  $(data_type): $(length(renderers)) renderer(s)")
        for renderer in renderers
            println("    - $(typeof(renderer))")
        end
    end
    
    # Demonstrate graceful fallback
    println("\n🛡️  Graceful fallback demonstration:")
    println("Even without plotting packages, the framework provides useful analysis:")
    
    # Create simple test data
    test_experiments = [Dict("degree" => 3, "L2_norm" => 1e-8, "dimension" => 2)]
    test_data = prepare_l2_degree_plot_data(test_experiments)
    
    # Force fallback rendering
    fallback_result = fallback_render(test_data, PlotConfig())
    
    println("✅ Fallback demonstration complete")
end

"""
Main demo function.
"""
function main()
    println("🎯 GlobTim Visualization Framework Demo")
    println("Issue #67: Extensible visualization framework for future plotting capabilities")
    println("Generated: $(Dates.now())")
    
    # Check command line arguments
    save_plots = "--save-plots" in ARGS
    if save_plots
        println("💾 Plot saving enabled - outputs will be saved to PNG files")
    else
        println("👁️  Display mode - plots will be shown but not saved")
    end
    
    # Run demonstrations
    try
        # L2-degree analysis
        l2_data, l2_plot = demo_l2_degree_analysis(save_plots)
        
        # Parameter space visualization
        param_results = demo_parameter_space_analysis(save_plots)
        
        # Convergence trajectory analysis
        conv_data, conv_plot = demo_convergence_analysis(save_plots)
        
        # Extensibility demonstration
        demo_extensibility()
        
        println("\n" * "="^60)
        println("✅ ALL DEMONSTRATIONS COMPLETE")
        println("="^60)
        println("📊 Framework Features Demonstrated:")
        println("  ✅ Abstract plotting interfaces")
        println("  ✅ Data preparation functions")
        println("  ✅ Plugin-style architecture")
        println("  ✅ Graceful degradation without Makie")
        println("  ✅ Integration points for CairoMakie/GLMakie")
        println("  ✅ L2-norm vs degree plot framework")
        println("  ✅ Parameter space visualization")
        println("  ✅ Convergence trajectory plots")
        println("  ✅ Extensible renderer system")
        
        if save_plots
            println("\n📁 Output files (if Makie available):")
            println("  - l2_degree_demo.png")
            println("  - param_space_1d_demo.png")
            println("  - param_space_2d_demo.png") 
            println("  - param_space_5d_demo.png")
            println("  - convergence_demo.png")
        end
        
        println("\n🚀 Framework ready for production use!")
        
    catch e
        println("❌ Demo failed with error: $e")
        println("Stack trace:")
        showerror(stdout, e, catch_backtrace())
        return 1
    end
    
    return 0
end

# Run the demo if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    exit_code = main()
    exit(exit_code)
end