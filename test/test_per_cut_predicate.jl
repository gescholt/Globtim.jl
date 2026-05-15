using Test
using Globtim
using Globtim: Subdomain, estimate_subdomain_error, pick_strategy

# Tests for bead globopt_merged-4vtd.3 — per-cut-direction bump-vs-split
# predicate. The current `pick_strategy` returns one global verdict per leaf;
# this file exercises the new per-axis API: `pick_strategy_per_axis` (returns
# a Vector{Symbol} of length n_dim) and `decide_action` (combines into an
# (action, cut_dim) pair).
#
# A note on test landscapes: `estimate_subdomain_error(f, sd, base_d)` uses a
# Chebyshev sample grid of GN = 2*base_d nodes per dimension. Test signals
# whose Chebyshev coefficients alias on this grid (e.g. T_n with n ≡ k
# (mod 2*base_d) aliasing to T_k) cannot be distinguished from the lower
# alias by the polynomial fit, so the residual collapses to numerical noise
# and no predicate can give a meaningful verdict. The tests below pick
# (test-degree, fit-degree) pairs that avoid aliasing on the resulting grid.

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

@testset "pick_strategy_per_axis + decide_action (4vtd.3)" begin

    @testset "Test 1: anisotropic slow-y → split along y" begin
        # f = T_2(x) + T_12(y). Fit at degree 6 (so GN=12, T_12 doesn't alias
        # to a representable mode — see top-of-file note). The x-direction
        # is fully captured (deg 2 ≤ 6); the y-direction has all its mass
        # at shell 12 = base_d + 6, well past d+4=10 and not in {d+1, d+2}.
        # Per-axis verdict must be [:bump, :split]; cut_dim = 2.
        f(x) = cheb_T(2, x[1]) + cheb_T(12, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)

        verdicts = Globtim.pick_strategy_per_axis(sd)
        @test verdicts == [:bump, :split]

        action, cut_dim = Globtim.decide_action(verdicts)
        @test action === :split
        @test cut_dim == 2
    end

    @testset "Test 2: anisotropic slow-x → split along x (mirror of Test 1)" begin
        f(x) = cheb_T(12, x[1]) + cheb_T(2, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)

        verdicts = Globtim.pick_strategy_per_axis(sd)
        @test verdicts == [:split, :bump]

        action, cut_dim = Globtim.decide_action(verdicts)
        @test action === :split
        @test cut_dim == 1
    end

    @testset "Test 3: isotropic split → split, lowest-index tie-break" begin
        # Both axes have T_12 at shell 12. Both must say :split. The decision
        # function picks the lowest-index axis as the documented tie-breaker.
        f(x) = cheb_T(12, x[1]) + cheb_T(12, x[2])
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
        # Per-axis [:bump, :bump]. Decision: bump, cut_dim = nothing.
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
        # f = T_5(x) + T_5(y) fit at degree 4 — residual is exactly the two
        # T_5 contributions, each at shell d+1 = 5. Per-axis concentration = 1
        # on both axes → both :bump. Globally pick_strategy also returns
        # :bump (concentration = 1, well above θ = 0.5; coverage ≈ 1, well
        # above θ_coverage = 0.005). Confirms per-axis ⇄ global agreement
        # in the clean bump-friendly case.
        f(x) = cheb_T(5, x[1]) + cheb_T(5, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)

        verdicts = Globtim.pick_strategy_per_axis(sd)
        @test all(v -> v === :bump, verdicts)

        action, _ = Globtim.decide_action(verdicts)
        @test action === pick_strategy(sd)
    end
end
