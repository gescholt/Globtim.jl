#!/usr/bin/env julia
# run_per_axis_counterfactual_cluster.jl
# Bead globopt_merged-vh7e (D.2) — cluster-scale counterfactual A/B on the
# per-axis cut-dim disagreements logged by run_per_axis_audit_cluster.jl.
#
# For each disagreement leaf (per_axis_cut_dim != global_split_dim), fork the
# parent subdomain twice via subdivide_domain:
#   branch A: cut on the global predicate's chosen axis
#   branch B: cut on the per-axis predicate's chosen axis
# Then adaptive_refine each child to a budget (max_leaves_per_child) and
# compare max relative L2 error + total leaves to declare per_axis / global /
# tie. Writes verdicts.jsonl + summary.{md,json}.
#
# Driven by a stage-2 TOML config under experiments/cluster/per_axis_audit/
# carrying:
#   [model]   — same as stage 1 (catalogue + entry_name, or analytical)
#   [domain]  — same
#   [polynomial] degree_range — same base/step/max as stage 1
#   [solver]  — same
#   [audit_cf]
#       predcall_dir = "globtim_results/cluster/per_axis_audit/<family>"
#           # recursive search for predcall.jsonl files under this root
#       max_leaves_per_child = 16   # or 64, 256
#       max_depth = 10              # optional, default 10
#       experiment_filter = "lv4d_audit_deg2_leaves32"  # optional; restrict
#           # to predcall rows whose `experiment` field matches
#   [output]  dir = "globtim_results/cluster/per_axis_audit/.../cf_budget16"
#
# Usage:
#   julia --project=profiles/cluster pkg/globtim/scripts/run_per_axis_counterfactual_cluster.jl \
#       experiments/cluster/per_axis_audit/lv4d_cf_budget16.toml

using Dynamic_objectives
using Globtim
using Globtim:
    Subdomain,
    SubdivisionTree,
    adaptive_refine,
    pick_strategy,
    subdivide_domain,
    get_bounds
using HomotopyContinuation
import JSON3
import TOML
using Dates
using Printf

# ── Argument parsing ────────────────────────────────────────────────────────

function parse_args(args)
    isempty(args) && error(
        "Usage: julia run_per_axis_counterfactual_cluster.jl <config.toml>",
    )
    path = abspath(first(args))
    isfile(path) || error("Config file not found: $path")
    return path
end

# ── Catalogue / analytical → (objective, bounds) ────────────────────────────
# Mirrors run_per_axis_audit_cluster.jl::build_objective_and_bounds; kept
# inline here to keep the two stage scripts independent.

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
            Dynamic_objectives._resolve_solver(config.solver_method) :
            Dynamic_objectives.Tsit5()
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
        func_name = config.analytical_function
        dim = config.dimension
        bench = Globtim.get_benchmark_config_by_name(func_name, dim)
        bounds = config.bounds !== nothing ? config.bounds : bench.bounds
        return bench.objective, bounds, bench.name
    end
end

function load_cf_section(path::String)
    raw = TOML.parsefile(path)
    cf = get(raw, "audit_cf", Dict())
    haskey(cf, "predcall_dir") || error(
        "[audit_cf] predcall_dir (String, root to walk for predcall.jsonl) " *
        "is required in $path",
    )
    return (
        predcall_dir         = String(cf["predcall_dir"]),
        max_leaves_per_child = Int(get(cf, "max_leaves_per_child", 16)),
        max_depth            = Int(get(cf, "max_depth", 10)),
        experiment_filter    = get(cf, "experiment_filter", nothing),
    )
end

# ── Load disagreement leaves from one or more predcall.jsonl files ──────────

function find_predcall_files(root::String)
    isdir(root) || error("predcall_dir does not exist: $root")
    paths = String[]
    for (dir, _, files) in walkdir(root)
        for fn in files
            fn == "predcall.jsonl" && push!(paths, joinpath(dir, fn))
        end
    end
    sort!(paths)
    return paths
end

function load_disagreements(root::String; experiment_filter)
    paths = find_predcall_files(root)
    out = NamedTuple[]
    for path in paths
        for line in eachline(path)
            isempty(strip(line)) && continue
            r = JSON3.read(line)
            if experiment_filter !== nothing
                String(r.experiment) == experiment_filter || continue
            end
            String(r.consulted_at) == "predicate_call" || continue
            String(r.per_axis_action) == "split" || continue
            r.per_axis_cut_dim !== nothing || continue
            r.global_split_dim !== nothing || continue
            Int(r.per_axis_cut_dim) != Int(r.global_split_dim) || continue
            bounds = [(Float64(b[1]), Float64(b[2])) for b in r.bounds]
            push!(out, (
                source           = path,
                experiment       = String(r.experiment),
                bounds           = bounds,
                depth            = Int(r.depth),
                degree           = Int(r.degree),
                rel_l2           = Float64(r.rel_l2),
                per_axis_cut_dim = Int(r.per_axis_cut_dim),
                global_split_dim = Int(r.global_split_dim),
                base_degree      = Int(r.base_degree),
                max_degree       = Int(r.max_degree),
                max_leaves_stage1 = Int(r.max_leaves),
                l2_tolerance     = Float64(r.l2_tolerance),
            ))
        end
    end
    return out
end

# ── A/B forking helper ──────────────────────────────────────────────────────

function run_child_subtrees(objective, parent_bounds, cut_dim::Int;
                            base_degree, degree_step, max_degree,
                            l2_tol, max_leaves_per_child, max_depth)
    parent_sd = Subdomain(parent_bounds)
    left, right = subdivide_domain(parent_sd, cut_dim, 0.0)
    child_bounds = [get_bounds(left), get_bounds(right)]

    t0 = time()
    total_leaves = 0
    max_rel = 0.0
    for cb in child_bounds
        tree = adaptive_refine(
            objective, cb, base_degree;
            enable_p_refinement = true,
            max_degree    = max_degree,
            degree_step   = degree_step,
            max_leaves    = max_leaves_per_child,
            max_depth     = max_depth,
            l2_tolerance  = l2_tol,
            tolerance_mode = :relative,
            predicate     = pick_strategy,
        )
        leaves = vcat(tree.active_leaves,
                      tree.converged_leaves,
                      tree.pruned_leaves)
        total_leaves += length(leaves)
        for i in leaves
            rl = tree.subdomains[i].relative_l2_error
            if isfinite(rl) && rl > max_rel
                max_rel = rl
            end
        end
    end
    return (total_leaves = total_leaves,
            max_rel_l2 = max_rel,
            wall_s = time() - t0)
end

function declare_winner(a, b)
    if isapprox(a.max_rel_l2, b.max_rel_l2; rtol = 0.01)
        b.total_leaves < a.total_leaves ? "per_axis" :
        b.total_leaves > a.total_leaves ? "global" : "tie"
    elseif b.max_rel_l2 < a.max_rel_l2
        "per_axis"
    else
        "global"
    end
end

# ── Main ────────────────────────────────────────────────────────────────────

function main()
    path = parse_args(ARGS)
    config = Globtim.load_experiment_config(path)
    cf_cfg = load_cf_section(path)

    println("Loaded config: $(config.name)")

    objective, bounds, obj_name = build_objective_and_bounds(config)
    # degree_step is the only per-leaf knob we don't have in the JSONL row;
    # take it from [polynomial] degree_range (audit and counterfactual share
    # the same step). base_degree and max_degree come from each leaf at
    # fork time (see loop below) so the counterfactual matches the audit
    # condition under which the disagreement was logged.
    dr = config.degree_range
    degree_step = step(dr)

    # l2_tolerance: prefer [audit_cf] override, else inherit from [audit],
    # else from the leaf's predcall row.
    raw = TOML.parsefile(path)
    cf_raw = get(raw, "audit_cf", Dict())
    audit_raw = get(raw, "audit", Dict())
    l2_tol_cfg = haskey(cf_raw, "l2_tolerance") ? Float64(cf_raw["l2_tolerance"]) :
                 haskey(audit_raw, "l2_tolerance") ? Float64(audit_raw["l2_tolerance"]) :
                 nothing

    println("  objective: $obj_name  dim=$(length(bounds))")
    println("  degree_step=$degree_step (base_degree, max_degree from leaf JSONL)")
    println("  budget=$(cf_cfg.max_leaves_per_child)  l2_tol_cfg=$l2_tol_cfg")
    println("  predcall_dir: $(cf_cfg.predcall_dir)")

    leaves = load_disagreements(cf_cfg.predcall_dir;
                                experiment_filter = cf_cfg.experiment_filter)
    println("Loaded $(length(leaves)) disagreement leaves.")
    flush(stdout)

    output_dir = config.output_dir !== nothing ? config.output_dir : mktempdir()
    mkpath(output_dir)
    cp(realpath(path), joinpath(output_dir, "experiment_config.toml");
       force = true, follow_symlinks = true)

    records = NamedTuple[]
    n_done = 0
    n_total = length(leaves)
    t_start = time()
    for leaf in leaves
        n_done += 1
        # Per-leaf fork settings: continue the audit from the leaf's
        # base_degree/max_degree (carried in the predcall row), with the
        # l2_tol from config if set, else the leaf's audit-time tolerance.
        l2_tol_leaf = l2_tol_cfg !== nothing ? l2_tol_cfg : leaf.l2_tolerance
        # Branch A: global's chosen axis
        a = run_child_subtrees(
            objective, leaf.bounds, leaf.global_split_dim;
            base_degree = leaf.base_degree, degree_step = degree_step,
            max_degree = leaf.max_degree, l2_tol = l2_tol_leaf,
            max_leaves_per_child = cf_cfg.max_leaves_per_child,
            max_depth = cf_cfg.max_depth,
        )
        # Branch B: per-axis's chosen axis
        b = run_child_subtrees(
            objective, leaf.bounds, leaf.per_axis_cut_dim;
            base_degree = leaf.base_degree, degree_step = degree_step,
            max_degree = leaf.max_degree, l2_tol = l2_tol_leaf,
            max_leaves_per_child = cf_cfg.max_leaves_per_child,
            max_depth = cf_cfg.max_depth,
        )
        winner = declare_winner(a, b)
        push!(records, (
            experiment       = leaf.experiment,
            source_predcall  = leaf.source,
            depth            = leaf.depth,
            degree           = leaf.degree,
            base_degree      = leaf.base_degree,
            max_degree       = leaf.max_degree,
            max_leaves_stage1 = leaf.max_leaves_stage1,
            budget           = cf_cfg.max_leaves_per_child,
            global_split_dim = leaf.global_split_dim,
            per_axis_cut_dim = leaf.per_axis_cut_dim,
            branch_global    = a,
            branch_per_axis  = b,
            winner           = winner,
        ))
        @printf("[%d/%d] d=%d b=%d  global(%d, %.2e)  per_axis(%d, %.2e)  → %s\n",
            n_done, n_total, leaf.depth, cf_cfg.max_leaves_per_child,
            a.total_leaves, a.max_rel_l2,
            b.total_leaves, b.max_rel_l2,
            winner)
        flush(stdout)
    end
    total_wall = time() - t_start

    n_per_axis = count(r -> r.winner == "per_axis", records)
    n_global   = count(r -> r.winner == "global",   records)
    n_tie      = count(r -> r.winner == "tie",      records)

    open(joinpath(output_dir, "verdicts.jsonl"), "w") do io
        for r in records
            JSON3.write(io, r)
            println(io)
        end
    end

    open(joinpath(output_dir, "summary.md"), "w") do io
        println(io, "# vh7e — counterfactual (cluster, $(config.name))")
        println(io)
        @printf(io, "Input: %d disagreement leaves, budget=%d, %.1f min wall.\n",
                length(leaves), cf_cfg.max_leaves_per_child, total_wall/60)
        println(io)
        println(io, "## Aggregate")
        println(io)
        if length(records) > 0
            @printf(io, "- per_axis: %d (%.1f%%)\n",
                    n_per_axis, 100*n_per_axis/length(records))
            @printf(io, "- global:   %d (%.1f%%)\n",
                    n_global,   100*n_global/length(records))
            @printf(io, "- tie:      %d (%.1f%%)\n",
                    n_tie,      100*n_tie/length(records))
        end
        println(io)

        function emit(io, title, kfn)
            tally = Dict{Any,NTuple{4,Int}}()
            for r in records
                k = kfn(r)
                a, b, c, d = get(tally, k, (0, 0, 0, 0))
                tally[k] = (a+1,
                            b+(r.winner=="per_axis"),
                            c+(r.winner=="global"),
                            d+(r.winner=="tie"))
            end
            println(io, "### $title")
            println(io)
            println(io, "| key | n | per_axis | global | tie | per_axis_share |")
            println(io, "|---|---|---|---|---|---|")
            for k in sort(collect(keys(tally)); by = string)
                n, p, g, t = tally[k]
                share = n > 0 ? p/n : 0.0
                @printf(io, "| %s | %d | %d | %d | %d | %.1f%% |\n",
                        k, n, p, g, t, 100*share)
            end
            println(io)
        end
        emit(io, "By depth",       r -> r.depth == 1 ? "1" : r.depth == 2 ? "2" : "3+")
        emit(io, "By base_degree", r -> r.base_degree)
        emit(io, "By experiment",  r -> r.experiment)
    end

    open(joinpath(output_dir, "summary.json"), "w") do io
        JSON3.pretty(io, (
            generated  = string(Dates.now()),
            experiment = String(config.name),
            entry_name = obj_name,
            budget     = cf_cfg.max_leaves_per_child,
            n_records  = length(records),
            n_per_axis = n_per_axis,
            n_global   = n_global,
            n_tie      = n_tie,
            wall_s     = total_wall,
        ))
    end

    @printf("DONE in %.1f min. per_axis=%d, global=%d, tie=%d\n",
            total_wall/60, n_per_axis, n_global, n_tie)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
