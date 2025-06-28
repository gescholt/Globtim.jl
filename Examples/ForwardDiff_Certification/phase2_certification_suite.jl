# Proper way to initiate example files when developing new features
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim
using DynamicPolynomials, DataFrames

# Test Phase 2 Hessian Classification with a simple test case
println("=== Testing Phase 2 Hessian Classification ===")

# Use a simple 2D function with known critical points
f = x -> x[1]^2 + x[2]^2  # Simple quadratic with minimum at (0,0)

# Create artificial critical points around the minimum for testing
test_points = DataFrame(
    x1 = [0.0, 0.1, -0.1, 0.0, 0.0],
    x2 = [0.0, 0.0, 0.0, 0.1, -0.1],
    z = [f([0.0, 0.0]), f([0.1, 0.0]), f([-0.1, 0.0]), f([0.0, 0.1]), f([0.0, -0.1])]
)

# Create a minimal test_input structure for the function
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)

println("Test points:")
println(test_points)
println()

# Test Phase 2 analysis
println("Running Phase 2 Hessian analysis...")
try
    df_enhanced, df_min = analyze_critical_points(
        f, test_points, TR, 
        enable_hessian=true, 
        verbose=true,
        tol_dist=0.1  # Larger tolerance for this test
    )
    
    println("\n=== Phase 2 Results ===")
    println("Enhanced DataFrame columns: ", names(df_enhanced))
    println("\nCritical point classifications:")
    for i in 1:nrow(df_enhanced)
        println("Point $i: ($(df_enhanced.x1[i]), $(df_enhanced.x2[i])) -> $(df_enhanced.critical_point_type[i])")
    end
    
    if "hessian_norm" in names(df_enhanced)
        println("\nHessian norms: ", df_enhanced.hessian_norm)
    end
    
    if "hessian_condition_number" in names(df_enhanced)
        println("Condition numbers: ", df_enhanced.hessian_condition_number)
    end
    
    println("\n✅ Phase 2 Hessian analysis completed successfully!")
    
catch e
    println("❌ Error in Phase 2 analysis: $e")
    println("\nFull error details:")
    showerror(stdout, e, catch_backtrace())
end