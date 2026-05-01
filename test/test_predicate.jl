using Test
using Globtim
using Globtim:
    Subdomain,
    estimate_subdomain_error,
    pick_strategy,
    default_bump,
    adaptive_refine,
    SubdivisionTree

# Tests for the bump-vs-split predicate API (bead ehaj.1).

@testset "pick_strategy + default_bump (ehaj.1)" begin
    @testset "default_bump always returns :bump" begin
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        @test default_bump(sd) === :bump
    end

    @testset "Subdomain with no polynomial → :bump (default fallback)" begin
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        @test pick_strategy(sd) === :bump
    end

    @testset "T_5(x) leaf → :bump (concentration drives the call)" begin
        # Single Chebyshev mode at α=(5,0), all η²-mass at shell d+1=5.
        # Shells d+2=6, d+3=7, d+4=8 are FP-roundoff. shell_decay between
        # roundoff-only shells is unreliable, so concentration ≈ 1.0 carries
        # the bump verdict. This test exercises the concentration fallback.
        T5(t) = 16t^5 - 20t^3 + 5t
        f(x) = T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        @test pick_strategy(sd) === :bump
    end

    @testset "T_8(x) leaf → :split (mass past cutoff, no decay, low conc.)" begin
        # Single Chebyshev mode at α=(8,0). Real mass at shell d+4=8, FP-roundoff
        # mass elsewhere. shell_decay deeply negative; concentration ≈ 0 (mass
        # is at d+4 not d+1/d+2). Both signals say :split.
        T8(t) = 128t^8 - 256t^6 + 160t^4 - 32t^2 + 1
        f(x) = T8(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        @test pick_strategy(sd) === :split
    end

    @testset "Stagnant T_6+T_8 → :split (m(d+4) > m(d+2), low conc.)" begin
        # Bead dksx.0a "ackley pattern": shell_decay < 0 even with both shells
        # populated. Concentration is m(d+2)/(m(d+2)+m(d+4)) = 0.25/1.25 = 0.2,
        # below θ=0.5. Both signals say :split.
        T6(t) = 32t^6 - 48t^4 + 18t^2 - 1
        T8(t) = 128t^8 - 256t^6 + 160t^4 - 32t^2 + 1
        f(x) = 0.5 * T6(x[1]) + 1.0 * T8(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        @test pick_strategy(sd) === :split
    end

    @testset "Coverage gate: low coverage forces :split (griewank pattern)" begin
        # Force the coverage axis to dominate by setting θ_coverage above the
        # leaf's measured window_coverage. Even with concentration=1, the
        # coverage gate fires first → :split. This is the dksx.0a "griewank
        # pattern" — high concentration but residual tail outside window.
        T5(t) = 16t^5 - 20t^3 + 5t
        f(x) = T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        @test pick_strategy(sd; θ_coverage = 1e9) === :split
    end

    @testset "Bump signals are OR'd: both axes must fail to split" begin
        # The rule is: bump iff (shell_decay > θ_decay) OR (concentration ≥ θ_conc),
        # gated by coverage. Forcing JUST concentration high doesn't necessarily
        # split because shell_decay can carry the day from FP noise. Test the OR
        # explicitly: setting both θ_decay and θ_concentration to absurd values
        # is the only way to deny both signals.
        T5(t) = 16t^5 - 20t^3 + 5t
        f(x) = T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        @test pick_strategy(sd; θ_decay = 1e9, θ_concentration = 1e9) === :split
    end

    @testset "Bump-friendly two-mode (T_5 + small T_7) → :bump" begin
        # Real mass concentrated at d+1=5 with a small tail at d+3=7. shell_decay
        # between d+2/d+4 may still be roundoff-driven, but concentration ≈ 1
        # carries the bump verdict.
        T5(t) = 16t^5 - 20t^3 + 5t
        T7(t) = 64t^7 - 112t^5 + 56t^3 - 7t
        f(x) = 1.0 * T5(x[1]) + 0.001 * T7(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        @test pick_strategy(sd) === :bump
    end

    @testset "adaptive_refine threads predicate through (default unchanged)" begin
        # With predicate=default_bump (the new default), behavior must match
        # the legacy "always bump" path. Smoke test: no errors, tree builds.
        f(x) = sin(x[1]) * cos(x[2])
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = adaptive_refine(
            f,
            bounds,
            4;
            enable_p_refinement = true,
            max_degree = 10,
            max_leaves = 16,
            l2_tolerance = 1e-3,
            tolerance_mode = :relative,
        )
        @test tree isa SubdivisionTree
    end

    @testset "adaptive_refine accepts custom predicate" begin
        # Switch to pick_strategy and ensure the call goes through cleanly.
        # Behavior change is expected (some leaves will split where the default
        # would bump); we only assert it runs.
        f(x) = exp(-(x[1]^2 + x[2]^2))
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        tree = adaptive_refine(
            f,
            bounds,
            4;
            enable_p_refinement = true,
            max_degree = 10,
            max_leaves = 16,
            l2_tolerance = 1e-3,
            tolerance_mode = :relative,
            predicate = pick_strategy,
        )
        @test tree isa SubdivisionTree
    end
end
