using Test
using Globtim

# Track how many times the objective is called so we can verify that
# inheritance actually skips f-evaluations on the inherited rows.
mutable struct EvalCounter
    n::Int
    f::Function
end
(c::EvalCounter)(x) = (c.n += 1; c.f(x))

@testset "y0j integration: estimate_subdomain_error inherit_from" begin
    # A smooth objective so the fit is stable at modest degree.
    f_quad = x -> sum(x.^2) + x[1] * x[2]

    @testset "no inherit_from → same call count as before" begin
        parent = Globtim.Subdomain([0.0, 0.0], [1.0, 1.0]; degree=4)
        counter = EvalCounter(0, f_quad)
        l2 = Globtim.estimate_subdomain_error(counter, parent, 4, basis=:chebyshev)
        @test counter.n > 0
        @test isfinite(l2)
        # Baseline: 2*degree+1 = 9 per dim, 81 samples in 2D.
        @test counter.n == 81
    end

    @testset "inherit_from with no overlap: falls back to full eval" begin
        # Two non-overlapping boxes: parent covers x ∈ [-1,0]; child covers [5,6].
        # No parent point remaps into the child → no savings, same n_fresh evals.
        parent = Globtim.Subdomain([-0.5, 0.0], [0.5, 1.0]; degree=4)
        Globtim.estimate_subdomain_error(f_quad, parent, 4, basis=:chebyshev)

        far_child = Globtim.Subdomain([5.5, 0.0], [0.5, 1.0]; degree=4)
        counter = EvalCounter(0, f_quad)
        Globtim.estimate_subdomain_error(counter, far_child, 4,
                                         basis=:chebyshev, inherit_from=parent)
        @test counter.n == 81
    end

    @testset "inherit_from with full overlap: inherits rows into sample matrix" begin
        # Parent at higher GN so many of its samples remap into the child after
        # a bisection. Use n_samples_per_dim to force a dense parent grid, then
        # bisect in dim 1 at the midpoint and let the child inherit.
        parent = Globtim.Subdomain([0.0, 0.0], [1.0, 1.0]; degree=4)
        Globtim.estimate_subdomain_error(f_quad, parent, 4,
                                         basis=:chebyshev, n_samples_per_dim=15)
        parent_samples = size(parent.samples, 1)
        @test parent_samples == 225  # 15×15

        # Left child = [-1, 0] × [-1, 1] in parent coords.
        left = Globtim.Subdomain([-0.5, 0.0], [0.5, 1.0]; degree=4)
        counter = EvalCounter(0, f_quad)
        l2 = Globtim.estimate_subdomain_error(counter, left, 4,
                                              basis=:chebyshev,
                                              inherit_from=parent)
        # The child runs its own 9×9 = 81 fresh Chebyshev grid and additionally
        # picks up parent samples that remap inside its box. First-kind
        # Chebyshev nodes at different N generally do not coincide under an
        # affine remap, so the savings show up as inherited rows appended to
        # the sample matrix (their f-values are copied from the parent cache
        # and don't count against counter.n), not as dropped fresh rows.
        @test size(left.samples, 1) > 81            # inherited rows were appended
        @test counter.n ≤ 81                         # no more than the fresh grid
        @test counter.n > 0
        @test isfinite(l2)
    end

    @testset "inherit_from preserves fit accuracy" begin
        # Polynomial fit on combined (inherited + fresh) should still converge.
        # Compare against a from-scratch fit — L2 error order of magnitude
        # should match, since the fit is least-squares and the combined sample
        # set is a superset of the fresh grid's coordinate coverage.
        parent = Globtim.Subdomain([0.0, 0.0], [1.0, 1.0]; degree=4)
        Globtim.estimate_subdomain_error(f_quad, parent, 4, basis=:chebyshev)

        left_fresh = Globtim.Subdomain([-0.5, 0.0], [0.5, 1.0]; degree=4)
        l2_fresh = Globtim.estimate_subdomain_error(f_quad, left_fresh, 4, basis=:chebyshev)

        left_inherit = Globtim.Subdomain([-0.5, 0.0], [0.5, 1.0]; degree=4)
        l2_inherit = Globtim.estimate_subdomain_error(f_quad, left_inherit, 4,
                                                     basis=:chebyshev,
                                                     inherit_from=parent)

        # Both should be finite and small for this quadratic-ish objective.
        @test isfinite(l2_fresh)
        @test isfinite(l2_inherit)
        # The inheritance path uses a richer sample set, so the LS residual
        # should be within 10× of the clean Chebyshev fit.
        rel = l2_inherit / max(l2_fresh, 1e-12)
        @test rel < 10.0
    end
end

@testset "y0j integration: process_subdomain wires parent into inherit_from" begin
    f = x -> sum(x.^2)

    tree = Globtim.SubdivisionTree([(-1.0, 1.0), (-1.0, 1.0)]; degree=4)
    root_id = 1

    # Process the root: populates parent.samples/f_values.
    Globtim.process_subdomain(f, tree, root_id, 4, 1e-12)  # strict tol forces Split or Bump
    parent = tree.subdomains[root_id]
    @test parent.samples !== nothing
    @test parent.f_values !== nothing

    # Manually add a child to the tree so process_subdomain can resolve its
    # parent_id lookup. Do NOT go through update_tree! here to keep the test
    # focused on the inheritance hookup.
    child_left, child_right = Globtim.subdivide_domain(parent, 1, 0.0)
    child_left.parent_id = root_id
    push!(tree.subdomains, child_left)
    child_id = length(tree.subdomains)
    push!(tree.active_leaves, child_id)

    counter = EvalCounter(0, f)
    Globtim.process_subdomain(counter, tree, child_id, 4, 1e-12)

    # With inheritance on by default, the child's sample matrix must be larger
    # than its fresh 9×9 grid because inherited rows from the parent cache are
    # appended. Fresh eval count stays ≤ 81 (inherited rows skip f-evals).
    child = tree.subdomains[child_id]
    @test counter.n > 0
    @test counter.n ≤ 81
    @test size(child.samples, 1) > 81

    # Now rerun with reuse_parent_samples=false to confirm the opt-out path
    # still works. We need a fresh child subdomain because the prior call
    # cached samples.
    child_left_fresh, _ = Globtim.subdivide_domain(parent, 1, 0.0)
    child_left_fresh.parent_id = root_id
    push!(tree.subdomains, child_left_fresh)
    fresh_id = length(tree.subdomains)
    push!(tree.active_leaves, fresh_id)

    counter_off = EvalCounter(0, f)
    Globtim.process_subdomain(counter_off, tree, fresh_id, 4, 1e-12;
                              reuse_parent_samples=false)
    @test counter_off.n == 81
end
