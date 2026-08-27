"""
Tests for the certificate-slack (absolute) leaf-convergence rule — bead dfzo.1
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
