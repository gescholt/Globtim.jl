# Bead acqq: `power_of_two_denom = true` threw UndefVarError the first time the
# branch ran, because `Polynomial` is exported by both DynamicPolynomials and
# MultivariatePolynomials and the bare name is ambiguous inside Globtim. The
# branch had never executed; these tests make it execute.

using Test
using Globtim
using DynamicPolynomials: @polyvar
using MultivariatePolynomials: coefficients, terms, coefficient, monomial

_pow2(q::Rational) = ispow2(denominator(q))
# The helper rounds to the nearest numerator over the smallest power of two
# not below the original denominator, so the error is at most half a unit of
# the new denominator and the denominator at most doubles.
function _rounded_ok(q::Rational, r::Rational)
    _pow2(q) && abs(q - r) <= 1 // (2 * denominator(q)) && denominator(q) < 2 * denominator(r)
end

@testset "power_of_two_denom (acqq)" begin
    @testset "scalar and pass-through" begin
        q = Globtim._convert_to_power_of_two_denom(1 // 3)
        @test q isa Rational{Int}
        @test _rounded_ok(q, 1 // 3)
        @test Globtim._convert_to_power_of_two_denom(0.25) === 0.25
        @test Globtim._convert_to_power_of_two_denom(3 // 8) == 3 // 8
        # BigInt path, exact for large denominators.
        r_big = Rational{BigInt}(big(7)^40, big(3)^50)
        qb = Globtim._convert_to_power_of_two_denom(r_big)
        @test qb isa Rational{BigInt}
        @test _rounded_ok(qb, r_big)
        @test Globtim._convert_to_power_of_two_denom(big(5) // big(2)^80) == big(5) // big(2)^80
    end

    @testset "polynomial coefficients" begin
        @polyvar x y
        p = (1 // 3) * x^2 * y + (2 // 5) * x - 7 // 6
        q = Globtim._convert_to_power_of_two_denom(p)
        @test length(terms(q)) == length(terms(p))
        for (tp, tq) in zip(terms(p), terms(q))
            @test monomial(tp) == monomial(tq)
            @test _rounded_ok(coefficient(tq), coefficient(tp))
        end
    end

    @testset "symbolic_chebyshev with the flag set" begin
        # Unnormalized T_3 = 4x^3 - 3x has integer coefficients; the flag must
        # leave it exact.
        T3 = Globtim.symbolic_chebyshev(
            3;
            precision = Globtim.RationalPrecision,
            normalized = false,
            power_of_two_denom = true,
        )
        @test all(_pow2, filter(c -> c isa Rational, coefficients(T3)))
        @test all(c -> c isa Rational, coefficients(T3))
        @test sort(coefficients(T3)) == sort([4 // 1, -3 // 1])

        # The normalized path must not throw either (this is the call that
        # threw before the fix); every rational coefficient is dyadic after it.
        T4 = Globtim.symbolic_chebyshev(
            4;
            precision = Globtim.RationalPrecision,
            normalized = true,
            power_of_two_denom = true,
        )
        @test all(_pow2, filter(c -> c isa Rational, coefficients(T4)))
    end
end
