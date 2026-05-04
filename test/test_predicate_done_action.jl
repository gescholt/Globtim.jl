using Test
using Globtim
using Globtim: Subdomain, SubdivisionTree, adaptive_refine, n_leaves

# Tests for the third predicate return value `:done` — short-circuits a leaf
# to ActionConverged from inside the bump branch of process_subdomain.
#
# Motivation (option (b) from the low-start subdivision design discussion):
# starting from low degree and growing on demand requires a way to mark a
# leaf "fit is good enough at this degree" without going through the global
# l2_tolerance gate. The predicate hook already routes :bump vs :split;
# adding :done lets a custom predicate stop refinement on its own terms.
#
# Simple example: f(x) = x[1]^2 + x[2]^2 on [-1,1]^2.
#   - At degree 1, the LSQ residual is large (quadratic ≠ affine).
#   - At degree 2, the fit is exact (residual ≈ roundoff).
#   - With predicate (_) -> :bump, the root leaf bumps 1 → 2 and converges.
#   - With predicate (_) -> :done, the root leaf converges at degree 1.
# The degree of the converged leaf is the test signal.

@testset "predicate :done — short-circuit ActionConverged (subdivision-jrqv)" begin
    f_quad(x) = x[1]^2 + x[2]^2
    bounds = [(-1.0, 1.0), (-1.0, 1.0)]

    common_kwargs = (
        l2_tolerance = 1e-3,
        tolerance_mode = :relative,
        max_depth = 4,
        max_leaves = 16,
        enable_p_refinement = true,
        max_degree = 4,
        degree_step = 1,
        parallel = false,
    )

    @testset ":bump baseline — converges at degree 2 after one bump" begin
        tree = adaptive_refine(f_quad, bounds, 1; common_kwargs..., predicate = (_) -> :bump)
        @test length(tree.converged_leaves) == 1
        @test tree.subdomains[tree.converged_leaves[1]].degree == 2
        @test isempty(tree.active_leaves)
        @test isempty(tree.pruned_leaves)
    end

    @testset ":done — converges at starting degree, no bump, no split" begin
        tree = adaptive_refine(f_quad, bounds, 1; common_kwargs..., predicate = (_) -> :done)
        @test length(tree.converged_leaves) == 1
        @test tree.subdomains[tree.converged_leaves[1]].degree == 1
        @test isempty(tree.active_leaves)
        @test isempty(tree.pruned_leaves)
        # Witness that the leaf was *not* converged via the natural gate:
        # relative_l2_error of a degree-1 fit on x²+y² is well above the 1e-3 tol.
        @test tree.subdomains[tree.converged_leaves[1]].relative_l2_error > 1e-3
    end

    @testset ":done honored at max_degree (no fallback to split)" begin
        # Start already at max_degree; the bump branch would normally fall
        # through to ActionSplit. :done must override that and converge.
        f_smooth(x) = sin(2 * x[1]) * cos(2 * x[2])
        tree = adaptive_refine(
            f_smooth, bounds, 3;
            l2_tolerance = 1e-9,            # tight: would never naturally converge
            tolerance_mode = :relative,
            max_depth = 2, max_leaves = 8,
            enable_p_refinement = true,
            max_degree = 3,                 # already at cap
            degree_step = 1,
            parallel = false,
            predicate = (_) -> :done,
        )
        @test length(tree.converged_leaves) == 1
        @test tree.subdomains[tree.converged_leaves[1]].degree == 3
        @test isempty(tree.active_leaves)
    end

    @testset ":bump regression — default behavior unchanged for non-:done predicates" begin
        # Sanity: nothing in the existing :bump / :split logic moved.
        f_smooth(x) = exp(-(x[1]^2 + x[2]^2))
        tree = adaptive_refine(
            f_smooth, bounds, 4;
            l2_tolerance = 1e-3,
            tolerance_mode = :relative,
            max_depth = 4, max_leaves = 16,
            enable_p_refinement = true,
            max_degree = 10, degree_step = 2,
            parallel = false,
        )
        @test tree isa SubdivisionTree
        @test n_leaves(tree) >= 1
    end
end
