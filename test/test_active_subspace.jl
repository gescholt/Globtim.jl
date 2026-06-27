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
