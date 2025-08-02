"""
Error Handling Framework Demonstration

This script demonstrates the comprehensive error handling and recovery
capabilities of the Globtim.jl error handling framework.

Run this script to see how the framework handles various error conditions
and automatically recovers from common failure modes.
"""

using Globtim
using DataFrames
using Printf

println("🛡️  Globtim.jl Error Handling Framework Demo")
println("=" ^ 60)

# ============================================================================
# DEMO 1: INPUT VALIDATION
# ============================================================================

println("\n📋 Demo 1: Input Validation")
println("-" ^ 40)

# Test various invalid inputs to see validation in action
test_cases = [
    ("Invalid dimension", () -> validate_dimension(-1)),
    ("Invalid degree", () -> validate_polynomial_degree(25, 100)),
    ("Invalid sample count", () -> validate_sample_count(5)),
    ("Invalid center vector", () -> validate_center_vector([NaN, 0.0], 2)),
    ("Invalid sample range", () -> validate_sample_range(-1.0)),
]

for (description, test_func) in test_cases
    println("\n🧪 Testing: $description")
    try
        test_func()
        println("  ✅ Validation passed (unexpected)")
    catch e
        if isa(e, InputValidationError)
            println("  ❌ Validation failed as expected:")
            println("     Parameter: $(e.parameter)")
            println("     Value: $(e.value)")
            println("     💡 Suggestion: $(e.suggestion)")
        else
            println("  ⚠️  Unexpected error: $e")
        end
    end
end

# ============================================================================
# DEMO 2: SAFE FUNCTION USAGE
# ============================================================================

println("\n📋 Demo 2: Safe Function Usage")
println("-" ^ 40)

# Define test functions with different characteristics
println("\n🔬 Testing with well-behaved function:")
f_good(x) = sum(x.^2) + 0.1 * prod(x)

try
    TR = safe_test_input(f_good, dim=2, center=[0.0, 0.0], sample_range=1.0, GN=100)
    pol = safe_constructor(TR, 6)
    println("  ✅ Success! L2 error: $(pol.nrm)")
catch e
    println("  ❌ Unexpected failure: $e")
end

# Test with challenging parameters that might cause issues
println("\n🔬 Testing with challenging parameters:")
try
    TR = safe_test_input(f_good, dim=3, center=zeros(3), sample_range=2.0, GN=50)
    pol = safe_constructor(TR, 12)  # High degree with few samples
    println("  ✅ Success despite challenging parameters! L2 error: $(pol.nrm)")
catch e
    if isa(e, GlobtimError)
        println("  ⚠️  Expected failure handled gracefully:")
        println("     Error type: $(typeof(e))")
        if isa(e, NumericalError)
            println("     Problem: $(e.details)")
            println("     💡 Suggestions:")
            for suggestion in e.suggestions
                println("       • $suggestion")
            end
        end
    else
        println("  ❌ Unexpected error: $e")
    end
end

# ============================================================================
# DEMO 3: AUTOMATIC PARAMETER ADJUSTMENT
# ============================================================================

println("\n📋 Demo 3: Automatic Parameter Adjustment")
println("-" ^ 40)

# Define a function that might cause numerical issues
f_challenging(x) = sum(x.^4) + 0.001 * sum(x.^2) + 1e-6 * prod(x)

println("\n🔄 Testing automatic parameter adjustment:")
try
    # This might fail initially but should recover with adjusted parameters
    TR = safe_test_input(f_challenging, dim=2, center=[0.0, 0.0], sample_range=3.0, GN=80)
    pol = safe_constructor(TR, 14, max_retries=5)  # Very high degree, likely to cause issues
    println("  ✅ Success with automatic adjustments! L2 error: $(pol.nrm)")
catch e
    if isa(e, GlobtimError)
        println("  ⚠️  Failed even with automatic adjustments:")
        println("     Final error: $(typeof(e))")
    else
        println("  ❌ Unexpected error: $e")
    end
end

# ============================================================================
# DEMO 4: COMPLETE WORKFLOW WITH ERROR HANDLING
# ============================================================================

println("\n📋 Demo 4: Complete Safe Workflow")
println("-" ^ 40)

# Test the complete safe workflow
test_functions = [
    ("Simple Quadratic", x -> sum(x.^2)),
    ("Rosenbrock-like", x -> 100*(x[2] - x[1]^2)^2 + (1 - x[1])^2),
    ("Multimodal", x -> sum(x.^2) + 0.1*sum(sin.(10*x))),
]

for (name, func) in test_functions
    println("\n🎯 Testing complete workflow with: $name")
    
    try
        results = safe_globtim_workflow(
            func,
            dim=2, center=[0.0, 0.0], sample_range=2.0,
            degree=6, GN=150, enable_hessian=true,
            max_retries=3
        )
        
        println("  ✅ Workflow completed successfully!")
        println("     L2 error: $(@sprintf("%.2e", results.polynomial.nrm))")
        println("     Critical points: $(nrow(results.critical_points))")
        println("     Minima found: $(nrow(results.minima))")
        println("     Analysis time: $(@sprintf("%.2f", results.analysis_summary["workflow_time_seconds"]))s")
        
        if haskey(results.analysis_summary, "bfgs_convergence_rate")
            conv_rate = results.analysis_summary["bfgs_convergence_rate"]
            println("     BFGS convergence rate: $(@sprintf("%.1f", conv_rate*100))%")
        end
        
    catch e
        if isa(e, GlobtimError)
            println("  ⚠️  Workflow failed gracefully:")
            println("     Error type: $(typeof(e))")
            if isa(e, ComputationError)
                println("     Stage: $(e.stage)")
                println("     💡 Recovery options:")
                for option in e.recovery_options
                    println("       • $option")
                end
            end
        else
            println("  ❌ Unexpected error: $e")
        end
    end
end

# ============================================================================
# DEMO 5: PROGRESS MONITORING
# ============================================================================

println("\n📋 Demo 5: Progress Monitoring")
println("-" ^ 40)

println("\n⏱️  Demonstrating progress monitoring:")

function demo_long_computation(progress::ComputationProgress)
    stages = [
        (0.2, "Initializing"),
        (0.4, "Processing data"),
        (0.6, "Computing approximation"),
        (0.8, "Analyzing results"),
        (1.0, "Finalizing")
    ]
    
    for (prog, stage) in stages
        update_progress!(progress, prog, stage)
        println("     Progress: $(@sprintf("%.0f", prog*100))% - $stage")
        sleep(0.5)  # Simulate work
    end
    
    return "computation_result"
end

try
    result = with_progress_monitoring(
        demo_long_computation,
        "Demo Long Computation",
        interruptible=true
    )
    println("  ✅ Progress monitoring completed: $result")
catch InterruptException
    println("  ⚠️  Computation was interrupted")
catch e
    println("  ❌ Error in progress monitoring: $e")
end

# ============================================================================
# DEMO 6: DIAGNOSTIC INFORMATION
# ============================================================================

println("\n📋 Demo 6: System Diagnostics")
println("-" ^ 40)

println("\n🔍 Running system diagnostics:")
diagnostics = diagnose_globtim_setup()

println("  Julia version: $(diagnostics["julia_version"])")
println("  Globtim loaded: $(diagnostics["globtim_loaded"])")
println("  Setup healthy: $(diagnostics["setup_healthy"])")

if haskey(diagnostics, "memory_allocated_mb")
    println("  Memory allocated: $(@sprintf("%.1f", diagnostics["memory_allocated_mb"])) MB")
end

println("  Package status:")
for (pkg, status) in diagnostics["package_status"]
    status_icon = status ? "✅" : "❌"
    println("    $status_icon $pkg")
end

if !isempty(diagnostics["potential_issues"])
    println("  ⚠️  Potential issues:")
    for issue in diagnostics["potential_issues"]
        println("    • $issue")
    end
else
    println("  ✅ No issues detected")
end

# ============================================================================
# SUMMARY
# ============================================================================

println("\n📋 Demo Summary")
println("-" ^ 40)

println("""
🎉 Error Handling Framework Demo Completed!

The demo showcased:
✅ Comprehensive input validation with helpful error messages
✅ Automatic parameter adjustment and retry mechanisms  
✅ Safe wrapper functions with graceful error handling
✅ Progress monitoring for long-running computations
✅ Complete workflow automation with error recovery
✅ System diagnostics and health checking

Key Benefits:
• User-friendly error messages with actionable suggestions
• Automatic recovery from common failure modes
• Robust handling of numerical instabilities
• Progress tracking and interruption support
• Comprehensive validation and safety checks

Next Steps:
• Use safe_globtim_workflow() for production analysis
• Enable verbose logging for detailed diagnostics
• Customize error handling parameters for your use case
• Report any unhandled errors to help improve the framework

Happy analyzing! 🚀
""")

println("\n" * "=" ^ 60)
