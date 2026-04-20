"""
Test certified range search: interval-based domain filtering for msolve solutions.

Covers:
- RANGE-01: Interval parsing — _parse_solution_block_intervals returns (midpoints, intervals)
- RANGE-02: parse_msolve_output_with_intervals returns points + interval bounds
- RANGE-03: interval_in_box / interval_overlaps_box certified filtering
- RANGE-04: filter_solutions_by_box — certified range filtering
- RANGE-05: msolve_raw_points_with_intervals (file-based parsing)
- RANGE-06: End-to-end solver integration with search_bounds (2D)
- RANGE-07: 3D range search — certified interval filtering in higher dimensions
- RANGE-08: Monotonicity — tighter boxes yield strictly fewer or equal CPs
"""

using Test
using Globtim
using HomotopyContinuation
using Globtim.StandardExperiment: solve_and_transform
using DynamicPolynomials
using Printf

# ─── Helper: check msolve binary is available ────────────────────────────────

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

if !@isdefined(HAS_MSOLVE)
    const HAS_MSOLVE = msolve_available()
end

# ═══════════════════════════════════════════════════════════════════════════════
# RANGE-01: Interval parsing
# ═══════════════════════════════════════════════════════════════════════════════

@testset "RANGE-01: _parse_solution_block_intervals" begin
    # Exact-integer solutions (lo == hi) → zero-width intervals
    block = "[[1, 1], [2, 2]]"
    midpts, intervals = Globtim._parse_solution_block_intervals(block, 2)
    @test midpts == [1.0, 2.0]
    @test intervals == [(1.0, 1.0), (2.0, 2.0)]

    # Negative exact-integer solution
    block2 = "[[-1, -1], [-2, -2]]"
    midpts2, intervals2 = Globtim._parse_solution_block_intervals(block2, 2)
    @test midpts2 == [-1.0, -2.0]
    @test intervals2 == [(-1.0, -1.0), (-2.0, -2.0)]

    # Rational interval bounds (real msolve output)
    block3 = "[[-3 / 2^1, -1], [1, 3 / 2^1]]"
    midpts3, intervals3 = Globtim._parse_solution_block_intervals(block3, 2)
    @test midpts3[1] ≈ (-1.5 + -1.0) / 2  # midpoint of [-1.5, -1.0]
    @test midpts3[2] ≈ (1.0 + 1.5) / 2     # midpoint of [1.0, 1.5]
    @test intervals3[1] == (-1.5, -1.0)
    @test intervals3[2] == (1.0, 1.5)

    # 3D solution
    block4 = "[[1, 1], [-1, -1], [3 / 2^1, 3 / 2^1]]"
    midpts4, intervals4 = Globtim._parse_solution_block_intervals(block4, 3)
    @test midpts4 == [1.0, -1.0, 1.5]
    @test intervals4 == [(1.0, 1.0), (-1.0, -1.0), (1.5, 1.5)]

    # Wrong dimension → nothing
    result = Globtim._parse_solution_block_intervals(block, 3)
    @test result === nothing
end

# ═══════════════════════════════════════════════════════════════════════════════
# RANGE-02: Full msolve output parsing with intervals
# ═══════════════════════════════════════════════════════════════════════════════

@testset "RANGE-02: parse_msolve_output_with_intervals" begin
    # 2D: Four solutions from x^2-1, y^2-4
    content = """[0, [1,
[[[1, 1], [2, 2]], [[-1, -1], [2, 2]], [[1, 1], [-2, -2]], [[-1, -1], [-2, -2]]]
]]:"""
    pts, ivs = Globtim.parse_msolve_output_with_intervals(content, 2)
    @test length(pts) == 4
    @test length(ivs) == 4
    @test all(iv -> length(iv) == 2, ivs)

    # Each interval should be (lo, hi) tuple with lo ≤ hi
    for iv in ivs
        for (lo, hi) in iv
            @test lo <= hi
        end
    end

    # No solutions
    pts_empty, ivs_empty = Globtim.parse_msolve_output_with_intervals("[-1]:", 2)
    @test isempty(pts_empty)
    @test isempty(ivs_empty)
end

# ═══════════════════════════════════════════════════════════════════════════════
# RANGE-03: Certified interval-box overlap tests
# ═══════════════════════════════════════════════════════════════════════════════

@testset "RANGE-03: interval_overlaps_box" begin
    unit_box = [(-1.0, 1.0), (-1.0, 1.0)]

    # Fully inside
    @test Globtim.interval_overlaps_box([(0.2, 0.3), (-0.5, -0.4)], unit_box) == true
    # Fully outside (x > 1)
    @test Globtim.interval_overlaps_box([(1.5, 2.0), (0.0, 0.1)], unit_box) == false
    # Fully outside (y < -1)
    @test Globtim.interval_overlaps_box([(0.0, 0.1), (-3.0, -2.0)], unit_box) == false
    # Straddling boundary
    @test Globtim.interval_overlaps_box([(-0.5, 1.5), (0.0, 0.1)], unit_box) == true
    # Exactly on boundary (touching)
    @test Globtim.interval_overlaps_box([(1.0, 1.0), (0.0, 0.0)], unit_box) == true

    # Custom box
    custom_box = [(-2.0, 2.0), (-3.0, 3.0)]
    @test Globtim.interval_overlaps_box([(1.5, 1.8), (2.5, 2.8)], custom_box) == true
    @test Globtim.interval_overlaps_box([(2.5, 3.0), (0.0, 0.1)], custom_box) == false

    # 3D overlap tests
    box_3d = [(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]
    @test Globtim.interval_overlaps_box([(0.0, 0.1), (0.0, 0.1), (0.0, 0.1)], box_3d) ==
          true
    @test Globtim.interval_overlaps_box([(0.0, 0.1), (0.0, 0.1), (2.0, 3.0)], box_3d) ==
          false
    # 3D: one dimension barely overlapping
    @test Globtim.interval_overlaps_box([(0.9, 1.1), (0.0, 0.1), (0.0, 0.1)], box_3d) ==
          true
    # 3D: one dimension just outside
    @test Globtim.interval_overlaps_box([(1.01, 1.1), (0.0, 0.1), (0.0, 0.1)], box_3d) ==
          false
end

@testset "RANGE-03: interval_certified_inside" begin
    unit_box = [(-1.0, 1.0), (-1.0, 1.0)]

    # Fully certified inside
    @test Globtim.interval_certified_inside([(0.2, 0.3), (-0.5, -0.4)], unit_box) == true
    # One coordinate straddles → NOT certified inside
    @test Globtim.interval_certified_inside([(-0.5, 1.5), (0.0, 0.1)], unit_box) == false
    # Exactly on boundary → certified inside (closed interval)
    @test Globtim.interval_certified_inside([(1.0, 1.0), (-1.0, -1.0)], unit_box) == true
    # Outside → NOT certified inside
    @test Globtim.interval_certified_inside([(1.5, 2.0), (0.0, 0.1)], unit_box) == false

    # 3D certified inside
    box_3d = [(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]
    @test Globtim.interval_certified_inside([(0.0, 0.1), (0.0, 0.1), (0.0, 0.1)], box_3d) ==
          true
    @test Globtim.interval_certified_inside([(0.0, 0.1), (0.0, 0.1), (0.9, 1.1)], box_3d) ==
          false
end

# ═══════════════════════════════════════════════════════════════════════════════
# RANGE-04: filter_solutions_by_box — certified range filtering
# ═══════════════════════════════════════════════════════════════════════════════

@testset "RANGE-04: filter_solutions_by_box" begin
    # Setup: 4 solutions at (±1, ±2), all exact (zero-width intervals)
    points = [[1.0, 2.0], [-1.0, 2.0], [1.0, -2.0], [-1.0, -2.0]]
    intervals = [
        [(1.0, 1.0), (2.0, 2.0)],
        [(-1.0, -1.0), (2.0, 2.0)],
        [(1.0, 1.0), (-2.0, -2.0)],
        [(-1.0, -1.0), (-2.0, -2.0)],
    ]

    # Box [-1.5, 1.5] x [-1.5, 1.5] → all have |y| = 2.0 > 1.5, none overlap
    box_small = [(-1.5, 1.5), (-1.5, 1.5)]
    filtered_pts, _ = Globtim.filter_solutions_by_box(points, intervals, box_small)
    @test isempty(filtered_pts)

    # Box [-1.5, 1.5] x [-2.5, 2.5] → all 4 solutions overlap
    box_wide = [(-1.5, 1.5), (-2.5, 2.5)]
    filtered_pts2, _ = Globtim.filter_solutions_by_box(points, intervals, box_wide)
    @test length(filtered_pts2) == 4

    # Box [0.0, 2.0] x [0.0, 3.0] → only (1.0, 2.0) overlaps
    box_quadrant = [(0.0, 2.0), (0.0, 3.0)]
    filtered_pts3, _ = Globtim.filter_solutions_by_box(points, intervals, box_quadrant)
    @test length(filtered_pts3) == 1
    @test filtered_pts3[1] == [1.0, 2.0]

    # Non-trivial intervals: midpoint inside but interval may straddle
    pts_iv = [[0.5, 0.5]]
    ivs_iv = [[(0.4, 0.6), (0.4, 0.6)]]
    @test length(
        Globtim.filter_solutions_by_box(pts_iv, ivs_iv, [(0.0, 1.0), (0.0, 1.0)])[1],
    ) == 1
    @test length(
        Globtim.filter_solutions_by_box(pts_iv, ivs_iv, [(0.7, 1.0), (0.0, 1.0)])[1],
    ) == 0

    # 3D filtering: 8 solutions at (±1, ±1, ±1)
    pts_3d =
        [[s1, s2, s3] for s1 in [-1.0, 1.0] for s2 in [-1.0, 1.0] for s3 in [-1.0, 1.0]]
    ivs_3d = [[(p, p) for p in pt] for pt in pts_3d]  # exact intervals

    # Positive octant → only (1,1,1)
    box_octant = [(0.0, 2.0), (0.0, 2.0), (0.0, 2.0)]
    filt_3d, _ = Globtim.filter_solutions_by_box(pts_3d, ivs_3d, box_octant)
    @test length(filt_3d) == 1
    @test filt_3d[1] == [1.0, 1.0, 1.0]

    # Half-space x > 0 → 4 solutions
    box_half = [(0.0, 2.0), (-2.0, 2.0), (-2.0, 2.0)]
    filt_half, _ = Globtim.filter_solutions_by_box(pts_3d, ivs_3d, box_half)
    @test length(filt_half) == 4
end

# ═══════════════════════════════════════════════════════════════════════════════
# RANGE-05: msolve_raw_points_with_intervals (file-based)
# ═══════════════════════════════════════════════════════════════════════════════

@testset "RANGE-05: msolve_raw_points_with_intervals" begin
    content = """[0, [1,
[[[1, 1], [2, 2]], [[-1, -1], [2, 2]], [[1, 1], [-2, -2]], [[-1, -1], [-2, -2]]]
]]:"""
    tmpfile = tempname() * ".ms"
    write(tmpfile, content)

    pts, ivs = Globtim.msolve_raw_points_with_intervals(tmpfile, 2)
    @test length(pts) == 4
    @test length(ivs) == 4
    @test !isfile(tmpfile)  # cleaned up
end

# ═══════════════════════════════════════════════════════════════════════════════
# RANGE-06 through RANGE-08: Live solver tests (require msolve binary)
# ═══════════════════════════════════════════════════════════════════════════════

if HAS_MSOLVE

    # ─── RANGE-06: 2D search_bounds — msolve certified filtering ────────────

    @testset "RANGE-06: _solve_msolve with search_bounds — 2D" begin
        f = Levy
        TR =
            TestInput(f, dim = 2, center = [0.0, 0.0], GN = 12, sample_range = [10.0, 10.0])
        pol = Constructor(TR, 6, basis = :chebyshev, normalized = false)

        @polyvar x_all[1:2]
        all_pts = solve_polynomial_system(x_all, pol; solver = :msolve)

        @polyvar x_tight[1:2]
        tight_pts = solve_polynomial_system(
            x_tight,
            pol;
            solver = :msolve,
            search_bounds = [(-0.5, 0.5), (-0.5, 0.5)],
        )

        @test length(tight_pts) <= length(all_pts)

        # Strict assertion: msolve uses certified intervals, so filtered points
        # must have their interval overlapping the search box. The midpoints
        # returned should be close to the box — allow half the interval width
        # as overshoot (typically < 0.01 for msolve's isolation precision).
        for p in tight_pts
            @test -0.55 <= p[1] <= 0.55
            @test -0.55 <= p[2] <= 0.55
        end

        @info @sprintf(
            "Levy 2D deg 6: all=%d CPs, tight=[-0.5,0.5]²=%d CPs",
            length(all_pts),
            length(tight_pts)
        )
    end

    @testset "RANGE-06: HC search_bounds — midpoint filter" begin
        f = Levy
        TR =
            TestInput(f, dim = 2, center = [0.0, 0.0], GN = 12, sample_range = [10.0, 10.0])
        pol = Constructor(TR, 6, basis = :chebyshev, normalized = false)

        @polyvar x_hc_all[1:2]
        all_hc = solve_polynomial_system(x_hc_all, pol; solver = :hc)

        @polyvar x_hc_tight[1:2]
        tight_hc = solve_polynomial_system(
            x_hc_tight,
            pol;
            solver = :hc,
            search_bounds = [(-0.5, 0.5), (-0.5, 0.5)],
        )

        @test length(tight_hc) <= length(all_hc)
        # HC uses exact midpoint filtering — no interval overshoot
        for p in tight_hc
            @test -0.5 <= p[1] <= 0.5
            @test -0.5 <= p[2] <= 0.5
        end
    end

    @testset "RANGE-06: solve_and_transform with search_bounds — 2D" begin
        f = Levy
        TR =
            TestInput(f, dim = 2, center = [0.0, 0.0], GN = 12, sample_range = [10.0, 10.0])
        pol = Constructor(TR, 6, basis = :chebyshev, normalized = false)
        bounds = [(-10.0, 10.0), (-10.0, 10.0)]

        cps_all, _ = solve_and_transform(pol, bounds; solver = :msolve)
        cps_sub, _ = solve_and_transform(
            pol,
            bounds;
            solver = :msolve,
            search_bounds = [(-5.0, 5.0), (-5.0, 5.0)],
        )

        @test length(cps_sub) <= length(cps_all)
        for p in cps_sub
            @test -5.5 <= p[1] <= 5.5
            @test -5.5 <= p[2] <= 5.5
        end

        @info @sprintf(
            "solve_and_transform 2D: all=%d CPs, [-5,5]²=%d CPs",
            length(cps_all),
            length(cps_sub)
        )
    end

    # ─── RANGE-07: 3D range search — certified interval filtering ────────────

    @testset "RANGE-07: 3D search_bounds — msolve" begin
        f = Sphere
        TR = TestInput(
            f,
            dim = 3,
            center = [0.0, 0.0, 0.0],
            GN = 8,
            sample_range = [5.12, 5.12, 5.12],
        )
        pol = Constructor(TR, 4, basis = :chebyshev, normalized = false)

        @polyvar x_all3[1:3]
        all_pts_3d = solve_polynomial_system(x_all3, pol; solver = :msolve)

        @polyvar x_tight3[1:3]
        tight_pts_3d = solve_polynomial_system(
            x_tight3,
            pol;
            solver = :msolve,
            search_bounds = [(-0.3, 0.3), (-0.3, 0.3), (-0.3, 0.3)],
        )

        @test length(tight_pts_3d) <= length(all_pts_3d)
        for p in tight_pts_3d
            for c in p
                @test -0.35 <= c <= 0.35
            end
        end

        @info @sprintf(
            "Sphere 3D deg 4: all=%d CPs, tight=[-0.3,0.3]³=%d CPs",
            length(all_pts_3d),
            length(tight_pts_3d)
        )
    end

    @testset "RANGE-07: 3D search_bounds — HC midpoint filter" begin
        f = Sphere
        TR = TestInput(
            f,
            dim = 3,
            center = [0.0, 0.0, 0.0],
            GN = 8,
            sample_range = [5.12, 5.12, 5.12],
        )
        pol = Constructor(TR, 4, basis = :chebyshev, normalized = false)

        @polyvar x_hc3_all[1:3]
        all_hc_3d = solve_polynomial_system(x_hc3_all, pol; solver = :hc)

        @polyvar x_hc3_tight[1:3]
        tight_hc_3d = solve_polynomial_system(
            x_hc3_tight,
            pol;
            solver = :hc,
            search_bounds = [(-0.3, 0.3), (-0.3, 0.3), (-0.3, 0.3)],
        )

        @test length(tight_hc_3d) <= length(all_hc_3d)
        for p in tight_hc_3d
            for c in p
                @test -0.3 <= c <= 0.3
            end
        end
    end

    # ─── RANGE-08: Monotonicity — tighter boxes yield ≤ CPs ─────────────────

    @testset "RANGE-08: monotonicity — nested boxes yield non-increasing CP count" begin
        f = Levy
        TR =
            TestInput(f, dim = 2, center = [0.0, 0.0], GN = 12, sample_range = [10.0, 10.0])
        pol = Constructor(TR, 8, basis = :chebyshev, normalized = false)

        # Nested boxes: full ⊃ medium ⊃ tight
        boxes = [
            nothing,                                     # full [-1,1]^2
            [(-0.8, 0.8), (-0.8, 0.8)],                # medium
            [(-0.4, 0.4), (-0.4, 0.4)],                # tight
        ]

        counts = Int[]
        for sb in boxes
            @polyvar xm[1:2]
            pts = solve_polynomial_system(xm, pol; solver = :msolve, search_bounds = sb)
            push!(counts, length(pts))
        end

        # Monotonicity: full ≥ medium ≥ tight
        @test counts[1] >= counts[2]
        @test counts[2] >= counts[3]

        @info @sprintf(
            "Levy 2D deg 8 monotonicity: full=%d, [-0.8,0.8]²=%d, [-0.4,0.4]²=%d",
            counts[1],
            counts[2],
            counts[3]
        )

        # Same for HC
        counts_hc = Int[]
        for sb in boxes
            @polyvar xh[1:2]
            pts = solve_polynomial_system(xh, pol; solver = :hc, search_bounds = sb)
            push!(counts_hc, length(pts))
        end

        @test counts_hc[1] >= counts_hc[2]
        @test counts_hc[2] >= counts_hc[3]
    end

else
    @warn "msolve binary not found — skipping range search integration tests (RANGE-06 through RANGE-08)"
end
