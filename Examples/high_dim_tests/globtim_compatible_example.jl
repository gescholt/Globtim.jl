"""
Globtim-Compatible Example with 4D Diffusion Problem

This example shows how to use the 4D diffusion problem with Globtim's
dimension limits (≤10D) by creating smaller problems or using the 4D active subspace directly.
"""

using Globtim
using LinearAlgebra
using Printf
include("diffusion_inverse/src/diffusion_problem.jl")

println("=== Globtim-Compatible 4D Diffusion Example ===")

"""
    create_small_diffusion_problem()

Create a diffusion problem that fits within Globtim's 10D limit.
"""
function create_small_diffusion_problem()
    println("\n1. Creating small diffusion problem (≤10D)...")
    
    # Create a problem with ≤10 parameters
    problem, θ_true = create_synthetic_diffusion_problem(
        n_params=8,           # Within Globtim's 10D limit
        grid_size=(11, 11),   # Smaller grid for speed
        n_sensors=4           # Fewer sensors
    )
    
    println("   ✅ Created 8D problem (within Globtim's 10D limit)")
    println("   - Parameter dimension: 8")
    println("   - Active subspace: 4D [Diffusion, Advection, Reaction, Anisotropy]")
    println("   - Grid size: (11, 11)")
    println("   - Sensors: 4")
    
    return problem, θ_true
end

"""
    create_4d_active_subspace_problem(full_problem)

Extract just the 4D active subspace for direct optimization.
"""
function create_4d_active_subspace_problem(full_problem)
    println("\n2. Creating 4D active subspace problem...")
    
    # Create a function that works directly in the 4D active space
    function active_subspace_objective(y)
        # y is 4D: [diffusion, advection, reaction, anisotropy]
        
        # Convert 4D coordinates to full parameter space
        # Use the first 4 columns of W_active as a basis
        θ = full_problem.W_active[:, 1:4] * y
        
        # Evaluate the full objective
        full_objective = construct_4d_diffusion_objective(full_problem)
        return full_objective(θ)
    end
    
    println("   ✅ Created 4D active subspace objective")
    println("   - Direct 4D optimization in active coordinates")
    println("   - Maps: y ∈ ℝ⁴ → objective value")
    
    return active_subspace_objective
end

"""
    run_globtim_on_small_problem()

Run Globtim on the small 8D problem.
"""
function run_globtim_on_small_problem()
    println("\n=== Approach 1: Small 8D Problem ===")
    
    # Create small problem
    problem, θ_true = create_small_diffusion_problem()
    objective = construct_4d_diffusion_objective(problem)
    
    # Test objective
    obj_true = objective(θ_true)
    println("   - Objective at true parameters: $obj_true")
    
    # Run Globtim
    println("\n   Running Globtim on 8D problem...")
    
    try
        results = safe_globtim_workflow(
            objective,
            dim=8,                    # Within 10D limit
            center=zeros(8),
            sample_range=2.0,
            degree=6,                 # Can use higher degree for 8D
            GN=120,
            enable_hessian=true
        )
        
        println("   ✅ SUCCESS!")
        println("   - L2 error: $(results.polynomial.nrm)")
        println("   - Critical points: $(nrow(results.critical_points))")
        println("   - Minima found: $(nrow(results.minima))")
        
        if nrow(results.minima) > 0
            println("   - Best minimum: $(minimum(results.minima.objective_value))")
        end
        
        return results, problem
        
    catch e
        println("   ❌ Failed: $e")
        return nothing, problem
    end
end

"""
    run_globtim_on_4d_active_space()

Run Globtim directly on the 4D active subspace.
"""
function run_globtim_on_4d_active_space()
    println("\n=== Approach 2: Direct 4D Active Subspace ===")
    
    # Create a medium-sized problem for the active subspace extraction
    full_problem, _ = create_synthetic_diffusion_problem(
        n_params=50,          # Larger problem for better 4D structure
        grid_size=(15, 15),
        n_sensors=8
    )
    
    # Create 4D active subspace objective
    active_objective = create_4d_active_subspace_problem(full_problem)
    
    # Test the 4D objective
    y_test = [0.5, -0.3, 0.2, 0.1]  # Test 4D coordinates
    obj_test = active_objective(y_test)
    println("   - Test objective value: $obj_test")
    
    # Run Globtim on 4D space
    println("\n   Running Globtim on 4D active subspace...")
    
    try
        results = safe_globtim_workflow(
            active_objective,
            dim=4,                    # True 4D problem
            center=zeros(4),
            sample_range=2.0,
            degree=8,                 # Can use high degree for 4D
            GN=150,
            enable_hessian=true
        )
        
        println("   ✅ SUCCESS!")
        println("   - L2 error: $(results.polynomial.nrm)")
        println("   - Critical points: $(nrow(results.critical_points))")
        println("   - Minima found: $(nrow(results.minima))")
        
        if nrow(results.minima) > 0
            println("   - Best minimum: $(minimum(results.minima.objective_value))")
            
            # Show the 4D coordinates of the minima
            println("\n   4D Active Subspace Minima:")
            for i in 1:min(3, nrow(results.minima))
                row = results.minima[i, :]
                if haskey(row, :coordinates) || hasproperty(row, :coordinates)
                    y_coords = row.coordinates
                    obj_val = row.objective_value
                    println("     Basin $i: y=[$(@sprintf("%.3f", y_coords[1])), $(@sprintf("%.3f", y_coords[2])), $(@sprintf("%.3f", y_coords[3])), $(@sprintf("%.3f", y_coords[4]))] → obj=$(@sprintf("%.6f", obj_val))")
                    
                    # Interpret physics
                    println("       Physics: D≈$(@sprintf("%.2f", exp(y_coords[1]))), |v|≈$(@sprintf("%.2f", abs(y_coords[2]))), R≈$(@sprintf("%.2f", y_coords[3])), aniso≈$(@sprintf("%.2f", exp(y_coords[4])))")
                end
            end
        end
        
        return results, full_problem
        
    catch e
        println("   ❌ Failed: $e")
        return nothing, full_problem
    end
end

"""
    compare_approaches()

Compare both approaches and provide recommendations.
"""
function compare_approaches()
    println("\n" * "="^60)
    println("COMPARISON OF APPROACHES")
    println("="^60)
    
    # Run both approaches
    results1, problem1 = run_globtim_on_small_problem()
    results2, problem2 = run_globtim_on_4d_active_space()
    
    println("\n" * "="^60)
    println("SUMMARY & RECOMMENDATIONS")
    println("="^60)
    
    println("\n🎯 For your 100D problem, you have these options:")
    
    println("\n1. **Small Problem Approach** (8D)")
    if results1 !== nothing
        println("   ✅ Works with Globtim")
        println("   ✅ Full parameter space optimization")
        println("   ⚠️  Limited to small problems (≤10D)")
        println("   💡 Good for: Proof of concept, method validation")
    else
        println("   ❌ Failed in this test")
    end
    
    println("\n2. **4D Active Subspace Approach**")
    if results2 !== nothing
        println("   ✅ Works with Globtim")
        println("   ✅ Captures the essential 4D physics")
        println("   ✅ Can handle large underlying problems")
        println("   ✅ Direct interpretation of physical mechanisms")
        println("   💡 Good for: Understanding basin structure, physical insight")
    else
        println("   ❌ Failed in this test")
    end
    
    println("\n3. **Alternative for 100D Problems:**")
    println("   🔧 Use other optimization methods for full 100D:")
    println("      - Optim.jl with multiple random starts")
    println("      - BlackBoxOptim.jl")
    println("      - Custom basin-hopping algorithms")
    println("   🔬 Use Globtim on 4D active subspace for basin analysis")
    
    println("\n📊 **Recommended Workflow for Large Problems:**")
    println("   1. Use 4D active subspace with Globtim to understand basin structure")
    println("   2. Use insights to guide full-dimensional optimization")
    println("   3. Validate results by projecting to 4D space")
    
    return results1, results2, problem1, problem2
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    results1, results2, problem1, problem2 = compare_approaches()
    
    println("\n🎉 Both approaches demonstrated!")
    println("\nTo use in your code:")
    println("""
    # For small problems (≤10D):
    problem, θ_true = create_synthetic_diffusion_problem(n_params=8, ...)
    objective = construct_4d_diffusion_objective(problem)
    results = safe_globtim_workflow(objective, dim=8, ...)
    
    # For large problems via 4D active subspace:
    full_problem, _ = create_synthetic_diffusion_problem(n_params=100, ...)
    active_obj = create_4d_active_subspace_problem(full_problem)
    results = safe_globtim_workflow(active_obj, dim=4, ...)
    """)
end
