# test_sparsification.jl
# Tests for polynomial sparsification functionality

using Test
using Globtim
using DynamicPolynomials
using LinearAlgebra

@testset "Sparsification" begin
    @testset "Basic Sparsification" begin
        # Create a simple 1D polynomial approximation
        f = x -> sin(3 * x[1])
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 10, basis = :chebyshev)

        # Test relative mode sparsification
        result = sparsify_polynomial(pol, 0.01, mode = :relative)

        @test haskey(result, :polynomial)
        @test haskey(result, :sparsity)
        @test haskey(result, :zeroed_indices)
        @test haskey(result, :l2_ratio)
        @test haskey(result, :original_nnz)
        @test haskey(result, :new_nnz)

        # Check that sparsification actually reduces coefficients
        @test result.new_nnz <= result.original_nnz
        @test result.sparsity <= 1.0
        @test result.sparsity >= 0.0

        # Check that L2 norm is reasonably preserved
        @test result.l2_ratio > 0.9  # Should preserve at least 90% of L2 norm
        @test result.l2_ratio <= 1.0

        # Test absolute mode sparsification
        result_abs = sparsify_polynomial(pol, 1e-6, mode = :absolute)
        @test result_abs.new_nnz >= 0
        @test result_abs.new_nnz <= length(pol.coeffs)
    end

    @testset "Coefficient Preservation" begin
        # Create polynomial
        f = x -> 1 / (1 + 25 * x[1]^2)  # Runge function
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 15, basis = :chebyshev)

        # Sparsify with preservation of first 3 coefficients
        result = sparsify_polynomial(pol, 0.05, mode = :relative, preserve_indices = [1, 2, 3])

        # Check that preserved coefficients are not zeroed
        for idx in [1, 2, 3]
            @test !(idx in result.zeroed_indices)
        end
    end

    @testset "L²-Norm Computation Methods" begin
        # Create polynomial
        f = x -> exp(-x[1]^2)
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 8, basis = :chebyshev)

        # Test Vandermonde-based L2 norm
        l2_vand = compute_l2_norm_vandermonde(pol)
        @test l2_vand >= 0.0
        @test isfinite(l2_vand)

        # Test coefficient-based L2 norm with modified coefficients
        sparse_coeffs = copy(pol.coeffs)
        sparse_coeffs[abs.(sparse_coeffs) .< 1e-6] .= 0
        l2_coeffs = compute_l2_norm_coeffs(pol, sparse_coeffs)
        @test l2_coeffs >= 0.0
        @test isfinite(l2_coeffs)
        @test l2_coeffs <= l2_vand  # Sparsified should have smaller or equal norm

        # Test grid-based L2 norm for monomial polynomial
        @polyvar x
        mono_poly = to_exact_monomial_basis(pol, variables = [x])
        domain = BoxDomain(1, 1.0)
        l2_grid = compute_l2_norm(mono_poly, domain)
        @test l2_grid >= 0.0
        @test isfinite(l2_grid)

        # Note: l2_vand and l2_grid measure different things:
        # - l2_vand: precomputed norm from polynomial construction (Chebyshev basis)
        # - l2_grid: grid-based quadrature on monomial polynomial (after basis conversion)
        # They operate on different representations and domains, so direct comparison is not meaningful
    end

    @testset "Sparsification Analysis" begin
        # Create polynomial
        f = x -> cos(2 * x[1])
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 12, basis = :chebyshev)

        # Analyze sparsification tradeoffs
        thresholds = [1e-2, 1e-4, 1e-6]
        results = analyze_sparsification_tradeoff(pol, thresholds = thresholds)

        @test length(results) == length(thresholds)

        for (i, res) in enumerate(results)
            @test res.threshold == thresholds[i]
            @test haskey(res, :sparsity)
            @test haskey(res, :l2_ratio)
            @test haskey(res, :new_nnz)
            @test res.l2_ratio > 0.0
            @test res.l2_ratio <= 1.0
        end

        # Check that tighter thresholds preserve more coefficients
        @test results[1].new_nnz <= results[2].new_nnz <= results[3].new_nnz
    end

    @testset "Approximation Error Tradeoff" begin
        # Create polynomial
        f = x -> sin(π * x[1])
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 10, basis = :chebyshev)

        # Analyze approximation error
        thresholds = [1e-3, 1e-5]
        results = analyze_approximation_error_tradeoff(f, pol, TR, thresholds = thresholds)

        @test length(results) == length(thresholds)

        for res in results
            @test haskey(res, :threshold)
            @test haskey(res, :approx_error)
            @test haskey(res, :approx_error_ratio)
            @test haskey(res, :sparsity)
            @test res.approx_error >= 0.0
            # Allow for small numerical errors in grid-based error computation
            @test res.approx_error_ratio >= 0.99  # Error should not decrease significantly
        end
    end

    @testset "Exact Monomial Conversion" begin
        # Create 1D polynomial
        f = x -> x[1]^2 + 0.5 * x[1]
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 5, basis = :chebyshev)

        # Convert to monomial basis
        @polyvar x
        mono_poly = to_exact_monomial_basis(pol, variables = [x])

        @test mono_poly !== nothing
        @test length(variables(mono_poly)) == 1

        # Test evaluation
        test_val = mono_poly(0.5)
        @test isfinite(test_val)

        # Create 2D polynomial
        f2 = x -> x[1]^2 + x[2]^2
        TR2 = test_input(f2, dim = 2, center = [0.0, 0.0], sample_range = 1.0)
        pol2 = Constructor(TR2, 4, basis = :chebyshev)

        # Convert to monomial basis
        @polyvar y[1:2]
        mono_poly2 = to_exact_monomial_basis(pol2, variables = y)

        @test mono_poly2 !== nothing
        @test length(variables(mono_poly2)) == 2
    end

    @testset "Verify Truncation Quality" begin
        # Create polynomial
        f = x -> exp(-x[1]^2)
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 10, basis = :chebyshev)

        # Create sparse version
        sparse_result = sparsify_polynomial(pol, 1e-4, mode = :relative)

        # Convert both to monomial
        @polyvar x
        original_mono = to_exact_monomial_basis(pol, variables = [x])
        sparse_mono = to_exact_monomial_basis(sparse_result.polynomial, variables = [x])

        # Verify quality
        domain = BoxDomain(1, 1.0)
        quality = verify_truncation_quality(original_mono, sparse_mono, domain)

        @test haskey(quality, :l2_ratio)
        @test haskey(quality, :l2_original)
        @test haskey(quality, :l2_truncated)

        @test quality.l2_ratio > 0.9  # Should preserve most of the norm
        @test quality.l2_ratio <= 1.0
        @test quality.l2_original >= quality.l2_truncated
    end

    @testset "Edge Cases" begin
        # Test with very small polynomial
        f = x -> x[1]
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 2, basis = :chebyshev)

        # Sparsify with very aggressive threshold
        result = sparsify_polynomial(pol, 0.9, mode = :relative)
        @test result.new_nnz >= 0  # Should not error

        # Test with zero threshold (should keep all coefficients)
        result_zero = sparsify_polynomial(pol, 0.0, mode = :relative)
        @test result_zero.new_nnz == result_zero.original_nnz
    end

    @testset "Integration with BoxDomain" begin
        # Test BoxDomain creation
        domain1d = BoxDomain(1, 1.0)
        @test domain1d.dimension == 1
        @test domain1d.radius == 1.0

        domain2d = BoxDomain(2, 2.0)
        @test domain2d.dimension == 2
        @test domain2d.radius == 2.0

        # Test monomial integration
        # ∫_{-1}^{1} x² dx = 2/3
        integral = integrate_monomial([2], BoxDomain(1, 1.0))
        @test abs(integral - 2 / 3) < 1e-10

        # ∫_{-1}^{1} x dx = 0 (odd function)
        integral_odd = integrate_monomial([1], BoxDomain(1, 1.0))
        @test abs(integral_odd) < 1e-10

        # Test 2D integration
        # ∫∫_{[-1,1]²} x²y² dx dy = (2/3)²
        integral2d = integrate_monomial([2, 2], BoxDomain(2, 1.0))
        @test abs(integral2d - (2 / 3)^2) < 1e-10
    end
end
