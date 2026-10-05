# test_box_strata_census.jl — closed Poincaré–Hopf census on [-1,1]ⁿ (box_strata_census.jl).
# Requires HomotopyContinuation (loaded by runtests.jl).

using Test
using Globtim
using DynamicPolynomials
using HomotopyContinuation

@testset "box strata Poincaré–Hopf census" begin
    @polyvar x[1:2]
    xv = collect(x)

    @testset "interior minimum only" begin
        c = box_strata_census(x[1]^2 + x[2]^2, xv)
        @test c.exact && c.ok && c.sum == 1
        @test c.n_interior == 1 && c.n_boundary_counted == 0
    end

    @testset "concave: interior max, four edge maxima, four vertices" begin
        c = box_strata_census(-(x[1]^2 + x[2]^2), xv)
        @test c.exact && c.sum == 1
        @test c.n_interior == 1
        @test count(q -> q.counted && q.stratum_dim == 1, c.points) == 4
        @test count(q -> q.counted && q.stratum_dim == 0, c.points) == 4
    end

    @testset "linear: a single inward vertex" begin
        c = box_strata_census(x[1] + 0.1 * x[2], xv)
        @test c.exact && c.ok
        counted = filter(q -> q.counted, c.points)
        @test length(counted) == 1 && counted[1].x == [-1.0, -1.0]
    end

    @testset "boundary minimum: the interior-only count misses it" begin
        # minimum of (x₁ − 1.4)² + x₂² on the box is on the face x₁ = 1
        c = box_strata_census((x[1] - 1.4)^2 + x[2]^2, xv)
        @test c.ok
        @test c.n_interior == 0 && c.n_boundary_counted == 1
        b = only(filter(q -> q.counted, c.points))
        @test b.x ≈ [1.0, 0.0] && b.index == 0 && b.stratum_dim == 1
    end

    @testset "non-isolated stationary set is not exact" begin
        c = box_strata_census(x[1]^2 + 0 * x[2], xv)   # p independent of x₂
        @test !c.exact && !c.ok
        @test c.n_degenerate_faces > 0
    end

    @testset "3-D product and a surrogate" begin
        @polyvar y[1:3]
        c = box_strata_census(sum(yi^4 - yi^2 for yi in y), collect(y))  # 3³ interior CPs
        @test c.exact && c.ok
        @test c.n_interior == 27
        # a fitted surrogate goes through the same monomial conversion as the HC solve
        TR = TestInput(Deuflhard, dim = 2, center = [0.0, 0.0], GN = 30, sample_range = 1.2)
        pol = Constructor(TR, 12)
        cp = box_strata_census(pol)
        @test cp.n_faces == 9
        @test !cp.exact || cp.sum == 1   # when the census is exact it must close at 1
    end
end
