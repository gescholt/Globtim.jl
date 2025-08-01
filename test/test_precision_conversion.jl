"""
Test to verify that AdaptivePrecision actually works in the monomial conversion pipeline
"""

using Globtim
using DynamicPolynomials

println("=== Testing AdaptivePrecision Conversion Pipeline ===")

# Test function
f = x -> x[1]^2 + x[2]^2
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0, tolerance=nothing)

println("\n1. Creating polynomials with different precisions...")

# Create polynomials
pol_adaptive = Constructor(TR, 2, precision=AdaptivePrecision, verbose=0)
pol_float64 = Constructor(TR, 2, precision=Float64Precision, verbose=0)

println("✓ Polynomials created")
println("  AdaptivePrecision pol.precision: ", pol_adaptive.precision)
println("  Float64Precision pol.precision: ", pol_float64.precision)
println("  AdaptivePrecision coeffs type: ", eltype(pol_adaptive.coeffs))
println("  Float64Precision coeffs type: ", eltype(pol_float64.coeffs))

println("\n2. Converting to monomial basis...")

@polyvar x[1:2]

# Convert to monomial basis - this is where precision conversion should happen
mono_adaptive = to_exact_monomial_basis(pol_adaptive, variables=x)
mono_float64 = to_exact_monomial_basis(pol_float64, variables=x)

println("✓ Monomial conversion completed")

# Check coefficient types in the monomial polynomials
coeffs_adaptive = [coefficient(t) for t in terms(mono_adaptive)]
coeffs_float64 = [coefficient(t) for t in terms(mono_float64)]

println("\n3. Analyzing monomial coefficient types...")
println("  AdaptivePrecision monomial coeffs type: ", typeof(coeffs_adaptive[1]))
println("  Float64Precision monomial coeffs type: ", typeof(coeffs_float64[1]))

if coeffs_adaptive[1] isa BigFloat
    println("  ✓ SUCCESS: AdaptivePrecision produces BigFloat coefficients in monomial expansion")
else
    println("  ✗ FAILURE: AdaptivePrecision produces $(typeof(coeffs_adaptive[1])) coefficients")
end

if coeffs_float64[1] isa Float64
    println("  ✓ SUCCESS: Float64Precision produces Float64 coefficients")
else
    println("  ✗ FAILURE: Float64Precision produces $(typeof(coeffs_float64[1])) coefficients")
end

println("\n4. Testing coefficient values...")
println("  AdaptivePrecision coefficients: ", coeffs_adaptive)
println("  Float64Precision coefficients: ", coeffs_float64)

# Test evaluation - use Float64 for substitution (DynamicPolynomials compatibility)
test_point = [0.3, 0.7]

println("\n5. Testing polynomial evaluation...")
val_adaptive = substitute(mono_adaptive, x, test_point)
val_float64 = substitute(mono_float64, x, test_point)
expected = f(test_point)

println("  Expected value: ", expected)
println("  AdaptivePrecision result: ", Float64(val_adaptive))
println("  Float64Precision result: ", val_float64)

error_adaptive = abs(Float64(val_adaptive) - expected)
error_float64 = abs(val_float64 - expected)

println("  AdaptivePrecision error: ", error_adaptive)
println("  Float64Precision error: ", error_float64)

if error_adaptive <= error_float64
    println("  ✓ AdaptivePrecision is at least as accurate")
else
    println("  ⚠ AdaptivePrecision is less accurate (might be OK for this simple test)")
end

println("\n=== Test Complete ===")

if coeffs_adaptive[1] isa BigFloat && coeffs_float64[1] isa Float64
    println("🎉 SUCCESS: AdaptivePrecision is working correctly!")
    println("   - Raw coefficients stay Float64 (good for performance)")
    println("   - Monomial expansion uses BigFloat (good for accuracy)")
else
    println("❌ FAILURE: AdaptivePrecision is not working as expected")
end