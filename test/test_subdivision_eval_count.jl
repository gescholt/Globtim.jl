# Regression: deterministic eval counts under adaptive_refine.
#
# Locks in two invariants the smoke harness depends on:
# 1. Rosenbrock 2D is an exact degree-4 polynomial. Any fit at degree >= 4
#    representable on the root grid converges immediately. Total f-evals must
#    equal n_samples_per_dim^dim regardless of `degree`. This guards against
#    regressions where the algorithm would split or refit unnecessarily.
# 2. A non-polynomial 2D objective (trigonometric) under the same caps must
#    produce the canonical eval counts below. This guards against regressions
#    in the sample-reuse path or the convergence check.
#
# Tracks bead globopt_merged-zwbs.8 (SMOKE-INFRA).

using Test
using Globtim

@testset "subdivision eval-count invariants" begin
    @testset "rosenbrock 2D: exact polynomial, 49 evals at every degree" begin
        rosenbrock(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
        bounds = [(-2.0, 2.0), (-2.0, 2.0)]

        for degree in (4, 6, 8)
            n_evals = Ref(0)
            counted(x) = (n_evals[] += 1; rosenbrock(x))
            tree = adaptive_refine(
                counted,
                bounds,
                degree;
                l2_tolerance = 1e-2,
                tolerance_mode = :relative,
                max_depth = 3,
                max_leaves = 20,
                parallel = false,
                n_samples_per_dim = 7,
                reuse_parent_samples = true,
            )
            @test n_evals[] == 49  # 7^2 root grid
            @test length(tree.converged_leaves) == 1
            @test isempty(tree.active_leaves)
            @test isempty(tree.pruned_leaves)
        end
    end

    @testset "trig 2D: subdivision invariant across degrees" begin
        trig(x) = sin(2π * x[1]) * sin(2π * x[2])
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]

        # Canonical eval counts on Apple libm. Linux libm rounds sin(2π·x)
        # differently, so trig L2 residuals straddle l2_tolerance=1e-2 and
        # split decisions can flip — observed counts up to ~1.2× canonical
        # on glibc. We pin a 2× band: catches genuine regressions (eval
        # explosions, infinite-split bugs) while tolerating libm drift.
        canonical = Dict(4 => 3745, 6 => 7441, 8 => 9111)

        for (degree, n_canon) in canonical
            n_evals = Ref(0)
            counted(x) = (n_evals[] += 1; trig(x))
            adaptive_refine(
                counted,
                bounds,
                degree;
                l2_tolerance = 1e-2,
                tolerance_mode = :relative,
                max_depth = 3,
                max_leaves = 20,
                parallel = false,
                n_samples_per_dim = 7,
                reuse_parent_samples = true,
            )
            @test n_canon ÷ 2 <= n_evals[] <= 2 * n_canon
        end
    end
end
