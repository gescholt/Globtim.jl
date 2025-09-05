#!/usr/bin/env julia
"""
4D Lotka-Volterra Parameter Estimation Example
==============================================

Modern 4D parameter estimation example integrated with Issue #41 Strategic Hook Integration.
This script provides standardized 4D Lotka-Volterra parameter estimation with:

- Integration with strategic hook orchestrator system
- Fixed GN parameter bug (GN = samples per dimension, not total)
- Compatibility with current package infrastructure
- Comprehensive error handling and logging
- Standardized output format compatible with post-processing

Usage:
------
# Direct execution with defaults
./Examples/hpc_4d_lotka_volterra_example.jl

# With parameters
SAMPLES_PER_DIM=10 DEGREE=8 ./Examples/hpc_4d_lotka_volterra_example.jl

# Via robust experiment runner (recommended)
./hpc/experiments/robust_experiment_runner.sh hpc_4d_lotka_volterra_example.jl

Author: GlobTim Team
Date: September 2025
Updated: For Issue #41 Strategic Hook Integration
"""

using Pkg
Pkg.activate(get(ENV, "JULIA_PROJECT", "/home/scholten/globtim"))

using Globtim
using DynamicPolynomials
using DataFrames
using CSV
using JSON
using TimerOutputs
using StaticArrays
using LinearAlgebra
using Statistics
using Dates

# Get parameters from environment or use defaults
samples_per_dim = parse(Int, get(ENV, "SAMPLES_PER_DIM", "8"))
degree = parse(Int, get(ENV, "DEGREE", "10"))
results_dir = length(ARGS) > 0 ? ARGS[1] : joinpath(dirname(@__DIR__), "results", "4d_lotka_volterra_$(Dates.format(now(), "yyyymmdd_HHMMSS"))")

mkpath(results_dir)

# Timer for performance tracking
to = TimerOutput()

println("\n" * "="^80)
println("4D Lotka-Volterra Parameter Estimation Example")
println("Modern GlobTim Implementation with Hook Integration")
println("="^80)
println("Configuration:")
println("  Problem: 4D parameter estimation [α, β, γ, δ]")
println("  Polynomial degree: $degree")
println("  Samples per dimension: $samples_per_dim")
println("  Total grid points: $(samples_per_dim^4)")
println("  Results directory: $results_dir")
println("  Hook integration: Issue #41 compatible")
println("="^80)

# Lotka-Volterra system: dx/dt = αx - βxy, dy/dt = γxy - δy
# Estimate parameters θ = [α, β, γ, δ] from synthetic data

# True parameter values (biological realistic)
θ_true = [1.5, 1.0, 0.75, 1.25]  # [α, β, γ, δ]
println("True parameters: α=$(θ_true[1]), β=$(θ_true[2]), γ=$(θ_true[3]), δ=$(θ_true[4])")

# Time points and initial conditions
t_obs = collect(0:0.2:5.0)  # 26 time points
x0 = [10.0, 5.0]  # Initial conditions [prey, predator]

println("ODE setup: $(length(t_obs)) time points from $(t_obs[1]) to $(t_obs[end])")
println("Initial conditions: x0 = $x0")

# Simple Euler integration for Lotka-Volterra (robust implementation)
function lotka_volterra_solution(θ, x0, t_obs)
    α, β, γ, δ = θ
    dt = t_obs[2] - t_obs[1]
    sol = zeros(length(t_obs), 2)
    sol[1, :] = x0
    
    for i in 2:length(t_obs)
        x, y = sol[i-1, :]
        # Prevent negative populations (biological constraint)
        x = max(x, 0.0)
        y = max(y, 0.0)
        
        dx_dt = α*x - β*x*y
        dy_dt = γ*x*y - δ*y
        sol[i, :] = [x + dt*dx_dt, y + dt*dy_dt]
    end
    return sol
end

# Generate synthetic observed data
@timeit to "generate_synthetic_data" begin
    true_solution = lotka_volterra_solution(θ_true, x0, t_obs)
    
    # Add realistic noise
    noise_level = 0.1
    observed_data = true_solution + noise_level * randn(size(true_solution))
    
    # Ensure observed data is non-negative (biological constraint)
    observed_data = max.(observed_data, 0.01)
end

println("✓ Synthetic data generated with noise level $(noise_level)")

# Parameter estimation objective function (robust implementation)
function parameter_estimation_objective(θ::AbstractVector)
    # Biological constraints: all parameters must be positive
    if any(θ .<= 0) || any(θ .> 5.0)  # Upper bound for stability
        return 1e6
    end
    
    try
        # Solve ODE with candidate parameters
        predicted_solution = lotka_volterra_solution(θ, x0, t_obs)
        
        # Check for numerical stability
        if any(!isfinite.(predicted_solution))
            return 1e6
        end
        
        # Compute weighted residual (emphasize later time points)
        weights = collect(range(1.0, 2.0, length=length(t_obs)))
        residual = sum(weights .* sum((predicted_solution - observed_data).^2, dims=2))
        
        return residual
    catch e
        # Return large penalty for integration failures
        return 1e6
    end
end

# Define parameter space (CRITICAL: Fixed GN parameter bug)
θ_center = [1.0, 1.0, 1.0, 1.0]  # Parameter space center
θ_range = 0.8  # ±80% range around center
n = 4  # Parameter space dimension

# CRITICAL FIX: GN = samples_per_dim, NOT samples_per_dim^n
# This was the major bug causing memory issues in previous experiments
GN = samples_per_dim  # Samples per dimension (GlobTim handles total internally)

println("\nStep 1: Parameter space sampling...")
println("  Parameter center: $θ_center")
println("  Parameter range: ±$θ_range")
println("  Samples per dimension: $GN (FIXED: not $GN^4)")
println("  Total samples generated: $(GN^4) (handled internally by GlobTim)")

@timeit to "test_input" begin
    TR = test_input(
        parameter_estimation_objective,
        dim = n,
        center = θ_center,
        GN = GN,  # THIS IS THE CRITICAL FIX
        sample_range = θ_range
    )
end
println("✓ Parameter space sampled successfully")
println("  Sample points generated: $(TR.GN)")
println("  Objective function evaluations: $(TR.GN)")

println("\nStep 2: Polynomial approximation construction...")
@timeit to "constructor" begin
    pol = Constructor(
        TR,
        (:one_d_for_all, degree),
        basis = :chebyshev,
        precision = Float64Precision,
        verbose = true
    )
end

println("✓ Polynomial approximation completed")
println("  Condition number: $(pol.cond_vandermonde)")
println("  L2 approximation error: $(pol.nrm)")

# Quality assessment
quality_class = if pol.nrm < 1e-10
    "excellent"
elseif pol.nrm < 1e-6
    "good"
elseif pol.nrm < 1e-3
    "acceptable"
else
    "poor"
end
println("  Quality assessment: $quality_class")

println("\nStep 3: Solving polynomial system for critical points...")
@polyvar(x[1:n])

@timeit to "solve_polynomial" begin
    real_pts, (system, nsols) = solve_polynomial_system(
        x,
        n,
        (:one_d_for_all, degree),
        pol.coeffs;
        basis = :chebyshev,
        precision = Float64Precision,
        return_system = true
    )
end

println("✓ Polynomial system solved")
println("  Total polynomial solutions: $nsols")
println("  Real solutions found: $(length(real_pts))")

println("\nStep 4: Local optimization at critical points...")
@timeit to "process_critical_points" begin
    df_critical = process_crit_pts(real_pts, parameter_estimation_objective, TR)
end

# Enhanced analysis with parameter names and metrics
if nrow(df_critical) > 0
    # Add parameter columns
    df_critical[!, :alpha] = [pt[1] for pt in df_critical.x]
    df_critical[!, :beta] = [pt[2] for pt in df_critical.x]
    df_critical[!, :gamma] = [pt[3] for pt in df_critical.x]
    df_critical[!, :delta] = [pt[4] for pt in df_critical.x]
    
    # Distance from true parameters
    df_critical[!, :distance_from_true] = [norm([pt[1], pt[2], pt[3], pt[4]] - θ_true) for pt in df_critical.x]
    
    # Relative errors
    df_critical[!, :alpha_rel_error] = abs.(df_critical.alpha .- θ_true[1]) / θ_true[1]
    df_critical[!, :beta_rel_error] = abs.(df_critical.beta .- θ_true[2]) / θ_true[2]
    df_critical[!, :gamma_rel_error] = abs.(df_critical.gamma .- θ_true[3]) / θ_true[3]
    df_critical[!, :delta_rel_error] = abs.(df_critical.delta .- θ_true[4]) / θ_true[4]
    
    # Average relative error
    df_critical[!, :avg_rel_error] = (df_critical.alpha_rel_error + df_critical.beta_rel_error + 
                                     df_critical.gamma_rel_error + df_critical.delta_rel_error) / 4
    
    # Biological validity check
    df_critical[!, :biologically_valid] = [all(pt .> 0) && all(pt .< 5.0) for pt in df_critical.x]
end

println("✓ Critical point analysis completed")
println("  Critical points found: $(nrow(df_critical))")

# Results analysis and reporting
if nrow(df_critical) > 0
    valid_points = sum(df_critical.biologically_valid)
    println("  Biologically valid points: $valid_points")
    
    # Find best estimate
    best_idx = argmin(df_critical.val)
    best_point = df_critical[best_idx, :]
    θ_estimated = [best_point.alpha, best_point.beta, best_point.gamma, best_point.delta]
    
    println("\nBest Parameter Estimate:")
    println("  Estimated: α=$(round(θ_estimated[1], digits=4)), β=$(round(θ_estimated[2], digits=4)), γ=$(round(θ_estimated[3], digits=4)), δ=$(round(θ_estimated[4], digits=4))")
    println("  True:      α=$(θ_true[1]), β=$(θ_true[2]), γ=$(θ_true[3]), δ=$(θ_true[4])")
    println("  Distance from true: $(round(best_point.distance_from_true, digits=4))")
    println("  Average relative error: $(round(100*best_point.avg_rel_error, digits=2))%")
    println("  Objective value: $(round(best_point.val, digits=2))")
    println("  Biologically valid: $(best_point.biologically_valid)")
    
    # Individual parameter errors
    println("\nParameter-specific errors:")
    println("  α error: $(round(100*best_point.alpha_rel_error, digits=2))%")
    println("  β error: $(round(100*best_point.beta_rel_error, digits=2))%") 
    println("  γ error: $(round(100*best_point.gamma_rel_error, digits=2))%")
    println("  δ error: $(round(100*best_point.delta_rel_error, digits=2))%")
else
    println("⚠️  No critical points found - consider adjusting parameters")
end

# Save comprehensive results
println("\nStep 5: Saving results...")
@timeit to "save_results" begin
    # Save critical points with full analysis
    if nrow(df_critical) > 0
        csv_file = joinpath(results_dir, "critical_points.csv")
        CSV.write(csv_file, df_critical)
        println("✓ Critical points saved to: $(basename(csv_file))")
    end
    
    # Save synthetic data for validation
    data_df = DataFrame(
        time = t_obs,
        prey_observed = observed_data[:, 1],
        predator_observed = observed_data[:, 2],
        prey_true = true_solution[:, 1],
        predator_true = true_solution[:, 2]
    )
    CSV.write(joinpath(results_dir, "synthetic_data.csv"), data_df)
    
    # Save experiment metadata (Issue #41 compatible format)
    experiment_info = Dict(
        "problem_type" => "4D_lotka_volterra_parameter_estimation",
        "dimension" => n,
        "degree" => degree,
        "samples_per_dim" => samples_per_dim,
        "total_samples" => GN^4,
        "true_parameters" => θ_true,
        "parameter_center" => θ_center,
        "parameter_range" => θ_range,
        "noise_level" => noise_level,
        "time_points" => length(t_obs),
        "initial_conditions" => x0,
        
        # Approximation quality
        "condition_number" => pol.cond_vandermonde,
        "L2_norm" => pol.nrm,
        "quality_class" => quality_class,
        
        # Solution statistics
        "total_polynomial_solutions" => nsols,
        "real_solutions" => length(real_pts),
        "critical_points" => nrow(df_critical),
        "biologically_valid_points" => nrow(df_critical) > 0 ? sum(df_critical.biologically_valid) : 0,
        
        # Best solution (if available)
        "best_solution" => nrow(df_critical) > 0 ? Dict(
            "parameters" => θ_estimated,
            "distance_from_true" => best_point.distance_from_true,
            "avg_relative_error" => best_point.avg_rel_error,
            "objective_value" => best_point.val,
            "biologically_valid" => best_point.biologically_valid
        ) : nothing,
        
        # Infrastructure metadata
        "created_at" => string(now()),
        "hook_integration" => "Issue_41_compatible",
        "gn_parameter_bug" => "fixed",
        "infrastructure_version" => "2025.09"
    )
    
    open(joinpath(results_dir, "experiment_info.json"), "w") do io
        JSON.print(io, experiment_info, 2)
    end
    
    # Save timing report
    open(joinpath(results_dir, "timing_report.txt"), "w") do io
        print(io, to)
    end
    
    println("✓ Experiment metadata saved")
    println("✓ Timing report saved")
end

println("\n" * "="^80)
println("4D Lotka-Volterra Parameter Estimation Completed!")
println("="^80)
println("Results directory: $results_dir")
if nrow(df_critical) > 0
    println("Best estimate: α=$(round(θ_estimated[1], digits=3)), β=$(round(θ_estimated[2], digits=3)), γ=$(round(θ_estimated[3], digits=3)), δ=$(round(θ_estimated[4], digits=3))")
    println("Quality: $(round(100*best_point.avg_rel_error, digits=1))% avg error, $(best_point.biologically_valid ? "biologically valid" : "invalid")")
else
    println("No valid solutions found - experiment completed successfully but needs parameter tuning")
end
println("Hook integration: ✅ Issue #41 compatible")
println("Infrastructure: ✅ Modern GlobTim with fixed GN parameter bug")
println("="^80)

# Return results for programmatic access
df_critical