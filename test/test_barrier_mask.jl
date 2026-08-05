using Test
using Globtim

# Bead yhta: penalty/flat-barrier leaf masking in adaptive_subdivision.
#
# An objective that returns a finite penalty PLATEAU over part of the domain
# (e.g. an ODE-shooting objective on unstable-integration corners) creates a
# discontinuous edge. When the edge is NOT axis-aligned, cut optimization cannot
# cleanly isolate it, so the L2 estimator keeps splitting (and, with
# p-refinement, re-fitting higher-degree polynomials on the step) — runaway work
# that never reduces error. The barrier detector marks such leaves `masked` and
# terminates them as pruned: no split, no p-refine, excluded from total_error and
# from the solvable leaf set.

const _PV = 5.0  # finite penalty sentinel (a "barrier" value)

# Smooth bowl with an interior minimum at (-0.5, -0.5); a DIAGONAL barrier covers
# the half-plane x+y > 0.3 with the flat sentinel _PV. The diagonal edge defeats
# axis-aligned cut isolation, reproducing the runaway the bead describes.
function diag_barrier_obj(x)
    (x[1] + x[2] > 0.3) && return _PV
    return (x[1] + 0.5)^2 + (x[2] + 0.5)^2
end

# A barrier-free smooth control: same bowl, no plateau. The detector must NOT
# fire here (acceptance: masking a non-barrier objective changes nothing).
smooth_obj(x) = (x[1] + 0.5)^2 + (x[2] + 0.5)^2

const _BOUNDS = [(-1.0, 1.0), (-1.0, 1.0)]

# Find the leaf whose box contains point p (among converged ∪ active).
function _leaf_containing(tree, p)
    for id in vcat(tree.converged_leaves, tree.active_leaves)
        sd = tree.subdomains[id]
        if all(
            abs(p[d] - sd.center[d]) <= sd.half_widths[d] + 1e-9 for d = 1:length(p)
        )
            return id
        end
    end
    return nothing
end

@testset "barrier masking (yhta)" begin

    @testset "penalty_barrier_detector unit behavior" begin
        det = penalty_barrier_detector(_PV)               # frac = 0.5 default
        @test det([_PV, _PV, _PV, 0.1]) == true            # 3/4 ≥ 0.5
        @test det([_PV, 0.1, 0.2, 0.3]) == false           # 1/4 < 0.5
        @test det([_PV, _PV, 0.1, 0.2]) == true            # 2/4 ≥ 0.5
        @test det(Float64[]) == false                      # empty → never a barrier
        @test det([0.1, 0.2, 0.3]) == false                # none at sentinel

        det9 = penalty_barrier_detector(_PV; frac = 0.9)
        @test det9([_PV, _PV, _PV, 0.1]) == false          # 0.75 < 0.9
        @test det9([_PV, _PV, _PV, _PV]) == true

        # near-equality respects rtol
        det_rt = penalty_barrier_detector(_PV; rtol = 1e-2)
        @test det_rt([5.01, 5.0, 0.0, 0.0]) == true        # both ≈ 5 within 1%
        @test_throws ErrorException penalty_barrier_detector(_PV; frac = 0.0)
    end

    @testset "flat_barrier_detector unit behavior" begin
        flat = flat_barrier_detector()
        @test flat(fill(3.0, 8)) == true                   # perfectly constant
        @test flat([1.0, 2.0, 3.0, 4.0]) == false          # varied
        @test flat([2.5]) == false                         # too few samples
    end

    @testset "detector masks barrier leaves; baseline over-subdivides" begin
        common = (
            l2_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 6,
            max_leaves = 64,
            parallel = false,
            basis = :chebyshev,
            verbose = false,
        )

        baseline = Globtim.adaptive_refine(diag_barrier_obj, _BOUNDS, 4; common...)
        det = penalty_barrier_detector(_PV)
        masked = Globtim.adaptive_refine(
            diag_barrier_obj,
            _BOUNDS,
            4;
            barrier_detector = det,
            common...,
        )

        # Baseline (no detector) never masks anything.
        @test Globtim.n_masked(baseline) == 0

        # With the detector, barrier leaves get masked …
        @test Globtim.n_masked(masked) > 0
        # … and masking strictly trims the tree vs the baseline runaway.
        @test Globtim.n_leaves(masked) < Globtim.n_leaves(baseline)

        # Masked leaves live in pruned_leaves, carry the flag, and are NOT in the
        # solvable set (converged ∪ active) — so they yield no spurious CPs.
        solvable = Set(vcat(masked.converged_leaves, masked.active_leaves))
        masked_ids = [id for id in masked.pruned_leaves if masked.subdomains[id].masked]
        @test !isempty(masked_ids)
        for id in masked_ids
            sd = masked.subdomains[id]
            @test sd.masked
            @test !(id in solvable)
            # the leaf really is a penalty plateau
            @test sd.f_values !== nothing
            @test count(v -> isapprox(v, _PV; rtol = 1e-3), sd.f_values) /
                  length(sd.f_values) >= 0.5
        end

        # total_error excludes masked leaves (it sums only active ∪ converged),
        # so it stays finite and is not polluted by the plateau.
        @test isfinite(Globtim.total_error(masked))

        # The interior feasible minimum is preserved: the leaf covering (-0.5,-0.5)
        # converged, is not masked, and fits well.
        fid = _leaf_containing(masked, [-0.5, -0.5])
        @test fid !== nothing
        @test !masked.subdomains[fid].masked
        @test fid in masked.converged_leaves
        @test masked.subdomains[fid].l2_error < 1e-2
    end

    @testset "masking holds under p-refinement (the timeout trigger)" begin
        # With enable_p_refinement the bead's runaway is worst (degree bumps on a
        # step). The detector must still bound the tree and mask the plateau.
        det = penalty_barrier_detector(_PV)
        tree = Globtim.adaptive_refine(
            diag_barrier_obj,
            _BOUNDS,
            4;
            barrier_detector = det,
            enable_p_refinement = true,
            max_degree = 12,
            degree_step = 2,
            l2_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 6,
            max_leaves = 64,
            parallel = false,
            verbose = false,
        )
        @test Globtim.n_masked(tree) > 0
        @test Globtim.n_leaves(tree) <= 64
    end

    @testset "detector is a no-op on a barrier-free objective" begin
        det = penalty_barrier_detector(_PV)
        with_det = Globtim.adaptive_refine(
            smooth_obj,
            _BOUNDS,
            4;
            barrier_detector = det,
            l2_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 5,
            max_leaves = 32,
            parallel = false,
            verbose = false,
        )
        # No sample ever hits the sentinel ⇒ nothing masked, behavior unchanged.
        @test Globtim.n_masked(with_det) == 0
    end
end
