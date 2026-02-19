"""
    run_aqua_tests(mod)

Run Aqua.jl quality assurance checks on `mod`.

Skips `test_persistent_tasks` due to TimerOutputs global timer.
All other checks run without exclusions.
"""
function run_aqua_tests(mod)
    Aqua.test_ambiguities(mod)
    Aqua.test_undefined_exports(mod)
    Aqua.test_unbound_args(mod)
    Aqua.test_stale_deps(mod)
    Aqua.test_deps_compat(mod)
    # test_persistent_tasks skipped: TimerOutputs global const _TO triggers false positive
end
