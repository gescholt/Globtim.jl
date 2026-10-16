# Chebyshev-native gradient kernels (chebyshev_eval.jl) and the HC system built on them
# (ext/chebyshev_gradient_system.jl). Agreement with the generic evaluator and
# ForwardDiff; generic scalar types; truncated-Taylor consistency; B1 of
# CHEBYSHEV_NATIVE_HC_PLAN.md: same real critical points as the monomial path.

using Test
using Globtim
using HomotopyContinuation
using LinearAlgebra
using ForwardDiff
using DynamicPolynomials
using Random

ENV["GLOBTIM_LEDGER_APPEND"] = "0"

@testset "chebyshev native" begin
    @testset "1-D utilities" begin
        c = [1.0, -0.5, 0.25, 0.125, -0.0625]
        for x in (-0.9, -0.3, 0.0, 0.41, 1.0)
            direct = sum(c[k+1] * cos(k * acos(x)) for k in 0:4)
            @test clenshaw(c, x) ≈ direct atol = 1e-14
            dc = chebyshev_derivative_coeffs(c)
            h = 1e-6
            @test clenshaw(dc, x) ≈ (clenshaw(c, x + h) - clenshaw(c, x - h)) / 2h atol = 1e-7
        end
        @test clenshaw(c, 0.3 + 0.2im) ≈ sum(c[k+1] * cos(k * acos(0.3 + 0.2im)) for k in 0:4) atol = 1e-12
        T = zeros(6); dT = zeros(6); d2T = zeros(6)
        chebyshev_tables!(T, dT, d2T, 0.37, 5)
        @test T ≈ [cos(k * acos(0.37)) for k in 0:5] atol = 1e-14
        @test dT[3] ≈ 4 * 0.37 && d2T[3] ≈ 4.0        # T_2 = 2x² − 1
        @test dT[4] ≈ 12 * 0.37^2 - 3 && d2T[4] ≈ 24 * 0.37
    end

    f3(x) = exp(0.3 * x[1]) * sin(x[2]) + 0.5 * x[3]^2 * x[1] - x[2] * x[3]
    TR = TestInput(f3; dim = 3, center = [0.1, -0.2, 0.05], GN = 8, sample_range = [0.8, 1.1, 0.9])
    pol = Constructor(TR, 5)
    K = ChebyshevGradientKernel(pol)
    phat(ẑ) = Globtim.evaluate(pol, pol.center .+ pol.scale_factor .* ẑ)

    @testset "kernel reproduces the surrogate and its derivatives" begin
        @test K.n == 3 && K.m == length(pol.coeffs) && K.dmax == [5, 5, 5]
        rng = MersenneTwister(3)
        u = zeros(3); U = zeros(3, 3)
        for _ in 1:20
            ẑ = 2 .* rand(rng, 3) .- 1
            @test Globtim.value(K, ẑ, pol.coeffs) ≈ phat(ẑ) atol = 1e-13
            Globtim.evaluate!(u, K, ẑ, pol.coeffs)
            @test u ≈ ForwardDiff.gradient(phat, ẑ) atol = 1e-12
            Globtim.evaluate_and_jacobian!(u, U, K, ẑ, pol.coeffs)
            @test u ≈ ForwardDiff.gradient(phat, ẑ) atol = 1e-12
            @test U ≈ ForwardDiff.hessian(phat, ẑ) atol = 1e-11
            @test U ≈ U'
        end
        # a point outside the box (the tracker visits them): still the same polynomial
        ẑ = [1.7, -2.2, 0.4]
        Globtim.evaluate!(u, K, ẑ, pol.coeffs)
        @test u ≈ ForwardDiff.gradient(phat, ẑ) rtol = 1e-12
        # the gradient system is linear in c: A(x) c = ∇p
        A = gradient_basis_matrix(K, ẑ)
        @test A * pol.coeffs ≈ u rtol = 1e-12
    end

    @testset "complex arguments and complex coefficients" begin
        z = [0.3 + 0.2im, -0.5 - 0.1im, 0.8 + 0.05im]
        u = zeros(ComplexF64, 3); U = zeros(ComplexF64, 3, 3)
        Globtim.evaluate_and_jacobian!(u, U, K, z, pol.coeffs)
        @test Globtim.value(K, z, pol.coeffs) ≈ phat(z) atol = 1e-12
        # finite-difference check in the complex plane (analytic polynomial)
        h = 1e-6
        for k in 1:3
            e = zeros(ComplexF64, 3); e[k] = h
            @test u[k] ≈ (phat(z .+ e) - phat(z .- e)) / 2h atol = 1e-6
        end
        cc = ComplexF64.(pol.coeffs) .* (1 + 0.5im)
        Globtim.evaluate!(u, K, z, cc)
        u1 = zeros(ComplexF64, 3)
        Globtim.evaluate!(u1, K, z, pol.coeffs)
        @test u ≈ (1 + 0.5im) .* u1
    end

    @testset "TaylorScalar: coefficients of ∇p along a path" begin
        rng = MersenneTwister(11)
        x0 = 2 .* rand(rng, 3) .- 1
        x1 = randn(rng, 3); x2 = randn(rng, 3)
        c0 = pol.coeffs; c1 = 0.1 .* randn(rng, length(c0))
        xt(t) = x0 .+ x1 .* t .+ x2 .* t^2
        ct(t) = c0 .+ c1 .* t
        g(t) = (u = zeros(3); Globtim.evaluate!(u, K, xt(t), ct(t)); u)
        x_terms = [(x0[k], x1[k], x2[k]) for k in 1:3]
        c_terms = [(c0[r], c1[r]) for r in eachindex(c0)]
        w = taylor_series(Val(3), K, x_terms, c_terms)      # 4 terms
        for (h, tol) in ((1e-2, 1e-6), (5e-3, 1e-7))
            truncated = [sum(w[k][j] * h^j for j in 0:3) for k in 1:3]
            @test norm(g(h) .- truncated) < tol * max(1.0, norm(g(h)))
        end
        @test [w[k][0] for k in 1:3] ≈ g(0.0)
        # order-1 coefficient equals the derivative along the path
        hh = 1e-6
        @test [w[k][1] for k in 1:3] ≈ (g(hh) .- g(-hh)) ./ 2hh atol = 1e-6
        u = zeros(3)
        taylor_coefficient!(u, Val(2), K, x_terms, c_terms)
        @test u ≈ [w[k][2] for k in 1:3]
    end

    # B1 agreement: same real critical points as the monomial path, degree ≤ 8. Compared
    # on the box with a margin (|x_k| ≤ 1.5): the two endgames classify escaping paths
    # differently (at infinity vs huge finite), and nothing downstream reads them.
    function match_sets(a, b; tol = 1e-8, margin = 0.5)
        a = [p for p in a if maximum(abs, p) <= 1 + margin]
        b = [p for p in b if maximum(abs, p) <= 1 + margin]
        length(a) == length(b) || return false
        used = falses(length(b))
        for p in a
            j = findfirst(i -> !used[i] && norm(p .- b[i]) < tol, eachindex(b))
            j === nothing && return false
            used[j] = true
        end
        return true
    end

    @testset "B1: Deuflhard 2-D, degrees 4/6/8" begin
        @polyvar x[1:2]
        TRd = TestInput(Deuflhard; dim = 2, center = [0.0, 0.0], GN = 20, sample_range = 1.2)
        for d in (4, 6, 8)
            pd = Constructor(TRd, d)
            mono = Globtim.solve_polynomial_system_from_approx(x, pd)
            stats = Base.RefValue{Any}(nothing)
            cheb = Globtim.solve_polynomial_system_from_approx(x, pd; representation = :chebyshev, path_stats_ref = stats)
            @test !isempty(mono)
            @test match_sets(mono, cheb)
            s = stats[]
            @test s.start_system == :chebyshev_anchor
            @test s.anchor_expected == (d - 1)^2 && s.anchor_n == (d - 1)^2
            @test s.paths_tracked == (d - 1)^2
            @test s.n_path_failures == 0
            @test isfinite(s.cond_jacobian_median)
        end
    end

    @testset "B1: Rosenbrock 3-D, degrees 4/6" begin
        @polyvar y[1:3]
        TRr = TestInput(Rosenbrock; dim = 3, center = zeros(3), GN = 10, sample_range = 1.0)
        for d in (4, 6)
            pr = Constructor(TRr, d)
            mono = Globtim.solve_polynomial_system_from_approx(y, pr)
            cheb = Globtim.solve_polynomial_system_from_approx(y, pr; representation = :chebyshev)
            @test !isempty(mono)
            @test match_sets(mono, cheb)
        end
        # the anchor is cached per support: a second fit on the same support reuses it
        pr2 = Constructor(TRr, 4)
        cheb2 = Globtim.solve_polynomial_system_from_approx(y, pr2; representation = :chebyshev)
        @test match_sets(cheb2, Globtim.solve_polynomial_system_from_approx(y, pr2))
    end

    @testset "solve_tree_leaves with representation = :chebyshev" begin
        f2(x) = Deuflhard(x)
        bounds = [(-1.2, 1.2), (-1.2, 1.2)]
        tree = Globtim.adaptive_refine(f2, bounds, 6; max_depth = 1, max_leaves = 2, parallel = false)
        rm = Globtim.solve_tree_leaves(tree; solver = :hc)
        rc = Globtim.solve_tree_leaves(tree; solver = :hc, representation = :chebyshev)
        @test all(v == :ran for v in values(rc.leaf_status))
        inbox(S) = [p for p in S if all(bounds[i][1] - 1e-9 <= p[i] <= bounds[i][2] + 1e-9 for i in 1:2)]
        @test match_sets(inbox(rm.critical_points) ./ 1.2, inbox(rc.critical_points) ./ 1.2)
        @test all(s.start_system == :chebyshev_anchor for (_, s) in rc.path_stats)
    end

    @testset "argument checks" begin
        @polyvar z[1:2]
        TRd = TestInput(Deuflhard; dim = 2, center = [0.0, 0.0], GN = 10, sample_range = 1.2)
        pd = Constructor(TRd, 4)
        @test_throws ArgumentError Globtim.solve_polynomial_system_from_approx(z, pd; representation = :legendre)
        @test_throws ArgumentError Globtim.solve_polynomial_system_from_approx(z, pd; representation = :chebyshev, solver = :msolve)
        pl = Constructor(TRd, 4; basis = :legendre)
        @test_throws ArgumentError ChebyshevGradientKernel(pl)
    end
end
