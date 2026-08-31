# MargulesTPD — closed-form thermodynamic phase-stability fixture (bead 3ztw.1)
#
# Two-suffix Margules binary TPD in the logit chart. This is Globtim's
# Clapeyron-free stand-in for the TPD problem family: three known stationary
# points (two minima, one maximum at the feed), Poincaré–Hopf N_min − N_max = 1.

using Test
using ForwardDiff
using Globtim

@testset "MargulesTPD fixture" begin
    cps = Globtim.MARGULES_TPD_KNOWN_CPS

    @testset "value at the feed is exactly the tangent-plane zero" begin
        w_feed = log(0.4 / 0.6)
        @test abs(MargulesTPD([w_feed])) < 1e-15
    end

    @testset "known CPs are stationary with the recorded classification" begin
        g(w) = ForwardDiff.derivative(t -> MargulesTPD([t]), w)
        for cp in cps
            @test abs(g(cp.w)) < 1e-13
            @test MargulesTPD([cp.w]) ≈ cp.tpd atol = 1e-14
            curv = ForwardDiff.derivative(g, cp.w)
            if cp.kind == :minimum
                @test curv > 0
            else
                @test curv < 0
            end
            # logit chart consistency
            @test 1 / (1 + exp(-cp.w)) ≈ cp.y1 rtol = 1e-12
        end
    end

    @testset "CP set is complete: Poincaré–Hopf and dense sign-change scan" begin
        n_min = count(cp -> cp.kind == :minimum, cps)
        n_max = count(cp -> cp.kind == :maximum, cps)
        @test n_min - n_max == 1

        # Every sign change of tpd' on a fine grid must bracket a known CP.
        g(w) = ForwardDiff.derivative(t -> MargulesTPD([t]), w)
        grid = range(-5.0, 5.0; length = 20_001)
        brackets = [
            (grid[i], grid[i+1]) for
            i in 1:(length(grid)-1) if sign(g(grid[i])) != sign(g(grid[i+1]))
        ]
        @test length(brackets) == length(cps)
        for ((lo, hi), cp) in zip(brackets, cps)
            @test lo <= cp.w <= hi
        end
    end

    @testset "registry entry" begin
        entry = Globtim.FUNCTION_REGISTRY[MargulesTPD]
        @test entry.name == "MargulesTPD"
        @test entry.min_dim == 1 && entry.max_dim == 1
        loc = entry.global_min_location(1)
        @test MargulesTPD(loc) ≈ entry.global_min_value(1) atol = 1e-14
        # global min is the lowest of the known CPs
        @test entry.global_min_value(1) == minimum(cp.tpd for cp in cps)

        bench = get_benchmark_config(MargulesTPD, 1)
        @test bench.bounds == [(-5.0, 5.0)]
        @test_throws ErrorException get_benchmark_config(MargulesTPD, 2)
        @test get_benchmark_config_by_name("margulestpd", 1).objective === MargulesTPD
    end

    @testset "dimension guard and AD-genericity" begin
        @test_throws ArgumentError MargulesTPD([0.1, 0.2])
        # gradient through the vector interface (pipeline calling convention)
        gvec = ForwardDiff.gradient(MargulesTPD, [1.0])
        @test length(gvec) == 1 && isfinite(gvec[1])
    end
end
