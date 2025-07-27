using Test
using Globtim
using DynamicPolynomials
using LinearAlgebra

@testset "Polynomial Truncation" begin
    @testset "Basic truncation with BoxDomain" begin
        # Create a simple polynomial
        @polyvar x
        poly = 1.0 + 0.1 * x + 0.001 * x^2 + 0.0001 * x^3
        domain = BoxDomain(1, 1.0)  # [-1, 1]

        # Truncate with relative threshold
        result = truncate_polynomial(poly, 0.01, mode = :relative, domain = domain)

        @test isa(result, NamedTuple)
        @test haskey(result, :polynomial)
        @test haskey(result, :removed_terms)
        @test haskey(result, :l2_ratio)

        # Should have removed small terms
        @test length(result.removed_terms) > 0
        @test result.l2_ratio > 0.95  # L2 norm mostly preserved
    end

    @testset "Absolute threshold truncation" begin
        @polyvar x y
        poly = x^2 + y^2 + 0.001 * x * y + 0.0001 * x^3 * y
        domain = BoxDomain(2, 1.0)

        result = truncate_polynomial(poly, 1e-3, mode = :absolute, domain = domain)

        # Check that small coefficients were removed
        @test length(result.removed_terms) >= 1

        # Verify the truncated polynomial
        truncated = result.polynomial
        @test isa(truncated, AbstractPolynomial)
    end

    @testset "L2 tolerance checking" begin
        @polyvar x
        # Create polynomial where high-order terms have more L2 contribution
        poly = sum((i + 1) * 0.1^i * x^i for i = 0:5)
        domain = BoxDomain(1, 1.0)

        # Set threshold high enough to remove terms with significant L2 contribution
        result = @test_logs (:warn,) match_mode = :any begin
            truncate_polynomial(
                poly,
                0.8,
                mode = :relative,
                domain = domain,
                l2_tolerance = 0.01,
            )
        end

        # Even with warning, should return valid result
        @test isa(result.polynomial, AbstractPolynomial)
    end

    @testset "Monomial L2 contributions" begin
        @polyvar x y
        poly = x^2 + 2 * x * y + y^2
        domain = BoxDomain(2, 1.0)

        contributions = monomial_l2_contributions(poly, domain)

        @test isa(contributions, Vector)
        @test length(contributions) == length(monomials(poly))

        # All contributions should be positive
        @test all(c -> c.l2_contribution > 0, contributions)

        # Check sorting (descending by contribution)
        for i in eachindex(contributions)[2:end]
            @test contributions[i-1].l2_contribution >= contributions[i].l2_contribution
        end
    end

    @testset "Integration with Globtim polynomial" begin
        # Create polynomial using Globtim
        f = x -> x[1]^2 + 0.1 * sin(5 * x[1])
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 10, basis = :chebyshev)

        # Convert to monomial basis
        @polyvar x
        mono_poly = to_exact_monomial_basis(pol, variables = [x])

        # Truncate the monomial polynomial
        domain = BoxDomain(1, 1.0)
        result = truncate_polynomial(mono_poly, 1e-4, mode = :relative, domain = domain)

        @test length(monomials(result.polynomial)) < length(monomials(mono_poly))
        @test result.l2_ratio > 0.99  # Should preserve most of the norm
    end

    @testset "Truncation impact analysis" begin
        @polyvar x
        poly = sum((0.5)^i * x^i for i = 0:8)
        domain = BoxDomain(1, 1.0)

        thresholds = [1e-1, 1e-2, 1e-3]
        results = analyze_truncation_impact(poly, domain, thresholds = thresholds)

        @test length(results) == length(thresholds)

        # Check monotonicity
        for i in eachindex(results)[2:end]
            @test results[i].remaining_terms >= results[i-1].remaining_terms
            @test results[i].l2_ratio >= results[i-1].l2_ratio
        end
    end

    @testset "L2 norm verification" begin
        @polyvar x y
        original_poly = x^2 + y^2 + 0.1 * x * y + 0.01 * x^2 * y^2
        domain = BoxDomain(2, 1.0)

        # Truncate
        result = truncate_polynomial(original_poly, 0.05, mode = :relative, domain = domain)

        # Verify L2 norm preservation
        verification = verify_truncation_quality(original_poly, result.polynomial, domain)

        @test verification.l2_ratio ≈ result.l2_ratio rtol = 0.1
        @test verification.l2_original > 0
        @test verification.l2_truncated > 0
        @test verification.l2_truncated <= verification.l2_original * 1.1  # Allow 10% numerical error
    end

    @testset "Exact monomial integration" begin
        domain = BoxDomain(2, 1.0)

        # Test constant
        @test integrate_monomial([0, 0], domain) ≈ 4.0  # 2^2 for 2D

        # Test linear terms (should be 0 due to symmetry)
        @test abs(integrate_monomial([1, 0], domain)) < 1e-15
        @test abs(integrate_monomial([0, 1], domain)) < 1e-15

        # Test quadratic terms
        integral_x2 = integrate_monomial([2, 0], domain)
        @test integral_x2 > 0
        @test integral_x2 ≈ 4 / 3  # Analytical result for ∫∫ x^2 dx dy over [-1,1]^2
    end

    @testset "Edge cases" begin
        @polyvar x

        # Empty polynomial after truncation
        poly = 0.0001 * x + 0.00001 * x^2
        domain = BoxDomain(1, 1.0)
        result = truncate_polynomial(poly, 0.001, mode = :absolute, domain = domain)

        # Should handle gracefully
        @test isa(result.polynomial, AbstractPolynomial)
        @test iszero(result.polynomial) || length(monomials(result.polynomial)) == 0

        # Very high threshold
        poly2 = x^2 + 2 * x + 1
        result2 = truncate_polynomial(poly2, 10.0, mode = :relative, domain = domain)
        @test length(result2.removed_terms) > 0
    end
end
