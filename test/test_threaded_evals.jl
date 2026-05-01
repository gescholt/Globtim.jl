using Test
using Globtim

# Tests for the thread_evals kwarg added to estimate_subdomain_error,
# find_optimal_cut_sparse, process_subdomain, adaptive_refine, two_phase_refine.
#
# The threaded path is only exercised when Threads.nthreads() > 1. In that
# case we assert that it produces bit-for-bit identical results to the
# sequential path when f is pure-Julia. Thread-safety of ODE-based objectives
# is validated separately in Dynamic_objectives (see bead iyj).

@testset "thread_evals kwarg" begin
    # Pure-Julia objective — thread-safe by construction, no shared state.
    # 3D is enough to hit the (2*4+1)^3 = 729 grid-point inner loop without
    # making the test slow.
    sphere(x) = sum(abs2, x)
    bounds = [(-1.0, 1.0), (-1.0, 1.0), (-1.0, 1.0)]

    @testset "estimate_subdomain_error (threaded == sequential)" begin
        tree_seq = Globtim.SubdivisionTree(bounds; degree = 4)
        tree_par = Globtim.SubdivisionTree(bounds; degree = 4)

        l2_seq = Globtim.estimate_subdomain_error(
            sphere,
            tree_seq.subdomains[1],
            4;
            basis = :chebyshev,
            thread_evals = false,
        )
        l2_par = Globtim.estimate_subdomain_error(
            sphere,
            tree_par.subdomains[1],
            4;
            basis = :chebyshev,
            thread_evals = true,
        )

        @test l2_seq == l2_par
        @test tree_seq.subdomains[1].f_values == tree_par.subdomains[1].f_values
    end

    @testset "adaptive_refine produces identical trees" begin
        # thread_evals=true should not change the structure of the refined tree
        # when f is deterministic.
        tree_seq = Globtim.adaptive_refine(
            sphere,
            bounds,
            4;
            l2_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 3,
            max_leaves = 50,
            verbose = false,
            thread_evals = false,
        )
        tree_par = Globtim.adaptive_refine(
            sphere,
            bounds,
            4;
            l2_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 3,
            max_leaves = 50,
            verbose = false,
            thread_evals = true,
        )

        @test Globtim.n_leaves(tree_seq) == Globtim.n_leaves(tree_par)
        @test length(tree_seq.converged_leaves) == length(tree_par.converged_leaves)

        # Per-leaf L2 errors should match (same evaluations, same polynomial fits).
        seq_errors =
            sort([tree_seq.subdomains[id].l2_error for id in keys(tree_seq.subdomains)])
        par_errors =
            sort([tree_par.subdomains[id].l2_error for id in keys(tree_par.subdomains)])
        @test seq_errors == par_errors
    end

    @testset "two_phase_refine plumbs thread_evals" begin
        # Smoke-test that the kwarg propagates through two_phase_refine without
        # changing results. Short budget — we only want to confirm plumbing.
        tree_seq = Globtim.two_phase_refine(
            sphere,
            bounds,
            4;
            coarse_tolerance = 1e-2,
            fine_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 2,
            max_leaves = 20,
            verbose = false,
            thread_evals = false,
        )
        tree_par = Globtim.two_phase_refine(
            sphere,
            bounds,
            4;
            coarse_tolerance = 1e-2,
            fine_tolerance = 1e-3,
            tolerance_mode = :absolute,
            max_depth = 2,
            max_leaves = 20,
            verbose = false,
            thread_evals = true,
        )

        @test Globtim.n_leaves(tree_seq) == Globtim.n_leaves(tree_par)
    end

    @testset "default (thread_evals=false) is unchanged" begin
        # Regression: callers that never set the kwarg must still behave
        # exactly as before.
        tree = Globtim.SubdivisionTree(bounds; degree = 4)
        l2 = Globtim.estimate_subdomain_error(
            sphere,
            tree.subdomains[1],
            4;
            basis = :chebyshev,
        )
        @test isfinite(l2)
        @test tree.subdomains[1].polynomial !== nothing
    end

    @testset "Constructor / MainGenerate (threaded == sequential)" begin
        # Cover the Main_Gen.jl evaluation path separately from
        # adaptive_subdivision.jl.
        TR = TestInput(
            sphere,
            dim = 3,
            center = [0.0, 0.0, 0.0],
            GN = 10,
            sample_range = 1.0,
        )

        p_seq =
            Constructor(TR, 4; basis = :chebyshev, normalized = false, thread_evals = false)
        p_par =
            Constructor(TR, 4; basis = :chebyshev, normalized = false, thread_evals = true)

        @test p_seq.coeffs == p_par.coeffs
        @test p_seq.nrm == p_par.nrm
    end

    # Diagnostic: if this test file runs with Threads.nthreads() == 1 the
    # threaded path is a no-op — print so CI logs make the coverage visible.
    @info "thread_evals tests ran with Threads.nthreads() = $(Threads.nthreads())"
end
