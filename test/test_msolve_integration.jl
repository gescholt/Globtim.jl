"""
Test msolve integration: solver dispatch, N-D parser, and HC vs msolve comparison.

Covers:
- MSOLVE-01: N-dimensional output parsing (parse_msolve_output, parse_msolve_rational)
- MSOLVE-02: solver=:hc/:msolve kwarg dispatch in solve_polynomial_system
- MSOLVE-03: solver kwarg propagation through solve_and_transform, solve_tree_leaves
- MSOLVE-04: HC vs msolve correctness and timing comparison on benchmarks
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

# ─── MSOLVE-01: N-dimensional parser tests ───────────────────────────────────

@testset "parse_msolve_rational" begin
    # Plain integer
    @test Globtim.parse_msolve_rational("42") == 42.0
    @test Globtim.parse_msolve_rational("-7") == -7.0

    # Rational with 2^n denominator
    @test Globtim.parse_msolve_rational("3 / 2^1") == 1.5
    @test Globtim.parse_msolve_rational("-5 / 2^2") == -1.25
    @test Globtim.parse_msolve_rational("1 / 2^10") ≈ 1.0 / 1024.0

    # Large rational (like real msolve output)
    val = Globtim.parse_msolve_rational("170141183460469231731687303715884105727 / 2^127")
    @test isfinite(val)
    @test val ≈ 170141183460469231731687303715884105727 / BigFloat(2)^127 atol=1e-10

    # Whitespace tolerance
    @test Globtim.parse_msolve_rational("  3  /  2^2  ") == 0.75
end

@testset "parse_msolve_output — 2D" begin
    # Two exact-integer solutions (from x^2-1, y^2-4)
    content = """[0, [1,
[[[1, 1], [2, 2]], [[-1, -1], [2, 2]], [[1, 1], [-2, -2]], [[-1, -1], [-2, -2]]]
]]:"""
    pts = Globtim.parse_msolve_output(content, 2)
    @test length(pts) == 4
    @test all(p -> length(p) == 2, pts)

    # Check values (midpoints of [lo,hi] where lo==hi)
    coords = sort(pts, by=p -> (p[1], p[2]))
    @test coords[1] ≈ [-1.0, -2.0]
    @test coords[2] ≈ [-1.0,  2.0]
    @test coords[3] ≈ [ 1.0, -2.0]
    @test coords[4] ≈ [ 1.0,  2.0]
end

@testset "parse_msolve_output — 3D" begin
    # Eight solutions from x^2-1, y^2-1, z^2-1
    content = """[0, [1,
[[[1, 1], [1, 1], [1, 1]], [[-1, -1], [1, 1], [1, 1]], [[1, 1], [-1, -1], [1, 1]], [[-1, -1], [-1, -1], [1, 1]], [[1, 1], [1, 1], [-1, -1]], [[-1, -1], [1, 1], [-1, -1]], [[1, 1], [-1, -1], [-1, -1]], [[-1, -1], [-1, -1], [-1, -1]]]
]]:"""
    pts = Globtim.parse_msolve_output(content, 3)
    @test length(pts) == 8
    @test all(p -> length(p) == 3, pts)

    # All coordinates should be ±1
    for p in pts
        for c in p
            @test abs(c) ≈ 1.0
        end
    end
end

@testset "parse_msolve_output — intervals (rational bounds)" begin
    # Single solution with rational interval bounds
    content = """[0, [1,
[[[-146840379335314082943973272861937783459 / 2^127, -293680758670628165887946545723875566917 / 2^128], [-616413592448569057031365022676287685021 / 2^130, -2465654369794276228125460090705150740083 / 2^132]]]
]]:"""
    pts = Globtim.parse_msolve_output(content, 2)
    @test length(pts) == 1
    @test length(pts[1]) == 2
    @test all(isfinite, pts[1])
end

@testset "parse_msolve_output — edge cases" begin
    # No solutions
    pts = Globtim.parse_msolve_output("[-1]:", 2)
    @test isempty(pts)

    # Infinitely many solutions → error
    @test_throws ErrorException Globtim.parse_msolve_output("[1, 2, -1, []]:", 2)

    # Bad format → error
    @test_throws ErrorException Globtim.parse_msolve_output("garbage", 2)
end

# ─── MSOLVE-02/03: Solver dispatch + pipeline integration ────────────────────

if HAS_MSOLVE
    @testset "solver dispatch — Levy 2D degree 8" begin
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=15, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 8, basis=:chebyshev, normalized=false)

        # HC
        @polyvar x_hc[1:2]
        hc_time = @elapsed hc_pts = solve_polynomial_system(x_hc, pol; solver=:hc)

        # msolve
        @polyvar x_ms[1:2]
        ms_time = @elapsed ms_pts = solve_polynomial_system(x_ms, pol; solver=:msolve)

        @test length(hc_pts) > 0
        @test length(ms_pts) > 0
        @test length(ms_pts) >= length(hc_pts)  # msolve should find at least as many

        # Match: every HC point should have a nearby msolve point
        for hp in hc_pts
            dists = [sqrt(sum((hp .- mp).^2)) for mp in ms_pts]
            @test minimum(dists) < 0.1
        end

        @info @sprintf(
            "Levy 2D deg 8: HC=%d CPs (%.3fs), msolve=%d CPs (%.3fs), speedup=%.1fx",
            length(hc_pts), hc_time, length(ms_pts), ms_time, hc_time / ms_time
        )
    end

    @testset "solve_and_transform — msolve pathway" begin
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=15, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 8, basis=:chebyshev, normalized=false)
        bounds = [(-10.0, 10.0), (-10.0, 10.0)]

        sat_hc, t_hc = solve_and_transform(pol, bounds; solver=:hc)
        sat_ms, t_ms = solve_and_transform(pol, bounds; solver=:msolve)

        @test length(sat_hc) > 0
        @test length(sat_ms) > 0
        @test length(sat_ms) >= length(sat_hc)

        # Points should be in original domain (not [-1,1])
        for p in sat_ms
            @test -10.0 <= p[1] <= 10.0
            @test -10.0 <= p[2] <= 10.0
        end

        @info @sprintf(
            "solve_and_transform: HC=%d CPs (%.3fs), msolve=%d CPs (%.3fs)",
            length(sat_hc), t_hc, length(sat_ms), t_ms
        )
    end

    @testset "solver kwarg — invalid solver errors" begin
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=10, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 4, basis=:chebyshev, normalized=false)
        @polyvar x_err[1:2]
        @test_throws ErrorException solve_polynomial_system(x_err, pol; solver=:nonexistent)
    end

    @testset "solver kwarg — return_system not supported for msolve" begin
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=10, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 4, basis=:chebyshev, normalized=false)
        @polyvar x_rs[1:2]
        @test_throws ErrorException solve_polynomial_system(
            x_rs, pol; solver=:msolve, return_system=true
        )
    end

    # ─── MSOLVE-04: Multi-benchmark timing comparison ─────────────────────────

    @testset "HC vs msolve timing — multi-benchmark" begin
        benchmarks = [
            ("Levy",      Levy,      [(-10.0, 10.0), (-10.0, 10.0)]),
            ("Rastrigin", Rastrigin, [(-5.12, 5.12), (-5.12, 5.12)]),
            ("DeJong5",   dejong5,   [(-65.536, 65.536), (-65.536, 65.536)]),
        ]
        degrees = [6, 10]

        println("\n", "="^80)
        @printf("%-12s %4s  %6s %8s  %6s %8s  %7s\n",
                "Function", "Deg", "HC#", "HC(s)", "MS#", "MS(s)", "Speedup")
        println("-"^80)

        for (name, f, bounds) in benchmarks
            center = [(b[1]+b[2])/2 for b in bounds]
            sr = [(b[2]-b[1])/2 for b in bounds]
            TR = TestInput(f, dim=2, center=center, GN=15, sample_range=sr)

            for deg in degrees
                pol = Constructor(TR, deg, basis=:chebyshev, normalized=false)

                @polyvar xh[1:2]
                t_hc = @elapsed hc_pts = solve_polynomial_system(xh, pol; solver=:hc)

                @polyvar xm[1:2]
                t_ms = @elapsed ms_pts = solve_polynomial_system(xm, pol; solver=:msolve)

                speedup = t_hc / max(t_ms, 1e-6)
                @printf("%-12s %4d  %6d %7.3fs  %6d %7.3fs  %6.1fx\n",
                        name, deg, length(hc_pts), t_hc, length(ms_pts), t_ms, speedup)

                # msolve should find at least as many CPs (no path loss)
                @test length(ms_pts) >= length(hc_pts)
            end
        end
        println("="^80)
    end
else
    @warn "msolve binary not found — skipping msolve integration tests"
end
