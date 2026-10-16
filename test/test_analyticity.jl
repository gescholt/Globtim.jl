# N7 analyticity detector (analyticity.jl): geometric coefficient decay along an axis is
# analytic, algebraic decay is a kink / plateau inside the box on that axis. Synthetic
# envelopes first, then fits of |x₁| + x₂² (kink on axis 1 only) and of a smooth function,
# then the pipeline stop with the suggested axis.

using Test
using Globtim

ENV["GLOBTIM_LEDGER_APPEND"] = "0"   # the pipeline runs below write no central-ledger row

@testset "analyticity" begin
    @testset "synthetic envelopes" begin
        geo = [0.5^k for k in 0:12]                       # analytic: ρ = 2
        r = axis_analyticity(geo)
        @test r.resolved && !r.offending
        @test r.decay_rate ≈ 0.5 atol = 1e-6
        @test r.model_rss_ratio > 1                       # algebraic model fits worse

        alg = [k == 0 ? 1.0 : Float64(k)^-2 for k in 0:12]   # kink: |c_k| ~ k^-2
        r = axis_analyticity(alg)
        @test r.resolved && r.offending
        @test r.model_rss_ratio < 0.5
        @test r.algebraic_exponent ≈ 2.0 atol = 1e-6

        # parity zeros (an even function) must not count as a plateau or break the fit
        alg_even = [k == 0 ? 1.0 : (iseven(k) ? Float64(k)^-2 : 0.0) for k in 0:16]
        r = axis_analyticity(alg_even)
        @test r.resolved && r.offending
        geo_even = [iseven(k) ? 0.4^k : 0.0 for k in 0:16]
        r = axis_analyticity(geo_even)
        @test r.resolved && !r.offending

        # geometric decay into a noise plateau: analytic, plateau found, fit on the decay only
        plat = [k <= 8 ? 0.3^k : 1e-7 for k in 0:16]
        r = axis_analyticity(plat)
        @test r.plateau_found && r.resolved && !r.offending
        @test r.decay_rate ≈ 0.3 atol = 1e-6

        # the evidence map's rule: slow geometric ratio with no plateau trips too
        slow = [0.95^k for k in 0:12]
        r = axis_analyticity(slow)
        @test r.offending
        @test r.decay_rate ≈ 0.95 atol = 1e-6
        @test !axis_analyticity(slow; rate_threshold = 0.99).offending

        # too few resolved coefficients: unresolved, never offending
        r = axis_analyticity([1.0, 0.5, 0.25])
        @test !r.resolved && !r.offending
        @test !axis_analyticity(zeros(5)).resolved

        @test_throws ArgumentError axis_analyticity(geo; rate_threshold = 1.0)
        @test_throws ArgumentError axis_analyticity(geo; model_ratio = 0.0)
        @test_throws ArgumentError axis_analyticity(geo; min_points = 2)
    end

    @testset "fits: kink on axis 1 only" begin
        kink(x) = abs(x[1]) + x[2]^2
        TR = TestInput(kink; dim = 2, center = [0.0, 0.0], GN = 20, sample_range = 1.0)
        pol = Constructor(TR, 14)
        v = analyticity_verdict(pol)
        @test v.verdict == :non_analytic
        @test v.offending[1] && !v.offending[2]
        @test v.suggested_axis == 1
        @test v.algebraic_exponent[1] > 1
        s = analyticity_summary(v)
        @test s["verdict"] == "non_analytic" && s["offending_axes"] == [1] && s["suggested_axis"] == 1

        smooth(x) = exp(0.5 * x[1] + 0.3 * x[2]) + sin(2 * x[1]) * x[2]
        TRs = TestInput(smooth; dim = 2, center = [0.0, 0.0], GN = 20, sample_range = 1.0)
        vs = analyticity_verdict(Constructor(TRs, 14))
        @test vs.verdict == :analytic
        @test !any(vs.offending) && vs.suggested_axis == 0
        @test all(vs.decay_rate .< 0.9)
    end

    @testset "run_standard_experiment records the verdict and can stop" begin
        # kink away from the centre: the coefficients carry a cos(kθ₀) modulation, and the
        # peak envelope needs ~9 points before the two decay laws separate — degree 14 here
        kink(x) = abs(x[1] - 0.2) + (x[2] - 0.1)^2
        cfg = Globtim.ExperimentParams(; GN = 20, degree_range = 6:4:18, basis = :chebyshev)
        md = Dict{String,Any}()
        r = run_standard_experiment(;
            objective_function = kink,
            objective_name = "kink",
            bounds = [(-1.0, 1.0), (-1.0, 1.0)],
            experiment_config = cfg,
            output_dir = mktempdir(),
            metadata = md,
            analyticity_stop = true,
        )
        @test haskey(md, "analyticity")
        @test haskey(md, "stopped_non_analytic")
        @test md["stopped_non_analytic"]["degree"] == 14
        @test md["stopped_non_analytic"]["offending_axes"] == [1]
        @test md["stopped_non_analytic"]["suggested_axis"] == 1
        @test md["stopped_after_degree"] == 14
        @test length(r[:degree_results]) == 3                 # 6, 10, 14 — not 18
        # verdicts are recorded for every fitted degree, whether or not the stop is on
        md2 = Dict{String,Any}()
        r2 = run_standard_experiment(;
            objective_function = kink,
            objective_name = "kink",
            bounds = [(-1.0, 1.0), (-1.0, 1.0)],
            experiment_config = Globtim.ExperimentParams(; GN = 20, degree_range = 6:4:14, basis = :chebyshev),
            output_dir = mktempdir(),
            metadata = md2,
        )
        @test length(r2[:degree_results]) == 3
        @test !haskey(md2, "stopped_non_analytic")
        @test Set(keys(md2["analyticity"])) == Set(["6", "10", "14"])
        @test md2["analyticity"]["14"]["verdict"] == "non_analytic"
        @test md2["analyticity"]["14"]["algebraic_exponent"][1] > 1.5
    end
end
