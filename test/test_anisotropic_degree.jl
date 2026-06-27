using Test
using Globtim
using LinearAlgebra
using Random

# Bead jl9z.7: anisotropic per-dimension degree must SURVIVE the subdivision loop.
#
# The fit / grid / HC layers already accept a per-dim spec `(:one_d_per_dim, [d…])`
# (SupportGen, lambda_vandermonde_anisotropic, the gnua HC fix). The blocker was
# `Subdomain.degree::Int` + the `effective_degree = maximum(...)` collapse in
# process_subdomain, which threw the per-axis budget away at every split. This
# suite pins (a) the new per_dim_degree plumbing, (b) inheritance through splits
# (the regression guard on the collapse), (c) spec partitioning so HC can't
# conflate anisotropic leaves, and (d) the single-box payoff (a sloppy valley
# fit at low degree on the flat axis matches isotropic at far fewer points).

# A sloppy valley: genuinely high-degree along x₁ (exp is non-polynomial), exactly
# degree-2 along x₂. The active axis needs degree; the sloppy axis does not — the
# small-coefficient micro-version of the CR3BP "effectively 2-D" finding.
sloppy(x) = exp(2.0 * x[1]) + 1e-3 * x[2]^2

const _B2 = [(-1.0, 1.0), (-1.0, 1.0)]  # center 0, half 1 ⇒ normalized == physical

# Relative-L2 of a fitted leaf polynomial against `f` on a common hold-out set
# drawn in normalized [-1,1]² coords (== physical here).
function _holdout_relL2(pol, f, pts)
    p = Globtim.evaluate_polynomial_at_samples(pol, pts)
    fv = [f(pts[i, :]) for i = 1:size(pts, 1)]
    return norm(p .- fv) / norm(fv)
end

@testset "anisotropic per-dim degree (jl9z.7)" begin

    @testset "leaf_degree_spec accessor" begin
        iso = Subdomain(_B2; degree = 5)
        @test leaf_degree_spec(iso) == 5                       # isotropic ⇒ scalar
        an = Subdomain(_B2; degree = 6, per_dim_degree = [6, 2])
        @test leaf_degree_spec(an) == (:one_d_per_dim, [6, 2]) # anisotropic ⇒ tuple
    end

    @testset "subdivide_domain inherits per_dim_degree (no aliasing)" begin
        parent = Subdomain(_B2; degree = 6, per_dim_degree = [6, 2])
        l, r = Globtim.subdivide_domain(parent, 1, 0.0)
        @test l.per_dim_degree == [6, 2]
        @test r.per_dim_degree == [6, 2]
        # mutating one child must not touch the parent or the sibling
        l.per_dim_degree[1] = 99
        @test parent.per_dim_degree == [6, 2]
        @test r.per_dim_degree == [6, 2]

        # isotropic parent ⇒ children stay isotropic (nothing)
        piso = Subdomain(_B2; degree = 4)
        li, ri = Globtim.subdivide_domain(piso, 1, 0.0)
        @test li.per_dim_degree === nothing
        @test ri.per_dim_degree === nothing
    end

    @testset "anisotropy survives splits (regression guard on the maximum() collapse)" begin
        # Low degree + tight tolerance + p-refinement off ⇒ the root cannot
        # converge and MUST h-refine. Before the fix the children's per_dim_degree
        # would be nothing (collapsed to a scalar); now they inherit [2,2].
        tree = Globtim.adaptive_refine(
            sloppy,
            _B2,
            (:one_d_per_dim, [2, 2]);
            l2_tolerance = 1e-4,
            tolerance_mode = :absolute,
            max_depth = 5,
            max_leaves = 48,
            enable_p_refinement = false,
            parallel = false,
            verbose = false,
        )
        @test length(tree.subdomains) > 1  # at least one split happened
        leaves = vcat(tree.active_leaves, tree.converged_leaves)
        @test !isempty(leaves)
        for id in leaves
            sd = tree.subdomains[id]
            @test sd.per_dim_degree == [2, 2]   # vector survived the split
            @test sd.degree == 2                # scalar summary = maximum
        end
    end

    @testset "anisotropic leaves carry distinct specs/bases (HC can't conflate)" begin
        a = Subdomain(_B2)
        b = Subdomain(_B2)
        Globtim.estimate_subdomain_error(sloppy, a, (:one_d_per_dim, [6, 6]); basis = :chebyshev)
        Globtim.estimate_subdomain_error(sloppy, b, (:one_d_per_dim, [6, 2]); basis = :chebyshev)
        @test a.polynomial.degree == (:one_d_per_dim, [6, 6])
        @test b.polynomial.degree == (:one_d_per_dim, [6, 2])
        @test a.polynomial.degree != b.polynomial.degree
        # tensor bases differ in size (7·7 vs 7·3) — the gnua HC group_key keys on
        # pol.degree, so these never warm-start from one another.
        @test length(a.polynomial.coeffs) != length(b.polynomial.coeffs)
    end

    @testset "single-box payoff: [6,2] matches iso deg-6 at far fewer points" begin
        Random.seed!(20260627)
        pts = 2.0 .* rand(2000, 2) .- 1.0

        iso = Subdomain(_B2)
        an = Subdomain(_B2)
        Globtim.estimate_subdomain_error(sloppy, iso, 6; basis = :chebyshev)
        Globtim.estimate_subdomain_error(sloppy, an, (:one_d_per_dim, [6, 2]); basis = :chebyshev)

        h_iso = _holdout_relL2(iso.polynomial, sloppy, pts)
        h_an = _holdout_relL2(an.polynomial, sloppy, pts)

        # Fewer ODE-shoots-equivalent: anisotropic tensor grid is smaller.
        @test size(an.samples, 1) < size(iso.samples, 1)
        # Comparable accuracy: dropping the flat axis to degree 2 costs ~nothing
        # (x₂ enters sloppy() exactly at degree 2).
        @test h_an <= 2.0 * h_iso
        @test h_an < 1e-2
    end

    @testset "choose_per_dim_degree_lsfit: contract + ρ_k ordering" begin
        # A leaf with measurable offender mass on BOTH axes but a steeper axis 1
        # (exp(2x) decays slower at finite degree than exp(0.5x)).
        steep_flat(x) = exp(2.0 * x[1]) + exp(0.5 * x[2])
        sd = Subdomain(_B2)
        Globtim.estimate_subdomain_error(steep_flat, sd, 3; basis = :chebyshev)

        d = choose_per_dim_degree_lsfit(sd; c = 4.0, floor_degree = 2, max_degree = 10,
            extended_degree = 6)
        @test length(d) == 2
        @test all(2 .<= d .<= 10)            # clamped into [floor, max]
        @test d[1] >= d[2]                    # steeper axis gets ≥ degree

        # Floor is respected even when the formula would go lower.
        dfloor = choose_per_dim_degree_lsfit(sd; c = 4.0, floor_degree = 5, max_degree = 10,
            extended_degree = 6)
        @test all(dfloor .>= 5)

        # No-signal axis (constant in x₂) → conservative max_degree fallback, not
        # below-floor. (The flat→LOW reduction is Stage 2's active-subspace job.)
        steep_const(x) = exp(2.0 * x[1]) + 0.0 * x[2]
        sc = Subdomain(_B2)
        Globtim.estimate_subdomain_error(steep_const, sc, 3; basis = :chebyshev)
        dc = choose_per_dim_degree_lsfit(sc; c = 4.0, floor_degree = 2, max_degree = 8,
            extended_degree = 6)
        @test dc[2] == 8

        # Misconfigured floor/max raises (no silent clamp swap).
        @test_throws ErrorException choose_per_dim_degree_lsfit(sd; floor_degree = 9,
            max_degree = 4)
    end

    @testset "isotropic call path is unchanged (per_dim_degree stays nothing)" begin
        tree = Globtim.adaptive_refine(
            sloppy,
            _B2,
            4;  # plain scalar degree
            l2_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 4,
            max_leaves = 32,
            parallel = false,
            verbose = false,
        )
        for id in vcat(tree.active_leaves, tree.converged_leaves, tree.pruned_leaves)
            @test tree.subdomains[id].per_dim_degree === nothing
        end
    end
end
