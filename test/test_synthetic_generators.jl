using Test
using Globtim
using Globtim: Subdomain, estimate_subdomain_error, pick_strategy_per_axis_lsfit
using Random

include(joinpath(@__DIR__, "synthetic_generators.jl"))
using .SyntheticGenerators:
    PlantedDecay, make_planted, effective_rho, planted_tail, right_decision

# Tests for the planted-decay generator + closed-form decision oracle
# (bead 8f4p.5.2 DR-ORACLE). Acceptance criteria pinned here:
#   (1) measured per-axis decay on the fit grid is monotone in planted ρᵢ,
#   (2) the oracle flags argmin ρᵢ as the cut axis on anisotropic instances,
#   (3) the oracle says :bump when all ρᵢ are large relative to the degree
#       budget (reachable) and :done when the tail already clears tolerance.

@testset "planted-decay generator + oracle (8f4p.5.2)" begin

    @testset "generating-function identity: coefficients are exactly ρ^{-k}" begin
        # f (1D, untilted at xstar=0 ⇒ tilt λ = g'(0) subtracted back) must
        # equal the truncated series Σ ρ^{-k} T_k(x) up to the geometric
        # truncation error. Chebyshev three-term recurrence, K = 200 terms.
        ρ = 1.7
        f, planted = make_planted((ρ,))
        λ = planted.lambda[1]
        for x in (-0.95, -0.4, 0.0, 0.33, 0.8, 0.999)
            Tm, Tk = 1.0, x           # T₀, T₁
            series = 1.0 + x / ρ      # k = 0, 1 terms
            for k in 2:200
                Tm, Tk = Tk, 2x * Tk - Tm
                series += ρ^(-Float64(k)) * Tk
            end
            @test f([x]) + λ * x ≈ series rtol = 1e-12
        end
    end

    @testset "planted interior minimum sits exactly at xstar" begin
        f, _ = make_planted((1.5, 4.0); xstar = (0.3, -0.5))
        x0 = [0.3, -0.5]
        # Central-difference gradient vanishes at xstar…
        h = 1e-6
        for i in 1:2
            e = zeros(2)
            e[i] = h
            @test abs(f(x0 + e) - f(x0 - e)) / (2h) < 1e-6
        end
        # …and xstar beats random points (strict convexity ⇒ unique min).
        rng = Xoshiro(42)
        fmin = f(x0)
        for _ in 1:50
            p = 2 .* rand(rng, 2) .- 1
            @test f(p) >= fmin
        end
    end

    @testset "effective_rho: exact on the full box, rises under bisection" begin
        _, planted = make_planted((1.3, 2.0, 7.5))
        full = [(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]
        @test effective_rho(planted, full) ≈ [1.3, 2.0, 7.5] rtol = 1e-12

        # Bisect axis 1: BOTH children have strictly larger ρ_eff than the
        # parent; the right child (closer to the pole at x_p > 1) is the
        # smaller of the two.
        left = [(-1.0, 0.0), (-1.0, 1.0), (-1.0, 1.0)]
        right = [(0.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]
        ρL = effective_rho(planted, left)[1]
        ρR = effective_rho(planted, right)[1]
        @test ρR > 1.3 && ρL > 1.3
        @test ρL > ρR
        # Untouched axes are exactly unchanged.
        @test effective_rho(planted, left)[2:3] ≈ [2.0, 7.5] rtol = 1e-12
    end

    @testset "acceptance 1: measured per-axis ρ̂ is monotone in planted ρ" begin
        # Fit the 3D planted instance on the full box and read the E2
        # LS-slope estimates: their ORDER must reproduce the planted order
        # (that is the property the oracle labels certify downstream).
        # Base degree 4, not 6: at degree 6 the ρ=6 axis's tail mass is
        # already below the estimator's axis_mass_floor (it has effectively
        # converged), which is the correct "no signal" answer but not the
        # ordering being pinned here.
        f, planted = make_planted((1.5, 3.0, 6.0))
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        ls = pick_strategy_per_axis_lsfit(sd)
        ρ̂ = [r.rho for r in ls]
        @test all(isfinite, ρ̂)
        @test ρ̂[1] < ρ̂[2] < ρ̂[3]
        # The slowest axis is estimated quantitatively, not just ordinally
        # (fast axes sit near the LS-solve noise floor, so only order is
        # asserted for them).
        @test isapprox(ρ̂[1], 1.5; rtol = 0.25)
    end

    @testset "oracle: :done when the planted tail clears tolerance" begin
        _, planted = make_planted((8.0, 8.0))
        full = [(-1.0, 1.0), (-1.0, 1.0)]
        d = right_decision(planted, full, 6; l2_tolerance = 1e-2, max_degree = 20)
        @test d.action === :done
        @test d.cut_dim === nothing
        @test d.degree_needed == 6
    end

    @testset "acceptance 3: :bump when tolerance is reachable in the budget" begin
        _, planted = make_planted((3.0, 3.0))
        full = [(-1.0, 1.0), (-1.0, 1.0)]
        d = right_decision(planted, full, 2; l2_tolerance = 1e-6, max_degree = 30)
        @test d.action === :bump
        @test d.cut_dim === nothing
        @test 2 < d.degree_needed <= 30
        # Consistency: the reported degree really is minimal — at
        # degree_needed the oracle stops, one degree lower it does not.
        @test right_decision(
            planted, full, d.degree_needed;
            l2_tolerance = 1e-6, max_degree = 30,
        ).action === :done
        @test right_decision(
            planted, full, d.degree_needed - 1;
            l2_tolerance = 1e-6, max_degree = 30,
        ).action !== :done
        # Faster planted decay ⇒ smaller needed degree.
        _, faster = make_planted((6.0, 6.0))
        d2 = right_decision(faster, full, 2; l2_tolerance = 1e-6, max_degree = 30)
        @test d2.degree_needed < d.degree_needed
    end

    @testset "acceptance 2: :split flags argmin ρ_eff on anisotropic instances" begin
        _, planted = make_planted((1.05, 5.0))
        full = [(-1.0, 1.0), (-1.0, 1.0)]
        d = right_decision(planted, full, 4; l2_tolerance = 1e-8, max_degree = 10)
        @test d.action === :split
        @test d.cut_dim == 1
        @test d.degree_needed > 10
        # Same instance with the axes swapped flags the other axis — the
        # verdict tracks the planted anisotropy, not an axis-order artifact.
        _, swapped = make_planted((5.0, 1.05))
        @test right_decision(
            swapped, full, 4; l2_tolerance = 1e-8, max_degree = 10,
        ).cut_dim == 2
    end

    @testset "bisecting the flagged axis makes the oracle's target easier" begin
        # Halving the slow axis raises its ρ_eff, so degree_needed strictly
        # falls level by level and the verdict eventually leaves :split —
        # the closed-form version of "subdivision terminates".
        _, planted = make_planted((1.05, 5.0))
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        needed = Int[]
        for _ in 1:6
            d = right_decision(planted, bounds, 4; l2_tolerance = 1e-8, max_degree = 10)
            push!(needed, d.degree_needed)
            d.action === :split || break
            lo, hi = bounds[d.cut_dim]
            bounds[d.cut_dim] = (lo, (lo + hi) / 2)   # keep the far-from-pole half
        end
        @test length(needed) >= 2
        @test all(diff(needed) .< 0)
    end

    @testset "input validation errors, no fallbacks" begin
        @test_throws ErrorException make_planted((1.0, 2.0))         # ρ ≤ 1
        @test_throws ErrorException make_planted((2.0,); xstar = (1.0,))  # boundary x*
        f, planted = make_planted((2.0, 2.0))
        @test_throws ErrorException f([0.5])                          # wrong dim
        @test_throws ErrorException effective_rho(planted, [(-2.0, 1.0), (-1.0, 1.0)])
        @test_throws ErrorException right_decision(
            planted, [(-1.0, 1.0), (-1.0, 1.0)], 4;
            l2_tolerance = 0.0, max_degree = 10,
        )
    end
end
