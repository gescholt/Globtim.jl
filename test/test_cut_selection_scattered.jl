using Test
using Globtim
using Globtim: Subdomain, estimate_subdomain_error, select_cut_dimension

# bead 0lhz.3: `select_cut_dimension` scores each axis by the variance of the
# residual along 1-D grid lines (points sharing every other coordinate). A
# christoffel design has no such lines, so every axis scored 0.0 and `argmax`
# returned axis 1 at every level: the k000 christoffel arm (cluster job 975743) bisected
# axis 1 nine times, its 512 leaves had half-widths (0.0016, 0.9, 0.8, 0.9), and no
# leaf ever left the root box's error. Scattered designs now use the variance of
# binned residual means along each axis; tensor designs are unchanged.

@testset "select_cut_dimension on scattered designs" begin
    box3 = [(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]

    @testset "christoffel design: the residual lives on axis 2" begin
        f(x) = 0.1 * x[1] + exp(3 * x[2])   # degree 3 misses the exponential along axis 2
        sd = Subdomain(box3)
        estimate_subdomain_error(f, sd, 3; basis = :chebyshev, sampling = :christoffel,
            rng_seed = 7)
        @test select_cut_dimension(sd) == 2
    end

    @testset "christoffel design: the residual lives on axis 3" begin
        f(x) = 0.1 * x[2] + exp(3 * x[3])
        sd = Subdomain(box3)
        estimate_subdomain_error(f, sd, 3; basis = :chebyshev, sampling = :christoffel,
            rng_seed = 7)
        @test select_cut_dimension(sd) == 3
    end

    @testset "tensor design: grid-line scores still decide" begin
        f(x) = 0.1 * x[1] + exp(3 * x[2])
        sd = Subdomain(box3)
        estimate_subdomain_error(f, sd, 3; basis = :chebyshev)
        @test select_cut_dimension(sd) == 2
    end

    @testset "a christoffel tree cuts more than one axis" begin
        # Isotropic: every axis carries the same residual, so a tree that only ever
        # cuts axis 1 (the pre-fix behaviour, leaves (1/8, 1, 1)) is wrong on its face.
        f(x) = exp(2 * x[1]) + exp(2 * x[2]) + exp(2 * x[3])
        tree = Globtim.adaptive_refine(f, box3, 3;
            l2_tolerance = 1e-9, tolerance_mode = :relative,
            enable_p_refinement = false, max_depth = 3, max_leaves = 8,
            n_samples_per_dim = 6, sampling = :christoffel, rng_base_seed = 11,
            parallel = false, verbose = false)
        leaves = vcat(tree.converged_leaves, tree.active_leaves, tree.pruned_leaves)
        cut_axes = Set{Int}()
        for id in leaves
            hw = tree.subdomains[id].half_widths
            for d in 1:3
                hw[d] < 1.0 && push!(cut_axes, d)
            end
        end
        @test length(cut_axes) >= 2
    end

    @testset "a parallel christoffel tree builds (no shared-timer race)" begin
        # cluster job 1203749 / 1203752: parallel leaf tasks of a christoffel tree died in
        # lambda_vandermonde_original's global TimerOutput ("Vector can not be resized
        # concurrently", "array must be non-empty"). Many small concurrent fits.
        if Threads.nthreads() < 2
            @test_skip "needs julia -t >= 2 to exercise the parallel leaf fits"
        else
            box4 = fill((-1.0, 1.0), 4)
            f4(x) = exp(x[1]) * cos(2 * x[2]) + x[3]^2 - 0.5 * x[4]^3
            for seed in 1:3
                tree = Globtim.adaptive_refine(f4, box4, 3;
                    l2_tolerance = 1e-12, tolerance_mode = :relative,
                    enable_p_refinement = false, max_depth = 8, max_leaves = 64,
                    sampling = :christoffel, christoffel_oversampling = 2.0,
                    rng_base_seed = seed, parallel = true, verbose = false)
                leaves = vcat(tree.converged_leaves, tree.active_leaves)
                @test length(leaves) == 64
                @test all(tree.subdomains[id].polynomial !== nothing for id in leaves)
            end
        end
    end
end
