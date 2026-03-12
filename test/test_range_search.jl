"""
Test certified range search: interval-based domain filtering for msolve solutions.

Covers:
- RANGE-01: Interval parsing — _parse_solution_block_intervals returns (midpoints, intervals)
- RANGE-02: parse_msolve_output_with_intervals returns points + interval bounds
- RANGE-03: interval_in_box / interval_overlaps_box certified filtering
- RANGE-04: _solve_msolve with search_bounds filters solutions algebraically
- RANGE-05: solve_polynomial_system with search_bounds (both :hc and :msolve)
- RANGE-06: solve_and_transform with search_bounds (subdomain filtering)
"""

using Test
using Globtim
using Globtim.StandardExperiment: solve_and_transform
using DynamicPolynomials
using Printf

# ─── Helper: check msolve binary is available ────────────────────────────────

function msolve_available()
    try
        run(pipeline(`msolve -h`, devnull), wait=true)
        return true
    catch
        return false
    end
end

const HAS_MSOLVE = msolve_available()

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

    # Each interval should be (lo, hi) tuple
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
    # 2D intervals, box is [-1,1]^2

    # Fully inside: intervals [0.2, 0.3] x [-0.5, -0.4] → overlaps
    iv_inside = [(0.2, 0.3), (-0.5, -0.4)]
    @test Globtim.interval_overlaps_box(iv_inside, [(-1.0, 1.0), (-1.0, 1.0)]) == true

    # Fully outside (x > 1): intervals [1.5, 2.0] x [0.0, 0.1] → no overlap
    iv_outside_x = [(1.5, 2.0), (0.0, 0.1)]
    @test Globtim.interval_overlaps_box(iv_outside_x, [(-1.0, 1.0), (-1.0, 1.0)]) == false

    # Fully outside (y < -1): intervals [0.0, 0.1] x [-3.0, -2.0] → no overlap
    iv_outside_y = [(0.0, 0.1), (-3.0, -2.0)]
    @test Globtim.interval_overlaps_box(iv_outside_y, [(-1.0, 1.0), (-1.0, 1.0)]) == false

    # Straddling boundary: interval [-0.5, 1.5] x [0.0, 0.1] → overlaps
    iv_straddle = [(-0.5, 1.5), (0.0, 0.1)]
    @test Globtim.interval_overlaps_box(iv_straddle, [(-1.0, 1.0), (-1.0, 1.0)]) == true

    # Exactly on boundary: interval [1.0, 1.0] x [0.0, 0.0] → overlaps (touching)
    iv_boundary = [(1.0, 1.0), (0.0, 0.0)]
    @test Globtim.interval_overlaps_box(iv_boundary, [(-1.0, 1.0), (-1.0, 1.0)]) == true

    # Custom box: [-2, 2] x [-3, 3]
    custom_box = [(-2.0, 2.0), (-3.0, 3.0)]
    iv_in_custom = [(1.5, 1.8), (2.5, 2.8)]
    @test Globtim.interval_overlaps_box(iv_in_custom, custom_box) == true
    iv_out_custom = [(2.5, 3.0), (0.0, 0.1)]
    @test Globtim.interval_overlaps_box(iv_out_custom, custom_box) == false

    # 3D test
    iv_3d_in = [(0.0, 0.1), (0.0, 0.1), (0.0, 0.1)]
    box_3d = [(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]
    @test Globtim.interval_overlaps_box(iv_3d_in, box_3d) == true

    iv_3d_out = [(0.0, 0.1), (0.0, 0.1), (2.0, 3.0)]
    @test Globtim.interval_overlaps_box(iv_3d_out, box_3d) == false
end

@testset "RANGE-03: interval_certified_inside" begin
    # Fully certified inside: both lo and hi within box
    iv_inside = [(0.2, 0.3), (-0.5, -0.4)]
    @test Globtim.interval_certified_inside(iv_inside, [(-1.0, 1.0), (-1.0, 1.0)]) == true

    # One coordinate straddles → NOT certified inside
    iv_straddle = [(-0.5, 1.5), (0.0, 0.1)]
    @test Globtim.interval_certified_inside(iv_straddle, [(-1.0, 1.0), (-1.0, 1.0)]) == false

    # Exactly on boundary → certified inside (closed interval)
    iv_boundary = [(1.0, 1.0), (-1.0, -1.0)]
    @test Globtim.interval_certified_inside(iv_boundary, [(-1.0, 1.0), (-1.0, 1.0)]) == true

    # Outside → NOT certified inside
    iv_outside = [(1.5, 2.0), (0.0, 0.1)]
    @test Globtim.interval_certified_inside(iv_outside, [(-1.0, 1.0), (-1.0, 1.0)]) == false
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

    # Box [-1.5, 1.5] x [-1.5, 1.5] → only solutions with |y| ≤ 1.5 qualify
    # All 4 solutions have |y| = 2.0, none overlap
    box_small = [(-1.5, 1.5), (-1.5, 1.5)]
    filtered_pts, filtered_ivs = Globtim.filter_solutions_by_box(points, intervals, box_small)
    @test isempty(filtered_pts)

    # Box [-1.5, 1.5] x [-2.5, 2.5] → all 4 solutions overlap
    box_wide = [(-1.5, 1.5), (-2.5, 2.5)]
    filtered_pts2, filtered_ivs2 = Globtim.filter_solutions_by_box(points, intervals, box_wide)
    @test length(filtered_pts2) == 4

    # Box [0.0, 2.0] x [0.0, 3.0] → only (1.0, 2.0) overlaps
    box_quadrant = [(0.0, 2.0), (0.0, 3.0)]
    filtered_pts3, filtered_ivs3 = Globtim.filter_solutions_by_box(points, intervals, box_quadrant)
    @test length(filtered_pts3) == 1
    @test filtered_pts3[1] == [1.0, 2.0]

    # With non-trivial intervals: solution at midpoint 0.5 but interval [0.4, 0.6]
    pts_iv = [[0.5, 0.5]]
    ivs_iv = [[(0.4, 0.6), (0.4, 0.6)]]
    # Box [0.0, 1.0]^2 → interval overlaps → keep
    @test length(Globtim.filter_solutions_by_box(pts_iv, ivs_iv, [(0.0, 1.0), (0.0, 1.0)])[1]) == 1
    # Box [0.7, 1.0]^2 → x-interval [0.4, 0.6] doesn't overlap [0.7, 1.0] → reject
    @test length(Globtim.filter_solutions_by_box(pts_iv, ivs_iv, [(0.7, 1.0), (0.0, 1.0)])[1]) == 0
end

# ═══════════════════════════════════════════════════════════════════════════════
# RANGE-05: msolve_raw_points_with_intervals (file-based)
# ═══════════════════════════════════════════════════════════════════════════════

@testset "RANGE-05: msolve_raw_points_with_intervals" begin
    # Write a mock msolve output file
    content = """[0, [1,
[[[1, 1], [2, 2]], [[-1, -1], [2, 2]], [[1, 1], [-2, -2]], [[-1, -1], [-2, -2]]]
]]:"""
    tmpfile = tempname() * ".ms"
    write(tmpfile, content)

    pts, ivs = Globtim.msolve_raw_points_with_intervals(tmpfile, 2)
    @test length(pts) == 4
    @test length(ivs) == 4
    # File should be cleaned up
    @test !isfile(tmpfile)
end

# ═══════════════════════════════════════════════════════════════════════════════
# RANGE-06: End-to-end solver integration with search_bounds
# ═══════════════════════════════════════════════════════════════════════════════

if HAS_MSOLVE
    @testset "RANGE-06: _solve_msolve with search_bounds" begin
        # Levy 2D degree 6 — known to have solutions both inside and outside [-1,1]^2
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=12, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 6, basis=:chebyshev, normalized=false)

        @polyvar x_all[1:2]
        all_pts = solve_polynomial_system(x_all, pol; solver=:msolve)

        # Now solve with tight search_bounds — should find fewer or equal CPs
        @polyvar x_tight[1:2]
        tight_pts = solve_polynomial_system(
            x_tight, pol;
            solver=:msolve,
            search_bounds=[(-0.5, 0.5), (-0.5, 0.5)]
        )

        @test length(tight_pts) <= length(all_pts)
        # All tight points should be within the search bounds (midpoint check)
        for p in tight_pts
            @test -0.5 <= p[1] <= 0.5 || abs(p[1]) < 0.6  # allow small interval overshoot
            @test -0.5 <= p[2] <= 0.5 || abs(p[2]) < 0.6
        end

        @info @sprintf(
            "Levy 2D deg 6: all=%d CPs, tight=[-0.5,0.5]^2=%d CPs",
            length(all_pts), length(tight_pts)
        )
    end

    @testset "RANGE-06: solve_polynomial_system search_bounds — HC uses midpoint filter" begin
        # HC doesn't have intervals, so search_bounds falls back to midpoint filtering
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=12, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 6, basis=:chebyshev, normalized=false)

        @polyvar x_hc_all[1:2]
        all_hc = solve_polynomial_system(x_hc_all, pol; solver=:hc)

        @polyvar x_hc_tight[1:2]
        tight_hc = solve_polynomial_system(
            x_hc_tight, pol;
            solver=:hc,
            search_bounds=[(-0.5, 0.5), (-0.5, 0.5)]
        )

        @test length(tight_hc) <= length(all_hc)
        # All tight points should have midpoints inside search bounds
        for p in tight_hc
            @test -0.5 <= p[1] <= 0.5
            @test -0.5 <= p[2] <= 0.5
        end
    end

    @testset "RANGE-06: solve_and_transform with search_bounds" begin
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=12, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 6, basis=:chebyshev, normalized=false)
        bounds = [(-10.0, 10.0), (-10.0, 10.0)]

        # Without search_bounds: full domain
        cps_all, _ = solve_and_transform(pol, bounds; solver=:msolve)

        # With search_bounds in ORIGINAL coordinates: [-5, 5]^2
        cps_sub, _ = solve_and_transform(
            pol, bounds;
            solver=:msolve,
            search_bounds=[(-5.0, 5.0), (-5.0, 5.0)]
        )

        @test length(cps_sub) <= length(cps_all)
        for p in cps_sub
            # Should be roughly within [-5, 5]^2 (allow small interval overshoot)
            @test -5.5 <= p[1] <= 5.5
            @test -5.5 <= p[2] <= 5.5
        end

        @info @sprintf(
            "solve_and_transform: all=%d CPs, [-5,5]^2=%d CPs",
            length(cps_all), length(cps_sub)
        )
    end
else
    @warn "msolve binary not found — skipping range search integration tests"
end
