#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════════════
# run_experiment.jl — Generic CLI entry point for the experiment pipeline
#
# Usage:
#   julia --project=. globtim/scripts/run_experiment.jl config.toml
#   julia --project=. globtim/scripts/run_experiment.jl config1.toml config2.toml config3.toml
#   julia --project=. globtim/scripts/run_experiment.jl examples/configs/*.toml
#   julia --project=. globtim/scripts/run_experiment.jl --dry-run examples/configs/*.toml
#   julia --project=. globtim/scripts/run_experiment.jl --help
#
# This is the single entry point for the Globtim experiment pipeline.
# Write a TOML config, run this script. Results go to [output].dir.
#
# Bead: gwo
# ═══════════════════════════════════════════════════════════════════════════════

using Printf
using Dynamic_objectives
using Globtim
using GlobtimPostProcessing

# ── Argument parsing ──────────────────────────────────────────────────────────

function print_usage()
    println("""
    Globtim Experiment Pipeline
    ═══════════════════════════

    Usage:
      julia --project=. globtim/scripts/run_experiment.jl [options] config1.toml [config2.toml ...]

    Options:
      --dry-run    Validate configs and print summary without running experiments
      --help       Show this help message

    Examples:
      # Run a single experiment
      julia --project=. globtim/scripts/run_experiment.jl examples/configs/levy_3d.toml

      # Run multiple experiments
      julia --project=. globtim/scripts/run_experiment.jl examples/configs/levy_3d.toml examples/configs/ackley_3d.toml

      # Validate configs without running
      julia --project=. globtim/scripts/run_experiment.jl --dry-run examples/configs/*.toml

    TOML Config Sections:
      [experiment]   name, description
      [model]        analytical_function + dimension  OR  catalogue_path + entry_name
      [domain]       bounds = [[lo,hi], ...]  OR  radius  OR  radii
      [polynomial]   GN, degree_range, basis
      [solver]       method, abstol, reltol, numpoints  (optional, ODE models)
      [refinement]   enabled, method, max_time  (optional)
      [analysis]     enabled, gradient_method, newton_tol  (optional)
      [output]       dir

    See examples/configs/ for reference TOML files.
    """)
end

function parse_args(args)
    dry_run = false
    config_paths = String[]

    for arg in args
        if arg == "--dry-run"
            dry_run = true
        elseif arg == "--help" || arg == "-h"
            print_usage()
            exit(0)
        elseif startswith(arg, "--")
            error("Unknown option: $arg. Run with --help for usage.")
        else
            if !isfile(arg)
                error("Config file not found: $arg")
            end
            push!(config_paths, abspath(arg))
        end
    end

    if isempty(config_paths)
        print_usage()
        error("No config files specified. Pass one or more TOML config paths.")
    end

    return (; dry_run, config_paths)
end

# ── Dry-run: validate and summarize ──────────────────────────────────────────

function dry_run_configs(config_paths::Vector{String})
    println("Dry run: validating $(length(config_paths)) config(s)\n")

    all_valid = true
    for (i, path) in enumerate(config_paths)
        rel = relpath(path)
        print("  [$i/$(length(config_paths))] $rel ... ")
        try
            config = Globtim.load_experiment_config(path)
            mode = config.analytical_function !== nothing ? "analytical" : "catalogue"
            func = config.analytical_function !== nothing ? config.analytical_function : config.entry_name
            dim = config.dimension !== nothing ? "$(config.dimension)D" : "from catalogue"
            degrees = config.degree_range
            gn = config.GN
            output = config.output_dir !== nothing ? config.output_dir : "(temp)"
            println("OK")
            println("         name=$(config.name)  mode=$mode  func=$func  dim=$dim")
            println("         GN=$gn  degrees=$degrees  basis=$(config.basis)  output=$output")
            ref = config.refinement_enabled ? "yes" : "no"
            ana = config.analysis_enabled ? "yes" : "no"
            println("         refinement=$ref  analysis=$ana")
        catch e
            println("FAILED")
            msg = hasproperty(e, :msg) ? e.msg : string(e)
            println("         $msg")
            all_valid = false
        end
        println()
    end

    if all_valid
        println("All $(length(config_paths)) configs are valid.")
    else
        error("Some configs failed validation. Fix errors above and retry.")
    end
end

# ── Run experiments ──────────────────────────────────────────────────────────

function run_experiments(config_paths::Vector{String})
    n = length(config_paths)
    println("Running $n experiment(s)\n")
    println("=" ^ 72)

    # Store results in order (not just by name) so summary table matches input order
    results_ordered = Vector{Dict{Symbol, Any}}()
    timings = Float64[]

    for (i, path) in enumerate(config_paths)
        rel = relpath(path)
        println("\n[$i/$n] $rel")
        println("-" ^ 72)

        t0 = time()
        result = run_experiment_from_config(path)
        elapsed = time() - t0
        push!(timings, elapsed)
        push!(results_ordered, result)

        degree_results = result[:degree_results]
        known_cps = result[:known_cps]

        # Print polynomial summary
        print_poly_summary_table(degree_results)

        # Print CP summary if analysis was run
        if known_cps !== nothing
            n_known = length(known_cps.points)
            n_min = count(==(:min), known_cps.types)
            n_max = count(==(:max), known_cps.types)
            n_saddle = count(==(:saddle), known_cps.types)
            println("  CPs discovered: $n_known ($n_min min, $n_max max, $n_saddle saddle)")
        end

        println("  Output: $(result[:output_dir])")
        @printf("  Total time: %.1fs\n", elapsed)
    end

    # ── Summary table ─────────────────────────────────────────────────────
    if n > 1
        println("\n" * "=" ^ 72)
        println("SUMMARY")
        println("=" ^ 72)
        @printf("  %-20s  %5s  %6s  %8s  %s\n", "Experiment", "#Deg", "Status", "Time", "Output")
        println("  " * "-" ^ 65)

        for (i, result) in enumerate(results_ordered)
            config = result[:config]
            dr = result[:degree_results]
            n_success = count(r -> r.status == "success", dr)
            n_total = length(dr)
            status = n_success == n_total ? "$(n_success)/$(n_total) ok" : "$(n_success)/$(n_total) WARN"

            @printf("  %-20s  %5d  %6s  %7.1fs  %s\n",
                config.name, n_total, status, timings[i], result[:output_dir])
        end
        @printf("\n  Total: %.1fs across %d experiments\n", sum(timings), n)
    end

    println()
    return results_ordered
end

# ── Main ─────────────────────────────────────────────────────────────────────

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_args(ARGS)

    if args.dry_run
        dry_run_configs(args.config_paths)
    else
        run_experiments(args.config_paths)
    end
end
