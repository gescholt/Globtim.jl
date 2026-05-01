@testset "SolverTimeoutError: unit tests" begin
    # T1: fast function completes normally
    result = Globtim.with_solver_timeout(() -> 42, 5.0; label = "fast")
    @test result == 42

    # T2: slow function throws SolverTimeoutError
    @test_throws Globtim.SolverTimeoutError Globtim.with_solver_timeout(
        () -> sleep(1.0),
        0.15;
        label = "slow",
    )

    # T3: nothing timeout is a passthrough (no thread spawn, returns normally)
    result3 = Globtim.with_solver_timeout(() -> "ok", nothing; label = "passthrough")
    @test result3 == "ok"

    # T4: non-timeout exceptions propagate unchanged
    @test_throws ErrorException Globtim.with_solver_timeout(
        () -> error("propagated"),
        5.0;
        label = "error_propagation",
    )
end

@testset "SolverTimeoutError: degree loop continues after timeout" begin
    # Test that with_solver_timeout can be called in a loop (like run_standard_experiment's
    # degree loop) and each call times out independently without aborting the loop.
    #
    # NOTE: We test at the with_solver_timeout level rather than through
    # run_standard_experiment to avoid a TimerOutputs thread-safety issue: Constructor
    # calls @timeit on a shared global TimerOutput; concurrent zombie tasks from back-
    # to-back degree timeouts race on that object and SIGABRT.
    slow_op = () -> sleep(5.0)
    degree_statuses = String[]

    for degree in [4, 6]
        try
            Globtim.with_solver_timeout(slow_op, 0.2; label = "degree $degree")
            push!(degree_statuses, "success")
        catch e
            if e isa Globtim.SolverTimeoutError
                push!(degree_statuses, "timeout")
            else
                rethrow()
            end
        end
    end

    @test length(degree_statuses) == 2
    @test all(s -> s == "timeout", degree_statuses)
end

@testset "SolverTimeoutError: msolve process-level kill" begin
    # Use `sleep` binary as a stand-in for a long-running msolve call.
    # timedwait + kill should fire within 0.15s, not 5s.
    sleep_cmd = `sleep 5`
    t_start = time()
    @test_throws Globtim.SolverTimeoutError begin
        proc = run(sleep_cmd, wait = false)
        did_finish = timedwait(() -> !process_running(proc), 0.15)
        if did_finish == :timed_out
            kill(proc)
            throw(Globtim.SolverTimeoutError("msolve_test", 0.15))
        end
    end
    elapsed = time() - t_start
    @test elapsed < 1.0  # must not have waited for `sleep 5` to finish
end
