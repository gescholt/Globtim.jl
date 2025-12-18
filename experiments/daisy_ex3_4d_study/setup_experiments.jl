#!/usr/bin/env julia
"""
Setup script for Lotka-Volterra 4D experiments - PHASE 1 PIPELINE TEST
========================================================================

Campaign: LV4D 2025 - Phase 1 Test (October 11, 2025)

Configuration (Phase 1 - Pipeline Validation):
- GN = 16 (samples per dimension)
- Degree range: 4 to 6 (lightweight test)
- Domain ranges: 0.2 (single domain for fast validation)
- Domain center offset: random vector of length sqrt(4*0.05^2)/2 from true point

PURPOSE: Test full collection and analysis pipeline before scaling to degree 18

Author: GlobTim Project
Date: September 15, 2025 (Updated: October 11, 2025 - Phase 1)
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

# Include BatchManifest for formal batch tracking
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "BatchManifest.jl"))
using .BatchManifest
using .BatchManifest: ExperimentEntry, Manifest

# Set random seed for reproducibility
Random.seed!(42)

# Configuration constants
const GN = 16  # samples per dimension
const DEGREE_RANGE = (4, 6)  # min and max degree - PHASE 1 TEST
const DOMAIN_RANGES = [0.2]  # Single domain size for Phase 1 testing
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
        "description" => "Lotka-Volterra 4D experiment with domain range $(domain_range)"
    )

    return config
end

"""
Create Julia script for HPC execution
"""
function create_hpc_script(config::Dict, output_dir::String)
    experiment_id = config["experiment_id"]
    domain_range = config["domain_range"]

    # Generate portable script using PathUtils (Issue #135 and #145)
    script_template = """
#!/usr/bin/env julia
# Lotka-Volterra 4D Experiment $(experiment_id) - Domain Range $(domain_range)
# Generated on $(now())

using Pkg
Pkg.activate(dirname(dirname(dirname(@__DIR__))))
Pkg.instantiate()

using Globtim
using DynamicPolynomials
using DataFrames
using CSV
using TimerOutputs
using StaticArrays
using LinearAlgebra
using Statistics
using Dates
using JSON

# Include PathUtils for centralized path resolution (Issue #145)
include(joinpath(dirname(dirname(dirname(@__DIR__))), "src", "PathUtils.jl"))
using .PathManager

# Use Dynamic_objectives package for ODE models
using Dynamic_objectives

# Configuration from setup
const EXPERIMENT_ID = $(experiment_id)
const DOMAIN_RANGE = $(domain_range)
const GN = $(config["GN"])
const DEGREE_MIN = $(config["degree_min"])
const DEGREE_MAX = $(config["degree_max"])
const P_TRUE = $(config["p_true"])
const P_CENTER = $(config["p_center"])
const IC = $(config["ic"])
const TIME_INTERVAL = $(config["time_interval"])
const NUM_POINTS = $(config["num_points"])

# Results directory - centralized using GLOBTIM_RESULTS_ROOT (Issue #145)
results_root = get_results_root()
batch_name = "lv4d_\$(Dates.format(now(), "yyyymmdd"))"
batch_dir = joinpath(results_root, "batches", batch_name)
results_dir = joinpath(batch_dir, "exp_\$(EXPERIMENT_ID)_range\$(DOMAIN_RANGE)_\$(Dates.format(now(), "HHMMss"))")
mkpath(results_dir)

println("\\n" * "="^80)
println("Lotka-Volterra 4D Experiment \$EXPERIMENT_ID")
println("Domain Range: \$DOMAIN_RANGE")
println("="^80)
println("Configuration:")
println("  Dimension: 4")
println("  GN (samples per dim): \$GN")
println("  Degree range: \$DEGREE_MIN to \$DEGREE_MAX")
println("  Domain range: \$DOMAIN_RANGE")
println("  True parameters: \$P_TRUE")
println("  Domain center: \$P_CENTER")
println("  Results directory: \$results_dir")
println("="^80)

# Timer for performance tracking
to = TimerOutput()

# Define the Lotka-Volterra 4D model
model, params, states, outputs = define_daisy_ex3_model_4D()

# Create error function
error_func = make_error_distance(
    model,
    outputs,
    IC,
    P_TRUE,
    TIME_INTERVAL,
    NUM_POINTS,
    L2_norm
)

println("\\nStep 1: Generating sample points and evaluating function...")
@timeit to "test_input" begin
    TR = test_input(
        error_func,
        dim = 4,
        center = P_CENTER,
        GN = GN,
        sample_range = DOMAIN_RANGE
    )
end
println("✓ Generated \$(TR.GN) sample points")

# Save experiment configuration
config_info = Dict(
    "experiment_id" => EXPERIMENT_ID,
    "domain_range" => DOMAIN_RANGE,
    "dimension" => 4,
    "GN" => GN,
    "degree_range" => [DEGREE_MIN, DEGREE_MAX],
    "p_true" => P_TRUE,
    "p_center" => P_CENTER,
    "sample_range" => DOMAIN_RANGE,
    "basis" => "chebyshev",
    "model_func" => "define_daisy_ex3_model_4D",
    "time_interval" => TIME_INTERVAL,
    "num_points" => NUM_POINTS,
    "ic" => IC
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

# Save timing report
open(joinpath(results_dir, "timing_report.txt"), "w") do io
    print(io, to)
end

# Create summary report
open(joinpath(results_dir, "summary.txt"), "w") do io
    println(io, "Lotka-Volterra 4D Experiment \$EXPERIMENT_ID Summary")
    println(io, "="^60)
    println(io, "Generated: \$(now())")
    println(io, "")
    println(io, "Configuration:")
    println(io, "  Experiment ID: \$EXPERIMENT_ID")
    println(io, "  Domain Range: \$DOMAIN_RANGE")
    println(io, "  Dimension: 4")
    println(io, "  GN (samples per dim): \$GN")
    println(io, "  Degree range tested: \$DEGREE_MIN to \$DEGREE_MAX")
    println(io, "  True parameters: \$P_TRUE")
    println(io, "  Domain center: \$P_CENTER")
    println(io, "")
    println(io, "Results Summary:")

    successful_degrees = filter(r -> get(r, "success", false), results_summary)
    failed_degrees = filter(r -> !get(r, "success", false), results_summary)

    println(io, "  Successful degrees: \$(length(successful_degrees))/\$(length(results_summary))")
    if !isempty(failed_degrees)
        println(io, "  Failed degrees: \$([r["degree"] for r in failed_degrees])")
    end

    if !isempty(successful_degrees)
        best_degree = successful_degrees[argmin([r["L2_norm"] for r in successful_degrees])]
        println(io, "  Best degree (lowest L2 norm): \$(best_degree["degree"])")
        println(io, "    L2 norm: \$(best_degree["L2_norm"])")
        println(io, "    Condition number: \$(best_degree["condition_number"])")
        println(io, "    Critical points: \$(best_degree["critical_points"])")
    end

    println(io, "")
    println(io, "Timing Summary:")
    println(io, to)
end

println("\\n" * "="^80)
println("Experiment \$EXPERIMENT_ID completed!")
println("Results saved in: \$results_dir")
println("="^80)
"""

    # Make script portable with environment variable fallbacks (Issue #135)
    script_content = make_portable_script(script_template, project_root)

    script_path = joinpath(output_dir, "lotka_volterra_4d_exp$(experiment_id).jl")
    open(script_path, "w") do io
        print(io, script_content)
    end

    return script_path
end

# Main execution
function main()
    # Create output directory using PathUtils (Issue #135)
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    output_dir = create_output_dir(@__DIR__, "configs_$(timestamp)")

    println("Setting up 4 Lotka-Volterra 4D experiments...")
    println("Output directory: $(output_dir)")
    println()

    # Create configurations and scripts for each domain range
    experiment_configs = []
    script_paths = []

    for (i, domain_range) in enumerate(DOMAIN_RANGES)
        println("Creating experiment $(i) with domain range $(domain_range)...")

        # Create configuration
        config = create_experiment_config(i, domain_range)
        push!(experiment_configs, config)

        # Save individual config
        config_path = joinpath(output_dir, "experiment_$(i)_config.json")
        open(config_path, "w") do io
            JSON.print(io, config, 2)
        end

        # Create HPC script
        script_path = create_hpc_script(config, output_dir)
        push!(script_paths, script_path)

        println("  ✓ Configuration: $(config_path)")
        println("  ✓ HPC script: $(script_path)")
        println("  ✓ Domain range: $(domain_range)")
        println("  ✓ Domain center: $(round.(config["p_center"], digits=4))")
        println("  ✓ Offset length: $(round(config["offset_length"], digits=4))")
        println()
    end

    # Save master configuration
    master_config = Dict(
        "study_name" => "lotka_volterra_4d_domain_range_study",
        "created_at" => string(now()),
        "total_experiments" => length(DOMAIN_RANGES),
        "domain_ranges" => DOMAIN_RANGES,
        "parameters" => Dict(
            "GN" => GN,
            "degree_range" => DEGREE_RANGE,
            "p_true" => P_TRUE,
            "ic" => IC,
            "time_interval" => TIME_INTERVAL,
            "num_points" => NUM_POINTS
        ),
        "experiments" => experiment_configs,
        "script_paths" => script_paths
    )

    master_config_path = joinpath(output_dir, "master_config.json")
    open(master_config_path, "w") do io
        JSON.print(io, master_config, 2)
    end

    # Create batch manifest for experiment tracking
    batch_id = "lv4d_$(Dates.format(now(), "yyyymmdd_HHMMSS"))"

    # Create experiment entries for manifest
    manifest_experiments = [
        ExperimentEntry(
            "exp_$(config["experiment_id"])",
            basename(script_paths[i]),
            "experiment_$(config["experiment_id"])_config.json",
            "hpc_results/lotka_volterra_4d_exp$(config["experiment_id"])_range$(config["domain_range"])_\$(Dates.format(now(), \"yyyymmdd_HHMMSS\"))",
            "pending"
        )
        for (i, config) in enumerate(experiment_configs)
    ]

    # Create manifest with batch parameters
    manifest = Manifest(
        batch_id,
        "parameter_sweep",
        now(),
        length(DOMAIN_RANGES),
        manifest_experiments,
        Dict{String, Any}(
            "study_name" => "lotka_volterra_4d_domain_range_study",
            "domain_ranges" => DOMAIN_RANGES,
            "GN" => GN,
            "degree_range" => collect(DEGREE_RANGE),
            "p_true" => P_TRUE,
            "ic" => IC,
            "time_interval" => TIME_INTERVAL,
            "num_points" => NUM_POINTS,
            "model_func" => "define_daisy_ex3_model_4D"
        ),
        "pending"
    )

    # Save batch manifest
    save_batch_manifest(manifest, output_dir)

    # Save copy of this setup script for provenance (Issue: reproducibility)
    setup_script_copy = joinpath(output_dir, "setup_experiments_used.jl")
    cp(@__FILE__, setup_script_copy)
    println("📄 Saved setup script copy: $(basename(setup_script_copy))")

    println("="^80)
    println("Setup Complete!")
    println("="^80)
    println("Created $(length(DOMAIN_RANGES)) experiments:")
    for (i, range) in enumerate(DOMAIN_RANGES)
        println("  Experiment $(i): Domain range $(range)")
    end
    println()
    println("Master configuration: $(master_config_path)")
    println("Batch manifest: $(joinpath(output_dir, "batch_manifest.json"))")
    println("Batch ID: $(batch_id)")
    println("Output directory: $(output_dir)")
    println("="^80)

    return output_dir, experiment_configs, script_paths
end

# Execute setup
if abspath(PROGRAM_FILE) == @__FILE__
    output_dir, configs, scripts = main()

    # Display validation information
    println("\nValidation Information:")
    println("-"^50)
    for (i, config) in enumerate(configs)
        println("Experiment $(i):")
        println("  Domain range: $(config["domain_range"])")
        println("  True parameters: $(config["p_true"])")
        println("  Domain center: $(round.(config["p_center"], digits=4))")
        println("  Offset vector: $(round.(config["offset_vector"], digits=4))")
        println(
            "  Offset length: $(round(config["offset_length"], digits=4)) (target: $(round(sqrt(4*0.05^2)/2, digits=4)))"
        )
        println()
    end
end
