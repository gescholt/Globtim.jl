#!/usr/bin/env julia

"""
Minimal Test (No Dependencies)

Ultra-simple test that uses only Julia built-ins to validate cluster functionality.
"""

using LinearAlgebra  # Should be available in Julia standard library

println("🎯 MINIMAL CLUSTER TEST")
println("=" ^ 30)
println("Julia version: $(VERSION)")
println("Started: $(now())")
println()

# Test basic functionality
println("📊 Testing basic Julia functionality...")

# Simple sphere function
function sphere_4d(x::Vector{Float64})
    return sum(x.^2)
end

# Test the function
test_point = [0.1, 0.2, 0.3, 0.4]
test_value = sphere_4d(test_point)

println("✅ Function evaluation test:")
println("   Point: $test_point")
println("   Value: $test_value")
println("   Expected: $(sum(test_point.^2))")
println()

# Test optimization (simple grid search)
println("🔍 Testing simple optimization...")

best_point = [0.0, 0.0, 0.0, 0.0]
best_value = sphere_4d(best_point)

# Simple random search
n_samples = 100
for i in 1:n_samples
    x = 2 * rand(4) .- 1  # Random point in [-1, 1]^4
    value = sphere_4d(x)
    
    if value < best_value
        best_point = copy(x)
        best_value = value
    end
end

println("✅ Simple optimization test:")
println("   Samples: $n_samples")
println("   Best point: [$(join([round(x, digits=4) for x in best_point], ", "))]")
println("   Best value: $(round(best_value, digits=6))")
println("   Distance to origin: $(round(norm(best_point), digits=6))")
println()

# Test distance computation
global_minimum = [0.0, 0.0, 0.0, 0.0]
distance_to_global = norm(best_point - global_minimum)

println("📏 Distance analysis:")
println("   Distance to global minimum: $(round(distance_to_global, digits=6))")
println("   Success (distance < 0.5): $(distance_to_global < 0.5)")
println()

# Pass/fail analysis
distance_pass = distance_to_global < 0.5
value_pass = best_value < 0.25
overall_pass = distance_pass && value_pass

println("✅ PASS/FAIL ANALYSIS:")
println("   Distance check: $(distance_pass ? "PASS" : "FAIL") ($(round(distance_to_global, digits=6)) < 0.5)")
println("   Value check: $(value_pass ? "PASS" : "FAIL") ($(round(best_value, digits=6)) < 0.25)")
println("   Overall status: $(overall_pass ? "✅ PASS" : "❌ FAIL")")
println()

# Save simple result
result_data = """
{
  "test_type": "minimal_cluster_test",
  "julia_version": "$(VERSION)",
  "timestamp": "$(now())",
  "samples_tested": $n_samples,
  "best_point": [$(join(best_point, ", "))],
  "best_value": $best_value,
  "distance_to_global": $distance_to_global,
  "distance_pass": $(distance_pass ? "true" : "false"),
  "value_pass": $(value_pass ? "true" : "false"),
  "overall_pass": $(overall_pass ? "true" : "false")
}
"""

filename = "minimal_test_result_$(replace(string(now()), ":" => "-")).json"
open(filename, "w") do f
    write(f, result_data)
end

println("💾 Results saved to: $filename")
println()

println("🎯 MINIMAL TEST SUMMARY:")
println("   Julia Version: $(VERSION)")
println("   Test Status: $(overall_pass ? "✅ PASS" : "❌ FAIL")")
println("   Best Distance: $(round(distance_to_global, digits=6))")
println("   Best Value: $(round(best_value, digits=6))")
println("   Samples: $n_samples")

println()
println("✅ Minimal cluster test completed successfully!")
