# test_rational_pathcount.jl — B1.0 of docs/research/plans/RATIONAL_PHASE3_BRIEF.md
#
# The lifted system p − y q = 0, ∇p − y ∇q = 0 of a generic rational function
# of type (M, N) in n variables has
#
#     C(n, M, N) = (M−1)^n + N · Σ_{k=1}^{n} (M−1)^{n−k} (N−1)^{k−1}   (M ≠ N)
#     C(n, M, M) = (n + 1) (M−1)^n                                      (M = N)
#
# isolated solutions (at M = N the mixed volume, the first formula, is tracked
# but not attained). Three things are pinned here:
#   1. `rational_generic_path_count` reproduces every ledgered polyhedral path
#      count and the brief's cost table (pure arithmetic, no HC).
#   2. The count is ATTAINED: for generic complex coefficients the polyhedral
#      solve returns exactly C nonsingular solutions (the mixed volume is
#      attained, which is what the parametric solver and the monodromy
#      stopping rule of B1.2/B1.3 rest on). Cluster-scale version:
#      experiments/sandbox/rational_phase3/generic_count_check.jl.
#   3. A real Chebyshev fit of the Phase-1 anchor (A2 at (8,4), GN = 24)
#      tracks exactly C(2, 8, 4) = 89 paths.
#
# HC-dependent testsets are SKIPPED loudly when the extension cannot load.

using Test
using Globtim
using LinearAlgebra
using Random

const PATHCOUNT_HC_OK = try
    @eval using HomotopyContinuation
    Base.get_extension(Globtim, :GlobtimHomotopyContinuationExt) !== nothing
catch err
    @warn "HomotopyContinuation extension unavailable; skipping path-count attainment tests" err
    false
end

@testset "rational_generic_path_count: the formula" begin
    C = rational_generic_path_count

    # n = 1: M + N − 1 (p' q − p q' has degree M + N − 1), 2M − 2 when M = N
    # (the leading coefficients cancel)
    for M in 1:8, N in 0:6
        @test C(1, M, N) == (M == N ? 2M - 2 : M + N - 1)
    end

    # N = 0 is the polynomial case: Bézout count of ∇p = 0
    for n in 1:6, M in 2:8
        @test C(n, M, 0) == (M - 1)^n
    end

    # the nine ledgered polyhedral counts (brief B1.0)
    @test C(2, 8, 4) == 89
    @test C(3, 8, 4) == 659
    @test C(4, 8, 4) == 4_721
    @test C(5, 8, 4) == 33_371
    @test C(6, 8, 4) == 234_569
    @test C(6, 6, 3) == 31_186
    @test C(7, 6, 3) == 156_122
    @test C(8, 6, 3) == 780_994
    # (4,2) at m = 12 ran with a total-degree start, whose count is the Bézout
    # number 4·3¹² = 2 125 764 — NOT C; the polyhedral count is smaller.
    @test C(12, 4, 2) < 4 * 3^12

    # the brief's cost table, m = 5..8 for (6,3), (6,6), (7,5), (8,4); the (6,6)
    # entries are (m + 1)·5^m (the brief's 21 875 / 128 125 / 734 375 / 4 140 625
    # were the mixed volume, which M = N does not attain)
    table = Dict(
        (5, 6, 3) => 6_218, (5, 6, 6) => 18_750, (5, 7, 5) => 24_656, (5, 8, 4) => 33_371,
        (6, 6, 3) => 31_186, (6, 6, 6) => 109_375, (6, 7, 5) => 153_056, (6, 8, 4) => 234_569,
        (7, 6, 3) => 156_122, (7, 6, 6) => 625_000, (7, 7, 5) => 938_816, (7, 8, 4) => 1_644_899,
        (8, 6, 3) => 780_994, (8, 6, 6) => 3_515_625, (8, 7, 5) => 5_714_816, (8, 8, 4) => 11_523_041,
        (4, 6, 6) => 3_125,
    )
    for ((n, M, N), c) in table
        @test C(n, M, N) == c
    end

    # closed forms: M ≠ N and M = N
    for n in 1:6, M in 2:8, N in 1:8
        if M != N
            @test C(n, M, N) == (M - 1)^n + N * ((M - 1)^n - (N - 1)^n) ÷ (M - N)
        else
            @test C(n, M, N) == (n + 1) * (M - 1)^n
        end
    end

    # M sets the exponent, N only the multiplier: C(n, M, N) ≤ (1 + nN) (M−1)^n
    # whenever N ≤ M, and is monotone in both
    for n in 2:6, M in 2:8, N in 1:M
        @test C(n, M, N) <= (1 + n * N) * (M - 1)^n
        @test C(n, M, N) >= C(n, M, N - 1)
        @test C(n, M, N) >= C(n, M - 1, N)
    end

    @test_throws ArgumentError C(0, 4, 2)
    @test_throws ArgumentError C(2, 0, 2)
    @test_throws ArgumentError C(2, 4, -1)
end

# ── generic complex family: is C attained? ───────────────────────────────────
"exponent vectors of total degree ≤ d in n variables"
function _pathcount_support(n, d)
    out = Vector{Vector{Int}}()
    for α in Iterators.product(ntuple(_ -> 0:d, n)...)
        sum(α) <= d && push!(out, collect(α))
    end
    out
end

@testset "generic count is attained (polyhedral, complex coefficients)" begin
    if !PATHCOUNT_HC_OK
        @test_skip "HomotopyContinuation extension unavailable"
    else
        rng = MersenneTwister(2026)
        for (n, M, N) in ((2, 4, 2), (2, 6, 3), (3, 4, 2), (3, 5, 3), (2, 4, 5), (2, 4, 4), (3, 4, 4))
            C = rational_generic_path_count(n, M, N)
            # mixed volume: the M ≠ N formula; tracked always, attained only for M ≠ N
            a, b = M - 1, N - 1
            MV = a^n + N * sum(a^(n - k) * b^(k - 1) for k in 1:n)
            x = [HomotopyContinuation.Variable(:x, i) for i in 1:n]
            y = HomotopyContinuation.Variable(:y)
            SM, SN = _pathcount_support(n, M), _pathcount_support(n, N)
            mono(α) = prod(x[i]^α[i] for i in 1:n)
            p = sum(randn(rng, ComplexF64) * mono(α) for α in SM)
            q = sum(randn(rng, ComplexF64) * mono(β) for β in SN)
            eqs = vcat(p - y * q, HomotopyContinuation.differentiate(p, x) .- y .* HomotopyContinuation.differentiate(q, x))
            F = HomotopyContinuation.System(eqs; variables = vcat(x, [y]))
            # HC's polyhedral tracker loses a path now and then (147 of 148 on one shape in
            # one run of this suite): the count is asserted on a solve with no failed path,
            # and three solves in a row with a failed path fail the test.
            R = HomotopyContinuation.solve(F; start_system = :polyhedral, show_progress = false)
            for _ in 1:2
                HomotopyContinuation.nfailed(R) == 0 && break
                R = HomotopyContinuation.solve(F; start_system = :polyhedral, show_progress = false)
            end
            @test HomotopyContinuation.nfailed(R) == 0
            @test HomotopyContinuation.ntracked(R) == MV
            @test HomotopyContinuation.nsolutions(R) == C   # = MV iff M ≠ N
            @test HomotopyContinuation.nsingular(R) == 0
        end
    end
end

# ── the Phase-1 anchor: A2 at (8,4) tracks 89 paths ──────────────────────────
@testset "A2 at (8,4): n_paths == C(2,8,4) == 89" begin
    if !PATHCOUNT_HC_OK
        @test_skip "HomotopyContinuation extension unavailable"
    else
        f_pole(x) = 1 / ((x[1] - 1.15)^2 + (x[2] - 0.30)^2 + 0.04) + sin(3x[1]) * cos(2x[2])
        TRp = TestInput(f_pole; dim = 2, center = [0.0, 0.0], sample_range = 1.0, GN = 24)
        R = RationalConstructor(TRp, 8, 4)
        res = solve_rational_critical_points(R)
        @test res.n_paths == rational_generic_path_count(2, 8, 4) == 89
        @test res.n_singular == 0
    end
end
