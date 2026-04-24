"""
Tests for the sparsification polynomial-equality short-circuit (bead oasi).

Regression guards:
- sparsify_polynomial returns `n_zeroed::Int`.
- When a threshold zeros no coefficients, the sweep marks the variant
  `cached_hit=true`, copies the full-solve CPs, and reports solve_time = 0.0.
- When a threshold does zero coefficients, the variant is a normal HC solve
  and cached_hit=false.
"""

using Test
using Globtim

@testset "Sparsification cached-hit short-circuit" begin
    TR = Globtim.TestInput(
        x -> (x[1] - 0.3)^2 + (x[2] - 0.1)^2;
        dim = 2, center = [0.0, 0.0], GN = 12, sample_range = [1.0, 1.0],
    )
    pol = Globtim.Constructor(TR, 4; basis = :chebyshev, normalized = false)

    @testset "sparsify_polynomial returns n_zeroed" begin
        r_tiny = Globtim.sparsify_polynomial(pol, 1e-20; mode = :relative)
        @test hasproperty(r_tiny, :n_zeroed)
        @test r_tiny.n_zeroed == 0  # threshold below every coefficient

        r_big = Globtim.sparsify_polynomial(pol, 0.5; mode = :relative)
        @test r_big.n_zeroed > 0
        @test r_big.n_zeroed == length(r_big.zeroed_indices)
    end

    @testset "run_sparsification_experiment marks cached hits" begin
        results = Globtim.run_sparsification_experiment(
            objective = x -> (x[1] - 0.3)^2 + (x[2] - 0.1)^2,
            bounds = [(-1.0, 1.0), (-1.0, 1.0)],
            degree_range = [4],
            thresholds = [1e-20, 1e-18],  # both subthreshold
            threshold_labels = ["tiny1", "tiny2"],
            GN = 12,
        )
        dr = results[1]
        @test length(dr.variants) == 2
        for v in dr.variants
            @test v.cached_hit == true
            @test v.n_zeroed == 0
            @test v.solve_time == 0.0
            @test v.critical_points == dr.full_critical_points
        end
    end

    @testset "real-sparsification variant is not cached" begin
        # Use a richer Chebyshev spectrum so moderate sparsification retains
        # enough structure for HC to solve (the bare quadratic above degenerates
        # the gradient system — classic xosc territory).
        f = x -> 0.3 * cos(2 * x[1]) + 0.2 * sin(2 * x[2]) + 0.1 * x[1] * x[2]
        results = Globtim.run_sparsification_experiment(
            objective = f,
            bounds = [(-1.0, 1.0), (-1.0, 1.0)],
            degree_range = [6],
            thresholds = [1e-4],   # moderate — zeros ~70% on this problem
            threshold_labels = ["moderate"],
            GN = 16,
        )
        v = results[1].variants[1]
        @test v.cached_hit == false
        @test v.n_zeroed > 0
        @test v.solve_time > 0.0
    end
end
