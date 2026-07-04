using Test
using Globtim
using Globtim:
    Subdomain, estimate_subdomain_error, compute_mode_spectrum, shell_decay_parity,
    pick_strategy

# Tests for parity-stratified shell decay (bead 4vtd.1).
#
# The single-ratio `shell_decay = 0.5·log(m(d+2)/m(d+4))` compares two FIXED
# shells, so it NaNs (shell absent) or returns roundoff garbage (shell present
# but FP-noise-only) whenever the residual populates only one parity class —
# even-symmetric functions (Ackley, Griewank) populate even shells only.
# `shell_decay_parity` fits m(s) ∝ λ^s separately on the even and odd shells
# that carry real mass, in the SAME log-rate units as the old scalar (the old
# scalar IS the 2-point even-pair fit), and combines the finite parity rates
# by arithmetic mean in log-rate space (= geometric mean of the multiplicative
# per-shell factors λ).

@testset "shell_decay_parity (4vtd.1)" begin

    # ---------------------------------------------------------------------
    # Closed-form unit tests on synthetic shell_mass dictionaries: exact
    # zeros and exact geometric decay, no LS-fit quadrature noise.
    # ---------------------------------------------------------------------

    @testset "two-shell parity classes reproduce the old 2-point ratios" begin
        # base 4, window (4,8]: even {6,8}, odd {5,7}. Both parities planted
        # with ratio 100 per 2 shells ⇒ decay = 0.5·log(100) each.
        sm = Dict(5 => 1.0, 7 => 1e-2, 6 => 0.5, 8 => 5e-3)
        r = shell_decay_parity(sm)
        @test r.n_even == 2 && r.n_odd == 2
        @test r.decay_even ≈ 0.5 * log(100) rtol = 1e-12
        @test r.decay_odd ≈ 0.5 * log(100) rtol = 1e-12
        @test r.combined ≈ 0.5 * log(100) rtol = 1e-12
    end

    @testset "≥3 shells per parity: least-squares fit, not endpoint ratio" begin
        # Even shells {4,6,8} in exact geometric decay λ² = 1e-2 per 2 shells:
        # LS on log m vs s recovers decay = -slope = log(100)/2 exactly.
        sm_geom = Dict(4 => 1e-2, 6 => 1e-4, 8 => 1e-6)
        r = shell_decay_parity(sm_geom)
        @test r.n_even == 3 && r.n_odd == 0
        @test r.decay_even ≈ 0.5 * log(100) rtol = 1e-9
        @test isnan(r.decay_odd)
        @test r.combined == r.decay_even

        # NON-geometric masses pin the LS averaging (an endpoint ratio would
        # give log(100)/4 ≈ 1.151 by coincidence here, so use the closed-form
        # LS slope): log m = [0, log(1e-2), log(1e-2)] at s = [4, 6, 8]
        # ⇒ slope = Σ(s-s̄)(y-ȳ)/Σ(s-s̄)² = -9.2103/8, decay = -slope.
        sm_flat = Dict(4 => 1.0, 6 => 1e-2, 8 => 1e-2)
        y = [0.0, log(1e-2), log(1e-2)]
        s = [4.0, 6.0, 8.0]
        slope = sum((s .- 6.0) .* (y .- sum(y) / 3)) / sum(abs2, s .- 6.0)
        r2 = shell_decay_parity(sm_flat)
        @test r2.decay_even ≈ -slope rtol = 1e-9
    end

    @testset "single-parity dict: other parity NaN, combined falls through" begin
        sm = Dict(4 => 1.0, 6 => 1e-2, 8 => 1e-4)   # even only
        r = shell_decay_parity(sm)
        @test isfinite(r.decay_even)
        @test isnan(r.decay_odd)
        @test r.combined == r.decay_even
    end

    @testset "roundoff-only shells are excluded by the relative noise floor" begin
        # Odd shells carry FP-roundoff mass (~1e-30 of the total): the parity
        # fit must NOT produce a garbage λ_odd from noise — this is the
        # roundoff sibling of the NaN failure the fixed-shell scalar has.
        sm = Dict(4 => 1.0, 6 => 1e-2, 5 => 1e-30, 7 => 3e-31)
        r = shell_decay_parity(sm)
        @test r.n_odd == 0
        @test isnan(r.decay_odd)
        @test r.combined == r.decay_even
    end

    @testset "fewer than 2 populated shells in a parity ⇒ NaN for it" begin
        sm = Dict(5 => 1.0, 6 => 0.5, 8 => 5e-3)   # odd has only shell 5
        r = shell_decay_parity(sm)
        @test r.n_odd == 1
        @test isnan(r.decay_odd)
        @test isfinite(r.decay_even)
        @test r.combined == r.decay_even
    end

    @testset "empty residual (perfect fit): sentinel is +Inf, not NaN" begin
        # SENTINEL SPEC (bead 4vtd.1 test 4): all-zero shell mass means the
        # residual has already decayed away — "no signal" is encoded as
        # decay = +Inf (comparison-safe: any θ_decay threshold reads it as
        # maximally bump-friendly, which is vacuously right on a converged
        # leaf) with n_even = n_odd = 0 as the machine-checkable discriminator
        # between "no signal" and "populated but unfittable" (NaN).
        for sm in (Dict{Int,Float64}(), Dict(5 => 0.0, 6 => 0.0))
            r = shell_decay_parity(sm)
            @test r.decay_even == Inf && r.decay_odd == Inf && r.combined == Inf
            @test r.n_even == 0 && r.n_odd == 0
        end
    end

    @testset "both parities populated but unfittable ⇒ combined NaN" begin
        sm = Dict(5 => 1.0, 6 => 0.5)   # one shell each
        r = shell_decay_parity(sm)
        @test isnan(r.decay_even) && isnan(r.decay_odd) && isnan(r.combined)
        @test r.n_even == 1 && r.n_odd == 1
    end

    # ---------------------------------------------------------------------
    # Real fits: the failure mode this bead exists for, end to end.
    # ---------------------------------------------------------------------

    @testset "even-symmetric residual: old scalar NaN, parity fit finite" begin
        # f = T₄ + 0.1·T₆ fit at base degree 3: window (3, 6] has shells
        # {4,5,6}. Real mass sits on even shells 4 and 6 only. The old scalar
        # compares d+2 = 5 (roundoff) with d+4 = 7 (OUTSIDE the window ⇒ mass
        # exactly 0) ⇒ deterministically NaN. The parity fit reads the even
        # pair (4,6) and returns the true rate 0.5·log(m₄/m₆) ≈ 0.5·log(100).
        T4(t) = 8t^4 - 8t^2 + 1
        T6(t) = 32t^6 - 48t^4 + 18t^2 - 1
        f(x) = T4(x[1]) + 0.1 * T6(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 3, basis = :chebyshev)
        spec = compute_mode_spectrum(sd.polynomial)

        @test isnan(spec.shell_decay)               # the bug being fixed
        r = shell_decay_parity(spec)
        @test r.n_even >= 2
        @test isfinite(r.decay_even)
        @test r.decay_even ≈ 0.5 * log(100) rtol = 0.2   # quadrature noise
        @test r.combined == r.decay_even
    end

    @testset "mixed-symmetry residual: parity combined matches old scalar" begin
        # Both parities planted at the SAME ratio-100 rate (base 4, window
        # (4,8]): T₅+0.1T₇ (odd) + 0.5T₆+0.05T₈ (even). The old scalar reads
        # the even pair; combined averages two equal rates ⇒ must agree with
        # the old scalar within 10% (bead sanity condition).
        T5(t) = 16t^5 - 20t^3 + 5t
        T6(t) = 32t^6 - 48t^4 + 18t^2 - 1
        T7(t) = 64t^7 - 112t^5 + 56t^3 - 7t
        T8(t) = 128t^8 - 256t^6 + 160t^4 - 32t^2 + 1
        f(x) = T5(x[1]) + 0.1 * T7(x[1]) + 0.5 * T6(x[1]) + 0.05 * T8(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        spec = compute_mode_spectrum(sd.polynomial)

        @test isfinite(spec.shell_decay)
        r = shell_decay_parity(spec)
        @test isfinite(r.decay_even) && isfinite(r.decay_odd)
        @test isapprox(r.combined, spec.shell_decay; rtol = 0.1)
    end

    @testset "pure odd residual: (NaN, finite), combined falls through" begin
        # f = T₅ + 0.1·T₇ at base 4: odd shells {5,7} real, even shells {6,8}
        # FP-roundoff only. The old scalar divides two roundoff masses —
        # finite GARBAGE of arbitrary sign (not asserted; it is not
        # deterministic). The parity fit must filter the roundoff evens and
        # report the odd rate.
        T5(t) = 16t^5 - 20t^3 + 5t
        T7(t) = 64t^7 - 112t^5 + 56t^3 - 7t
        f(x) = T5(x[1]) + 0.1 * T7(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        spec = compute_mode_spectrum(sd.polynomial)

        r = shell_decay_parity(spec)
        @test isnan(r.decay_even)
        @test isfinite(r.decay_odd)
        @test r.decay_odd ≈ 0.5 * log(100) rtol = 0.2
        @test r.combined == r.decay_odd
    end

    # ---------------------------------------------------------------------
    # Predicate wiring: pick_strategy consumes `combined` (Phase 1).
    # ---------------------------------------------------------------------

    @testset "pick_strategy: even-symmetric bump-friendly leaf no longer NaN-falls-through" begin
        # Even-only residual with a strong parity decay but concentration
        # BELOW θ_concentration: under the old scalar the decay signal was NaN
        # so the leaf split; under the parity fit the decay signal carries the
        # bump verdict. Synthetic spec, base 4: mass at even shells 6 and 8
        # (so concentration = m₆/(m₆+m₈) is small w.r.t. θ = 0.9), planted
        # rate 0.5·log(m₆/m₈) = 0.5·log(50) ≈ 1.96 > θ_decay = 0.5.
        spec = (
            spectrum = [sqrt(0.5), sqrt(0.01)],
            modes = [6 0; 8 0],
            dominant_mode = [6, 0],
            spectral_concentration = 0.5 / 0.51,   # < 0.9 is what matters...
            shell_mass = Dict(6 => 0.5, 8 => 0.01),
            shell_decay = NaN,                     # what the old scalar said
            window_coverage = 0.15,
            base_degree = 4,
            extended_degree = 8,
        )
        # ...so force the concentration axis quiet and let decay decide:
        @test pick_strategy(spec; θ_concentration = 1.1, rel_l2 = 0.5) === :bump
        # Old-scalar behavior check: with the parity signal ALSO denied, the
        # leaf splits — decay really is the deciding axis in this test.
        @test pick_strategy(spec; θ_concentration = 1.1, θ_decay = 1e9, rel_l2 = 0.5) ===
              :split
    end

    @testset "pick_strategy: parity-stagnant even leaf still splits" begin
        # Mass GROWS across even shells (ackley pattern): combined < 0 < θ.
        spec = (
            spectrum = [sqrt(0.1), sqrt(0.5)],
            modes = [6 0; 8 0],
            dominant_mode = [8, 0],
            spectral_concentration = 0.1 / 0.6,
            shell_mass = Dict(6 => 0.1, 8 => 0.5),
            shell_decay = NaN,
            window_coverage = 0.15,
            base_degree = 4,
            extended_degree = 8,
        )
        @test pick_strategy(spec; rel_l2 = 0.5) === :split
    end
end
