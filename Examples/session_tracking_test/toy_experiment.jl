#!/usr/bin/env julia
"""
Toy experiment to test session-directory linkage and progress tracking.
Simulates a multi-step computation with progress updates.
"""

using Pkg
Pkg.activate(".")

using JSON
using Dates
using Printf

# Load PathManager module for session tracking functions (Issue #192)
# PathManager consolidates ExperimentPathTracker and other path modules
include("../../src/PathManager.jl")
using .PathManager

function main()
    # Get output directory from command line args or environment
    output_dir = get(ENV, "EXPERIMENT_OUTPUT_DIR", ".")

    if length(ARGS) > 0
        output_dir = ARGS[1]
    end

    println("=" ^ 60)
    println("🧪 TOY EXPERIMENT: Session Tracking Test")
    println("=" ^ 60)
    println("Output directory: $output_dir")
    println()

    # Verify output directory exists
    if !isdir(output_dir)
        @error "Output directory does not exist: $output_dir"
        exit(1)
    end

    # Simulate multi-step computation
    steps = ["initialize", "compute_phase_1", "compute_phase_2", "compute_phase_3", "finalize"]
    total_steps = length(steps)

    results = Dict{String, Any}()

    try
        for (i, step) in enumerate(steps)
            println("\n▶️  Step $i/$total_steps: $step")

            # Simulate computation time
            sleep_time = rand(2:5)  # Random sleep 2-5 seconds
            println("   (sleeping for $sleep_time seconds to simulate work...)")
            sleep(sleep_time)

            # Store dummy result
            results[step] = Dict(
                "completed_at" => string(now()),
                "duration_seconds" => sleep_time,
                "result_value" => rand()
            )

            # Update progress using ExperimentPathTracker
            update_experiment_progress(output_dir, i, total_steps, current_step_name=step)

            println("   ✅ Completed")
        end

        # Save final results
        results_file = joinpath(output_dir, "toy_results.json")
        open(results_file, "w") do io
            JSON.print(io, results, 2)
        end
        println("\n💾 Results saved to: $results_file")

        # Mark as completed using ExperimentPathTracker
        finalize_experiment_session(output_dir, true, "All steps completed successfully")

        println("\n" * "=" ^ 60)
        println("✅ EXPERIMENT COMPLETED SUCCESSFULLY")
        println("=" ^ 60)

    catch e
        @error "Experiment failed" exception=(e, catch_backtrace())
        finalize_experiment_session(output_dir, false, "Error: $e")

        println("\n" * "=" ^ 60)
        println("❌ EXPERIMENT FAILED")
        println("=" ^ 60)

        rethrow(e)
    end
end

main()
