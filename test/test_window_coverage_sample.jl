using Test
using Globtim
using Globtim:
    Subdomain,
    estimate_subdomain_error,
    subdomain_mode_spectrum,
    compute_mode_spectrum,
    pick_strategy

# Tests for the sample-based (Parseval-true) window coverage (bead 4vtd.2).
#
# The legacy `window_coverage = Σ η_α² / rel_l2²` mixes units: the numerator
# sums SQUARED LS COEFFICIENTS (Euclidean, basis columns not orthonormal —
# ‖T_α‖² at the sample grid is N/2^{#nonzero(α)}, not 1), the denominator is
# the quadrature-weighted residual energy. The ratio understates the true
# in-window energy fraction by 2^{#zero components of α} per mode — a factor
# that depends on DIMENSION and mode sparsity, which is why the docstring
# says "relative comparison only" and why calibrated thresholds sit at
# absurd values like θ_coverage = 0.005.
#
# The sample-based metric is computed from the SAME cached samples with no
# unit mixing:
#
#     coverage = ‖p_ext - p‖² / ‖f - p‖²  =  1 - ‖f - p_ext‖² / ‖f - p‖²
#
# (Euclidean at the sample grid; exact Pythagoras since base span ⊆ extended
# span and both fits are LS projections). It is a true fraction in [0, 1].

# Chebyshev polynomials used throughout.
T2(t) = 2t^2 - 1
T3(t) = 4t^3 - 3t
T5(t) = 16t^5 - 20t^3 + 5t
T20(t) = cos(20 * acos(clamp(t, -1.0, 1.0)))

@testset "window_coverage_sample (4vtd.2)" begin

    # ---------------------------------------------------------------------
    # Test 1 (bead): residual entirely inside the window ⇒ coverage ≈ 1,
    # AND the legacy metric on the same fit reads a misleading 0.5.
    # ---------------------------------------------------------------------
    @testset "in-window residual: sample ≈ 1, legacy misleads by 2× (2D)" begin
        # Base degree 3, auto grid (7 Gauss pts/dim, 49 samples, ext_d = 6).
        # f = T₂ + 0.3·T₅ along x₁: base fit captures T₂ exactly, residual is
        # 0.3·T₅ — mode (5,0), INSIDE the window (3,6]. Truth: coverage = 1.
        # Legacy: mode (5,0) has one zero component in 2D, so its coefficient²
        # under-counts its sample energy by 2¹ ⇒ legacy = 0.5. Deterministic,
        # and it would read 0.25 for the same 1D function embedded in 3D —
        # the "relative comparison only" caveat made concrete.
        f(x) = T2(x[1]) + 0.3 * T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 3, basis = :chebyshev)
        spec = subdomain_mode_spectrum(sd)

        @test spec.window_coverage_sample >= 0.999
        @test isapprox(spec.window_coverage, 0.5; rtol = 0.05)  # the bug
    end

    @testset "legacy under-count grows with dimension; sample invariant (3D)" begin
        # Same residual mode T₅ along x₁ embedded in 3D: mode (5,0,0) has two
        # zero components ⇒ legacy = 0.25. The sample-based fraction stays 1.
        f(x) = T2(x[1]) + 0.3 * T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 3, basis = :chebyshev)
        spec = subdomain_mode_spectrum(sd)

        @test spec.window_coverage_sample >= 0.999
        @test isapprox(spec.window_coverage, 0.25; rtol = 0.05)
    end

    # ---------------------------------------------------------------------
    # Test 2 (bead): residual entirely OUTSIDE the window ⇒ coverage ≈ 0.
    # Needs a fine grid: on the auto grid everything above the Nyquist band
    # aliases back into the window (see the aliasing testset below).
    # ---------------------------------------------------------------------
    @testset "out-of-window residual on a resolving grid: sample ≈ 0" begin
        # Base degree 3 with n_samples_per_dim = 25: the grid resolves T₂₀
        # exactly, the window is still (3, 6] (ext = 2·base). All residual
        # energy is invisible to the window ⇒ coverage ≈ 0.
        f(x) = T20(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 3, basis = :chebyshev, n_samples_per_dim = 25)
        spec = subdomain_mode_spectrum(sd)

        @test spec.extended_degree == 6      # window did not widen with the grid
        @test spec.window_coverage_sample <= 0.05
    end

    @testset "mixed in/out residual: sample reads the true 50/50 split" begin
        # f = T₅ + T₂₀ along x₁, base 3, 25-pt grid: equal sample energy at
        # mode (5,0) (inside window) and (20,0) (outside). Truth: 0.5.
        # Legacy reads ≈ 0.0196: on top of the 2× sparsity under-count, its
        # normalization hardcodes the AUTO-grid quadrature weight
        # (GN = 2·base ⇒ (2/7)² here) while the actual grid has 25 pts/dim —
        # an n_samples_per_dim override distorts legacy by the assumed/actual
        # grid ratio on the numerator only (measured: 0.5 · (2/7)²·25/(2·…)
        # ⇒ 1/51). The sample-based fraction has no weights to get wrong.
        f(x) = T5(x[1]) + T20(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 3, basis = :chebyshev, n_samples_per_dim = 25)
        spec = subdomain_mode_spectrum(sd)

        @test isapprox(spec.window_coverage_sample, 0.5; atol = 0.05)
        @test spec.window_coverage < 0.05              # grid-dependent garbage
        @test abs(spec.window_coverage - 0.5) > 0.15   # misleading as a fraction
    end

    @testset "KNOWN LIMIT: auto-grid aliasing folds T₂₀ into the window" begin
        # On the base-3 AUTO grid (7 Gauss pts/dim), T₂₀ ≡ -T₆ at the sample
        # points (2N - m aliasing with N = 7 ⇒ 14 - 20 ≡ 6). Mode 6 is inside
        # the window, so BOTH metrics report high coverage — no statistic
        # computed from these samples can tell T₂₀ from -T₆. Pinned here so
        # nobody mistakes the sample-based metric for an aliasing detector;
        # grid density (4vtd bead family: n_samples_per_dim) is the only cure.
        f(x) = T20(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 3, basis = :chebyshev)
        spec = subdomain_mode_spectrum(sd)

        @test spec.window_coverage_sample > 0.9
    end

    # ---------------------------------------------------------------------
    # Test 3 (bead): leaf-size behavior. The sample metric is a true
    # fraction on every leaf and varies continuously with leaf width.
    # ---------------------------------------------------------------------
    @testset "leaf-width sweep: true fraction, no discontinuity" begin
        f(x) = sin(5 * x[1]) + cos(3 * x[2])
        widths = 0.2:0.1:1.0
        covs = Float64[]
        for w in widths
            sd = Subdomain([(0.0, w), (0.0, w)])
            estimate_subdomain_error(f, sd, 3, basis = :chebyshev)
            spec = subdomain_mode_spectrum(sd)
            push!(covs, spec.window_coverage_sample)
        end
        @test all(c -> 0.0 <= c <= 1.0, covs)          # Parseval-true bound
        @test maximum(abs, diff(covs)) < 0.5            # no jump under h-change
    end

    # ---------------------------------------------------------------------
    # Test 4 (bead): NaN guard. Zero / roundoff-floor residual must give
    # coverage 1.0 with no NaN, where the legacy metric NaNs (rel_l2² = 0)
    # or divides roundoff by roundoff.
    # ---------------------------------------------------------------------
    @testset "zero-residual leaf: sample = 1.0, no NaN" begin
        # f is exactly representable at the base degree ⇒ residual is FP
        # roundoff only. Legacy divides two roundoff quantities; the sample
        # metric hits its relative floor and reports perfect coverage.
        f(x) = T3(x[1]) + T2(x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        spec = subdomain_mode_spectrum(sd)

        @test spec.window_coverage_sample == 1.0
        @test !isnan(spec.window_coverage_sample)
    end

    @testset "legacy NaN path (rel_l2² = 0) leaves sample coverage intact" begin
        f(x) = T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        spec = compute_mode_spectrum(sd.polynomial; rel_l2_squared = 0.0)

        @test isnan(spec.window_coverage)               # legacy guard
        @test isfinite(spec.window_coverage_sample)     # sample metric unaffected
        @test spec.window_coverage_sample > 0.9         # T₅ is inside (4,8]
    end

    @testset "empty spectrum ⇒ sample coverage NaN (no-signal contract)" begin
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        spec = subdomain_mode_spectrum(sd)   # no polynomial fitted
        @test isnan(spec.window_coverage_sample)
    end

    # ---------------------------------------------------------------------
    # Phase-1 wiring: the pick_strategy stagnation gate reads the sample
    # metric (θ_coverage = 0.4 in true-fraction units), not the legacy ratio.
    # ---------------------------------------------------------------------
    @testset "pick_strategy gate consumes the sample metric" begin
        base = (
            spectrum = [1.0],
            modes = [5 0],
            dominant_mode = [5, 0],
            spectral_concentration = 0.99,
            shell_mass = Dict(5 => 1.0),
            shell_decay = 2.0,
            base_degree = 4,
            extended_degree = 8,
        )
        # Legacy ratio says "stagnant" (would have fired the old gate), the
        # sample fraction says covered → gate quiet; bump signal decides.
        covered = merge(base, (window_coverage = 1e-4, window_coverage_sample = 0.95))
        @test pick_strategy(covered; rel_l2 = 0.5) === :bump
        # Sample fraction low → gate fires regardless of the legacy value.
        uncovered = merge(base, (window_coverage = 0.9, window_coverage_sample = 0.1))
        @test pick_strategy(uncovered; rel_l2 = 0.5) === :split
        # NaN sample coverage bypasses the gate (no-reference contract).
        nocov = merge(base, (window_coverage = 0.9, window_coverage_sample = NaN))
        @test pick_strategy(nocov; rel_l2 = 0.5) === :bump
        # The near-convergence conjunct still suppresses the gate.
        @test pick_strategy(uncovered; rel_l2 = 5e-3) === :bump
    end
end
