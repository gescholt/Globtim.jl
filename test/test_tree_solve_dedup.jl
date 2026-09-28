using Test
using Globtim
using Random

# Bead 8f4p.6: _dedup_point_indices buckets kept points on a grid instead of scanning
# them all. It must return exactly what the plain greedy scan returns.
function _dedup_reference(points, tol)
    keep = Int[]
    for (i, pt) in enumerate(points)
        any(j -> sum(abs2, pt .- points[j]) < tol^2, keep) || push!(keep, i)
    end
    return keep
end

@testset "tree_solve dedup matches the greedy scan" begin
    rng = Xoshiro(20260928)
    for _ in 1:500
        n = rand(rng, 1:6)
        tol = rand(rng, [1e-6, 1e-3, 0.05, 0.3, 0.0, -0.05])
        base = [randn(rng, n) .* rand(rng, [1e-3, 0.1, 1.0]) for _ in 1:rand(rng, 1:20)]
        pts = Vector{Float64}[]
        for _ in 1:rand(rng, 0:80)
            p = rand(rng, base) .+ randn(rng, n) .* rand(rng, [0.0, tol / 3, tol, 2tol])
            r = rand(rng)
            r < 0.03 && (p[1] = NaN)
            0.03 <= r < 0.06 && (p[end] = Inf)
            0.06 <= r < 0.09 && (p .*= 1e12)
            0.09 <= r < 0.12 && (p[1] = -0.0)
            push!(pts, p)
        end
        @test Globtim._dedup_point_indices(pts, tol) == _dedup_reference(pts, tol)
    end

    # the cases the grid must not break
    @test Globtim._dedup_point_indices(Vector{Float64}[], 1e-6) == Int[]
    @test Globtim._dedup_point_indices([[0.0], [-0.0], [1e-7]], 1e-6) == [1]
    @test Globtim._dedup_point_indices([[0.0, 0.0], [0.0, 0.0]], 0.0) == [1, 2]
    @test Globtim._dedup_point_indices([[NaN, 0.0], [NaN, 0.0], [0.0, 0.0]], 1e-6) == [1, 2, 3]
    # neighbours straddling a cell edge (cell width 2tol)
    @test Globtim._dedup_point_indices([[2e-6 - 1e-9], [2e-6 + 1e-9]], 1e-6) == [1]
    @test Globtim._dedup_points([[1.0, 2.0], [1.0, 2.0 + 1e-8], [3.0, 4.0]], 1e-6) ==
          [[1.0, 2.0], [3.0, 4.0]]
end
