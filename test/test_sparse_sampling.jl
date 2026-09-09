# Sparse/least-squares sampling front-end: degree decoupled from the tensor
# grid. A total-degree-d fit from ~oversample·binom(d+n,n) scattered points instead of
# (d+1)^n tensor points, routed through lambda_vandermonde_original and Monte-Carlo
# quadrature for nrm.

using Test
using Globtim
using Random
using LinearAlgebra

@testset "generate_sparse_samples" begin
    rng = Random.MersenneTwister(11)
    S = generate_sparse_samples(3, 4; oversample = 2.0, measure = :chebyshev, rng = rng)
    @test size(S) == (2 * binomial(7, 3), 3)      # ceil(2.0 * 35) = 70 points
    @test all(-1.0 .<= S .<= 1.0)

    Su = generate_sparse_samples(2, 3; oversample = 1.5, measure = :uniform, rng = rng)
    @test size(Su, 1) == ceil(Int, 1.5 * binomial(5, 2))
    @test all(-1.0 .<= Su .<= 1.0)

    # arcsine density concentrates near ±1 relative to uniform
    Sc = generate_sparse_samples(1, 60; oversample = 4.0, measure = :chebyshev, rng = rng)
    @test count(abs.(Sc) .> 0.9) / length(Sc) > 0.2   # uniform would give ~0.1

    @test_throws ArgumentError generate_sparse_samples(3, 4; oversample = 0.5)
    @test_throws ArgumentError generate_sparse_samples(3, 4; measure = :sobol)
    @test_throws ArgumentError generate_sparse_samples(0, 4)
end

@testset "non-tensor Constructor: degree is authoritative" begin
    Random.seed!(42)
    # f is itself degree 4 in 3D — the degree-4 sparse LS fit must reproduce it exactly,
    # which is only possible if the requested degree survives (the legacy tensor inference
    # would silently lower degree to round(70^(1/3))-1 = 3 and fail).
    f = x -> 1.0 + 0.5x[1] - 2x[2] * x[3] + x[1]^2 * x[2]^2 - 0.3x[3]^4 + x[1] * x[2] * x[3]
    TR = TestInput(f; dim = 3, center = zeros(3), sample_range = 1.0, tolerance = nothing)
    S = generate_sparse_samples(3, 4; oversample = 2.0, measure = :chebyshev)
    p = Constructor(TR, 4; grid = S, grid_mode = :nontensor, sample_measure = :chebyshev)

    @test p.degree == (:one_d_for_all, 4)
    @test p.N == size(S, 1)
    @test p.nrm < 1e-10                            # exact recovery of a degree-4 polynomial
    @test p.cond_vandermonde < 1e4                 # arcsine sampling keeps LS well-conditioned

    # scattered evaluation matches f (fit is exact, so w(x) == f(x) pointwise)
    for _ in 1:5
        x = 2.0 .* rand(3) .- 1.0
        @test isapprox(Globtim.evaluate(p, x), f(x); atol = 1e-9)
    end
end

@testset "non-tensor Constructor: guards" begin
    f = x -> sum(abs2, x)
    TR = TestInput(f; dim = 3, center = zeros(3), sample_range = 1.0, tolerance = nothing)
    S = generate_sparse_samples(3, 4; oversample = 2.0)

    # fewer points than basis functions must error, not silently lower the degree
    @test_throws ErrorException Constructor(TR, 8; grid = S, grid_mode = :nontensor)
    # :nontensor without a grid is a contradiction
    @test_throws ArgumentError Constructor(TR, 4; grid_mode = :nontensor)
    @test_throws ArgumentError Constructor(TR, 4; grid = S, grid_mode = :scattered)
end

@testset "sparse fit quality tracks the tensor fit at equal degree" begin
    Random.seed!(7)
    g = x -> exp(-(x[1]^2 + 2x[2]^2)) + 0.1 * sin(3x[1])
    TR = TestInput(g; dim = 2, center = zeros(2), sample_range = 1.0, GN = 8, tolerance = nothing)
    pt = Constructor(TR, 8)                                       # tensor: 81 evals
    S = generate_sparse_samples(2, 8; oversample = 2.0, measure = :chebyshev)
    ps = Constructor(TR, 8; grid = S, grid_mode = :nontensor, sample_measure = :chebyshev)

    @test ps.nrm < 5 * pt.nrm                      # same accuracy class as the tensor fit
    @test ps.cond_vandermonde < 1e5

    # The eval saving is dimensional: in 2D at d=8 the sparse set (2·45=90) EXCEEDS the 81-pt
    # tensor grid — the front-end pays off from 3D up, and explodes with dimension.
    n_sparse(n, d; c = 2.0) = ceil(Int, c * binomial(n + d, n))
    @test n_sparse(2, 8) > 81                      # 2D: not the use case
    @test n_sparse(3, 8) < 9^3                     # 330 vs 729
    @test n_sparse(5, 6) < 7^5                     # 924 vs 16807 (18x)
    @test n_sparse(8, 6) < 7^8                     # ~6k vs 5.76M (960x)
end

@testset "compute_norm_scattered measures" begin
    # residual ≡ 1 integrates to the domain volume: nrm = sqrt(2^n) on [-1,1]^n
    n = 2
    S = generate_sparse_samples(n, 3; oversample = 8.0, measure = :chebyshev,
                                rng = Random.MersenneTwister(3))
    VL = ones(size(S, 1), 1)
    sol = (u = [1.0],)
    F = zeros(size(S, 1))
    nrm_c = compute_norm_scattered(1.0, VL, sol, F, :chebyshev, S)
    @test isapprox(nrm_c, 2.0; rtol = 0.15)        # MC estimate of sqrt(4)

    Su = generate_sparse_samples(n, 3; oversample = 8.0, measure = :uniform,
                                 rng = Random.MersenneTwister(3))
    VLu = ones(size(Su, 1), 1)
    nrm_u = compute_norm_scattered(1.0, VLu, sol, zeros(size(Su, 1)), :uniform, Su)
    @test isapprox(nrm_u, 2.0; atol = 1e-12)       # uniform weights are exact for a constant

    # vector scale multiplies mass by prod(scale): sqrt(4 * 0.5 * 0.25) = 0.7071
    nrm_v = compute_norm_scattered([0.5, 0.25], VLu, sol, zeros(size(Su, 1)), :uniform, Su)
    @test isapprox(nrm_v, sqrt(4 * 0.5 * 0.25); atol = 1e-12)

    @test_throws ArgumentError compute_norm_scattered(1.0, VLu, sol, F, :sobol, Su)
end
