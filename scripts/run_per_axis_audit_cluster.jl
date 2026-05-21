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

function make_perstep_audit_predicate(
    records::Vector{NamedTuple},
    partial_io::Union{IO, Nothing},
    static_decoration::NamedTuple,
)
    # adaptive_refine calls `predicate(subdomain)` from concurrent
    # Threads.@spawn tasks (see process_subdomain). The lock guards both the
    # records push! (Julia Vector push is not thread-safe) and the partial-IO
    # write (interleaved JSON would corrupt downstream parsers).
    lock = ReentrantLock()
    return function (sd::Subdomain)
        g = pick_strategy(sd)
        per_axis = pick_strategy_per_axis(sd)
        action, cut_dim = decide_action(per_axis)
        rec = (
            bounds            = copy(get_bounds(sd)),
            depth             = sd.depth,
            degree            = sd.degree,
            rel_l2            = sd.relative_l2_error,
            global_verdict    = g,
            per_axis_verdicts = collect(per_axis),
            per_axis_action   = action,
            per_axis_cut_dim  = cut_dim,
            consulted_at      = :predicate_call,
            global_split_dim  = nothing,
        )
        Base.@lock lock begin
            push!(records, rec)
            if partial_io !== nothing
                JSON3.write(partial_io, merge(rec, static_decoration))
                println(partial_io)
                flush(partial_io)
            end
        end
        return g  # byte-identical to baseline pick_strategy run
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

    println("Loaded config: $(config.name)")
    println("  source: $path")

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

    audit_pred = make_perstep_audit_predicate(records, partial_io, static_decoration)

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
