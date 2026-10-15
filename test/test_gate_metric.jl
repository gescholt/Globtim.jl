# N1 (EVIDENCE_MAP_2026-10.md): the solve gate and the rel-L2 ladder can read the
# relative gradient error instead of the relative L2 error. Pure parts
# (_ladder_history with a metric dict, the skip path of process_single_degree) — no HC
# solve is run.

using Test
using Globtim
using Globtim: RelL2LadderEntry, classify_rel_l2

@testset "gate_metric = :rel_grad" begin
    @testset "_ladder_history substitutes the metric and drops degrees without one" begin
        r(d, st, rel, m) = (; degree = d, status = st, relative_l2_error = rel, best_estimate = m)
        rs = [
            r(8, "success", 0.02, [1.0]),
            r(4, "skipped_rel_l2", 0.3, nothing),
            r(6, "success", 0.05, [0.9]),
            r(10, "failed", NaN, nothing),
        ]
        g = Dict(4 => 0.5, 8 => 0.01)          # no entry for degree 6
        h = Globtim.StandardExperiment._ladder_history(rs; metric = g)
        @test [x.degree for x in h] == [4, 8]
        @test [x.rel_l2 for x in h] == [0.5, 0.01]          # the metric, in the rel_l2 slot
        @test [x.solved for x in h] == [false, true]
        # NaN metric values are dropped too
        g2 = Dict(4 => NaN, 6 => 0.2, 8 => 0.01)
        @test [x.degree for x in Globtim.StandardExperiment._ladder_history(rs; metric = g2)] == [6, 8]
        # without a metric: unchanged behaviour
        h0 = Globtim.StandardExperiment._ladder_history(rs)
        @test [x.rel_l2 for x in h0] == [0.3, 0.05, 0.02]
    end

    @testset "_record_ladder! names the metric" begin
        r(d, st, rel, m) = (; degree = d, status = st, relative_l2_error = rel, best_estimate = m)
        rs = [r(4, "success", 0.02, [1.0])]
        th = Globtim.RelL2Thresholds()
        md = Dict{String,Any}()
        Globtim.StandardExperiment._record_ladder!(md, :converged, "x", 4, rs, th, 0.05)
        @test md["rel_l2_ladder"]["metric"] == "rel_l2"
        @test md["rel_l2_ladder"]["relative_l2"] == [0.02]
        md2 = Dict{String,Any}()
        Globtim.StandardExperiment._record_ladder!(md2, :converged, "x", 4, rs, th, 0.05; metric = Dict(4 => 0.007))
        @test md2["rel_l2_ladder"]["metric"] == "rel_grad"
        @test md2["rel_l2_ladder"]["relative_l2"] == [0.007]
    end

    @testset "process_single_degree gates on the gradient error" begin
        cfg = (; GN = 20, basis = :chebyshev, truncation_threshold = nothing, truncation_mode = :relative)
        bounds = [(-1.2, 1.2), (-1.2, 1.2)]
        TR = TestInput(Deuflhard, dim = 2, center = [0.0, 0.0], GN = cfg.GN, sample_range = 1.2)
        dir = mktempdir()
        ge = Dict{Int,Float64}()
        r = Globtim.StandardExperiment.process_single_degree(
            2,
            Deuflhard,
            TR,
            bounds,
            cfg,
            dir,
            nothing;
            solve_rel_l2_max = 0.0,
            gate_metric = :rel_grad,
            gradient_errors = ge,
            gradient_check_points = 8,
        )
        @test r.status == "skipped_rel_l2"
        @test haskey(ge, 2) && isfinite(ge[2]) && ge[2] > 0
        @test r.error["skip_reason"] == "rel_grad_above_solve_threshold"
        @test r.error["gate_metric"] == "rel_grad"
        @test r.error["gate_value"] == ge[2]
        @test r.error["relative_gradient_error"] == ge[2]
        @test r.error["rel_l2_band"] == string(classify_rel_l2(r.relative_l2_error))
        # :rel_l2 default keeps the legacy skip_reason string
        r0 = Globtim.StandardExperiment.process_single_degree(
            2, Deuflhard, TR, bounds, cfg, dir, nothing; solve_rel_l2_max = 0.0,
        )
        @test r0.error["skip_reason"] == "rel_l2_above_solve_threshold"
        # :rel_grad without the gradient dict is an error, not a silent fallback to rel-L2
        @test_throws ErrorException Globtim.StandardExperiment.process_single_degree(
            2, Deuflhard, TR, bounds, cfg, dir, nothing;
            solve_rel_l2_max = 0.0, gate_metric = :rel_grad,
        )
    end

    @testset "run_standard_experiment validates gate_metric" begin
        @test_throws ArgumentError run_standard_experiment(
            objective_function = x -> sum(abs2, x),
            objective_name = "q",
            bounds = [(-1.0, 1.0)],
            experiment_config = (;),
            output_dir = mktempdir(),
            gate_metric = :rel_value,
        )
    end
end
