# test_rel_l2_ladder.jl — relative-L2 degree ladder (rel_l2_ladder.jl) and its wiring
# into run_standard_experiment (_ladder_history, the skip path of process_single_degree).

using Test
using Globtim

E(d, r; solved = true, m = solved ? [1.0, 2.0] : nothing) = RelL2LadderEntry(d, r, solved, m)

@testset "rel-L2 ladder" begin
    @testset "bands follow quality_thresholds.toml" begin
        th = RelL2Thresholds()
        @test (th.reliable, th.structure_visible, th.unreliable) == (0.03, 0.05, 0.10)
        @test classify_rel_l2(0.018) == :reliable
        @test classify_rel_l2(0.03) == :structure_visible      # lower edge is strict
        @test classify_rel_l2(0.037) == :structure_visible
        @test classify_rel_l2(0.056) == :unreliable
        @test classify_rel_l2(0.33) == :no_structure
        @test classify_rel_l2(NaN) == :unknown
        @test_throws ArgumentError RelL2Thresholds(reliable = 0.06, structure_visible = 0.05)
    end

    @testset "converged: reliable band + minimizer plateau" begin
        h = [
            E(4, 0.2; solved = false),
            E(6, 0.04; m = [1.0, 2.0]),
            E(8, 0.02; m = [1.1, 2.1]),
            E(10, 0.01; m = [1.10005, 2.10005]),
            E(12, 0.005; m = [1.10006, 2.10004]),
        ]
        s = rel_l2_ladder_step(h)
        @test s.action == :stop && s.verdict == :converged
        # the plateau is read on RELIABLE solves only: the structure-visible degree 6
        # (minimizer far away) does not enter the test
        @test rel_l2_ladder_step(h[1:4]).action == :continue
    end

    @testset "reliable budget" begin
        moving = [E(d, 0.01; m = [Float64(d), 0.0]) for d in 4:2:10]
        s = rel_l2_ladder_step(moving; max_reliable_solves = 4)
        @test s.verdict == :reliable_budget
        @test rel_l2_ladder_step(moving[1:3]; max_reliable_solves = 4).action == :continue
    end

    @testset "stagnation above the solve threshold ⇒ escalate" begin
        h = [E(d, r; solved = false) for (d, r) in zip(4:2:12, [0.40, 0.35, 0.349, 0.348, 0.3475])]
        s = rel_l2_ladder_step(h)
        @test s.action == :stop && s.verdict == :stagnated_unsolvable
        @test occursin("escalate", s.reason)
    end

    @testset "stagnation in the structure-visible band ⇒ partial" begin
        h = [E(4, 0.2; solved = false); [E(d, r) for (d, r) in zip(6:2:12, [0.045, 0.0449, 0.0448, 0.0447])]]
        @test rel_l2_ladder_step(h).verdict == :stagnated_partial
    end

    @testset "still improving ⇒ continue" begin
        h = [E(d, r; solved = r <= 0.05) for (d, r) in zip(4:2:10, [0.5, 0.2, 0.08, 0.04])]
        @test rel_l2_ladder_step(h).action == :continue
        @test rel_l2_ladder_step(RelL2LadderEntry[]).action == :continue
    end

    @testset "final verdict when the range runs out" begin
        @test rel_l2_final_verdict([E(4, 0.01)]).verdict == :range_exhausted_reliable
        @test rel_l2_final_verdict([E(4, 0.04)]).verdict == :range_exhausted_partial
        @test rel_l2_final_verdict([E(4, 0.2; solved = false)]).verdict == :range_exhausted_unsolvable
        @test rel_l2_final_verdict(RelL2LadderEntry[]).verdict == :no_fit
    end

    @testset "_ladder_history keeps fitted degrees only, sorted" begin
        r(d, st, rel, m) = (; degree = d, status = st, relative_l2_error = rel, best_estimate = m)
        rs = [
            r(8, "success", 0.02, [1.0]),
            r(4, "skipped_rel_l2", 0.3, nothing),
            r(6, "failed", NaN, nothing),
            r(10, "timeout", NaN, nothing),
        ]
        h = Globtim.StandardExperiment._ladder_history(rs)
        @test [x.degree for x in h] == [4, 8]
        @test [x.solved for x in h] == [false, true]
        @test h[2].best_estimate == [1.0]
    end

    @testset "process_single_degree skips the solve above the threshold" begin
        cfg = (; GN = 20, basis = :chebyshev, truncation_threshold = nothing, truncation_mode = :relative)
        bounds = [(-1.2, 1.2), (-1.2, 1.2)]
        TR = TestInput(Deuflhard, dim = 2, center = [0.0, 0.0], GN = cfg.GN, sample_range = 1.2)
        dir = mktempdir()
        r = Globtim.StandardExperiment.process_single_degree(
            2,
            Deuflhard,
            TR,
            bounds,
            cfg,
            dir,
            nothing;
            solve_rel_l2_max = 0.0,
        )
        @test r.status == "skipped_rel_l2"
        @test r.n_critical_points == 0
        @test isfinite(r.relative_l2_error) && r.relative_l2_error > 0
        @test r.error["rel_l2_band"] == string(classify_rel_l2(r.relative_l2_error))
        @test !isfile(joinpath(dir, "critical_points_raw_deg_2.csv"))   # nothing solved
    end

    @testset "ladder refuses the legacy gates alongside it" begin
        @test_throws ArgumentError run_standard_experiment(
            objective_function = x -> sum(abs2, x),
            objective_name = "q",
            bounds = [(-1.0, 1.0)],
            experiment_config = (;),
            output_dir = mktempdir(),
            degree_policy = :rel_l2_ladder,
            stagnation_stop = true,
        )
        @test_throws ArgumentError run_standard_experiment(
            objective_function = x -> sum(abs2, x),
            objective_name = "q",
            bounds = [(-1.0, 1.0)],
            experiment_config = (;),
            output_dir = mktempdir(),
            degree_policy = :bogus,
        )
    end
end
