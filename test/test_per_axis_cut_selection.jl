using Test
using Globtim
using Globtim: Subdomain, estimate_subdomain_error, select_cut_dimension

# Tests for bead 4vtd.5 — per-axis spectrum-based cut selection.
# Phase 0 RED: `pick_cut_dim_spectrum` is not implemented yet, so every test
# below must fail with UndefVarError (or `LoadError` wrapping one). Phase 1
# GREEN will land the implementation in pkg/globtim/src/per_axis_cut_selection.jl
# and turn these green.
#
# Hypothesis (per bead 4vtd.5): on anisotropic problems, picking the cut
# dimension by **slowest mode-spectrum decay along each axis** identifies the
# offender axis more reliably than the current per-axis residual-variance
# heuristic in `select_cut_dimension` (adaptive_subdivision.jl:413-482). The
# variance score is a 2nd moment that doesn't see where the energy lives in
# frequency; the spectrum score does.
#
# Same Chebyshev-grid aliasing caveat as test_per_cut_predicate.jl applies:
# `estimate_subdomain_error(f, sd, base_d)` uses GN = 2*base_d Chebyshev
# nodes per dimension, and signals with mode index n ≡ k (mod 2*base_d) alias
# down to mode k. The test landscapes below pick (test-degree, fit-degree)
# pairs that avoid aliasing.

function cheb_T(n::Int, t::Real)
    n == 0 && return one(t)
    n == 1 && return t
    Tnm1, Tn = one(t), t
    for _ = 1:(n-1)
        Tnm1, Tn = Tn, 2 * t * Tn - Tnm1
    end
    return Tn
end

@testset "pick_cut_dim_spectrum (4vtd.5)" begin

    @testset "Test 1: anisotropic slow-y → cut along y" begin
        # f = T_2(x) + T_12(y), fit deg 6. The x-direction is captured
        # exactly (deg 2 ≤ 6); all residual mass lives on the y-axis spectrum
        # at shell 12. Spectrum-based picks the axis with the most resistance
        # to bumping — here, y.
        f(x) = cheb_T(2, x[1]) + cheb_T(12, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)
        @test Globtim.pick_cut_dim_spectrum(sd) == 2
    end

    @testset "Test 2: anisotropic slow-x → cut along x (mirror)" begin
        f(x) = cheb_T(12, x[1]) + cheb_T(2, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)
        @test Globtim.pick_cut_dim_spectrum(sd) == 1
    end

    @testset "Test 3: equal axis-total, slower decay on y → cut along y" begin
        # Both axes carry residual mass at shells 8 and 10. By construction:
        #   x-axis:  m(8)=1.288^2,        m(10)=(0.3·1.288)^2
        #   y-axis:  m(8)=1.0^2,          m(10)=(0.9·1.0)^2
        # Per-axis axis_total (m(8)+m(10)) is approximately equal:
        #   x: 1.288^2 · (1 + 0.09) ≈ 1.808
        #   y: 1.0^2   · (1 + 0.81) ≈ 1.810
        # so a 2nd-moment scorer sees both axes as equally "rough". But the
        # per-axis decay diverges sharply:
        #   x: 0.5·log(m(8)/m(10)) = 0.5·log(1/0.09)  ≈  1.20  (FAST)
        #   y: 0.5·log(m(8)/m(10)) = 0.5·log(1/0.81)  ≈  0.11  (SLOW)
        # Spectrum-based picks y. This is the headline anisotropy-detection
        # win case: variance is blind, spectrum is not.
        f(x) =
            (1.288 * cheb_T(8, x[1]) + 0.3 * 1.288 * cheb_T(10, x[1])) +
            (1.0   * cheb_T(8, x[2]) + 0.9 * 1.0   * cheb_T(10, x[2]))
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)
        @test Globtim.pick_cut_dim_spectrum(sd) == 2
    end

    @testset "Test 4: isotropic high-shell → lowest-index tie-break" begin
        # Both axes have a T_12 contribution. Axis_total and (degenerate)
        # decay are equal across axes. The documented tie-break is lowest
        # index — matching `decide_action`'s convention from bead 4vtd.3 so
        # the two predicates compose deterministically. Test pins the rule.
        f(x) = cheb_T(12, x[1]) + cheb_T(12, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)
        @test Globtim.pick_cut_dim_spectrum(sd) == 1
    end

    @testset "Test 5: fully captured residual → must still return a valid dim" begin
        # f = T_4(x) + T_4(y) fit at deg 6 — residual ≈ machine noise.
        # No meaningful per-axis signal exists; `pick_cut_dim_spectrum`
        # must NOT crash and must return a valid 1-indexed dim. By the
        # lowest-index tie-break it should return 1.
        f(x) = cheb_T(4, x[1]) + cheb_T(4, x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6, basis = :chebyshev)
        d = Globtim.pick_cut_dim_spectrum(sd)
        @test d == 1
    end
end
