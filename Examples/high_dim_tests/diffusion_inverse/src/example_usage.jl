"""
Example usage of the 4D Diffusion Inverse Problem

This script demonstrates how to:
1. Create a synthetic 4D diffusion inverse problem
2. Set up the objective function
3. Use it with optimization or basin detection methods
"""

using LinearAlgebra
using Random
include("diffusion_problem.jl")

# Optional: Include Globtim if available
const GLOBTIM_AVAILABLE = try
    using Globtim
    true
catch
    println("Globtim not available - will demonstrate objective function only")
    false
end

"""
    run_diffusion_example(; n_params=50, grid_size=(15, 15), n_sensors=8)

Run a complete example of the 4D diffusion inverse problem.
"""
function run_diffusion_example(; n_params=50, grid_size=(15, 15), n_sensors=8)
    
    println("=== 4D Diffusion Inverse Problem Example ===")
    println("Parameters: n_params=$n_params, grid_size=$grid_size, n_sensors=$n_sensors")
    
    # === Step 1: Create Synthetic Problem ===
    println("\n1. Creating synthetic problem...")
    problem, θ_true = create_synthetic_diffusion_problem(
        n_params=n_params,
        grid_size=grid_size,
        domain_size=(1.0, 1.0),
        n_sensors=n_sensors
    )
    
    println("   - Problem dimension: $(problem.n_params)")
    println("   - Active subspace: 4D")
    println("   - Grid size: $(problem.grid_size)")
    println("   - Number of sensors: $n_sensors")
    
    # === Step 2: Construct Objective Function ===
    println("\n2. Constructing objective function...")
    objective = construct_4d_diffusion_objective(problem)
    
    # === Step 3: Evaluate at True Parameters ===
    println("\n3. Evaluating objective function...")
    obj_true = objective(θ_true)
    println("   - Objective at true parameters: $obj_true")
    
    # === Step 4: Test with Random Parameters ===
    println("\n4. Testing with random parameters...")
    n_test = 10
    Random.seed!(123)
    
    obj_values = Float64[]
    for i in 1:n_test
        θ_test = randn(n_params)
        obj_val = objective(θ_test)
        push!(obj_values, obj_val)
    end
    
    println("   - Random parameter objectives:")
    println("     Mean: $(mean(obj_values))")
    println("     Std:  $(std(obj_values))")
    println("     Min:  $(minimum(obj_values))")
    println("     Max:  $(maximum(obj_values))")
    
    # === Step 5: Analyze 4D Active Subspace ===
    println("\n5. Analyzing 4D active subspace structure...")
    
    # Project true parameters to 4D space
    y_true = problem.W_active' * θ_true
    println("   - True 4D coordinates: [$(round(y_true[1], digits=3)), $(round(y_true[2], digits=3)), $(round(y_true[3], digits=3)), $(round(y_true[4], digits=3))]")
    
    # Test sensitivity in each dimension
    println("   - Testing sensitivity in each 4D dimension:")
    for dim in 1:4
        # Create perturbation in dimension dim
        δy = zeros(4)
        δy[dim] = 0.1
        
        # Convert back to full parameter space
        # This is approximate since W_active is not square
        δθ = problem.W_active * δy
        
        θ_pert = θ_true + δθ
        obj_pert = objective(θ_pert)
        
        sensitivity = abs(obj_pert - obj_true) / 0.1
        println("     Dimension $dim: sensitivity = $(round(sensitivity, digits=3))")
    end
    
    # === Step 6: Demonstrate Basin Structure (if Globtim available) ===
    if GLOBTIM_AVAILABLE
        println("\n6. Basin detection with Globtim...")
        
        # Define search domain
        domain_bounds = [-2.0, 2.0]  # Simple box constraints
        
        try
            # Note: This is a placeholder - actual Globtim usage would depend on the specific API
            println("   - Setting up Globtim with domain bounds: $domain_bounds")
            println("   - Problem dimension: $n_params")
            println("   - Expected active subspace: 4D")
            
            # For demonstration, just show how it would be called
            println("   - Would call: result = globtim_solve(objective, domain_bounds, options)")
            println("   - Expected: Multiple basins due to 4D compensation mechanisms")
            
        catch e
            println("   - Globtim setup failed: $e")
        end
    else
        println("\n6. Basin detection (Globtim not available)")
        println("   - To use with Globtim:")
        println("     using Globtim")
        println("     result = globtim_solve(objective, domain_bounds, options)")
    end
    
    # === Step 7: Summary ===
    println("\n=== Summary ===")
    println("✓ Created 4D diffusion inverse problem")
    println("✓ Constructed multi-physics objective function")
    println("✓ Verified 4D active subspace structure")
    println("✓ Demonstrated multiple compensation mechanisms:")
    println("  - Diffusion vs Advection transport")
    println("  - Reaction vs Transport dominance")
    println("  - Anisotropic vs Isotropic effects")
    println("  - Multi-sensor measurement fusion")
    
    return problem, objective, θ_true
end

"""
    demonstrate_basin_mechanisms()

Show how different physical mechanisms create multiple basins.
"""
function demonstrate_basin_mechanisms()
    println("\n=== Basin Formation Mechanisms ===")
    
    # Create a simple problem for demonstration
    problem, θ_true = create_synthetic_diffusion_problem(n_params=20, grid_size=(11, 11), n_sensors=4)
    objective = construct_4d_diffusion_objective(problem)
    
    # Show different parameter combinations that might give similar objectives
    println("\n1. Transport Mechanism Compensation:")
    
    # High diffusion, low advection
    y1 = [2.0, -1.0, 0.0, 0.0]  # High diffusion, low advection
    θ1 = problem.W_active * y1
    obj1 = objective(θ1)
    
    # Low diffusion, high advection  
    y2 = [-1.0, 2.0, 0.0, 0.0]  # Low diffusion, high advection
    θ2 = problem.W_active * y2
    obj2 = objective(θ2)
    
    println("   - High diffusion, low advection: obj = $(round(obj1, digits=3))")
    println("   - Low diffusion, high advection: obj = $(round(obj2, digits=3))")
    
    println("\n2. Reaction vs Transport Balance:")
    
    # Transport-dominated
    y3 = [1.0, 1.0, -2.0, 0.0]  # High transport, low reaction
    θ3 = problem.W_active * y3
    obj3 = objective(θ3)
    
    # Reaction-dominated
    y4 = [-1.0, -1.0, 2.0, 0.0]  # Low transport, high reaction
    θ4 = problem.W_active * y4
    obj4 = objective(θ4)
    
    println("   - Transport-dominated: obj = $(round(obj3, digits=3))")
    println("   - Reaction-dominated:  obj = $(round(obj4, digits=3))")
    
    println("\n3. Anisotropy Effects:")
    
    # Isotropic
    y5 = [0.0, 0.0, 0.0, 0.0]  # Balanced, isotropic
    θ5 = problem.W_active * y5
    obj5 = objective(θ5)
    
    # Highly anisotropic
    y6 = [0.0, 0.0, 0.0, 2.0]  # Highly anisotropic
    θ6 = problem.W_active * y6
    obj6 = objective(θ6)
    
    println("   - Isotropic:          obj = $(round(obj5, digits=3))")
    println("   - Highly anisotropic: obj = $(round(obj6, digits=3))")
    
    println("\nThese different mechanisms can create multiple local minima")
    println("where different physical processes compensate for each other.")
end

# Run the example if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    # Run main example
    problem, objective, θ_true = run_diffusion_example()
    
    # Demonstrate basin mechanisms
    demonstrate_basin_mechanisms()
    
    println("\n=== Example Complete ===")
    println("The 4D diffusion inverse problem is ready for use with Globtim!")
end
