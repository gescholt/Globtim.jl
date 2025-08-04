"""
Simple example showing how to use your 4D diffusion problem with Globtim

This shows the exact steps to go from your existing problem setup to Globtim results.
"""

using Globtim
include("diffusion_inverse/src/diffusion_problem.jl")

println("=== Simple Globtim Example with 4D Diffusion Problem ===")

# Step 1: You already have this working!
println("\n1. Creating your problem (this is what you already did)...")
problem, θ_true = create_synthetic_diffusion_problem(
    n_params=100,
    grid_size=(21, 21),
    n_sensors=12
)
println("✅ Problem created successfully")

# Step 2: Create the objective function (you need this)
println("\n2. Creating objective function...")
objective = construct_4d_diffusion_objective(problem)
println("✅ Objective function created")

# Step 3: Test the objective function
println("\n3. Testing objective function...")
test_obj = objective(θ_true)
println("✅ Objective at true parameters: $test_obj")

# Step 4: Use Globtim (this is what you were missing)
println("\n4. Running Globtim...")
println("   Using conservative parameters for 100D problem...")

try
    # This is the correct Globtim function call
    results = safe_globtim_workflow(
        objective,                    # Your objective function
        dim=100,                     # Your parameter dimension
        center=zeros(100),           # Search center (origin)
        sample_range=2.0,            # Search radius
        degree=4,                    # Conservative polynomial degree for 100D
        GN=150,                      # Sample count
        enable_hessian=true,         # Enable Hessian analysis
        basis=:chebyshev,           # Basis type
        precision=RationalPrecision, # Precision type
        max_retries=3               # Error handling
    )
    
    println("✅ Globtim completed successfully!")
    println("\nResults summary:")
    println("   - L2 approximation error: $(results.polynomial.nrm)")
    println("   - Critical points found: $(nrow(results.critical_points))")
    println("   - Local minima found: $(nrow(results.minima))")
    
    if nrow(results.minima) > 0
        println("\nFirst few minima:")
        for i in 1:min(3, nrow(results.minima))
            obj_val = results.minima[i, :objective_value]
            println("   Basin $i: objective = $obj_val")
        end
    end
    
    println("\n🎉 SUCCESS! Your 4D diffusion problem works with Globtim!")
    
catch e
    println("❌ Globtim failed: $e")
    println("\n🔧 Try these smaller parameters:")
    println("   - Reduce degree to 3")
    println("   - Reduce GN to 100") 
    println("   - Reduce sample_range to 1.5")
    println("   - Or use a smaller problem size (n_params=50)")
end

println("\n=== How to use this in your own code ===")
println("""
# Your working code:
problem, θ_true = create_synthetic_diffusion_problem(n_params=100, grid_size=(21, 21), n_sensors=12)
objective = construct_4d_diffusion_objective(problem)

# Add this Globtim call:
using Globtim
results = safe_globtim_workflow(
    objective, 
    dim=100, center=zeros(100), sample_range=2.0,
    degree=4, GN=150
)

# Access results:
println("Minima found: ", nrow(results.minima))
println("L2 error: ", results.polynomial.nrm)
""")

println("\n=== Parameter Guidelines for Different Problem Sizes ===")
println("n_params=20:  degree=6, GN=100, sample_range=2.0")
println("n_params=50:  degree=5, GN=150, sample_range=2.0") 
println("n_params=100: degree=4, GN=150, sample_range=2.0")
println("n_params=200: degree=3, GN=200, sample_range=1.5")
