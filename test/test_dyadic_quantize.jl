# dyadic_quantize (poly_solver.jl): common-denominator rounding of Float64 coefficients
# before the exact Chebyshev → monomial conversion that feeds msolve.

using Test
using Globtim

@testset "dyadic_quantize" begin
    c = [1.0, -0.37, 2.5e-3, 7.1e-9, 0.0, 1e-13]

    @testset "rel_tol = 0 is the exact conversion" begin
        q = dyadic_quantize(c; rel_tol = 0.0)
        @test q == [Rational{BigInt}(x) for x in c]
        @test eltype(q) == Rational{BigInt}
        # exact conversion keeps every bit: 7.1e-9 has an 80-bit denominator, 1e-13 a 95-bit one
        @test denominator(q[4]) == big(2)^80
        @test denominator(q[6]) == big(2)^95
    end

    @testset "rounding error and common denominator" begin
        tol = 1e-14
        q = dyadic_quantize(c; rel_tol = tol)
        cmax = maximum(abs, c)
        @test all(abs(Float64(q[i] - Rational{BigInt}(c[i]))) <= tol * cmax / 2 for i in eachindex(c))
        # every denominator divides one common power of two ≤ 2^ceil(-log2(tol*cmax))
        b = ceil(Int, -log2(tol * cmax))
        D = big(2)^b
        @test all(denominator(x) ≤ D && D % denominator(x) == 0 for x in q)
        @test b <= 48
        # the big coefficient is unchanged (it was already on the grid)
        @test q[1] == 1
        @test q[5] == 0
        # the 1e-13 entry is below the grid spacing 2^-b ≈ 3.6e-15·… and rounds to a grid point
        @test abs(Float64(q[6]) - 1e-13) <= 2.0^(-b - 1)
    end

    @testset "explicit bits" begin
        q = dyadic_quantize(c; bits = 20)
        @test all(denominator(x) ≤ big(2)^20 for x in q)
        @test q[4] == 0                      # 7.1e-9 < 2^-21
        @test abs(Float64(q[2]) + 0.37) <= 2.0^(-21)
        @test dyadic_quantize(Float64[]; rel_tol = 1e-12) == Rational{BigInt}[]
        @test all(iszero, dyadic_quantize(zeros(3); rel_tol = 1e-12))
        @test_throws ArgumentError dyadic_quantize(c; rel_tol = -1.0)
        @test_throws ArgumentError dyadic_quantize(c; bits = -1)
    end

    @testset "rational input passes through" begin
        r = [1 // 3, -2 // 7]
        q = dyadic_quantize(r; rel_tol = 0.0)
        @test q == Rational{BigInt}.(r)
        q2 = dyadic_quantize(r; bits = 10)
        @test all(denominator(x) ≤ 1024 for x in q2)
        @test abs(Float64(q2[1] - 1 // 3)) <= 2.0^(-11)
    end
end
