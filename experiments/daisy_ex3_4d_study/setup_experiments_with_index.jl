#!/usr/bin/env julia
"""
Setup script for Lotka-Volterra 4D experiments WITH INDEXING
============================================================

This is an enhanced version of setup_experiments.jl that integrates
with the experiment index system for:
- Duplicate detection
- Parameter tracking
- Experiment history

Author: GlobTim Project
Date: October 6, 2025
"""

using Pkg

# Use PathUtils for robust path resolution
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "PathManager.jl"))
using .PathManager

project_root = get_project_root()
Pkg.activate(project_root)
Pkg.instantiate()

# Load index integration
include(joinpath(project_root, "src", "ExperimentIndexIntegration.jl"))

using Random
using LinearAlgebra
using JSON
using Dates
using Printf

# Set random seed for reproducibility
Random.seed!(42)

# Configuration constants
const GN = 16
const DEGREE_RANGE = (4, 12)
const DOMAIN_RANGES = [0.4, 0.8, 1.2, 1.6]
const P_TRUE = [0.2, 0.3, 0.5, 0.6]
const IC = [1.0, 2.0, 1.0, 1.0]
const TIME_INTERVAL = [0.0, 10.0]
const NUM_POINTS = 25

"""
Generate a random unit vector in 4D space and scale to specified length
"""
function generate_random_offset_vector(target_length::Float64)
    components = randn(4)
    unit_vector = components / norm(components)
    offset_vector = unit_vector * target_length
    return offset_vector
end

"""
Create experiment configuration for a specific domain range
"""
function create_experiment_config(experiment_id::Int, domain_range::Float64)
    offset_length = sqrt(4 * 0.05^2) / 2
    offset_vector = generate_random_offset_vector(offset_length)
    p_center = P_TRUE .+ offset_vector

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
Main setup function with indexing integration
"""
function main()
    println("=" ^80)
    println("Lotka-Volterra 4D Experiment Setup with Indexing")
    println("=" ^80)
    println()

    # Create timestamp for this batch
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    config_dir = joinpath(@__DIR__, "configs_$(timestamp)")
    mkpath(config_dir)

    println("📁 Configuration directory: $(config_dir)")
    println()

    # Track experiments with duplicates
    experiments_with_duplicates = []

    # Create configurations for each domain range
    all_configs = []
    for (idx, domain_range) in enumerate(DOMAIN_RANGES)
        println("Creating experiment $(idx) (domain_range=$(domain_range))...")

        config = create_experiment_config(idx, domain_range)

        # Check for duplicates and index the experiment
        experiment_name = "lotka_volterra_4d"
        experiment_path = joinpath(config_dir, "experiment_$(idx)_config.json")

        has_duplicates, comp_id, duplicates = check_and_index_experiment(
            config,
            experiment_name=experiment_name,
            experiment_path=experiment_path,
            warn_duplicates=true
        )

        if has_duplicates
            push!(experiments_with_duplicates, (idx, comp_id, length(duplicates)))
        end

        # Add computation_id to config
        config["computation_id"] = comp_id

        # Save config
        open(experiment_path, "w") do io
            JSON.print(io, config, 2)
        end

        push!(all_configs, config)
        println("   ✅ Config saved with computation ID: $(comp_id)")
        println()
    end

    # Create master config
    master_config = Dict(
        "campaign_name" => "LV4D_2025",
        "created_at" => timestamp,
        "total_experiments" => length(DOMAIN_RANGES),
        "GN" => GN,
        "degree_range" => DEGREE_RANGE,
        "domain_ranges" => DOMAIN_RANGES,
        "experiments" => [
            Dict(
                "id" => i,
                "computation_id" => cfg["computation_id"],
                "config_file" => "experiment_$(i)_config.json",
                "domain_range" => cfg["domain_range"]
            )
            for (i, cfg) in enumerate(all_configs)
        ]
    )

    master_config_path = joinpath(config_dir, "master_config.json")
    open(master_config_path, "w") do io
        JSON.print(io, master_config, 2)
    end

    # Summary
    println("=" ^80)
    println("Setup Complete!")
    println("=" ^80)
    println("Total experiments:     $(length(all_configs))")
    println("With duplicates:       $(length(experiments_with_duplicates))")
    println("Configuration dir:     $(config_dir)")
    println("Master config:         $(master_config_path)")
    println()

    if !isempty(experiments_with_duplicates)
        println("⚠️  Experiments with potential duplicates:")
        for (idx, comp_id, dup_count) in experiments_with_duplicates
            println("   Experiment $(idx) ($(comp_id)): $(dup_count) duplicate(s) found")
        end
        println()
        println("Review the warnings above and consider:")
        println("  1. Reusing existing results if parameters are truly identical")
        println("  2. Modifying parameters if you intended a different experiment")
        println("  3. Proceeding anyway if this is intentional (e.g., reproducibility check)")
        println()
    end

    println("Next steps:")
    println("  1. Review configurations in $(config_dir)")
    println("  2. Submit experiments to HPC cluster")
    println("  3. Use search_experiments_cli() to query results")
    println()

    return config_dir
end

# Run main if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
