#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════════════
# postprocess_experiment.jl — Standalone post-processing from saved results
#
# Usage:
#   julia --project=. globtim/scripts/postprocess_experiment.jl results_dir/
#   julia --project=. globtim/scripts/postprocess_experiment.jl results_dir/ --refinement
#   julia --project=. globtim/scripts/postprocess_experiment.jl results_dir/ --capture
#   julia --project=. globtim/scripts/postprocess_experiment.jl results_dir/ --all
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
using Dynamic_objectives
using Globtim
using GlobtimPostProcessing

# ── Argument parsing ──────────────────────────────────────────────────────────

function print_usage()
    println("""
    Globtim Experiment Post-Processing
    ═══════════════════════════════════

    Usage:
      julia --project=. globtim/scripts/postprocess_experiment.jl [options] results_dir/

    Options:
      --refinement   Run NelderMead refinement on raw CPs
      --capture      Run Newton CP discovery + capture analysis
      --all          Run all analyses (refinement + capture)
      --help         Show this help message

    If no analysis flags are given, defaults to --all.

    The results directory must contain:
      - results_summary.jld2  (saved by globtim/scripts/run_experiment.jl)
      - experiment_config.toml  (copied by globtim/scripts/run_experiment.jl)

    Examples:
      # Full post-processing on saved results
      julia --project=. globtim/scripts/postprocess_experiment.jl globtim_results/benchmark_3d/levy/

      # Only refinement
      julia --project=. globtim/scripts/postprocess_experiment.jl --refinement globtim_results/benchmark_3d/levy/
    """)
end

function parse_args(args)
    do_refinement = false
    do_capture = false
    results_dir = nothing

    for arg in args
        if arg == "--refinement"
            do_refinement = true
        elseif arg == "--capture"
            do_capture = true
        elseif arg == "--all"
            do_refinement = true
            do_capture = true
        elseif arg == "--help" || arg == "-h"
            print_usage()
            exit(0)
        elseif startswith(arg, "--")
            error("Unknown option: $arg. Run with --help for usage.")
        else
            results_dir !== nothing && error("Only one results directory can be specified.")
            results_dir = String(rstrip(arg, '/'))
        end
    end

    results_dir === nothing && (print_usage(); error("No results directory specified."))
    isdir(results_dir) || error("Results directory not found: $results_dir")

    # Default to --all if no flags given
    if !do_refinement && !do_capture
        do_refinement = true
        do_capture = true
    end

    return (; results_dir, do_refinement, do_capture)
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
            bench = Globtim.get_benchmark_config_by_name(config.analytical_function, config.dimension)
            bounds = config.bounds !== nothing ? config.bounds : bench.bounds
            return bench.objective, bounds, config
        elseif config.catalogue_path !== nothing
            # ODE catalogue model — reconstruct with correct solver settings
            isfile(config.catalogue_path) || error(
                "Catalogue file not found: $(config.catalogue_path)\n" *
                "The catalogue path in the saved TOML config is no longer valid.\n" *
                "Update [model].catalogue_path in $toml_path to point to the catalogue file.")
            entries = load_catalogue(config.catalogue_path; model_name=config.entry_name)
            matching = filter(e -> e.name == config.entry_name, entries)
            isempty(matching) && error("Entry '$(config.entry_name)' not found in catalogue")
            entry = first(matching)

            # Resolve solver settings from config.
            # For postprocessing (Newton refinement, Hessian computation), we need
            # tighter solver tolerances than the experiment used for sampling.
            # The experiment may use 1e-4 for speed, but gradient/Hessian accuracy
            # requires at least 1e-8 to avoid finite-difference noise.
            solver = config.solver_method !== nothing ?
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
                numpoints = config.solver_numpoints !== nothing ? config.solver_numpoints : entry.numpoints
                time_interval = config.time_interval !== nothing ? config.time_interval : entry.time_interval
                uneven_sampling_times = Float64[]
            end

            if abstol < config_abstol || reltol < config_reltol
                println("  Tightened solver tolerances for analysis: abstol=$abstol, reltol=$reltol " *
                        "(experiment used abstol=$config_abstol, reltol=$config_reltol)")
            end

            model, _, _, outputs = entry.model_fn()
            objective = make_error_distance(
                model, outputs, entry.ic, entry.p_true,
                time_interval, numpoints,
                entry.distance_function, entry.aggregate_distances;
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
        "Cannot reconstruct objective automatically.")

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
        isfile(catalogue_path) || error(
            "Catalogue file not found: $catalogue_path\n" *
            "The catalogue path saved in results metadata is no longer valid.")
        entries = load_catalogue(catalogue_path; model_name=entry_name)
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

    error("Cannot reconstruct objective: no analytical_function or catalogue_path in metadata.\n" *
          "Available metadata keys: $(join(keys(meta), ", "))")
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
        ref_config = GlobtimPostProcessing.RefinementConfig(
            bounds = bounds,
        )

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
            newton_tol = 1e-8
            newton_max_iter = 200
            hessian_tol = 1e-6
            dedup_frac = 0.02
            top_k = nothing
            accept_tol = 1e-2  # default from build_known_cps_from_refinement
            f_accept_tol = nothing  # disabled by default; set in TOML [analysis] for ODE objectives
            if config !== nothing
                newton_tol = config.analysis_newton_tol !== nothing ? config.analysis_newton_tol : newton_tol
                newton_max_iter = config.analysis_newton_max_iterations !== nothing ? config.analysis_newton_max_iterations : newton_max_iter
                hessian_tol = config.analysis_hessian_tol !== nothing ? config.analysis_hessian_tol : hessian_tol
                dedup_frac = config.analysis_dedup_fraction !== nothing ? config.analysis_dedup_fraction : dedup_frac
                top_k = config.analysis_top_k
                accept_tol = config.analysis_accept_tol !== nothing ? config.analysis_accept_tol : accept_tol
                f_accept_tol = config.analysis_f_accept_tol
            end

            # Phase header
            println()
            println("══ Newton CP Analysis ══════════════════════════════════════")
            println("  Source: degree $(highest_dr.degree) ($(highest_dr.n_critical_points) raw CPs)")
            top_k_str = top_k === nothing ? "none (refining all)" : string(top_k)
            @printf("  Params: tol=%.0e, accept_tol=%.0e, max_iter=%d, gradient=%s\n",
                newton_tol, accept_tol, newton_max_iter, analysis_grad_method)
            if f_accept_tol !== nothing
                @printf("  f_accept_tol=%.0e (accept CPs with f(x) below this value)\n", f_accept_tol)
            end
            println("  Pre-filter: top_k=$top_k_str, dedup=$(dedup_frac)")
            println()

            discovery_result = GlobtimPostProcessing.build_known_cps_from_refinement(
                objective,
                highest_dr.critical_points,
                bounds;
                gradient_method = analysis_grad_method,
                tol = newton_tol,
                accept_tol = accept_tol,
                f_accept_tol = f_accept_tol,
                max_iterations = newton_max_iter,
                hessian_tol = hessian_tol,
                dedup_fraction = dedup_frac,
                top_k = top_k,
            )

            if discovery_result === nothing
                println("  Consider: larger domain radius, higher polynomial degree, or setting f_accept_tol in [analysis].")
            else
                known_cps = discovery_result.known_cps
                cp_refinement_results = discovery_result.refinement_results

                n_known = length(known_cps.points)
                n_min = count(==(:min), known_cps.types)
                n_max = count(==(:max), known_cps.types)
                n_saddle = count(==(:saddle), known_cps.types)

                print_section("Discovered Critical Points ($n_known total)")
                println("  $n_min minima, $n_max maxima, $n_saddle saddle points")

                for (i, (pt, val, tp)) in enumerate(zip(known_cps.points, known_cps.values, known_cps.types))
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
                    GlobtimPostProcessing.run_valley_analysis(objective, cp_refinement_results)
                end

                # Capture analysis across all degrees
                degree_capture_results = compute_degree_capture_results(degree_results, known_cps)
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
                    @printf("  f(x*) = %.6e  (degree %d, %s)\n", best.value, best.degree, best.source)
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

# ── Main ─────────────────────────────────────────────────────────────────────

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_args(ARGS)
    run_postprocessing(args.results_dir;
        do_refinement = args.do_refinement,
        do_capture = args.do_capture)
end
