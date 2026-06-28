using Test
using Globtim
using LinearAlgebra

# Stage 2: active-subspace ROTATION. The gradient-covariance eigenbasis recovers
# the (possibly oblique) active direction; rotating the box frame to it lets an
# anisotropic degree budget [d, floor, …] target the now-axis-aligned hard
# direction. Coverage caveat: a rotated hyperrectangle covers a rotated region, so
# each fit is scored on its OWN box (no shared-domain confound) — the claim is that
# the SAME cheap budget succeeds in the aligned frame and fails axis-aligned.

# A fixed orthonormal rotation (deterministic; no RNG).
const _R = Matrix(qr([1.0 0.4 0.2; -0.3 1.0 0.5; 0.1 -0.2 1.0]).Q)
const _B3 = [(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]

# Hard (non-polynomial) along R[:,1]; nearly flat along R[:,2], R[:,3].
_tilted(z) = exp(2.0 * dot(_R[:, 1], z)) + 1e-3 * (dot(_R[:, 2], z)^2 + dot(_R[:, 3], z)^2)

# Hold-out rel-L2 of a fitted leaf over ITS OWN box: sample ẑ∈[-1,1]³, map to
# physical via the leaf's frame, compare p(ẑ) to f(physical).
function _holdout(sd, f, Ẑ)
    p = Globtim.evaluate_polynomial_at_samples(sd.polynomial, Ẑ)
    x = Vector{Float64}(undef, size(Ẑ, 2))
    fv = similar(p)
    for i in 1:size(Ẑ, 1)
        Globtim.box_to_physical!(x, view(Ẑ, i, :), sd)
        fv[i] = f(x)
    end
    return norm(p .- fv) / norm(fv)
end

@testset "active-subspace rotation (Stage 2)" begin

    @testset "_validate_transform raises on a bad frame" begin
        @test_throws ErrorException Globtim._validate_transform(zeros(3, 3), 3)      # not orthonormal
        @test_throws ErrorException Globtim._validate_transform(Matrix(I, 2, 2) * 1.0, 3)  # wrong size
        Globtim._validate_transform(Matrix{Float64}(I, 3, 3), 3)                     # identity ok (no throw)
        Globtim._validate_transform(_R, 3)                                           # a real rotation ok
        @test true
    end

    @testset "gradient_covariance recovers the oblique active direction (A1)" begin
        sd = Subdomain(_B3)                         # axis-aligned
        C = gradient_covariance(_tilted, sd; n_cells = 7, h = 0.005)
        Q, frac, _ = active_subspace(C)
        @test abs(dot(Q[:, 1], _R[:, 1])) > 0.95    # leading eigenvector ≈ R[:,1]
        @test frac[1] > 0.8                         # energy concentrated on it
    end

    @testset "anisotropic_degree_from_spectrum: floor + active_cum (A3)" begin
        # [72, 21, 6, 0.7, 0.4]% — the CR3BP-shaped spectrum.
        λ = [0.72, 0.21, 0.06, 0.007, 0.004]
        @test anisotropic_degree_from_spectrum(λ, 6; floor_deg = 2, active_cum = 0.90) ==
              [6, 6, 2, 2, 2]                        # proven pattern at 0.90
        @test anisotropic_degree_from_spectrum(λ, 6; floor_deg = 2, active_cum = 0.95) ==
              [6, 6, 6, 2, 2]                        # top-3 at 0.95
        @test all(anisotropic_degree_from_spectrum(λ, 6; floor_deg = 3) .>= 3)  # floor honored
        @test_throws ErrorException anisotropic_degree_from_spectrum(λ, 4; floor_deg = 9)
    end

    @testset "spectral_effective_dimension: threshold-free, gap-aware (A5)" begin
        # A clean 2-D structure (a decisive cliff after the 2nd eigenvalue): the
        # participation ratio, the gap, and the round all agree ⇒ unambiguous.
        clean = spectral_effective_dimension([0.7, 0.29, 0.005, 0.005])
        @test 1.6 < clean.participation < 1.9
        @test clean.n_round == 2
        @test clean.gap_dim == 2
        @test clean.gap_dominance > 1.5
        @test clean.ambiguous == false

        # The CR3BP-shaped spectrum [72,21,6,0.7,0.4]%: the participation ratio reads
        # ~1.8 (→2) but the largest multiplicative gap is after the 3rd direction
        # (→3). The estimators DISAGREE ⇒ flagged ambiguous. This is exactly the
        # "effectively 2- or 3-D?" tension the fixed cumulative cutoff hid.
        cr3bp = spectral_effective_dimension([0.72, 0.21, 0.06, 0.007, 0.004])
        @test 1.6 < cr3bp.participation < 1.9
        @test cr3bp.n_round == 2
        @test cr3bp.gap_dim == 3
        @test cr3bp.ambiguous == true

        # A sloppy geometric ramp (each eigenvalue half the previous): every step
        # drops by the SAME factor ⇒ no decisive gap (dominance ≈ 1) ⇒ ambiguous.
        # This is the parameter-estimation-sloppiness regime where no integer
        # effective dimension is meaningful.
        sloppy = spectral_effective_dimension([1.0, 0.5, 0.25, 0.125, 0.0625])
        @test sloppy.gap_dominance < 1.2
        @test sloppy.ambiguous == true

        # A single dominant direction: unambiguously 1-D.
        one = spectral_effective_dimension([1.0, 0.0, 0.0])
        @test one.n_round == 1
        @test one.ambiguous == false

        # Estimators are bracketed by [1, n] and entropy tracks participation on the
        # clean case.
        @test 1.0 <= clean.entropy <= 4.0
        @test abs(clean.entropy - clean.participation) < 0.5
    end

    @testset "anisotropic_degree_from_spectrum: explicit n_active override (A6)" begin
        λ = [0.72, 0.21, 0.06, 0.007, 0.004]
        # n_active makes the active/sloppy split explicit (no energy-cutoff guessing):
        @test anisotropic_degree_from_spectrum(λ, 6; floor_deg = 2, n_active = 2) ==
              [6, 6, 2, 2, 2]
        @test anisotropic_degree_from_spectrum(λ, 6; floor_deg = 2, n_active = 3) ==
              [6, 6, 6, 2, 2]
        @test anisotropic_degree_from_spectrum(λ, 6; floor_deg = 2, n_active = 0) ==
              [2, 2, 2, 2, 2]
        # Driven by the adaptive rank, it reproduces the proven CR3BP pattern with no
        # threshold at all.
        r = spectral_effective_dimension(λ).n_round
        @test anisotropic_degree_from_spectrum(λ, 6; floor_deg = 2, n_active = r) ==
              [6, 6, 2, 2, 2]
    end

    @testset "non-finite gradients are dropped, not poisoned (hardening, A7)" begin
        # Real ODE losses return Inf/NaN on infeasible inputs; those cells must be
        # dropped (with a warning) so eigen(C) does not choke, NOT silently averaged.
        sd = Subdomain(_B3)
        finf(x) = x[1] > 0.0 ? Inf : exp(x[1]) + 1e-3 * (x[2]^2 + x[3]^2)
        C = @test_logs (:warn,) match_mode = :any gradient_covariance(finf, sd;
            n_cells = 4, h = 0.01)
        @test all(isfinite, C)
        @test issymmetric(C)
        _, frac, _ = active_subspace(C)            # eigen must not choke
        @test all(isfinite, frac)

        # Every cell non-finite ⇒ raises (no usable signal, no silent fallback).
        @test_throws ErrorException gradient_covariance(x -> Inf, sd; n_cells = 3)

        # rotate_to_active_frame! surfaces the drop counts programmatically.
        sd2 = Subdomain(_B3)
        info = rotate_to_active_frame!(finf, sd2; n_cells = 4, h = 0.01)
        @test info.n_dropped > 0
        @test info.n_used > 0
        @test info.n_used + info.n_dropped == 4^3
    end

    @testset "rotation lets a cheap budget capture the hard direction (A2)" begin
        Ẑ = let g = range(-0.95, 0.95; length = 9)
            collect(reduce(vcat, ([a b c] for a in g, b in g, c in g)))
        end

        # Rotated frame: rotate_to_active_frame! aligns axis 1 with R[:,1] and sets
        # per_dim_degree from the spectrum (≈[6,2,2] — exp dominates).
        sd_rot = Subdomain(_B3)
        info = rotate_to_active_frame!(_tilted, sd_rot; n_cells = 7, h = 0.005,
            deg_max = 6, floor_deg = 2, active_cum = 0.90)
        @test info.degrees[1] == 6
        @test all(info.degrees[2:end] .== 2)
        Globtim.estimate_subdomain_error(_tilted, sd_rot, leaf_degree_spec(sd_rot);
            basis = :chebyshev)
        h_rot = _holdout(sd_rot, _tilted, Ẑ)

        # Axis-aligned frame, SAME budget [6,2,2]: the hard direction is oblique, so
        # axes 2,3 at degree 2 cannot resolve it.
        sd_axis = Subdomain(_B3)
        Globtim.estimate_subdomain_error(_tilted, sd_axis, (:one_d_per_dim, [6, 2, 2]);
            basis = :chebyshev)
        h_axis = _holdout(sd_axis, _tilted, Ẑ)

        @test h_rot < 0.1 * h_axis     # aligning the budget with the active axis wins big
        @test h_rot < 1e-2             # and is genuinely accurate
    end

    @testset "identity transform == axis-aligned (byte-identical default, A4)" begin
        sd0 = Subdomain(_B3)                                   # transform = nothing
        sdI = Subdomain(_B3; transform = Matrix{Float64}(I, 3, 3))  # explicit identity
        Globtim.estimate_subdomain_error(_tilted, sd0, 4; basis = :chebyshev)
        Globtim.estimate_subdomain_error(_tilted, sdI, 4; basis = :chebyshev)
        @test sd0.l2_error ≈ sdI.l2_error rtol = 1e-12
        @test sd0.samples ≈ sdI.samples
    end
end
