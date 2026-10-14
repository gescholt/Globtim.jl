# Monotone value transforms (value_transform.jl): g ∘ f has the critical points and the
# Morse indices of f; the fit of g ∘ f is what changes. These tests pin the invariance,
# the inverse/derivative identities, the fitting heuristics and the domain guard.

using Test
using Globtim
using ForwardDiff
using LinearAlgebra

@testset "value transforms" begin
    @testset "apply / invert / derivative identities" begin
        ts = (
            IdentityTransform(),
            AsinhTransform(2.5; shift = -1.0),
            LogTransform(0.0; floor = 1e-3),
            SqrtTransform(-0.5),
        )
        vals = (0.0, 0.3, 2.0, 17.5, 1e4)
        for t in ts, v in vals
            v >= Globtim.domain_lower(t) || continue
            y = Globtim.apply(t, v)
            @test isapprox(Globtim.invert(t, y), v; rtol = 1e-12, atol = 1e-12)
            # derivative formula vs ForwardDiff of apply
            d_ad = ForwardDiff.derivative(u -> Globtim.apply(t, u), v)
            @test isapprox(Globtim.derivative(t, v), d_ad; rtol = 1e-10)
            @test Globtim.derivative(t, v) > 0
        end
        # strictly increasing on a sample of the domain
        for t in ts
            lo = max(Globtim.domain_lower(t), -3.0)
            xs = range(lo + 1e-9, 50.0; length = 200)
            ys = [Globtim.apply(t, x) for x in xs]
            @test all(diff(ys) .> 0)
        end
    end

    @testset "constructor guards" begin
        @test_throws ArgumentError AsinhTransform(0.0)
        @test_throws ArgumentError AsinhTransform(-1.0)
        @test_throws ArgumentError LogTransform(0.0; floor = 0.0)
        @test_throws ArgumentError SqrtTransform(Inf)
    end

    @testset "critical points and inertia are invariant" begin
        # clean Morse function: two minima and one saddle, all with f ≥ 10
        f(x) = (x[1]^2 - 1)^2 + 3 * x[2]^2 + 10.0      # minima (±1,0), saddle (0,0)
        t = AsinhTransform(0.7; shift = 9.0)             # shift below min f = 10
        g = TransformedObjective(f, t)
        for p in ([1.0, 0.0], [-1.0, 0.0], [0.0, 0.0])
            @test norm(ForwardDiff.gradient(g, p)) < 1e-12
            Hf = ForwardDiff.hessian(f, p)
            Hg = ForwardDiff.hessian(g, p)
            # Hg = g'(f(p)) Hf at a critical point
            @test Hg ≈ Globtim.derivative(t, f(p)) * Hf rtol = 1e-10
            @test count(<(0), eigvals(Hg)) == count(<(0), eigvals(Hf))
        end
        # and NOT at a non-critical point (the g'' ∇f ∇fᵀ term is there)
        p = [0.5, 0.2]
        @test !(ForwardDiff.hessian(g, p) ≈ Globtim.derivative(t, f(p)) * ForwardDiff.hessian(f, p))
        @test original_objective(g) === f
        @test value_transform(g) === t
        @test value_transform(f) isa IdentityTransform
        @test transform_summary(t)["kind"] == "asinh"
    end

    @testset "domain guard raises instead of clamping" begin
        f(x) = x[1]                                 # takes negative values
        g = TransformedObjective(f, LogTransform(0.0; floor = 0.1))
        @test g([0.5]) ≈ log(0.6)
        @test_throws ErrorException g([-0.5])
        # Inf passes through asinh (finite penalties / Inf branch pins are allowed)
        h = TransformedObjective(x -> Inf, AsinhTransform(1.0))
        @test h([0.0]) == Inf
    end

    @testset "fit_value_transform" begin
        vals = [10.0; 10.0 .+ (1:1000) ./ 10; 1e6; Inf; NaN]
        t = fit_value_transform(vals; kind = :asinh, quantile = 0.5)
        @test t isa AsinhTransform
        @test t.shift == 10.0
        @test 40.0 <= t.scale <= 60.0               # median of the positive excesses
        tl = fit_value_transform(vals; kind = :log, floor_quantile = 0.05)
        @test tl isa LogTransform && tl.floor > 0 && tl.shift == 10.0
        ts = fit_value_transform(vals; kind = :sqrt)
        @test ts isa SqrtTransform && ts.shift < 10.0
        @test fit_value_transform(vals; kind = :identity) isa IdentityTransform
        # degenerate pilots fall back to identity
        @test fit_value_transform([3.0, 3.0, 3.0]) isa IdentityTransform
        @test fit_value_transform([Inf, NaN]) isa IdentityTransform
        @test fit_value_transform(Float64[]) isa IdentityTransform
        @test_throws ArgumentError fit_value_transform(vals; kind = :exp)
        @test_throws ArgumentError fit_value_transform(vals; quantile = 0.0)
    end

    @testset "asinh compresses a misfit landscape's coefficient envelope" begin
        # f = misfit-like: small near the minimum, 1e4 on the peaks. The transformed fit
        # at the same degree must have a smaller relative L2 error than the raw one.
        f(x) = 1e4 * ((x[1] - 0.3)^2 + (x[2] + 0.2)^2)^2 + 1e-2 * (x[1]^2 + x[2]^2)
        TR_raw = TestInput(f; dim = 2, center = [0.0, 0.0], GN = 16, sample_range = 1.0, tolerance = nothing)
        pol_raw = Constructor(TR_raw, 8)
        pilot = pol_raw.z
        t = fit_value_transform(pilot; kind = :asinh)
        TR_t = TestInput(TransformedObjective(f, t); dim = 2, center = [0.0, 0.0], GN = 16, sample_range = 1.0, tolerance = nothing)
        pol_t = Constructor(TR_t, 8)
        # this f is a degree-4 polynomial, so the raw fit is exact up to rounding; the
        # test is that the transformed fit is still well below the structure-visible band
        @test relative_l2_error(pol_t) < 5e-2
        # and the transformed surrogate's minimiser still sits near (0.3, -0.2)
        best = argmin(pol_t.z)
        xbest = pol_t.grid[best, :]
        @test norm(xbest .- [0.3, -0.2]) < 0.2
    end
end
