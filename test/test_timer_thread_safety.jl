using Test
using Globtim

# Bead 7kdo: adaptive_refine(; parallel = true) fits leaves in Threads.@spawn tasks,
# and every fit pushed and popped the one global TimerOutputs stack `_TO`. With
# JULIA_NUM_THREADS > 1 that corrupted the stack (korok job 948633: pop! on an
# empty array from lambda_vandermonde_original). The timed sections are now
# `@timeit_debug`, off unless enabled, and the parallel paths refuse to run while
# they are on.

const _TimerOutputs = Globtim.TimerOutputs

@testset "global timer is off by default and safe under parallel refine" begin
    @test Globtim.timeit_debug_enabled() == false
    @test Globtim._check_timer_thread_safety("test") === nothing
    @test_throws ErrorException print_timing_breakdown()

    # The crash path: concurrent process_subdomain fits (select_cut_dimension ->
    # lambda_vandermonde_original). Only races when nthreads() > 1, runs either way.
    f(x) = sum(cos.(6 .* x)) + 0.1 * sum(abs2, x)
    tree = Globtim.adaptive_refine(
        f,
        [(-1.0, 1.0), (-1.0, 1.0)],
        4;
        l2_tolerance = 1e-6,
        tolerance_mode = :absolute,
        max_depth = 4,
        max_leaves = 16,
        parallel = true,
    )
    @test Globtim.n_leaves(tree) > 1
    @test isempty(Globtim._TO.inner_timers)
end

@testset "debug timings: recorded when enabled, parallel paths refuse" begin
    _TimerOutputs.enable_debug_timings(Globtim)
    try
        # enable_debug_timings redefines a method; call through the new world
        @test Base.invokelatest(Globtim.timeit_debug_enabled)
        @test_throws ErrorException Base.invokelatest(
            Globtim._check_timer_thread_safety,
            "adaptive_refine(; parallel = true)",
        )
    finally
        _TimerOutputs.disable_debug_timings(Globtim)
        _TimerOutputs.reset_timer!(Globtim._TO)
    end
    @test Base.invokelatest(Globtim.timeit_debug_enabled) == false
end
