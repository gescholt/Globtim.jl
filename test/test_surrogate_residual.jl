# N4 (EVIDENCE_MAP_2026-10.md): every root a solver returns is checked to be a critical
# point of the FITTED surrogate. Pure part: the residual function on hand-made points.
# Solver part: the ApproxPoly overload now defaults to the fit's own basis metadata and
# runs the check; an explicit mismatch (the Legendre-as-Chebyshev trap) is caught.

using Test
using Globtim
using DynamicPolynomials: @polyvar
using LinearAlgebra

@testset "surrogate residual check" begin
    # Degree 4 with a mixed term, so the orthonormal-weight distortion (w(1)² ≠ w(0)w(4))
    # changes the polynomial and not only its scale. Critical points: ∂₂ = 2x₂ + x₁/2 = 0
    # ⇒ x₂ = −x₁/4; ∂₁ = 4x₁³ − 4x₁ + x₂/2 = 0 ⇒ x₁ ∈ {0, ±√(33/32)}.
    f(x) = (x[1]^2 - 1)^2 + x[2]^2 + 0.5 * x[1] * x[2]
    x1s = sqrt(33 / 32)
    true_cps = [[x1s, -x1s / 4], [-x1s, x1s / 4], [0.0, 0.0]]
    TR = TestInput(f; dim = 2, center = [0.0, 0.0], GN = 8, sample_range = 1.5, tolerance = nothing)

    @testset "residuals vanish at true critical points, not elsewhere" begin
        for basis in (:chebyshev, :legendre)
            pol = Constructor(TR, 4; basis = basis)
            good = [cp ./ 1.5 for cp in true_cps]            # box coordinates
            bad = [[0.5, 0.3]]
            r_good = surrogate_gradient_residuals(pol, good)
            r_bad = surrogate_gradient_residuals(pol, bad)
            @test all(r_good .< 1e-9)                       # exact degree-4 fit
            @test r_bad[1] > 1e-2
            @test check_surrogate_residuals(pol, good) < 1e-9
            @test_throws ErrorException check_surrogate_residuals(pol, bad)
            @test check_surrogate_residuals(pol, bad; tol = Inf) |> isnan   # disabled
            # outside the margin: not checked
            @test isnan(surrogate_gradient_residuals(pol, [[3.0, 0.0]]; margin = 0.5)[1])
            @test isnan(check_surrogate_residuals(pol, [[3.0, 0.0]]))
            @test check_surrogate_residuals(pol, Vector{Vector{Float64}}()) == 0.0
            @test_throws ArgumentError surrogate_gradient_residuals(pol, good; margin = -1.0)
        end
    end

    @testset "ApproxPoly overload solves the fitted polynomial (both bases)" begin
        @polyvar x[1:2]
        for basis in (:chebyshev, :legendre)
            pol = Constructor(TR, 4; basis = basis)
            cps = solve_polynomial_system(x, pol)              # defaults = pol's own metadata
            inbox = [c for c in cps if all(abs.(c) .<= 1)]
            phys = [1.5 .* c for c in inbox]
            for cp in true_cps
                @test any(p -> norm(p - cp) < 1e-6, phys)
            end
            # same answer through the explicit entry point
            cps2 = Globtim.solve_polynomial_system_from_approx(x, pol)
            @test length(cps2) == length(cps)
        end
    end

    @testset "the basis trap is caught, not returned" begin
        @polyvar x[1:2]
        pol_leg = Constructor(TR, 4; basis = :legendre)
        # Solving a Legendre fit as Chebyshev used to return (±1.1407, 0) silently.
        @test_throws ErrorException solve_polynomial_system(x, pol_leg; basis = :chebyshev, normalized = true)
        pol_cheb = Constructor(TR, 4; basis = :chebyshev)
        # Chebyshev with the orthonormal weights is a different polynomial too.
        @test_throws ErrorException solve_polynomial_system(x, pol_cheb; normalized = true)
        # with the check disabled the old behaviour is reachable, explicitly
        cps = solve_polynomial_system(x, pol_cheb; normalized = true, surrogate_residual_tol = Inf)
        @test cps isa Vector
    end

    @testset "tolerance is forwarded on the monomial path of from_approx" begin
        @polyvar x[1:2]
        pol = Constructor(TR, 4; basis = :chebyshev)
        # a correct solve has residuals ~1e-12; an impossible tolerance must therefore
        # raise — before the fix the keyword was accepted and silently ignored here
        @test_throws ErrorException Globtim.solve_polynomial_system_from_approx(x, pol; surrogate_residual_tol = 1e-30)
        @test Globtim.solve_polynomial_system_from_approx(x, pol; surrogate_residual_tol = Inf) isa Vector
    end

    @testset "sparsified solve is checked against the polynomial that was solved" begin
        @polyvar x[1:2]
        pol = Constructor(TR, 4; basis = :chebyshev)
        c = pol.coeffs
        @test Globtim._sparsify_coeffs(c, 0.0) === c
        cs = Globtim._sparsify_coeffs(c, 0.3)
        @test length(cs) == length(c)
        @test count(iszero, cs) > count(iszero, c)                       # something was chopped
        @test all((cs[i] == c[i]) || (cs[i] == 0 && abs(c[i]) < 0.3 * maximum(abs, c)) for i in eachindex(c))
        ps = Globtim._with_coeffs(pol, cs)
        @test ps.coeffs === cs && ps.basis == pol.basis && ps.center == pol.center
        @test_throws DimensionMismatch Globtim._with_coeffs(pol, cs[1:end-1])
        # the truncated system's roots are critical points of the TRUNCATED surrogate;
        # measured against the dense fit at least one of them is not, so the dense check
        # would have raised on a legitimate root
        roots = Globtim.solve_polynomial_system_from_approx(x, pol; sparsify_threshold = 0.3)
        @test roots isa Vector && !isempty(roots)
        inbox = [r for r in roots if all(abs.(r) .<= 1.0)]
        @test !isempty(inbox)
        @test check_surrogate_residuals(ps, inbox) < 1e-6
        @test maximum(surrogate_gradient_residuals(pol, inbox)) > 1e-4
    end

    @testset "solve_polynomial_with_defaults uses the stored metadata" begin
        @polyvar x[1:2]
        pol_leg = Constructor(TR, 4; basis = :legendre)
        cps = solve_polynomial_with_defaults(x, pol_leg)
        phys = [1.5 .* c for c in cps if all(abs.(c) .<= 1)]
        @test any(p -> norm(p - true_cps[1]) < 1e-6, phys)
    end
end
