#!/usr/bin/env julia
# Lotka-Volterra 4D Parameter Estimation Experiment
# This script estimates parameters (α, β, γ, δ) of the Lotka-Volterra system using GlobTim

using Pkg
Pkg.activate(get(ENV, "JULIA_PROJECT", "/home/scholten/globtim"))  # Activate main globtim project

using Globtim
using DynamicPolynomials
using DataFrames
using CSV  # This activates the GlobtimDataExt extension
using JSON
using TimerOutputs
using StaticArrays
using LinearAlgebra
using Statistics
using Dates

# Get parameters from environment or use defaults
samples_per_dim = parse(Int, get(ENV, "SAMPLES_PER_DIM", "8"))
degree = parse(Int, get(ENV, "DEGREE", "10"))
results_dir = length(ARGS) > 0 ? ARGS[1] : joinpath(@__DIR__, "..", "outputs", "lotka_volterra_4d_$(Dates.format(now(), "yyyymmdd_HHMMSS"))")

mkpath(results_dir)

# Timer for performance tracking
to = TimerOutput()

println("\n" * "="^80)
println("Lotka-Volterra 4D Parameter Estimation Experiment")
println("="^80)
println("Configuration:")
println("  Parameter space dimension: 4")
println("  Polynomial degree: $degree")
println("  Samples per parameter: $samples_per_dim")
println("  Total parameter combinations: $(samples_per_dim^4)")
println("  Results directory: $results_dir")
println("="^80)

# Lotka-Volterra ODE system: dx/dt = αx - βxy, dy/dt = γxy - δy
# We want to estimate parameters θ = [α, β, γ, δ] from synthetic data

# True parameter values (what we want to recover)
θ_true = [1.5, 1.0, 0.75, 1.25]  # [α, β, γ, δ]
println("True parameters to recover: α=$(θ_true[1]), β=$(θ_true[2]), γ=$(θ_true[3]), δ=$(θ_true[4])")

# Time points for ODE integration
t_obs = collect(0:0.2:5.0)  # 26 time points
x0 = [10.0, 5.0]  # Initial conditions [prey, predator]

println("ODE integration setup:")
println("  Time span: $(t_obs[1]) to $(t_obs[end]) ($(length(t_obs)) points)")
println("  Initial conditions: x0 = $x0")

# Generate synthetic "observed" data using true parameters
@timeit to "generate_synthetic_data" begin
    # Simple Euler integration for Lotka-Volterra
    function lotka_volterra_solution(θ, x0, t_obs)
        α, β, γ, δ = θ
        dt = t_obs[2] - t_obs[1]
        sol = zeros(length(t_obs), 2)
        sol[1, :] = x0
        
        for i in 2:length(t_obs)
            x, y = sol[i-1, :]
            dx_dt = α*x - β*x*y
            dy_dt = γ*x*y - δ*y
            sol[i, :] = [x + dt*dx_dt, y + dt*dy_dt]
        end
        return sol
    end
    
    # Generate true trajectory
    true_solution = lotka_volterra_solution(θ_true, x0, t_obs)
    
    # Add noise to create synthetic observations
    noise_level = 0.1
    observed_data = true_solution + noise_level * randn(size(true_solution))
end

println("✓ Synthetic data generated with $(size(observed_data, 1)) time points and $(size(observed_data, 2)) variables")

# Parameter estimation objective function
function parameter_estimation_objective(θ::AbstractVector)
    # Ensure parameters are positive (biological constraint)
    if any(θ .<= 0)
        return 1e6  # Large penalty for invalid parameters
    end
    
    try
        # Solve ODE with candidate parameters
        predicted_solution = lotka_volterra_solution(θ, x0, t_obs)
        
        # Compute residual (sum of squared errors)
        residual = sum((predicted_solution - observed_data).^2)
        
        return residual
    catch
        # Return large value if ODE integration fails
        return 1e6
    end
end

# Define parameter space for sampling
# Reasonable biological parameter ranges around true values
θ_center = [1.0, 1.0, 1.0, 1.0]  # Central point for sampling
θ_range = 0.8  # ±80% around center
n = 4  # Parameter space dimension
GN = samples_per_dim^n

println("\nStep 1: Sampling parameter space and evaluating objective function...")
@timeit to "test_input" begin
    TR = test_input(
        parameter_estimation_objective,
        dim = n,
        center = θ_center,
        GN = GN,
        sample_range = θ_range
    )
end
println("✓ Generated $(TR.GN) parameter samples")
println("  Objective function ready for polynomial approximation")

println("\nStep 2: Constructing polynomial approximation of objective function...")
@timeit to "constructor" begin
    pol = Constructor(
        TR,
        (:one_d_for_all, degree),
        basis = :chebyshev,
        precision = Float64Precision,
        verbose = true
    )
end
println("✓ Polynomial approximation complete")
println("  Condition number: $(pol.cond_vandermonde)")
println("  L2 norm (approximation error): $(pol.nrm)")

# Save approximation info
approx_info = Dict(
    "problem" => "Lotka-Volterra parameter estimation",
    "parameter_dimension" => n,
    "polynomial_degree" => degree,
    "samples_per_parameter" => samples_per_dim,
    "total_samples" => GN,
    "condition_number" => pol.cond_vandermonde,
    "L2_norm" => pol.nrm,
    "basis" => "chebyshev",
    "parameter_center" => θ_center,
    "parameter_range" => θ_range,
    "true_parameters" => θ_true,
    "objective_range" => [minimum(TR.objective), maximum(TR.objective)]
)

open(joinpath(results_dir, "approximation_info.json"), "w") do io
    JSON.print(io, approx_info, 2)
end

println("\nStep 3: Finding critical points of polynomial approximation...")
@polyvar(x[1:n])

@timeit to "solve_polynomial" begin
    real_pts, (system, nsols) = solve_polynomial_system(
        x,
        n,
        (:one_d_for_all, degree),
        pol.coeffs;
        basis = :chebyshev,
        return_system = true
    )
end
println("✓ Polynomial system solved")
println("  Total solutions: $nsols")
println("  Real solutions: $(length(real_pts))")

println("\nStep 4: Local optimization at critical points...")
@timeit to "process_critical_points" begin
    df_critical = process_crit_pts(real_pts, parameter_estimation_objective, TR)
end

# Add parameter estimation specific information
if nrow(df_critical) > 0
    # Convert critical points back to parameter space
    df_critical[!, :alpha] = [pt[1] for pt in df_critical.x]
    df_critical[!, :beta] = [pt[2] for pt in df_critical.x]  
    df_critical[!, :gamma] = [pt[3] for pt in df_critical.x]
    df_critical[!, :delta] = [pt[4] for pt in df_critical.x]
    
    # Add distance from true parameters
    df_critical[!, :distance_from_true] = [norm([pt[1], pt[2], pt[3], pt[4]] - θ_true) for pt in df_critical.x]
    
    # Add relative error for each parameter
    df_critical[!, :alpha_rel_error] = abs.(df_critical.alpha .- θ_true[1]) / θ_true[1]
    df_critical[!, :beta_rel_error] = abs.(df_critical.beta .- θ_true[2]) / θ_true[2]
    df_critical[!, :gamma_rel_error] = abs.(df_critical.gamma .- θ_true[3]) / θ_true[3]
    df_critical[!, :delta_rel_error] = abs.(df_critical.delta .- θ_true[4]) / θ_true[4]
end

println("✓ Critical points processed")
println("  Number of critical points: $(nrow(df_critical))")

# Analysis and reporting
if nrow(df_critical) > 0
    println("\nParameter Estimation Results:")
    println("  Best objective value: $(minimum(df_critical.val))")
    println("  Worst objective value: $(maximum(df_critical.val))")
    
    # Find best parameter estimate
    best_idx = argmin(df_critical.val)
    best_point = df_critical[best_idx, :]
    θ_estimated = [best_point.alpha, best_point.beta, best_point.gamma, best_point.delta]
    
    println("\nBest parameter estimate:")
    println("  Estimated: α=$(round(θ_estimated[1], digits=4)), β=$(round(θ_estimated[2], digits=4)), γ=$(round(θ_estimated[3], digits=4)), δ=$(round(θ_estimated[4], digits=4))")
    println("  True:      α=$(θ_true[1]), β=$(θ_true[2]), γ=$(θ_true[3]), δ=$(θ_true[4])")
    println("  Distance from true: $(round(best_point.distance_from_true, digits=4))")
    println("  Objective value: $(round(best_point.val, digits=4))")
    println("  Gradient norm: $(round(best_point.grad_norm, digits=6))")
    
    # Parameter-specific errors
    println("\nParameter estimation errors:")
    println("  α error: $(round(100*best_point.alpha_rel_error, digits=2))%")
    println("  β error: $(round(100*best_point.beta_rel_error, digits=2))%") 
    println("  γ error: $(round(100*best_point.gamma_rel_error, digits=2))%")
    println("  δ error: $(round(100*best_point.delta_rel_error, digits=2))%")
end

# Save results
csv_file = joinpath(results_dir, "parameter_estimates.csv")
CSV.write(csv_file, df_critical)
println("\n✓ Parameter estimates saved to: $csv_file")

# Save timing report
timing_file = joinpath(results_dir, "timing_report.txt")
open(timing_file, "w") do io
    print(io, to)
end
println("✓ Timing report saved to: $timing_file")

# Create comprehensive summary report
summary_file = joinpath(results_dir, "summary.txt")
open(summary_file, "w") do io
    println(io, "Lotka-Volterra 4D Parameter Estimation Summary")
    println(io, "="^60)
    println(io, "Generated: $(Dates.now())")
    println(io, "")
    println(io, "Problem Setup:")
    println(io, "  True parameters: α=$(θ_true[1]), β=$(θ_true[2]), γ=$(θ_true[3]), δ=$(θ_true[4])")
    println(io, "  Parameter space center: $θ_center")
    println(io, "  Parameter space range: ±$(θ_range)")
    println(io, "  Time points: $(length(t_obs)) from $(t_obs[1]) to $(t_obs[end])")
    println(io, "  Initial conditions: $x0")
    println(io, "")
    println(io, "Computational Configuration:")
    println(io, "  Parameter space dimension: $n")
    println(io, "  Polynomial degree: $degree")
    println(io, "  Samples per parameter: $samples_per_dim")
    println(io, "  Total parameter samples: $GN")
    println(io, "")
    println(io, "Approximation Quality:")
    println(io, "  Condition number: $(pol.cond_vandermonde)")
    println(io, "  L2 norm (error): $(pol.nrm)")
    println(io, "")
    println(io, "Results:")
    println(io, "  Total polynomial solutions: $nsols")
    println(io, "  Real solutions found: $(length(real_pts))")
    println(io, "  Critical points after optimization: $(nrow(df_critical))")
    
    if nrow(df_critical) > 0
        best_idx = argmin(df_critical.val)
        best_point = df_critical[best_idx, :]
        θ_estimated = [best_point.alpha, best_point.beta, best_point.gamma, best_point.delta]
        
        println(io, "")
        println(io, "Best Parameter Estimate:")
        println(io, "  Estimated: α=$(round(θ_estimated[1], digits=4)), β=$(round(θ_estimated[2], digits=4)), γ=$(round(θ_estimated[3], digits=4)), δ=$(round(θ_estimated[4], digits=4))")
        println(io, "  True:      α=$(θ_true[1]), β=$(θ_true[2]), γ=$(θ_true[3]), δ=$(θ_true[4])")
        println(io, "  Distance from true: $(round(best_point.distance_from_true, digits=4))")
        println(io, "  Objective value: $(round(best_point.val, digits=4))")
        println(io, "  Relative errors: α=$(round(100*best_point.alpha_rel_error, digits=2))%, β=$(round(100*best_point.beta_rel_error, digits=2))%, γ=$(round(100*best_point.gamma_rel_error, digits=2))%, δ=$(round(100*best_point.delta_rel_error, digits=2))%")
    end
    
    println(io, "")
    println(io, "Timing Breakdown:")
    println(io, to)
end
println("✓ Summary saved to: $summary_file")

# Save results as JSON for programmatic access
json_file = joinpath(results_dir, "parameter_estimates.json")
if nrow(df_critical) > 0
    open(json_file, "w") do io
        dict_array = [Dict(names(df_critical) .=> values(row)) for row in eachrow(df_critical)]
        JSON.print(io, dict_array, 2)
    end
    println("✓ Parameter estimates JSON saved to: $json_file")
end

# Save synthetic data for validation
data_file = joinpath(results_dir, "synthetic_data.csv")
data_df = DataFrame(
    time = t_obs,
    prey_observed = observed_data[:, 1],
    predator_observed = observed_data[:, 2],
    prey_true = true_solution[:, 1],
    predator_true = true_solution[:, 2]
)
CSV.write(data_file, data_df)
println("✓ Synthetic data saved to: $data_file")

println("\n" * "="^80)
println("Lotka-Volterra Parameter Estimation Experiment Completed!")
println("Results saved in: $results_dir")
if nrow(df_critical) > 0
    best_idx = argmin(df_critical.val)
    best_point = df_critical[best_idx, :]
    θ_estimated = [best_point.alpha, best_point.beta, best_point.gamma, best_point.delta]
    println("Best estimate: α=$(round(θ_estimated[1], digits=3)), β=$(round(θ_estimated[2], digits=3)), γ=$(round(θ_estimated[3], digits=3)), δ=$(round(θ_estimated[4], digits=3))")
    println("Distance from true: $(round(best_point.distance_from_true, digits=3))")
end
println("="^80)

# Return the DataFrame for potential further processing
df_critical