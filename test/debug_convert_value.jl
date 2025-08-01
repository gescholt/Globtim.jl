"""
Debug _convert_value function specifically for AdaptivePrecision
"""

using Globtim

println("=== Testing _convert_value with AdaptivePrecision ===")

# Test 1: Check if AdaptivePrecision exists
println("\n1. Checking AdaptivePrecision...")
println("AdaptivePrecision = ", AdaptivePrecision)
println("Type: ", typeof(AdaptivePrecision))

# Test 2: Test _convert_value directly
println("\n2. Testing _convert_value directly...")

test_values = [1.0, 1e-10, π, 42, -3.14159]

for val in test_values
    println("\nTesting value: $val ($(typeof(val)))")

    # Test with Float64Precision first
    result_f64 = Globtim._convert_value(val, Float64Precision)
    println("  Float64Precision: $result_f64 ($(typeof(result_f64)))")

    # Test with AdaptivePrecision
    try
        result_adaptive = Globtim._convert_value(val, AdaptivePrecision)
        println("  AdaptivePrecision: $result_adaptive ($(typeof(result_adaptive)))")

        if result_adaptive isa BigFloat
            println("  ✓ SUCCESS: AdaptivePrecision produces BigFloat")
        else
            println("  ✗ PROBLEM: AdaptivePrecision produces $(typeof(result_adaptive)), not BigFloat")
        end
    catch e
        println("  ✗ ERROR with AdaptivePrecision: $e")
    end
end

# Test 3: Test the _convert_value_adaptive function directly
println("\n3. Testing _convert_value_adaptive directly...")
try
    result = Globtim._convert_value_adaptive(1.0)
    println("_convert_value_adaptive(1.0) = $result ($(typeof(result)))")

    if result isa BigFloat
        println("✓ _convert_value_adaptive works correctly")
    else
        println("✗ _convert_value_adaptive produces wrong type: $(typeof(result))")
    end
catch e
    println("✗ _convert_value_adaptive failed: $e")
end

println("\n=== Debug Complete ===")