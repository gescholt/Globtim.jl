# test_gradient_fit.jl — gradient information in the approximation step (gradient_fit.jl,
# subdomain_gradient_check.jl): derivative Vandermonde, gradient-enhanced least squares,
# the relative gradient error, and the gradient check on subdivision leaves.

using Test
using Globtim
using ForwardDiff
using LinearAlgebra

@testset "gradient information in the fit" begin
    @testset "derivative_vandermonde differentiates the fitted basis" begin
        for basis in (:chebyshev, :legendre)
            Lambda = Globtim.SupportGen(2, (:one_d_for_all, 7))
            S = [0.3 -0.7; -0.91 0.12; 0.0 0.55; 0.77 -0.33]
            Vref = Globtim.lambda_vandermonde(Lambda, S, basis = basis, force_original = true)
            V, D = derivative_vandermonde(Lambda, S; basis = basis, reference = Vref)
            @test V ≈ Vref
            # against ForwardDiff of the fitted polynomial for random coefficients
            TR = TestInput(x -> sin(2x[1]) * cos(x[2]), dim = 2, center = [0.0, 0.0], GN = 12, sample_range = 1.0)
            pol = Constructor(TR, 7, basis = basis)
            for i in axes(S, 1)
                z = S[i, :]
                g_fd = ForwardDiff.gradient(u -> Globtim.evaluate(pol, u), z)
                # recompute on pol's own support order
                Vp, Dp = derivative_vandermonde((data = Matrix(pol.support), size = size(pol.support)), reshape(z, 1, 2); basis = basis)
                @test [Dp[k][1, :] ⋅ pol.coeffs for k in 1:2] ≈ g_fd rtol = 1e-10 atol = 1e-12
                @test Vp[1, :] ⋅ pol.coeffs ≈ Globtim.evaluate(pol, z) rtol = 1e-10 atol = 1e-12
            end
        end
    end

    @testset "gradient_weight = 0 is the value-only fit, bit for bit" begin
        TR = TestInput(Deuflhard, dim = 2, center = [0.0, 0.0], GN = 20, sample_range = 1.2)
        a = Constructor(TR, 8)
        b = Constructor(TR, 8; gradient_weight = 0.0)
        @test a.coeffs == b.coeffs
        @test a.nrm == b.nrm
    end

    @testset "a polynomial objective is reproduced exactly by the H¹ fit" begin
        f(x) = 1 + x[1] - 2x[2]^3 + x[1]^2 * x[2]
        TR = TestInput(f, dim = 2, center = [0.5, -0.5], GN = 10, sample_range = [1.5, 2.0])
        p0 = Constructor(TR, 4)
        p1 = Constructor(TR, 4; gradient_weight = 1.0)
        @test p1.coeffs ≈ p0.coeffs atol = 1e-9
        @test relative_gradient_error(p1, f) < 1e-9
    end

    @testset "relative gradient error: decreases with degree; H¹ fit lowers it" begin
        f(x) = sin(3x[1]) * cos(2x[2]) + 0.3x[1]^2
        TR = TestInput(f, dim = 2, center = [0.0, 0.0], GN = 24, sample_range = 1.0)
        e = [relative_gradient_error(Constructor(TR, d), f) for d in (4, 8, 12)]
        @test e[1] > e[2] > e[3]
        # the discrete H¹ fit minimizes value + weighted gradient residual on the grid,
        # so on the grid its gradient residual can only be ≤ the value-only fit's
        pv = Constructor(TR, 8)
        ph = Constructor(TR, 8; gradient_weight = 1.0)
        S = pv.grid
        w = fill(1.0 / size(S, 1), size(S, 1))
        @test relative_gradient_error(ph, f; points = S, weights = w) <=
              relative_gradient_error(pv, f; points = S, weights = w) + 1e-12
        # finite differences agree with ForwardDiff
        @test relative_gradient_error(pv, f; method = :finitediff) ≈
              relative_gradient_error(pv, f) rtol = 1e-5
        # subset check is deterministic
        @test relative_gradient_error(pv, f; n_points = 40) == relative_gradient_error(pv, f; n_points = 40)
    end

    @testset "non-finite gradient is an error, not a silent fallback" begin
        # finite values everywhere, infinite slope at x₁ = 0 (a node of the equispaced
        # Legendre grid for even GN; the Chebyshev nodes miss 0 by roundoff)
        f(x) = sqrt(abs(x[1])) + x[2]^2
        G = objective_gradients_box(f, [0.3 0.1; -0.2 0.4], 1.0, [0.0, 0.0])
        @test G ≈ [0.5/sqrt(0.3) 0.2; -0.5/sqrt(0.2) 0.8]
        @test_throws ErrorException objective_gradients_box(f, [0.0 0.1], 1.0, [0.0, 0.0])
        TR = TestInput(f, dim = 2, center = [0.0, 0.0], GN = 8, sample_range = 1.0)
        @test_throws ErrorException Constructor(TR, 4; basis = :legendre, gradient_weight = 1.0)
        @test Constructor(TR, 4; basis = :legendre) isa ApproxPoly        # value-only fit is unaffected
    end

    @testset "gradient check gates leaf convergence in adaptive_refine" begin
        f(x) = sin(4x[1]) * cos(3x[2])
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        t0 = adaptive_refine(f, bounds, 6; l2_tolerance = 0.05, max_depth = 4, parallel = false)
        t1 = adaptive_refine(
            f,
            bounds,
            6;
            l2_tolerance = 0.05,
            gradient_tolerance = 0.02,
            max_depth = 4,
            parallel = false,
        )
        # default: no check, nothing measured
        @test all(isnan(sd.relative_grad_error) for sd in t0.subdomains)
        # with a tolerance: every converged leaf was measured and passed
        conv = [t1.subdomains[i] for i in t1.converged_leaves]
        @test !isempty(conv)
        @test all(sd -> sd.relative_grad_error <= 0.02, conv)
        # a gradient requirement can only refine more, never less
        @test Globtim.n_leaves(t1) >= Globtim.n_leaves(t0)
        # the leaf check equals the generic check on the same rows and map
        sd = conv[1]
        @test subdomain_gradient_error(f, sd) ≈ sd.relative_grad_error
    end
end
