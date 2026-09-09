"""
Level-6 polynomial approximation quality tests.

L7 asked whether HC finds every critical point of the polynomial system, and
deliberately used fixtures where the approximation is EXACT so that solver
completeness was the only variable. L6 removes that assumption and asks the
complementary question: is the approximation good enough for critical-point
finding, and how does that depend on degree, grid resolution and domain size?

Two fixtures, chosen so each isolates one behaviour:

  EXACT-AT-A-KNOWN-DEGREE — p(x) = Σ q(xᵢ) with q(t) = t⁴ - t².
  Its gradient decouples into per-axis cubics with roots {0, ±1/√2}, so there are
  exactly 3ⁿ critical points, known analytically. Because p is degree 4, a
  degree-d Chebyshev fit is poor for d < 4 and exact for d ≥ 4. That gives a sharp,
  predictable transition: the minimum capturing degree is 4, and it is knowable in
  advance rather than read off the output.

  NEVER-EXACT — the 2D Runge function 1/(1 + 25‖x‖²). No finite polynomial
  represents it, so its L2 error decays geometrically instead of collapsing, which
  is what makes a convergence RATE measurable.

`normalized = false` throughout, the coefficient-preserving convention.

Self-contained by design: no include of the ground-truth tables in
globtimpostprocessing/test. globtim ships to the public mirror and its tests must
run from the package's own environment (pre-push Layers 0.6/0.7).
"""

using Test
using Globtim
using DynamicPolynomials
using HomotopyContinuation
using LinearAlgebra

# ── Fixtures ─────────────────────────────────────────────────────────────────

_q(t) = t^4 - t^2
_quartic(v) = sum(_q, v)                     # degree 4, 3ⁿ critical points
_runge(v) = 1 / (1 + 25 * sum(abs2, v))      # not a polynomial at any degree

const _EXACT_DEGREE = 4                      # degree at which _quartic is representable

function _analytic_cps(n::Int)
    roots = [0.0, 1 / sqrt(2), -1 / sqrt(2)]
    return [collect(p) for p in Iterators.product(ntuple(_ -> roots, n)...)] |> vec
end

_fit(f, n::Int, d::Int; GN::Int = 20, range::Float64 = 1.0) = Constructor(
    TestInput(f, dim = n, center = zeros(n), GN = GN, sample_range = range),
    d;
    basis = :chebyshev,
    normalized = false,
)

"Fit at degree `d`, solve, and score against the analytic critical points."
function _capture(f, n::Int, d::Int; GN::Int = 20)
    pol = _fit(f, n, d; GN = GN)
    @polyvar x[1:n]
    cps =
        solve_polynomial_system(x, n, d, pol.coeffs; basis = :chebyshev, normalized = false)
    in_box = filter(p -> all(abs.(p) .<= 1.0 + 1e-8), cps)
    expected = _analytic_cps(n)
    found = count(e -> any(c -> norm(c .- e) < 1e-6, in_box), expected)
    return (
        l2 = pol.nrm,
        cond = pol.cond_vandermonde,
        n_in_box = length(in_box),
        recall = found / length(expected),
        spurious = length(in_box) - found,   # in-box CPs matching no true CP
    )
end

@testset "L6 Approximation Quality" begin

    # ========================================================================
    # 6a — L2 error convergence with degree
    # ========================================================================

    @testset "exact-at-degree-4: L2 collapses at the representable degree" begin
        below = _fit(_quartic, 2, 2).nrm
        at = _fit(_quartic, 2, _EXACT_DEGREE).nrm
        above = _fit(_quartic, 2, 8).nrm

        @test below > 1e-3          # a degree-2 fit cannot represent t⁴
        @test at < 1e-12            # ~9e-16 measured
        @test above < 1e-12         # padding degree does not degrade it
        @test at < below / 1e10     # the transition is a collapse, not a slope

        # Odd degrees buy nothing here: q is even, so degree 3 adds only odd
        # basis functions and lands on the same error as degree 2.
        @test isapprox(_fit(_quartic, 2, 3).nrm, below; rtol = 1e-6)
    end

    @testset "runge: L2 decays geometrically in degree" begin
        degrees = 4:2:14
        errs = [_fit(_runge, 2, d; GN = 30).nrm for d in degrees]

        @test all(diff(errs) .< 0)                    # strictly decreasing
        ratios = errs[2:end] ./ errs[1:(end-1)]
        # Measured ratios per +2 degrees: 0.747, 0.743, 0.743, 0.743, 0.742 —
        # a stable geometric rate, which is the signature of Chebyshev
        # convergence for an analytic function with poles off the interval.
        @test all(0.6 .< ratios .< 0.85)
        @test maximum(ratios) - minimum(ratios) < 0.05   # rate is stable, not drifting
    end

    # ========================================================================
    # 6b/6c/6d — CP correspondence, minimum capturing degree, spurious count
    # ========================================================================

    @testset "capture vs degree: nothing below the representable degree, all at it" begin
        results = Dict(d => _capture(_quartic, 2, d) for d in (2, 3, 4, 6))

        # Below: not a single true critical point is recovered, and everything
        # the solver does return in-box is spurious. Worth asserting explicitly —
        # an under-resolved fit does not degrade gracefully here, it produces
        # confident nonsense.
        for d in (2, 3)
            @test results[d].recall == 0.0
            @test results[d].spurious == results[d].n_in_box
            @test results[d].n_in_box > 0
        end

        # At and above: everything, with nothing extra.
        for d in (4, 6)
            @test results[d].recall == 1.0
            @test results[d].spurious == 0
            @test results[d].n_in_box == 9
        end
    end

    @testset "minimum capturing degree equals the representable degree" begin
        # The quantity of interest, computed rather than asserted from a
        # constant: sweep upward and take the first degree with full recall.
        min_deg = nothing
        for d in 2:6
            if _capture(_quartic, 2, d).recall == 1.0
                min_deg = d
                break
            end
        end
        @test min_deg == _EXACT_DEGREE
    end

    # ========================================================================
    # 6e — grid resolution (GN) sensitivity
    # ========================================================================

    @testset "GN: once the grid supports the basis, more points do not help" begin
        # Measured L2 across GN = 5…40 at degree 4: all ~1e-16. The honest claim
        # is that accuracy is already at machine precision and stays there — NOT
        # that it improves with GN, which it does not for an exactly
        # representable target.
        for gn in (5, 8, 20, 40)
            r = _fit(_quartic, 2, 4; GN = gn)
            @test r.nrm < 1e-12
            @test r.N >= 25          # grid must at least support the coefficient count
        end
        # Recovery is likewise GN-insensitive here.
        @test _capture(_quartic, 2, 4; GN = 8).recall == 1.0
        @test _capture(_quartic, 2, 4; GN = 30).recall == 1.0
    end

    # ========================================================================
    # 6f — domain size sensitivity
    # ========================================================================

    @testset "domain size: a smaller box is easier, but NOT monotonically" begin
        errs = Dict(r => _fit(_runge, 2, 4; range = r).nrm for r in (0.25, 0.5, 1.0, 2.0))

        # The strong, reliable part: shrinking the domain by 4× makes the Runge
        # feature much easier to fit.
        @test errs[0.25] < errs[1.0] / 2

        # The part that would be wrong to assert: monotonicity. Measured
        # 0.051 → 0.141 → 0.169 → 0.148, so error PEAKS near range 1.0 and then
        # falls again as the domain outgrows the 1/(1+25r²) feature. Asserting
        # "bigger domain ⇒ worse fit" would encode a plausible story the data
        # refutes.
        @test errs[2.0] < errs[1.0]
    end

    # ========================================================================
    # 6g — condition number monitoring
    # ========================================================================

    @testset "Vandermonde conditioning stays bounded across degree and GN" begin
        # Measured: cond ≈ 4.0 at every degree 2…14 and every GN 5…40. Chebyshev
        # coefficients on this grid are well conditioned, so the assertion is a
        # bound, not a growth law — the test exists to catch a regression that
        # introduces ill-conditioning, not to describe a trend that is absent.
        for d in (2, 4, 8, 14)
            @test _fit(_runge, 2, d; GN = 30).cond_vandermonde < 100
        end
        for gn in (5, 20, 40)
            @test _fit(_quartic, 2, 4; GN = gn).cond_vandermonde < 100
        end
    end
end
