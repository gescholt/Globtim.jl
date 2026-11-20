# Globtim 1.6 dropped DrWatson (results_summary.jld2 is written with JLD2 directly),
# JSON (PathManager session files use JSON3) and StatsBase, and moved
# ConstructionBase.setproperties for ExperimentParams into an extension. These tests
# pin the three replaced code paths.

using Test
using Globtim
using JLD2
import ConstructionBase

@testset "Globtim 1.6 slim dependencies" begin
    @testset "save_experiment_summary writes JSON + JLD2 with string keys" begin
        mktempdir() do dir
            summary = Dict(:degree => 6, :n_cps => 3, :l2 => 1.5e-3, :note => "x")
            Globtim.StandardExperiment.save_experiment_summary(summary, dir)
            @test isfile(joinpath(dir, "results_summary.json"))
            d = JLD2.load(joinpath(dir, "results_summary.jld2"))
            for (k, v) in summary
                @test d[string(k)] == v
            end
            # gitcommit is present exactly when the active project is in a git checkout
            @test !haskey(d, "gitcommit") || d["gitcommit"] isa String
        end
    end

    @testset "PathManager session file round-trips through JSON3" begin
        mktempdir() do dir
            meta = Dict{String,Any}("GN" => 10, "basis" => "chebyshev")
            f = Globtim.PathManager.register_experiment(dir, meta)
            @test isfile(f)
            Globtim.PathManager.update_experiment_progress(dir, 2, 5; current_step_name = "fit")
            Globtim.PathManager.finalize_experiment(dir, true, "done")
            s = read(f, String)
            @test occursin("\"completed\"", s)
            @test occursin("\"fit\"", s)
            @test occursin("\"chebyshev\"", s)
        end
    end

    @testset "setproperties via the ConstructionBase extension" begin
        @test Base.get_extension(Globtim, :GlobtimConstructionBaseExt) !== nothing
        ep = ExperimentParams(GN = 10, truncation_threshold = 0.05, truncation_mode = :absolute)
        ep2 = ConstructionBase.setproperties(ep, (GN = 20,))
        @test ep2.GN == 20
        @test ep2.truncation_threshold == 0.05
        @test ep2.truncation_mode == :absolute
    end
end
