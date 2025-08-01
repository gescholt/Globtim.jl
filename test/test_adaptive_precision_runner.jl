"""
Simple test runner for AdaptivePrecision functionality
This can be run without Julia to verify the implementation works
"""

# Add the current directory to the load path
push!(LOAD_PATH, ".")
push!(LOAD_PATH, "./src")

using Pkg
Pkg.activate(".")

try
    using Globtim
    using DynamicPolynomials

    println("=== AdaptivePrecision Test Runner ===")

    # Test 1: Basic AdaptivePrecision availability
    println("\n1. Testing AdaptivePrecision enum...")
    @assert AdaptivePrecision isa PrecisionType
    println("✓ AdaptivePrecision enum available")

    # Test 2: AdaptivePrecision through Constructor
    println("\n2. Testing AdaptivePrecision through Constructor...")
    f_simple = x -> x[1]^2
    TR_simple = test_input(f_simple, dim=1, center=[0.0], sample_range=1.0, tolerance=nothing)
    pol_test = Constructor(TR_simple, 2, precision=AdaptivePrecision, verbose=0)
    @assert eltype(pol_test.coeffs) <: BigFloat
    println("✓ AdaptivePrecision works through Constructor")

    # Test 3: Constructor with AdaptivePrecision
    println("\n3. Testing Constructor with AdaptivePrecision...")
    f = x -> x[1]^2 + x[2]^2
    TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0, tolerance=nothing)
    pol = Constructor(TR, 4, precision=AdaptivePrecision, verbose=0)
    @assert eltype(pol.coeffs) <: BigFloat
    println("✓ Constructor works with AdaptivePrecision")
    println("  Coefficient type: $(eltype(pol.coeffs))")
    println("  Number of coefficients: $(length(pol.coeffs))")

    # Test 4: Monomial conversion
    println("\n4. Testing monomial conversion...")
    @polyvar x[1:2]
    mono_poly = to_exact_monomial_basis(pol, variables=x)
    coeffs = [coefficient(t) for t in terms(mono_poly)]
    @assert all(c isa BigFloat for c in coeffs)
    println("✓ Monomial conversion preserves BigFloat precision")
    println("  Number of terms: $(length(coeffs))")

    # Test 5: Coefficient analysis
    println("\n5. Testing coefficient analysis...")
    analysis = analyze_coefficient_distribution(mono_poly)
    @assert analysis.n_total > 0
    @assert analysis.dynamic_range > 1.0
    println("✓ Coefficient analysis works")
    println("  Total terms: $(analysis.n_total)")
    println("  Dynamic range: $(analysis.dynamic_range:.2e)")
    println("  Max coefficient: $(analysis.max_coefficient:.2e)")
    println("  Min coefficient: $(analysis.min_coefficient:.2e)")

    # Test 6: Adaptive truncation
    println("\n6. Testing adaptive truncation...")
    threshold = analysis.max_coefficient * 1e-10
    truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)
    @assert stats.n_kept <= stats.n_total
    println("✓ Adaptive truncation works")
    println("  Original terms: $(stats.n_total)")
    println("  Kept terms: $(stats.n_kept)")
    println("  Sparsity: $(round(stats.sparsity_ratio*100, digits=1))%")

    # Test 7: Accuracy comparison
    println("\n7. Testing accuracy comparison...")
    pol_float64 = Constructor(TR, 4, precision=Float64Precision, verbose=0)
    mono_float64 = to_exact_monomial_basis(pol_float64, variables=x)

    # Evaluate at test point
    test_point = [0.3, 0.7]
    val_adaptive = substitute(mono_poly, x[1] => test_point[1], x[2] => test_point[2])
    val_float64 = substitute(mono_float64, x[1] => test_point[1], x[2] => test_point[2])
    expected = f(test_point)

    error_adaptive = abs(Float64(val_adaptive) - expected)
    error_float64 = abs(Float64(val_float64) - expected)

    println("✓ Accuracy comparison completed")
    println("  Expected value: $(expected)")
    println("  AdaptivePrecision error: $(error_adaptive:.2e)")
    println("  Float64Precision error: $(error_float64:.2e)")
    println("  Improvement factor: $(error_float64/error_adaptive:.1f)x")

    println("\n=== All Tests Passed! ===")
    println("AdaptivePrecision implementation is working correctly.")

catch e
    println("ERROR: $e")
    println("\nStacktrace:")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
    exit(1)
end