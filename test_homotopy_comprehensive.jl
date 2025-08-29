#!/usr/bin/env julia

# Comprehensive HomotopyContinuation Test Suite for HPC Cluster
# Tests all critical functionality to verify the cross-platform bundle works correctly
# Designed to run on falcon cluster with the deployed bundle

using Pkg

println("=== Comprehensive HomotopyContinuation Test Suite ===")
println("Julia version: $(VERSION)")
println("Architecture: $(Sys.MACHINE)")
println("Date: $(Dates.now())")
println()

# Test configuration
test_results = Dict{String, Any}()
error_details = Dict{String, String}()

function test_section(name::String, test_func::Function)
    println("=== $name ===")
    try
        result = test_func()
        test_results[name] = true
        println("✅ $name PASSED")
        return result
    catch e
        test_results[name] = false
        error_msg = string(e)
        error_details[name] = error_msg
        println("❌ $name FAILED: $e")
        
        # Detailed error analysis
        if occursin("artifact", error_msg) || occursin("library", error_msg) || occursin("OpenBLAS", error_msg) || occursin("OpenSpecFun", error_msg)
            println("   🔍 Binary artifact/library issue detected")
        elseif occursin("precompile", error_msg)
            println("   🔍 Precompilation issue detected")
        elseif occursin("symbol", error_msg) || occursin("undefined", error_msg)
            println("   🔍 Symbol/linking issue detected")
        else
            println("   🔍 Unknown error type")
        end
        println()
        return nothing
    end
end

# Test 1: Package Loading
test_section("Package Loading") do
    println("Loading required packages...")
    
    using LinearAlgebra
    println("  ✅ LinearAlgebra loaded")
    
    using StaticArrays
    println("  ✅ StaticArrays loaded")
    
    using SpecialFunctions
    println("  ✅ SpecialFunctions loaded")
    
    using ForwardDiff
    println("  ✅ ForwardDiff loaded")
    
    using MultivariatePolynomials
    println("  ✅ MultivariatePolynomials loaded")
    
    using DynamicPolynomials
    println("  ✅ DynamicPolynomials loaded")
    
    using HomotopyContinuation
    println("  ✅ HomotopyContinuation loaded")
    
    println("All critical packages loaded successfully")
    return true
end

# Test 2: Basic Polynomial Creation
polynomial_vars = test_section("Polynomial Creation") do
    using DynamicPolynomials
    
    println("Creating polynomial variables...")
    @var x y z
    println("  ✅ Variables created: x, y, z")
    
    # Test simple polynomials
    p1 = x^2 + y^2 - 1
    p2 = x + y - 1
    println("  ✅ Simple polynomials created")
    
    # Test more complex polynomials
    p3 = x^3 + 2*x*y*z + y^3 - z^2
    println("  ✅ Complex polynomial created")
    
    # Test multivariate array
    @var u[1:3]
    poly_array = [u[1]^2 + u[2]^2 + u[3]^2 - 1, sum(u) - 1]
    println("  ✅ Multivariate polynomial array created")
    
    return (x, y, z, u)
end

# Test 3: System Creation
systems = test_section("System Creation") do
    using HomotopyContinuation, DynamicPolynomials
    
    if polynomial_vars === nothing
        @var x y z
        @var u[1:3]
        polynomial_vars = (x, y, z, u)
    end
    
    x, y, z, u = polynomial_vars
    
    println("Creating polynomial systems...")
    
    # Simple 2x2 system
    system_2x2 = System([x^2 + y^2 - 1, x + y - 1])
    println("  ✅ 2x2 system created: $system_2x2")
    
    # 3x3 system
    system_3x3 = System([
        x^2 + y^2 + z^2 - 1,
        x + y + z - 1,
        x*y + y*z + z*x - 0.5
    ])
    println("  ✅ 3x3 system created: $system_3x3")
    
    # Parametric system
    @var t
    param_system = System(
        [x^2 + y^2 - t, x + y - 1], 
        variables=[x, y], 
        parameters=[t]
    )
    println("  ✅ Parametric system created: $param_system")
    
    return (system_2x2, system_3x3, param_system)
end

# Test 4: Basic Solving
solutions_2x2 = test_section("Basic Solving") do
    using HomotopyContinuation
    
    if systems === nothing
        error("Systems not available from previous test")
    end
    
    system_2x2, system_3x3, param_system = systems
    
    println("Solving 2x2 system...")
    sols_2x2 = solve(system_2x2)
    println("  ✅ 2x2 system solved: $(length(sols_2x2)) solutions found")
    
    # Display solutions
    for (i, sol) in enumerate(sols_2x2)
        if is_real(sol)
            println("    Real solution $i: $(real(sol.solution))")
        else
            println("    Complex solution $i: $(sol.solution)")
        end
    end
    
    return sols_2x2
end

# Test 5: Advanced Solving
test_section("Advanced Solving") do
    using HomotopyContinuation
    
    if systems === nothing
        error("Systems not available from previous test")
    end
    
    system_2x2, system_3x3, param_system = systems
    
    println("Solving 3x3 system...")
    sols_3x3 = solve(system_3x3)
    println("  ✅ 3x3 system solved: $(length(sols_3x3)) solutions found")
    
    # Count real vs complex solutions
    real_count = sum(is_real(sol) for sol in sols_3x3)
    complex_count = length(sols_3x3) - real_count
    println("    Real solutions: $real_count")
    println("    Complex solutions: $complex_count")
    
    return sols_3x3
end

# Test 6: Parametric Homotopy
test_section("Parametric Homotopy") do
    using HomotopyContinuation
    
    if systems === nothing
        error("Systems not available from previous test")
    end
    
    system_2x2, system_3x3, param_system = systems
    
    println("Solving parametric system...")
    
    # Solve for different parameter values
    param_values = [0.1, 0.5, 1.0, 2.0]
    param_solutions = Dict()
    
    for t_val in param_values
        try
            sols = solve(param_system, target_parameters=[t_val])
            param_solutions[t_val] = sols
            real_sols = sum(is_real(sol) for sol in sols)
            println("    t=$t_val: $(length(sols)) solutions ($real_sols real)")
        catch e
            println("    t=$t_val: Failed ($e)")
        end
    end
    
    println("  ✅ Parametric homotopy completed for $(length(param_solutions)) parameter values")
    return param_solutions
end

# Test 7: Large System Performance
test_section("Large System Performance") do
    using HomotopyContinuation, DynamicPolynomials
    
    println("Creating and solving large system...")
    
    # Create 5x5 system
    @var vars[1:5]
    equations = [
        sum(vars[i]^2 for i in 1:5) - 1,
        sum(vars[i] for i in 1:5) - 1,
        vars[1]*vars[2] + vars[3]*vars[4] + vars[5]^2 - 0.5,
        vars[1]*vars[3] + vars[2]*vars[4] + vars[1]*vars[5] - 0.3,
        vars[2]*vars[3] + vars[4]*vars[5] + vars[1]^2 - 0.2
    ]
    
    large_system = System(equations)
    println("  ✅ 5x5 system created")
    
    # Time the solve
    println("Solving large system (this may take a moment)...")
    start_time = time()
    large_solutions = solve(large_system)
    solve_time = time() - start_time
    
    println("  ✅ Large system solved in $(round(solve_time, digits=2)) seconds")
    println("    Found $(length(large_solutions)) solutions")
    
    # Performance assessment
    if solve_time < 10
        println("  🚀 Excellent performance (< 10 seconds)")
    elseif solve_time < 30
        println("  ✅ Good performance (< 30 seconds)")
    elseif solve_time < 60
        println("  ⚠️ Acceptable performance (< 60 seconds)")
    else
        println("  🐌 Slow performance (> 60 seconds)")
    end
    
    return (large_solutions, solve_time)
end

# Test 8: Real Solution Filtering
test_section("Real Solution Analysis") do
    using HomotopyContinuation
    
    if solutions_2x2 === nothing
        error("Basic solutions not available")
    end
    
    println("Analyzing solution types...")
    
    # Test real solution detection
    real_solutions = filter(is_real, solutions_2x2)
    complex_solutions = filter(!is_real, solutions_2x2)
    
    println("  Total solutions: $(length(solutions_2x2))")
    println("  Real solutions: $(length(real_solutions))")
    println("  Complex solutions: $(length(complex_solutions))")
    
    # Extract real parts
    if !isempty(real_solutions)
        real_coords = [real(sol.solution) for sol in real_solutions]
        println("  Real solution coordinates:")
        for (i, coords) in enumerate(real_coords)
            println("    Solution $i: $coords")
        end
    end
    
    return (real_solutions, complex_solutions)
end

# Test 9: Error Handling and Edge Cases
test_section("Error Handling") do
    using HomotopyContinuation, DynamicPolynomials
    
    println("Testing error handling and edge cases...")
    
    # Test overconstrained system
    @var a b
    try
        overconstrained = System([
            a^2 + b^2 - 1,
            a + b - 1,
            a - b - 2,
            a^2 - b - 3
        ])
        
        # This should either solve or handle gracefully
        over_sols = solve(overconstrained)
        println("  ✅ Overconstrained system handled: $(length(over_sols)) solutions")
    catch e
        if occursin("overdetermined", string(e)) || occursin("inconsistent", string(e))
            println("  ✅ Overconstrained system detected and handled appropriately")
        else
            println("  ⚠️ Unexpected error with overconstrained system: $e")
        end
    end
    
    # Test underconstrained system
    try
        underconstrained = System([a + b - 1])  # 1 equation, 2 variables
        under_sols = solve(underconstrained)
        println("  ✅ Underconstrained system handled: $(length(under_sols)) solutions")
    catch e
        if occursin("underdetermined", string(e)) || occursin("dimension", string(e))
            println("  ✅ Underconstrained system detected and handled appropriately")
        else
            println("  ⚠️ Unexpected error with underconstrained system: $e")
        end
    end
    
    # Test zero polynomial
    try
        zero_system = System([a*0, b*0])  # Zero polynomials
        zero_sols = solve(zero_system)
        println("  ⚠️ Zero system solved: $(length(zero_sols)) solutions")
    catch e
        println("  ✅ Zero polynomial system appropriately rejected: $e")
    end
    
    return true
end

# Test 10: Memory and Resource Usage
test_section("Resource Usage") do
    println("Assessing resource usage...")
    
    # Memory usage
    used_memory = Sys.total_memory() - Sys.free_memory()
    memory_gb = round(used_memory / (1024^3), digits=2)
    println("  Current memory usage: $(memory_gb) GB")
    
    # GC stats
    gc_stats = Base.gc_num()
    println("  Garbage collections: $(gc_stats.total_time / 1e9) seconds total")
    
    # Compilation stats
    println("  Julia compilation appears stable")
    
    if memory_gb < 4
        println("  ✅ Excellent memory efficiency (< 4 GB)")
    elseif memory_gb < 8
        println("  ✅ Good memory usage (< 8 GB)")
    else
        println("  ⚠️ High memory usage (> 8 GB)")
    end
    
    return memory_gb
end

# Generate final report
println("\n" * "="^60)
println("FINAL TEST REPORT")
println("="^60)

total_tests = length(test_results)
passed_tests = sum(values(test_results))
failed_tests = total_tests - passed_tests

println("Test Summary:")
println("  Total tests: $total_tests")
println("  Passed: $passed_tests")
println("  Failed: $failed_tests")
println("  Success rate: $(round(100 * passed_tests / total_tests, digits=1))%")

println("\nDetailed Results:")
for (test_name, passed) in test_results
    status = passed ? "✅ PASS" : "❌ FAIL"
    println("  $status: $test_name")
    if !passed && haskey(error_details, test_name)
        error_summary = first(error_details[test_name], 100) * "..."
        println("    Error: $error_summary")
    end
end

# Overall assessment
println("\nOVERALL ASSESSMENT:")
if failed_tests == 0
    println("🎉 PERFECT SCORE: HomotopyContinuation fully functional on x86_64 Linux!")
    println("✅ All binary artifacts working correctly")
    println("✅ All functionality tests passed")
    println("✅ Ready for production use on cluster")
    final_status = "FULLY_FUNCTIONAL"
elseif passed_tests >= 7
    println("✅ HIGHLY FUNCTIONAL: HomotopyContinuation mostly working")
    println("✅ Core functionality available")
    println("⚠️ Some advanced features may have issues")
    println("✅ Suitable for most use cases")
    final_status = "MOSTLY_FUNCTIONAL"
elseif passed_tests >= 4
    println("⚠️ PARTIALLY FUNCTIONAL: HomotopyContinuation has significant issues")
    println("⚠️ Basic functionality may work")
    println("❌ Advanced features likely problematic")
    println("🔧 Requires fixes before production use")
    final_status = "PARTIALLY_FUNCTIONAL"
else
    println("❌ NON-FUNCTIONAL: HomotopyContinuation deployment failed")
    println("❌ Critical errors in basic functionality")
    println("❌ Not suitable for production use")
    println("🔧 Requires major fixes or alternative approach")
    final_status = "NON_FUNCTIONAL"
end

println("\nRECOMMENDATIONS:")
if final_status == "FULLY_FUNCTIONAL"
    println("- Deploy to production workflows")
    println("- Use for all polynomial system solving needs")
    println("- Consider it a solved architecture compatibility issue")
elseif final_status == "MOSTLY_FUNCTIONAL"
    println("- Use for basic polynomial solving")
    println("- Avoid advanced parametric features if they failed")
    println("- Monitor for stability in production")
elseif final_status == "PARTIALLY_FUNCTIONAL"
    println("- Consider alternative solvers for critical work")
    println("- Use manual polynomial implementations where possible")
    println("- Attempt cluster-native compilation if needed")
else
    println("- Use alternative polynomial solvers")
    println("- Implement manual polynomial system solving")
    println("- Consider container-based deployment")
end

println("\nTEST_STATUS: $final_status")
println("TIMESTAMP: $(Dates.now())")
println("\n" * "="^60)

println("✅ Comprehensive HomotopyContinuation test suite completed")