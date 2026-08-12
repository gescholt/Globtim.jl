"""
Test suite for the predicate → cut-axis channel in `adaptive_refine`
(bead 8f4p.5.4).

Before this, a predicate could only return an action Symbol; the split axis was
always chosen by `select_cut_dimension`, which never sees per-axis evidence. So
at `degree == max_degree`, where `:bump` cannot bump and falls through to a
split, the predicate's opinion about WHERE to cut was discarded precisely when
it had one.

`adaptive_refine` now also accepts a `(action, cut_dim)` tuple. These tests pin
both the new behaviour and the backward compatibility of the Symbol contract.
"""

using Test
using Globtim

@testset "predicate cut-dim channel (8f4p.5.4)" begin

    # Anisotropic Runge-type function. It must NOT be polynomial: a degree-4 fit
    # of a low-order polynomial is near-exact, the leaf converges on the L2 gate
    # before any predicate decision matters, and nothing ever splits — which is
    # exactly how the first draft of this file silently tested nothing.
    f = x -> 1.0 / (1.0 + 25.0 * x[1]^2) + 1.0 / (1.0 + x[2]^2)
    bounds = [(-1.0, 1.0), (-1.0, 1.0)]

    "Depth-1 split axis of the root, under the given predicate."
    function first_split_dim(pred)
        tree = adaptive_refine(
            f,
            bounds,
            4;
            enable_p_refinement = true,
            max_degree = 4,          # start AT the cap so the first call splits
            degree_step = 2,
            max_leaves = 4,
            l2_tolerance = 1e-14,    # unreachable ⇒ forces refinement
            tolerance_mode = :relative,
            predicate = pred,
            parallel = false,
        )
        root = tree.subdomains[1]
        return root.split_dim === nothing ? nothing : Int(root.split_dim)
    end

    @testset "Symbol contract still works (backward compatibility)" begin
        # A bare Symbol must behave exactly as before: engine picks the axis.
        d = first_split_dim(_ -> :bump)
        @test d isa Int
        @test d in (1, 2)
    end

    @testset "tuple form routes the predicate's axis into the split" begin
        # Force each axis in turn; the tree must obey, not consult its heuristic.
        @test first_split_dim(_ -> (:bump, 1)) == 1
        @test first_split_dim(_ -> (:bump, 2)) == 2
        @test first_split_dim(_ -> (:split, 1)) == 1
        @test first_split_dim(_ -> (:split, 2)) == 2
    end

    @testset "nothing as cut_dim falls back to the engine's choice" begin
        want = first_split_dim(_ -> :bump)
        @test first_split_dim(_ -> (:bump, nothing)) == want
    end

    @testset "out-of-range hints are ignored, not trusted" begin
        want = first_split_dim(_ -> :bump)
        for bad in (0, 3, -1, 99)
            @test first_split_dim(_ -> (:split, bad)) == want
        end
    end

    @testset ":done still short-circuits from the tuple form" begin
        # ActionConverged must win over any axis hint.
        tree = adaptive_refine(
            f,
            bounds,
            4;
            enable_p_refinement = true,
            max_degree = 4,
            degree_step = 2,
            max_leaves = 8,
            l2_tolerance = 1e-14,
            tolerance_mode = :relative,
            predicate = _ -> (:done, 2),
            parallel = false,
        )
        # Nothing was split: the root is the only leaf and carries no split_dim.
        @test length(tree.subdomains) == 1
        @test tree.subdomains[1].split_dim === nothing
    end
end
