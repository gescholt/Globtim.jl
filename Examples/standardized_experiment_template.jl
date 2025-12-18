#!/usr/bin/env julia
"""
Standardized Experiment Template

This template demonstrates the ENFORCED output path standardization system.
All experiments MUST follow this pattern.

Usage:
    julia --project=. examples/standardized_experiment_template.jl --GN 8 --degree-range 4:6

Created: 2025-10-16 (Output Path Standardization)
"""

using Pkg
Pkg.activate(".")

using Globtim
using DynamicPolynomials
using Dates

# Import standardized modules
if !isdefined(Main, :ExperimentCLI)
    include(joinpath(@__DIR__, "..", "src", "ExperimentCLI.jl"))
end
using .ExperimentCLI

if !isdefined(Main, :StandardExperiment)
    include(joinpath(@__DIR__, "..", "src", "StandardExperiment.jl"))
end
using .StandardExperiment

# PathManager provides unified path management (Issue #192)
# Replaces: PathUtils, OutputPathManager, ExperimentPaths, etc.
using Globtim.PathManager

# Parse command-line arguments using standardized CLI
config = parse_experiment_args(ARGS)

println("="^80)
println("Standardized Experiment Template")
println("="^80)
println("Configuration:")
println("  GN: $(config.GN)")
println("  Degree range: $(config.degree_range)")
println("  Domain size: $(config.domain_size)")
println("  Max time: $(config.max_time)")
println("="^80)

# 1. VALIDATE OUTPUT CONFIGURATION (MANDATORY)
# This ensures GLOBTIM_RESULTS_ROOT is set - fails fast if not configured
validate_results_root()

# 2. DEFINE OBJECTIVE FUNCTION
# This example uses a simple 4D quadratic objective
function example_objective(point::Vector{Float64}, params)
    target = params.target
    # Sum of squared differences from target
    return sum((point .- target).^2)
end

# Problem parameters
true_params = [1.0, 2.0, 3.0, 4.0]
problem_params = (target = true_params,)

# Domain bounds (centered around true parameters)
domain_radius = config.domain_size
domain_bounds = [
    (true_params[i] - domain_radius, true_params[i] + domain_radius)
    for i in 1:4
]

# 3. CREATE STANDARDIZED OUTPUT DIRECTORY
# This is the REQUIRED way to create experiment output paths
objective_name = "example_quadratic_4d"
experiment_id = "template_test"

# Create directory using PathManager (Issue #192)
# Structure: $GLOBTIM_RESULTS_ROOT/objective_name/experiment_id_timestamp/
output_dir = create_experiment_dir(objective_name, experiment_id)

println("\n📁 Output directory created:")
println("   $output_dir")
println("\nThis follows the standard structure:")
println("   \$GLOBTIM_RESULTS_ROOT/$(objective_name)/$(experiment_id)_*")
println()

# Register experiment for tracking (optional)
experiment_metadata = Dict{String, Any}(
    "objective_name" => objective_name,
    "GN" => config.GN,
    "degree_range" => collect(config.degree_range),
    "domain_size" => config.domain_size,
    "true_params" => true_params
)
register_experiment(output_dir, experiment_metadata)

# 4. RUN STANDARDIZED EXPERIMENT
# StandardExperiment automatically validates paths and enforces standards
result = run_standard_experiment(
    objective_function = example_objective,
    problem_params = problem_params,
    domain_bounds = domain_bounds,
    experiment_config = config,
    output_dir = output_dir,
    metadata = Dict(
        "objective_name" => objective_name,
        "experiment_type" => "example_template",
        "system_type" => "quadratic_4d",
        "true_params" => true_params,
        "description" => "Standardized experiment template demonstration"
    ),
    true_params = true_params  # Enables recovery_error calculation
)

# 5. PRINT SUMMARY
println("\n" * "="^80)
println("✅ Experiment Complete")
println("="^80)
println("Results location:")
println("  $output_dir")
println("\nFiles created:")
println("  ├─ results_summary.json    (Schema v1.1.0)")
println("  ├─ results_summary.jld2    (DrWatson format)")
for degree in config.degree_range
    println("  ├─ critical_points_deg_$(degree).csv")
end
println("\nOutput structure follows ENFORCED standardization:")
println("  \$GLOBTIM_RESULTS_ROOT/")
println("  └── $(objective_name)/")
println("      └── $(basename(output_dir))/")
println("          ├── results_summary.json")
println("          └── critical_points_*.csv")
println("="^80)
println("\nTo analyze results:")
println("  julia --project=globtimpostprocessing globtimpostprocessing/analyze_experiments.jl \\")
println("    --objective $(objective_name)")
println()
