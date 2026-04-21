using Test
using Globtim
using JLD2

# Minimal stand-in for Globtim.ExperimentCLI.ExperimentParams: the resume
# helpers only read a small set of fields by name, so a NamedTuple is enough.
function _fake_cfg(; GN=5, basis=:chebyshev, domain_size=0.1,
                     truncation_threshold=nothing, truncation_mode=:relative)
    return (; GN, basis, domain_size, truncation_threshold, truncation_mode)
end

const _DR = Globtim.StandardExperiment.DegreeResult
const _hash_fn = Globtim.StandardExperiment._experiment_config_hash
const _load_fn = Globtim.StandardExperiment._load_resumable_checkpoint
const _save_fn = Globtim.StandardExperiment._save_checkpoint

"Build a minimal successful DegreeResult for a given degree."
function _success_result(degree::Int)
    return _DR(
        degree, "success",
        1,                                  # n_critical_points
        [[0.0, 0.0]],                       # critical_points
        [0.0],                              # objective_values
        [0.0], 0.0, nothing,                # best_estimate, best_objective, recovery_error
        1e-6, 1e-9, 1.0,                    # l2_approx_error, relative_l2_error, condition_number
        10, 10,                             # n_total_coeffs, support_size
        nothing, nothing, nothing,          # truncation_*
        0.1, 0.2, 0.0, 0.0, 0.3,            # timing fields
        "",                                 # output_dir (set per test)
        nothing,                            # error
    )
end

@testset "StandardExperiment resume helpers" begin
    bounds = [(-1.0, 1.0), (-1.0, 1.0)]
    cfg = _fake_cfg()

    @testset "config hash is deterministic and sensitive" begin
        h1 = _hash_fn(cfg, bounds, "lv4d", :hc, 1)
        h2 = _hash_fn(cfg, bounds, "lv4d", :hc, 1)
        @test h1 == h2

        # Different bounds → different hash
        @test _hash_fn(cfg, [(-2.0, 2.0), (-1.0, 1.0)], "lv4d", :hc, 1) != h1
        # Different objective_name → different hash
        @test _hash_fn(cfg, bounds, "other", :hc, 1) != h1
        # Different GN → different hash
        @test _hash_fn(_fake_cfg(GN=6), bounds, "lv4d", :hc, 1) != h1
        # Different solver → different hash
        @test _hash_fn(cfg, bounds, "lv4d", :msolve, 1) != h1
    end

    @testset "load returns empty when checkpoint missing" begin
        mktempdir() do dir
            @test isempty(_load_fn(dir, UInt(0)))
        end
    end

    @testset "save/load round-trip on matching hash" begin
        mktempdir() do dir
            h = _hash_fn(cfg, bounds, "lv4d", :hc, 1)
            results = [_success_result(4), _success_result(6)]
            _save_fn(dir, results, h)

            loaded = _load_fn(dir, h)
            @test length(loaded) == 2
            @test loaded[1].degree == 4
            @test loaded[2].degree == 6
            @test all(r -> r.status == "success", loaded)
        end
    end

    @testset "hash mismatch is ignored (empty result, file preserved)" begin
        mktempdir() do dir
            h = _hash_fn(cfg, bounds, "lv4d", :hc, 1)
            _save_fn(dir, [_success_result(4)], h)

            other_h = _hash_fn(_fake_cfg(GN=99), bounds, "lv4d", :hc, 1)
            @test other_h != h
            @test isempty(_load_fn(dir, other_h))
            # File should still be on disk for user inspection
            @test isfile(joinpath(dir, "checkpoint.jld2"))
        end
    end

    @testset "pre-resume checkpoints (no config_hash) are ignored" begin
        mktempdir() do dir
            # Simulate an older run that saved a checkpoint without a config_hash
            path = joinpath(dir, "checkpoint.jld2")
            jldsave(path; degree_results=[_success_result(4)], warn=false)
            @test isempty(_load_fn(dir, _hash_fn(cfg, bounds, "lv4d", :hc, 1)))
        end
    end

    @testset "corrupted checkpoint is ignored, not fatal" begin
        mktempdir() do dir
            path = joinpath(dir, "checkpoint.jld2")
            write(path, "this is not a valid JLD2 file")
            @test isempty(_load_fn(dir, UInt(0)))
        end
    end
end
