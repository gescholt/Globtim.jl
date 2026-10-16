# N5 surrogate-side deduplication (surrogate_dedup.jl): Newton polish on the surrogate,
# clustering with membership, and the pipeline's cluster columns in the raw CSV.

using Test
using Globtim
using LinearAlgebra
using CSV, DataFrames

ENV["GLOBTIM_LEDGER_APPEND"] = "0"   # the pipeline runs below write no central-ledger row

@testset "surrogate dedup" begin
    @testset "cluster_points membership" begin
        pts = [[0.0, 0.0], [1.0, 0.0], [1e-9, 0.0], [1.0, 1e-9], [0.5, 0.5], [0.0, 2e-9]]
        c = cluster_points(pts, 1e-6)
        @test c.cluster_id == [1, 2, 1, 2, 3, 1]
        @test c.cluster_size == [3, 2, 3, 2, 1, 3]
        @test c.representative == [true, true, false, false, true, false]
        @test cluster_points(Vector{Vector{Float64}}(), 1e-6).cluster_id == Int[]
        @test_throws ArgumentError cluster_points(pts, 0.0)
    end

    # a double well with two minima and a saddle; degree 4 reproduces it exactly
    dw(x) = (x[1]^2 - 0.25)^2 + x[2]^2
    TR = TestInput(dw; dim = 2, center = [0.0, 0.0], GN = 10, sample_range = 1.0)
    pol = Constructor(TR, 4)

    @testset "newton_polish_on_surrogate reaches the surrogate's critical points" begin
        # the true critical points of dw: (±0.5, 0) minima, (0, 0) saddle; start nearby
        for (z0, zstar) in (([0.45, 0.02], [0.5, 0.0]), ([-0.52, -0.03], [-0.5, 0.0]), ([0.02, 0.01], [0.0, 0.0]))
            ẑ, conv, gn, k = newton_polish_on_surrogate(pol, z0)
            @test conv
            @test norm(ẑ .- zstar) < 1e-8
            @test k <= 20
        end
        # the step cap keeps a far start from leaping: at most step_max per iteration
        ẑ, _, _, k = newton_polish_on_surrogate(pol, [0.9, 0.9]; iters = 1, step_max = 0.01)
        @test maximum(abs, ẑ .- [0.9, 0.9]) <= 0.01 + 1e-15
    end

    @testset "dedupe_on_surrogate merges perturbed duplicates" begin
        # eight seeds around the three critical points (perturbed by 1e-4), plus one far outside
        rng_pts = [
            [0.5001, 0.0001], [0.4999, -0.0001], [0.5, 0.0002],
            [-0.5001, 0.0], [-0.4999, 0.0001],
            [0.0001, 0.0], [0.0, -0.0001], [-0.0001, 0.0001],
            [3.0, 3.0],
        ]
        d = dedupe_on_surrogate(pol, rng_pts; tol = 1e-6)
        @test d.n_clusters == 4
        @test d.cluster_size[1:3] == [3, 3, 3] && d.cluster_size[4:5] == [2, 2] && d.cluster_size[6:8] == [3, 3, 3]
        @test d.cluster_size[9] == 1 && d.moved[9] == 0.0          # outside the margin: not polished
        @test count(d.representative) == 4
        @test d.n_converged == 8
        @test all(d.moved[1:8] .< 1e-3)
        # without polish the perturbed seeds stay distinct at this tolerance
        d0 = dedupe_on_surrogate(pol, rng_pts; tol = 1e-6, polish = false)
        @test d0.n_clusters == 9 && all(d0.moved .== 0)
    end

    @testset "run_standard_experiment writes the cluster columns" begin
        cfg = Globtim.ExperimentParams(; GN = 10, degree_range = 4:2:6, basis = :chebyshev)
        outdir = mktempdir()
        r = run_standard_experiment(;
            objective_function = dw,
            objective_name = "dw",
            bounds = [(-1.0, 1.0), (-1.0, 1.0)],
            experiment_config = cfg,
            output_dir = outdir,
        )
        df = CSV.read(joinpath(outdir, "critical_points_raw_deg_4.csv"), DataFrame)
        @test all(c in names(df) for c in ("cluster_id", "cluster_size", "representative", "surrogate_polish_move"))
        @test sum(df.representative) == maximum(df.cluster_id)
        @test all(df.cluster_size .>= 1)
        @test nrow(df) == r[:degree_results][1].n_critical_points   # the census is untouched
        # opt-out: plain CSV
        outdir2 = mktempdir()
        run_standard_experiment(;
            objective_function = dw,
            objective_name = "dw",
            bounds = [(-1.0, 1.0), (-1.0, 1.0)],
            experiment_config = Globtim.ExperimentParams(; GN = 10, degree_range = 4:2:4, basis = :chebyshev),
            output_dir = outdir2,
            surrogate_dedup = false,
        )
        df2 = CSV.read(joinpath(outdir2, "critical_points_raw_deg_4.csv"), DataFrame)
        @test !("cluster_id" in names(df2))
    end
end
