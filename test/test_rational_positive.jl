# test_rational_positive.jl — positive denominators in the linearised rational fit
# (src/rational_bernstein.jl): the Bernstein map and lower bound, the constrained QP
# rational_ls_fit_positive, and RationalConstructor(...; denominator = :points /
# :bernstein). Pure linear algebra and Optim; no HomotopyContinuation.

using Test
using Globtim
using LinearAlgebra
using Random: Xoshiro
using Statistics: mean

f_rat(x) = (1 + x[1] + x[2]^2) / (2 + x[1]^2 + x[2]^2)
f_pole(x) = 1 / ((x[1] - 1.15)^2 + (x[2] - 0.30)^2 + 0.04) + sin(3x[1]) * cos(2x[2])
# a kink: no rational of low type fits it, and the free linearised fit puts a zero
# of q across the box
f_kink(x) = abs(x[1] - 0.1) + 0.5x[2]

vand(L, S) = Globtim.lambda_vandermonde_original(L, S; basis = :chebyshev)

@testset "Positive denominators" begin
    @testset "bernstein_matrix reproduces the polynomial and bounds it" begin
        rng = Xoshiro(3)
        for (n, N, deg) in ((1, 5, 5), (2, 4, 4), (2, 4, 9), (3, 3, 3))
            Λ = SupportGen(n, (:one_d_for_all, N))
            T = bernstein_matrix(Λ, :chebyshev; degree = deg)
            @test size(T) == ((deg + 1)^n, size(Λ.data, 1))
            b = randn(rng, size(Λ.data, 1))
            X = 2 .* rand(rng, 500, n) .- 1
            q = vand(Λ, X) * b
            c = T * b
            t = (X .+ 1) ./ 2
            qb = zeros(size(X, 1))
            for (idx, γ) in enumerate(Iterators.product(ntuple(_ -> 0:deg, n)...))
                qb .+= c[idx] .* reduce((u, v) -> u .* v,
                    [binomial(deg, γ[k]) .* t[:, k] .^ γ[k] .* (1 .- t[:, k]) .^ (deg - γ[k]) for k in 1:n])
            end
            @test maximum(abs.(q .- qb)) < 1e-10
            @test minimum(c) <= minimum(q)
        end
        # the constant has every Bernstein coefficient 1 (the QP's feasible start)
        Λ = SupportGen(3, (:one_d_for_all, 4))
        @test all(isapprox.(bernstein_matrix(Λ, :chebyshev)[:, 1], 1; atol = 1e-12))
        # elevation tightens: x² on [-1,1] has coefficients (1, -1, 1) at degree 2
        Λ1 = SupportGen(1, (:one_d_for_all, 2))
        b = [d == 1 ? 0.0 : 0.5 for d in Λ1.data[:, 1]]   # T₀/2 + T₂/2 = x²
        @test minimum(bernstein_matrix(Λ1, :chebyshev) * b) ≈ -1 atol = 1e-12
        @test minimum(bernstein_matrix(Λ1, :chebyshev; degree = 8) * b) > -0.2
        @test_throws ArgumentError bernstein_matrix(Λ1, :chebyshev; degree = 1)
    end

    @testset "Bernstein-constrained fit recovers an exact rational" begin
        TR = TestInput(f_rat; dim = 2, center = [0.0, 0.0], sample_range = 1.0)
        # q = 2 + x₁² + x₂² is in the Bernstein cone only after elevation (degree 2
        # gives a zero coefficient); at degree 4 its smallest coefficient is 4/3
        R = RationalConstructor(TR, 2, 2; GN = 8, denominator = :bernstein, bernstein_degree = 4, delta = 0.05)
        X = 2 .* rand(Xoshiro(1), 400, 2) .- 1
        @test maximum(abs(R(X[i, :]) - f_rat(X[i, :])) for i in 1:400) < 1e-8
        @test bernstein_lower_bound(R; degree = 4) >= 0.05 - 1e-9
        @test R.qmin_grid > 0
    end

    @testset "rational_ls_fit_positive: constraint holds, argument checks" begin
        n, M, N = 2, 4, 2
        S = 2 .* rand(Xoshiro(2), 200, n) .- 1
        z = [f_kink(S[i, :]) for i in 1:200]
        ΛM = SupportGen(n, (:one_d_for_all, M)); ΛN = SupportGen(n, (:one_d_for_all, N))
        VM = vand(ΛM, S); VN = vand(ΛN, S)
        T = bernstein_matrix(ΛN, :chebyshev; degree = 6)
        f = rational_ls_fit_positive(VM, VN, z, T; delta = 0.1)
        @test minimum(T * f.b) >= 0.1 * mean(VN * f.b) - 1e-8
        @test mean(VN * f.b) ≈ 1 atol = 1e-8
        @test f.ipm_iterations < 100
        @test_throws ArgumentError rational_ls_fit_positive(VM, VN, z, T; delta = 1.5)
        @test_throws ArgumentError rational_ls_fit_positive(VM, VN, z[1:10], T)
        @test_throws ArgumentError rational_ls_fit_positive(VM, VN, z, T[:, 1:3])
    end

    @testset "denominator = :points" begin
        Xv = 2 .* rand(Xoshiro(9), 3000, 2) .- 1
        # pole target: as accurate as the free fit (the true q is positive)
        TR = TestInput(f_pole; dim = 2, center = [0.0, 0.0], sample_range = 1.0)
        kw() = (; sampling = :christoffel, n_samples = 120, rng = Xoshiro(1))   # a fresh stream per call
        Rf = RationalConstructor(TR, 8, 4; kw()...)
        Rp = RationalConstructor(TR, 8, 4; kw()..., denominator = :points, delta = 0.01)
        @test Rp.grid == Rf.grid
        err(R, f) = sqrt(mean(abs2, [R(Xv[i, :]) - f(Xv[i, :]) for i in 1:size(Xv, 1)]))
        @test err(Rp, f_pole) < 2 * err(Rf, f_pole) + 1e-6
        # kink target: the free fit's q changes sign in the box, the constrained one
        # stays above delta/2 · mean(q) on a dense check set
        TRk = TestInput(f_kink; dim = 2, center = [0.0, 0.0], sample_range = 1.0)
        kwk = (; sampling = :christoffel, n_samples = 60, rng = Xoshiro(4))
        Rk = RationalConstructor(TRk, 4, 2; kwk..., denominator = :points, delta = 0.05)
        qv = [rational_denominator(Rk, Xv[i, :]) for i in 1:size(Xv, 1)]
        @test minimum(qv) > 0.02 * mean([rational_denominator(Rk, Rk.grid[i, :]) for i in 1:size(Rk.grid, 1)])
        @test_throws ArgumentError RationalConstructor(TR, 8, 4; denominator = :positive)
    end
end
