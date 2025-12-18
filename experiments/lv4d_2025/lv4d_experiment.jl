#!/usr/bin/env julia
"""
Lotka-Volterra 4D Parameter Recovery Experiment

Modern template using StandardExperiment.jl with Schema v1.2.0 validation.

Features:
- ForwardDiff gradient verification (spurious critical point detection)
- Hessian-based classification (minimum/maximum/saddle)
- Distinct local minima detection
- CSV export with validation columns
- JSON output with validation_stats

Usage:
    julia --project=. experiments/lv4d_2025/lv4d_experiment.jl \\
        --GN 16 \\
        --degree-range 4:2:12 \\
        --domain 0.4 \\
        --seed 42

Arguments:
    --GN: Grid nodes per dimension (default: 16)
    --degree-range: Polynomial degrees as start:step:stop (default: 4:2:12)
    --domain: Domain size around center (±value, default: 0.4)
    --basis: Polynomial basis type - chebyshev or legendre (default: chebyshev)
    --seed: Random seed for p_true generation (default: nothing = random)
    --p-true: Explicit p_true values as comma-separated (overrides seed)
    --output-dir: Custom output directory (default: GLOBTIM_RESULTS_ROOT/lotka_volterra_4d/)
    --max-time: Maximum time per degree in seconds (default: 300.0)
    --max-iterations: Maximum optimization iterations per critical point (default: 300)
    --optim-f-tol: Function tolerance for optimization convergence (default: 1e-6)
    --optim-x-tol: Parameter tolerance for optimization convergence (default: 1e-6)

Generated: 2025-10-21 (Schema v1.2.0)
"""

const SCRIPT_DIR = @__DIR__
const PROJECT_ROOT = abspath(joinpath(SCRIPT_DIR, "..", ".."))

using Pkg
Pkg.activate(PROJECT_ROOT)
Pkg.instantiate()

using Dynamic_objectives
using Globtim
using DynamicPolynomials
using DataFrames
using CSV
using TimerOutputs
using StaticArrays
using LinearAlgebra
using Statistics
using Dates
using JSON3
using Random
using ArgParse

# Load StandardExperiment module
include(joinpath(PROJECT_ROOT, "src", "StandardExperiment.jl"))
using .StandardExperiment

# Load ExperimentCLI for argument parsing
include(joinpath(PROJECT_ROOT, "src", "ExperimentCLI.jl"))
using .ExperimentCLI

# Parse command-line arguments
function parse_lv4d_args()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--GN"
            help = "Grid nodes per dimension"
            arg_type = Int
            default = 16
        "--degree-range"
            help = "Polynomial degrees as start:step:stop (e.g., 4:2:12)"
            arg_type = String
            default = "4:2:12"
        "--domain"
            help = "Domain size around center (±value)"
            arg_type = Float64
            default = 0.4
        "--seed"
            help = "Random seed for p_true generation"
            arg_type = Int
            default = nothing
        "--p-true"
            help = "Explicit p_true as comma-separated values (e.g., 0.2,0.3,0.5,0.6)"
            arg_type = String
            default = nothing
        "--output-dir"
            help = "Custom output directory"
            arg_type = String
            default = nothing
        "--max-time"
            help = "Maximum time per degree (seconds)"
            arg_type = Float64
            default = 300.0
        "--basis"
            help = "Polynomial basis type (chebyshev or legendre)"
            arg_type = String
            default = "chebyshev"
        "--optim-f-tol"
            help = "Optim.jl function tolerance (f_abstol)"
            arg_type = Float64
            default = 1e-6
        "--optim-x-tol"
            help = "Optim.jl parameter tolerance (x_abstol)"
            arg_type = Float64
            default = 1e-6
        "--max-iterations"
            help = "Maximum number of optimization iterations per critical point"
            arg_type = Int
            default = 300
    end
    return parse_args(s)
end

# Main experiment
function main()
    args = parse_lv4d_args()

    # Parse degree range
    degree_range_parts = split(args["degree-range"], ":")
    if length(degree_range_parts) == 3
        deg_start = parse(Int, degree_range_parts[1])
        deg_step = parse(Int, degree_range_parts[2])
        deg_stop = parse(Int, degree_range_parts[3])
        degree_range = deg_start:deg_step:deg_stop
    elseif length(degree_range_parts) == 2
        # If only start:stop provided, default step is 1
        deg_start = parse(Int, degree_range_parts[1])
        deg_stop = parse(Int, degree_range_parts[2])
        degree_range = deg_start:1:deg_stop
    else
        error("Invalid degree-range format. Use start:stop or start:step:stop (e.g., 4:12 or 4:2:12)")
    end

    # Configuration
    GN = args["GN"]
    domain_size = args["domain"]
    max_time = args["max-time"]
    basis = args["basis"]

    # Validate basis
    if !(basis in ["chebyshev", "legendre"])
        error("Invalid basis: $basis. Must be 'chebyshev' or 'legendre'")
    end

    # Generate or parse p_true
    p_center = [0.224, 0.273, 0.473, 0.578]  # Default center
    p_true = if args["p-true"] !== nothing
        # Explicit p_true provided
        parse.(Float64, split(args["p-true"], ","))
    elseif args["seed"] !== nothing
        # Generate p_true with seed
        Random.seed!(args["seed"])
        p_center .+ (rand(4) .- 0.5) .* (domain_size * 0.8)  # Stay within 80% of domain
    else
        # Generate p_true without seed (random)
        p_center .+ (rand(4) .- 0.5) .* (domain_size * 0.8)
    end

    # Initial conditions and time interval
    ic = [1.0, 2.0, 1.0, 1.0]
    time_interval = [0.0, 10.0]
    num_points = 25

    println("="^80)
    println("LOTKA-VOLTERRA 4D EXPERIMENT (Schema v1.2.0)")
    println("="^80)

    # Setup LV4D model
    println("Setting up LV4D model...")
    model, params, states, outputs = define_daisy_ex3_model_4D()

    # Create error function with timeout
    eval_timeout = 5.0
    error_func = make_error_distance(
        model,
        outputs,
        ic,
        p_true,
        time_interval,
        num_points,
        L2_norm,
        first,  # aggregate_distances
        nothing;  # add_noise_in_time_series
        return_inf_on_error = true,
        eval_timeout = eval_timeout
    )

    # Create domain bounds
    domain_bounds = [(p_center[i] - domain_size, p_center[i] + domain_size) for i in 1:4]

    # Create experiment configuration
    experiment_config = ExperimentParams(
        domain_size = domain_size,
        GN = GN,
        degree_range = degree_range,
        max_time = max_time,
        basis = basis,
        optim_f_tol = args["optim-f-tol"],
        optim_x_tol = args["optim-x-tol"],
        max_iterations = args["max-iterations"]
    )

    # Setup output directory
    if args["output-dir"] !== nothing
        output_dir = args["output-dir"]
    else
        # Use relative path to globtim_results (sibling of globtimcore)
        results_root = joinpath(dirname(dirname(dirname(@__DIR__))), "globtim_results")
        mkpath(results_root)  # Ensure it exists
        timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
        seed_str = args["seed"] !== nothing ? "_seed$(args["seed"])" : ""
        experiment_name = "lv4d_GN$(GN)_domain$(domain_size)$(seed_str)_$(timestamp)"
        output_dir = joinpath(results_root, "lotka_volterra_4d", experiment_name)
    end

    mkpath(output_dir)

    # Prepare metadata for Schema v1.2.0
    metadata = Dict{String, Any}(
        "experiment_type" => "4d_lotka_volterra",
        "objective_name" => "lotka_volterra_4d",
        "system_info" => Dict(
            "system_type" => "lotka_volterra_4d",
            "dimension" => 4,
            "domain_center" => p_center,
            "domain_size" => domain_size,
            "known_equilibrium" => p_true,
            "objective_function" => "squared_system_residual"
        ),
        "campaign" => "lv4d_2025",
        "basis" => basis,
        "loss_function" => "L2",
        "support_type" => "hypercube",
        "random_seed" => args["seed"]
    )

    # Objective function wrapper for StandardExperiment
    # StandardExperiment expects: objective_function(point, problem_params)
    # Our error_func has signature: error_func(point)
    objective_for_standard = (point, _) -> error_func(point)

    # Run experiment using StandardExperiment.jl
    println("Running experiment...")

    experiment_start = time()

    result = run_standard_experiment(
        objective_function = objective_for_standard,
        problem_params = nothing,  # Not used (error_func already has p_true baked in)
        domain_bounds = domain_bounds,
        experiment_config = experiment_config,
        output_dir = output_dir,
        metadata = metadata,
        true_params = p_true  # Enables recovery_error calculation
    )

    total_time = time() - experiment_start

    # Print summary
    println()
    println("="^80)
    println("EXPERIMENT COMPLETE")
    println("="^80)
end

# Run main
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
