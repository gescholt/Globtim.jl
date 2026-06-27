using Test
using Globtim
using Globtim: Subdomain, estimate_subdomain_error, subdivide_domain, get_bounds,
    detect_degeneracy!, pick_cut_direction_spectrum, _frame_from_normal,
    solve_and_transform
using LinearAlgebra
using HomotopyContinuation  # loads the HC extension for the lift-back round-trip

# Stage 3: oblique fold-aligned cuts (generalize pick_cut_dim_spectrum from
# best-AXIS to best-DIRECTION), plus the Stage 2b rotation-aware CP lift-back.
# A fold/crease along a non-axis hyperplane can't be cleanly isolated by an
# axis-aligned cut; rotating the leaf so the fold normal is box-axis 1 and cutting
# axis 1 slices perpendicular to the crease, leaving each child smooth.

@testset "oblique fold-aligned cuts (Stage 3)" begin

    @testset "_frame_from_normal builds an orthonormal frame on the normal" begin
        a = [1.0, 0.6, -0.3]
        Q = _frame_from_normal(a)
        @test size(Q) == (3, 3)
        @test Q' * Q ≈ I(3) atol = 1e-10                  # orthonormal
        @test Q[:, 1] ≈ a ./ norm(a) atol = 1e-10         # first column is the normal
        @test_throws ErrorException _frame_from_normal(zeros(3))
    end

    @testset "pick_cut_direction_spectrum falls back to the axis selector" begin
        # A smooth, well-fit leaf has no fold verdict ⇒ axis-aligned (nothing frame),
        # and the chosen dim matches pick_cut_dim_spectrum.
        f(z) = z[1]^2 + 0.5 * z[2]^2
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 6; basis = :chebyshev)
        detect_degeneracy!(sd)
        dim, Q = pick_cut_direction_spectrum(sd)
        @test Q === nothing
        @test dim == Globtim.pick_cut_dim_spectrum(sd)
    end

    @testset "a coherent oblique fold ⇒ cut along its normal" begin
        a = normalize([1.0, 0.6])
        f(z) = abs(dot(a, z))                              # crease along aᵀz = 0
        sd = Subdomain([(-1.0, 1.0), (-1.0, 1.0)])
        estimate_subdomain_error(f, sd, 5; basis = :chebyshev)
        diag = detect_degeneracy!(sd)
        @test diag.verdict == :fold_caustic
        dim, Q = pick_cut_direction_spectrum(sd)
        @test dim == 1
        @test Q !== nothing
        @test abs(dot(Q[:, 1], a)) > 0.85                 # cut normal ≈ fold normal
    end

    @testset "oblique cut beats the best axis cut on combined child error" begin
        a = normalize([1.0, 0.6])
        f(z) = abs(dot(a, z))
        B = [(-1.0, 1.0), (-1.0, 1.0)]

        # Best axis cut (oblique to the fold ⇒ both children straddle the crease).
        sd = Subdomain(B)
        estimate_subdomain_error(f, sd, 5; basis = :chebyshev)
        ax = Globtim.pick_cut_dim_spectrum(sd)
        l, r = subdivide_domain(sd, ax, 0.0)
        estimate_subdomain_error(f, l, 5; basis = :chebyshev)
        estimate_subdomain_error(f, r, 5; basis = :chebyshev)
        axis_combined = l.relative_l2_error + r.relative_l2_error

        # Fold-aligned cut: rotate so axis 1 = fold normal, cut axis 1 ⇒ each child
        # is on one smooth side of the crease (f is linear there).
        Q = _frame_from_normal(a)
        sdo = Subdomain(B; transform = Q)
        estimate_subdomain_error(f, sdo, 5; basis = :chebyshev)
        lo, ro = subdivide_domain(sdo, 1, 0.0)
        estimate_subdomain_error(f, lo, 5; basis = :chebyshev)
        estimate_subdomain_error(f, ro, 5; basis = :chebyshev)
        obl_combined = lo.relative_l2_error + ro.relative_l2_error

        @test obl_combined < 0.5 * axis_combined          # slicing the crease wins decisively
        @test obl_combined < 1e-3                          # each side fits ~exactly
    end

    @testset "Stage 2b: rotation-aware CP lift-back round-trips (HC)" begin
        # A paraboloid with a known interior minimum; fit over a ROTATED leaf, solve
        # ∇p=0 in the rotated frame, and lift back through Q. The recovered physical
        # CP must equal the planted minimum — and the lift-back must apply Q (a Q=I
        # lift would land on the wrong point).
        m = [0.3, -0.2]
        f(z) = (z[1] - m[1])^2 + (z[2] - m[2])^2
        B = [(-1.0, 1.0), (-1.0, 1.0)]
        Q = _frame_from_normal(normalize([1.0, 0.5]))
        sd = Subdomain(B; transform = Q)
        estimate_subdomain_error(f, sd, 2; basis = :chebyshev)

        cps_Q, _ = solve_and_transform(sd.polynomial, get_bounds(sd); solver = :hc,
            transform = sd.transform)
        @test length(cps_Q) >= 1
        @test minimum(norm(c .- m) for c in cps_Q) < 1e-6          # correct lift-back

        # Lifting the SAME rotated-frame polynomial as if axis-aligned misses m.
        cps_I, _ = solve_and_transform(sd.polynomial, get_bounds(sd); solver = :hc,
            transform = nothing)
        @test minimum(norm(c .- m) for c in cps_I) > 1e-3          # Q≠I genuinely matters
    end
end
