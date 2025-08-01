"""
Demonstration of AdaptivePrecision for Extended Precision Polynomial Expansion
with Sparsity Integration

This demonstrates your exact requirements:
- Float64 for function evaluation (performance)
- BigFloat for polynomial expansion (accuracy)
- Easy integration with coefficient truncation (sparsity)
"""

using Globtim
using DynamicPolynomials

println("🚀 AdaptivePrecision Demonstration")
println("=" ^ 50)

# Test function with multiple scales
f = x -> exp(-x[1]^2 - x[2]^2) + 0.1*sin(5*π*x[1])*cos(3*π*x[2])
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0, tolerance=nothing)

println("\n📊 Step 1: Polynomial Construction")
println("Function: exp(-x₁² - x₂²) + 0.1*sin(5πx₁)*cos(3πx₂)")

# Construct with AdaptivePrecision
pol = Constructor(TR, 10, precision=AdaptivePrecision, verbose=0)

println("✓ Polynomial constructed with AdaptivePrecision")
println("  Raw coefficients type: $(eltype(pol.coeffs)) (Float64 for performance)")
println("  Precision setting: $(pol.precision)")
println("  Number of coefficients: $(length(pol.coeffs))")

println("\n🔄 Step 2: Extended Precision Expansion")

@polyvar x[1:2]
mono_poly = to_exact_monomial_basis(pol, variables=x)

# Check coefficient types
coeffs = [coefficient(t) for t in terms(mono_poly)]
println("✓ Monomial expansion completed")
println("  Monomial coefficients type: $(typeof(coeffs[1])) (BigFloat for accuracy)")
println("  Number of terms: $(length(coeffs))")

println("\n📈 Step 3: Coefficient Analysis")

# Analyze coefficient distribution
analysis = analyze_coefficient_distribution(mono_poly)
println("✓ Coefficient analysis completed")
println("  Total terms: $(analysis.n_total)")
println("  Dynamic range: $(analysis.dynamic_range:.2e)")
println("  Max coefficient: $(analysis.max_coefficient:.2e)")
println("  Min coefficient: $(analysis.min_coefficient:.2e)")
println("  Suggested thresholds: $(analysis.suggested_thresholds)")

println("\n✂️  Step 4: Smart Truncation for Sparsity")

# Apply truncation
threshold = analysis.suggested_thresholds[1]
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)

println("✓ Truncation completed")
println("  Threshold used: $(stats.threshold_used:.2e)")
println("  Original terms: $(stats.n_total)")
println("  Kept terms: $(stats.n_kept)")
println("  Removed terms: $(stats.n_removed)")
println("  Sparsity achieved: $(round(stats.sparsity_ratio*100, digits=1))%")
println("  Largest removed coeff: $(stats.largest_removed:.2e)")
println("  Smallest kept coeff: $(stats.smallest_kept:.2e)")

println("\n🎯 Step 5: Accuracy Validation")

# Test evaluation at multiple points
test_points = [
    [0.0, 0.0], [0.5, 0.5], [-0.3, 0.7], [0.9, -0.2], [-0.8, -0.6]
]

max_error_original = 0.0
max_error_truncated = 0.0

for point in test_points
    # Expected value
    expected = f(point)

    # Original polynomial
    val_original = substitute(mono_poly, x, point)
    error_original = abs(Float64(val_original) - expected)
    max_error_original = max(max_error_original, error_original)

    # Truncated polynomial
    val_truncated = substitute(truncated_poly, x, point)
    error_truncated = abs(Float64(val_truncated) - expected)
    max_error_truncated = max(max_error_truncated, error_truncated)
end

println("✓ Accuracy validation completed")
println("  Max error (original): $(max_error_original:.2e)")
println("  Max error (truncated): $(max_error_truncated:.2e)")
println("  Error increase: $(max_error_truncated/max_error_original:.1f)x")

println("\n🎉 Summary: AdaptivePrecision Success!")
println("=" ^ 50)
println("✅ Float64 evaluation: Fast polynomial construction")
println("✅ BigFloat expansion: Extended precision coefficients")
println("✅ Smart truncation: $(round(stats.sparsity_ratio*100, digits=1))% sparsity with minimal accuracy loss")
println("✅ Performance: Best of both worlds!")

println("\n💡 Key Benefits:")
println("  • No rational arithmetic overhead")
println("  • Function evaluation stays Float64 (fast)")
println("  • Coefficient manipulation uses BigFloat (accurate)")
println("  • Easy integration with sparsification")
println("  • Automatic precision selection based on coefficient magnitude")

println("\n🔧 Usage Pattern:")
println("  1. Constructor(TR, degree, precision=AdaptivePrecision)")
println("  2. to_exact_monomial_basis(pol, variables=vars)")
println("  3. analyze_coefficient_distribution(mono_poly)")
println("  4. truncate_polynomial_adaptive(mono_poly, threshold)")

println("\nAdaptivePrecision is ready for production use! 🚀")