# test_rational_approx.jl — Phase 1 of the rational-surrogate brief
# (docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md, bead B1): the linear-algebra fit
# r = p/q of Austin et al., CPC 261 (2021) §3, with the degree reduction of
# their Algorithm 3.3, wrapped as `ApproxRational` / `RationalConstructor`.
#
# No HomotopyContinuation here — pure linear algebra against closed-form
# objectives.

using Test
using Globtim
using LinearAlgebra
using ForwardDiff
using Random: Xoshiro

# f is a genuine rational function of type (2,2): the fit must be exact.
f_rat(x) = (1 + x[1] + x[2]^2) / (2 + x[1]^2 + x[2]^2)

# Pole pair just outside the box plus a smooth ripple: the motivating example.
f_pole(x) = 1 / ((x[1] - 1.15)^2 + (x[2] - 0.30)^2 + 0.04) + sin(3x[1]) * cos(2x[2])

@testset "rational_ls_fit / RationalConstructor" begin
    TR = TestInput(f_rat; dim = 2, center = [0.0, 0.0], sample_range = 1.0)

    @testset "exact recovery of a (2,2) rational" begin
        R = RationalConstructor(TR, 2, 2)
        @test R isa ApproxRational
        @test R.M == 2 && R.N == 2
        @test R.nrm < 1e-10
        @test R.rms < 1e-10
        @test R.sigma_ratio < 1e-10
        @test isfinite(R.qmin_grid) && R.qmin_grid > 0
        @test size(R.grid, 2) == 2
        @test length(R.z) == size(R.grid, 1)
        # the fit reproduces f pointwise, in surrogate coordinates
        for x in ([0.3, -0.7], [-0.95, 0.1], [0.0, 0.0])
            @test R(x) ≈ f_rat(x) atol = 1e-10
            @test rational_numerator(R, x) / rational_denominator(R, x) ≈ f_rat(x) atol =
                1e-10
        end
        # normalisation: mean of q on the grid is 1 (sign and scale fixed)
        @test abs(sum(rational_denominator(R, R.grid[i, :]) for i in 1:size(R.grid, 1)) /
                  size(R.grid, 1) - 1) < 1e-12
    end

    @testset "degree reduction (Algorithm 3.3)" begin
        # (M,N) = (4,4): every (p_true·s, q_true·s) with deg s ≤ 2 solves the
        # linearised problem, so the null space of W has dimension 6 and the
        # second singular value is zero → reduce N until the null space is a line.
        R = RationalConstructor(TR, 4, 4; reduce = true)
        @test R.N == 2
        @test R.M == 4
        @test R.nrm < 1e-8
        # brief §2 B1 test 2 asks for (M,N) = (2,4) here, but with M = 2 the
        # only solutions are s = const (deg p = 2 + deg s ≤ 2), the null space
        # is one-dimensional and the reduction criterion does not fire. Record
        # that as a test rather than let it look like a bug.
        R24 = RationalConstructor(TR, 2, 4; reduce = true)
        @test R24.N == 4
        @test R24.nrm < 1e-8
        # reduce = false keeps the requested N and still fits exactly
        R_nored = RationalConstructor(TR, 4, 4; reduce = false)
        @test R_nored.N == 4
        @test R_nored.nrm < 1e-8
        @test R_nored.singular_values[end-1] < 1e-10 * R_nored.singular_values[1]
    end

    @testset "polynomial special case N = 0 matches Constructor" begin
        g(x) = exp(0.3x[1]) * cos(x[2]) + x[1]^2 * x[2]
        TRg = TestInput(g; dim = 2, center = [0.1, -0.2], sample_range = 0.8, GN = 10)
        pol = Constructor(TRg, 5)
        R = RationalConstructor(TRg, 5, 0)
        @test R.N == 0
        @test R.M == 5
        @test length(R.b) == 1
        @test R.b[1] ≈ 1.0 atol = 1e-12                      # q ≡ 1 after normalisation
        @test length(R.a) == length(pol.coeffs)
        @test maximum(abs.(R.a .- pol.coeffs)) < 1e-10
        @test R.normalized == pol.normalized
        @test R.grid == pol.grid
        @test R.z == pol.z
        @test R.nrm ≈ pol.nrm rtol = 1e-8                     # same quadrature-weighted L2
        # evaluation in original coordinates agrees with Globtim.evaluate
        xo = [0.4, -0.5]
        @test Globtim.evaluate(R, xo) ≈ Globtim.evaluate(pol, xo) atol = 1e-10
        @test Globtim.evaluate(R, xo) ≈ R(to_surrogate_coordinates(R, xo)) atol = 1e-12
        @test to_original_coordinates(R, to_surrogate_coordinates(R, xo)) ≈ xo atol = 1e-14
    end

    @testset "pole pair: rational (8,4) beats polynomial 20 at a quarter of the dof" begin
        TRp = TestInput(f_pole; dim = 2, center = [0.0, 0.0], sample_range = 1.0, GN = 24)
        R = RationalConstructor(TRp, 8, 4)
        pol = Constructor(TRp, 20)
        @test R.M == 8 && R.N == 4
        @test R.nrm < pol.nrm
        @test R.qmin_grid > 0
        @test isfinite(R.sigma_ratio) && isfinite(R.nrm) && isfinite(R.qmin_grid)
        dof_R = binomial(2 + 8, 8) + binomial(2 + 4, 4) - 1
        dof_P = binomial(2 + 20, 20)
        @test dof_R < dof_P ÷ 2
        # max pointwise error on a fine independent lattice: reference numbers in
        # the brief are 1.5e-2 (rational) vs 1.35e-1 (polynomial)
        xs = range(-1, 1; length = 41)
        errR = maximum(abs(R([u, v]) - f_pole([u, v])) for u in xs, v in xs)
        errP = maximum(abs(Globtim.evaluate(pol, [u, v]) - f_pole([u, v])) for u in xs, v in xs)
        @test errR < errP
        @test errR < 5e-2
    end

    @testset "grid selection by the oversample rule" begin
        # α(8)+α(4) = 45+15 = 60 in 2-D; oversample 2 → 120 points → GN+1 = 11
        TRp = TestInput(f_pole; dim = 2, center = [0.0, 0.0], sample_range = 1.0)
        R = RationalConstructor(TRp, 8, 4)
        @test R.GN == 10
        @test size(R.grid, 1) == 11^2
        R3 = RationalConstructor(TRp, 8, 4; oversample = 3)
        @test (R3.GN + 1)^2 >= 180 && R3.GN^2 < 180
        # an explicit GN kwarg wins over the rule and over TR.GN
        R_gn = RationalConstructor(TRp, 8, 4; GN = 14)
        @test R_gn.GN == 14
        # GN + 1 nodes determine degree ≤ GN only: the rule is raised to max(M,N)
        # (3-D (8,4): oversample 2 wants 8 nodes, the zeros of T_8, on which every
        # degree-8 basis function vanishes — observed as 0 real HC solutions)
        TR3 = TestInput(x -> sum(abs2, x); dim = 3, center = zeros(3), sample_range = 1.0)
        R3d = RationalConstructor(TR3, 8, 4)
        @test R3d.GN == 8
        @test_throws ArgumentError RationalConstructor(TR3, 8, 4; GN = 7)
        # the same hazard through TR.GN is refused too, and the fit itself refuses a
        # rank-deficient Vandermonde
        TR3g = TestInput(x -> sum(abs2, x); dim = 3, center = zeros(3), sample_range = 1.0, GN = 7)
        @test_throws ArgumentError RationalConstructor(TR3g, 8, 4)
        S = Globtim._grid_matrix(2, 3, :chebyshev)                 # 4 nodes: zeros of T_4
        V_M = Globtim.lambda_vandermonde(SupportGen(2, (:one_d_for_all, 4)), S)  # includes T_4 columns
        V_N = ones(size(S, 1), 1)
        @test_throws ErrorException rational_ls_fit(V_M, V_N, ones(size(S, 1)))
    end

    @testset "evaluation helpers are ForwardDiff-compatible" begin
        R = RationalConstructor(TR, 2, 2)
        x0 = [0.2, -0.4]
        g_R = ForwardDiff.gradient(R, x0)
        g_f = ForwardDiff.gradient(f_rat, x0)
        @test g_R ≈ g_f atol = 1e-9
        H_R = ForwardDiff.hessian(R, x0)
        H_f = ForwardDiff.hessian(f_rat, x0)
        @test H_R ≈ H_f atol = 1e-8
    end

    @testset "input validation" begin
        @test_throws ArgumentError RationalConstructor(TR, -1, 2)
        @test_throws ArgumentError RationalConstructor(TR, 2, -1)
        @test_throws ArgumentError RationalConstructor(TR, 2, 2; basis = :monomial)
        # a normalized flag that contradicts the basis convention is refused,
        # not silently honoured (the classic Vandermonde/monomial mismatch)
        @test_throws ArgumentError RationalConstructor(TR, 2, 2; normalized = true)
        # rational_ls_fit refuses a system with fewer rows than unknowns
        @test_throws ArgumentError rational_ls_fit(ones(3, 4), ones(3, 2), ones(3))
    end

    @testset "sign-changing q: zero mean is reported, not an error" begin
        # p/q = (a₁x + a₃x³)/(b₁x) = 1 + x² exactly with q = b₁x: an odd q on a
        # symmetric grid has zero mean, so the mean = 1 normalisation is impossible
        xs = collect(range(-1, 1; length = 21))
        V_M = [xs xs .^ 3]
        V_N = reshape(xs, :, 1)
        fit = rational_ls_fit(V_M, V_N, 1 .+ xs .^ 2)
        @test fit.normalization == :maxabs
        @test maximum(abs, V_N * fit.b) ≈ 1
        @test minimum(V_N * fit.b) < 0 < maximum(V_N * fit.b)
        @test maximum(abs.((V_M * fit.a) ./ (V_N * fit.b) .- (1 .+ xs .^ 2))[xs .!= 0]) < 1e-10
        # the mean convention holds in the generic case
        TRg = TestInput(f_rat; dim = 2, center = [0.0, 0.0], sample_range = 1.0)
        @test RationalConstructor(TRg, 2, 2).q_normalization == :mean
    end

    @testset "Legendre basis" begin
        R = RationalConstructor(TR, 2, 2; basis = :legendre)
        @test R.basis == :legendre
        @test R.normalized == true
        @test R.nrm < 1e-10
        @test R([0.3, -0.7]) ≈ f_rat([0.3, -0.7]) atol = 1e-10
    end

    @testset "scattered samples (sampling = :christoffel)" begin
        # the (2,2) rational is recovered exactly from 3 samples per unknown
        R = RationalConstructor(TR, 2, 2; sampling = :christoffel, n_samples = 36, rng = Xoshiro(1))
        @test R.sampling == :christoffel
        @test R.GN == -1
        @test size(R.grid) == (36, 2)
        @test length(R.sample_weights) == 36 && all(>(0), R.sample_weights)
        @test R.nrm < 1e-10
        @test R.sigma_ratio < 1e-10
        for x in ([0.3, -0.7], [-0.95, 0.1])
            @test R(x) ≈ f_rat(x) atol = 1e-10
        end
        # replayable: the same generator state gives the same points and coefficients
        R2 = RationalConstructor(TR, 2, 2; sampling = :christoffel, n_samples = 36, rng = Xoshiro(1))
        @test R2.grid == R.grid && R2.a == R.a && R2.b == R.b
        @test RationalConstructor(TR, 2, 2; sampling = :christoffel, n_samples = 36, rng = Xoshiro(2)).grid != R.grid
        # the grid path is unchanged and says so
        Rg = RationalConstructor(TR, 2, 2)
        @test Rg.sampling == :grid && all(==(1.0), Rg.sample_weights)

        # pole pair at 4 samples per unknown (240 points, 38 % of the 25² grid): the
        # residual on the grid matches the grid fit's, and q stays positive there
        TRp = TestInput(f_pole; dim = 2, center = [0.0, 0.0], sample_range = 1.0, GN = 24)
        Rp = RationalConstructor(TRp, 8, 4)
        Rc = RationalConstructor(TRp, 8, 4; sampling = :christoffel, n_samples = 240, rng = Xoshiro(1))
        S = Rp.grid
        w = Globtim.compute_quadrature_weights(:chebyshev, 24, 2)
        grid_nrm = sqrt(sum(w[i] * (Rc(S[i, :]) - f_pole(S[i, :]))^2 for i in 1:size(S, 1)))
        @test grid_nrm < 2 * Rp.nrm
        @test minimum(rational_denominator(Rc, S[i, :]) for i in 1:size(S, 1)) > 0

        # weights of one are the unweighted fit
        xs = collect(range(-1, 1; length = 30))
        V_M = hcat(ones(30), xs, xs .^ 2)
        V_N = hcat(ones(30), xs)
        zz = (1 .+ xs) ./ (2 .+ xs)
        f0 = rational_ls_fit(V_M, V_N, zz)
        f1 = rational_ls_fit(V_M, V_N, zz; sqrt_w = ones(30))
        @test f0.a ≈ f1.a && f0.b ≈ f1.b

        # everything the scattered path needs is explicit
        @test_throws ArgumentError RationalConstructor(TR, 2, 2; sampling = :christoffel, n_samples = 36)
        @test_throws ArgumentError RationalConstructor(TR, 2, 2; sampling = :christoffel, rng = Xoshiro(1))
        @test_throws ArgumentError RationalConstructor(TR, 2, 2; sampling = :christoffel, n_samples = 11, rng = Xoshiro(1))
        @test_throws ArgumentError RationalConstructor(TR, 2, 2; sampling = :christoffel, n_samples = 36, rng = Xoshiro(1), GN = 10)
        @test_throws ArgumentError RationalConstructor(TR, 2, 2; sampling = :christoffel, n_samples = 36, rng = Xoshiro(1), basis = :legendre)
        @test_throws ArgumentError RationalConstructor(TR, 2, 2; sampling = :sparse)
        @test_throws ArgumentError RationalConstructor(TR, 2, 2; n_samples = 36)
        @test_throws ArgumentError rational_ls_fit(V_M, V_N, zz; sqrt_w = zeros(30))
    end

    @testset "1-D objective (MargulesTPD, scalar call convention)" begin
        TR1 = TestInput(MargulesTPD; dim = 1, center = [0.0], sample_range = 5.0, GN = 40)
        R = RationalConstructor(TR1, 8, 4)
        @test size(R.grid, 2) == 1
        @test isfinite(R.nrm)
        w = 1.3
        @test abs(Globtim.evaluate(R, [w]) - MargulesTPD(w)) < 0.2
    end
end
