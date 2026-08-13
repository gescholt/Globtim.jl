"""
Level-7 HomotopyContinuation completeness tests (bead mooi).

The question is not "did the solver return something" — test_hc_solve_kwargs.jl
already exercises the code paths and asserts only `length(cps) >= 1`. L7 asks
whether HC finds **every** critical point of the polynomial system.

Answering that needs a system whose solution count is known independently of the
solver. The construction used throughout is a SEPARABLE polynomial:

    q(t) = t^4 - t^2        q'(t) = 4t^3 - 2t = 2t(2t^2 - 1)   ⇒ roots {0, ±1/√2}
    p(x) = Σ q(xᵢ)          ∇p = (q'(x₁), …, q'(xₙ))

The gradient decouples, so the critical points are exactly the Cartesian product
of the per-axis roots: 3ⁿ of them, all real, all strictly inside [-1,1]ⁿ. For
n = 2 that is 9, known analytically with no reference to HC.

Because p is itself a degree-4 polynomial, a degree-4 Chebyshev approximation on
[-1,1]ⁿ is exact to rounding (measured L2 ≈ 9e-16), so the system HC solves is
the true gradient system rather than an approximation of it. That separates
solver completeness from approximation quality, which is L6's question.

`normalized = false` throughout: the 7vug fix made that the coefficient-preserving
Chebyshev path, and it is what the pipeline and validation scripts use. Passing
`normalized = true` here would solve a differently-scaled polynomial.
"""

using Test
using Globtim
using DynamicPolynomials
using HomotopyContinuation
using LinearAlgebra

# ── Known-count fixtures ─────────────────────────────────────────────────────

_q(t) = t^4 - t^2                      # 3 critical points per axis
_separable_quartic(v) = sum(_q, v)

"Analytic critical points of Σ q(xᵢ): the Cartesian product of {0, ±1/√2}."
function _analytic_cps(n::Int)
    roots = [0.0, 1 / sqrt(2), -1 / sqrt(2)]
    return [collect(p) for p in Iterators.product(ntuple(_ -> roots, n)...)] |> vec
end

"""
Solve the gradient system of `f`'s degree-`d` Chebyshev approximation on [-1,1]^n.

Rebuilding the Constructor per call is deliberate. A memoised version was tried
and made no measurable difference (45.3s either way): the runtime here is HC
path-tracking, not polynomial fitting, so the cache added a global and an
objectid key for nothing.
"""
function _solve_cps(f, n::Int, d::Int; kwargs...)
    TR = TestInput(f, dim = n, center = zeros(n), GN = 20, sample_range = 1.0)
    pol = Constructor(TR, d, basis = :chebyshev, normalized = false)
    @polyvar x[1:n]
    cps = solve_polynomial_system(
        x,
        n,
        d,
        pol.coeffs;
        basis = :chebyshev,
        normalized = false,
        kwargs...,
    )
    return cps, pol
end

# Boundary tolerance: some fixtures place critical points exactly ON the box
# face, where a bare `abs(p) <= 1` would reject them for a last-bit overshoot.
_in_box(p; tol = 1e-8) = all(abs.(p) .<= 1.0 + tol)
_n_in_box(cps; tol = 1e-8) = count(p -> _in_box(p; tol = tol), cps)

"Does every analytic CP have a computed CP within `tol`? Returns (recall, missed)."
function _match_analytic(cps, expected; tol = 1e-6)
    missed = [e for e in expected if !any(c -> norm(c .- e) < tol, cps)]
    return (length(expected) - length(missed)) / length(expected), missed
end

@testset "L7 HC Completeness (mooi)" begin

    # ========================================================================
    # 7a — known critical-point count
    # ========================================================================

    @testset "separable quartic: all 3^n critical points found (n=2)" begin
        cps, pol = _solve_cps(_separable_quartic, 2, 4)
        expected = _analytic_cps(2)

        # The approximation must be exact, or this is L6's test rather than L7's.
        @test pol.nrm < 1e-12
        @test length(expected) == 9

        recall, missed = _match_analytic(cps, expected)
        @test recall == 1.0
        @test isempty(missed)
        # Completeness cuts both ways: no extras either, at the exact degree.
        @test length(cps) == 9
        @test _n_in_box(cps) == 9
    end

    @testset "separable quartic in 3D: 27 critical points" begin
        cps, pol = _solve_cps(_separable_quartic, 3, 4)
        expected = _analytic_cps(3)
        @test pol.nrm < 1e-12
        @test length(expected) == 27

        recall, missed = _match_analytic(cps, expected)
        @test recall == 1.0
        @test isempty(missed)
        @test _n_in_box(cps) == 27
    end

    # ========================================================================
    # 7b — total-degree vs polyhedral start system
    # ========================================================================

    @testset "start systems agree on the full solution set" begin
        expected = _analytic_cps(2)
        counts = Dict{Symbol,Int}()
        for ss in (:total_degree, :polyhedral, :auto)
            cps, _ = _solve_cps(_separable_quartic, 2, 4; start_system = ss)
            recall, missed = _match_analytic(cps, expected)
            @testset "$ss" begin
                @test recall == 1.0            # completeness is start-system independent
                @test isempty(missed)
            end
            counts[ss] = _n_in_box(cps)
        end
        # Not merely "each ≥ 9" — they must agree with each other.
        @test counts[:total_degree] == counts[:polyhedral] == counts[:auto] == 9
    end

    # ========================================================================
    # 7c — sparsification impact
    # ========================================================================

    @testset "sparsification preserves the solution set on a genuinely sparse system" begin
        expected = _analytic_cps(2)
        # p has only x^4, x^2, y^4, y^2 terms, so its Chebyshev coefficients are
        # sparse by construction: thresholding should drop numerical dust, not
        # structure. A dense approximant would not be expected to behave this way.
        for th in (0.0, 1e-10, 1e-6, 1e-3, 1e-1)
            cps, _ = _solve_cps(_separable_quartic, 2, 4; sparsify_threshold = th)
            recall, missed = _match_analytic(cps, expected)
            @testset "threshold=$th" begin
                @test recall == 1.0
                @test isempty(missed)
                @test _n_in_box(cps) == 9
            end
        end
    end

    # ========================================================================
    # 7d — critical points on the domain boundary
    # ========================================================================

    @testset "a critical point exactly on the box corner is found" begin
        # ∇[(x-1)² + (y-1)²] = 0 at (1,1) — the corner of [-1,1]², the worst
        # place for an in-box filter to be sloppy about.
        fb(v) = sum(t -> (t - 1)^2, v)
        cps, pol = _solve_cps(fb, 2, 2)
        @test pol.nrm < 1e-12
        @test length(cps) == 1
        @test norm(cps[1] .- [1.0, 1.0]) < 1e-10
        # It lands a hair outside the closed box in floating point, which is why
        # the in-box predicate carries a tolerance rather than using `<= 1.0`.
        @test _in_box(cps[1])
    end

    # ========================================================================
    # 7e — higher degree than needed: true CPs survive, spurious ones appear
    # ========================================================================

    @testset "over-fitting adds spurious CPs outside the box but loses none inside" begin
        expected = _analytic_cps(2)
        cps, pol = _solve_cps(_separable_quartic, 2, 6)
        @test pol.nrm < 1e-12          # still exact — degree 6 ⊃ degree 4

        recall, missed = _match_analytic(cps, expected)
        @test recall == 1.0            # nothing true is lost
        @test isempty(missed)
        @test _n_in_box(cps) == 9      # and nothing spurious sneaks inside

        # Measured: degree 6 yields 11 total, i.e. 2 extra roots of the padded
        # gradient system, both outside [-1,1]². Recorded because it is the
        # concrete argument for filtering to the box rather than trusting the
        # raw solution count.
        @test length(cps) >= 9
        @test length(cps) - _n_in_box(cps) == length(cps) - 9
    end

    # ========================================================================
    # 7f — singular / degenerate solutions
    # ========================================================================

    @testset "degenerate critical point is found, at reduced accuracy" begin
        # q(t) = t^4 ⇒ q'(t) = 4t^3, a triple root at 0. The 2D system has one
        # critical point, at the origin, with a singular Hessian.
        fs(v) = sum(t -> t^4, v)
        cps, pol = _solve_cps(fs, 2, 4)
        @test pol.nrm < 1e-12
        @test length(cps) == 1
        @test _in_box(cps[1])

        # Accuracy is the point of this test. A multiplicity-m root is resolvable
        # only to about eps^(1/m); for m = 3 that is ~6e-6, and the measured
        # distance from the origin is ~8e-6. Asserting 1e-10 here would fail, and
        # asserting nothing would miss that HC does NOT return machine-accurate
        # coordinates for singular solutions.
        dist = norm(cps[1])
        @test dist < 1e-3               # it is the right critical point
        @test dist > 1e-9               # but not to machine precision
    end

    # ========================================================================
    # Independent oracle — msolve, when available
    # ========================================================================

    if !@isdefined(msolve_available)
        function msolve_available()
            try
                run(pipeline(`msolve -h`, devnull), wait = true)
                return true
            catch
                return false
            end
        end
    end

    if msolve_available()
        @testset "msolve agrees with HC on the full solution set" begin
            # msolve is symbolic, so this is a genuinely independent count rather
            # than HC checking itself.
            expected = _analytic_cps(2)
            cps_ms, _ = _solve_cps(_separable_quartic, 2, 4; solver = :msolve)
            recall, missed = _match_analytic(cps_ms, expected)
            @test recall == 1.0
            @test isempty(missed)
            @test _n_in_box(cps_ms) == 9
        end
    else
        @info "L7: msolve not on PATH — skipping the independent-oracle cross-check"
    end
end
