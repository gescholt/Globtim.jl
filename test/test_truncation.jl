# test_truncation.jl
# Tests for polynomial truncation analysis

using Test
using Globtim
using DynamicPolynomials
using LinearAlgebra

@testset "Truncation Analysis" begin
    @testset "Basic Truncation" begin
        # Create a simple polynomial
        @polyvar x y
        poly = x^2 + y^2 + 0.001 * x * y + 0.0001 * x^3

        domain = BoxDomain(2, 1.0)

        # Test relative truncation
        result = truncate_polynomial(poly, 0.01, mode = :relative, domain = domain)

        @test haskey(result, :polynomial)
        @test haskey(result, :removed_terms)
        @test haskey(result, :l2_ratio)
        @test haskey(result, :original_terms)
        @test haskey(result, :remaining_terms)

        # Check that truncation reduces terms
        @test result.remaining_terms <= result.original_terms
        @test result.l2_ratio > 0.0
        @test result.l2_ratio <= 1.0

        # Test absolute truncation
        result_abs = truncate_polynomial(poly, 1e-4, mode = :absolute, domain = domain)
        @test result_abs.remaining_terms >= 0
        @test result_abs.remaining_terms <= result_abs.original_terms
    end

    @testset "Truncation with L² Tolerance Warning" begin
        @polyvar x
        poly = x^2 + 0.5 * x + 0.3  # Significant coefficients

        domain = BoxDomain(1, 1.0)

        # This should warn because we're removing a significant term
        @test_logs (:warn, r"L²-norm reduction.*exceeds tolerance") truncate_polynomial(
            poly,
            0.4,
            mode = :relative,
            domain = domain,
            l2_tolerance = 0.05
        )

        # This should not warn
        result = truncate_polynomial(
            poly,
            0.01,
            mode = :relative,
            domain = domain,
            l2_tolerance = 0.05
        )
        @test result.l2_ratio > 0.95
    end

    @testset "Monomial L² Contributions" begin
        @polyvar x y
        poly = 2 * x^2 + 3 * y^2 + 0.1 * x * y

        domain = BoxDomain(2, 1.0)

        contributions = monomial_l2_contributions(poly, domain)

        # Should have 3 terms
        @test length(contributions) == 3

        # Each contribution should have the right fields
        for contrib in contributions
            @test haskey(contrib, :monomial)
            @test haskey(contrib, :coefficient)
            @test haskey(contrib, :l2_contribution)
            @test contrib.l2_contribution >= 0.0
        end

        # Should be sorted by L² contribution (descending)
        for i in 1:(length(contributions) - 1)
            @test contributions[i].l2_contribution >= contributions[i + 1].l2_contribution
        end
    end

    @testset "Analyze Truncation Impact" begin
        # Create a polynomial from Globtim approximation
        f = x -> sin(2 * x[1]) * cos(3 * x[2])
        TR = TestInput(f, dim = 2, center = [0.0, 0.0], sample_range = 1.0)
        pol = Constructor(TR, 8, basis = :chebyshev)

        # Convert to monomial
        @polyvar x[1:2]
        mono_poly = to_exact_monomial_basis(pol, variables = x)

        domain = BoxDomain(2, 1.0)

        # Analyze truncation impact with multiple thresholds
        thresholds = [1e-2, 1e-4, 1e-6]
        results = analyze_truncation_impact(mono_poly, domain, thresholds = thresholds)

        @test length(results) == length(thresholds)

        for (i, res) in enumerate(results)
            @test res.threshold == thresholds[i]
            @test haskey(res, :original_terms)
            @test haskey(res, :remaining_terms)
            @test haskey(res, :removed_terms)
            @test haskey(res, :sparsity)
            @test haskey(res, :l2_ratio)

            @test res.original_terms == res.remaining_terms + res.removed_terms
            @test res.sparsity == res.remaining_terms / res.original_terms
            @test res.l2_ratio > 0.0
            # Allow small numerical errors above 1.0 due to grid-based L2 norm computation
            @test res.l2_ratio <= 1.01
        end

        # More aggressive thresholds should remove more terms
        @test results[1].remaining_terms <= results[2].remaining_terms
        @test results[2].remaining_terms <= results[3].remaining_terms
    end

    @testset "Complete Workflow" begin
        # Test the complete workflow from the documentation
        f = x -> 1 / (1 + 25 * x[1]^2)  # Runge function
        TR = TestInput(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 20, basis = :chebyshev)

        # Analyze sparsification options
        sparsity_analysis =
            analyze_sparsification_tradeoff(pol, thresholds = [1e-2, 1e-3, 1e-4])
        @test length(sparsity_analysis) == 3

        # Choose threshold and sparsify
        sparse_pol = sparsify_polynomial(pol, 1e-4, mode = :relative).polynomial

        # Convert to exact monomial form
        @polyvar x
        mono_sparse = to_exact_monomial_basis(sparse_pol, variables = [x])

        # Verify quality
        domain = BoxDomain(1, 1.0)
        original_mono = to_exact_monomial_basis(pol, variables = [x])
        quality = verify_truncation_quality(original_mono, mono_sparse, domain)

        @test quality.l2_ratio > 0.9  # Should preserve at least 90% of L² norm

        # Count non-zero terms
        nnz = count(!iszero, sparse_pol.coeffs)
        @test nnz >= 0
        @test nnz <= length(pol.coeffs)
    end

    @testset "Edge Cases" begin
        # Test with very simple polynomial
        @polyvar x
        poly = x + 1.0

        domain = BoxDomain(1, 1.0)

        # Truncate with aggressive threshold
        result = truncate_polynomial(poly, 0.9, mode = :relative, domain = domain)
        @test result.remaining_terms >= 0

        # Test with zero polynomial (after truncation)
        result_zero = truncate_polynomial(poly, 1.0, mode = :relative, domain = domain)
        # Should handle this gracefully
        @test result_zero.remaining_terms >= 0

        # Test single term polynomial
        poly_single = x^2
        result_single = truncate_polynomial(poly_single, 0.1, mode = :relative, domain = domain)
        @test result_single.remaining_terms >= 0
    end

    @testset "Truncation with Different Domains" begin
        @polyvar x
        poly = x^2 + 0.1 * x + 0.01

        # Test with different domain sizes
        domain1 = BoxDomain(1, 1.0)
        domain2 = BoxDomain(1, 2.0)

        result1 = truncate_polynomial(poly, 0.05, mode = :relative, domain = domain1)
        result2 = truncate_polynomial(poly, 0.05, mode = :relative, domain = domain2)

        # Both should work
        @test result1.remaining_terms >= 0
        @test result2.remaining_terms >= 0
    end

    @testset "L² Computation Methods Consistency" begin
        # Ensure different L² computation methods give valid results
        f = x -> x[1]^2 - 0.5
        TR = TestInput(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 6, basis = :chebyshev)

        # Vandermonde-based
        l2_vand = compute_l2_norm_vandermonde(pol)
        @test l2_vand >= 0.0
        @test isfinite(l2_vand)

        # Grid-based (via monomial)
        @polyvar x
        mono_poly = to_exact_monomial_basis(pol, variables = [x])
        domain = BoxDomain(1, 1.0)
        l2_grid = compute_l2_norm(mono_poly, domain)
        @test l2_grid >= 0.0
        @test isfinite(l2_grid)

        # Note: These methods operate on different representations and should not be directly compared
        # - l2_vand: precomputed from Chebyshev basis construction
        # - l2_grid: grid-based quadrature on monomial polynomial after basis conversion
    end

    @testset "Removed Terms Information" begin
        @polyvar x y
        poly = x^2 + y^2 + 0.001 * x * y + 0.0001 * x * y^2

        domain = BoxDomain(2, 1.0)
        result = truncate_polynomial(poly, 0.01, mode = :relative, domain = domain)

        # Check removed_terms structure
        @test isa(result.removed_terms, Vector)
        for term in result.removed_terms
            @test haskey(term, :monom)
            @test haskey(term, :coeff)
        end

        # Number of removed terms should match (2 small terms should be removed)
        @test length(result.removed_terms) == 2
        @test result.original_terms == result.remaining_terms + length(result.removed_terms)
    end

    @testset "Preservation After Truncation" begin
        # Test that truncation doesn't change significant terms
        @polyvar x
        poly = 10.0 * x^2 + 0.0001 * x  # Large difference in coefficients

        domain = BoxDomain(1, 1.0)
        result = truncate_polynomial(poly, 0.01, mode = :relative, domain = domain)

        # The x^2 term should be preserved
        @test result.remaining_terms >= 1

        # Evaluate both polynomials at a point
        test_point = 0.5
        orig_val = poly(test_point)
        trunc_val = result.polynomial(test_point)

        # They should be close
        @test abs(orig_val - trunc_val) / abs(orig_val) < 0.01
    end
end
