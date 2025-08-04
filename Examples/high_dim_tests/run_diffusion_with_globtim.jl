"""
Run 4D Diffusion Inverse Problem with Globtim

This script demonstrates how to use the 4D diffusion inverse problem
with Globtim's basin detection capabilities.
"""

using Globtim
using LinearAlgebra
using Printf

# Include the diffusion problem implementation
include("diffusion_inverse/src/diffusion_problem.jl")

"""
    run_diffusion_with_globtim(; n_params=50, grid_size=(15, 15), n_sensors=8, 
                               degree=6, GN=200, sample_range=2.0)

Run the 4D diffusion inverse problem with Globtim basin detection.
"""
function run_diffusion_with_globtim(; n_params=50, grid_size=(15, 15), n_sensors=8, 
                                    degree=6, GN=200, sample_range=2.0)
    
    println("="^60)
    println("4D DIFFUSION INVERSE PROBLEM WITH GLOBTIM")
    println("="^60)
    
    # === Step 1: Create the 4D diffusion problem ===
    println("\n1. Creating 4D diffusion inverse problem...")
    problem, θ_true = create_synthetic_diffusion_problem(
        n_params=n_params,
        grid_size=grid_size,
        domain_size=(1.0, 1.0),
        n_sensors=n_sensors
    )
    
    println("   - Parameter dimension: $n_params")
    println("   - Active subspace: 4D [Diffusion, Advection, Reaction, Anisotropy]")
    println("   - Grid size: $grid_size")
    println("   - Number of sensors: $n_sensors")
    
    # === Step 2: Construct objective function ===
    println("\n2. Constructing objective function...")
    objective = construct_4d_diffusion_objective(problem)
    
    # Test the objective function
    obj_true = objective(θ_true)
    println("   - Objective at true parameters: $(@sprintf("%.6f", obj_true))")
    
    # === Step 3: Set up Globtim parameters ===
    println("\n3. Setting up Globtim parameters...")
    center = zeros(n_params)  # Center the search at origin
    
    println("   - Search center: origin ($(n_params)D)")
    println("   - Search radius: $sample_range")
    println("   - Polynomial degree: $degree")
    println("   - Sample count: $GN")
    
    # === Step 4: Run Globtim basin detection ===
    println("\n4. Running Globtim basin detection...")
    println("   This may take a few minutes for high-dimensional problems...")
    
    start_time = time()
    
    try
        # Use the safe workflow function
        results = safe_globtim_workflow(
            objective,
            dim=n_params,
            center=center,
            sample_range=sample_range,
            degree=degree,
            GN=GN,
            enable_hessian=true,
            basis=:chebyshev,
            precision=RationalPrecision,
            max_retries=3
        )
        
        end_time = time()
        total_time = end_time - start_time
        
        # === Step 5: Analyze results ===
        println("\n5. Analyzing results...")
        println("   ✅ Globtim completed successfully!")
        println("   - Total time: $(@sprintf("%.2f", total_time)) seconds")
        println("   - L2 approximation error: $(@sprintf("%.2e", results.polynomial.nrm))")
        println("   - Critical points found: $(nrow(results.critical_points))")
        println("   - Local minima identified: $(nrow(results.minima))")
        
        if haskey(results.analysis_summary, "bfgs_convergence_rate")
            conv_rate = results.analysis_summary["bfgs_convergence_rate"]
            println("   - BFGS convergence rate: $(@sprintf("%.1f", conv_rate*100))%")
        end
        
        # === Step 6: Examine the basins ===
        println("\n6. Basin analysis...")
        
        if nrow(results.minima) > 0
            println("   Found $(nrow(results.minima)) local minima:")
            
            for i in 1:min(5, nrow(results.minima))  # Show first 5 minima
                row = results.minima[i, :]
                obj_val = row.objective_value
                println("     Basin $i: objective = $(@sprintf("%.6f", obj_val))")
                
                # Project to 4D active subspace for interpretation
                if haskey(row, :coordinates) || hasproperty(row, :coordinates)
                    coords = row.coordinates
                    if length(coords) == n_params
                        y_coords = problem.W_active' * coords
                        println("       4D coordinates: [$(@sprintf("%.3f", y_coords[1])), $(@sprintf("%.3f", y_coords[2])), $(@sprintf("%.3f", y_coords[3])), $(@sprintf("%.3f", y_coords[4]))]")
                        
                        # Interpret the physics
                        diffusion_strength = exp(y_coords[1])
                        advection_magnitude = abs(y_coords[2])
                        reaction_rate = y_coords[3]
                        anisotropy_ratio = exp(y_coords[4])
                        
                        println("       Physics: D≈$(@sprintf("%.2f", diffusion_strength)), |v|≈$(@sprintf("%.2f", advection_magnitude)), R≈$(@sprintf("%.2f", reaction_rate)), aniso≈$(@sprintf("%.2f", anisotropy_ratio))")
                    end
                end
            end
            
            if nrow(results.minima) > 5
                println("     ... and $(nrow(results.minima) - 5) more minima")
            end
        else
            println("   ⚠️  No local minima found - try increasing sample_range or degree")
        end
        
        # === Step 7: Validate 4D structure ===
        println("\n7. Validating 4D active subspace structure...")
        
        # Check if the basins correspond to different physical regimes
        if nrow(results.minima) >= 2
            println("   ✅ Multiple basins found - consistent with 4D compensation mechanisms")
            println("   Expected mechanisms:")
            println("     - High diffusion ↔ Low advection transport")
            println("     - Transport-dominated ↔ Reaction-dominated regimes")
            println("     - Isotropic ↔ Anisotropic diffusion patterns")
            println("     - Different sensor information content")
        else
            println("   ⚠️  Few basins found - may need larger search domain or different parameters")
        end
        
        return results, problem, objective
        
    catch e
        end_time = time()
        total_time = end_time - start_time
        
        println("\n❌ Globtim failed after $(@sprintf("%.2f", total_time)) seconds")
        println("Error: $e")
        
        # Provide troubleshooting suggestions
        println("\n🔧 Troubleshooting suggestions:")
        println("   - Try smaller degree (current: $degree)")
        println("   - Try fewer samples (current: $GN)")
        println("   - Try smaller problem size (current: $n_params params)")
        println("   - Try smaller search radius (current: $sample_range)")
        
        return nothing, problem, objective
    end
end

"""
    run_small_test()

Run a small test to verify everything works.
"""
function run_small_test()
    println("Running small test first...")
    
    return run_diffusion_with_globtim(
        n_params=20,      # Small parameter space
        grid_size=(11, 11), # Small grid
        n_sensors=4,      # Few sensors
        degree=4,         # Low degree
        GN=100,          # Moderate samples
        sample_range=1.5  # Moderate search radius
    )
end

"""
    run_medium_test()

Run a medium-sized test.
"""
function run_medium_test()
    println("Running medium test...")
    
    return run_diffusion_with_globtim(
        n_params=50,      # Medium parameter space
        grid_size=(15, 15), # Medium grid
        n_sensors=8,      # Moderate sensors
        degree=5,         # Medium degree
        GN=200,          # Good samples
        sample_range=2.0  # Good search radius
    )
end

"""
    run_production_test()

Run a production-sized test.
"""
function run_production_test()
    println("Running production test...")
    
    return run_diffusion_with_globtim(
        n_params=100,     # Full parameter space
        grid_size=(21, 21), # Full grid
        n_sensors=12,     # Many sensors
        degree=6,         # Higher degree
        GN=300,          # Many samples
        sample_range=2.5  # Large search radius
    )
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    println("4D Diffusion Inverse Problem - Globtim Integration")
    println("Choose test size:")
    println("1. Small test (fast, ~1-2 minutes)")
    println("2. Medium test (moderate, ~5-10 minutes)")  
    println("3. Production test (slow, ~15-30 minutes)")
    
    # For automatic execution, run small test
    println("\nRunning small test automatically...")
    results, problem, objective = run_small_test()
    
    if results !== nothing
        println("\n🎉 SUCCESS! The 4D diffusion inverse problem works with Globtim!")
        println("\nTo run larger tests:")
        println("julia> include(\"Examples/high_dim_tests/run_diffusion_with_globtim.jl\")")
        println("julia> results, problem, objective = run_medium_test()")
        println("julia> results, problem, objective = run_production_test()")
    else
        println("\n⚠️  Small test failed. Check the troubleshooting suggestions above.")
    end
end
