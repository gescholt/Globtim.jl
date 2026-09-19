"""
Tests for the certificate-slack (absolute) leaf-convergence rule
(CS-1 of the CERT-SUBDIV epic).

The pathology being guarded: `tolerance_mode = :relative` normalizes each
leaf's fit error by ‖f‖_L²(leaf). Real objectives carry an evaluation-error
floor η (ODE solver tolerance) that no polynomial degree can fit. On a leaf
where the objective itself sits at that floor (plateaus, valley floors), the
relative error is err/‖f‖ ≈ O(1) FOREVER: the leaf bumps degree to the cap
and splits to max depth, over-refining exactly the flat region where a
high-degree approximant manufactures spurious critical points at the scale
of its own error (‖∇f‖ ≤ ε_C¹ automatically at any CP of the approximant).

The certificate-slack rule is `tolerance_mode = :absolute` with
`l2_tolerance` set to the capture certificate's slack budget (λε²/4-scale):
a flat leaf then converges at low degree — a low-degree polynomial cannot
oscillate — and the spurious accumulation disappears.

Test function: a smooth step with an explicit evaluation floor,
    f(x) = step(x₁)·(1 + x₂²) + 10⁻⁵ sin(137.1 x₁) cos(129.3 x₂),
step(t) = (tanh(6(t − 0.3)) + 1)/2. Left of the step f sits at the 10⁻⁵
floor; the oscillation is unfittable at any tested degree — the honest model
of an ODE-evaluation floor η.
"""

using Test
using Globtim
using HomotopyContinuation

_step(t) = (tanh(30 * (t - 0.3)) + 1) / 2
_floorterm(x) = 1e-5 * sin(137.1 * x[1]) * cos(129.3 * x[2])
_plateau(x) = _step(x[1]) * (1 + x[2]^2) + _floorterm(x)
const _PLATEAU_BOUNDS = [(-1.0, 1.0), (-1.0, 1.0)]

_leafcount(tree) =
    length(tree.active_leaves) + length(tree.converged_leaves) +
    length(tree.pruned_leaves)

function _build(mode, tol)
    return Globtim.adaptive_refine(_plateau, _PLATEAU_BOUNDS, 4;
        l2_tolerance = tol, tolerance_mode = mode,
        enable_p_refinement = true, max_degree = 8, degree_step = 2,
        max_depth = 4, max_leaves = 64,
        optimize_cuts = false, parallel = false, verbose = false)
end

@testset "certificate-slack leaf convergence (CS-1)" begin
    tree_rel = _build(:relative, 1e-2)
    tree_abs = _build(:absolute, 1e-3)

    n_rel = _leafcount(tree_rel)
    n_abs = _leafcount(tree_abs)

    @testset "over-refinement pathology exists in :relative mode" begin
        # plateau leaves sit at the floor: err/||f|| = O(1) can never pass,
        # so refinement runs to the depth/leaf budget and leaves stay
        # unconverged
        @test n_rel > n_abs
        @test !isempty(tree_rel.active_leaves)
    end

    @testset "absolute-slack mode: plateau converges, only the step face works" begin
        @test n_abs <= 16
        # any still-active leaf sits on the step face (genuinely hard region),
        # never on the plateau: plateau leaves (center x1 < 0) all converge
        for id in tree_abs.active_leaves
            @test tree_abs.subdomains[id].center[1] > 0.0
        end
        plateau_ids = [id for id in vcat(tree_abs.active_leaves,
                                         tree_abs.converged_leaves)
                       if tree_abs.subdomains[id].center[1] < 0.0]
        @test !isempty(plateau_ids)
        @test all(id in tree_abs.converged_leaves for id in plateau_ids)
        for id in tree_abs.converged_leaves
            @test tree_abs.subdomains[id].l2_error <= 1e-3
        end
    end

    @testset "the discriminating leaf: slack passes where relative cannot" begin
        # at least one converged leaf of the slack tree satisfies the
        # absolute budget while its RELATIVE error is far above the relative
        # tolerance — the leaf class the relative rule refines forever
        discr = [id for id in tree_abs.converged_leaves
                 if tree_abs.subdomains[id].l2_error <= 1e-3 &&
                    tree_abs.subdomains[id].relative_l2_error > 1e-2]
        @test !isempty(discr)
    end

    @testset "raw critical-point accumulation is reduced" begin
        r_rel = Globtim.solve_tree_leaves(tree_rel)
        r_abs = Globtim.solve_tree_leaves(tree_abs)
        if any(==(Symbol("hc_missing")), values(r_rel.leaf_status))
            @test_skip "HomotopyContinuation not loaded"
        else
            @test length(r_abs.critical_points) <= length(r_rel.critical_points)
        end
    end
end

# =============================================================================
# The MIRROR pathology: a relative gate that stops the tree TOO EARLY.
#
# The CS-1 testset above guards over-refinement — on a plateau at the evaluation
# floor, `err/||f||` stays O(1) forever, so `:relative` splits to the budget. The
# other end of the same normalizer bit us on 2026-09-18: on a SMOOTH objective the
# relative gate is satisfied almost immediately, the tree stops at a handful of
# leaves, and `max_leaves` cannot compensate because it is only a cap — growth is
# emitted exclusively for leaves that FAIL the tolerance. Three LV4D ladder rungs
# asking for 128 / 512 / 2048 leaves all produced the same 3-leaf tree.
#
# Compounding it, `--radius` boxes are centred on `p_true`, and with midpoint cuts
# the first cut on each axis lands exactly ON the minimiser, so it sits on a FACE of
# every leaf at every depth. A leaf whose minimum is on its boundary has a
# near-monotone restriction, which a low-degree fit matches easily (hence the early
# convergence) and whose gradient has no interior zero (hence 0 in-box roots).
# =============================================================================

# The fixture must NOT be exactly fittable, or the whole exercise is vacuous: a
# degree-4 Chebyshev fit reproduces x^2 + y^2 to machine zero, so even
# `l2_tolerance = 1e-12` converges the ROOT box and the tree never splits (measured).
# A smoothed |x| has the same exact minimiser but no finite-degree exact fit, which is
# also the honest analogue of a real objective: an ODE misfit carries a solver-error
# floor (abstol 1e-8) that no degree can fit, and that floor is precisely why an
# unreachable tolerance makes the leaf budget bind.
_smoothabs(c) = x -> sqrt(1e-6 + (x[1] - c)^2) + sqrt(1e-6 + (x[2] - c)^2)
const _SYM_BOUNDS = [(-1.0, 1.0), (-1.0, 1.0)]

"""Smallest distance from `p` to a face of `id`'s box, in half-width units."""
function _face_margin(tree, id, p)
    bb = Globtim.get_bounds(tree.subdomains[id])
    return minimum(min(p[i] - bb[i][1], bb[i][2] - p[i]) /
                   ((bb[i][2] - bb[i][1]) / 2) for i in eachindex(p))
end

_containing(tree, p) = [id for id in vcat(tree.converged_leaves, tree.active_leaves)
                        if (bb = Globtim.get_bounds(tree.subdomains[id]);
                            all(i -> bb[i][1] <= p[i] <= bb[i][2], eachindex(p)))]

function _forced(tol; max_leaves = 64, max_depth = 12, c = 0.0)
    return Globtim.adaptive_refine(_smoothabs(c), _SYM_BOUNDS, 4;
        l2_tolerance = tol, tolerance_mode = :relative,
        enable_p_refinement = false, max_degree = 4,
        max_depth = max_depth, max_leaves = max_leaves,
        optimize_cuts = false, parallel = false, verbose = false)
end

@testset "a relative gate can stop the tree TOO EARLY (LV4D ladder, 2026-09-18)" begin
    @testset "max_leaves is a CAP: a loose gate makes the budget unreachable" begin
        tree = _forced(1e-3; max_leaves = 64)
        # the gate is met after two splits, so the tree stops at a handful of leaves
        # with every one converged -- the bug's exact signature, and the reason three
        # rungs asking for 128 / 512 / 2048 leaves all agreed
        @test _leafcount(tree) < 64
        @test isempty(tree.active_leaves)
        @test !isempty(tree.converged_leaves)
    end

    @testset "an unreachable tolerance makes the budget bind exactly" begin
        tree = _forced(1e-12; max_leaves = 64)
        # nothing can converge, growth is uniform bisection, and the cap fires on a
        # completed level: the T3x regime (0 converged / all active), and the
        # documented way to run a leaf-budget ladder
        @test _leafcount(tree) == 64
        @test isempty(tree.converged_leaves)
        @test length(tree.active_leaves) == 64
        # counts land on powers of two -- which is why a cap of 400 yields 512 and
        # 1200 yields 2048 in the committed corpus: max_leaves is a SOFT cap
        @test ispow2(_leafcount(tree))
    end

    @testset "a minimiser at the box centre lies on a face of EVERY leaf" begin
        # c = 0.0 centres the minimum, exactly what `lb = p_true - r; ub = p_true + r`
        # does; with midpoint cuts the first cut on each axis runs through it
        tree = _forced(1e-12; max_leaves = 64, c = 0.0)
        p = [0.0, 0.0]
        hits = _containing(tree, p)
        @test length(hits) > 1                       # shared across faces, not interior
        @test all(id -> _face_margin(tree, id, p) == 0.0, hits)
    end

    @testset "offsetting the centre makes the minimiser strictly interior" begin
        # the --center-offset fix: 0.137 is non-dyadic, so no midpoint cut at any
        # depth can coincide with it
        tree = _forced(1e-12; max_leaves = 64, c = 0.137)
        p = [0.137, 0.137]
        hits = _containing(tree, p)
        @test length(hits) == 1
        @test _face_margin(tree, only(hits), p) > 0.0
    end
end
