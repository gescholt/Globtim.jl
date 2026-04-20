#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════════════
# postprocess_experiment.jl — Standalone post-processing from saved results
#
# Usage:
#   julia --project=. globtim/scripts/postprocess_experiment.jl results_dir/ [results_dir2/ ...]
#   julia --project=. globtim/scripts/postprocess_experiment.jl --refinement results_dir/
#   julia --project=. globtim/scripts/postprocess_experiment.jl --hessian-only globtim_results/paper/*/
#   julia --project=. globtim/scripts/postprocess_experiment.jl --all results_dir/
#   julia --project=. globtim/scripts/postprocess_experiment.jl --help
#
# Loads saved experiment results (JLD2) and reconstructs the objective function
# from saved metadata, then runs post-processing analyses without re-running
# the experiment.
#
# Requires that the experiment was run via globtim/scripts/run_experiment.jl (or
# run_experiment_from_config), which saves reconstruction metadata and
# a copy of the TOML config in the output directory.
#
# Bead: gwo
# ═══════════════════════════════════════════════════════════════════════════════

using Printf
using JLD2
using CSV
using DataFrames
using JSON
using Dynamic_objectives
using Globtim
using GlobtimPostProcessing

# ── Argument parsing ──────────────────────────────────────────────────────────

function print_usage()
    println(
        """
Globtim Experiment Post-Processing
═══════════════════════════════════

Usage:
  julia --project=. globtim/scripts/postprocess_experiment.jl [options] results_dir/ [results_dir2/ ...]

Options:
  --refinement   Run NelderMead refinement on raw CPs
  --capture      Run Newton CP discovery + capture analysis
  --hessian-only Add Hessian classification to existing refined CSVs (no re-refinement)
  --all          Run all analyses (refinement + capture)
  --help         Show this help message

If no analysis flags are given, defaults to --all.
Multiple results directories can be specified for batch processing.

The results directory must contain:
  - results_summary.jld2  (saved by globtim/scripts/run_experiment.jl)
  - experiment_config.toml  (copied by globtim/scripts/run_experiment.jl)

Examples:
  # Full post-processing on saved results
  julia --project=. globtim/scripts/postprocess_experiment.jl globtim_results/paper/levy_3d/

  # Add Hessian classification to all paper experiments (no re-refinement)
  julia --project=. globtim/scripts/postprocess_experiment.jl --hessian-only globtim_results/paper/*/

  # Only refinement on multiple experiments
  julia --project=. globtim/scripts/postprocess_experiment.jl --refinement globtim_results/paper/lv2d/ globtim_results/paper/fhn3d/
""",
    )
end

function parse_args(args)
    do_refinement = false
    do_capture = false
    do_hessian_only = false
    results_dirs = String[]

    for arg in args
        if arg == "--refinement"
            do_refinement = true
        elseif arg == "--capture"
            do_capture = true
        elseif arg == "--hessian-only"
            do_hessian_only = true
        elseif arg == "--all"
            do_refinement = true
            do_capture = true
        elseif arg == "--help" || arg == "-h"
            print_usage()
            exit(0)
        elseif startswith(arg, "--")
            error("Unknown option: $arg. Run with --help for usage.")
        else
            push!(results_dirs, String(rstrip(arg, '/')))
        end
    end

    isempty(results_dirs) && (print_usage(); error("No results directory specified."))
    for d in results_dirs
        isdir(d) || error("Results directory not found: $d")
    end

    # Validate flag combinations
    if do_hessian_only && (do_refinement || do_capture)
        error("--hessian-only cannot be combined with --refinement or --capture")
    end

    # Default to --all if no flags given
    if !do_refinement && !do_capture && !do_hessian_only
        do_refinement = true
        do_capture = true
    end

    return (; results_dirs, do_refinement, do_capture, do_hessian_only)
end

# ── Cluster path remapping ────────────────────────────────────────────────────

const REPO_ROOT = dirname(dirname(dirname(@__DIR__)))
const CLUSTER_MARKERS = ["globopt_merged/", "globopt/globopt_merged/"]

"""
    _remap_cluster_path(path) -> Union{String, Nothing}

Remap a catalogue path to the local repo root. Handles:
1. Absolute cluster paths (`/mnt/beegfs/.../globopt_merged/globtim_results/foo.jsonl`)
2. Mis-resolved relative paths (`/repo/globtim_results/paper/exp/../../Dynamic_objectives/...`)
   where the config loader resolved `../../` against the wrong base directory.

Strategy: extract a recognizable tail (after `globopt_merged/` or known package dirs)
and re-resolve it against the local repo root, trying `pkg/` prefix if needed.
"""
function _remap_cluster_path(path::String)
    # Strategy 1: Find globopt_merged/ marker and extract relative tail
    for marker in CLUSTER_MARKERS
        idx = findlast(marker, path)
        idx === nothing && continue
        relative = path[(last(idx)+1):end]
        # Try direct resolution
        candidate = joinpath(REPO_ROOT, relative)
        isfile(candidate) && return candidate
        # Try under pkg/ (e.g., Dynamic_objectives/ → pkg/Dynamic_objectives/)
        candidate = joinpath(REPO_ROOT, "pkg", relative)
        isfile(candidate) && return candidate
    end

    # Strategy 2: Look for known package directory names in the path
    # Handles mis-resolved paths like .../globtim_results/paper/exp/../../Dynamic_objectives/paper/catalogue/foo.jsonl
    for pkg_dir in ["Dynamic_objectives/", "globtim/", "globtimpostprocessing/"]
        idx = findlast(pkg_dir, path)
        idx === nothing && continue
        # Extract from the package dir onward
        relative = path[first(idx):end]
        for prefix in ["pkg/", ""]
            candidate = joinpath(REPO_ROOT, prefix, relative)
            isfile(candidate) && return candidate
        end
    end

    # Strategy 3: basename fallback — search known catalogue locations
    fname = basename(path)
    for dir in ["globtim_results", "pkg/Dynamic_objectives/paper/catalogue"]
        candidate = joinpath(REPO_ROOT, dir, fname)
        isfile(candidate) && return candidate
    end

    return nothing
end

# ── Objective reconstruction ──────────────────────────────────────────────────

"""
    reconstruct_objective(results_dir) -> (objective, bounds, config)

Reconstruct the objective function from saved experiment metadata.

Tries two approaches in order:
1. Load experiment_config.toml from the results directory (preferred — self-contained)
2. Load results_summary.jld2 user_metadata and use reconstruction fields

For ODE/catalogue models, uses the config's solver settings (method, tolerances)
to reconstruct the objective with the same solver used during the experiment.
"""
function reconstruct_objective(results_dir::String)
    # Approach 1: Load the TOML config copy from the output directory
    toml_path = joinpath(results_dir, "experiment_config.toml")
    if isfile(toml_path)
        config = Globtim.load_experiment_config(toml_path)

        if config.analytical_function !== nothing
            # Analytical benchmark function
            bench = Globtim.get_benchmark_config_by_name(
                config.analytical_function,
                config.dimension,
            )
            bounds = config.bounds !== nothing ? config.bounds : bench.bounds
            return bench.objective, bounds, config
        elseif config.catalogue_path !== nothing
            # ODE catalogue model — reconstruct with correct solver settings
            cat_path = config.catalogue_path
            if !isfile(cat_path)
                local_path = _remap_cluster_path(cat_path)
                if local_path !== nothing && isfile(local_path)
                    @info "Remapped cluster catalogue path" cluster=cat_path local_path=local_path
                    cat_path = local_path
                else
                    error(
                        "Catalogue file not found: $cat_path\n" *
                        "The catalogue path in the saved TOML config is no longer valid.\n" *
                        "Tried local remap: $(something(local_path, "no match"))\n" *
                        "Update [model].catalogue_path in $toml_path to point to the catalogue file.",
                    )
                end
            end
            entries = load_catalogue(cat_path; model_name = config.entry_name)
            matching = filter(e -> e.name == config.entry_name, entries)
            isempty(matching) &&
                error("Entry '$(config.entry_name)' not found in catalogue")
            entry = first(matching)

            # Resolve solver settings from config.
            # For postprocessing (Newton refinement, Hessian computation), we need
            # tighter solver tolerances than the experiment used for sampling.
            # The experiment may use 1e-4 for speed, but gradient/Hessian accuracy
            # requires at least 1e-8 to avoid finite-difference noise.
            solver =
                config.solver_method !== nothing ?
                Dynamic_objectives._resolve_solver(config.solver_method) : Vern9()
            config_abstol = config.solver_abstol !== nothing ? config.solver_abstol : 1e-10
            config_reltol = config.solver_reltol !== nothing ? config.solver_reltol : 1e-10
            abstol = min(config_abstol, 1e-8)
            reltol = min(config_reltol, 1e-8)
            # sample_times overrides both time_interval and numpoints
            if config.sample_times !== nothing
                time_interval = [config.sample_times[1], config.sample_times[end]]
                numpoints = length(config.sample_times)
                uneven_sampling_times = config.sample_times
            else
                numpoints =
                    config.solver_numpoints !== nothing ? config.solver_numpoints :
                    entry.numpoints
                time_interval =
                    config.time_interval !== nothing ? config.time_interval :
                    entry.time_interval
                uneven_sampling_times = Float64[]
            end

            if abstol < config_abstol || reltol < config_reltol
                println(
                    "  Tightened solver tolerances for analysis: abstol=$abstol, reltol=$reltol " *
                    "(experiment used abstol=$config_abstol, reltol=$config_reltol)",
                )
            end

            model, _, _, outputs = entry.model_fn()
            objective = make_error_distance(
                model,
                outputs,
                entry.ic,
                entry.p_true,
                time_interval,
                numpoints,
                entry.distance_function,
                entry.aggregate_distances;
                return_inf_on_error = true,
                eval_timeout = entry.eval_timeout,
                solver = solver,
                abstol = abstol,
                reltol = reltol,
                uneven_sampling_times = uneven_sampling_times,
            )

            if config.bounds !== nothing
                bounds = config.bounds
            elseif config.radius !== nothing
                bounds = Dynamic_objectives.build_bounds(entry.p_true, config.radius)
            elseif config.radii !== nothing
                bounds = Dynamic_objectives.build_bounds(entry.p_true, config.radii)
            else
                bounds = entry.bounds
            end
            return objective, bounds, config
        end
    end

    # Approach 2: Load from JLD2 user_metadata
    jld2_path = joinpath(results_dir, "results_summary.jld2")
    isfile(jld2_path) || error("No results_summary.jld2 found in $results_dir")

    data = JLD2.load(jld2_path)
    meta = get(data, "user_metadata", nothing)
    meta === nothing && error(
        "No user_metadata in results_summary.jld2.\n" *
        "This experiment was not run via the TOML pipeline (globtim/scripts/run_experiment.jl).\n" *
        "Cannot reconstruct objective automatically.",
    )

    analytical_fn = get(meta, "analytical_function", nothing)
    dimension = get(meta, "dimension", nothing)

    if analytical_fn !== nothing && dimension !== nothing
        bench = Globtim.get_benchmark_config_by_name(analytical_fn, dimension)
        # Get bounds from experiment_definition
        exp_def = get(data, "experiment_definition", Dict())
        saved_bounds = get(exp_def, "bounds", nothing)
        bounds = if saved_bounds !== nothing
            [Tuple{Float64,Float64}((b[1], b[2])) for b in saved_bounds]
        else
            bench.bounds
        end
        return bench.objective, bounds, nothing
    end

    catalogue_path = get(meta, "catalogue_path", nothing)
    entry_name = get(meta, "entry_name", nothing)

    if catalogue_path !== nothing && entry_name !== nothing
        if !isfile(catalogue_path)
            # Try to resolve cluster paths to local repo paths
            # Cluster saves absolute paths like /mnt/beegfs/.../globopt_merged/globtim_results/foo.jsonl
            # Locally, the same file is at <repo_root>/globtim_results/foo.jsonl
            local_path = _remap_cluster_path(catalogue_path)
            if local_path !== nothing && isfile(local_path)
                @info "Remapped cluster catalogue path" cluster=catalogue_path local_path=local_path
                catalogue_path = local_path
            else
                error(
                    "Catalogue file not found: $catalogue_path\n" *
                    "The catalogue path saved in results metadata is no longer valid.\n" *
                    "Tried local remap: $(something(local_path, "no match"))",
                )
            end
        end
        entries = load_catalogue(catalogue_path; model_name = entry_name)
        matching = filter(e -> e.name == entry_name, entries)
        isempty(matching) && error("Entry '$entry_name' not found in catalogue")
        entry = first(matching)
        objective = create_objective(entry)

        exp_def = get(data, "experiment_definition", Dict())
        saved_bounds = get(exp_def, "bounds", nothing)
        bounds = if saved_bounds !== nothing
            [Tuple{Float64,Float64}((b[1], b[2])) for b in saved_bounds]
        else
            entry.bounds
        end
        return objective, bounds, nothing
    end

    error(
        "Cannot reconstruct objective: no analytical_function or catalogue_path in metadata.\n" *
        "Available metadata keys: $(join(keys(meta), ", "))",
    )
end

# ── Load degree results from JLD2 ────────────────────────────────────────────

function load_degree_results(results_dir::String)
    jld2_path = joinpath(results_dir, "results_summary.jld2")
    isfile(jld2_path) || error("No results_summary.jld2 found in $results_dir")

    data = JLD2.load(jld2_path)
    degree_results = get(data, "degree_results", nothing)
    degree_results === nothing && error("No degree_results in $jld2_path")
    return degree_results
end

# ── Gradient method resolution ────────────────────────────────────────────────

"""
    _resolve_gradient_method(config, section::Symbol) -> Symbol

Resolve gradient method from saved config. For catalogue/ODE models, defaults
to :finitediff (ForwardDiff cannot propagate Dual types through ODE solvers).
For analytical functions, defaults to :forwarddiff.
"""
function _resolve_gradient_method(config, section::Symbol)
    if config === nothing
        return :finitediff  # Safe default when no config available
    end

    # Read from the appropriate config section
    method_str = if section == :refinement
        config.refinement_gradient_method
    elseif section == :analysis
        config.analysis_gradient_method
    else
        nothing
    end

    # If explicitly set in config, use it
    if method_str !== nothing
        return Symbol(method_str)
    end

    # Default: finitediff for ODE/catalogue models, forwarddiff for analytical
    if config.catalogue_path !== nothing
        return :finitediff
    else
        return :forwarddiff
    end
end

# ── Post-processing pipeline ─────────────────────────────────────────────────

function run_postprocessing(results_dir::String; do_refinement::Bool, do_capture::Bool)
    println("Post-processing: $results_dir")
    println("=" ^ 72)

    # 1. Load saved results
    println("\nLoading saved results...")
    degree_results = load_degree_results(results_dir)
    n_success = count(r -> r.status == "success", degree_results)
    println("  $(length(degree_results)) degrees loaded ($n_success successful)")

    # 2. Reconstruct objective
    println("\nReconstructing objective function...")
    objective, bounds, config = reconstruct_objective(results_dir)
    println("  Objective reconstructed successfully")
    println("  Bounds: $(join(["[$(lb), $(ub)]" for (lb, ub) in bounds], " × "))")

    # Print polynomial summary
    print_poly_summary_table(degree_results)

    # 3. Refinement
    refinement_results = nothing
    if do_refinement
        ref_grad_method = _resolve_gradient_method(config, :refinement)
        println("\nRunning NelderMead refinement (gradient: $ref_grad_method)...")
        ref_config = GlobtimPostProcessing.RefinementConfig(bounds = bounds)

        refinement_results = GlobtimPostProcessing.run_degree_analyses(
            degree_results,
            objective,
            results_dir,
            ref_config;
            gradient_method = ref_grad_method,
        )
        println("  Refinement complete: $(length(refinement_results)) degrees refined")
    end

    # 4. Newton CP discovery + capture analysis
    known_cps = nothing
    if do_capture
        # Find highest successful degree
        highest_dr = nothing
        for dr in reverse(degree_results)
            if dr.status == "success" && dr.n_critical_points > 0
                highest_dr = dr
                break
            end
        end

        if highest_dr === nothing
            println("  WARNING: No successful degrees with CPs — skipping capture analysis")
        else
            analysis_grad_method = _resolve_gradient_method(config, :analysis)

            # Read analysis parameters from config if available, else use defaults
            refinement_goal = :minimum
            newton_tol = 1e-8
            newton_max_iter = 200
            max_time_pt = 60.0
            hessian_tol = 1e-6
            dedup_frac = 0.02
            top_k = nothing
            accept_tol = 1e-2  # default from build_known_cps_from_refinement
            f_accept_tol = nothing  # disabled by default; set in TOML [analysis] for ODE objectives
            if config !== nothing
                refinement_goal =
                    config.analysis_refinement_goal !== nothing ?
                    Symbol(config.analysis_refinement_goal) : refinement_goal
                newton_tol =
                    config.analysis_newton_tol !== nothing ? config.analysis_newton_tol :
                    newton_tol
                newton_max_iter =
                    config.analysis_newton_max_iterations !== nothing ?
                    config.analysis_newton_max_iterations : newton_max_iter
                max_time_pt =
                    config.analysis_max_time_per_point !== nothing ?
                    config.analysis_max_time_per_point : max_time_pt
                hessian_tol =
                    config.analysis_hessian_tol !== nothing ? config.analysis_hessian_tol :
                    hessian_tol
                dedup_frac =
                    config.analysis_dedup_fraction !== nothing ?
                    config.analysis_dedup_fraction : dedup_frac
                top_k = config.analysis_top_k
                accept_tol =
                    config.analysis_accept_tol !== nothing ? config.analysis_accept_tol :
                    accept_tol
                f_accept_tol = config.analysis_f_accept_tol
            end

            # Phase header
            goal_label =
                refinement_goal == :minimum ? "NelderMead (f-minimization)" :
                "Newton (∇f = 0)"
            println()
            println("══ CP Refinement: $goal_label ══════════════════════════════════════")
            println(
                "  Source: degree $(highest_dr.degree) ($(highest_dr.n_critical_points) raw CPs)",
            )
            top_k_str = top_k === nothing ? "none (refining all)" : string(top_k)
            @printf(
                "  Params: goal=%s, tol=%.0e, accept_tol=%.0e, max_iter=%d, gradient=%s\n",
                refinement_goal,
                newton_tol,
                accept_tol,
                newton_max_iter,
                analysis_grad_method
            )
            if f_accept_tol !== nothing
                @printf(
                    "  f_accept_tol=%.0e (accept CPs with f(x) below this value)\n",
                    f_accept_tol
                )
            end
            println("  Pre-filter: top_k=$top_k_str, dedup=$(dedup_frac)")
            println()

            refine_method = if refinement_goal == :minimum
                GlobtimPostProcessing.OptimNelderMead(;
                    gradient_method = analysis_grad_method,
                    hessian_tol,
                    max_iterations = newton_max_iter,
                    max_time = max_time_pt,
                )
            else
                GlobtimPostProcessing.NewtonCP(;
                    gradient_method = analysis_grad_method,
                    tol = newton_tol,
                    accept_tol,
                    f_accept_tol,
                    max_iterations = newton_max_iter,
                    hessian_tol,
                )
            end
            discovery_result = GlobtimPostProcessing.build_known_cps_from_refinement(
                objective,
                highest_dr.critical_points,
                bounds;
                method = refine_method,
                dedup_fraction = dedup_frac,
                top_k = top_k,
            )

            if discovery_result === nothing
                println(
                    "  Consider: larger domain radius, higher polynomial degree, or setting f_accept_tol in [analysis].",
                )
            else
                known_cps = discovery_result.known_cps
                cp_refinement_results = discovery_result.refinement_results

                n_known = length(known_cps.points)
                n_min = count(==(:min), known_cps.types)
                n_max = count(==(:max), known_cps.types)
                n_saddle = count(==(:saddle), known_cps.types)

                print_section("Discovered Critical Points ($n_known total)")
                println("  $n_min minima, $n_max maxima, $n_saddle saddle points")

                for (i, (pt, val, tp)) in
                    enumerate(zip(known_cps.points, known_cps.values, known_cps.types))
                    pt_str = join([@sprintf("%+.4f", x) for x in pt], ", ")
                    @printf("    %2d. [%s]  f = %+.6e  (%s)\n", i, pt_str, val, tp)
                    if i >= 30
                        println("    ... ($(n_known - 30) more)")
                        break
                    end
                end

                # Valley walking analysis (opt-in via TOML [analysis] valley_walking = true)
                valley_walking_enabled = false
                if config !== nothing
                    valley_walking_enabled = config.analysis_valley_walking
                end
                if valley_walking_enabled
                    GlobtimPostProcessing.run_valley_analysis(
                        objective,
                        cp_refinement_results,
                    )
                end

                # Capture analysis across all degrees
                degree_capture_results =
                    compute_degree_capture_results(degree_results, known_cps)
                if !isempty(degree_capture_results)
                    print_section("Capture Analysis")
                    print_degree_capture_convergence(degree_capture_results)
                    verdict = compute_capture_verdict(degree_capture_results)
                    print_capture_verdict(verdict)
                end
            end

            if refinement_results !== nothing
                best = find_best_estimate(degree_results, refinement_results)
                if best !== nothing
                    print_section("Best Minimum Found")
                    @printf(
                        "  f(x*) = %.6e  (degree %d, %s)\n",
                        best.value,
                        best.degree,
                        best.source
                    )
                    pt_str = join([@sprintf("%.4f", x) for x in best.point], ", ")
                    println("  x* = [$pt_str]")
                end
            end
        end
    end

    println("\n" * "=" ^ 72)
    println("Post-processing complete for: $results_dir")
    println()
end

# ── Hessian-only mode ──────────────────────────────────────────────────────

"""
    run_hessian_only(results_dir::String)

Add Hessian eigenvalue classification to existing refined CSVs without re-running
refinement. Reads refined points from `critical_points_refined_deg_*.csv`, computes
Hessian matrices (ForwardDiff for analytical, FiniteDiff for ODE objectives), classifies
each point as minimum/saddle/maximum/degenerate, and updates both the CSV and JSON.

This is much faster than full re-refinement since it only requires n_points × O(d²)
function evaluations for the Hessian, vs n_points × O(iterations) for NelderMead.
"""
function run_hessian_only(results_dir::String)
    println("Hessian-only classification: $results_dir")
    println("=" ^ 72)

    # 1. Reconstruct objective
    println("\nReconstructing objective function...")
    objective, _, config = reconstruct_objective(results_dir)
    println("  Objective reconstructed successfully")

    # 2. Determine gradient method (finitediff for ODE, forwarddiff for analytical)
    gradient_method = _resolve_gradient_method(config, :refinement)
    println("  Hessian method: $gradient_method")

    # 3. Find all refined CSVs
    refined_csvs = sort(
        filter(
            f ->
                startswith(basename(f), "critical_points_refined_deg_") &&
                endswith(f, ".csv"),
            readdir(results_dir, join = true),
        ),
    )

    if isempty(refined_csvs)
        println("  No refined CSVs found — run --refinement first.")
        return
    end
    println("  Found $(length(refined_csvs)) refined CSV(s)")

    n_updated = 0
    for csv_path in refined_csvs
        # Extract degree from filename
        m = match(r"critical_points_refined_deg_(\d+)\.csv", basename(csv_path))
        m === nothing && continue
        degree = parse(Int, m[1])

        # Load refined points
        df = CSV.read(csv_path, DataFrame)
        nrow(df) == 0 && (println("  Degree $degree: 0 points, skipping"); continue)

        # Extract point coordinates (dim1, dim2, ...)
        dim_cols = filter(n -> startswith(String(n), "dim"), names(df))
        points = [Vector{Float64}([row[c] for c in dim_cols]) for row in eachrow(df)]

        # Classify via Hessian
        println("  Degree $degree: classifying $(length(points)) points...")
        classifications = GlobtimPostProcessing.classify_refined_points(
            GlobtimPostProcessing._as_function(objective),
            points;
            gradient_method = gradient_method,
        )

        if isempty(classifications)
            println(
                "    WARNING: classify_refined_points returned empty — GlobtimExt may not be loaded",
            )
            continue
        end

        # Update CSV
        df[!, :critical_point_type] = String.(classifications)
        CSV.write(csv_path, df)

        # Count classification results
        n_min = count(==(Symbol("minimum")), classifications)
        n_saddle = count(==(Symbol("saddle")), classifications)
        n_max = count(==(Symbol("maximum")), classifications)
        n_degen = count(==(Symbol("degenerate")), classifications)
        n_err = count(==(Symbol("error")), classifications)
        println(
            "    → $n_min min, $n_saddle saddle, $n_max max, $n_degen degenerate, $n_err error",
        )

        # Update refinement summary JSON
        summary_path = joinpath(results_dir, "refinement_summary_deg_$degree.json")
        if isfile(summary_path)
            summary = JSON.parsefile(summary_path)
            summary["hessian_classification"] = Dict(
                "n_minimum" => n_min,
                "n_saddle" => n_saddle,
                "n_maximum" => n_max,
                "n_degenerate" => n_degen,
                "n_error" => n_err,
            )
            open(summary_path, "w") do io
                JSON.print(io, summary, 2)
            end
        end

        # Also update comparison CSV if it exists
        comparison_path = joinpath(results_dir, "refinement_comparison_deg_$degree.csv")
        if isfile(comparison_path)
            comp_df = CSV.read(comparison_path, DataFrame)
            # Expand classifications to n_raw (only converged rows get a value)
            if "converged" in names(comp_df)
                cp_type_col = fill("", nrow(comp_df))
                cls_idx = 0
                for (j, conv) in enumerate(comp_df.converged)
                    if conv
                        cls_idx += 1
                        if cls_idx <= length(classifications)
                            cp_type_col[j] = String(classifications[cls_idx])
                        end
                    end
                end
                comp_df[!, :critical_point_type] = cp_type_col
                CSV.write(comparison_path, comp_df)
            end
        end

        n_updated += 1
    end

    println("\n  Updated $n_updated degree(s) with Hessian classification")
    println("=" ^ 72)
end

# ── Main ─────────────────────────────────────────────────────────────────────

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_args(ARGS)

    n_dirs = length(args.results_dirs)
    for (i, results_dir) in enumerate(args.results_dirs)
        if n_dirs > 1
            println("\n[$i/$n_dirs] $(basename(results_dir))")
            println("─" ^ 72)
        end

        if args.do_hessian_only
            run_hessian_only(results_dir)
        else
            run_postprocessing(
                results_dir;
                do_refinement = args.do_refinement,
                do_capture = args.do_capture,
            )
        end
    end

    if n_dirs > 1
        println("\n" * "=" ^ 72)
        println("Batch complete: $n_dirs experiment(s) processed")
        println("=" ^ 72)
    end
end
