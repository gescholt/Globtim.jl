using Test
using Globtim
using DynamicPolynomials
using LinearAlgebra

@testset "Polynomial Sparsification" begin
    @testset "Basic sparsification" begin
        # Create a polynomial with some small coefficients
        f = x -> 1.0 + 0.1 * x[1] + 0.001 * x[1]^2 + 0.0001 * x[1]^3
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 10, basis = :chebyshev)

        # Test relative threshold sparsification
        result = sparsify_polynomial(pol, 0.01, mode = :relative)

        @test isa(result, NamedTuple)
        @test haskey(result, :polynomial)
        @test haskey(result, :sparsity)
        @test haskey(result, :zeroed_indices)
        @test haskey(result, :l2_ratio)

        # Should have zeroed out small coefficients
        @test result.sparsity < 1.0
        @test length(result.zeroed_indices) > 0

        # L2 norm should be mostly preserved
        @test result.l2_ratio > 0.95
    end

    @testset "Absolute threshold sparsification" begin
        f = x -> exp(x[1])
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 0.5)
        pol = Constructor(TR, 8, basis = :chebyshev)

        # Use absolute threshold
        result = sparsify_polynomial(pol, 1e-6, mode = :absolute)

        @test result.sparsity <= 1.0
        @test result.l2_ratio > 0.99  # Very small threshold should preserve norm

        # Check that coefficients below threshold are zeroed
        sparse_coeffs = result.polynomial.coeffs
        for idx in result.zeroed_indices
            @test sparse_coeffs[idx] == 0
        end
    end

    @testset "Preserve indices functionality" begin
        f = x -> x[1]^2 + x[2]^2
        TR = test_input(f, dim = 2, center = [0.0, 0.0], sample_range = 1.0)
        pol = Constructor(TR, 6, basis = :chebyshev)

        # Preserve first few coefficients
        preserve_idx = [1, 2, 3]
        result =
            sparsify_polynomial(pol, 0.1, mode = :relative, preserve_indices = preserve_idx)

        # Check preserved indices are not zeroed
        for idx in preserve_idx
            if idx <= length(result.polynomial.coeffs)
                @test idx ∉ result.zeroed_indices
            end
        end
    end

    @testset "Sparsification tradeoff analysis" begin
        f = x -> sin(3 * x[1])
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 15, basis = :chebyshev)

        thresholds = [1e-2, 1e-3, 1e-4, 1e-5]
        results = analyze_sparsification_tradeoff(pol, thresholds = thresholds)

        @test length(results) == length(thresholds)

        # Check monotonicity: smaller threshold -> more coefficients kept
        for i = 2:length(results)
            @test results[i].new_nnz >= results[i-1].new_nnz
            @test results[i].l2_ratio >= results[i-1].l2_ratio
        end

        # First result (largest threshold) should have most sparsity
        @test results[1].sparsity < results[end].sparsity
    end

    @testset "Vandermonde L2 norm computation" begin
        f = x -> x[1]^2 - x[1] + 1
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 4, basis = :chebyshev)

        # Compute L2 norm using Vandermonde approach
        l2_vand = compute_l2_norm_vandermonde(pol)

        @test isa(l2_vand, Real)
        @test l2_vand > 0

        # Compare with stored norm (should be close)
        @test abs(l2_vand - pol.nrm) / pol.nrm < 0.1  # Within 10%
    end

    @testset "L2 norm with modified coefficients" begin
        f = x -> cos(π * x[1])
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 8, basis = :legendre)

        # Test with zeroed coefficients
        modified_coeffs = copy(pol.coeffs)
        modified_coeffs[5:end] .= 0

        l2_modified = compute_l2_norm_coeffs(pol, modified_coeffs)
        l2_original = compute_l2_norm_vandermonde(pol)

        @test l2_modified < l2_original  # Should be smaller with zeroed coeffs
        @test l2_modified > 0
    end

    @testset "Approximation error analysis" begin
        f = x -> 1 / (1 + 25 * x[1]^2)  # Runge function
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 1.0)
        pol = Constructor(TR, 20, basis = :chebyshev)

        # Compute approximation error
        error = compute_approximation_error(f, pol, TR)

        @test isa(error, Real)
        @test error >= 0
        @test error < 0.1  # Should be a good approximation

        # Test error after sparsification
        sparse_result = sparsify_polynomial(pol, 1e-4, mode = :relative)
        error_sparse = compute_approximation_error(f, sparse_result.polynomial, TR)

        @test error_sparse >= error - 1e-10  # Error should not decrease (within numerical tolerance)
        @test error_sparse < 0.2  # But should still be reasonable
    end

    @testset "Approximation error tradeoff" begin
        f = x -> exp(-x[1]^2)  # Gaussian
        TR = test_input(f, dim = 1, center = [0.0], sample_range = 2.0)
        pol = Constructor(TR, 12, basis = :chebyshev)

        results = analyze_approximation_error_tradeoff(
            f,
            pol,
            TR,
            thresholds = [1e-2, 1e-3, 1e-4],
        )

        @test length(results) == 3

        # Check that results contain expected fields
        for res in results
            @test haskey(res, :threshold)
            @test haskey(res, :sparsity)
            @test haskey(res, :l2_ratio)
            @test haskey(res, :approx_error)
            @test haskey(res, :approx_error_ratio)
        end

        # Error should increase with more aggressive sparsification
        @test results[1].approx_error >= results[3].approx_error
    end
end
