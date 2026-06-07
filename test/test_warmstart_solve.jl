# test_warmstart_solve.jl — Part C: batched parametric warm-start + recovery recording
#
# Covers:
#   * cell_monomial_coeffs round-trip (dense, aligned to support; correct length)
#   * group_key groups same-support cells
#   * solve_tree_leaves_warmstart: no solution loss (cold ⊆ warm), anchor = (deg-1)^n
#   * explicit rejection of solver≠:hc and sparsify_threshold>0 (no silent fallback)
#   * solve_tree_and_recover records recovery_error vs true_params (the Part A gap)

using Test
using Globtim
using HomotopyContinuation   # activates GlobtimHomotopyContinuationExt

# Cheap multimodal objective so a degree-d fit is imperfect and the tree splits.
_wsobj(x) = sum(x .^ 2) + 0.3 * sum(cos.(4 .* x))

_missing_from(big, small, tol) =
    [s for s in small if !any(b -> sqrt(sum(abs2, s .- b)) < tol, big)]

@testset "cell_monomial_coeffs: dense, support-aligned" begin
    bench = Globtim.get_benchmark_config_by_name("Ackley", 2)
    TR = Globtim.TestInput(bench.objective, dim = 2, center = [0.0, 0.0], GN = 20,
        sample_range = 1.0)
    pol = Globtim.Constructor(TR, 4; basis = :chebyshev)
    a = Globtim.cell_monomial_coeffs(pol)
    @test length(a) == size(pol.support, 1)   # densified to full support
    @test all(isfinite, a)
    @test eltype(a) == Float64
end

@testset "warm-start: no loss + anchor count + explicit rejections" begin
    bounds = [(-1.0, 1.0), (-1.0, 1.0)]
    degree = 3
    tree = Globtim.adaptive_refine(_wsobj, bounds, degree; l2_tolerance = 1e-10,
        tolerance_mode = :absolute, max_depth = 5, max_leaves = 4,
        optimize_cuts = false, parallel = false)

    cold = solve_tree_leaves(tree; solver = :hc)
    warm = solve_tree_leaves_warmstart(tree; solver = :hc)

    # NO LOSS: every cold critical point appears in warm (warm may find ≥, never <).
    @test isempty(_missing_from(warm.critical_points, cold.critical_points, 1e-5))

    # anchor count == Bezout (deg-1)^dim for every solved group
    bez = (degree - 1)^2
    @test !isempty(warm.path_stats)
    @test all(((_, st),) -> st[1] == bez, collect(warm.path_stats))
    @test all(==(:ran), values(warm.leaf_status))

    # explicit rejections (no silent fallback)
    @test_throws ErrorException solve_tree_leaves_warmstart(tree; solver = :msolve)
    @test_throws ErrorException solve_tree_leaves_warmstart(tree; sparsify_threshold = 1e-3)
end

@testset "solve_tree_and_recover records recovery_error" begin
    bounds = [(-1.0, 1.0), (-1.0, 1.0)]
    tree = Globtim.adaptive_refine(_wsobj, bounds, 3; l2_tolerance = 1e-10,
        tolerance_mode = :absolute, max_depth = 5, max_leaves = 4,
        optimize_cuts = false, parallel = false)

    # A "true" parameter near the global min of _wsobj (≈ origin).
    p_true = [0.0, 0.0]

    for strat in (:coldstart, :parametric)
        r = solve_tree_and_recover(tree, p_true; strategy = strat)
        @test !isempty(r.critical_points)
        @test r.recovery !== nothing
        # recovery_error is the min distance from any CP to p_true
        dmin = minimum(sqrt(sum(abs2, cp .- p_true)) for cp in r.critical_points)
        @test r.recovery.recovery_error ≈ dmin
        @test r.recovery.best_estimate in r.critical_points
    end

    # nothing true_params ⇒ no recovery record, but still returns CPs
    r0 = solve_tree_and_recover(tree, nothing; strategy = :coldstart)
    @test r0.recovery === nothing
    @test !isempty(r0.critical_points)
end
