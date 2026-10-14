# Coefficient envelope, noise-floor estimate and automatic chop (chop.jl).

using Test
using Globtim
using LinearAlgebra
using Random

@testset "chop" begin
    @testset "estimate_noise_floor on synthetic envelopes" begin
        rng = MersenneTwister(7)
        # geometric decay ρ = 0.3 to degree 8, then a noisy plateau around 1e-7
        env = [k <= 8 ? 0.3^k : 1e-7 * (0.5 + rand(rng)) for k in 0:16]
        est = estimate_noise_floor(env)
        @test est.plateau_found
        @test 7 <= est.usable_degree <= 9
        @test 3e-8 <= est.floor <= 3e-7
        @test est.relative_floor == est.floor / maximum(env)
        @test 0.2 <= est.decay_rate <= 0.4
        @test est.envelope == env

        # still converging: pure geometric decay, no plateau
        env2 = [0.5^k for k in 0:16]
        est2 = estimate_noise_floor(env2)
        @test !est2.plateau_found
        @test isnan(est2.floor)
        @test est2.usable_degree == 16
        @test 0.45 <= est2.decay_rate <= 0.55

        # a tail that keeps decaying, only more slowly (ratio 0.6 after 0.3), is a change
        # of analyticity radius, not a noise floor: rejected by the flatness criterion
        env3 = [k <= 8 ? 0.3^k : 0.3^8 * 0.6^(k - 8) for k in 0:16]
        @test !estimate_noise_floor(env3).plateau_found

        # too short / degenerate inputs never throw
        @test !estimate_noise_floor([1.0, 0.1, 0.01]).plateau_found
        @test !estimate_noise_floor(Float64[]).plateau_found
        @test !estimate_noise_floor(zeros(10)).plateau_found
        # zero entries (degrees absent from the support) are ignored, not log'd
        env4 = copy(env); env4[3] = 0.0
        @test estimate_noise_floor(env4).plateau_found
    end

    @testset "coefficient_envelope and axis_envelopes on an ApproxPoly" begin
        f(x) = 2.0 + 0.5 * x[1] - 0.25 * x[1] * x[2]^2
        TR = TestInput(f; dim = 2, center = [0.0, 0.0], GN = 8, sample_range = 1.0, tolerance = nothing)
        pol = Constructor(TR, 4)
        env = coefficient_envelope(pol)
        @test env.degrees == 0:4
        @test length(env.envelope) == 5
        @test env.envelope[1] ≈ 2.0 atol = 1e-10                 # T0 coefficient
        @test env.envelope[2] > 0.1                              # x1 term lives at total degree 1
        @test env.envelope[4] > 0.01                             # x1 x2^2 at total degree 3
        @test env.envelope[5] < 1e-10                            # nothing at degree 4
        ax = axis_envelopes(pol)
        @test length(ax) == 2
        @test length(ax[1]) == 5 && length(ax[2]) == 5
        @test ax[1][3] < 1e-10                                   # no x1^2
        @test ax[2][3] > 0.01                                    # x2^2 present
        rates = axis_decay_rates(pol)
        @test length(rates) == 2
    end

    @testset "chop_polynomial on a fit with a deterministic noise floor" begin
        # smooth part with super-geometric decay + deterministic sample "noise" at 1e-8 (a
        # sine the grid cannot resolve, so it aliases like noise): the envelope decays to
        # ~1e-9 by total degree 11 and is flat beyond (checked numerically: floor ≈ 1.7e-9,
        # usable degree 11, separation 4.5 decades at GN = 24, degree 20).
        f(x) = exp(x[1]) * cos(x[2]) + 1e-8 * sin(1e6 * x[1] * x[2] + 1e5 * x[1] + 3e4 * x[2])
        TR = TestInput(f; dim = 2, center = [0.0, 0.0], GN = 24, sample_range = 1.0, tolerance = nothing)
        pol = Constructor(TR, 20)
        est = estimate_noise_floor(pol)
        @test est.plateau_found
        @test 1e-10 <= est.floor <= 1e-7
        @test 9 <= est.usable_degree <= 13
        @test 0.1 <= est.decay_rate <= 0.3
        res = chop_polynomial(pol)
        @test res.new_nnz < res.original_nnz
        @test res.l2_ratio ≈ 1.0 atol = 1e-6
        @test res.estimate.floor == est.floor
        # the chopped polynomial reproduces the fit values to the noise level
        @test all(iszero, res.polynomial.coeffs[abs.(pol.coeffs) .<= est.floor])
        @test all(res.polynomial.coeffs[abs.(pol.coeffs) .> est.floor] .== pol.coeffs[abs.(pol.coeffs) .> est.floor])

        # no plateau ⇒ unchanged
        g(x) = 1.0 + x[1] + x[2]^2
        polg = Constructor(TestInput(g; dim = 2, center = [0.0, 0.0], GN = 6, sample_range = 1.0, tolerance = nothing), 3)
        resg = chop_polynomial(polg)
        if !resg.estimate.plateau_found
            @test resg.new_nnz == resg.original_nnz
            @test resg.polynomial === polg
        end
    end
end
