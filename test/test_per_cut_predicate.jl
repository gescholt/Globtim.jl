using Test
using Globtim
using Globtim: Subdomain, estimate_subdomain_error, pick_strategy

# Phase 0 (RED) tests for bead globopt_merged-4vtd.3 — per-cut-direction
# bump-vs-split predicate. The current `pick_strategy` returns one global
# verdict per leaf; this bead adds per-axis verdicts and a coupled decision.
#
# These tests reference `Globtim.pick_strategy_per_axis` and
# `Globtim.decide_action`, neither of which exist yet. Each test is expected
# to FAIL with `UndefVarError` until Phase 1 lands the implementation.
#
# Once Phase 1 is GREEN, this file should be added to runtests.jl alongside
# test_predicate.jl.

# Chebyshev T_n via recurrence — used to build anisotropic test landscapes
# with mass concentrated at a known shell.
function cheb_T(n::Int, t::Real)
    n == 0 && return one(t)
    n == 1 && return t
    Tnm1, Tn = one(t), t
    for _ = 1:(n-1)
        Tnm1, Tn = Tn, 2 * t * Tn - Tnm1
    end
    return Tn
end

@testset "pick_strategy_per_axis + decide_action (4vtd.3, Phase 0 RED)" begin

    @testset "Test 1: anisotropic slow-y → split along y" begin
        # f = T_2(x) + T_20(y). Fit at degree 6. The x-direction is fully
        # captured (deg 2 < 6); the y-direction has all its mass at shell 20,
        # far outside any +degree_step bump's reach. Per-axis verdict must
        # be (:bump, :split). Final decision: split, cut_dim = 2.
        f(x) = cheb_T(2, x[1]) + cheb_T(20, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)

        verdicts = Globtim.pick_strategy_per_axis(sd)
        @test verdicts == [:bump, :split]

        action, cut_dim = Globtim.decide_action(verdicts)
        @test action === :split
        @test cut_dim == 2
    end

    @testset "Test 2: anisotropic slow-x → split along x (mirror of Test 1)" begin
        f(x) = cheb_T(20, x[1]) + cheb_T(2, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)

        verdicts = Globtim.pick_strategy_per_axis(sd)
        @test verdicts == [:split, :bump]

        action, cut_dim = Globtim.decide_action(verdicts)
        @test action === :split
        @test cut_dim == 1
    end

    @testset "Test 3: isotropic split → split, lowest-index tie-break" begin
        # Both axes have mass at shell 20. Both must say :split. The decision
        # function picks the lowest-index axis as the documented tie-breaker
        # (deterministic; document this choice in Phase 1).
        f(x) = cheb_T(20, x[1]) + cheb_T(20, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)

        verdicts = Globtim.pick_strategy_per_axis(sd)
        @test verdicts == [:split, :split]

        action, cut_dim = Globtim.decide_action(verdicts)
        @test action === :split
        @test cut_dim == 1
    end

    @testset "Test 4: isotropic bump → bump, no cut" begin
        # f = T_4(x) + T_4(y) fit at degree 6 — fully captured in both axes.
        # Per-axis (:bump, :bump). Decision: bump, cut_dim = nothing.
        f(x) = cheb_T(4, x[1]) + cheb_T(4, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)

        verdicts = Globtim.pick_strategy_per_axis(sd)
        @test verdicts == [:bump, :bump]

        action, cut_dim = Globtim.decide_action(verdicts)
        @test action === :bump
        @test cut_dim === nothing
    end

    @testset "Test 5: all-bump fallback agrees with global pick_strategy" begin
        # Smooth radial Gaussian — bumping works in both axes. The new
        # per-axis mechanism must agree with the legacy global predicate
        # whenever per-axis verdicts are all :bump (regression guard against
        # the per-axis predicate diverging from the global one in the easy case).
        f(x) = exp(-(x[1]^2 + x[2]^2))
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 8, basis = :chebyshev)

        verdicts = Globtim.pick_strategy_per_axis(sd)
        @test all(v -> v === :bump, verdicts)

        action, _ = Globtim.decide_action(verdicts)
        @test action === pick_strategy(sd)
    end
end
