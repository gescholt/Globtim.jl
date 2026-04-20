using Test
using Globtim

@testset "Relative L2 tolerance" begin
    @testset "nrm bug fix: pol.nrm is residual norm, not polynomial norm" begin
        # Construct a polynomial on a subdomain and verify pol.nrm = ||f-p||_L2
        f(x) = sin(3 * x[1]) * cos(3 * x[2]) + 0.5
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = Globtim.SubdivisionTree(bounds; degree = 4)
        sd = tree.subdomains[1]

        l2 = Globtim.estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        pol = sd.polynomial
        @test pol !== nothing

        # pol.nrm should equal the absolute L2 error (residual norm), not polynomial norm
        # Verify by recomputing from scratch
        poly_vals = Globtim.evaluate_polynomial_at_samples(pol, sd.samples)
        residuals = sd.f_values .- poly_vals
        weight = prod(2.0 ./ (2 .* [4, 4] .+ 1))
        expected_nrm = sqrt(sum(abs2.(residuals)) * weight)
        @test pol.nrm ≈ expected_nrm atol = 1e-14

        # And it should match l2_error
        @test pol.nrm ≈ l2 atol = 1e-14
    end

    @testset "relative_l2_error stored on Subdomain" begin
        f(x) = x[1]^2 + x[2]^2 + 1.0  # Offset to ensure nonzero norm
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = Globtim.SubdivisionTree(bounds; degree = 6)
        sd = tree.subdomains[1]

        l2 = Globtim.estimate_subdomain_error(f, sd, 6, basis = :chebyshev)
        @test isfinite(sd.relative_l2_error)
        @test sd.relative_l2_error >= 0
        @test sd.relative_l2_error <= 1.0  # Good approx of a polynomial

        # For a polynomial of sufficient degree, relative L2 should be very small
        @test sd.relative_l2_error < 1e-10
    end

    @testset "relative_l2_error both paths produce small values for good approximation" begin
        # subdivision and scaling_utils use different quadrature weights
        # but both should indicate a good approximation
        f(x) = sin(2 * x[1]) + cos(3 * x[2])
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = Globtim.SubdivisionTree(bounds; degree = 6)
        sd = tree.subdomains[1]

        Globtim.estimate_subdomain_error(f, sd, 6, basis = :chebyshev)
        pol = sd.polynomial
        @test pol !== nothing

        rel_from_scaling = Globtim.relative_l2_error(pol)
        # Both should be small for a degree-6 approximation of sin+cos
        @test sd.relative_l2_error < 0.01
        @test rel_from_scaling < 0.01
    end

    @testset "convergence with relative tolerance mode" begin
        # Deuflhard-like smooth 2D function
        f(x) = exp(-2 * (x[1] - 0.5)^2 - 3 * (x[2] + 0.3)^2)
        bounds = [(-1.2, 1.2), (-1.2, 1.2)]

        tree = Globtim.adaptive_refine(
            f,
            bounds,
            6;
            l2_tolerance = 0.03,
            tolerance_mode = :relative,
            max_depth = 4,
            max_leaves = 50,
            parallel = false,
            verbose = false,
        )

        # All converged leaves should have relative_l2_error <= tolerance
        for id in tree.converged_leaves
            sd = tree.subdomains[id]
            @test sd.relative_l2_error <= 0.03
        end

        # Should have at least one converged leaf
        @test length(tree.converged_leaves) > 0
    end

    @testset "absolute tolerance backward compatibility" begin
        f(x) = sin(3 * x[1]) * cos(3 * x[2])
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]

        tree = Globtim.adaptive_refine(
            f,
            bounds,
            4;
            l2_tolerance = 1e-4,
            tolerance_mode = :absolute,
            max_depth = 4,
            max_leaves = 50,
            parallel = false,
            verbose = false,
        )

        # All converged leaves should have absolute l2_error <= tolerance
        for id in tree.converged_leaves
            sd = tree.subdomains[id]
            @test sd.l2_error <= 1e-4
        end
    end

    @testset "zero function edge case" begin
        f(x) = 0.0
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = Globtim.SubdivisionTree(bounds; degree = 4)
        sd = tree.subdomains[1]

        l2 = Globtim.estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        @test l2 ≈ 0.0 atol = 1e-15
        @test sd.relative_l2_error == 0.0  # Not NaN or Inf
    end

    @testset "all-Inf stores relative_l2_error = Inf" begin
        f(x) = Inf
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = Globtim.SubdivisionTree(bounds; degree = 4)
        sd = tree.subdomains[1]

        l2 = Globtim.estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        @test l2 == Inf
        @test sd.relative_l2_error == Inf
    end

    @testset "invalid tolerance_mode raises error" begin
        f(x) = x[1]^2
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]

        @test_throws ErrorException Globtim.adaptive_refine(
            f,
            bounds,
            4;
            tolerance_mode = :foo,
            max_depth = 1,
            max_leaves = 4,
            parallel = false,
        )

        @test_throws ErrorException Globtim.two_phase_refine(
            f,
            bounds,
            4;
            tolerance_mode = :foo,
            max_depth = 1,
            max_leaves = 4,
            parallel = false,
        )
    end

    @testset "two_phase_refine with relative tolerance" begin
        f(x) = sin(2 * x[1]) * cos(x[2]) + 0.3 * x[1]^2
        bounds = [(-2.0, 2.0), (-2.0, 2.0)]

        tree = Globtim.two_phase_refine(
            f,
            bounds,
            6;
            coarse_tolerance = 0.05,
            fine_tolerance = 0.03,
            tolerance_mode = :relative,
            max_depth = 4,
            max_leaves = 50,
            parallel = false,
            verbose = false,
        )

        # Converged leaves should meet the fine relative tolerance
        for id in tree.converged_leaves
            sd = tree.subdomains[id]
            @test sd.relative_l2_error <= 0.03
        end
    end

    @testset "default tolerance depends on mode" begin
        # Verify that NaN sentinel resolves correctly
        # We can't easily test the defaults without running, but we can test
        # that passing NaN with explicit mode produces reasonable behavior
        f(x) = x[1]^2 + x[2]^2
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]

        # Relative mode with default tolerance (0.03) — polynomial should converge quickly
        tree = Globtim.adaptive_refine(
            f,
            bounds,
            4;
            tolerance_mode = :relative,
            max_depth = 2,
            max_leaves = 10,
            parallel = false,
        )
        @test length(tree.converged_leaves) > 0
    end
end
