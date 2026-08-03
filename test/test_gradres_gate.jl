# test_gradres_gate.jl — GRADRES-GATE recovered-minimizer convergence gate (bead jw9g.1).
# Verifies `_recovered_minimizer_plateaued`: stop the degree sweep once the recovered
# global minimizer stops moving, regardless of the still-falling L2 error (finding F9).
# The helper is field-duck-typed (reads .status/.degree/.best_estimate), so NamedTuple
# stand-ins exercise it without building full DegreeResult objects.

@testset "GRADRES-GATE: recovered-minimizer plateau" begin
    # The helper lives in the StandardExperiment submodule (matches sibling tests'
    # `Globtim.StandardExperiment._foo` convention); it is not hoisted to Globtim's namespace.
    mk(deg, m) = (; status = "success", degree = deg, best_estimate = m)

    # Minimizer plateaus after degree 4: two consecutive sub-tol steps ⇒ STOP.
    plateaued = [mk(4, [1.0, 2.0]), mk(6, [1.0001, 2.0001]), mk(8, [1.00011, 2.00009])]
    @test Globtim.StandardExperiment._recovered_minimizer_plateaued(plateaued, 1e-3)

    # Minimizer still moving by ~10% each step ⇒ DO NOT stop.
    moving = [mk(4, [1.0, 2.0]), mk(6, [1.1, 2.1]), mk(8, [1.2, 2.2])]
    @test !Globtim.StandardExperiment._recovered_minimizer_plateaued(moving, 1e-3)

    # Only one sub-tol step at the end (the prior step is large) ⇒ DO NOT stop
    # (requires two consecutive, mirroring the L2 gate's robustness).
    one_step = [mk(4, [1.0, 2.0]), mk(6, [1.3, 2.3]), mk(8, [1.30005, 2.30005])]
    @test !Globtim.StandardExperiment._recovered_minimizer_plateaued(one_step, 1e-3)

    # Fewer than 3 successful minimizers ⇒ cannot conclude ⇒ false.
    @test !Globtim.StandardExperiment._recovered_minimizer_plateaued([mk(4, [1.0]), mk(6, [1.0])], 1e-3)

    # Degrees that found no minimizer (best_estimate === nothing) are skipped, and the
    # decision uses the surviving sequence sorted by degree (here: deg 4,8,10 plateau).
    holes = [
        mk(4, [1.0, 2.0]),
        (; status = "success", degree = 6, best_estimate = nothing),
        mk(8, [1.0001, 2.0001]),
        mk(10, [1.00011, 2.00009]),
    ]
    @test Globtim.StandardExperiment._recovered_minimizer_plateaued(holes, 1e-3)

    # Failed/timeout degrees are filtered out by the status check.
    with_failures = [
        mk(4, [1.0, 2.0]),
        (; status = "timeout", degree = 6, best_estimate = [9.0, 9.0]),
        mk(8, [1.0001, 2.0001]),
        mk(10, [1.00011, 2.00009]),
    ]
    @test Globtim.StandardExperiment._recovered_minimizer_plateaued(with_failures, 1e-3)
end
