"""
Comprehensive Debug Suite for 4D Benchmark Testing

Run all debugging steps in sequence to identify and resolve issues with:
- L2-norm computation and recomputation
- Sparsification analysis
- Visualization setup and plotting

Usage:
    julia --project=. Examples/4d_benchmark_tests/run_debug_suite.jl
    
    # Or run individual steps:
    julia --project=. Examples/4d_benchmark_tests/run_debug_suite.jl l2norm
    julia --project=. Examples/4d_benchmark_tests/run_debug_suite.jl sparsity  
    julia --project=. Examples/4d_benchmark_tests/run_debug_suite.jl visualization
"""

using Pkg
Pkg.activate(".")

using Globtim
using Printf
using Dates

println("🔧 4D Benchmark Testing - Comprehensive Debug Suite")
println("=" ^ 60)
println("Started: $(Dates.now())")
println()

# ============================================================================
# STEP 0: Environment Check
# ============================================================================

println("🔍 Step 0: Environment Check")
println("-" ^ 40)

println("Julia version: $(VERSION)")
println("Globtim loaded: ✅")

# Check if we're in the right directory
if isfile("src/Globtim.jl")
    println("Working directory: ✅ Correct (Globtim root)")
else
    println("Working directory: ⚠️  May not be in Globtim root")
    println("Current directory: $(pwd())")
end

# Check if 4D benchmark files exist
benchmark_files = [
    "Examples/4d_benchmark_tests/benchmark_4d_framework.jl",
    "Examples/4d_benchmark_tests/plotting_4d.jl"
]

for file in benchmark_files
    if isfile(file)
        println("Framework file $file: ✅")
    else
        println("Framework file $file: ❌ Missing")
    end
end

println()

# ============================================================================
# MAIN DEBUG EXECUTION
# ============================================================================

function run_debug_step(step_name::String, script_path::String)
    """Run a single debug step and capture results"""
    
    println("🚀 Running $step_name...")
    println("Script: $script_path")
    
    if !isfile(script_path)
        println("❌ Debug script not found: $script_path")
        return false
    end
    
    try
        # Include and run the debug script
        include(script_path)
        println("✅ $step_name completed successfully")
        return true
    catch e
        println("❌ $step_name failed with error:")
        println("   $e")
        
        # Print stack trace for debugging
        println("\nStack trace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
        
        return false
    end
end

function run_all_debug_steps()
    """Run all debug steps in sequence"""
    
    debug_steps = [
        ("L2-norm Debugging", "Examples/4d_benchmark_tests/debug_l2_norm.jl"),
        ("Sparsity Visualization Debugging", "Examples/4d_benchmark_tests/debug_sparsity_visualization.jl"),
        ("Visualization Setup Debugging", "Examples/4d_benchmark_tests/debug_visualization_setup.jl")
    ]
    
    results = []
    
    for (step_name, script_path) in debug_steps
        println("\n" * "=" ^ 60)
        success = run_debug_step(step_name, script_path)
        push!(results, (step_name, success))

        if success
            println("✅ $step_name: PASSED")
        else
            println("❌ $step_name: FAILED")
        end

        println("=" ^ 60)
        println()
    end
    
    return results
end

function print_debug_summary(results)
    """Print a summary of all debug results"""
    
    println("\n🎯 DEBUG SUITE SUMMARY")
    println("=" ^ 60)
    
    total_steps = length(results)
    passed_steps = count(r -> r[2], results)
    
    println("Total debug steps: $total_steps")
    println("Passed: $passed_steps")
    println("Failed: $(total_steps - passed_steps)")
    println()
    
    println("Detailed Results:")
    for (step_name, success) in results
        status = success ? "✅ PASS" : "❌ FAIL"
        println("  $status - $step_name")
    end
    
    println()
    
    if passed_steps == total_steps
        println("🎉 All debug steps passed!")
        println("Your 4D benchmark testing infrastructure should be working correctly.")
    else
        println("⚠️  Some debug steps failed.")
        println("Check the output above for specific issues and solutions.")
    end
    
    println("\n📁 Debug outputs saved to: Examples/4d_benchmark_tests/debug_output/")
end

function run_specific_debug_step(step_arg::String)
    """Run a specific debug step based on command line argument"""
    
    step_mapping = Dict(
        "l2norm" => ("L2-norm Debugging", "Examples/4d_benchmark_tests/debug_l2_norm.jl"),
        "sparsity" => ("Sparsity Visualization Debugging", "Examples/4d_benchmark_tests/debug_sparsity_visualization.jl"),
        "visualization" => ("Visualization Setup Debugging", "Examples/4d_benchmark_tests/debug_visualization_setup.jl")
    )
    
    if haskey(step_mapping, step_arg)
        step_name, script_path = step_mapping[step_arg]
        println("Running specific debug step: $step_name")
        success = run_debug_step(step_name, script_path)
        
        if success
            println("\n✅ Debug step completed successfully!")
        else
            println("\n❌ Debug step failed. Check output above for details.")
        end
    else
        println("❌ Unknown debug step: $step_arg")
        println("Available steps: l2norm, sparsity, visualization")
        println("Or run without arguments to execute all steps.")
    end
end

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

function main()
    # Create debug output directory
    debug_output_dir = "Examples/4d_benchmark_tests/debug_output"
    if !isdir(debug_output_dir)
        mkpath(debug_output_dir)
        println("Created debug output directory: $debug_output_dir")
    end
    
    if length(ARGS) == 0
        # Run all debug steps
        println("Running complete debug suite...")
        results = run_all_debug_steps()
        print_debug_summary(results)
        
    elseif length(ARGS) == 1
        # Run specific debug step
        step_arg = lowercase(ARGS[1])
        run_specific_debug_step(step_arg)
        
    else
        println("Usage:")
        println("  julia run_debug_suite.jl              # Run all debug steps")
        println("  julia run_debug_suite.jl l2norm       # Debug L2-norm issues")
        println("  julia run_debug_suite.jl sparsity     # Debug sparsification")
        println("  julia run_debug_suite.jl visualization # Debug plotting setup")
    end
    
    println("\n🏁 Debug suite completed at $(Dates.now())")
end

# ============================================================================
# QUICK DIAGNOSTIC FUNCTION
# ============================================================================

function quick_diagnostic()
    """Run a quick diagnostic to identify the most likely issues"""
    
    println("🔍 Quick Diagnostic")
    println("-" ^ 30)
    
    issues_found = []
    
    # Test basic polynomial construction
    try
        f_test(x) = sum(x.^2)
        TR_test = test_input(f_test, dim=2, center=zeros(2), sample_range=1.0)
        pol_test = Constructor(TR_test, 4)
        println("✅ Basic polynomial construction: Working")
    catch e
        println("❌ Basic polynomial construction: Failed")
        push!(issues_found, "polynomial_construction")
    end
    
    # Test sparsification
    try
        f_test(x) = sum(x.^2)
        TR_test = test_input(f_test, dim=2, center=zeros(2), sample_range=1.0)
        pol_test = Constructor(TR_test, 4)
        sparse_result = sparsify_polynomial(pol_test, 1e-6, mode=:absolute)
        println("✅ Sparsification: Working")
    catch e
        println("❌ Sparsification: Failed")
        push!(issues_found, "sparsification")
    end
    
    # Test plotting availability
    plotting_available = false
    try
        using CairoMakie
        plotting_available = true
        println("✅ CairoMakie plotting: Available")
    catch
        try
            using GLMakie
            plotting_available = true
            println("✅ GLMakie plotting: Available")
        catch
            try
                using Plots
                plotting_available = true
                println("✅ Plots.jl plotting: Available")
            catch
                println("❌ Plotting packages: None available")
                push!(issues_found, "plotting")
            end
        end
    end
    
    # Summary
    if isempty(issues_found)
        println("\n🎉 Quick diagnostic: No major issues found!")
        println("You should be able to run the 4D benchmark tests.")
    else
        println("\n⚠️  Issues found: $issues_found")
        println("Run the full debug suite for detailed analysis:")
        println("julia Examples/4d_benchmark_tests/run_debug_suite.jl")
    end
end

# Run main function if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) > 0 && ARGS[1] == "quick"
        quick_diagnostic()
    else
        main()
    end
end
