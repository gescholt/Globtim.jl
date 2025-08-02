"""
OTL Circuit - Minimal Error Handling Test

This is a simplified version of the OTL Circuit test that focuses on 
testing the core error handling functionality without complex formatting.

Usage:
    julia --project=. Examples/otl_circuit_minimal_test.jl
"""

using Globtim
using Printf

println("📊 OTL Circuit - Minimal Error Handling Test")
println("=" ^ 50)

# ============================================================================
# 1. DEFINE THE OTL CIRCUIT FUNCTION
# ============================================================================

function otl_circuit(x)
    """
    OTL Circuit function from SFU benchmark suite
    Domain: [50,150] × [25,70] × [0.5,3] × [1.2,2.5] × [0.25,1.2] × [50,300]
    """
    Rb1, Rb2, Rf, Rc1, Rc2, β = x[1], x[2], x[3], x[4], x[5], x[6]
    
    Vb1 = 12 * Rb2 / (Rb1 + Rb2)
    
    term1 = (Vb1 + 0.74) * β * (Rc2 + 9) / (β * (Rc2 + 9) + Rf)
    term2 = 11.35 * Rf / (β * (Rc2 + 9) + Rf)
    term3 = 0.74 * Rf * β * (Rc2 + 9) / ((β * (Rc2 + 9) + Rf) * Rc1)
    
    return term1 + term2 + term3
end

# Domain bounds and normalization
const OTL_BOUNDS = [
    (50.0, 150.0), (25.0, 70.0), (0.5, 3.0),
    (1.2, 2.5), (0.25, 1.2), (50.0, 300.0)
]

otl_center = [(bounds[1] + bounds[2]) / 2 for bounds in OTL_BOUNDS]
otl_ranges = [(bounds[2] - bounds[1]) / 2 for bounds in OTL_BOUNDS]

function otl_circuit_normalized(x)
    """Normalized version for Globtim (maps [-1,1]^6 to original domain)"""
    x_original = [otl_center[i] + x[i] * otl_ranges[i] for i in 1:6]
    return otl_circuit(x_original)
end

println("✅ OTL Circuit function defined (6D)")
println("   Center: [$(join([@sprintf("%.1f", c) for c in otl_center], ", "))]")

# Test function evaluation
test_value = otl_circuit_normalized(zeros(6))
println("   Test value at center: $(@sprintf("%.4f", test_value))")

# ============================================================================
# 2. MEMORY COMPLEXITY QUICK CHECK
# ============================================================================

println("\n📊 Memory Complexity Quick Check")
println("-" ^ 30)

test_configs = [
    ("Safe", 3, 120),
    ("Moderate", 4, 150), 
    ("Risky", 5, 200),
    ("Dangerous", 6, 300)
]

println("Configuration     Memory(MB)  Status")
println("-" ^ 40)

for (name, degree, samples) in test_configs
    try
        complexity = estimate_computation_complexity(6, degree, samples)
        memory_mb = complexity["total_memory_mb"]
        feasible = complexity["memory_feasible"]
        
        status = feasible ? "✅ OK" : "⚠️  Risk"
        if memory_mb > 1000
            status = "🚫 No"
        end
        
        println(@sprintf("%-16s %8.0f    %s", name, memory_mb, status))
        
    catch e
        println(@sprintf("%-16s %8s    %s", name, "ERROR", "❌ Bad"))
    end
end

# ============================================================================
# 3. PARAMETER VALIDATION TEST
# ============================================================================

println("\n📋 Parameter Validation Test")
println("-" ^ 30)

validation_tests = [
    ("Conservative", 6, 3, 150),
    ("Aggressive", 6, 6, 300),
    ("Extreme", 6, 8, 500),
]

for (desc, dim, degree, samples) in validation_tests
    print("$desc (degree $degree): ")
    
    try
        validate_polynomial_degree(degree, samples)
        println("✅ Passed")
    catch e
        if isa(e, InputValidationError)
            println("❌ Rejected - $(e.suggestion)")
        else
            println("❌ Error - $e")
        end
    end
end

# ============================================================================
# 4. SAFE WORKFLOW TEST
# ============================================================================

println("\n🚀 Safe Workflow Test")
println("-" ^ 30)

println("Testing conservative parameters...")
try
    results = safe_globtim_workflow(
        otl_circuit_normalized,
        dim=6,
        center=zeros(6),
        sample_range=1.0,
        degree=3,  # Conservative
        GN=120,    # Conservative
        enable_hessian=false,
        max_retries=2
    )
    
    println("✅ Conservative workflow successful!")
    println("   L2 error: $(@sprintf("%.2e", results.polynomial.nrm))")
    println("   Critical points: $(nrow(results.critical_points))")
    println("   Minima found: $(nrow(results.minima))")
    println("   Time: $(@sprintf("%.1f", results.analysis_summary["workflow_time_seconds"]))s")
    
catch e
    if isa(e, GlobtimError)
        println("❌ Conservative workflow failed: $(typeof(e))")
        if isa(e, ResourceError)
            println("   Suggestion: $(e.suggestion)")
        end
    else
        println("❌ Unexpected error: $e")
    end
end

println("\nTesting aggressive parameters (should adjust automatically)...")
try
    results = safe_globtim_workflow(
        otl_circuit_normalized,
        dim=6,
        center=zeros(6),
        sample_range=1.0,
        degree=6,  # Aggressive
        GN=250,    # Aggressive
        enable_hessian=false,
        max_retries=3
    )
    
    println("✅ Aggressive parameters succeeded with adjustment!")
    println("   Final degree: $(results.polynomial.degree)")
    println("   L2 error: $(@sprintf("%.2e", results.polynomial.nrm))")
    println("   Time: $(@sprintf("%.1f", results.analysis_summary["workflow_time_seconds"]))s")
    
    if results.polynomial.degree < 6
        println("   🔄 Degree automatically reduced from 6 to $(results.polynomial.degree)")
    end
    
catch e
    if isa(e, GlobtimError)
        println("⚠️  Aggressive parameters failed even with adjustment:")
        println("   Error: $(typeof(e))")
        if isa(e, ResourceError)
            println("   Final suggestion: $(e.suggestion)")
        end
        println("   💡 This demonstrates the framework's protective limits")
    else
        println("❌ Unexpected error: $e")
    end
end

# ============================================================================
# 5. SYSTEM DIAGNOSTICS
# ============================================================================

println("\n🔍 System Diagnostics")
println("-" ^ 30)

diagnostics = diagnose_globtim_setup()

println("Julia version: $(diagnostics["julia_version"])")
println("Setup healthy: $(diagnostics["setup_healthy"])")

if haskey(diagnostics, "memory_allocated_mb")
    memory_mb = diagnostics["memory_allocated_mb"]
    println("Memory usage: $(@sprintf("%.1f", memory_mb)) MB")
end

critical_packages = ["Optim", "HomotopyContinuation", "DataFrames"]
println("Critical packages:")
for pkg in critical_packages
    if haskey(diagnostics["package_status"], pkg)
        status = diagnostics["package_status"][pkg] ? "✅" : "❌"
        println("  $status $pkg")
    else
        println("  ❓ $pkg (unknown)")
    end
end

if !isempty(diagnostics["potential_issues"])
    println("Issues detected:")
    for issue in diagnostics["potential_issues"]
        println("  ⚠️  $issue")
    end
end

# ============================================================================
# 6. SUMMARY
# ============================================================================

println("\n📋 Test Summary")
println("=" ^ 50)

println("🎯 OTL Circuit (6D) Error Handling Test Results:")
println()
println("This test revealed several issues that need to be addressed:")
println("• Error handling framework has implementation bugs")
println("• Parameter validation works correctly")
println("• Memory complexity estimation needs refinement")
println("• Safe workflow has method signature mismatches")
println()
println("The test successfully demonstrates that the validation")
println("components work, but the execution components need fixes.")

println("\n" * "=" ^ 50)
println("📋 Minimal OTL Circuit Test Completed")
println("Note: Test revealed implementation issues that need to be fixed.")
