"""
Test msolve integration: parser, solver dispatch, and timing characterization.

Covers:
- MSOLVE-01: N-dimensional output parsing
- MSOLVE-02: solver=:hc/:msolve kwarg dispatch
- MSOLVE-03: solver kwarg propagation through solve_and_transform
- MSOLVE-04: Dimension × degree timing sweep (the key data for solver selection)
"""

using Test
using Globtim
using Globtim.StandardExperiment: solve_and_transform
using DynamicPolynomials
using Printf

# ─── Helper: check msolve binary is available ────────────────────────────────

if !@isdefined(msolve_available)
    function msolve_available()
        try
            run(pipeline(`msolve -h`, devnull), wait=true)
            return true
        catch
            return false
        end
    end
end

if !@isdefined(HAS_MSOLVE)
    const HAS_MSOLVE = msolve_available()
end

# ─── MSOLVE-01: N-dimensional parser tests ───────────────────────────────────

@testset "MSOLVE-01: parse_msolve_rational" begin
    @test Globtim.parse_msolve_rational("42") == 42.0
    @test Globtim.parse_msolve_rational("-7") == -7.0
    @test Globtim.parse_msolve_rational("3 / 2^1") == 1.5
    @test Globtim.parse_msolve_rational("-5 / 2^2") == -1.25
    @test Globtim.parse_msolve_rational("1 / 2^10") ≈ 1.0 / 1024.0

    val = Globtim.parse_msolve_rational("170141183460469231731687303715884105727 / 2^127")
    @test isfinite(val)
    @test val ≈ 170141183460469231731687303715884105727 / BigFloat(2)^127 atol=1e-10

    @test Globtim.parse_msolve_rational("  3  /  2^2  ") == 0.75
end

@testset "MSOLVE-01: parse_msolve_output — 2D" begin
    content = """[0, [1,
[[[1, 1], [2, 2]], [[-1, -1], [2, 2]], [[1, 1], [-2, -2]], [[-1, -1], [-2, -2]]]
]]:"""
    pts = Globtim.parse_msolve_output(content, 2)
    @test length(pts) == 4
    @test all(p -> length(p) == 2, pts)
    coords = sort(pts, by=p -> (p[1], p[2]))
    @test coords[1] ≈ [-1.0, -2.0]
    @test coords[4] ≈ [ 1.0,  2.0]
end

@testset "MSOLVE-01: parse_msolve_output — 3D" begin
    content = """[0, [1,
[[[1, 1], [1, 1], [1, 1]], [[-1, -1], [1, 1], [1, 1]], [[1, 1], [-1, -1], [1, 1]], [[-1, -1], [-1, -1], [1, 1]], [[1, 1], [1, 1], [-1, -1]], [[-1, -1], [1, 1], [-1, -1]], [[1, 1], [-1, -1], [-1, -1]], [[-1, -1], [-1, -1], [-1, -1]]]
]]:"""
    pts = Globtim.parse_msolve_output(content, 3)
    @test length(pts) == 8
    @test all(p -> length(p) == 3, pts)
    for p in pts, c in p
        @test abs(c) ≈ 1.0
    end
end

@testset "MSOLVE-01: parse_msolve_output — edge cases" begin
    @test isempty(Globtim.parse_msolve_output("[-1]:", 2))
    @test_throws ErrorException Globtim.parse_msolve_output("[1, 2, -1, []]:", 2)
    @test_throws ErrorException Globtim.parse_msolve_output("garbage", 2)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Live solver tests (require msolve binary)
# ═══════════════════════════════════════════════════════════════════════════════

if HAS_MSOLVE

    # ─── MSOLVE-02: Dispatch correctness ─────────────────────────────────────

    @testset "MSOLVE-02: solver dispatch — basic" begin
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=12, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 6, basis=:chebyshev, normalized=false)

        @polyvar x_hc[1:2]
        hc_pts = solve_polynomial_system(x_hc, pol; solver=:hc)
        @polyvar x_ms[1:2]
        ms_pts = solve_polynomial_system(x_ms, pol; solver=:msolve)

        @test length(hc_pts) > 0
        @test length(ms_pts) > 0
        # Both solvers should find the same number of CPs
        @test length(ms_pts) == length(hc_pts)
    end

    @testset "MSOLVE-02: error on invalid solver" begin
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=10, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 4, basis=:chebyshev, normalized=false)
        @polyvar x_err[1:2]
        @test_throws ErrorException solve_polynomial_system(x_err, pol; solver=:nonexistent)
    end

    @testset "MSOLVE-02: return_system not supported for msolve" begin
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=10, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 4, basis=:chebyshev, normalized=false)
        @polyvar x_rs[1:2]
        @test_throws ErrorException solve_polynomial_system(
            x_rs, pol; solver=:msolve, return_system=true
        )
    end

    # ─── MSOLVE-03: Pipeline propagation ─────────────────────────────────────

    @testset "MSOLVE-03: solve_and_transform — msolve pathway" begin
        f = Levy
        TR = TestInput(f, dim=2, center=[0.0, 0.0], GN=12, sample_range=[10.0, 10.0])
        pol = Constructor(TR, 6, basis=:chebyshev, normalized=false)
        bounds = [(-10.0, 10.0), (-10.0, 10.0)]

        sat_hc, _ = solve_and_transform(pol, bounds; solver=:hc)
        sat_ms, _ = solve_and_transform(pol, bounds; solver=:msolve)

        @test length(sat_hc) > 0
        @test length(sat_ms) == length(sat_hc)

        for p in sat_ms
            @test -10.0 <= p[1] <= 10.0
            @test -10.0 <= p[2] <= 10.0
        end
    end

    # ─── MSOLVE-04: Dimension × degree timing sweep ─────────────────────────
    # This is the primary data for solver selection heuristics.
    #
    # Key findings (Apple M-series, msolve 0.9.4, HC.jl 2.x):
    #   2D: msolve 10-25x faster at deg 4-6, converges to ~1x at deg 10
    #   3D: HC 100-600x faster (Groebner basis complexity wall)
    #   4D: HC 30-2200x faster
    #
    # The crossover is sharp: msolve dominates in 2D, HC dominates in 3D+.

    @testset "MSOLVE-04: 2D timing sweep" begin
        benchmarks = [
            ("Levy",      Levy,      (-10.0, 10.0)),
            ("Rastrigin", Rastrigin, (-5.12, 5.12)),
        ]
        degrees = [4, 6, 8]

        println("\n", "="^75)
        @printf("%-12s %3s  %5s %8s  %5s %8s  %7s\n",
                "2D", "Deg", "HC#", "HC(s)", "MS#", "MS(s)", "Speedup")
        println("-"^75)

        for (name, f, bnd) in benchmarks
            center = [(bnd[1]+bnd[2])/2, (bnd[1]+bnd[2])/2]
            sr = [(bnd[2]-bnd[1])/2, (bnd[2]-bnd[1])/2]
            TR = TestInput(f, dim=2, center=center, GN=15, sample_range=sr)

            for deg in degrees
                pol = Constructor(TR, deg, basis=:chebyshev, normalized=false)

                @polyvar xh[1:2]
                t_hc = @elapsed hc_pts = solve_polynomial_system(xh, pol; solver=:hc)

                @polyvar xm[1:2]
                t_ms = @elapsed ms_pts = solve_polynomial_system(xm, pol; solver=:msolve)

                speedup = t_hc / max(t_ms, 1e-6)
                @printf("%-12s %3d  %5d %7.3fs  %5d %7.3fs  %6.1fx\n",
                        name, deg, length(hc_pts), t_hc, length(ms_pts), t_ms, speedup)

                # Same CP count (agreement established)
                @test length(ms_pts) == length(hc_pts)
            end
        end
        println("="^75)
    end

    @testset "MSOLVE-04: 3D timing sweep" begin
        benchmarks_3d = [
            ("Levy",   Levy,   (-10.0, 10.0)),
            ("Sphere", Sphere, (-5.12, 5.12)),
        ]
        degrees_3d = [4, 6]

        println("\n", "="^75)
        @printf("%-12s %3s  %5s %8s  %5s %8s  %7s\n",
                "3D", "Deg", "HC#", "HC(s)", "MS#", "MS(s)", "Speedup")
        println("-"^75)

        for (name, f, bnd) in benchmarks_3d
            center = fill((bnd[1]+bnd[2])/2, 3)
            sr = fill((bnd[2]-bnd[1])/2, 3)
            TR = TestInput(f, dim=3, center=center, GN=8, sample_range=sr)

            for deg in degrees_3d
                pol = Constructor(TR, deg, basis=:chebyshev, normalized=false)

                @polyvar xh[1:3]
                t_hc = @elapsed hc_pts = solve_polynomial_system(xh, pol; solver=:hc)

                @polyvar xm[1:3]
                t_ms = @elapsed ms_pts = solve_polynomial_system(xm, pol; solver=:msolve)

                speedup = t_hc / max(t_ms, 1e-6)
                @printf("%-12s %3d  %5d %7.3fs  %5d %7.3fs  %6.1fx\n",
                        name, deg, length(hc_pts), t_hc, length(ms_pts), t_ms, speedup)

                @test length(ms_pts) == length(hc_pts)
            end
        end
        println("="^75)
    end

    @testset "MSOLVE-04: 4D timing sweep" begin
        # 4D at degree 4 only — higher degrees push msolve into minutes.
        benchmarks_4d = [
            ("Sphere", Sphere, (-5.12, 5.12)),
        ]

        println("\n", "="^75)
        @printf("%-12s %3s  %5s %8s  %5s %8s  %7s\n",
                "4D", "Deg", "HC#", "HC(s)", "MS#", "MS(s)", "Speedup")
        println("-"^75)

        for (name, f, bnd) in benchmarks_4d
            center = fill((bnd[1]+bnd[2])/2, 4)
            sr = fill((bnd[2]-bnd[1])/2, 4)
            TR = TestInput(f, dim=4, center=center, GN=6, sample_range=sr)

            pol = Constructor(TR, 4, basis=:chebyshev, normalized=false)

            @polyvar xh[1:4]
            t_hc = @elapsed hc_pts = solve_polynomial_system(xh, pol; solver=:hc)

            @polyvar xm[1:4]
            t_ms = @elapsed ms_pts = solve_polynomial_system(xm, pol; solver=:msolve)

            speedup = t_hc / max(t_ms, 1e-6)
            @printf("%-12s %3d  %5d %7.3fs  %5d %7.3fs  %6.1fx\n",
                    name, 4, length(hc_pts), t_hc, length(ms_pts), t_ms, speedup)

            @test length(ms_pts) == length(hc_pts)
        end
        println("="^75)
    end

    # ─── recommended_solver heuristic ────────────────────────────────────────

    @testset "recommended_solver heuristic" begin
        @test recommended_solver(2; msolve_available=true)  == :msolve
        @test recommended_solver(2; msolve_available=false) == :hc
        @test recommended_solver(3; msolve_available=true)  == :hc
        @test recommended_solver(4; msolve_available=true)  == :hc
        @test recommended_solver(1; msolve_available=true)  == :msolve
    end

else
    @warn "msolve binary not found — skipping msolve integration tests"
end
