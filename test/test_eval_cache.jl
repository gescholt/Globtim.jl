# CachedObjective (eval_cache.jl): the degree sweep evaluates the objective once per
# grid point. Constructor re-evaluates the whole (GN+1)^n grid at every degree, so the
# integration test below is the one that matters: second Constructor call ⇒ all hits.

using Test
using Globtim
using ForwardDiff

@testset "CachedObjective" begin
    @testset "counts, values, scalar and vector keys" begin
        calls = Ref(0)
        f = x -> (calls[] += 1; sum(abs2, x) + 0.5)
        c = CachedObjective(f)
        @test c([1.0, 2.0]) == 5.5
        @test c([1.0, 2.0]) == 5.5
        @test c(view([1.0, 2.0, 9.0], 1:2)) == 5.5  # any AbstractVector{Float64}: same key
        @test calls[] == 1
        st = cache_stats(c)
        @test st.misses == 1 && st.hits == 2 && st.size == 1
        @test st.hit_rate ≈ 2 / 3
        # a bit-different point is a miss
        @test c([1.0, 2.0 + 1e-15]) ≈ 5.5
        @test calls[] == 2
        # scalar (1-D objectives receive a scalar from MainGenerate)
        g = CachedObjective(x -> 3x)
        @test g(2.0) == 6.0 && g(2.0) == 6.0
        @test cache_stats(g).hits == 1
        clear_cache!(c)
        st = cache_stats(c)
        @test st.hits == 0 && st.misses == 0 && st.size == 0
        @test original_objective(c) === f
    end

    @testset "duals bypass the cache" begin
        calls = Ref(0)
        f = x -> (calls[] += 1; x[1]^2 * x[2])
        c = CachedObjective(f)
        g = ForwardDiff.gradient(c, [2.0, 3.0])
        @test g ≈ [12.0, 4.0]
        H = ForwardDiff.hessian(c, [2.0, 3.0])
        @test H ≈ [6.0 4.0; 4.0 0.0]
        @test cache_stats(c).size == 0                # nothing stored for Dual inputs
        @test c([2.0, 3.0]) == 12.0
        @test cache_stats(c).size == 1
    end

    @testset "thread safety" begin
        c = CachedObjective(x -> sum(x))
        pts = [Float64[i, 2i] for i in 1:50]
        Threads.@threads for k in 1:2000
            p = pts[mod1(k, 50)]
            @assert c(p) == 3 * p[1]
        end
        st = cache_stats(c)
        @test st.size == 50
        @test st.hits + st.misses == 2000
        # duplicate misses can only happen in a race on first touch: at most one per thread per key
        @test st.misses <= 50 * Threads.nthreads()
    end

    @testset "Constructor degree sweep hits the cache from the second degree on" begin
        calls = Ref(0)
        f = x -> (calls[] += 1; exp(0.3 * x[1]) * cos(x[2]) + x[1] * x[2])
        c = CachedObjective(f)
        GN = 10
        TR = TestInput(c; dim = 2, center = [0.1, -0.2], GN = GN, sample_range = [1.0, 0.5], tolerance = nothing)
        n_grid = (GN + 1)^2
        pol4 = Constructor(TR, 4)
        @test calls[] == n_grid
        st = cache_stats(c)
        @test st.misses == n_grid && st.hits == 0
        pol6 = Constructor(TR, 6)
        @test calls[] == n_grid                       # no new evaluations
        @test cache_stats(c).hits == n_grid
        pol8 = Constructor(TR, 8)
        @test calls[] == n_grid
        @test cache_stats(c).hits == 2n_grid
        # the fits are the same as without the cache
        TR_plain = TestInput(f; dim = 2, center = [0.1, -0.2], GN = GN, sample_range = [1.0, 0.5], tolerance = nothing)
        @test Constructor(TR_plain, 6).coeffs == pol6.coeffs
        @test pol4.z == pol6.z == pol8.z
    end
end
