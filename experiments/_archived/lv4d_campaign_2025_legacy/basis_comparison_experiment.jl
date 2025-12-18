#!/usr/bin/env julia
# Lotka-Volterra 4D Basis Comparison Experiment
#
# PURPOSE: Test and compare different polynomial basis types (Chebyshev vs Legendre)
#          for the same parameter estimation problem.
#
# CONFIGURATION: Edit the BASIS_TYPE constant below to switch between basis types
#                - :chebyshev - Uses Chebyshev polynomials (standard approach)
#                - :legendre  - Uses Legendre polynomials (alternative approach)
#
# USAGE:
#   1. Edit BASIS_TYPE constant below to desired basis
#   2. Launch via standardized infrastructure (shell script + tmux)
#   3. Results include basis type in directory name and config
#
# Based on: daisy_ex3_4d_study template and deg18 campaign
# Generated: 2025-10-13

# ============================================================================
# CONFIGURATION SECTION - EDIT HERE
# ============================================================================

# Polynomial basis type - CHANGE THIS TO SWITCH BASIS
const BASIS_TYPE = :chebyshev  # Options: :chebyshev, :legendre

# Experiment parameters
const DOMAIN_RANGE = 0.3
const GN = 16
const DEGREE_MIN = 4
const DEGREE_MAX = 6  # Small range for testing/comparison

# Model parameters (Lotka-Volterra 4D)
const P_TRUE = [0.2, 0.3, 0.5, 0.6]
const P_CENTER = [0.22400297579961453, 0.27321104265283463, 0.4733957065001409, 0.5776746672054316]
const IC = [1.0, 2.0, 1.0, 1.0]
const TIME_INTERVAL = [0.0, 10.0]
const NUM_POINTS = 25

# ============================================================================
# END CONFIGURATION SECTION
# ============================================================================

using Pkg
# Activate the main globtimcore project (the one containing src/Globtim.jl)
# Store this in a global so we can use it for includes later
const GLOBTIM_ROOT = let
    script_dir = @__DIR__
    project_root = script_dir
    # Search up for a Project.toml that has src/Globtim.jl alongside it
    while true
        if isfile(joinpath(project_root, "Project.toml")) &&
           isfile(joinpath(project_root, "src", "Globtim.jl"))
            break
        end
        parent = dirname(project_root)
        if parent == project_root
            error("Could not find main Globtim project (with src/Globtim.jl)")
        end
        project_root = parent
    end
    Pkg.activate(project_root)
    Pkg.instantiate()
    project_root
end

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

# Include DynamicalSystems module
include(joinpath(GLOBTIM_ROOT, "Examples", "systems", "DynamicalSystems.jl"))
using .DynamicalSystems

# Validate basis type
@assert BASIS_TYPE in [:chebyshev, :legendre] "BASIS_TYPE must be :chebyshev or :legendre"

# Results directory - includes basis type in name
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
results_dir = "hpc_results/lv4d_basis_comparison_$(BASIS_TYPE)_deg$(DEGREE_MIN)-$(DEGREE_MAX)_domain$(DOMAIN_RANGE)_GN$(GN)_$(timestamp)"
mkpath(results_dir)

println("\n" * "="^80)
println("LOTKA-VOLTERRA 4D BASIS COMPARISON EXPERIMENT")
println("="^80)
println("Configuration:")
println("  Polynomial Basis: $(uppercase(string(BASIS_TYPE)))")
println("  Dimension: 4")
println("  GN (samples per dim): $GN")
println("  Degree range: $DEGREE_MIN to $DEGREE_MAX")
println("  Domain range: ±$DOMAIN_RANGE")
println("  True parameters: $P_TRUE")
println("  Domain center: $P_CENTER")
println("  Results directory: $results_dir")
println("="^80)
println()

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

println("Step 1: Generating sample points and evaluating function...")
@timeit to "test_input" begin
    TR = test_input(
        error_func,
        dim = 4,
        center = P_CENTER,
        GN = GN,
        sample_range = DOMAIN_RANGE
    )
end
println("✓ Generated $(TR.GN) sample points")
println()

# Save experiment configuration
config_info = Dict(
    "campaign" => "lv4d_basis_comparison_2025",
    "basis_type" => string(BASIS_TYPE),  # KEY: Basis type recorded in config
    "domain_range" => DOMAIN_RANGE,
    "dimension" => 4,
    "GN" => GN,
    "degree_range" => [DEGREE_MIN, DEGREE_MAX],
    "p_true" => P_TRUE,
    "p_center" => P_CENTER,
    "sample_range" => DOMAIN_RANGE,
    "model_func" => "define_daisy_ex3_model_4D",
    "time_interval" => TIME_INTERVAL,
    "num_points" => NUM_POINTS,
    "ic" => IC,
    "rationale" => "Comparing $(BASIS_TYPE) vs alternative basis types for polynomial approximation quality and convergence"
)

open(joinpath(results_dir, "experiment_config.json"), "w") do io
    JSON.print(io, config_info, 2)
end

# Test different polynomial degrees
results_summary = []

for degree in DEGREE_MIN:DEGREE_MAX
    println("="^80)
    println("Processing Degree $degree ($(degree - DEGREE_MIN + 1)/$(DEGREE_MAX - DEGREE_MIN + 1)) with $(uppercase(string(BASIS_TYPE))) basis")
    println("="^80)

    degree_start_time = time()

    @timeit to "constructor_deg_$degree" begin
        try
            # KEY: Using BASIS_TYPE parameter here
            pol = Constructor(
                TR,
                (:one_d_for_all, degree),
                basis = BASIS_TYPE,  # ← PARAMETERIZED
                precision = Float64Precision,
                verbose = true
            )

            println("✓ Polynomial approximation complete for degree $degree")
            println("  Basis: $(BASIS_TYPE)")
            println("  Condition number: $(pol.cond_vandermonde)")
            println("  L2 norm (error): $(pol.nrm)")

            # Find critical points
            @polyvar(x[1:4])

            @timeit to "solve_polynomial_deg_$degree" begin
                # KEY: Using BASIS_TYPE parameter here
                real_pts, (pol_sys, system, nsols) = solve_polynomial_system(
                    x,
                    4,
                    (:one_d_for_all, degree),
                    pol.coeffs;
                    basis = BASIS_TYPE,  # ← PARAMETERIZED
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
                "basis_type" => string(BASIS_TYPE),  # Record basis in results
                "condition_number" => pol.cond_vandermonde,
                "L2_norm" => pol.nrm,
                "total_solutions" => nsols,
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
                "basis_type" => string(BASIS_TYPE),
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
    println(io, "Lotka-Volterra 4D Basis Comparison Experiment Summary")
    println(io, "="^60)
    println(io, "Generated: $(now())")
    println(io, "")
    println(io, "Configuration:")
    println(io, "  Polynomial Basis: $(uppercase(string(BASIS_TYPE)))")
    println(io, "  Domain Range: ±$DOMAIN_RANGE")
    println(io, "  Dimension: 4")
    println(io, "  GN (samples per dim): $GN")
    println(io, "  Degree range tested: $DEGREE_MIN to $DEGREE_MAX")
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
    if length(successful_degrees) >= 2
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
println("  Basis type: $(uppercase(string(BASIS_TYPE)))")
println("  Successful degrees: $(length(successful_degrees))/$(length(results_summary))")
println("  Total critical points: $total_critical_points")
println("  Total computation time: $(round(total_time, digits=1))s")
println()
