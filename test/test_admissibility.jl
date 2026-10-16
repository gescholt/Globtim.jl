# N3 penalty-node admissibility gate (admissibility.jl): grid values that are non-finite,
# equal to the registered penalty, or above the dynamic-range cap fail the fit with the
# counts in the error; the standard experiment records the degree as "inadmissible" and
# stops the sweep. A smooth objective is untouched.

using Test
using Globtim

ENV["GLOBTIM_LEDGER_APPEND"] = "0"   # the pipeline runs below write no central-ledger row

@testset "admissibility" begin
    @testset "grid_admissibility counts" begin
        F = [0.1, 0.2, Inf, NaN, 5.0, 5.0 * (1 + 1e-4), 1e12, -0.3]
        a = grid_admissibility(F)
        @test (a.n_total, a.n_nonfinite, a.n_penalty, a.n_above_cap) == (8, 2, 0, 0)
        @test !a.admissible
        a = grid_admissibility(F; penalty_value = 5.0)
        @test a.n_penalty == 2                      # isapprox with rtol 1e-3
        a = grid_admissibility(F; penalty_value = 5.0, max_abs_value = 1e6)
        @test (a.n_nonfinite, a.n_penalty, a.n_above_cap) == (2, 2, 1)
        @test grid_admissibility([0.1, 0.2, 0.3]).admissible
        @test grid_admissibility([0.1, 0.2, 0.3]; penalty_value = 5.0, max_abs_value = 1.0).admissible
        @test_throws ArgumentError grid_admissibility(F; max_abs_value = 0.0)
        # a value is counted once: Inf is non-finite, not "above the cap"
        a = grid_admissibility([Inf]; max_abs_value = 1.0)
        @test (a.n_nonfinite, a.n_above_cap) == (1, 0)
    end

    @testset "check_grid_admissibility raises with the counts" begin
        @test check_grid_admissibility([1.0, 2.0]).admissible
        err = try
            check_grid_admissibility([1.0, 7.0, 7.0, Inf]; penalty_value = 7.0)
            nothing
        catch e
            e
        end
        @test err isa InadmissibleGridError
        @test (err.n_total, err.n_nonfinite, err.n_penalty, err.n_above_cap) == (4, 1, 2, 0)
        msg = sprint(showerror, err)
        @test occursin("1 non-finite", msg) && occursin("2 at the penalty value 7.0", msg)
        @test occursin("of 4 grid values", msg)
    end

    _PV = 1e9
    wall(x) = x[1] + x[2] > 0.3 ? _PV : x[1]^2 + x[2]^2
    smooth(x) = x[1]^2 + x[2]^2

    @testset "Constructor: penalty nodes fail the fit, smooth fits are untouched" begin
        TR = TestInput(wall; dim = 2, center = [0.0, 0.0], GN = 8, sample_range = 1.0)
        # the sentinel is finite, so without a registered penalty the fit goes through
        pol_blind = Constructor(TR, 4)
        @test pol_blind isa ApproxPoly
        # registered: the gate counts the wall nodes and raises
        err = try
            Constructor(TR, 4; penalty_value = _PV)
            nothing
        catch e
            e
        end
        @test err isa InadmissibleGridError
        @test err.n_penalty > 0 && err.n_nonfinite == 0
        @test err.n_total == 81
        # the cap catches the same nodes without a registered value
        @test_throws InadmissibleGridError Constructor(TR, 4; max_abs_value = 1e6)
        # opt out reproduces the blind fit
        pol_off = Constructor(TR, 4; penalty_value = _PV, admissibility = false)
        @test pol_off.coeffs ≈ pol_blind.coeffs
        # smooth objective: no effect of the gate
        TRs = TestInput(smooth; dim = 2, center = [0.0, 0.0], GN = 8, sample_range = 1.0)
        @test Constructor(TRs, 4; penalty_value = _PV, max_abs_value = 1e6) isa ApproxPoly
    end

    @testset "Constructor: non-finite values raise before the least-squares solve" begin
        inf_obj(x) = x[1] > 0.5 ? Inf : x[1]^2 + x[2]^2
        TR = TestInput(inf_obj; dim = 2, center = [0.0, 0.0], GN = 8, sample_range = 1.0)
        err = try
            Constructor(TR, 4)
            nothing
        catch e
            e
        end
        @test err isa InadmissibleGridError
        @test err.n_nonfinite > 0
    end

    @testset "run_standard_experiment: status inadmissible, sweep stops" begin
        cfg = Globtim.ExperimentParams(; GN = 8, degree_range = 4:2:6, basis = :chebyshev)
        md = Dict{String,Any}()
        r = run_standard_experiment(;
            objective_function = wall,
            objective_name = "wall",
            bounds = [(-1.0, 1.0), (-1.0, 1.0)],
            experiment_config = cfg,
            output_dir = mktempdir(),
            metadata = md,
            penalty_value = _PV,
        )
        drs = r[:degree_results]
        @test length(drs) == 1                     # stopped after the first degree
        @test drs[1].status == "inadmissible"
        @test drs[1].error["n_penalty"] > 0
        @test drs[1].error["error_type"] == "InadmissibleGridError"
        @test haskey(md, "stopped_inadmissible")
        @test md["stopped_inadmissible"]["degree"] == 4
        @test md["stopped_inadmissible"]["n_penalty"] == drs[1].error["n_penalty"]
        @test md["stopped_after_degree"] == 4
        # the same run without a registered penalty fits both degrees (the sentinel is finite)
        md2 = Dict{String,Any}()
        r2 = run_standard_experiment(;
            objective_function = wall,
            objective_name = "wall",
            bounds = [(-1.0, 1.0), (-1.0, 1.0)],
            experiment_config = cfg,
            output_dir = mktempdir(),
            metadata = md2,
        )
        @test length(r2[:degree_results]) == 2
        @test all(d.status != "inadmissible" for d in r2[:degree_results])
        @test !haskey(md2, "stopped_inadmissible")
    end
end
