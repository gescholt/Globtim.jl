#!/usr/bin/env julia
"""
Check Batch Status - CLI tool for batch experiment status checking

Loads a batch manifest and validates experiment completeness, displays status summary,
and identifies any errors or missing experiments.

Usage:
    julia tools/check_batch_status.jl --batch-dir experiments/lotka_volterra_4d_study/configs_20251009_153009
    julia tools/check_batch_status.jl --batch-dir configs_20251009_153009 --results-dir ../../../hpc_results
    julia tools/check_batch_status.jl -b configs_20251009_153009 -r ../../hpc_results --verbose
"""

# Activate project environment
using Pkg
const SCRIPT_DIR = @__DIR__
const PROJECT_ROOT = dirname(SCRIPT_DIR)
Pkg.activate(PROJECT_ROOT)

using Dates

# Load BatchManifest module
const BATCH_MANIFEST_PATH = joinpath(PROJECT_ROOT, "src", "BatchManifest.jl")
include(BATCH_MANIFEST_PATH)
using .BatchManifest

# ============================================================================
# CLI Argument Parsing (simple version without ArgParse)
# ============================================================================

function parse_commandline(args=ARGS)
    parsed = Dict{String, Any}(
        "batch-dir" => nothing,
        "results-dir" => nothing,
        "verbose" => false,
        "show-errors" => false
    )

    i = 1
    while i <= length(args)
        arg = args[i]
        if arg in ["--batch-dir", "-b"]
            i += 1
            parsed["batch-dir"] = args[i]
        elseif arg in ["--results-dir", "-r"]
            i += 1
            parsed["results-dir"] = args[i]
        elseif arg in ["--verbose", "-v"]
            parsed["verbose"] = true
        elseif arg == "--show-errors"
            parsed["show-errors"] = true
        elseif arg in ["--help", "-h"]
            println("""
            Usage: julia check_batch_status.jl [OPTIONS]

            Options:
              -b, --batch-dir DIR      Path to batch directory containing batch_manifest.json (required)
              -r, --results-dir DIR    Path to results directory (default: auto-detect)
              -v, --verbose            Show detailed experiment status
              --show-errors            Show detailed error information
              -h, --help               Show this help message
            """)
            exit(0)
        end
        i += 1
    end

    if isnothing(parsed["batch-dir"])
        println("Error: --batch-dir is required")
        println("Use --help for usage information")
        exit(1)
    end

    return parsed
end

# ============================================================================
# Result Directory Discovery
# ============================================================================

"""
    discover_results_directory(batch_dir::String) -> String

Attempt to discover the results directory based on project structure.

Searches in order:
1. batch_dir/hpc_results
2. batch_dir/../hpc_results
3. PROJECT_ROOT/globtimcore/hpc_results
4. PROJECT_ROOT/hpc_results
"""
function discover_results_directory(batch_dir::String)
    candidates = [
        joinpath(batch_dir, "hpc_results"),
        joinpath(batch_dir, "..", "hpc_results"),
        joinpath(dirname(dirname(SCRIPT_DIR)), "hpc_results"),
        joinpath(dirname(dirname(dirname(SCRIPT_DIR))), "hpc_results"),
    ]

    for candidate in candidates
        if isdir(candidate)
            return abspath(candidate)
        end
    end

    # Default to globtimcore/hpc_results
    return abspath(joinpath(dirname(dirname(SCRIPT_DIR)), "hpc_results"))
end

# ============================================================================
# Status Display Functions
# ============================================================================

"""
    display_batch_summary(manifest::BatchManifest.Manifest)

Display high-level batch summary with status counts.
"""
function display_batch_summary(manifest::BatchManifest.Manifest)
    summary = get_batch_summary(manifest)

    println("="^80)
    println("BATCH STATUS SUMMARY")
    println("="^80)
    println("Batch ID: $(summary["batch_id"])")
    println("Batch Status: $(uppercase(summary["status"]))")
    println("Created: $(manifest.created_at)")
    println()
    println("Experiments: $(summary["total_experiments"])")
    println("  ✓ Completed: $(summary["completed"])")
    println("  ⏳ Running: $(summary["running"])")
    println("  ⏸  Pending: $(summary["pending"])")
    println("  ✗ Failed: $(summary["failed"])")
    println("="^80)
end

"""
    display_experiment_details(manifest::BatchManifest.Manifest)

Display detailed status for each experiment.
"""
function display_experiment_details(manifest::BatchManifest.Manifest)
    println("\nEXPERIMENT DETAILS:")
    println("-"^80)

    for exp in manifest.experiments
        status_symbol = if exp.status == "completed"
            "✓"
        elseif exp.status == "running"
            "⏳"
        elseif exp.status == "failed"
            "✗"
        else
            "⏸"
        end

        println("$status_symbol $(exp.experiment_id) [$(uppercase(exp.status))]")
        println("  Script: $(exp.script_path)")
        println("  Config: $(exp.config_path)")

        if !isnothing(exp.start_time)
            println("  Started: $(exp.start_time)")
        end

        if !isnothing(exp.end_time)
            duration = exp.end_time - exp.start_time
            println("  Ended: $(exp.end_time)")
            println("  Duration: $(duration)")
        elseif !isnothing(exp.start_time)
            elapsed = now() - exp.start_time
            println("  Elapsed: $(elapsed)")
        end

        if !isnothing(exp.error)
            println("  Error: $(exp.error)")
        end

        println()
    end
end

"""
    display_validation_results(validation::BatchManifest.BatchValidation)

Display batch completeness validation results.
"""
function display_validation_results(validation::BatchManifest.BatchValidation)
    println("\nVALIDATION RESULTS:")
    println("-"^80)
    println("Total Experiments: $(validation.total_experiments)")
    println("Complete Experiments: $(validation.complete_experiments)")
    println("Batch Complete: $(validation.is_complete ? "YES ✓" : "NO ✗")")

    if !isempty(validation.missing_experiments)
        println("\nMissing/Incomplete Experiments:")
        for exp_id in validation.missing_experiments
            println("  - $exp_id")
        end
    end
    println("-"^80)
end

"""
    display_error_report(errors::Vector{BatchManifest.ErrorReport})

Display detailed error information for failed experiments.
"""
function display_error_report(errors::Vector{BatchManifest.ErrorReport})
    if isempty(errors)
        println("\n✓ No errors detected")
        return
    end

    println("\nERROR REPORT:")
    println("-"^80)
    println("Found $(length(errors)) error(s):\n")

    for err in errors
        println("✗ $(err.experiment_id)")
        println("  Type: $(err.error_type)")
        println("  Message: $(err.error_message)")
        println("  Detected: $(err.failed_at)")

        if !isnothing(err.degree_at_failure)
            println("  Degree at failure: $(err.degree_at_failure)")
        end

        if !isnothing(err.stack_trace)
            println("  Stack trace:")
            println("    $(err.stack_trace)")
        end

        println()
    end
    println("-"^80)
end

# ============================================================================
# Main Entry Point
# ============================================================================

function main()
    args = parse_commandline()

    batch_dir = abspath(args["batch-dir"])
    verbose = args["verbose"]
    show_errors = args["show-errors"]

    # Validate batch directory
    if !isdir(batch_dir)
        @error "Batch directory not found: $batch_dir"
        exit(1)
    end

    manifest_path = joinpath(batch_dir, "batch_manifest.json")
    if !isfile(manifest_path)
        @error "Batch manifest not found: $manifest_path"
        println("\nMake sure the directory contains a batch_manifest.json file.")
        exit(1)
    end

    # Load manifest
    println("Loading batch manifest from: $batch_dir")
    manifest = load_batch_manifest(batch_dir)

    # Determine results directory
    results_dir = if !isnothing(args["results-dir"])
        abspath(args["results-dir"])
    else
        discovered = discover_results_directory(batch_dir)
        println("Auto-detected results directory: $discovered")
        discovered
    end

    if !isdir(results_dir)
        @warn "Results directory not found: $results_dir"
        @warn "Validation will not be performed."
        display_batch_summary(manifest)
        if verbose
            display_experiment_details(manifest)
        end
        exit(0)
    end

    # Display batch summary
    display_batch_summary(manifest)

    # Show detailed experiment status if verbose
    if verbose
        display_experiment_details(manifest)
    end

    # Validate batch completeness
    println("\nValidating batch completeness against: $results_dir")
    validation = validate_batch_completeness(manifest, results_dir)
    display_validation_results(validation)

    # Detect and report errors if requested
    if show_errors || !validation.is_complete
        errors = identify_batch_errors(manifest, results_dir)
        display_error_report(errors)
    end

    # Exit with appropriate code
    if validation.is_complete
        println("\n✅ Batch $(manifest.batch_id) is COMPLETE")
        exit(0)
    else
        println("\n⚠️  Batch $(manifest.batch_id) is INCOMPLETE")
        exit(1)
    end
end

# Run main if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
