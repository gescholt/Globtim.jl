#!/usr/bin/env julia
# Lotka-Volterra 4D Extended Degree Experiment - Degrees 4-18, Domain 0.3
# Based on successful daisy_ex3_4d_study template
# Generated: 2025-10-13

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

# Include DynamicalSystems module
include(joinpath(dirname(dirname(@__DIR__)), "Examples", "systems", "DynamicalSystems.jl"))
using .DynamicalSystems

# Configuration - Extended degree testing
const DOMAIN_RANGE = 0.3
const GN = 16
const DEGREE_MIN = 4
const DEGREE_MAX = 18  # EXTENDED from usual 12
const P_TRUE = [0.2, 0.3, 0.5, 0.6]
const P_CENTER = [0.22400297579961453, 0.27321104265283463, 0.4733957065001409, 0.5776746672054316]
const IC = [1.0, 2.0, 1.0, 1.0]
const TIME_INTERVAL = [0.0, 10.0]
const NUM_POINTS = 25

# Results directory
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
results_dir = "hpc_results/lv4d_deg18_domain$(DOMAIN_RANGE)_GN$(GN)_$(timestamp)"
mkpath(results_dir)

println("\n" * "="^80)
println("LOTKA-VOLTERRA 4D EXTENDED DEGREE EXPERIMENT")
println("="^80)
println("Configuration:")
println("  Dimension: 4")
println("  GN (samples per dim): $GN")
println("  Degree range: $DEGREE_MIN to $DEGREE_MAX (EXTENDED)")
println("  Domain range: $DOMAIN_RANGE")
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
    "campaign" => "lv4d_deg18_testing_2025",
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
    "ic" => IC,
    "rationale" => "Testing extended degrees (4-18) based on successful convergence observed in campaign_lotka_volterra_4d_extended_degrees"
)

open(joinpath(results_dir, "experiment_config.json"), "w") do io
    JSON.print(io, config_info, 2)
end

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
                basis = :chebyshev,
                precision = Float64Precision,
                verbose = true
            )

            println("✓ Polynomial approximation complete for degree $degree")
            println("  Condition number: $(pol.cond_vandermonde)")
            println("  L2 norm (error): $(pol.nrm)")

            # Find critical points
            @polyvar(x[1:4])

            @timeit to "solve_polynomial_deg_$degree" begin
                real_pts, (pol_sys, system, nsols) = solve_polynomial_system(
                    x,
                    4,
                    (:one_d_for_all, degree),
                    pol.coeffs;
                    basis = :chebyshev,
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
                println("  Best objective value: $(round(minimum(df_critical.z), digits=2))")
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
    println(io, "Lotka-Volterra 4D Extended Degree Experiment Summary")
    println(io, "="^60)
    println(io, "Generated: $(now())")
    println(io, "")
    println(io, "Configuration:")
    println(io, "  Domain Range: $DOMAIN_RANGE")
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
    if length(successful_degrees) >= 3
        l2_norms = [r["L2_norm"] for r in successful_degrees]
        println(io, "  Initial L2 (deg $DEGREE_MIN): $(round(l2_norms[1], digits=2))")
        println(io, "  Final L2 (deg $(DEGREE_MIN + length(l2_norms) - 1)): $(round(l2_norms[end], digits=2))")
        reduction = l2_norms[1] / l2_norms[end]
        println(io, "  L2 reduction factor: $(round(reduction, digits=2))x")
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
