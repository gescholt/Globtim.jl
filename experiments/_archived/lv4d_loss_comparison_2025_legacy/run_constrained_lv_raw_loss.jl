#!/usr/bin/env julia
# Constrained Lotka-Volterra 4D Experiment: RAW L2 Loss Function
# Usage: julia --project=. run_constrained_lv_raw_loss.jl --GN 16 --deg-min 4 --deg-max 8 --domain 0.3 --seed 42

using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
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
using ArgParse
using Random

# Include SimpleOutputOrganizer
include(joinpath(dirname(dirname(@__DIR__)), "src", "SimpleOutputOrganizer.jl"))
using .SimpleOutputOrganizer

# Include DynamicalSystems module
include(joinpath(dirname(dirname(@__DIR__)), "Examples", "systems", "DynamicalSystems.jl"))
using .DynamicalSystems

# Parse command-line arguments
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--GN"
            help = "Number of samples per dimension"
            arg_type = Int
            default = 16
        "--deg-min"
            help = "Minimum polynomial degree"
            arg_type = Int
            default = 4
        "--deg-max"
            help = "Maximum polynomial degree"
            arg_type = Int
            default = 8
        "--domain"
            help = "Domain range (±value)"
            arg_type = Float64
            default = 0.1
        "--seed"
            help = "Random seed for reproducibility"
            arg_type = Int
            default = 42
        "--local"
            help = "Run locally (save to local_results/)"
            action = :store_true
        "--basis"
            help = "Polynomial basis (chebyshev or legendre)"
            arg_type = String
            default = "chebyshev"
    end
    return parse_args(s)
end

args = parse_commandline()

# Set random seed
const SEED = args["seed"]
Random.seed!(SEED)

# Configuration from arguments
const DOMAIN_RANGE = args["domain"]
const GN = args["GN"]
const DEGREE_MIN = args["deg-min"]
const DEGREE_MAX = args["deg-max"]
const BASIS = Symbol(args["basis"])
const IS_LOCAL = args["local"]
const LOSS_TYPE = "raw"

# Fixed known growth rates (not inferred)
const A_TRUE = [-0.5, 1.0, -0.5, 1.0]

# Generate true parameters (only epsilon perturbations - 4D problem)
# Sample epsilon from ball of radius 0.1
eps_norm = 0.1
eps_direction = randn(4)
eps_direction = eps_direction / norm(eps_direction)
const EPS_TRUE = eps_norm * rand() * eps_direction

# Parameters to infer (4D): only epsilon values
const P_TRUE = EPS_TRUE

# Generate p_center with small perturbation
const P_CENTER = P_TRUE .+ 0.05 * DOMAIN_RANGE * randn(length(P_TRUE))

# Fixed parameters
const IC = [5.0, 5.0, 5.0, 5.0]
const TIME_INTERVAL = [0.0, 10.0]
const NUM_POINTS = 25

println("="^80)
println("Constrained Lotka-Volterra 4D - RAW L2 Loss Function")
println("="^80)
println("  Loss function: RAW (L2 norm)")
println("  Random seed: $SEED")
println("  Parameters: 4 epsilon (growth rates fixed)")
println("  GN: $GN")
println("  Degrees: $DEGREE_MIN to $DEGREE_MAX")
println("  Domain: ±$DOMAIN_RANGE")
println("  Basis: $BASIS")
println("="^80)

# Create experiment configuration
exp_config = Dict{String, Any}(
    "objective_name" => "constrained_lv_4d",
    "loss_function" => LOSS_TYPE,
    "random_seed" => SEED,
    "campaign" => "lv4d_loss_comparison_2025",
    "dimension" => 4,  # Only inferring 4 epsilon parameters
    "GN" => GN,
    "degree_min" => DEGREE_MIN,
    "degree_max" => DEGREE_MAX,
    "degree_range" => [DEGREE_MIN, DEGREE_MAX],
    "domain_range" => DOMAIN_RANGE,
    "basis" => string(BASIS),
    "p_true" => P_TRUE,  # Only epsilon values [eps1, eps2, eps3, eps4]
    "p_center" => P_CENTER,
    "sample_range" => DOMAIN_RANGE,
    "model_func" => "define_constrained_lotka_volterra_4D",
    "time_interval" => TIME_INTERVAL,
    "num_points" => NUM_POINTS,
    "ic" => IC,
    "is_local" => IS_LOCAL,
    "a_fixed" => A_TRUE,  # Fixed growth rates (not inferred)
    "eps_true" => EPS_TRUE
)

# Create experiment directory
experiment_id = "lv4d_$(LOSS_TYPE)_GN$(GN)_deg$(DEGREE_MIN)-$(DEGREE_MAX)_seed$(SEED)_domain$(DOMAIN_RANGE)"
results_dir = create_experiment_dir(exp_config; experiment_id=experiment_id)

println("\nExperiment directory: $results_dir")
println("True parameters: ", P_TRUE)

# Define the constrained Lotka-Volterra 4D model
model, params, states, outputs = define_constrained_lotka_volterra_4D()

# Create error function with RAW L2 norm
error_func = make_error_distance(
    model,
    outputs,
    IC,
    P_TRUE,
    TIME_INTERVAL,
    NUM_POINTS,
    L2_norm  # RAW loss function
)

println("\nError function created (RAW L2 norm)")

# Test error function
test_error = error_func(P_CENTER)
println("Error at p_center: ", test_error)

# Run GlobTim experiment
println("\n" * "="^80)
println("Starting GlobTim optimization...")
println("="^80)

# Timer for performance tracking
to = TimerOutput()

println("Step 1: Generating sample points and evaluating function...")
@timeit to "test_input" begin
    TR = test_input(
        error_func,
        dim = 4,  # 4D problem: inferring only epsilon parameters
        center = P_CENTER,
        GN = GN,
        sample_range = DOMAIN_RANGE
    )
end
println("✓ Generated $(TR.GN) sample points")
println()

# Test different polynomial degrees
results_summary = []

for degree in DEGREE_MIN:DEGREE_MAX
    println("="^80)
    println("Processing Degree $degree ($(degree - DEGREE_MIN + 1)/$(DEGREE_MAX - DEGREE_MIN + 1))")
    println("="^80)

    degree_start_time = time()

    @timeit to "constructor_deg_$degree" begin
        try
            pol = Constructor(
                TR,
                (:one_d_for_all, degree),
                basis = BASIS,
                precision = Float64Precision,
                verbose = true
            )

            println("✓ Polynomial approximation complete for degree $degree")
            println("  Condition number: $(pol.cond_vandermonde)")
            println("  L2 norm (error): $(pol.nrm)")

            # Find critical points
            @polyvar(x[1:4])  # 4D problem

            @timeit to "solve_polynomial_deg_$degree" begin
                real_pts, (pol_sys, system, nsols) = solve_polynomial_system(
                    x,
                    4,  # 4D problem
                    (:one_d_for_all, degree),
                    pol.coeffs;
                    basis = BASIS,
                    return_system = true
                )
            end

            println("✓ Polynomial system solved for degree $degree")
            println("  Total solutions: $nsols")
            println("  Real solutions: $(length(real_pts))")

            @timeit to "process_critical_points_deg_$degree" begin
                df_critical = process_crit_pts(real_pts, error_func, TR)
            end

            println("✓ Critical points processed for degree $degree")
            println("  Number of critical points: $(nrow(df_critical))")

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
                CSV.write(joinpath(results_dir, "critical_points_deg_$(degree).csv"), df_critical)
                println("  Best objective value: $(round(minimum(df_critical.z), digits=6))")
            end

            push!(results_summary, degree_results)

            println("  Computation time: $(round(degree_time, digits=1))s")
            println("  ✓ Degree $degree complete")

        catch e
            degree_time = time() - degree_start_time
            @warn "Failed for degree $degree: $e"
            push!(results_summary, Dict(
                "degree" => degree,
                "success" => false,
                "error" => string(e),
                "computation_time" => degree_time
            ))
            println("  ✗ Degree $degree failed: $e")
        end
    end
    println()
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
    println(io, "Constrained Lotka-Volterra 4D - RAW L2 Loss Experiment Summary")
    println(io, "="^80)
    println(io, "Generated: $(now())")
    println(io, "")
    println(io, "Configuration:")
    println(io, "  Loss function: RAW (L2 norm)")
    println(io, "  Random seed: $SEED")
    println(io, "  Domain Range: ±$DOMAIN_RANGE")
    println(io, "  Dimension: 4 (inferring only epsilon, growth rates fixed)")
    println(io, "  GN (samples per dim): $GN")
    println(io, "  Degree range tested: $DEGREE_MIN to $DEGREE_MAX")
    println(io, "  Basis: $BASIS")
    println(io, "  True parameters: $P_TRUE")
    println(io, "  Domain center: $P_CENTER")
    println(io, "")
    println(io, "Results Summary:")

    successful_degrees = filter(r -> get(r, "success", false), results_summary)
    failed_degrees = filter(r -> !get(r, "success", false), results_summary)

    println(io, "  Successful degrees: $(length(successful_degrees))/$(length(results_summary))")
    if !isempty(failed_degrees)
        println(io, "  Failed degrees: $([r["degree"] for r in failed_degrees])")
    end

    if !isempty(successful_degrees)
        best_degree = successful_degrees[argmin([r["L2_norm"] for r in successful_degrees])]
        println(io, "  Best degree (lowest L2 norm): $(best_degree["degree"])")
        println(io, "    L2 norm: $(best_degree["L2_norm"])")
        println(io, "    Condition number: $(best_degree["condition_number"])")
        println(io, "    Critical points: $(best_degree["critical_points"])")
    end

    println(io, "")
    println(io, "Convergence Analysis:")
    if length(successful_degrees) >= 3
        l2_norms = [r["L2_norm"] for r in successful_degrees]
        println(io, "  Initial L2 (deg $DEGREE_MIN): $(round(l2_norms[1], digits=6))")
        println(io, "  Final L2 (deg $(DEGREE_MIN + length(l2_norms) - 1)): $(round(l2_norms[end], digits=6))")
        if l2_norms[end] > 0
            reduction = l2_norms[1] / l2_norms[end]
            println(io, "  L2 reduction factor: $(round(reduction, digits=2))x")
        end
    end

    println(io, "")
    println(io, "Timing Summary:")
    println(io, to)
end

println("="^80)
println("✨ Experiment complete!")
println("="^80)
println()
println("Results saved in: $results_dir")
println()
println("Summary Statistics:")
successful_degrees = filter(r -> get(r, "success", false), results_summary)
total_critical_points = sum(r -> get(r, "critical_points", 0), successful_degrees)
total_time = sum(r -> r["computation_time"], results_summary)
println("  Successful degrees: $(length(successful_degrees))/$(length(results_summary))")
println("  Total critical points: $total_critical_points")
println("  Total computation time: $(round(total_time, digits=1))s")
println()
