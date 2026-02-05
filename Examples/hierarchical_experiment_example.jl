#!/usr/bin/env julia
"""
Example: Using Hierarchical Experiment Path Structure

This example demonstrates how to use the hierarchical experiment output structure
introduced in Issue #174.

Benefits:
- Experiments grouped by objective function
- Simple path: base_dir/objective/exp_timestamp
- All parameters stay in config.json (no filesystem encoding)
- Easy to browse and organize large experiment collections

Created: 2025-10-15 (Issue #174)
"""

using Pkg
Pkg.activate(dirname(@__DIR__))

# Include the StandardExperiment module (which includes ExperimentPaths)
include("../src/StandardExperiment.jl")
using .StandardExperiment

println("="^80)
println("Hierarchical Experiment Path Structure - Example")
println("="^80)
println()

# Example 1: Simple hierarchical path generation
println("Example 1: Basic Hierarchical Path")
println("-"^40)

config = Dict(
    "objective_name" => "lotka_volterra_4d",
    "GN" => 8,
    "degree_range" => [4, 12],
    "domain_size_param" => 0.1,
    "max_time" => 120.0
)

output_dir = get_hierarchical_experiment_path(config, "test_results")
println("Config: objective_name = $(config["objective_name"])")
println("Generated path: $output_dir")
println("Structure: test_results/lotka_volterra_4d/exp_YYYYMMDD_HHMMSS")
println()

# Example 2: Different objective functions
println("Example 2: Multiple Objective Functions")
println("-"^40)

objectives = [
    "lotka_volterra_4d",
    "extended_brusselator",
    "degn_harrison"
]

for obj in objectives
    config["objective_name"] = obj
    path = get_hierarchical_experiment_path(config, "test_results")
    println("  $obj -> $path")
end
println()

# Example 3: Backwards compatibility (flat structure)
println("Example 3: Backwards Compatibility (Flat Structure)")
println("-"^40)

config = Dict("objective_name" => "lotka_volterra_4d")

# Hierarchical (new, default)
path_hier = get_hierarchical_experiment_path(config, "test_results", use_hierarchical=true)
println("Hierarchical: $path_hier")

# Flat (old, for backwards compatibility)
path_flat = get_hierarchical_experiment_path(config, "test_results", use_hierarchical=false)
println("Flat:         $path_flat")
println()

# Example 4: Objective name extraction from various config formats
println("Example 4: Objective Name Extraction")
println("-"^40)

# From explicit objective_name
config1 = Dict("objective_name" => "lotka_volterra_4d")
println("From objective_name: $(get_objective_name(config1))")

# From objective_function string
config2 = Dict("objective_function" => "extended_brusselator")
println("From objective_function (string): $(get_objective_name(config2))")

# From legacy experiment_type
config3 = Dict("experiment_type" => "4d_lotka_volterra")
println("From experiment_type (legacy): $(get_objective_name(config3))")

# Fallback
config4 = Dict{String, Any}()
println("From empty config (fallback): $(get_objective_name(config4))")
println()

# Example 5: Integration with StandardExperiment.run_standard_experiment
println("Example 5: Integration with run_standard_experiment")
println("-"^40)

config = Dict(
    "objective_name" => "simple_quadratic",
    "GN" => 4,
    "degree_range" => [2, 4],
    "domain_size_param" => 0.1,
    "max_time" => 60.0
)

# Generate hierarchical output directory
output_dir = get_hierarchical_experiment_path(config, "test_results")

println("Configuration:")
println("  objective_name: $(config["objective_name"])")
println("  GN: $(config["GN"])")
println("  degree_range: $(config["degree_range"])")
println("  All parameters stored in config.json")
println()
println("Generated output directory:")
println("  $output_dir")
println()
println("To run experiment:")
println("""
    result = run_standard_experiment(
        objective_function = my_objective,
        objective_name = "my_problem",
        problem_params = my_params,
        domain_bounds = my_bounds,
        experiment_config = parsed_config,
        output_dir = "$output_dir",
        metadata = config
    )
""")
println()

# Example 6: Directory structure visualization
println("Example 6: Directory Structure Visualization")
println("-"^40)

println("""
Before (Flat Structure):
  test_results/
  ├── standard_experiment_lv4d_deg4-12_20251014_171206/
  ├── standard_experiment_lv4d_deg4-12_20251014_143738/
  ├── timing_validation_20250929_225923/
  └── deg4_only_20251014_145539/

After (Hierarchical Structure):
  test_results/
  ├── lotka_volterra_4d/
  │   ├── exp_20251014_171206/
  │   ├── exp_20251014_171530/
  │   └── exp_20251015_093000/
  ├── extended_brusselator/
  │   ├── exp_20251014_180000/
  │   └── exp_20251014_181500/
  └── degn_harrison/
      └── exp_20251015_190000/

Benefits:
  ✓ Easy to find all experiments for a specific objective
  ✓ Simple path structure (only objective + timestamp)
  ✓ All parameters in config.json (no filesystem encoding)
  ✓ Flexible: add/remove parameters without changing paths
""")
println()

println("="^80)
println("Example complete!")
println("="^80)
println()
println("Next steps:")
println("  1. Use get_hierarchical_experiment_path() in your experiment scripts")
println("  2. Include 'objective_name' in your experiment metadata")
println("  3. All parameters stay in config.json - no filesystem encoding needed")
println()
