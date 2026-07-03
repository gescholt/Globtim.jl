#!/usr/bin/env julia
# run_per_axis_audit_cluster.jl
# Bead globopt_merged-vh7e (D.2) — cluster-scale per-step audit of the
# per-axis bump-vs-split predicate, driven by a TOML config.
#
# Sister of experiments/sandbox/run_per_axis_audit_perstep_3d.jl (bzvt, local
# 3D-analytical). Difference: this driver loads its problem from a
# `[model] catalogue_path + entry_name` catalogue (4D ODE) or `[model]
# analytical_function + dimension` analytical via the same machinery as
# pkg/globtim/scripts/run_experiment.jl, then short-circuits to
# `adaptive_refine` with an audit predicate wrapper (skipping HC + analysis).
#
# Usage:
#   julia --project=profiles/cluster pkg/globtim/scripts/run_per_axis_audit_cluster.jl \
#       experiments/cluster/per_axis_audit/lv4d_deg2_leaves32.toml
#
# Output (per [output] dir):
#   - predcall.jsonl         every predicate consultation as one line
#   - audit_summary.md       per-task tally (predcalls, disagreements, etc.)
#   - audit_summary.json     machine-readable mirror
#   - experiment_config.toml copy of the input TOML for reproducibility

using DynamicObjectives
using Globtim
using Globtim:
    Subdomain,
    SubdivisionTree,
    adaptive_refine,
    pick_strategy,
    pick_strategy_per_axis,
    decide_action,
    pick_strategy_per_axis_lsfit,
    decide_action_lsfit,
    subdomain_mode_spectrum,
    axis_shell_stats,
    get_bounds
using HomotopyContinuation  # weakdep activation; mirrors run_experiment.jl
import JSON3
import TOML
using Dates
using Printf

# ── Argument parsing ────────────────────────────────────────────────────────

function parse_args(args)
    isempty(args) && error(
        "Usage: julia run_per_axis_audit_cluster.jl <config.toml>",
    )
    path = abspath(first(args))
    isfile(path) || error("Config file not found: $path")
    return path
end

# ── TOML [audit] section ────────────────────────────────────────────────────

function load_audit_section(path::String)
    raw = TOML.parsefile(path)
    audit = get(raw, "audit", Dict())
    return (
        max_leaves   = Int(get(audit, "max_leaves", 64)),
        l2_tolerance = Float64(get(audit, "l2_tolerance", 1e-4)),
        max_depth    = Int(get(audit, "max_depth", 10)),
        # DR-INSTR (8f4p.5.1): per-axis shell-mass tables in every predcall
        # row. The scalar/vector spectrum fields are always logged; this
        # switch only gates the (heavier) per-shell mass dictionaries.
        log_mode_spectrum = Bool(get(audit, "log_mode_spectrum", true)),
    )
end

# ── E1 sampling + E2 predicate kwargs (opt-in features) ────────────────────
#
# Reads `[polynomial]` keys:
#
#   E1 (Christoffel sampling):
#     - `sampling = "tensor" | "christoffel"`           (default "tensor")
#     - `christoffel_oversampling = 2.0`                 (default)
#     - `rng_base_seed = 20260523`                       (default)
#
#   E2 (LS-slope ρ_k predicate):
#     - `predicate = "default" | "ls_slope"`             (default "default")
#         "default"  → audit closure returns the pick_strategy verdict (unchanged)
#         "ls_slope" → audit closure returns `decide_action_lsfit(...)`
#         Since DR-INSTR (8f4p.5.1) BOTH modes log the same row shape,
#         including ρ_per_axis / slope_per_axis and the spectrum fields —
#         the mode only selects which predicate drives subdivision.
#     - `ls_slope_rho_threshold = 2.71828...`            (default exp(1.0))
#     - `ls_slope_shell_mass_floor = 1e-14`              (default)
#
# Both defaults reproduce the historical audit path bit-for-bit.
function load_sampling_section(path::String)
    raw = TOML.parsefile(path)
    poly = get(raw, "polynomial", Dict())
    sampling_str = String(get(poly, "sampling", "tensor"))
    sampling = Symbol(sampling_str)
    sampling in (:tensor, :christoffel) ||
        error("[polynomial] sampling must be \"tensor\" or \"christoffel\", got \"$sampling_str\"")
    christoffel_oversampling = Float64(get(poly, "christoffel_oversampling", 2.0))
    rng_base_seed = haskey(poly, "rng_base_seed") ? Int(poly["rng_base_seed"]) : 20260523

    # E2 — predicate selector
    predicate_str = String(get(poly, "predicate", "default"))
    predicate_kind = Symbol(predicate_str)
    predicate_kind in (:default, :ls_slope) || error(
        "[polynomial] predicate must be \"default\" or \"ls_slope\", got \"$predicate_str\"",
    )
    ls_slope_rho_threshold = Float64(get(poly, "ls_slope_rho_threshold", exp(1.0)))
    ls_slope_shell_mass_floor = Float64(get(poly, "ls_slope_shell_mass_floor", 1e-14))

    return (
        sampling = sampling,
        christoffel_oversampling = christoffel_oversampling,
        rng_base_seed = rng_base_seed,
        predicate = predicate_kind,
        ls_slope_rho_threshold = ls_slope_rho_threshold,
        ls_slope_shell_mass_floor = ls_slope_shell_mass_floor,
    )
end

# ── Catalogue / analytical → (objective, bounds) ─────────────────────────────
#
# Mirrors DynamicObjectivesGlobtimExt.run_experiment_from_config lines 80-202.
# Inlined here so the audit driver depends only on DynamicObjectives +
# Globtim, not on the experiment-extension's HC pipeline.

function build_objective_and_bounds(config)
    if config.catalogue_path !== nothing
        entries = load_catalogue(
            config.catalogue_path; model_name = config.entry_name,
        )
        matching = filter(e -> e.name == config.entry_name, entries)
        isempty(matching) && error(
            "Entry '$(config.entry_name)' not found in catalogue " *
            "'$(config.catalogue_path)'. Available: " *
            join([e.name for e in entries], ", "),
        )
        entry = first(matching)

        p_true = config.p_true !== nothing ? config.p_true : entry.p_true
        model, _, _, outputs = entry.model_fn()

        solver = config.solver_method !== nothing ?
            DynamicObjectives._resolve_solver(config.solver_method) :
            DynamicObjectives.Tsit5()
        abstol = config.solver_abstol !== nothing ? config.solver_abstol : 1e-4
        reltol = config.solver_reltol !== nothing ? config.solver_reltol : 1e-4

        if config.sample_times !== nothing
            time_interval = [config.sample_times[1], config.sample_times[end]]
            numpoints = length(config.sample_times)
            uneven_sampling_times = config.sample_times
        else
            numpoints = config.solver_numpoints !== nothing ?
                config.solver_numpoints : entry.numpoints
            time_interval = config.time_interval !== nothing ?
                config.time_interval : entry.time_interval
            uneven_sampling_times = Float64[]
        end

        objective = TolerantObjective(
            model, outputs, entry.ic, p_true, time_interval, numpoints,
            entry.distance_function, entry.aggregate_distances;
            solver = solver, abstol = abstol, reltol = reltol,
            uneven_sampling_times = uneven_sampling_times,
        )

        p_center = config.p_center !== nothing ? config.p_center : p_true
        bounds = if config.radius !== nothing
            build_bounds(p_center, config.radius)
        elseif config.radii !== nothing
            build_bounds(p_center, config.radii)
        elseif config.bounds !== nothing
            config.bounds
        else
            entry.bounds
        end

        return objective, bounds, config.entry_name
    else
        # Analytical mode (3D registry benchmarks).
        func_name = config.analytical_function
        dim = config.dimension
        bench = Globtim.get_benchmark_config_by_name(func_name, dim)
        bounds = config.bounds !== nothing ? config.bounds : bench.bounds
        return bench.objective, bounds, bench.name
    end
end

# ── Audit predicate wrapper ─────────────────────────────────────────────────
#
# Streams each predicate-call record to `partial_io` as it fires (atomic flush
# after every record) so a timeout-killed job still leaves recoverable audit
# data on disk. Final `predcall.jsonl` is written separately at end-of-run
# with the `global_split_dim` backfill applied.
#
# DR-INSTR (bead 8f4p.5.1): ONE mode spectrum is computed per predicate call
# and shared by all consumers — pick_strategy, pick_strategy_per_axis, and
# pick_strategy_per_axis_lsfit (previously 2 independent compute_mode_spectrum
# calls in default mode, 3 in ls_slope mode). Both modes now log the SAME row
# shape, so predcall.jsonl is analyzable uniformly:
#   - ls_verdicts / rho_per_axis / slope_per_axis / ls_action / ls_cut_dim
#     (previously ls_slope-mode-only; the LS fit is a per-shell OLS on the
#     already-computed spectrum, so logging it in default mode is free)
#   - spec_base_degree / spec_extended_degree / spectral_concentration /
#     shell_decay / window_coverage / dominant_mode (leaf-level spectrum)
#   - axis_mass / concentration_per_axis / decay_per_axis (the 2-pt
#     predicate's per-axis inputs — what jw9g.4 back-fits ρ_K from)
#   - axis_shell_mass (per-axis {shell => η²-mass} tables; gated by
#     `[audit] log_mode_spectrum` since it is the heavy part of the row)
#
# `mode = :default` returns the pick_strategy verdict (byte-identical
# subdivision decisions to the historical audit path); `mode = :ls_slope`
# returns the lsfit action.

# JSON has no NaN/Inf literal — map non-finite floats to `null` so predcall
# rows stay strictly parseable (a NaN ρ on a no-signal axis is data, not error).
_json_num(x::Real) = isfinite(x) ? Float64(x) : nothing
_json_vec(v) = Union{Float64,Nothing}[_json_num(x) for x in v]

function make_perstep_audit_predicate(
    records::Vector{NamedTuple},
    partial_io::Union{IO, Nothing},
    static_decoration::NamedTuple;
    mode::Symbol = :default,
    ρ_threshold::Float64 = exp(1.0),
    shell_mass_floor::Float64 = 1e-14,
    log_mode_spectrum::Bool = true,
)
    mode in (:default, :ls_slope) ||
        error("audit predicate mode must be :default or :ls_slope, got :$mode")
    # adaptive_refine calls `predicate(subdomain)` from concurrent
    # Threads.@spawn tasks (see process_subdomain). The lock guards both the
    # records push! (Julia Vector push is not thread-safe) and the partial-IO
    # write (interleaved JSON would corrupt downstream parsers).
    lock = ReentrantLock()
    return function (sd::Subdomain)
        spec = subdomain_mode_spectrum(sd)
        stats = axis_shell_stats(spec)

        g = pick_strategy(spec)
        per_axis = pick_strategy_per_axis(spec)
        action_2pt, cut_dim_2pt = decide_action(per_axis)
        ls_results = pick_strategy_per_axis_lsfit(
            spec;
            ρ_threshold = ρ_threshold,
            shell_mass_floor = shell_mass_floor,
        )
        ls_action, ls_cut_dim = decide_action_lsfit(ls_results)

        rec = (
            bounds            = copy(get_bounds(sd)),
            depth             = sd.depth,
            degree            = sd.degree,
            rel_l2            = sd.relative_l2_error,
            global_verdict    = g,
            per_axis_verdicts = collect(per_axis),
            per_axis_action   = action_2pt,
            per_axis_cut_dim  = cut_dim_2pt,
            ls_verdicts       = [r.verdict for r in ls_results],
            rho_per_axis      = _json_vec(r.rho for r in ls_results),
            slope_per_axis    = _json_vec(r.slope for r in ls_results),
            ls_action         = ls_action,
            ls_cut_dim        = ls_cut_dim,
            spec_base_degree  = spec.base_degree,
            spec_extended_degree = spec.extended_degree,
            spectral_concentration = _json_num(spec.spectral_concentration),
            shell_decay       = _json_num(spec.shell_decay),
            window_coverage   = _json_num(spec.window_coverage),
            dominant_mode     = collect(spec.dominant_mode),
            axis_mass         = _json_vec(s.total for s in stats),
            concentration_per_axis = _json_vec(s.concentration for s in stats),
            decay_per_axis    = _json_vec(s.decay for s in stats),
            consulted_at      = :predicate_call,
            global_split_dim  = nothing,
        )
        if log_mode_spectrum
            rec = merge(rec, (axis_shell_mass = [s.shell_mass for s in stats],))
        end
        Base.@lock lock begin
            push!(records, rec)
            if partial_io !== nothing
                JSON3.write(partial_io, merge(rec, static_decoration))
                println(partial_io)
                flush(partial_io)
            end
        end
        # :default returns the pick_strategy verdict (byte-identical to the
        # baseline run); :ls_slope hands subdivision to the LS-slope action.
        # adaptive_refine wants :bump / :split / :done.
        return mode === :ls_slope ? ls_action : g
    end
end

# ── Backfill global_split_dim from the final tree ───────────────────────────

function backfill_split_dims!(records::Vector{NamedTuple}, tree::SubdivisionTree)
    out = Vector{NamedTuple}(undef, length(records))
    for (i, r) in enumerate(records)
        sdim = nothing
        for sd in tree.subdomains
            sd.depth == r.depth || continue
            b = get_bounds(sd)
            length(b) == length(r.bounds) || continue
            if all(
                j -> isapprox(b[j][1], r.bounds[j][1]; atol = 1e-12) &&
                     isapprox(b[j][2], r.bounds[j][2]; atol = 1e-12),
                1:length(b),
            )
                sdim = sd.split_dim
                break
            end
        end
        out[i] = merge(r, (global_split_dim = sdim,))
    end
    return out
end

# ── Tally helpers ───────────────────────────────────────────────────────────

function tally_predcalls(records::Vector{NamedTuple})
    n_pc_concord_bump = 0
    n_pc_concord_split = 0
    n_pc_per_axis_stricter = 0
    n_pc_per_axis_looser = 0
    n_pc_cut_dim_agree = 0
    n_pc_cut_dim_disagree = 0
    n_pc_cut_dim_unknown = 0
    deg_hist = Dict{Int,Int}()
    depth_hist = Dict{Int,Int}()
    for r in records
        per_axis_has_split = any(==(:split), r.per_axis_verdicts)
        if r.global_verdict === :bump && !per_axis_has_split
            n_pc_concord_bump += 1
        elseif r.global_verdict === :split && per_axis_has_split
            n_pc_concord_split += 1
        elseif r.global_verdict === :bump && per_axis_has_split
            n_pc_per_axis_stricter += 1
        elseif r.global_verdict === :split && !per_axis_has_split
            n_pc_per_axis_looser += 1
        end
        if r.per_axis_action === :split && r.per_axis_cut_dim !== nothing
            if r.global_split_dim === nothing
                n_pc_cut_dim_unknown += 1
            elseif r.global_split_dim == r.per_axis_cut_dim
                n_pc_cut_dim_agree += 1
            else
                n_pc_cut_dim_disagree += 1
            end
        end
        deg_hist[r.degree] = get(deg_hist, r.degree, 0) + 1
        depth_hist[r.depth] = get(depth_hist, r.depth, 0) + 1
    end
    return (
        n_pc_concord_bump      = n_pc_concord_bump,
        n_pc_concord_split     = n_pc_concord_split,
        n_pc_per_axis_stricter = n_pc_per_axis_stricter,
        n_pc_per_axis_looser   = n_pc_per_axis_looser,
        n_pc_cut_dim_agree     = n_pc_cut_dim_agree,
        n_pc_cut_dim_disagree  = n_pc_cut_dim_disagree,
        n_pc_cut_dim_unknown   = n_pc_cut_dim_unknown,
        predcall_degree_histogram = deg_hist,
        predcall_depth_histogram  = depth_hist,
    )
end

# ── DR-INSTR spectrum summary (8f4p.5.1 subtask 3) ─────────────────────────
#
# Per-run distribution mirror of the per-axis spectrum signals, written into
# audit_summary.json so stage-2 can sanity-check calibration (θ_decay,
# θ_concentration, ρ_threshold) without re-reading predcall.jsonl.

function _quantiles5(v::Vector{Float64})
    isempty(v) && return nothing
    s = sort(v)
    n = length(s)
    q(p) = s[clamp(1 + round(Int, p * (n - 1)), 1, n)]
    return (min = s[1], q25 = q(0.25), median = q(0.5), q75 = q(0.75), max = s[end])
end

function _collect_finite(records, field::Symbol)
    vals = Float64[]
    n_missing = 0
    for r in records
        for x in getproperty(r, field)
            if x isa Float64
                push!(vals, x)
            else
                n_missing += 1
            end
        end
    end
    return vals, n_missing
end

function summarize_spectrum(records::Vector{NamedTuple})
    conc, conc_missing = _collect_finite(records, :concentration_per_axis)
    decay, decay_missing = _collect_finite(records, :decay_per_axis)
    rho, rho_missing = _collect_finite(records, :rho_per_axis)

    # Histogram of per-axis concentration over 10 uniform bins on [0, 1].
    conc_hist = zeros(Int, 10)
    for c in conc
        conc_hist[clamp(1 + floor(Int, c * 10), 1, 10)] += 1
    end

    return (
        concentration_per_axis = (
            hist_bins01 = conc_hist,
            n_missing = conc_missing,
            quantiles = _quantiles5(conc),
        ),
        decay_per_axis = (
            n_nonpos = count(<=(0.0), decay),
            n_pos = count(>(0.0), decay),
            n_missing = decay_missing,
            quantiles = _quantiles5(decay),
        ),
        rho_per_axis = (
            n_below_e = count(<(exp(1.0)), rho),
            n_missing = rho_missing,
            quantiles = _quantiles5(rho),
        ),
    )
end

# ── Output ──────────────────────────────────────────────────────────────────

function write_jsonl(records, path::String)
    open(path, "w") do io
        for r in records
            JSON3.write(io, r)
            println(io)
        end
    end
end

function emit_markdown(out_path::String, exp_name, audit_cfg, bounds, tally,
                       n_leaves, n_predcall, wall_s)
    open(out_path, "w") do io
        println(io, "# Per-axis audit — $exp_name")
        println(io)
        println(io, "Cluster-scale per-step audit (bead `vh7e`, D.2). " *
                   "Records every predicate consultation as a row in `predcall.jsonl`.")
        println(io)
        @printf(io, "Config: max_leaves=%d, l2_tolerance=%.0e, max_depth=%d\n",
                audit_cfg.max_leaves, audit_cfg.l2_tolerance, audit_cfg.max_depth)
        println(io, "Bounds: ", bounds)
        println(io)
        @printf(io, "- final tree: %d leaves\n", n_leaves)
        @printf(io, "- predicate-call records: %d\n", n_predcall)
        @printf(io, "- wall: %.1f s\n", wall_s)
        println(io, "- degree histogram: ", tally.predcall_degree_histogram)
        println(io, "- depth histogram: ", tally.predcall_depth_histogram)
        println(io)
        println(io, "| metric | count |")
        println(io, "|---|---|")
        @printf(io, "| concordant bump | %d |\n", tally.n_pc_concord_bump)
        @printf(io, "| concordant split | %d |\n", tally.n_pc_concord_split)
        @printf(io, "| per-axis stricter | %d |\n", tally.n_pc_per_axis_stricter)
        @printf(io, "| per-axis looser | %d |\n", tally.n_pc_per_axis_looser)
        @printf(io, "| cut-dim agree | %d |\n", tally.n_pc_cut_dim_agree)
        @printf(io, "| **cut-dim disagree** | %d |\n", tally.n_pc_cut_dim_disagree)
        @printf(io, "| cut-dim n/a | %d |\n", tally.n_pc_cut_dim_unknown)
    end
end

# ── Main ────────────────────────────────────────────────────────────────────

function main()
    println("[heartbeat] driver started: $(Dates.now())"); flush(stdout)
    path = parse_args(ARGS)
    config = Globtim.load_experiment_config(path)
    audit_cfg = load_audit_section(path)
    sampling_cfg = load_sampling_section(path)

    println("Loaded config: $(config.name)")
    println("  source: $path")
    println("  sampling: $(sampling_cfg.sampling)" *
            (sampling_cfg.sampling === :christoffel ?
             "  (c=$(sampling_cfg.christoffel_oversampling), rng_base_seed=$(sampling_cfg.rng_base_seed))" : ""))

    objective, bounds, obj_name = build_objective_and_bounds(config)
    dim = length(bounds)

    # Resolve [polynomial] degree_range → (base_degree, degree_step, max_degree)
    dr = config.degree_range
    base_degree = first(dr)
    degree_step = step(dr)
    max_degree  = last(dr)

    println("  dim=$dim  bounds=$bounds")
    println("  base_degree=$base_degree  degree_step=$degree_step  max_degree=$max_degree")
    println("  max_leaves=$(audit_cfg.max_leaves)  l2_tol=$(audit_cfg.l2_tolerance)")
    flush(stdout)

    output_dir = config.output_dir !== nothing ? config.output_dir : mktempdir()
    mkpath(output_dir)
    cp(realpath(path), joinpath(output_dir, "experiment_config.toml");
       force = true, follow_symlinks = true)

    records = NamedTuple[]

    # Streaming partial-output file: every predicate call lands on disk
    # immediately so a SIGTERM/walltime kill still leaves recoverable data.
    # The `global_split_dim` field is `nothing` here because backfill needs
    # the final tree; post-processors should treat the partial file as
    # "everything except cut-dim disagreement counts."
    partial_path = joinpath(output_dir, "predcall.partial.jsonl")
    partial_io = open(partial_path, "w")
    static_decoration = (
        experiment = String(config.name),
        entry_name = obj_name,
        catalogue_path = config.catalogue_path,
        base_degree = base_degree,
        max_degree  = max_degree,
        max_leaves  = audit_cfg.max_leaves,
        l2_tolerance = audit_cfg.l2_tolerance,
    )

    if sampling_cfg.predicate === :ls_slope
        println("  predicate: ls_slope  (ρ_threshold=$(sampling_cfg.ls_slope_rho_threshold), shell_mass_floor=$(sampling_cfg.ls_slope_shell_mass_floor))")
    end
    audit_pred = make_perstep_audit_predicate(
        records, partial_io, static_decoration;
        mode = sampling_cfg.predicate,
        ρ_threshold = sampling_cfg.ls_slope_rho_threshold,
        shell_mass_floor = sampling_cfg.ls_slope_shell_mass_floor,
        log_mode_spectrum = audit_cfg.log_mode_spectrum,
    )

    println("[heartbeat] adaptive_refine start: $(Dates.now())"); flush(stdout)
    t0 = time()
    tree = try
        adaptive_refine(
            objective,
            bounds,
            base_degree;
            enable_p_refinement = true,
            max_degree   = max_degree,
            degree_step  = degree_step,
            max_leaves   = audit_cfg.max_leaves,
            max_depth    = audit_cfg.max_depth,
            l2_tolerance = audit_cfg.l2_tolerance,
            tolerance_mode = :relative,
            predicate    = audit_pred,
            sampling     = sampling_cfg.sampling,
            christoffel_oversampling = sampling_cfg.christoffel_oversampling,
            rng_base_seed = sampling_cfg.rng_base_seed,
            # T1.0 speed-up (bench_thread_evals.jl, 2026-05-21): inner-only
            # threading gives 3.13× over default outer-leaf parallelism on
            # the lv4d_deg2_leaves32 reference cell. Hybrid (parallel=true,
            # thread_evals=true) tied to within 1% but risks oversubscription
            # on multi-thread tasks; prefer the simpler inner-only config.
            parallel     = false,
            thread_evals = true,
        )
    finally
        close(partial_io)
    end
    wall = time() - t0
    @printf("[heartbeat] adaptive_refine done in %.1fs\n", wall); flush(stdout)

    records = backfill_split_dims!(records, tree)
    tally = tally_predcalls(records)
    n_leaves = length(tree.active_leaves) +
               length(tree.converged_leaves) +
               length(tree.pruned_leaves)

    # Decorate JSONL rows with the experiment-name + audit knobs so stage-2
    # can stratify without re-reading the TOML.
    decorated = [merge(r, (
        experiment = String(config.name),
        entry_name = obj_name,
        catalogue_path = config.catalogue_path,
        base_degree = base_degree,
        max_degree  = max_degree,
        max_leaves  = audit_cfg.max_leaves,
        l2_tolerance = audit_cfg.l2_tolerance,
    )) for r in records]

    predcall_path = joinpath(output_dir, "predcall.jsonl")
    write_jsonl(decorated, predcall_path)
    emit_markdown(joinpath(output_dir, "audit_summary.md"),
                  config.name, audit_cfg, bounds, tally,
                  n_leaves, length(records), wall)

    open(joinpath(output_dir, "audit_summary.json"), "w") do io
        JSON3.pretty(io, (
            generated  = string(Dates.now()),
            experiment = String(config.name),
            entry_name = obj_name,
            dim        = dim,
            bounds     = bounds,
            base_degree = base_degree,
            degree_step = degree_step,
            max_degree  = max_degree,
            max_leaves  = audit_cfg.max_leaves,
            l2_tolerance = audit_cfg.l2_tolerance,
            n_leaves   = n_leaves,
            n_predcall = length(records),
            wall_s     = wall,
            tally      = tally,
            spectrum_summary = summarize_spectrum(records),
        ))
    end

    @printf("Done in %.1f s — n_leaves=%d  n_predcall=%d  cut_dim_disagree=%d\n",
            wall, n_leaves, length(records), tally.n_pc_cut_dim_disagree)
    println("Wrote $predcall_path")
    flush(stdout)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
