using Test
using Globtim
using Globtim: Subdomain, estimate_subdomain_error, compute_mode_spectrum,
    compute_subdomain_mode_spectrum!

# Tests for compute_mode_spectrum (bead dksx.0): per-Chebyshev-mode residual
# decomposition, computed from an existing fit's cached samples without new
# objective evaluations.

@testset "compute_mode_spectrum (dksx.0)" begin
    @testset "Degree-2 polynomial fit at d=4 → empty residual spectrum" begin
        # f(x, y) = x² + y² is exactly representable at degree 2; a degree-4
        # fit captures it with no residual. All η_α for d < |α|_∞ ≤ d* should
        # be ≈ 0, and the dominant-mode/concentration summary should reflect
        # "no signal."
        f(x) = x[1]^2 + x[2]^2
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        result = compute_mode_spectrum(sd.polynomial)

        @test result.base_degree == 4
        @test result.extended_degree >= 5
        @test !isempty(result.spectrum)
        # All residual mode coefficients are numerical zero (within 1e-8 of 0).
        @test maximum(result.spectrum) < 1e-8
        @test 0.0 <= result.spectral_concentration <= 1.0
    end

    @testset "Single Chebyshev mode α=(5,0): dominant + concentrated at d+1" begin
        # f(x,y) = T₅(x). Fitting at d=4 misses the entire signal, residual is
        # exactly T₅. Spectrum at d* = 8 should have a single nonzero coefficient
        # at α=(5,0). |α|_∞ = 5 = base_degree + 1 ⇒ concentration ≈ 1.
        T5(t) = 16t^5 - 20t^3 + 5t
        f(x) = T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        result = compute_mode_spectrum(sd.polynomial)

        @test result.dominant_mode == [5, 0]
        @test result.spectral_concentration > 0.99
        # |c_α| at α=(5,0) should be the dominant by a wide margin.
        sorted_eta = sort(result.spectrum, rev = true)
        @test sorted_eta[1] / max(sorted_eta[2], 1e-30) > 1e6
        # All residual mass lives at shell d+1 = 5 — no other shell is populated.
        @test haskey(result.shell_mass, 5)
        @test result.shell_mass[5] > 0
        for (s, m) in result.shell_mass
            s == 5 && continue
            @test m < 1e-20
        end
    end

    @testset "Single Chebyshev mode α=(8,0): dominant but NOT concentrated" begin
        # T₈(x) at d=4: |α|_∞ = 8 ∉ {d+1=5, d+2=6}, so the dominant mode is
        # outside the "near-cutoff" band ⇒ spectral_concentration ≈ 0.
        T8(t) = 128t^8 - 256t^6 + 160t^4 - 32t^2 + 1
        f(x) = T8(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        result = compute_mode_spectrum(sd.polynomial)

        @test result.dominant_mode == [8, 0]
        @test result.spectral_concentration < 0.01
        # All real mass is at shell 8 = d+4. Shells d+1=5, d+2=6, d+3=7 have
        # only FP-roundoff energy (~1e-30), but `>0` so shell_decay is
        # computed as a large negative log-ratio instead of NaN. That's the
        # right signal for the predicate: "essentially no mass at d+2 relative
        # to d+4 ⇒ extremely stagnant ⇒ split, don't bump".
        @test get(result.shell_mass, 8, 0.0) > 0.1
        @test get(result.shell_mass, 6, 0.0) < 1e-20
        @test isfinite(result.shell_decay)
        @test result.shell_decay < -10.0
    end

    @testset "compute_subdomain_mode_spectrum! writes back to subdomain" begin
        f(x) = sin(x[1]) * cos(x[2])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)

        @test isempty(sd.mode_spectrum)
        @test isempty(sd.dominant_mode)
        @test isnan(sd.spectral_concentration)

        result = compute_subdomain_mode_spectrum!(sd)

        @test !isempty(sd.mode_spectrum)
        @test sd.mode_spectrum == result.spectrum
        @test length(sd.dominant_mode) == 2
        @test 0.0 <= sd.spectral_concentration <= 1.0
        @test !isnan(sd.spectral_concentration)
    end

    @testset "Subdomain without polynomial → no-op, returns empty" begin
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        result = compute_subdomain_mode_spectrum!(sd)

        @test isempty(result.spectrum)
        @test isempty(sd.mode_spectrum)
        @test isnan(sd.spectral_concentration)
    end

    @testset "Custom extended_degree clamp: requested > d_safe is reduced" begin
        # Subdomain with d=4 yields per_dim_GN=8 ⇒ 81 samples in 2D ⇒ d_safe = 8.
        # Requesting extended_degree=20 should clamp down without erroring.
        f(x) = exp(-(x[1]^2 + x[2]^2))
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        result = compute_mode_spectrum(sd.polynomial; extended_degree = 20)

        @test result.extended_degree <= 8
        @test result.extended_degree > 4
    end

    @testset "d_safe handles n_dim'th-root FP roundoff (regression)" begin
        # 3D fit at d=4 with default GN=8 produces 9³=729 samples. d_safe should
        # be 8 because (8+1)³ = 729 ≤ 729. The naive `floor(729^(1/3)) - 1`
        # returned 7 due to Float64 cube-root roundoff; the integer-walk fix
        # returns 8. Without this, ackley_3d's dominant residual mode at
        # |α|_∞=8 is invisible to the spectrum.
        f(x) = x[1]^2 + x[2]^2 + x[3]^2
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        result = compute_mode_spectrum(sd.polynomial)
        @test result.extended_degree == 8
    end

    @testset "L2-residual energy reconciles with relative_l2_error" begin
        # The squared η-mass should approximately equal relative_l2_error² for
        # a fit where the residual is fully captured by modes ≤ extended_degree.
        # This is the math sanity check: ‖r‖² / ‖f‖² ≈ Σ η_α².
        T5(t) = 16t^5 - 20t^3 + 5t
        f(x) = T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        result = compute_mode_spectrum(sd.polynomial)

        eta_energy = sum(abs2, result.spectrum)
        rel_l2_squared = sd.relative_l2_error^2
        # Both are computed under different inner-product conventions
        # (LS vs. CC quadrature), so allow generous tolerance — the test only
        # asserts they're in the same ballpark, not exactly equal.
        @test eta_energy > 0
        @test rel_l2_squared > 0
        ratio = eta_energy / rel_l2_squared
        @test 0.1 < ratio < 10.0
    end

    @testset "shell_decay: bump-friendly residual decays sharply across shells" begin
        # f = c1 * T_5(x) + c2 * T_7(x) with |c1| ≫ |c2|. Residual at d=4 has
        # mass at shells 5 and 7. shell_decay between d+2=6 and d+4=8 is NaN
        # here because both shells are empty for this 1D-like construction —
        # the test instead checks the dictionary directly.
        T5(t) = 16t^5 - 20t^3 + 5t
        T7(t) = 64t^7 - 112t^5 + 56t^3 - 7t
        f(x) = 1.0 * T5(x[1]) + 0.001 * T7(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        result = compute_mode_spectrum(sd.polynomial)

        m5 = get(result.shell_mass, 5, 0.0)
        m7 = get(result.shell_mass, 7, 0.0)
        @test m5 > 0
        @test m7 > 0
        # Geometric decay across shells (ratio of the two square magnitudes).
        @test m5 / m7 > 1e4  # |c1/c2|² = (1/0.001)² = 1e6 minus quadrature noise
    end

    @testset "shell_decay: stagnant residual (T_6 + T_8) shows m(d+4) ≥ m(d+2)" begin
        # f = c6 * T_6(x) + c8 * T_8(x) with |c8| > |c6|. Residual at d=4 has
        # mass at shell 6 = d+2 AND shell 8 = d+4. Since |c8| > |c6|, mass at
        # d+4 EXCEEDS mass at d+2 ⇒ shell_decay < 0 (the "ackley pattern").
        T6(t) = 32t^6 - 48t^4 + 18t^2 - 1
        T8(t) = 128t^8 - 256t^6 + 160t^4 - 32t^2 + 1
        f(x) = 0.5 * T6(x[1]) + 1.0 * T8(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        result = compute_mode_spectrum(sd.polynomial)

        m6 = get(result.shell_mass, 6, 0.0)
        m8 = get(result.shell_mass, 8, 0.0)
        @test m6 > 0
        @test m8 > m6
        @test !isnan(result.shell_decay)
        # 0.5 * log(m6/m8) < 0 since m6 < m8 — stagnant pattern.
        @test result.shell_decay < 0
    end

    @testset "window_coverage: passing rel_l2_squared populates field" begin
        T5(t) = 16t^5 - 20t^3 + 5t
        f(x) = T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        rel² = sd.relative_l2_error^2

        result_no_ref = compute_mode_spectrum(sd.polynomial)
        @test isnan(result_no_ref.window_coverage)

        result_with_ref = compute_mode_spectrum(sd.polynomial; rel_l2_squared = rel²)
        @test isfinite(result_with_ref.window_coverage)
        @test result_with_ref.window_coverage > 0
        # For a function that IS captured by modes ≤ d* = 8, coverage should
        # be in the same ballpark as 1 (modulo LS-vs-CC inner-product mismatch).
        @test 0.05 < result_with_ref.window_coverage < 20.0
    end

    @testset "compute_subdomain_mode_spectrum! passes rel_l2² automatically" begin
        T5(t) = 16t^5 - 20t^3 + 5t
        f(x) = T5(x[1])
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 4, basis = :chebyshev)
        result = compute_subdomain_mode_spectrum!(sd)
        @test isfinite(result.window_coverage)
        @test result.window_coverage > 0
    end
end
