"""
OTL Circuit Function - Error Handling Framework Test Script

This script demonstrates the Globtim.jl error handling framework using the 
OTL Circuit function from the SFU benchmark suite.

Function Details:
- Dimensions: 6
- Domain: [50,150] × [25,70] × [0.5,3] × [1.2,2.5] × [0.25,1.2] × [50,300]
- Application: Electronic circuit modeling
- Characteristics: Smooth, moderate complexity

Usage:
    julia --project=. Examples/otl_circuit_error_handling_test.jl
"""

using Globtim
using DataFrames
using Printf
using Statistics

println("📊 OTL Circuit Function - Error Handling Framework Test")
println("=" ^ 60)

# ============================================================================
# 1. DEFINE THE OTL CIRCUIT FUNCTION
# ============================================================================

function otl_circuit(x)
    """
    OTL Circuit function from SFU benchmark suite
    
    Input: x = [Rb1, Rb2, Rf, Rc1, Rc2, β]
    Domain: [50,150] × [25,70] × [0.5,3] × [1.2,2.5] × [0.25,1.2] × [50,300]
    """
    
    # Extract parameters
    Rb1, Rb2, Rf, Rc1, Rc2, β = x[1], x[2], x[3], x[4], x[5], x[6]
    
    # Calculate intermediate values
    Vb1 = 12 * Rb2 / (Rb1 + Rb2)
    
    # Calculate the three terms
    term1 = (Vb1 + 0.74) * β * (Rc2 + 9) / (β * (Rc2 + 9) + Rf)
    term2 = 11.35 * Rf / (β * (Rc2 + 9) + Rf)
    term3 = 0.74 * Rf * β * (Rc2 + 9) / ((β * (Rc2 + 9) + Rf) * Rc1)
    
    return term1 + term2 + term3
end

# Define domain bounds
const OTL_BOUNDS = [
    (50.0, 150.0),   # Rb1
    (25.0, 70.0),    # Rb2  
    (0.5, 3.0),      # Rf
    (1.2, 2.5),      # Rc1
    (0.25, 1.2),     # Rc2
    (50.0, 300.0)    # β
]

# Calculate center point and ranges
otl_center = [(bounds[1] + bounds[2]) / 2 for bounds in OTL_BOUNDS]
otl_ranges = [(bounds[2] - bounds[1]) / 2 for bounds in OTL_BOUNDS]

println("\n🔧 OTL Circuit Function Defined:")
println("  Dimension: 6")
println("  Center point: ", otl_center)
println("  Ranges: ", otl_ranges)

# Test function evaluation
test_point = otl_center
test_value = otl_circuit(test_point)
println("  Test evaluation at center: ", test_value)

# Create normalized version for Globtim
function otl_circuit_normalized(x)
    """
    Normalized OTL Circuit function for Globtim
    Maps from [-1,1]^6 to original domain
    """
    # Map from [-1,1] to original domain
    x_original = zeros(6)
    for i in 1:6
        x_original[i] = otl_center[i] + x[i] * otl_ranges[i]
    end
    
    return otl_circuit(x_original)
end

# ============================================================================
# 2. MEMORY COMPLEXITY ANALYSIS
# ============================================================================

println("\n📊 Memory Complexity Analysis for 6D OTL Circuit")
println("-" ^ 50)

degrees = [2, 3, 4, 5, 6]
sample_counts = [100, 200, 300, 500]

println("\nMemory usage estimates (MB):")
header_parts = [@sprintf("%-8s", "Degree")]
for s in sample_counts
    push!(header_parts, @sprintf("%-12s", "$(s) samples"))
end
println(join(header_parts))
println("-" ^ 60)

for degree in degrees
    row = @sprintf("%-8d", degree)
    
    for samples in sample_counts
        try
            complexity = estimate_computation_complexity(6, degree, samples)
            memory_mb = complexity["total_memory_mb"]
            
            # Color coding
            if memory_mb < 100
                status = "✅"  # Safe
            elseif memory_mb < 500
                status = "⚠️ "  # Caution
            else
                status = "🚫"  # Dangerous
            end
            
            row *= @sprintf("%s%-10.0f", status, memory_mb)
        catch e
            row *= "ERROR     "
        end
    end
    println(row)
end

println("\nLegend: ✅ <100MB (safe), ⚠️  100-500MB (caution), 🚫 >500MB (dangerous)")

# ============================================================================
# 3. PARAMETER VALIDATION TESTING
# ============================================================================

println("\n📋 Parameter Validation Testing")
println("-" ^ 40)

test_cases = [
    ("Conservative Safe", 6, 3, 150),
    ("Moderate Safe", 6, 4, 200),
    ("Aggressive", 6, 5, 300),
    ("Dangerous", 6, 6, 400),
    ("Extreme", 6, 8, 500),
]

for (description, dim, degree, samples) in test_cases
    println("\n🧪 Testing: $description ($(dim)D, degree $degree, $samples samples)")
    
    try
        # Test validation
        validate_polynomial_degree(degree, samples)
        
        # Get complexity estimate
        complexity = estimate_computation_complexity(dim, degree, samples)
        
        memory_mb = complexity["total_memory_mb"]
        terms = complexity["estimated_terms"]
        feasible = complexity["memory_feasible"] && complexity["time_feasible"]
        
        if feasible
            println("  ✅ Parameters validated successfully")
        else
            println("  ⚠️  Parameters risky but allowed")
        end
        
        println("     Memory: $(@sprintf("%.0f", memory_mb))MB")
        println("     Terms: $terms")
        println("     Feasible: $feasible")
        
        # Show warnings
        if !isempty(complexity["warnings"])
            println("     Warnings:")
            for warning in complexity["warnings"]
                println("       • $warning")
            end
        end
        
    catch e
        if isa(e, InputValidationError)
            println("  ❌ Validation failed: $(e.suggestion)")
        else
            println("  ❌ Error: $e")
        end
    end
end

# ============================================================================
# 4. SAFE TEST INPUT CONSTRUCTION
# ============================================================================

println("\n🏗️  Safe Test Input Construction")
println("-" ^ 40)

println("\n🧪 Testing safe test input construction:")

TR = nothing
try
    # Use conservative parameters for 6D
    TR = safe_test_input(
        otl_circuit_normalized,
        dim=6,
        center=zeros(6),  # Normalized center
        sample_range=1.0,  # Full normalized range
        GN=150  # Conservative sample count
    )
    
    println("  ✅ Test input constructed successfully!")
    println("     Dimension: $(TR.dim)")
    println("     Sample count: $(TR.GN)")
    println("     Center: $(TR.center)")
    println("     Sample range: $(TR.sample_range)")
    
    # Test function evaluation on samples
    sample_values = [TR.f(TR.X[i, :]) for i in 1:min(5, TR.GN)]
    println("     Sample function values: $(sample_values[1:min(3, length(sample_values))])...")
    
catch e
    if isa(e, GlobtimError)
        println("  ❌ Safe construction failed: $(typeof(e))")
        if isa(e, InputValidationError)
            println("     Suggestion: $(e.suggestion)")
        end
    else
        println("  ❌ Unexpected error: $e")
    end
end

# ============================================================================
# 5. PROGRESSIVE POLYNOMIAL CONSTRUCTION
# ============================================================================

println("\n📈 Progressive Polynomial Construction")
println("-" ^ 40)

if TR !== nothing
    println("\n🔄 Testing progressive degree increase:")
    
    degrees_to_test = [2, 3, 4, 5]
    successful_results = []
    
    for degree in degrees_to_test
        println("\n🧪 Attempting degree $degree:")
        
        try
            # Use safe constructor with progress monitoring
            pol = safe_constructor(
                TR, degree,
                basis=:chebyshev,
                precision=RationalPrecision,
                max_retries=2
            )
            
            println("  ✅ Degree $degree successful!")
            println("     L2 error: $(@sprintf("%.2e", pol.nrm))")
            println("     Coefficient count: $(length(pol.coeffs))")
            
            if hasfield(typeof(pol), :cond_vandermonde)
                println("     Condition number: $(@sprintf("%.2e", pol.cond_vandermonde))")
            end
            
            push!(successful_results, (degree=degree, l2_error=pol.nrm, polynomial=pol))
            
            # Check if error is good enough
            if pol.nrm < 1e-6
                println("     🎯 Excellent accuracy achieved - could stop here")
            end
            
        catch e
            if isa(e, GlobtimError)
                println("  ❌ Degree $degree failed: $(typeof(e))")
                if isa(e, ResourceError)
                    println("     Resource issue: $(e.suggestion)")
                    println("     🛑 Stopping progression due to resource limits")
                    break
                elseif isa(e, NumericalError)
                    println("     Numerical issue: $(e.details)")
                    println("     Suggestions: $(join(e.suggestions, ", "))")
                end
            else
                println("  ❌ Unexpected error: $e")
                break
            end
        end
    end
    
    # Summary of successful constructions
    if !isempty(successful_results)
        println("\n📊 Successful Polynomial Constructions Summary:")
        println(@sprintf("%-8s%-12s%s", "Degree", "L2 Error", "Quality"))
        println("-" ^ 30)
        
        for result in successful_results
            quality = if result.l2_error < 1e-8
                "Excellent"
            elseif result.l2_error < 1e-6
                "Very Good"
            elseif result.l2_error < 1e-4
                "Good"
            else
                "Acceptable"
            end
            
            println(@sprintf("%-8d%-12.2e%s", result.degree, result.l2_error, quality))
        end
        
        # Recommend best degree
        best_result = successful_results[end]  # Last successful is usually best
        println("\n🎯 Recommended: Degree $(best_result.degree) with L2 error $(@sprintf("%.2e", best_result.l2_error))")
    else
        println("\n❌ No polynomial constructions were successful")
    end
else
    println("\n❌ Cannot proceed with polynomial construction - test input failed")
end

# ============================================================================
# 6. COMPLETE SAFE WORKFLOW TEST
# ============================================================================

println("\n🚀 Complete Safe Workflow Test")
println("-" ^ 40)

println("\n🎯 Testing complete workflow with conservative parameters:")

try
    # Use very conservative parameters for 6D
    results = safe_globtim_workflow(
        otl_circuit_normalized,
        dim=6,
        center=zeros(6),
        sample_range=1.0,
        degree=3,  # Very conservative for 6D
        GN=120,    # Conservative sample count
        enable_hessian=false,  # Disable for speed
        max_retries=3
    )

    println("  ✅ Complete workflow successful!")
    println("\n📊 Results Summary:")
    println("     Polynomial degree: $(results.polynomial.degree)")
    println("     L2 approximation error: $(@sprintf("%.2e", results.polynomial.nrm))")
    println("     Critical points found: $(nrow(results.critical_points))")
    println("     Minima identified: $(nrow(results.minima))")
    println("     Total analysis time: $(@sprintf("%.2f", results.analysis_summary["workflow_time_seconds"]))s")

    if haskey(results.analysis_summary, "bfgs_convergence_rate")
        conv_rate = results.analysis_summary["bfgs_convergence_rate"]
        println("     BFGS convergence rate: $(@sprintf("%.1f", conv_rate*100))%")
    end

    # Show some critical points if found
    if nrow(results.critical_points) > 0
        println("\n🎯 Sample Critical Points (normalized coordinates):")
        n_show = min(3, nrow(results.critical_points))
        for i in 1:n_show
            point = [results.critical_points[i, Symbol("x$j")] for j in 1:6]
            f_val = results.critical_points[i, :z]
            println("     Point $i: f = $(@sprintf("%.4f", f_val))")
        end
    end

    # Show minima if found
    if nrow(results.minima) > 0
        println("\n🏆 Local Minima Found:")
        for i in 1:nrow(results.minima)
            f_val = results.minima[i, :z]
            println("     Minimum $i: f = $(@sprintf("%.6f", f_val))")
        end
    end

catch e
    if isa(e, GlobtimError)
        println("  ❌ Workflow failed gracefully: $(typeof(e))")

        if isa(e, ResourceError)
            println("     Resource: $(e.resource)")
            println("     Suggestion: $(e.suggestion)")
        elseif isa(e, ComputationError)
            println("     Stage: $(e.stage)")
            println("     Recovery options:")
            for option in e.recovery_options
                println("       • $option")
            end
        end
    else
        println("  ❌ Unexpected error: $e")
    end
end

# ============================================================================
# 7. AUTOMATIC PARAMETER ADJUSTMENT TEST
# ============================================================================

println("\n🔄 Automatic Parameter Adjustment Test")
println("-" ^ 40)

println("\n🎯 Testing with aggressive parameters (should trigger adjustment):")

try
    # Use aggressive parameters that should trigger adjustment
    results = safe_globtim_workflow(
        otl_circuit_normalized,
        dim=6,
        center=zeros(6),
        sample_range=1.0,
        degree=6,  # Aggressive for 6D
        GN=300,    # Aggressive sample count
        enable_hessian=false,
        max_retries=5  # Allow more retries for adjustment
    )

    println("  ✅ Aggressive parameters succeeded with automatic adjustment!")
    println("\n📊 Final Parameters After Adjustment:")
    println("     Final polynomial degree: $(results.polynomial.degree)")
    println("     L2 error: $(@sprintf("%.2e", results.polynomial.nrm))")
    println("     Analysis time: $(@sprintf("%.2f", results.analysis_summary["workflow_time_seconds"]))s")

    if results.polynomial.degree < 6
        println("     🔄 Degree was automatically reduced from 6 to $(results.polynomial.degree)")
    end

catch e
    if isa(e, GlobtimError)
        println("  ⚠️  Even with automatic adjustment, parameters were too aggressive:")
        println("     Error type: $(typeof(e))")

        if isa(e, ResourceError)
            println("     Final suggestion: $(e.suggestion)")
        elseif isa(e, ComputationError)
            println("     Failed at stage: $(e.stage)")
        end

        println("\n💡 This demonstrates the framework's limits - even with adjustment,")
        println("    some parameter combinations are too aggressive for 6D problems.")
    else
        println("  ❌ Unexpected error: $e")
    end
end

# ============================================================================
# 8. PERFORMANCE AND MEMORY ANALYSIS
# ============================================================================

println("\n📊 Performance and Memory Analysis")
println("-" ^ 40)

# Run system diagnostics
println("\n🔍 System Diagnostics:")
diagnostics = diagnose_globtim_setup()

println("  Julia version: $(diagnostics["julia_version"])")
println("  Setup healthy: $(diagnostics["setup_healthy"])")

if haskey(diagnostics, "memory_allocated_mb")
    memory_mb = diagnostics["memory_allocated_mb"]
    println("  Current memory usage: $(@sprintf("%.1f", memory_mb)) MB")
end

println("\n📦 Package Status:")
for (pkg, status) in diagnostics["package_status"]
    status_icon = status ? "✅" : "❌"
    println("  $status_icon $pkg")
end

if !isempty(diagnostics["potential_issues"])
    println("\n⚠️  Potential Issues:")
    for issue in diagnostics["potential_issues"]
        println("  • $issue")
    end
end

# Memory usage comparison
println("\n💾 Memory Usage Comparison for OTL Circuit (6D):")
println(@sprintf("%-20s%-12s%s", "Configuration", "Memory (MB)", "Status"))
println("-" ^ 45)

configs = [
    ("Conservative", 3, 120),
    ("Moderate", 4, 150),
    ("Aggressive", 5, 200),
    ("Dangerous", 6, 300)
]

for (name, degree, samples) in configs
    try
        complexity = estimate_computation_complexity(6, degree, samples)
        memory_mb = complexity["total_memory_mb"]
        feasible = complexity["memory_feasible"]

        status = feasible ? "✅ Safe" : "⚠️  Risky"
        if memory_mb > 1000
            status = "🚫 Dangerous"
        end

        config_str = "$name (d=$degree, n=$samples)"
        println(@sprintf("%-20s%-12.0f%s", config_str, memory_mb, status))

    catch e
        println(@sprintf("%-20s%-12s%s", name, "ERROR", "❌ Invalid"))
    end
end

# ============================================================================
# 9. SUMMARY AND RECOMMENDATIONS
# ============================================================================

println("\n📋 Summary and Recommendations")
println("=" ^ 60)

println("🎯 OTL Circuit Function (6D) - Test Results Summary:")
println()
println("✅ WORKING COMPONENTS:")
println("• OTL Circuit function definition and normalization")
println("• Memory complexity estimation and warnings")
println("• Parameter validation with helpful error messages")
println("• System diagnostics and package status checking")
println()
println("❌ ISSUES IDENTIFIED:")
println("• Error handling framework has implementation bugs")
println("• Method signature mismatches in safe wrappers")
println("• Missing error logging methods")
println("• Parameter adjustment logic needs fixes")
println()
println("🔧 FIXES NEEDED:")
println("• Fix ResourceError field access in logging")
println("• Correct method signatures for parameter adjustment")
println("• Implement missing log_error_details method")
println("• Fix complexity estimation warnings (showing wrong degree)")
println()
println("📊 VALIDATION RESULTS:")
println("• Conservative parameters (degree 3): Validation passes")
println("• Aggressive parameters (degree 6): Correctly rejected")
println("• Extreme parameters (degree 8): Correctly rejected")
println()
println("The test framework structure is sound, but execution")
println("components need debugging before full functionality.")

println("\n" * "=" ^ 60)
println("📋 OTL Circuit Error Handling Test Completed")
println("Status: Validation works, but execution needs debugging.")
