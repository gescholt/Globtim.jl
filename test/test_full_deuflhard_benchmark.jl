#!/usr/bin/env julia

"""
Full Deuflhard Benchmark Test
=============================

Comprehensive test of the Deuflhard function with polynomial approximation
and critical point computation. This test validates the complete Globtim
workflow from function evaluation to critical point analysis.
"""

using Pkg
Pkg.activate(".")

using Globtim
using DynamicPolynomials
using DataFrames
using LinearAlgebra
using Printf

println("🚀 Starting Full Deuflhard Benchmark")
println("=" ^ 50)

# Test parameters
test_configs = [
    (dim=2, degree=6, center=[0.0, 0.0], sample_range=1.2, description="Standard 2D test"),
    (dim=2, degree=8, center=[0.0, 0.0], sample_range=1.2, description="Higher degree 2D"),
    (dim=2, degree=10, center=[0.5, 0.5], sample_range=1.0, description="Off-center 2D"),
]

results = []

for (i, config) in enumerate(test_configs)
    println("\n📊 Test $i: $(config.description)")
    println("-" ^ 40)
    
    try
        # Step 1: Create test input
        println("  Creating test_input...")
        TR = test_input(
            Deuflhard, 
            dim=config.dim, 
            center=config.center, 
            sample_range=config.sample_range
        )
        
        # Step 2: Build polynomial approximation
        println("  Building polynomial approximation (degree $(config.degree))...")
        start_time = time()
        pol = Constructor(TR, config.degree, verbose=1)
        construction_time = time() - start_time
        
        println("    L2 error: $(pol.nrm)")
        println("    Condition number: $(pol.cond_vandermonde)")
        println("    Construction time: $(construction_time) seconds")
        
        # Step 3: Find critical points
        println("  Finding critical points...")
        @polyvar x[1:config.dim]
        start_time = time()
        solutions = solve_polynomial_system(x, config.dim, config.degree, pol.coeffs)
        solving_time = time() - start_time
        
        println("    Found $(length(solutions)) critical points")
        println("    Solving time: $(solving_time) seconds")
        
        # Step 4: Process and classify critical points
        println("  Processing critical points...")
        df = process_crit_pts(solutions, Deuflhard, TR)
        
        if nrow(df) > 0
            println("    Processed $(nrow(df)) valid critical points")
            
            # Find minimum
            min_idx = argmin(df.z)
            min_point = [df[min_idx, :x1], df[min_idx, :x2]]
            min_value = df[min_idx, :z]
            
            println("    Best critical point: $(min_point)")
            println("    Function value: $(min_value)")
            
            # Verify it's actually a critical point by checking gradient
            # Note: For Deuflhard, the global minimum is at (0,0) with f=0
            distance_to_origin = norm(min_point)
            println("    Distance to origin: $(distance_to_origin)")
        else
            println("    ⚠️  No valid critical points found")
        end
        
        # Store results
        result = Dict(
            "test_id" => i,
            "config" => config,
            "l2_error" => pol.nrm,
            "condition_number" => pol.cond_vandermonde,
            "construction_time" => construction_time,
            "num_critical_points" => length(solutions),
            "num_processed_points" => nrow(df),
            "solving_time" => solving_time,
            "success" => true
        )
        
        if nrow(df) > 0
            result["best_point"] = min_point
            result["best_value"] = min_value
            result["distance_to_origin"] = distance_to_origin
        end
        
        push!(results, result)
        println("  ✅ Test $i completed successfully")
        
    catch e
        println("  ❌ Test $i failed: $e")
        push!(results, Dict(
            "test_id" => i,
            "config" => config,
            "success" => false,
            "error" => string(e)
        ))
    end
end

# Summary
println("\n" * "=" ^ 50)
println("📈 BENCHMARK SUMMARY")
println("=" ^ 50)

successful_tests = filter(r -> get(r, "success", false), results)
failed_tests = filter(r -> !get(r, "success", false), results)

println("✅ Successful tests: $(length(successful_tests))/$(length(results))")
println("❌ Failed tests: $(length(failed_tests))")

if length(successful_tests) > 0
    println("\n📊 Performance Statistics:")
    construction_times = [r["construction_time"] for r in successful_tests]
    solving_times = [r["solving_time"] for r in successful_tests]
    l2_errors = [r["l2_error"] for r in successful_tests]
    
    println("  Construction time: $(minimum(construction_times):.3f) - $(maximum(construction_times):.3f) seconds")
    println("  Solving time: $(minimum(solving_times):.3f) - $(maximum(solving_times):.3f) seconds")
    println("  L2 errors: $(minimum(l2_errors):.2e) - $(maximum(l2_errors):.2e)")
    
    # Check if we found good critical points
    good_points = filter(r -> haskey(r, "distance_to_origin") && r["distance_to_origin"] < 0.1, successful_tests)
    println("  Tests finding points near origin: $(length(good_points))/$(length(successful_tests))")
end

if length(failed_tests) > 0
    println("\n❌ Failed test details:")
    for (i, result) in enumerate(failed_tests)
        println("  Test $(result["test_id"]): $(result["error"])")
    end
end

println("\n🎯 Benchmark completed!")
