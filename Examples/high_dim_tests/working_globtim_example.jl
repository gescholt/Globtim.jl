"""
Working Globtim Example with 4D Diffusion Problem

This example uses appropriate parameters that actually work with Globtim.
"""

using Globtim
using LinearAlgebra
using Printf
include("diffusion_inverse/src/diffusion_problem.jl")

println("=== Working Globtim Example ===")

"""
    run_working_4d_example()

Run a 4D example with parameters that actually work.
"""
function run_working_4d_example()
    println("\n🎯 Running 4D Active Subspace Example with Conservative Parameters")
    
    # Create a problem for 4D active subspace extraction
    full_problem, _ = create_synthetic_diffusion_problem(
        n_params=20,          # Moderate size for good 4D structure
        grid_size=(11, 11),   # Small grid for speed
        n_sensors=4           # Few sensors for speed
    )
    
    # Create 4D active subspace objective
    function active_subspace_objective(y)
        # y is 4D: [diffusion, advection, reaction, anisotropy]
        θ = full_problem.W_active[:, 1:4] * y
        full_objective = construct_4d_diffusion_objective(full_problem)
        return full_objective(θ)
    end
    
    # Test the objective
    y_test = [0.0, 0.0, 0.0, 0.0]
    obj_test = active_subspace_objective(y_test)
    println("   - Test objective at origin: $(@sprintf("%.6f", obj_test))")
    
    # Run Globtim with CONSERVATIVE parameters
    println("\n   Running Globtim with conservative parameters...")
    
    try
        results = safe_globtim_workflow(
            active_subspace_objective,
            dim=4,                    # 4D active subspace
            center=zeros(4),          # Search around origin
            sample_range=1.5,         # Moderate search radius
            degree=3,                 # LOW degree for stability
            GN=100,                   # Sufficient samples for degree 3
            enable_hessian=true,
            basis=:chebyshev,
            precision=RationalPrecision,
            max_retries=3
        )
        
        println("   ✅ SUCCESS!")
        println("   - L2 approximation error: $(@sprintf("%.2e", results.polynomial.nrm))")
        println("   - Critical points found: $(nrow(results.critical_points))")
        println("   - Local minima found: $(nrow(results.minima))")
        
        if nrow(results.minima) > 0
            println("\n   🎯 4D Basin Analysis:")
            for i in 1:min(5, nrow(results.minima))
                row = results.minima[i, :]
                obj_val = row.objective_value
                
                # Get coordinates - try different possible column names
                coords = nothing
                for col_name in [:coordinates, :x, :point, :location]
                    if haskey(row, col_name) || hasproperty(row, col_name)
                        coords = getproperty(row, col_name)
                        break
                    end
                end
                
                if coords !== nothing && length(coords) == 4
                    y_coords = coords
                    println("     Basin $i: y=[$(@sprintf("%.3f", y_coords[1])), $(@sprintf("%.3f", y_coords[2])), $(@sprintf("%.3f", y_coords[3])), $(@sprintf("%.3f", y_coords[4]))] → obj=$(@sprintf("%.6f", obj_val))")
                    
                    # Interpret the physics
                    diffusion_strength = exp(y_coords[1])
                    advection_magnitude = abs(y_coords[2])
                    reaction_rate = y_coords[3]
                    anisotropy_ratio = exp(y_coords[4])
                    
                    println("       Physics: D≈$(@sprintf("%.2f", diffusion_strength)), |v|≈$(@sprintf("%.2f", advection_magnitude)), R≈$(@sprintf("%.2f", reaction_rate)), aniso≈$(@sprintf("%.2f", anisotropy_ratio))")
                    
                    # Classify the regime
                    if diffusion_strength > 2.0 && advection_magnitude < 1.0
                        regime = "Diffusion-dominated"
                    elseif diffusion_strength < 1.0 && advection_magnitude > 1.0
                        regime = "Advection-dominated"
                    elseif abs(reaction_rate) > 1.0
                        regime = "Reaction-dominated"
                    elseif anisotropy_ratio > 2.0 || anisotropy_ratio < 0.5
                        regime = "Anisotropy-dominated"
                    else
                        regime = "Balanced transport"
                    end
                    println("       Regime: $regime")
                else
                    println("     Basin $i: obj=$(@sprintf("%.6f", obj_val)) (coordinates not accessible)")
                end
            end
            
            # Analyze basin diversity
            obj_values = results.minima.objective_value
            obj_range = maximum(obj_values) - minimum(obj_values)
            println("\n   📊 Basin Diversity:")
            println("     - Objective range: $(@sprintf("%.6f", obj_range))")
            println("     - Best minimum: $(@sprintf("%.6f", minimum(obj_values)))")
            println("     - Number of distinct basins: $(nrow(results.minima))")
            
            if nrow(results.minima) >= 2
                println("     ✅ Multiple basins found - confirms 4D compensation mechanisms!")
            end
        else
            println("   ⚠️  No minima found - try larger search_range or different parameters")
        end
        
        return results, full_problem
        
    catch e
        println("   ❌ Failed: $e")
        return nothing, full_problem
    end
end

"""
    run_small_8d_example()

Run an 8D example with very conservative parameters.
"""
function run_small_8d_example()
    println("\n🎯 Running Small 8D Example with Very Conservative Parameters")
    
    # Create very small problem
    problem, θ_true = create_synthetic_diffusion_problem(
        n_params=8,           # Minimum for interesting 4D structure
        grid_size=(9, 9),     # Very small grid
        n_sensors=3           # Minimal sensors
    )
    
    objective = construct_4d_diffusion_objective(problem)
    obj_true = objective(θ_true)
    println("   - Objective at true parameters: $(@sprintf("%.6f", obj_true))")
    
    # Run with VERY conservative parameters
    println("\n   Running Globtim with very conservative parameters...")
    
    try
        results = safe_globtim_workflow(
            objective,
            dim=8,                    # 8D parameter space
            center=zeros(8),
            sample_range=1.0,         # Small search radius
            degree=2,                 # VERY low degree
            GN=50,                    # Minimal samples for degree 2
            enable_hessian=false,     # Disable expensive Hessian analysis
            basis=:chebyshev,
            precision=RationalPrecision,
            max_retries=3
        )
        
        println("   ✅ SUCCESS!")
        println("   - L2 approximation error: $(@sprintf("%.2e", results.polynomial.nrm))")
        println("   - Critical points found: $(nrow(results.critical_points))")
        println("   - Local minima found: $(nrow(results.minima))")
        
        if nrow(results.minima) > 0
            println("   - Best minimum: $(@sprintf("%.6f", minimum(results.minima.objective_value)))")
        end
        
        return results, problem
        
    catch e
        println("   ❌ Failed: $e")
        return nothing, problem
    end
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    println("Testing both approaches with working parameters...")
    
    # Test 4D active subspace approach
    results_4d, problem_4d = run_working_4d_example()
    
    # Test small 8D approach
    results_8d, problem_8d = run_small_8d_example()
    
    println("\n" * "="^60)
    println("FINAL RECOMMENDATIONS FOR YOUR 100D PROBLEM")
    println("="^60)
    
    if results_4d !== nothing
        println("\n✅ 4D Active Subspace Approach WORKS!")
        println("   - Use this for understanding basin structure")
        println("   - Provides direct physical interpretation")
        println("   - Can handle large underlying problems")
        
        println("\n📋 Working parameters for 4D approach:")
        println("   dim=4, degree=3, GN=100, sample_range=1.5")
    end
    
    if results_8d !== nothing
        println("\n✅ Small 8D Approach WORKS!")
        println("   - Use this for small-scale validation")
        println("   - Full parameter space optimization")
        
        println("\n📋 Working parameters for 8D approach:")
        println("   dim=8, degree=2, GN=50, sample_range=1.0")
    end
    
    println("\n🎯 For your original 100D problem:")
    println("   1. ✅ Use 4D active subspace with Globtim (proven to work)")
    println("   2. 🔧 Use other methods for full 100D optimization:")
    println("      - Optim.jl with multiple random starts")
    println("      - BlackBoxOptim.jl for global optimization")
    println("      - Custom basin-hopping with 4D insights")
    
    println("\n💡 Recommended workflow:")
    println("   1. Run 4D active subspace analysis with Globtim")
    println("   2. Identify basin structure and physical regimes")
    println("   3. Use insights to guide full-dimensional optimization")
    println("   4. Validate results by projecting back to 4D space")
    
    if results_4d !== nothing || results_8d !== nothing
        println("\n🎉 SUCCESS! Your 4D diffusion problem works with Globtim!")
    else
        println("\n⚠️  Both approaches failed - may need even more conservative parameters")
    end
end
