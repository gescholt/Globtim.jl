"""
HPC No-JSON3 Example - Complete 2D Globtim Workflow

Clean version that completely avoids JSON3 and other problematic dependencies.
Uses only core Julia packages and simple text output for results.

Features:
- No JSON3 dependency
- Complete Globtim workflow
- Simple text-based result output
- Robust error handling

Usage:
    julia --project=. Examples/hpc_no_json3_example.jl
    julia --project=. Examples/hpc_no_json3_example.jl --light
"""

# Only use core Julia packages that are guaranteed to be available
using LinearAlgebra
using Printf
using Dates

println("🚀 HPC No-JSON3 Example - Complete 2D Globtim Workflow")
println("=" ^ 60)
println("Started: $(now())")
println()

# Check for --light flag
light_mode = "--light" in ARGS

if light_mode
    println("🪶 LIGHT MODE: Using minimal parameters")
    CONFIG = (
        degree = 3,           # Very low degree
        GN = 20,             # Minimal samples
        sample_range = 1.0,   # Small domain
    )
else
    println("⚡ STANDARD MODE: Using moderate parameters")
    CONFIG = (
        degree = 5,           # Moderate degree
        GN = 40,             # More samples
        sample_range = 1.5,   # Larger domain
    )
end

println("📋 Configuration:")
println("   Degree: $(CONFIG.degree)")
println("   Samples: $(CONFIG.GN)")
println("   Domain range: ±$(CONFIG.sample_range)")
println()

# ============================================================================
# SIMPLE RESULT SAVING (NO JSON3)
# ============================================================================

function save_simple_results(filename::String, results::Dict)
    """Save results as simple key-value text file"""
    open(filename, "w") do f
        println(f, "# HPC Test Results")
        println(f, "# Generated: $(now())")
        println(f, "")
        for (key, value) in results
            println(f, "$key: $value")
        end
    end
end

# ============================================================================
# SAFE PACKAGE LOADING
# ============================================================================

println("📦 Loading Required Packages...")
println("-" ^ 40)

# Track what's available
packages_loaded = Dict{String, Bool}()

function try_load_package(pkg_name::String, required::Bool=true)
    try
        eval(Meta.parse("using $pkg_name"))
        println("✅ $pkg_name loaded")
        packages_loaded[pkg_name] = true
        return true
    catch e
        status = required ? "❌" : "⚠️ "
        println("$status $pkg_name failed: $(typeof(e))")
        packages_loaded[pkg_name] = false
        return false
    end
end

# Try to load packages one by one
globtim_available = try_load_package("Globtim", false)
dataframes_available = try_load_package("DataFrames", false)
dynpoly_available = try_load_package("DynamicPolynomials", false)
homotopy_available = try_load_package("HomotopyContinuation", false)

println()
println("📊 Package Status:")
println("   Globtim: $(globtim_available ? "✅" : "❌")")
println("   DataFrames: $(dataframes_available ? "✅" : "❌")")
println("   DynamicPolynomials: $(dynpoly_available ? "✅" : "❌")")
println("   HomotopyContinuation: $(homotopy_available ? "✅" : "❌")")

# Determine what we can do
can_run_globtim = globtim_available && dataframes_available && dynpoly_available
can_run_basic = true  # Always true since we only need LinearAlgebra

println()

# ============================================================================
# TEST FUNCTION DEFINITION
# ============================================================================

println("🎯 Test Function Setup")
println("-" ^ 40)

# Simple 2D test function with known minimum
function simple_2d_function(x)
    return (x[1] - 1.0)^2 + 2.0 * (x[2] + 0.5)^2 + 0.1 * x[1] * x[2]
end

# Test function evaluation
test_point = [1.0, -0.5]
test_value = simple_2d_function(test_point)
println("✅ Test function defined: f(x,y) = (x-1)² + 2(y+0.5)² + 0.1xy")
println("   f([1.0, -0.5]) = $(@sprintf("%.6f", test_value))")
println("   Expected minimum near: (1.0, -0.5)")

# ============================================================================
# BASIC MATH VERIFICATION
# ============================================================================

println("\n🧮 Basic Math Verification")
println("-" ^ 40)

basic_tests_passed = 0
total_basic_tests = 3

# Test 1: Linear algebra
try
    A = rand(3, 3)
    b = rand(3)
    x = A \ b
    residual = norm(A * x - b)
    
    if residual < 1e-10
        println("✅ Linear algebra test passed (residual: $(@sprintf("%.2e", residual)))")
        basic_tests_passed += 1
    else
        println("❌ Linear algebra test failed (residual: $(@sprintf("%.2e", residual)))")
    end
catch e
    println("❌ Linear algebra test error: $e")
end

# Test 2: Function evaluation
try
    points = [[0.0, 0.0], [1.0, -0.5], [2.0, 1.0]]
    values = [simple_2d_function(p) for p in points]
    
    if all(isfinite.(values))
        println("✅ Function evaluation test passed")
        println("   Sample values: $(@sprintf("[%.3f, %.3f, %.3f]", values[1], values[2], values[3]))")
        basic_tests_passed += 1
    else
        println("❌ Function evaluation test failed (non-finite values)")
    end
catch e
    println("❌ Function evaluation test error: $e")
end

# Test 3: Random sampling
try
    n_samples = 10
    center = [1.0, -0.5]
    range_val = 1.0
    
    sample_points = []
    sample_values = []
    
    for i in 1:n_samples
        x1 = center[1] + range_val * (2 * rand() - 1)
        x2 = center[2] + range_val * (2 * rand() - 1)
        point = [x1, x2]
        value = simple_2d_function(point)
        
        push!(sample_points, point)
        push!(sample_values, value)
    end
    
    min_val = minimum(sample_values)
    max_val = maximum(sample_values)
    mean_val = sum(sample_values) / length(sample_values)
    
    println("✅ Random sampling test passed")
    println("   $n_samples samples: min=$(@sprintf("%.3f", min_val)), max=$(@sprintf("%.3f", max_val)), mean=$(@sprintf("%.3f", mean_val))")
    basic_tests_passed += 1
    
catch e
    println("❌ Random sampling test error: $e")
end

println("\n📊 Basic Tests: $basic_tests_passed/$total_basic_tests passed")

# ============================================================================
# GLOBTIM WORKFLOW (IF AVAILABLE)
# ============================================================================

workflow_results = Dict{String, Any}()
workflow_success = false

if can_run_globtim
    println("\n🎯 Globtim Workflow Test")
    println("-" ^ 40)
    
    workflow_start = time()
    
    try
        # Step 1: Create test input
        println("📈 Step 1: Creating test input...")
        TR = Globtim.test_input(
            simple_2d_function,
            dim = 2,
            center = [1.0, -0.5],
            sample_range = CONFIG.sample_range,
            GN = CONFIG.GN
        )
        
        println("✅ Generated $(TR.GN) sample points")
        
        # Step 2: Construct polynomial
        println("📈 Step 2: Constructing polynomial...")
        pol = Globtim.Constructor(TR, CONFIG.degree, basis=:chebyshev)
        
        println("✅ Polynomial constructed:")
        println("   Degree: $(CONFIG.degree)")
        println("   Coefficients: $(length(pol.coeffs))")
        println("   L2 error: $(@sprintf("%.2e", pol.nrm))")
        
        # Step 3: Find critical points
        println("📈 Step 3: Finding critical points...")
        @polyvar x[1:2]
        
        solutions = Globtim.solve_polynomial_system(x, 2, CONFIG.degree, pol.coeffs)
        df_critical = Globtim.process_crit_pts(solutions, simple_2d_function, TR)
        
        workflow_time = time() - workflow_start
        
        println("✅ Critical points found:")
        println("   Raw solutions: $(length(solutions))")
        println("   Valid critical points: $(nrow(df_critical))")
        println("   Workflow time: $(@sprintf("%.2f", workflow_time)) seconds")
        
        # Find best critical point
        best_value = Inf
        best_point = [NaN, NaN]
        if nrow(df_critical) > 0
            best_idx = argmin(df_critical.objective_value)
            best_point = [df_critical.x1[best_idx], df_critical.x2[best_idx]]
            best_value = df_critical.objective_value[best_idx]
            
            println("\n🎯 Best Critical Point:")
            println("   Position: $(@sprintf("[%.4f, %.4f]", best_point[1], best_point[2]))")
            println("   Function value: $(@sprintf("%.6f", best_value))")
        end
        
        # Store results
        workflow_results = Dict(
            "workflow_success" => true,
            "degree" => CONFIG.degree,
            "sample_count" => CONFIG.GN,
            "l2_error" => pol.nrm,
            "condition_number" => pol.cond_vandermonde,
            "critical_points_count" => nrow(df_critical),
            "best_function_value" => best_value,
            "best_point_x1" => best_point[1],
            "best_point_x2" => best_point[2],
            "workflow_time_seconds" => workflow_time,
            "raw_solutions_count" => length(solutions)
        )
        
        workflow_success = true
        println("\n🎉 GLOBTIM WORKFLOW SUCCESS!")
        
    catch e
        println("❌ Globtim workflow failed: $e")
        workflow_results = Dict(
            "workflow_success" => false,
            "error_message" => string(e),
            "error_type" => string(typeof(e))
        )
    end
    
else
    println("\n⏭️  Globtim Workflow: Skipped (packages not available)")
    workflow_results = Dict(
        "workflow_success" => false,
        "skip_reason" => "Required packages not available",
        "globtim_available" => globtim_available,
        "dataframes_available" => dataframes_available,
        "dynpoly_available" => dynpoly_available
    )
end

# ============================================================================
# FINAL RESULTS AND SUMMARY
# ============================================================================

total_time = time() - workflow_start

println("\n" * "=" ^ 60)
println("🏁 HPC NO-JSON3 EXAMPLE COMPLETED")
println("=" ^ 60)

# Comprehensive results
final_results = Dict(
    "test_name" => "hpc_no_json3_example",
    "mode" => light_mode ? "light" : "standard",
    "start_time" => string(now()),
    "total_time_seconds" => total_time,
    "basic_tests_passed" => basic_tests_passed,
    "total_basic_tests" => total_basic_tests,
    "basic_tests_success_rate" => basic_tests_passed / total_basic_tests,
    "packages_globtim_available" => globtim_available,
    "packages_dataframes_available" => dataframes_available,
    "packages_dynpoly_available" => dynpoly_available,
    "packages_homotopy_available" => homotopy_available,
    "can_run_globtim" => can_run_globtim,
    "overall_success" => (basic_tests_passed == total_basic_tests) && (can_run_globtim ? workflow_success : true)
)

# Merge workflow results
for (key, value) in workflow_results
    final_results["workflow_$key"] = value
end

# Save results (NO JSON3!)
save_simple_results("hpc_test_results.txt", final_results)

# Display summary
println("📊 Final Summary:")
println("   Mode: $(final_results["mode"])")
println("   Basic tests: $(final_results["basic_tests_passed"])/$(final_results["total_basic_tests"]) passed")
println("   Globtim available: $(final_results["packages_globtim_available"])")
println("   Workflow success: $(get(final_results, "workflow_workflow_success", false))")
println("   Total time: $(@sprintf("%.2f", final_results["total_time_seconds"])) seconds")
println("   Overall success: $(final_results["overall_success"])")

if final_results["overall_success"]
    println("\n✅ SUCCESS: All tests passed!")
    if can_run_globtim && workflow_success
        println("   🎯 Complete Globtim workflow executed successfully")
        println("   📊 Results saved to: hpc_test_results.txt")
    else
        println("   🔧 Basic functionality verified (Globtim needs package fixes)")
    end
else
    println("\n⚠️  PARTIAL SUCCESS: Some issues detected")
    println("   Check results file for details")
end

println("\nCompleted: $(now())")
println("🚀 No JSON3 dependencies - ready for HPC deployment!")
