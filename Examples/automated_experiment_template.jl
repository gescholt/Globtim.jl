#!/usr/bin/env julia
"""
Automated Experiment Template - Zero-Config Output Organization

This template demonstrates the RECOMMENDED way to structure experiments
using ExperimentOutputOrganizer for automatic directory management.

Key features:
✓ One-line directory creation
✓ Automatic objective folder management
✓ Config file saved automatically
✓ All paths validated before experiment runs
✓ Compatible with ExperimentCollector batch analysis

See: docs/AUTOMATED_OUTPUT_ORGANIZATION.md
"""

using Pkg
Pkg.activate(@__DIR__)

# Option A: Standalone (Lightweight - only loads output organization)
# Uncomment this if you DON'T need the full Globtim module:
# include(joinpath(@__DIR__, "../src/ExperimentOutputOrganizer.jl"))
# using .ExperimentOutputOrganizer

# Option B: Via Globtim (use if you need other Globtim features)
using Globtim
using Globtim.ExperimentOutputOrganizer  # Wraps PathManager with batch-aware features
using Globtim.PathManager  # Unified path management (Issue #192)

using JSON3
using Dates

println("="^80)
println("  AUTOMATED EXPERIMENT TEMPLATE")
println("="^80)

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1: Define Experiment Configuration
# ═════════════════════════════════════════════════════════════════════════════

config = Dict{String, Any}(
    # ⚠️  REQUIRED: Objective function name (used for directory organization)
    "objective_name" => "lotka_volterra_4d",

    # Experiment parameters (customize as needed)
    "GN" => 12,
    "degree_range" => [4, 12],
    "basis" => "chebyshev",
    "domain_range" => 0.1,
    "dimension" => 4,

    # Metadata
    "experiment_type" => "mcp_sweep",
    "description" => "Example automated experiment",
    "created_at" => string(now())
)

println("\n📋 Experiment Configuration:")
println("   Objective: $(config["objective_name"])")
println("   GN: $(config["GN"])")
println("   Degree range: $(config["degree_range"])")
println("   Basis: $(config["basis"])")

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2: Create Experiment Directory (AUTOMATIC!)
# ═════════════════════════════════════════════════════════════════════════════

println("\n🔧 Creating experiment directory...")

# 🎯 THIS IS THE KEY FUNCTION - Use it in all your experiments!
exp_dir = validate_and_create_experiment_dir(config)

println("✅ Experiment directory ready:")
println("   $exp_dir")
println()
println("   Structure created:")
println("   └── $(basename(dirname(exp_dir)))/  (objective)")
println("       └── $(basename(exp_dir))/  (experiment)")
println("           └── experiment_config.json  ✓ (saved automatically)")

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3: Run Your Experiment
# ═════════════════════════════════════════════════════════════════════════════

println("\n🚀 Running experiment...")

# Simulate experiment (replace with actual computation)
sleep(0.5)

# Simulate results
results = Dict(
    "status" => "completed",
    "num_critical_points" => 42,
    "max_degree_reached" => 12,
    "total_time" => 120.5,
    "minimizers_found" => 3
)

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4: Save Results
# ═════════════════════════════════════════════════════════════════════════════

println("\n💾 Saving results...")

# Save results summary
results_path = joinpath(exp_dir, "results_summary.json")
open(results_path, "w") do io
    JSON3.pretty(io, results)
end
println("   ✓ results_summary.json")

# Save critical points (example)
for deg in 4:2:12
    csv_path = joinpath(exp_dir, "critical_points_deg_$(deg).csv")
    open(csv_path, "w") do io
        println(io, "x1,x2,x3,x4,value,eigenvalues")
        # Dummy data
        for i in 1:5
            println(io, "$(rand()),$(rand()),$(rand()),$(rand()),$(rand()),-1.0;-0.5;0.5;1.0")
        end
    end
    println("   ✓ critical_points_deg_$(deg).csv")
end

# Save timing report
timing_path = joinpath(exp_dir, "timing_report.txt")
open(timing_path, "w") do io
    println(io, "="^80)
    println(io, "TIMING REPORT")
    println(io, "="^80)
    println(io, "Total time: 120.5 seconds")
    println(io, "Setup: 5.2s")
    println(io, "Computation: 110.3s")
    println(io, "Postprocessing: 5.0s")
end
println("   ✓ timing_report.txt")

# ═════════════════════════════════════════════════════════════════════════════
# STEP 5: Validation
# ═════════════════════════════════════════════════════════════════════════════

println("\n✓ Experiment Complete!")
println()
println("📊 Validation:")

# Check all expected files exist
expected_files = [
    "experiment_config.json",
    "results_summary.json",
    "timing_report.txt"
]

for deg in 4:2:12
    push!(expected_files, "critical_points_deg_$(deg).csv")
end

all_present = true
for file in expected_files
    file_path = joinpath(exp_dir, file)
    exists = isfile(file_path)
    status = exists ? "✓" : "✗"
    println("   $status $file")
    all_present = all_present && exists
end

if all_present
    println("\n✅ All required files present")
    println("   Ready for analysis with globtimpostprocessing!")
else
    println("\n⚠️  Some files missing")
end

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6: Next Steps
# ═════════════════════════════════════════════════════════════════════════════

println()
println("="^80)
println("  NEXT STEPS")
println("="^80)
println()
println("To analyze this experiment:")
println()
println("  cd ../globtimpostprocessing")
println("  julia analyze_experiments.jl")
println()
println("To run a batch of experiments:")
println()
println("  for GN in 8 12 16; do")
println("      julia automated_experiment_template.jl --GN \$GN")
println("  done")
println()
println("To view results:")
println()
println("  cat $exp_dir/results_summary.json")
println()
println("="^80)

# ═════════════════════════════════════════════════════════════════════════════
# BONUS: Custom Experiment ID Example
# ═════════════════════════════════════════════════════════════════════════════

function run_batch_with_custom_ids()
    """
    Example: Run a batch of experiments with meaningful IDs
    """

    base_config = Dict{String, Any}(
        "objective_name" => "sphere_function",
        "dimension" => 10
    )

    for tolerance in [1e-6, 1e-8, 1e-10]
        # Create config for this run
        config = merge(base_config, Dict(
            "tolerance" => tolerance
        ))

        # Custom experiment ID based on parameters
        exp_id = "tol_$(Int(-log10(tolerance)))"

        # Create directory with custom ID
        exp_dir = validate_and_create_experiment_dir(
            config;
            experiment_id = exp_id
        )

        println("Created: $(basename(exp_dir))")
        # Results in: sphere_function/tol_6_20251016_161234/
        #                               tol_8_20251016_161235/
        #                               tol_10_20251016_161236/
    end
end

# Uncomment to test:
# run_batch_with_custom_ids()
