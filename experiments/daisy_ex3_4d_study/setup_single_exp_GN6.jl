#!/usr/bin/env julia
"""
Setup script for single Lotka-Volterra 4D experiment
========================================================================

Configuration:
- GN = 6 (samples per dimension)
- Degree range: 4 to 8
- Domain range: 0.2
- Domain center offset: random vector of length sqrt(4*0.05^2)/2 from true point

Author: GlobTim Project
Date: October 8, 2025
"""

using Pkg

# Use PathManager for robust path resolution (Issue #192)
# PathManager consolidates PathUtils, OutputPathManager, ExperimentPaths, etc.
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "PathManager.jl"))
using .PathManager

project_root = get_project_root()
Pkg.activate(project_root)
Pkg.instantiate()

using Random
using LinearAlgebra
using StaticArrays
using JSON
using Dates
using Printf

# Set random seed for reproducibility
Random.seed!(42)

# Configuration constants
const GN = 6  # samples per dimension
const DEGREE_RANGE = (4, 8)  # min and max degree
const DOMAIN_RANGE = 0.2
const P_TRUE = [0.2, 0.3, 0.5, 0.6]  # True parameters for Lotka-Volterra 4D
const IC = [1.0, 2.0, 1.0, 1.0]      # Initial conditions
const TIME_INTERVAL = [0.0, 10.0]    # Time interval
const NUM_POINTS = 25                 # Number of time points

"""
Generate a random unit vector in 4D space and scale to specified length
"""
function generate_random_offset_vector(target_length::Float64)
    # Generate random vector components
    components = randn(4)

    # Normalize to unit vector
    unit_vector = components / norm(components)

    # Scale to target length
    offset_vector = unit_vector * target_length

    return offset_vector
end

"""
Create experiment configuration for a specific domain range
"""
function create_experiment_config(experiment_id::Int, domain_range::Float64)
    # Calculate random offset vector length: sqrt(4*0.05^2)/2
    offset_length = sqrt(4 * 0.05^2) / 2

    # Generate random offset vector
    offset_vector = generate_random_offset_vector(offset_length)

    # Calculate domain center (true point + random offset)
    p_center = P_TRUE .+ offset_vector

    # Create configuration dictionary
    config = Dict(
        "experiment_id" => experiment_id,
        "domain_range" => domain_range,
        "GN" => GN,
        "degree_min" => DEGREE_RANGE[1],
        "degree_max" => DEGREE_RANGE[2],
        "p_true" => P_TRUE,
        "p_center" => p_center,
        "offset_vector" => offset_vector,
        "offset_length" => offset_length,
        "ic" => IC,
        "time_interval" => TIME_INTERVAL,
        "num_points" => NUM_POINTS,
        "model_func" => "define_daisy_ex3_model_4D",
        "basis" => "chebyshev",
        "precision" => "Float64Precision",
        "distance" => "L2_norm",
        "created_at" => string(now()),
        "description" => "Lotka-Volterra 4D experiment with GN=6, domain range $(domain_range), degree range $(DEGREE_RANGE)"
    )

    return config
end

"""
Generate HPC script for experiment
"""
function generate_hpc_script(experiment_id::Int, config::Dict, output_dir::String)
    script_path = joinpath(output_dir, "lotka_volterra_4d_exp$(experiment_id).jl")

    script_content = """
#!/usr/bin/env julia
\"\"\"
Lotka-Volterra 4D Experiment $(experiment_id)
GN=$(config["GN"]), Domain Range=$(config["domain_range"]), Degree Range=$(DEGREE_RANGE)
\"\"\"

using Pkg
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "PathUtils.jl"))
using .PathUtils
project_root = get_project_root()
Pkg.activate(project_root)

using StaticArrays
using DynamicPolynomials
using LinearAlgebra
using DataFrames
using CSV
using JSON
using TimerOutputs
using Printf
using Dates

include(joinpath(project_root, "src", "DaisyModels.jl"))
include(joinpath(project_root, "src", "TrajectoryRefinement.jl"))
include(joinpath(project_root, "src", "Precision.jl"))
include(joinpath(project_root, "src", "Constructor.jl"))
include(joinpath(project_root, "src", "SolvePolySystem.jl"))
include(joinpath(project_root, "src", "ProcessCritPoints.jl"))

# Configuration from JSON
const GN = $(config["GN"])
const DEGREE_MIN = $(config["degree_min"])
const DEGREE_MAX = $(config["degree_max"])
const DOMAIN_RANGE = $(config["domain_range"])
const P_TRUE = $(config["p_true"])
const P_CENTER = $(config["p_center"])
const IC = $(config["ic"])
const TIME_INTERVAL = $(config["time_interval"])
const NUM_POINTS = $(config["num_points"])

# Create timestamp-based results directory using centralized path (Issue #145)
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
results_root = get_results_root()
batch_name = "lv4d_single_$(Dates.format(now(), "yyyymmdd"))"
batch_dir = joinpath(results_root, "batches", batch_name)
results_dir = joinpath(batch_dir, "lv4d_GN$(GN)_range$(DOMAIN_RANGE)_$(timestamp)")
mkpath(results_dir)

println("="^80)
println("Lotka-Volterra 4D Experiment $(experiment_id)")
println("="^80)
println("GN: \$GN")
println("Domain Range: \$DOMAIN_RANGE")
println("Degree Range: \$DEGREE_MIN to \$DEGREE_MAX")
println("True Parameters: \$P_TRUE")
println("Domain Center: \$P_CENTER")
println("Results Directory: \$results_dir")
println("="^80)

# Create TimerOutput for performance tracking
const to = TimerOutput()

# Step 1: Define model and create trajectory refinement
println("\\nStep 1: Setting up model and trajectory refinement...")

model = define_daisy_ex3_model_4D()

@timeit to "trajectory_refinement" begin
    TR = TrajectoryRefinement(
        model,
        TIME_INTERVAL[1], TIME_INTERVAL[2],
        NUM_POINTS,
        IC,
        P_CENTER,
        DOMAIN_RANGE,
        GN;
        float_type = Float64
    )
end

println("✓ Trajectory refinement object created")
println("  Approximate trajectory length: \$(length(TR.times))")

# Define error function
error_func = (x, y) -> sum((x .- y).^2)

# Save experiment configuration
config_info = Dict(
    "experiment_id" => $(experiment_id),
    "GN" => GN,
    "degree_min" => DEGREE_MIN,
    "degree_max" => DEGREE_MAX,
    "domain_range" => DOMAIN_RANGE,
    "p_true" => P_TRUE,
    "p_center" => P_CENTER,
    "sample_range" => DOMAIN_RANGE,
    "basis" => "chebyshev",
    "model_func" => "define_daisy_ex3_model_4D",
    "time_interval" => TIME_INTERVAL,
    "num_points" => NUM_POINTS,
    "ic" => IC,
    "created_at" => string(now())
)

open(joinpath(results_dir, "experiment_config.json"), "w") do io
    JSON.print(io, config_info, 2)
end

# Test different polynomial degrees
results_summary = []

for degree in DEGREE_MIN:DEGREE_MAX
    println("\\nStep 2: Testing degree \$degree...")

    degree_start_time = time()

    @timeit to "constructor_deg_\$degree" begin
        try
            pol = Constructor(
                TR,
                (:one_d_for_all, degree),
                basis = :chebyshev,
                precision = Float64Precision,
                verbose = true
            )

            println("✓ Polynomial approximation complete for degree \$degree")
            println("  Condition number: \$(pol.cond_vandermonde)")
            println("  L2 norm (error): \$(pol.nrm)")

            # Find critical points
            @polyvar(x[1:4])

            @timeit to "solve_polynomial_deg_\$degree" begin
                real_pts, (pol_sys, system, nsols) = solve_polynomial_system(
                    x,
                    4,
                    (:one_d_for_all, degree),
                    pol.coeffs;
                    basis = :chebyshev,
                    return_system = true
                )
            end

            println("✓ Polynomial system solved for degree \$degree")
            println("  Total solutions: \$nsols")
            println("  Real solutions: \$(length(real_pts))")

            @timeit to "process_critical_points_deg_\$degree" begin
                df_critical = process_crit_pts(real_pts, error_func, TR)
            end

            println("✓ Critical points processed for degree \$degree")
            println("  Number of critical points: \$(nrow(df_critical))")

            # Calculate degree timing
            degree_time = time() - degree_start_time

            # Save degree-specific results
            degree_results = Dict(
                "degree" => degree,
                "condition_number" => pol.cond_vandermonde,
                "L2_norm" => pol.nrm,
                "real_solutions" => length(real_pts),
                "critical_points" => nrow(df_critical),
                "computation_time" => degree_time,
                "success" => true
            )

            if nrow(df_critical) > 0
                degree_results["best_value"] = minimum(df_critical.z)
                degree_results["worst_value"] = maximum(df_critical.z)
                degree_results["mean_value"] = mean(df_critical.z)

                # Save critical points for this degree
                CSV.write(joinpath(results_dir, "critical_points_deg_\$(degree).csv"), df_critical)
            end

            push!(results_summary, degree_results)

        catch e
            @warn "Failed for degree \$degree: \$e"
            push!(results_summary, Dict(
                "degree" => degree,
                "success" => false,
                "error" => string(e),
                "computation_time" => time() - degree_start_time
            ))
        end
    end
end

# Save comprehensive results summary
open(joinpath(results_dir, "results_summary.json"), "w") do io
    JSON.print(io, results_summary, 2)
end

# Display timer statistics
println("\\n" * "="^80)
println("Performance Summary")
println("="^80)
show(to)
println()

# Save timer output
open(joinpath(results_dir, "timing_profile.txt"), "w") do io
    show(io, to)
end

println("\\n" * "="^80)
println("Experiment Complete!")
println("="^80)
println("Results saved to: \$results_dir")
println("="^80)
"""

    open(script_path, "w") do io
        write(io, script_content)
    end

    # Make script executable
    chmod(script_path, 0o755)

    return script_path
end

# Main execution
println("Setting up Lotka-Volterra 4D experiment with GN=6...")

# Create timestamp-based output directory
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
output_dir = joinpath(dirname(@__FILE__), "configs_$(timestamp)")
mkpath(output_dir)

println("Output directory: $(output_dir)")
println()

# Create single experiment
experiment_id = 1
println("Creating experiment 1 with GN=$(GN), domain range $(DOMAIN_RANGE), degree range $(DEGREE_RANGE)...")

config = create_experiment_config(experiment_id, DOMAIN_RANGE)

# Save configuration JSON
config_path = joinpath(output_dir, "experiment_$(experiment_id)_config.json")
open(config_path, "w") do io
    JSON.print(io, config, 2)
end
println("  ✓ Configuration: $(config_path)")

# Generate HPC script
script_path = generate_hpc_script(experiment_id, config, output_dir)
println("  ✓ HPC script: $(script_path)")
println("  ✓ GN: $(GN)")
println("  ✓ Domain range: $(DOMAIN_RANGE)")
println("  ✓ Degree range: $(DEGREE_RANGE)")
println("  ✓ Domain center: $(round.(config["p_center"], digits=4))")
println("  ✓ Offset length: $(round(config["offset_length"], digits=2))")

# Save master configuration
master_config = Dict(
    "campaign_id" => "lv4d_GN6_range02",
    "created_at" => string(now()),
    "num_experiments" => 1,
    "GN" => GN,
    "degree_range" => collect(DEGREE_RANGE),
    "domain_range" => DOMAIN_RANGE,
    "experiments" => [config]
)

master_config_path = joinpath(output_dir, "master_config.json")
open(master_config_path, "w") do io
    JSON.print(io, master_config, 2)
end

println()
println("="^80)
println("Setup Complete!")
println("="^80)
println("Created 1 experiment:")
println("  Experiment 1: GN=$(GN), Domain range $(DOMAIN_RANGE), Degree range $(DEGREE_RANGE)")
println()
println("Master configuration: $(master_config_path)")
println("Output directory: $(output_dir)")
println("="^80)
println()
println("Validation Information:")
println("-"^50)
println("Experiment 1:")
println("  GN: $(GN)")
println("  Domain range: $(DOMAIN_RANGE)")
println("  Degree range: $(DEGREE_RANGE)")
println("  True parameters: $(P_TRUE)")
println("  Domain center: $(round.(config["p_center"], digits=4))")
println("  Offset vector: $(round.(config["offset_vector"], digits=4))")
println("  Offset length: $(round(config["offset_length"], digits=2)) (target: 0.05)")
