"""
Level-8 full-pipeline integration tests (bead h0vk).

The whole chain against ground truth:

    f → TestInput (grid) → Constructor (polynomial) → solve_polynomial_system (HC)
      → process_crit_pts (box filter) → analyze_critical_points (BFGS refine +
        clustering/dedup + Hessian classification)

L6 tested the approximation, L7 tested the solver. L8 asserts the composition:
that a critical point known analytically survives *every* stage and comes out the
far end with the right coordinates, the right value and the right type.

Ground truth. p(x) = Σ q(xᵢ) with q(t) = t⁴ - t², whose gradient decouples into
per-axis cubics with roots {0, ±1/√2}. In 2D that is 9 critical points, and their
types follow from q''(t) = 12t² - 2 without computing anything:

    q''(0) = -2 < 0      q''(±1/√2) = +4 > 0

so the Hessian diag(q''(x₁), q''(x₂)) gives
    (0, 0)                → maximum   (1)
    (±1/√2, 0), (0, ±1/√2) → saddle    (4)
    (±1/√2, ±1/√2)         → minimum   (4)

with minimum value 2·q(1/√2) = -0.5 exactly. Nine points, three types, one known
value — enough to audit every stage.

`normalized = false` per the 7vug fix. Self-contained: no cross-package includes,
since globtim ships to the mirror (pre-push Layers 0.6/0.7).
"""

using Test
using Globtim
using DynamicPolynomials
using HomotopyContinuation
using DataFrames
using LinearAlgebra

# ── Ground truth ─────────────────────────────────────────────────────────────

_q(t) = t^4 - t^2
_quartic(v) = sum(_q, v)
const _R = 1 / sqrt(2)
const _EXACT_DEGREE = 4
const _MIN_VALUE = -0.5

"The 9 analytic critical points paired with their type."
function _truth()
    out = Tuple{Vector{Float64},Symbol}[]
    for a in (0.0, _R, -_R), b in (0.0, _R, -_R)
        t = (a == 0 && b == 0) ? :maximum : (a != 0 && b != 0) ? :minimum : :saddle
        push!(out, ([a, b], t))
    end
    return out
end

"Run the complete chain and hand back every intermediate, so a failure localises."
function _pipeline(d::Int; GN::Int = 20, tol_dist::Float64 = 0.025)
    n = 2
    TR = TestInput(_quartic, dim = n, center = zeros(n), GN = GN, sample_range = 1.0)
    pol = Constructor(TR, d, basis = :chebyshev, normalized = false)
    @polyvar x[1:n]
    raw =
        solve_polynomial_system(x, n, d, pol.coeffs; basis = :chebyshev, normalized = false)
    df = process_crit_pts(raw, _quartic, TR)
    enhanced, minimizers =
        analyze_critical_points(_quartic, df, TR; verbose = false, tol_dist = tol_dist)
    return (; pol, raw, df, enhanced, minimizers)
end

_match(pt, target; tol = 1e-6) = norm(pt .- target) < tol

@testset "L8 Pipeline Integration (h0vk)" begin

    # ========================================================================
    # 8a — single-degree capture rate, end to end
    # ========================================================================

    @testset "at the representable degree the whole chain captures everything" begin
        r = _pipeline(_EXACT_DEGREE)
        truth = _truth()

        @test r.pol.nrm < 1e-12                 # stage 2: approximation exact
        @test length(r.raw) == 9                # stage 3: HC found all 9
        @test nrow(r.df) == 9                   # stage 4: none lost to the box filter
        @test nrow(r.enhanced) == 9             # stage 5: none lost to dedup
        @test nrow(r.minimizers) == 4           # and exactly the 4 true minima

        # Every point is a genuine critical point after refinement.
        @test maximum(r.enhanced.gradient_norm) < 1e-8
        @test all(r.enhanced.converged)
    end

    @testset "classification matches the analytic Hessian" begin
        r = _pipeline(_EXACT_DEGREE)
        counts = Dict(
            t => count(==(t), r.enhanced.critical_point_type) for
            t in unique(r.enhanced.critical_point_type)
        )
        # Derived from q''(t) = 12t² - 2, not read off the output.
        @test counts[:minimum] == 4
        @test counts[:saddle] == 4
        @test counts[:maximum] == 1
    end

    @testset "minimizers land on the analytic coordinates and value" begin
        r = _pipeline(_EXACT_DEGREE)
        @test nrow(r.minimizers) == 4
        for row in eachrow(r.minimizers)
            @test isapprox(abs(row.x1), _R; atol = 1e-8)
            @test isapprox(abs(row.x2), _R; atol = 1e-8)
            @test isapprox(row.value, _MIN_VALUE; atol = 1e-8)
            @test row.critical_point_type == :minimum
        end
    end

    # ========================================================================
    # 8d — pipeline audit: trace each ground-truth CP through every stage
    # ========================================================================

    @testset "every ground-truth CP is traceable through all five stages" begin
        r = _pipeline(_EXACT_DEGREE)
        df_pts = [[row.x1, row.x2] for row in eachrow(r.df)]
        en_pts = [[row.x1, row.x2] for row in eachrow(r.enhanced)]

        for (target, want_type) in _truth()
            @testset "CP $(round.(target, digits=4)) ($want_type)" begin
                # Stage 3: HC
                @test any(p -> _match(p, target), r.raw)
                # Stage 4: box filter kept it
                @test any(p -> _match(p, target), df_pts)
                # Stage 5: refine/dedup kept it, exactly once
                @test count(p -> _match(p, target; tol = 1e-4), en_pts) == 1
                # ...and typed it correctly
                idx = findfirst(p -> _match(p, target; tol = 1e-4), en_pts)
                @test r.enhanced.critical_point_type[idx] == want_type
            end
        end
    end

    # ========================================================================
    # 8b/8c — degree sweep and cross-degree feature tracking
    # ========================================================================

    @testset "degree sweep: capture is all-or-nothing at the representable degree" begin
        captured = Dict{Int,Int}()
        for d in (2, 3, 4, 6)
            r = _pipeline(d)
            captured[d] = count(
                t -> any(p -> _match([p.x1, p.x2], t[1]), eachrow(r.enhanced)),
                _truth(),
            )
        end
        @test captured[2] == 0
        @test captured[3] == 0
        @test captured[4] == 9
        @test captured[6] == 9
    end

    @testset "cross-degree persistence separates real CPs from spurious ones" begin
        # The heuristic under test: a critical point that recurs across degrees is
        # real; one appearing at a single degree is an artifact of that fit.
        # Measured separation is total — the 9 true CPs each appear at degrees
        # {4,6,8}, and all 5 spurious ones appear at exactly one degree.
        appearances = Dict{Int,Vector{Vector{Float64}}}()
        for d in (2, 3, 4, 6, 8)
            r = _pipeline(d)
            appearances[d] = [[row.x1, row.x2] for row in eachrow(r.enhanced)]
        end

        # Cluster every point seen anywhere, and count how many degrees hit it.
        reps = Vector{Float64}[]
        counts = Int[]
        for d in keys(appearances), p in appearances[d]
            k = findfirst(rp -> norm(rp .- p) < 1e-3, reps)
            if k === nothing
                push!(reps, p)
                push!(counts, 1)
            else
                counts[k] += 1
            end
        end

        truth_pts = first.(_truth())
        for (rep, c) in zip(reps, counts)
            is_true = any(t -> _match(t, rep; tol = 1e-4), truth_pts)
            if is_true
                @test c >= 2      # persistent
            else
                @test c == 1      # singleton
            end
        end
        # And the tally is what we expect: 9 real, and every real one seen 3×.
        @test count(
            i -> any(t -> _match(t, reps[i]; tol = 1e-4), truth_pts),
            eachindex(reps),
        ) == 9
    end

    # ========================================================================
    # 8f — critical-point mode vs minimum mode
    # ========================================================================

    @testset "minimum mode is a strict subset of critical-point mode" begin
        r = _pipeline(_EXACT_DEGREE)
        @test nrow(r.minimizers) < nrow(r.enhanced)      # 4 of 9
        @test all(t -> t == :minimum, r.minimizers.critical_point_type)
        # Every minimizer must also appear in the full critical-point table.
        en_pts = [[row.x1, row.x2] for row in eachrow(r.enhanced)]
        for row in eachrow(r.minimizers)
            @test any(p -> _match(p, [row.x1, row.x2]; tol = 1e-4), en_pts)
        end
        # The complement is exactly the non-minima.
        @test nrow(r.enhanced) - nrow(r.minimizers) ==
              count(!=(:minimum), r.enhanced.critical_point_type)
    end

    # ========================================================================
    # 8e — parameter sensitivity
    # ========================================================================

    @testset "GN: capture is insensitive once the grid supports the basis" begin
        for gn in (8, 20, 30)
            r = _pipeline(_EXACT_DEGREE; GN = gn)
            @test nrow(r.enhanced) == 9
            @test nrow(r.minimizers) == 4
        end
    end

    @testset "dedup tolerance: too coarse a tol_dist merges distinct minima" begin
        # The 9 CPs are ~0.707 apart, so the default 0.025 keeps them separate.
        fine = _pipeline(_EXACT_DEGREE; tol_dist = 0.025)
        @test nrow(fine.minimizers) == 4

        # The four minima sit at (±1/√2, ±1/√2), so their nearest-neighbour
        # separation is 2/√2 = 1.414. Measured: tol_dist 1.0 still resolves all
        # four, tol_dist 2.0 collapses them to one — the boundary falls exactly
        # where the geometry says it should. Asserted as equalities rather than a
        # weak `<=`, which would pass even if dedup did nothing.
        @test nrow(_pipeline(_EXACT_DEGREE; tol_dist = 1.0).minimizers) == 4
        @test nrow(_pipeline(_EXACT_DEGREE; tol_dist = 2.0).minimizers) == 1
    end
end
