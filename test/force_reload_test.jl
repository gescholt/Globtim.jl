"""
Force reload test for AdaptivePrecision
This will help us determine if the issue is module caching
"""

println("=== Force Reload Test ===")

# Step 1: Try to force reload the module
println("\n1. Attempting to reload Globtim...")

# Remove from loaded modules if possible
if haskey(Base.loaded_modules, Base.PkgId(Base.UUID("7b0b8b8d-0d8a-4b8a-8b8a-8b8a8b8a8b8a"), "Globtim"))
    println("  Globtim is currently loaded, attempting to reload...")
else
    println("  Globtim not found in loaded modules")
end

# Force using again
using Globtim

println("  ✓ Globtim loaded")

# Step 2: Test AdaptivePrecision directly
println("\n2. Testing AdaptivePrecision enum...")
println("  AdaptivePrecision = ", AdaptivePrecision)
println("  All precision types:")
for pt in instances(PrecisionType)
    println("    - $pt")
end

# Step 3: Test _convert_value function directly
println("\n3. Testing _convert_value function...")

# Test with a simple value
test_val = 1.0
println("  Input: $test_val ($(typeof(test_val)))")

# Test Float64Precision
result_f64 = Globtim._convert_value(test_val, Float64Precision)
println("  Float64Precision: $result_f64 ($(typeof(result_f64)))")

# Test BigFloatPrecision
result_bf = Globtim._convert_value(test_val, BigFloatPrecision)
println("  BigFloatPrecision: $result_bf ($(typeof(result_bf)))")

# Test AdaptivePrecision
println("  Testing AdaptivePrecision...")
try
    result_adaptive = Globtim._convert_value(test_val, AdaptivePrecision)
    println("  AdaptivePrecision: $result_adaptive ($(typeof(result_adaptive)))")

    if result_adaptive isa BigFloat
        println("  ✓ SUCCESS: AdaptivePrecision produces BigFloat")
    else
        println("  ✗ FAILURE: AdaptivePrecision produces $(typeof(result_adaptive))")
        println("  This suggests the _convert_value function is not updated")
    end
catch e
    println("  ✗ ERROR: $e")
    println("  This suggests AdaptivePrecision case is not handled")
end

# Step 4: Test Constructor with verbose output
println("\n4. Testing Constructor with verbose output...")
f_simple = x -> x[1]^2
TR_simple = test_input(f_simple, dim=1, center=[0.0], sample_range=1.0, tolerance=nothing)

println("  Testing with AdaptivePrecision and verbose=1...")
try
    pol = Constructor(TR_simple, 2, precision=AdaptivePrecision, verbose=1)
    println("  ✓ Constructor succeeded")
    println("  Coefficient type: $(eltype(pol.coeffs))")

    if eltype(pol.coeffs) <: BigFloat
        println("  ✓ SUCCESS: Constructor produces BigFloat coefficients")
    else
        println("  ✗ FAILURE: Constructor produces $(eltype(pol.coeffs)) coefficients")
    end
catch e
    println("  ✗ Constructor failed: $e")
end

println("\n=== Force Reload Test Complete ===")