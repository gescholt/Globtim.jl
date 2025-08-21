"""
Memory Usage Demonstration for Globtim.jl

This script demonstrates memory-safe usage patterns and shows how the error
handling framework prevents memory exhaustion.

Run this to understand memory scaling and safe parameter choices.
"""

using Globtim
using Printf

println("🧠 Globtim.jl Memory Usage Demonstration")
println("=" ^ 50)

# ============================================================================
# DEMO 1: COMPLEXITY ESTIMATION
# ============================================================================

println("\n📊 Demo 1: Memory Complexity Analysis")
println("-" ^ 40)

# Show how memory usage scales with degree and dimension
dimensions = [2, 3, 4, 5]
degrees = [4, 6, 8, 10]
sample_count = 200

println("\nMemory usage estimates (MB) for $sample_count samples:")
println("Degree".ljust(8) * join([" $(d)D".ljust(10) for d in dimensions]))
println("-" ^ 50)

for degree in degrees
    row = @sprintf("%-8d", degree)
    for dim in dimensions
        try
            complexity = estimate_computation_complexity(dim, degree, sample_count)
            memory_mb = complexity["total_memory_mb"]
            
            if memory_mb < 100
                color_code = ""  # Green (safe)
            elseif memory_mb < 500
                color_code = "⚠️ "  # Yellow (caution)
            else
                color_code = "🚫"  # Red (dangerous)
            end
            
            row *= @sprintf("%s%-8.0f", color_code, memory_mb)
        catch e
            row *= "ERROR   "
        end
    end
    println(row)
end

println("\nLegend: 🚫 >500MB (dangerous), ⚠️  100-500MB (caution), <100MB (safe)")

# ============================================================================
# DEMO 2: SAFE VS UNSAFE PARAMETER CHOICES
# ============================================================================

println("\n📊 Demo 2: Safe vs Unsafe Parameter Validation")
println("-" ^ 40)

# Test various parameter combinations
test_cases = [
    ("Safe 2D", 2, 6, 200),
    ("Safe 3D", 3, 4, 150),
    ("Safe 4D", 4, 4, 100),
    ("Risky 3D", 3, 8, 300),
    ("Dangerous 4D", 4, 8, 200),
    ("Extreme 4D", 4, 10, 500),
]

for (description, dim, degree, samples) in test_cases
    println("\n🧪 Testing: $description ($(dim)D, degree $degree, $samples samples)")
    
    try
        # Check if parameters pass validation
        validate_polynomial_degree(degree, samples)
        
        # Get complexity estimate
        complexity = estimate_computation_complexity(dim, degree, samples)
        
        memory_mb = complexity["total_memory_mb"]
        feasible = complexity["memory_feasible"] && complexity["time_feasible"]
        
        if feasible
            println("  ✅ Parameters are safe")
            println("     Memory: $(@sprintf("%.0f", memory_mb))MB")
            println("     Terms: $(complexity["estimated_terms"])")
        else
            println("  ⚠️  Parameters are risky but allowed")
            println("     Memory: $(@sprintf("%.0f", memory_mb))MB (high)")
            println("     Terms: $(complexity["estimated_terms"]) (many)")
        end
        
        # Show warnings
        if !isempty(complexity["warnings"])
            println("     Warnings:")
            for warning in complexity["warnings"]
                println("       • $warning")
            end
        end
        
    catch e
        if isa(e, InputValidationError)
            println("  ❌ Parameters rejected by validation")
            println("     Reason: $(e.suggestion)")
        else
            println("  ❌ Validation error: $e")
        end
    end
end

# ============================================================================
# DEMO 3: AUTOMATIC PARAMETER ADJUSTMENT
# ============================================================================

println("\n📊 Demo 3: Automatic Parameter Adjustment")
println("-" ^ 40)

# Simulate parameter adjustment for memory errors
println("\n🔄 Simulating automatic parameter adjustment:")

original_params = Dict{String,Any}(
    "degree" => 10,
    "GN" => 500,
    "precision" => RationalPrecision
)

# Simulate a memory error
memory_error = ResourceError("memory", 3000.0, 1500.0, "Reduce parameters")

println("Original parameters:")
for (key, value) in original_params
    println("  $key: $value")
end

println("\nMemory error occurred: $(memory_error.suggestion)")

# Get suggested adjustments
suggestions = suggest_parameter_adjustments(memory_error, original_params)

println("\nSuggested adjustments:")
for (key, value) in suggestions
    if key != "reason"
        println("  $key: $(original_params[key]) → $value")
    end
end

if haskey(suggestions, "reason")
    println("Reason: $(suggestions["reason"])")
end

# ============================================================================
# DEMO 4: SAFE WORKFLOW DEMONSTRATION
# ============================================================================

println("\n📊 Demo 4: Safe Workflow with Memory Management")
println("-" ^ 40)

# Define a simple test function
f_test(x) = sum(x.^2) + 0.1 * sum(x[1:end-1] .* x[2:end])

println("\n🎯 Testing safe workflow with conservative parameters:")

try
    # Use safe parameters
    results = safe_globtim_workflow(
        f_test,
        dim=3, center=zeros(3), sample_range=2.0,
        degree=4,  # Conservative
        GN=100,    # Conservative
        max_retries=2
    )
    
    println("  ✅ Safe workflow completed successfully!")
    println("     L2 error: $(@sprintf("%.2e", results.polynomial.nrm))")
    println("     Critical points: $(nrow(results.critical_points))")
    println("     Analysis time: $(@sprintf("%.2f", results.analysis_summary["workflow_time_seconds"]))s")
    
catch e
    println("  ❌ Even safe parameters failed: $e")
end

println("\n🎯 Testing workflow with aggressive parameters (should adjust automatically):")

try
    # Use aggressive parameters that should trigger adjustment
    results = safe_globtim_workflow(
        f_test,
        dim=4, center=zeros(4), sample_range=2.0,
        degree=8,  # Aggressive
        GN=300,    # Aggressive
        max_retries=3
    )
    
    println("  ✅ Aggressive parameters succeeded with automatic adjustment!")
    println("     Final degree: $(results.polynomial.degree)")
    println("     L2 error: $(@sprintf("%.2e", results.polynomial.nrm))")
    println("     Analysis time: $(@sprintf("%.2f", results.analysis_summary["workflow_time_seconds"]))s")
    
catch e
    if isa(e, GlobtimError)
        println("  ⚠️  Workflow failed gracefully:")
        println("     Error: $(typeof(e))")
        if isa(e, ResourceError)
            println("     Resource: $(e.resource)")
            println("     Suggestion: $(e.suggestion)")
        end
    else
        println("  ❌ Unexpected error: $e")
    end
end

# ============================================================================
# DEMO 5: MEMORY MONITORING
# ============================================================================

println("\n📊 Demo 5: Real-time Memory Monitoring")
println("-" ^ 40)

println("\n🔍 Current system status:")

# Run diagnostics
diagnostics = diagnose_globtim_setup()

println("  Julia version: $(diagnostics["julia_version"])")
println("  Setup healthy: $(diagnostics["setup_healthy"])")

if haskey(diagnostics, "memory_allocated_mb")
    memory_mb = diagnostics["memory_allocated_mb"]
    println("  Current memory usage: $(@sprintf("%.1f", memory_mb)) MB")
    
    if memory_mb > 1000
        println("  ⚠️  High memory usage detected")
    else
        println("  ✅ Memory usage is reasonable")
    end
end

# Test memory monitoring
println("\n🔍 Testing memory monitoring:")
try
    check_memory_usage("demo_operation", memory_limit_gb=1.0)
    println("  ✅ Memory usage within limits")
catch ResourceError as e
    println("  ⚠️  Memory limit exceeded: $(e.suggestion)")
end

# ============================================================================
# SUMMARY AND RECOMMENDATIONS
# ============================================================================

println("\n📋 Summary and Recommendations")
println("-" ^ 40)

println("""
🎯 Key Takeaways:

Memory Usage Guidelines:
• 2D: degree ≤ 10, samples ≤ 1000 (generally safe)
• 3D: degree ≤ 6, samples ≤ 500 (watch memory)
• 4D: degree ≤ 4, samples ≤ 300 (conservative)
• 5D+: degree ≤ 4, samples ≤ 200 (very conservative)

Safe Usage Patterns:
✅ Use safe_globtim_workflow() for automatic management
✅ Start with conservative parameters and increase gradually
✅ Enable max_retries for automatic parameter adjustment
✅ Monitor complexity estimates before running expensive computations

Warning Signs:
⚠️  >500MB estimated memory usage
⚠️  >200 polynomial terms
⚠️  System becomes unresponsive during construction
⚠️  Julia process killed by operating system

Emergency Actions:
🚨 Ctrl+C to interrupt long computations
🚨 Reduce degree to 4 or lower if memory issues persist
🚨 Use domain decomposition for very large problems
🚨 Close other applications to free system memory

Remember: Better to get a reasonable approximation than crash the system! 🚀
""")

println("\n" * "=" ^ 50)
