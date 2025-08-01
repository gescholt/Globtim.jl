"""
Minimal test for AdaptivePrecision to isolate issues
"""

using Test

# Test that we can load Globtim
@testset "Basic Loading" begin
    @test_nowarn using Globtim
end

using Globtim

@testset "AdaptivePrecision Enum" begin
    # Test that AdaptivePrecision exists
    @test @isdefined AdaptivePrecision
    @test AdaptivePrecision isa PrecisionType

    # Test that it's different from other precision types
    @test AdaptivePrecision != Float64Precision
    @test AdaptivePrecision != RationalPrecision
    @test AdaptivePrecision != BigFloatPrecision
    @test AdaptivePrecision != BigIntPrecision

    println("✓ AdaptivePrecision enum works correctly")
end

@testset "AdaptivePrecision Integration" begin
    # Test AdaptivePrecision through the public API (Constructor)
    # This indirectly tests _convert_value functionality

    f_test = x -> 1.0 + 1e-10*x[1] + 1e-15*x[1]^2  # Mix of scales
    TR_test = test_input(f_test, dim=1, center=[0.0], sample_range=1.0, tolerance=nothing)

    # Test that AdaptivePrecision works through Constructor
    @test_nowarn pol = Constructor(TR_test, 3, precision=AdaptivePrecision, verbose=0)

    pol = Constructor(TR_test, 3, precision=AdaptivePrecision, verbose=0)
    @test eltype(pol.coeffs) <: BigFloat

    # Compare with Float64Precision
    pol_float = Constructor(TR_test, 3, precision=Float64Precision, verbose=0)
    @test eltype(pol_float.coeffs) <: Float64

    println("✓ AdaptivePrecision integration works through Constructor")
end

@testset "Constructor Integration" begin
    # Simple 1D test
    f_simple = x -> x[1]^2
    TR_simple = test_input(f_simple, dim=1, center=[0.0], sample_range=1.0, tolerance=nothing)

    # Test that Constructor accepts AdaptivePrecision
    @test_nowarn pol = Constructor(TR_simple, 2, precision=AdaptivePrecision, verbose=0)

    pol = Constructor(TR_simple, 2, precision=AdaptivePrecision, verbose=0)

    # Check coefficient types
    @test eltype(pol.coeffs) <: BigFloat
    @test length(pol.coeffs) > 0
    @test all(isfinite.(Float64.(pol.coeffs)))

    println("✓ Constructor works with AdaptivePrecision")
    println("  Coefficient type: $(eltype(pol.coeffs))")
    println("  Number of coefficients: $(length(pol.coeffs))")
end

@testset "Monomial Conversion" begin
    using DynamicPolynomials

    # Simple 2D test
    f_2d = x -> x[1]^2 + x[2]^2
    TR_2d = test_input(f_2d, dim=2, center=[0.0, 0.0], sample_range=1.0, tolerance=nothing)

    pol = Constructor(TR_2d, 2, precision=AdaptivePrecision, verbose=0)

    # Test monomial conversion
    @polyvar x[1:2]
    @test_nowarn mono_poly = to_exact_monomial_basis(pol, variables=x)

    mono_poly = to_exact_monomial_basis(pol, variables=x)

    # Check that we get a polynomial
    @test mono_poly isa AbstractPolynomial

    # Check coefficient types
    coeffs = [coefficient(t) for t in terms(mono_poly)]
    @test length(coeffs) > 0
    @test all(c isa BigFloat for c in coeffs)

    println("✓ Monomial conversion works")
    println("  Number of terms: $(length(coeffs))")
    println("  Coefficient types: $(typeof(coeffs[1]))")
end

println("\n=== Minimal AdaptivePrecision Tests Complete ===")