using Test
using Aqua
using Globtim

@testset "Aqua.jl Quality Assurance" begin
    # Full Aqua suite, no exclusions. `test_all` covers ambiguities, unbound_args,
    # undefined_exports, project_extras, stale_deps, deps_compat, piracies and
    # persistent_tasks.
    #
    # persistent_tasks was previously skipped on the theory that the TimerOutputs
    # global `_TO` tripped it. That is no longer true (verified on Julia 1.12.6 /
    # Aqua 0.8.14) — it passes, so it runs. It is the slow check here (~50s
    # locally): it spawns a subprocess that loads Globtim from scratch.
    #
    # undocumented_names is off by Aqua's own default and stays off for now: 60
    # public names lack docstrings. Tracked separately — flip it on there.
    # persistent_tasks tmax: Aqua defaults to 10s for the spawned subprocess to
    # load the package and exit. A cold load under CI contention can exceed that
    # and be misread as a lingering task — observed here as a real flake on
    # 2026-08-13 (failed with a formatter running alongside, passed on an idle
    # machine, same commit). A genuine persistent task never exits, so a longer
    # budget costs nothing on the happy path and removes the false positive.
    Aqua.test_all(Globtim; persistent_tasks = (; tmax = 90))
end
