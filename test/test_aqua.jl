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
    Aqua.test_all(Globtim)
end
