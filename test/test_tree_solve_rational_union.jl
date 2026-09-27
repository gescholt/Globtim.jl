# solve_tree_leaves(tree; rational_types): the union of each leaf's polynomial
# critical points with those of its best certified rational fit (bead 8f4p.7.9)

using Test
using Globtim
using HomotopyContinuation

@testset "solve_tree_leaves rational union" begin
    # a pole just outside the box plus an oscillation
    f(x) = 1 / ((x[1] - 1.15)^2 + (x[2] - 0.3)^2 + 0.04) + sin(3x[1]) * cos(2x[2])
    tree = Globtim.adaptive_refine(f, [(-1.0, 1.0), (-1.0, 1.0)], 6; l2_tolerance = 0.01,
        max_leaves = 8, max_depth = 3, sampling = :christoffel, rng_base_seed = 1,
        parallel = false, verbose = false)
    leaves = Set(vcat(tree.converged_leaves, tree.active_leaves))
    r0 = solve_tree_leaves(tree)
    r1 = solve_tree_leaves(tree; rational_types = [(3, 1), (4, 2)])

    # a superset: every polynomial point is kept, polynomial points first
    @test all(any(maximum(abs.(p .- q)) < 1e-9 for q in r1.critical_points) for p in r0.critical_points)
    @test length(r1.cp_sources) == length(r1.critical_points) == length(r1.cp_leaf_ids)
    @test count(==(:polynomial), r1.cp_sources) == length(r0.critical_points)
    @test all(in(leaves), keys(r1.rational_choice))
    @test any(c !== nothing for c in values(r1.rational_choice))
    for (id, c) in r1.rational_choice
        c === nothing && continue
        @test (c[1], c[2]) in [(3, 1), (4, 2)] && isfinite(c[3])
    end
    # without rational types nothing changes
    @test isempty(r0.rational_choice) && all(==(:polynomial), r0.cp_sources)

    @test_throws ArgumentError solve_tree_leaves(tree; rational_types = [(3, 1)], rational_weights = :foo)
    @test_throws ArgumentError solve_tree_leaves(tree; rational_types = [(3, 1)], rational_holdout = 1.5)
    # rational_fit_on_points: an exact (2,2) rational is recovered from scattered points
    g(x) = (1 + x[1] + x[2]^2) / (2 + x[1]^2 + x[2]^2)
    S = 2 .* rand(Globtim.Random.Xoshiro(3), 60, 2) .- 1
    R = rational_fit_on_points(S, [g(S[i, :]) for i in 1:60], 2, 2)
    @test abs(R([0.3, -0.4]) - g([0.3, -0.4])) < 1e-8
    @test_throws ArgumentError rational_fit_on_points(S[1:5, :], zeros(5), 2, 2)
end
