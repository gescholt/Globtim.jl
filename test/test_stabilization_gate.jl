# test_stabilization_gate.jl — Part B: relative-L2 stagnation gate (opt-in, default off)
#
# Covers:
#   * the reused EnhancedMetrics.detect_stagnation primitive (plateau vs steady decrease)
#   * collect_stabilized_leaves snapshots the solvable leaf set
#   * adaptive_refine knob-OFF ≡ legacy (identical tree), knob-ON never adds leaves
#     and can stop early
#   * Constructor accepts the new kwargs and still returns a valid ApproxPoly

using Test
using Globtim

leafcount(tree) = length(vcat(tree.converged_leaves, tree.active_leaves))

@testset "detect_stagnation primitive" begin
    ds = Globtim.EnhancedMetrics.detect_stagnation
    # last 3 relative improvements (0.004, 0.0020, 0.0010) all strictly < 0.01 ⇒ stagnated
    @test ds([1.0, 0.5, 0.498, 0.497, 0.4965], 0.01) == true
    # steady halving ⇒ 50% improvement each step ⇒ NOT stagnated
    @test ds([1.0, 0.5, 0.25, 0.125, 0.0625], 0.01) == false
    # too few points ⇒ false (needs ≥3)
    @test ds([1.0, 0.9], 0.01) == false
end

@testset "adaptive_refine: knob-off ≡ legacy, knob-on never adds leaves" begin
    bench = Globtim.get_benchmark_config_by_name("Ackley", 2)
    f = bench.objective
    bounds = [(-2.0, 2.0), (-2.0, 2.0)]
    deg = 4

    # Tight absolute tolerance it can't meet ⇒ keeps splitting until max_leaves.
    common = (; l2_tolerance = 1e-10, tolerance_mode = :absolute, max_depth = 6,
        max_leaves = 40, optimize_cuts = false, parallel = false, basis = :chebyshev)

    tree_legacy = Globtim.adaptive_refine(f, bounds, deg; common...)
    tree_off = Globtim.adaptive_refine(f, bounds, deg; common..., stagnation_stop = false)
    tree_on = Globtim.adaptive_refine(f, bounds, deg; common...,
        stagnation_stop = true, stagnation_threshold = 0.1)

    # knob-off (explicit) must reproduce the legacy (no-kwarg) tree exactly —
    # tensor sampling is deterministic, so leaf counts match.
    @test leafcount(tree_off) == leafcount(tree_legacy)
    # knob-on can only stop earlier (or equal); it must never create MORE leaves.
    @test leafcount(tree_on) <= leafcount(tree_legacy)
end

@testset "collect_stabilized_leaves snapshots solvable leaves" begin
    bench = Globtim.get_benchmark_config_by_name("Ackley", 2)
    f = bench.objective
    bounds = [(-2.0, 2.0), (-2.0, 2.0)]
    tree = Globtim.adaptive_refine(f, bounds, 4; l2_tolerance = 1e-10,
        tolerance_mode = :absolute, max_depth = 5, max_leaves = 16,
        optimize_cuts = false, parallel = false)

    leaves = collect_stabilized_leaves(tree)
    # one entry per solvable (non-nothing-polynomial) leaf in converged ∪ active
    n_solvable = count(
        id -> tree.subdomains[id].polynomial !== nothing,
        vcat(tree.converged_leaves, tree.active_leaves),
    )
    @test length(leaves) == n_solvable
    @test all(l -> l isa StabilizedLeaf, leaves)
    @test all(l -> length(l.bounds) == 2, leaves)
    @test all(l -> l.polynomial isa Globtim.ApproxPoly, leaves)
end

@testset "Constructor accepts stagnation kwargs and returns a valid poly" begin
    f = x -> sum(x .^ 2)
    TR = Globtim.TestInput(f, dim = 2, center = [0.0, 0.0], GN = 20, sample_range = 1.0)
    # GN is an Int here ⇒ single-degree path; kwargs must be accepted regardless.
    p = Globtim.Constructor(TR, 4; stagnation_stop = true, stagnation_threshold = 0.05)
    @test p isa Globtim.ApproxPoly
    @test isfinite(p.nrm)
end
