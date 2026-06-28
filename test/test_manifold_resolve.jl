using Test
using Globtim
using LinearAlgebra

# Stage 4: resolve a genuine positive-dimensional argmin (a continuum of minimizers)
# into a ManifoldResult, instead of reporting one spurious isolated point. Validated
# on the canonical curve-of-minima f=(‖x‖²−1)² (unit circle) via both the
# predictor-corrector trace and the symmetry-quotient orbit flow. Guards: a
# non-degenerate min and a k≥2 manifold both raise (no silent mis-handling).

# One-sided Hausdorff distance from sampled points to the unit circle.
_dist_to_unit_circle(pts) = maximum(abs(norm(p) - 1.0) for p in pts)

@testset "positive-dim argmin resolver (Stage 4)" begin

    circle(x) = (x[1]^2 + x[2]^2 - 1.0)^2   # minimizers = unit circle, common value 0

    @testset "predictor-corrector traces the curve of minima" begin
        m = resolve_positive_dim_argmin(circle, [1.0, 0.0]; step = 0.1)
        @test m.intrinsic_dim == 1
        @test m.source == :epsilon_continuation
        @test m.is_closed                                  # a closed curve
        @test m.converged
        @test _dist_to_unit_circle(m.sample_points) < 1e-3 # samples lie on the circle
        @test length(m.sample_points) > 20                 # covers the loop, not a patch
        @test abs(m.common_value) < 1e-8                   # shared minimum value ≈ 0
        @test m.value_spread < 1e-3                        # samples are equi-valued
        @test size(m.tangent_basis) == (2, 1)              # 1-D kernel = manifold tangent
    end

    @testset "symmetry-quotient reconstructs the orbit exactly" begin
        rot(x) = [-x[2], x[1]]                             # SO(2) generator
        m = resolve_positive_dim_argmin(circle, [1.0, 0.0]; symmetry_generator = rot,
            step = 0.05)
        @test m.source == :symmetry_quotient
        @test m.is_closed
        @test _dist_to_unit_circle(m.sample_points) < 1e-4 # flow of rotation is exact
        @test m.value_spread < 1e-4
    end

    @testset "a non-degenerate minimum raises (it is isolated, not a manifold)" begin
        bowl(x) = x[1]^2 + x[2]^2                          # unique min at 0, no kernel
        @test_throws ErrorException resolve_positive_dim_argmin(bowl, [0.0, 0.0])
    end

    @testset "a k≥2 manifold raises (open: needs multi-chart coverage)" begin
        sphere(x) = (x[1]^2 + x[2]^2 + x[3]^2 - 1.0)^2     # minimizers = 2-sphere
        # at (1,0,0) the Hessian kernel is 2-D ⇒ the predictor-corrector path refuses.
        @test_throws ErrorException resolve_positive_dim_argmin(sphere, [1.0, 0.0, 0.0])
    end
end
