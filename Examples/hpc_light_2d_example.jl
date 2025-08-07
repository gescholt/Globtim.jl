"""
HPC Light 2D Example - Complete Globtim Workflow

This example demonstrates the complete Globtim pipeline on a simple 2D function
with lightweight parameters suitable for HPC cluster testing.

Features:
- Complete workflow: polynomial fitting → critical points → refinement
- Lightweight parameters for fast execution
- Comprehensive error handling
- Detailed progress reporting
- HPC-compatible (no visualization dependencies)

Usage:
    julia --project=. Examples/hpc_light_2d_example.jl
    julia --project=. Examples/hpc_light_2d_example.jl --light    # Extra lightweight
"""

using Pkg
Pkg.activate(".")

using Globtim
using DynamicPolynomials
using DataFrames
using LinearAlgebra
using Printf
using Dates

println("🚀 HPC Light 2D Example - Complete Globtim Workflow")
println("=" ^ 60)
println("Started: $(now())")
println()

# ============================================================================
# CONFIGURATION
# ============================================================================

# Check for --light flag
light_mode = "--light" in ARGS

if light_mode
    println("🪶 LIGHT MODE: Using minimal parameters for fastest execution")
    CONFIG = (
        degree = 4,           # Low degree for speed
        GN = 30,             # Minimal samples
        sample_range = 1.0,   # Small domain
        enable_hessian = false # Skip expensive Hessian analysis
    )
else
    println("⚡ STANDARD MODE: Using moderate parameters for thorough testing")
    CONFIG = (
        degree = 6,           # Moderate degree
        GN = 50,             # More samples for accuracy
        sample_range = 1.5,   # Larger domain
        enable_hessian = true # Full analysis
    )
end

println("📋 Configuration:")
println("   Degree: $(CONFIG.degree)")
println("   Samples: $(CONFIG.GN)")
println("   Domain range: ±$(CONFIG.sample_range)")
println("   Hessian analysis: $(CONFIG.enable_hessian)")
println()

# ============================================================================
# TEST FUNCTION DEFINITION
# ============================================================================

"""
Simple 2D test function with known critical points.
f(x,y) = (x-1)² + 2(y+0.5)² + 0.1*x*y

Known minimum: approximately at (1, -0.5)
"""
function simple_2d_function(x)
    return (x[1] - 1.0)^2 + 2.0 * (x[2] + 0.5)^2 + 0.1 * x[1] * x[2]
end

# Function properties
center = [1.0, -0.5]  # Near the known minimum
println("🎯 Test Function: Simple 2D quadratic")
println("   f(x,y) = (x-1)² + 2(y+0.5)² + 0.1*x*y")
println("   Center: $(center)")
println("   Expected minimum near: (1.0, -0.5)")
println()

# ============================================================================
# STEP 1: POLYNOMIAL APPROXIMATION
# ============================================================================

println("📈 STEP 1: Polynomial Approximation")
println("-" ^ 40)

step1_start = time()

try
    # Create test input
    println("Creating test input...")
    TR = test_input(
        simple_2d_function,
        dim = 2,
        center = center,
        sample_range = CONFIG.sample_range,
        GN = CONFIG.GN
    )
    
    println("✅ Generated $(TR.GN) sample points")
    println("   Domain: [$(TR.center[1] - TR.sample_range), $(TR.center[1] + TR.sample_range)] × [$(TR.center[2] - TR.sample_range), $(TR.center[2] + TR.sample_range)]")
    
    # Construct polynomial
    println("\nConstructing polynomial approximation...")
    pol = Constructor(TR, CONFIG.degree, basis=:chebyshev, precision=RationalPrecision)
    
    step1_time = time() - step1_start
    
    println("✅ Polynomial constructed successfully!")
    println("   Degree: $(CONFIG.degree)")
    println("   Basis: Chebyshev")
    println("   Coefficients: $(length(pol.coeffs))")
    println("   L2 approximation error: $(@sprintf("%.2e", pol.nrm))")
    println("   Condition number: $(@sprintf("%.2e", pol.cond_vandermonde))")
    println("   Time: $(@sprintf("%.2f", step1_time)) seconds")
    
    global polynomial = pol
    global test_input_data = TR
    
catch e
    println("❌ STEP 1 FAILED: $e")
    exit(1)
end

println()

# ============================================================================
# STEP 2: CRITICAL POINT FINDING
# ============================================================================

println("🔍 STEP 2: Critical Point Finding")
println("-" ^ 40)

step2_start = time()

try
    # Set up polynomial variables
    @polyvar x[1:2]
    
    println("Solving polynomial system...")
    solutions = solve_polynomial_system(x, 2, CONFIG.degree, polynomial.coeffs)
    
    println("Processing critical points...")
    df_critical = process_crit_pts(solutions, simple_2d_function, test_input_data)
    
    step2_time = time() - step2_start
    
    println("✅ Critical points found successfully!")
    println("   Raw solutions: $(length(solutions))")
    println("   Valid critical points: $(nrow(df_critical))")
    println("   Time: $(@sprintf("%.2f", step2_time)) seconds")
    
    if nrow(df_critical) > 0
        println("\n📊 Critical Points Summary:")
        println("   Minimum function value: $(@sprintf("%.6f", minimum(df_critical.objective_value)))")
        println("   Maximum function value: $(@sprintf("%.6f", maximum(df_critical.objective_value)))")
        
        # Show best critical point
        best_idx = argmin(df_critical.objective_value)
        best_point = [df_critical.x1[best_idx], df_critical.x2[best_idx]]
        best_value = df_critical.objective_value[best_idx]
        println("   Best critical point: $(@sprintf("[%.4f, %.4f]", best_point[1], best_point[2]))")
        println("   Best function value: $(@sprintf("%.6f", best_value))")
    end
    
    global critical_points = df_critical
    
catch e
    println("❌ STEP 2 FAILED: $e")
    exit(1)
end

println()

# ============================================================================
# STEP 3: CRITICAL POINT REFINEMENT (Optional)
# ============================================================================

if CONFIG.enable_hessian
    println("🔬 STEP 3: Critical Point Refinement & Classification")
    println("-" ^ 40)
    
    step3_start = time()
    
    try
        println("Refining critical points with BFGS...")
        df_refined, df_minima = analyze_critical_points(
            simple_2d_function,
            copy(critical_points),
            test_input_data,
            tol_dist = 0.001,
            enable_hessian = true
        )
        
        step3_time = time() - step3_start
        
        println("✅ Critical point refinement completed!")
        println("   Refined points: $(nrow(df_refined))")
        println("   Local minima identified: $(nrow(df_minima))")
        println("   Time: $(@sprintf("%.2f", step3_time)) seconds")
        
        if nrow(df_minima) > 0
            println("\n🎯 Local Minima Found:")
            for i in 1:nrow(df_minima)
                x_min = [df_minima.x1[i], df_minima.x2[i]]
                f_min = df_minima.objective_value[i]
                println("   Minimum $i: $(@sprintf("[%.4f, %.4f]", x_min[1], x_min[2])) → f = $(@sprintf("%.6f", f_min))")
            end
        end
        
        global refined_points = df_refined
        global local_minima = df_minima
        
    catch e
        println("⚠️  STEP 3 FAILED (non-critical): $e")
        println("   Continuing with unrefined critical points...")
        global refined_points = nothing
        global local_minima = nothing
    end
else
    println("⏭️  STEP 3: Skipped (Hessian analysis disabled in light mode)")
    global refined_points = nothing
    global local_minima = nothing
end

println()

# ============================================================================
# FINAL SUMMARY
# ============================================================================

total_time = time() - step1_start

println("🏁 WORKFLOW COMPLETED SUCCESSFULLY!")
println("=" ^ 60)
println("📊 Final Results:")
println("   Polynomial degree: $(CONFIG.degree)")
println("   Sample points: $(CONFIG.GN)")
println("   L2 approximation error: $(@sprintf("%.2e", polynomial.nrm))")
println("   Critical points found: $(nrow(critical_points))")

if CONFIG.enable_hessian && local_minima !== nothing
    println("   Local minima identified: $(nrow(local_minima))")
end

println("   Total execution time: $(@sprintf("%.2f", total_time)) seconds")
println()

println("✅ SUCCESS: Complete 2D Globtim workflow executed successfully!")
println("   This example demonstrates the full pipeline:")
println("   1. ✓ Polynomial approximation")
println("   2. ✓ Critical point finding")
if CONFIG.enable_hessian
    println("   3. ✓ Critical point refinement & classification")
else
    println("   3. ⏭ Critical point refinement (skipped in light mode)")
end

println()
println("🎯 Ready for HPC cluster deployment!")
println("   Use --light flag for fastest execution on cluster")
println("   Example: julia --project=. Examples/hpc_light_2d_example.jl --light")

println("\nCompleted: $(now())")
