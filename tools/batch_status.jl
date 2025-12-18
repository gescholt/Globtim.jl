#!/usr/bin/env julia

"""
Batch Status CLI Tool

Display status information for batch experiments tracked with BatchManifest.

Usage:
    julia tools/batch_status.jl <batch_dir>
    julia tools/batch_status.jl <batch_dir> --detailed
    julia tools/batch_status.jl <batch_dir> --json
"""

using ArgParse
using Dates
using Printf
using JSON3

# Load BatchManifest module
const SCRIPT_DIR = @__DIR__
const BATCH_MANIFEST_PATH = joinpath(dirname(SCRIPT_DIR), "src", "BatchManifest.jl")
include(BATCH_MANIFEST_PATH)
using .BatchManifest
using .BatchManifest: ExperimentEntry, Manifest

# ============================================================================
# Status Summary Functions
# ============================================================================

"""
    get_batch_status_summary(batch_dir::String) -> Dict

Get summary statistics for a batch.

Returns dictionary with:
- batch_id
- total, completed, running, pending, failed counts
- status (overall batch status)
- created_at
"""
function get_batch_status_summary(batch_dir::String)
    manifest = BatchManifest.load_batch_manifest(batch_dir)
    summary = BatchManifest.get_batch_summary(manifest)

    # Add created_at to summary
    summary["created_at"] = manifest.created_at
    summary["batch_type"] = manifest.batch_type

    return summary
end

"""
    get_experiment_details(batch_dir::String) -> Vector{Dict}

Get detailed information for each experiment in the batch.
"""
function get_experiment_details(batch_dir::String)
    manifest = BatchManifest.load_batch_manifest(batch_dir)

    details = []
    for exp in manifest.experiments
        detail = Dict(
            "experiment_id" => exp.experiment_id,
            "script_path" => exp.script_path,
            "config_path" => exp.config_path,
            "output_dir" => exp.output_dir,
            "status" => exp.status,
            "start_time" => exp.start_time,
            "end_time" => exp.end_time,
            "error" => exp.error
        )
        push!(details, detail)
    end

    return details
end

"""
    get_status_json(batch_dir::String) -> Dict

Get complete status information in JSON-serializable format.
"""
function get_status_json(batch_dir::String)
    manifest = BatchManifest.load_batch_manifest(batch_dir)

    return Dict(
        "batch_id" => manifest.batch_id,
        "batch_type" => manifest.batch_type,
        "created_at" => string(manifest.created_at),
        "status" => manifest.status,
        "total_experiments" => manifest.total_experiments,
        "experiments" => [
            Dict(
                "experiment_id" => exp.experiment_id,
                "script_path" => exp.script_path,
                "status" => exp.status,
                "start_time" => isnothing(exp.start_time) ? nothing : string(exp.start_time),
                "end_time" => isnothing(exp.end_time) ? nothing : string(exp.end_time),
                "error" => exp.error
            )
            for exp in manifest.experiments
        ]
    )
end

# ============================================================================
# Display Formatting
# ============================================================================

"""
    calculate_progress(completed::Int, running::Int, total::Int) -> Float64

Calculate progress percentage (completed + running) / total * 100.
"""
function calculate_progress(completed::Int, running::Int, total::Int)
    if total == 0
        return 0.0
    end
    return ((completed + running) / total) * 100.0
end

"""
    format_elapsed_time(start_time::DateTime, end_time::DateTime) -> String

Format elapsed time as human-readable string (e.g., "2h 30m").
"""
function format_elapsed_time(start_time::DateTime, end_time::DateTime)
    elapsed = end_time - start_time

    hours = div(Dates.value(elapsed), 3600000)
    minutes = div(mod(Dates.value(elapsed), 3600000), 60000)
    seconds = div(mod(Dates.value(elapsed), 60000), 1000)

    if hours > 0
        return "$(hours)h $(minutes)m"
    elseif minutes > 0
        return "$(minutes)m $(seconds)s"
    else
        return "$(seconds)s"
    end
end

"""
    format_status_display(summary::Dict) -> String

Format batch status summary for terminal display.
"""
function format_status_display(summary::Dict)
    output = IOBuffer()

    println(output, "="^70)
    println(output, "BATCH STATUS: $(summary["batch_id"])")
    println(output, "="^70)
    println(output)

    println(output, "Batch Type:      $(get(summary, "batch_type", "unknown"))")
    println(output, "Status:          $(summary["status"])")

    if haskey(summary, "created_at")
        println(output, "Created:         $(summary["created_at"])")
    end

    println(output)
    println(output, "Experiments:")
    println(output, "  Total:         $(summary["total_experiments"])")
    println(output, "  Completed:     $(summary["completed"])")
    println(output, "  Running:       $(summary["running"])")
    println(output, "  Pending:       $(summary["pending"])")
    println(output, "  Failed:        $(summary["failed"])")

    # Calculate and display progress
    progress = calculate_progress(
        summary["completed"],
        summary["running"],
        summary["total_experiments"]
    )
    println(output, @sprintf("\nProgress:        %.1f%%", progress))

    # Progress bar
    bar_width = 40
    filled = round(Int, bar_width * progress / 100)
    empty = bar_width - filled
    bar = "█"^filled * "░"^empty
    println(output, "[$(bar)]")

    println(output)
    println(output, "="^70)

    return String(take!(output))
end

"""
    format_detailed_display(batch_dir::String) -> String

Format detailed experiment listing for terminal display.
"""
function format_detailed_display(batch_dir::String)
    summary = get_batch_status_summary(batch_dir)
    details = get_experiment_details(batch_dir)

    output = IOBuffer()

    # Print summary first
    print(output, format_status_display(summary))

    # Print detailed experiment list
    println(output, "\nDETAILED EXPERIMENT LIST:")
    println(output, "="^70)
    println(output)

    for detail in details
        status_symbol = if detail["status"] == "completed"
            "✓"
        elseif detail["status"] == "running"
            "⟳"
        elseif detail["status"] == "failed"
            "✗"
        else  # pending
            "○"
        end

        println(output, "$(status_symbol) $(detail["experiment_id"])")
        println(output, "  Status:        $(detail["status"])")

        if !isnothing(detail["start_time"])
            println(output, "  Started:       $(detail["start_time"])")

            if !isnothing(detail["end_time"])
                elapsed = format_elapsed_time(detail["start_time"], detail["end_time"])
                println(output, "  Completed:     $(detail["end_time"]) (elapsed: $(elapsed))")
            else
                # Still running - show elapsed since start
                elapsed = format_elapsed_time(detail["start_time"], now())
                println(output, "  Elapsed:       $(elapsed)")
            end
        end

        if !isnothing(detail["error"])
            println(output, "  Error:         $(detail["error"])")
        end

        println(output, "  Script:        $(detail["script_path"])")
        println(output, "  Output:        $(detail["output_dir"])")
        println(output)
    end

    return String(take!(output))
end

# ============================================================================
# CLI Argument Parsing
# ============================================================================

"""
    parse_commandline(args=ARGS) -> Dict

Parse command-line arguments for batch status tool.
"""
function parse_commandline(args=ARGS)
    s = ArgParseSettings(
        description = "Display batch experiment status",
        version = "1.0.0",
        add_version = true
    )

    @add_arg_table! s begin
        "batch_dir"
            help = "Directory containing batch_manifest.json"
            required = true
        "--detailed", "-d"
            help = "Show detailed experiment information"
            action = :store_true
        "--json", "-j"
            help = "Output status as JSON"
            action = :store_true
    end

    return parse_args(args, s)
end

# ============================================================================
# Main Entry Point
# ============================================================================

function main()
    args = parse_commandline()

    batch_dir = args["batch_dir"]

    # Check if batch directory exists
    if !isdir(batch_dir)
        error("Batch directory not found: $batch_dir")
    end

    # Check if manifest exists
    manifest_path = joinpath(batch_dir, "batch_manifest.json")
    if !isfile(manifest_path)
        error("No batch manifest found in: $batch_dir")
    end

    # Output format
    if args["json"]
        # JSON output
        status = get_status_json(batch_dir)
        println(JSON3.pretty(status))
    elseif args["detailed"]
        # Detailed display
        print(format_detailed_display(batch_dir))
    else
        # Summary display
        summary = get_batch_status_summary(batch_dir)
        print(format_status_display(summary))
    end
end

# Run main if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
