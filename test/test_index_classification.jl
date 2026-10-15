# classify_with_index / poincare_hopf_sum (hessian_analysis.jl): scale-aware Morse index
# classification with an explicit :ambiguous state, against the absolute-tolerance
# classify_critical_points it complements.

using Test
using Globtim
using LinearAlgebra
using ForwardDiff

@testset "index classification" begin
    @testset "synthetic Hessians" begin
        Hs = [
            Matrix(Diagonal([1.0, 2.0])),          # minimum
            Matrix(Diagonal([-1.0, -2.0])),        # maximum
            Matrix(Diagonal([1.0, -1.0])),         # saddle, index 1
            Matrix(Diagonal([1e6, 1e-3])),         # 1e-3 is 1e-9 of ‖H‖: inside the band
            Matrix(Diagonal([1e-6, -1e-6])),       # tiny but decided: both clear 1e-8·‖H‖
            [NaN 0.0; 0.0 1.0],                    # failed Hessian
        ]
        cl = classify_with_index(Hs; rel_tol = 1e-8)
        @test [c.class for c in cl] == [:minimum, :maximum, :saddle, :ambiguous, :saddle, :error]
        @test morse_index(cl[1]) == 0
        @test morse_index(cl[2]) == 2
        @test morse_index(cl[3]) == 1
        @test (cl[4].index_low, cl[4].index_high, cl[4].n_band) == (0, 1, 1)
        @test cl[4].band ≈ 1e-2
        @test cl[4].min_abs_eig ≈ 1e-3
        @test_throws ArgumentError morse_index(cl[4])
        @test cl[5].band ≈ 1e-14 && morse_index(cl[5]) == 1
        @test cl[6].class == :error && isnan(cl[6].band)
        @test all(isnan(c.grad_norm) for c in cl)

        # the absolute-tolerance classifier: at its default 1e-8 it calls the 1e6/1e-3
        # Hessian a minimum (1e-3 clears the absolute tolerance although it is 1e-9 of
        # ‖H‖); at an absolute 1e-5, a natural choice for ‖H‖ ~ 1 landscapes, it calls the
        # 1e-6/-1e-6 one degenerate. The two failure modes the relative band fixes.
        old = classify_critical_points(Hs[[4, 5]]; tol_zero = 1e-8, tol_pos = 1e-8, tol_neg = 1e-8)
        @test old == [:minimum, :saddle]
        old5 = classify_critical_points(Hs[[4, 5]]; tol_zero = 1e-5, tol_pos = 1e-5, tol_neg = 1e-5)
        @test old5 == [:minimum, :degenerate]
        @test classify_with_index(Hs[[5]]; rel_tol = 1e-8)[1].class == :saddle

        # abs_tol widens the band; rel_tol = 0 with abs_tol reproduces an absolute rule
        cl_abs = classify_with_index(Hs[[3, 5]]; rel_tol = 0.0, abs_tol = 1e-5)
        @test cl_abs[1].class == :saddle
        @test cl_abs[2].class == :ambiguous && cl_abs[2].n_band == 2
        @test (cl_abs[2].index_low, cl_abs[2].index_high) == (0, 2)

        @test_throws ArgumentError classify_with_index(Hs; rel_tol = -1.0)
        @test_throws ArgumentError classify_with_index(Hs; grad_norms = [1.0])
    end

    @testset "poincare_hopf_sum" begin
        Hs = [Matrix(Diagonal([1.0, 1.0])), Matrix(Diagonal([1.0, 1.0])), Matrix(Diagonal([1.0, -1.0]))]
        s = poincare_hopf_sum(classify_with_index(Hs))
        @test s.sum == 1 && s.exact && s.n_decided == 3 && s.lower == s.upper == 1
        # one ambiguous point widens the bounds by one either way
        push!(Hs, Matrix(Diagonal([1.0, 1e-12])))
        s2 = poincare_hopf_sum(classify_with_index(Hs))
        @test s2.sum == 1 && !s2.exact && s2.n_ambiguous == 1 && (s2.lower, s2.upper) == (0, 2)
        # a non-stationary point is excluded, not counted
        cl = classify_with_index(Hs[1:3]; grad_norms = [0.0, 1.0, 0.0], grad_tol = 1e-8)
        @test cl[2].class == :nonstationary
        s3 = poincare_hopf_sum(cl)
        @test s3.sum == 0 && s3.n_excluded == 1 && !s3.exact
    end

    @testset "true-objective method on a 2-D Morse function" begin
        f(x) = (x[1]^2 - 1)^2 + 3 * x[2]^2          # minima (±1,0), saddle (0,0): Σ(−1)^index = 1
        pts = [1.0 0.0; -1.0 0.0; 0.0 0.0]
        cl = classify_with_index(f, pts)
        @test [c.class for c in cl] == [:minimum, :minimum, :saddle]
        @test all(c.grad_norm < 1e-12 for c in cl)
        @test poincare_hopf_sum(cl).sum == 1
        # a Hessian-typed "minimum" on a box face with ‖∇f‖ = O(1) is not counted
        pts2 = [1.0 0.0; 0.5 0.0]
        cl2 = classify_with_index(f, pts2; grad_tol = 1e-8)
        @test cl2[2].class == :nonstationary
        @test cl2[2].grad_norm ≈ norm(ForwardDiff.gradient(f, [0.5, 0.0]))
        # the index-only view of the same point (no grad_tol) is a saddle: f'' < 0 at x1 = 0.5
        cl3 = classify_with_index(f, pts2)
        @test cl3[2].class == :saddle
    end
end
