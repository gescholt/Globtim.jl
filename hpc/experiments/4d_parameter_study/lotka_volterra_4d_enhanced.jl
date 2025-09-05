#!/usr/bin/env julia
"""
Enhanced 4D Lotka-Volterra Parameter Estimation Experiment

This script provides systematic parameter estimation with comprehensive tracking,
sparsification, log transformation, and standardized output format.
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

# Load experiment configuration system
include("experiment_config.jl")

"""
    enhanced_parameter_estimation_objective(config::ExperimentConfig, observed_data, t_obs, x0)

Create parameter estimation objective function with optional log transformation and sparsification.
"""
function enhanced_parameter_estimation_objective(config::ExperimentConfig, observed_data, t_obs, x0)
    function objective(θ::AbstractVector)
        # Ensure parameters are within domain bounds
        if any(θ .< config.domain_bounds[1]) || any(θ .> config.domain_bounds[2])
            return 1e6  # Large penalty for out-of-bounds parameters
        end
        
        try
            # Solve ODE with candidate parameters
            predicted_solution = lotka_volterra_solution(θ, x0, t_obs)
            
            # Compute residual (sum of squared errors)
            residual = sum((predicted_solution - observed_data).^2)
            
            # Apply log transformation if enabled
            if config.log_objective
                return log(residual + config.log_offset)
            else
                return residual
            end
            
        catch
            # Return large value if ODE integration fails
            return config.log_objective ? log(1e6 + config.log_offset) : 1e6
        end
    end
    
    return objective
end

"""
    apply_sparsification!(pol, config::ExperimentConfig)

Apply coefficient sparsification to polynomial approximation.
"""
function apply_sparsification!(pol, config::ExperimentConfig)
    if !config.sparsify_enabled
        return pol
    end
    
    # Find coefficients below threshold
    abs_coeffs = abs.(pol.coeffs)
    small_indices = abs_coeffs .< config.sparsify_threshold
    
    # Set small coefficients to zero
    pol.coeffs[small_indices] .= 0.0
    
    # Count sparsification
    n_removed = sum(small_indices)
    n_total = length(pol.coeffs)
    sparsification_ratio = n_removed / n_total
    
    println("✓ Sparsification applied: $(n_removed)/$(n_total) coefficients removed ($(round(100*sparsification_ratio, digits=1))%)")
    
    return pol, n_removed, sparsification_ratio
end

"""
    lotka_volterra_solution(θ, x0, t_obs)

Solve Lotka-Volterra ODE system using simple Euler integration.
"""
function lotka_volterra_solution(θ, x0, t_obs)
    α, β, γ, δ = θ
    dt = length(t_obs) > 1 ? t_obs[2] - t_obs[1] : 0.1
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

"""
    run_enhanced_experiment(config::ExperimentConfig; results_dir::String="")

Run enhanced 4D parameter estimation experiment with full configuration tracking.
"""
function run_enhanced_experiment(config::ExperimentConfig; results_dir::String="")
    
    # Create results directory
    if isempty(results_dir)
        results_dir = joinpath(@__DIR__, "..", "..", "node_experiments", "outputs", "4d_study_$(config.experiment_id)")
    end
    mkpath(results_dir)
    
    # Timer for performance tracking
    to = TimerOutput()
    
    println("\n" * "="^80)
    println("Enhanced 4D Lotka-Volterra Parameter Estimation")
    println("="^80)
    println("Experiment ID: $(config.experiment_id)")
    println("Description: $(config.description)")
    println("Created: $(config.created_at)")
    println("="^80)
    
    # Print configuration
    println("Configuration:")
    println("  Parameter space: 4D")
    println("  Polynomial degree: $(config.degree)")
    println("  Samples per parameter: $(config.GN)")
    println("  Total parameter combinations: $(config.GN^4)")
    println("  Basis: $(config.basis)")
    println("  Sample range: ±$(config.sample_range) around $(config.center)")
    println("  Domain bounds: [$(config.domain_bounds[1]), $(config.domain_bounds[2])]")
    println("  Sparsification: $(config.sparsify_enabled ? "enabled (threshold=$(config.sparsify_threshold))" : "disabled")")
    println("  Log objective: $(config.log_objective ? "enabled (offset=$(config.log_offset))" : "disabled")")
    println("  Noise level: $(config.noise_level)")
    println("  Results directory: $results_dir")
    println("="^80)
    
    # Generate time points
    t_obs = collect(range(config.time_span[1], config.time_span[2], length=config.time_steps))
    println("ODE integration: $(length(t_obs)) points from $(t_obs[1]) to $(t_obs[end])")
    println("Initial conditions: $(config.initial_conditions)")
    println("True parameters: α=$(config.true_params[1]), β=$(config.true_params[2]), γ=$(config.true_params[3]), δ=$(config.true_params[4])")
    
    # Generate synthetic "observed" data using true parameters
    @timeit to "generate_synthetic_data" begin
        true_solution = lotka_volterra_solution(config.true_params, config.initial_conditions, t_obs)
        observed_data = true_solution + config.noise_level * randn(size(true_solution))
    end
    println("✓ Synthetic data generated with $(size(observed_data, 1)) time points and $(size(observed_data, 2)) variables")
    
    # Create enhanced objective function
    objective_func = enhanced_parameter_estimation_objective(config, observed_data, t_obs, config.initial_conditions)
    
    # Parameter space sampling
    println("\nStep 1: Sampling parameter space and evaluating objective function...")
    @timeit to "test_input" begin
        TR = test_input(
            objective_func,
            dim = 4,
            center = config.center,
            GN = config.GN,  # Samples per dimension (NOT total samples - fixed GN parameter bug)
            sample_range = config.sample_range
        )
    end
    println("✓ Generated $(TR.GN) parameter samples")
    
    # Construct polynomial approximation
    println("\nStep 2: Constructing polynomial approximation...")
    @timeit to "constructor" begin
        pol = Constructor(
            TR,
            (:one_d_for_all, config.degree),
            basis = config.basis,
            precision = Float64Precision,
            verbose = true
        )
    end
    println("✓ Polynomial approximation complete")
    println("  Condition number: $(pol.cond_vandermonde)")
    println("  L2 norm (approximation error): $(pol.nrm)")
    
    # Apply sparsification if enabled
    sparsification_info = Dict{String, Any}()
    @timeit to "sparsification" begin
        if config.sparsify_enabled
            pol, n_removed, sparse_ratio = apply_sparsification!(pol, config)
            sparsification_info = Dict(
                "enabled" => true,
                "threshold" => config.sparsify_threshold,
                "coefficients_removed" => n_removed,
                "total_coefficients" => length(pol.coeffs),
                "sparsification_ratio" => sparse_ratio
            )
        else
            sparsification_info = Dict("enabled" => false)
        end
    end
    
    # Solve polynomial system
    println("\nStep 3: Finding critical points...")
    @polyvar(x[1:4])
    
    @timeit to "solve_polynomial" begin
        real_pts, (system, nsols) = solve_polynomial_system(
            x,
            4,
            (:one_d_for_all, config.degree),
            pol.coeffs;
            basis = config.basis,
            precision = Float64Precision,
            return_system = true
        )
    end
    println("✓ Polynomial system solved")
    println("  Total solutions: $nsols")
    println("  Real solutions: $(length(real_pts))")
    
    # Local optimization at critical points
    println("\nStep 4: Local optimization...")
    @timeit to "process_critical_points" begin
        df_critical = process_crit_pts(real_pts, objective_func, TR)
    end
    
    # Enhanced analysis with parameter-specific metrics
    if nrow(df_critical) > 0
        # Add parameter names
        df_critical[!, :alpha] = [pt[1] for pt in df_critical.x]
        df_critical[!, :beta] = [pt[2] for pt in df_critical.x]
        df_critical[!, :gamma] = [pt[3] for pt in df_critical.x]  
        df_critical[!, :delta] = [pt[4] for pt in df_critical.x]
        
        # Distance metrics
        df_critical[!, :distance_from_true] = [norm([pt[1], pt[2], pt[3], pt[4]] - config.true_params) for pt in df_critical.x]
        
        # Relative errors for each parameter
        df_critical[!, :alpha_rel_error] = abs.(df_critical.alpha .- config.true_params[1]) / config.true_params[1]
        df_critical[!, :beta_rel_error] = abs.(df_critical.beta .- config.true_params[2]) / config.true_params[2]
        df_critical[!, :gamma_rel_error] = abs.(df_critical.gamma .- config.true_params[3]) / config.true_params[3]
        df_critical[!, :delta_rel_error] = abs.(df_critical.delta .- config.true_params[4]) / config.true_params[4]
        
        # Average relative error
        df_critical[!, :avg_rel_error] = (df_critical.alpha_rel_error + df_critical.beta_rel_error + 
                                        df_critical.gamma_rel_error + df_critical.delta_rel_error) / 4
        
        # Within bounds check
        df_critical[!, :within_bounds] = [all(pt .>= config.domain_bounds[1]) && all(pt .<= config.domain_bounds[2]) for pt in df_critical.x]
    end
    
    println("✓ Critical points processed: $(nrow(df_critical)) points")
    
    # Create comprehensive results summary
    experiment_results = Dict(
        # Experiment metadata
        "experiment_id" => config.experiment_id,
        "description" => config.description,
        "created_at" => string(config.created_at),
        "completed_at" => string(now()),
        
        # Configuration (full config serialized)
        "configuration" => config_to_dict(config),
        
        # Approximation quality metrics
        "approximation_quality" => Dict(
            "condition_number" => pol.cond_vandermonde,
            "L2_norm" => pol.nrm,
            "total_samples" => TR.GN,
            "polynomial_degree" => config.degree,
            "basis" => string(config.basis)
        ),
        
        # Sparsification results
        "sparsification" => sparsification_info,
        
        # Solution statistics
        "solution_statistics" => Dict(
            "total_polynomial_solutions" => nsols,
            "real_solutions" => length(real_pts),
            "critical_points_found" => nrow(df_critical),
            "solutions_within_bounds" => nrow(df_critical) > 0 ? sum(df_critical.within_bounds) : 0
        ),
        
        # Performance timing
        "timing" => Dict(string(timer.name) => timer.time for timer in TimerOutputs.flatten(to).children)
    )
    
    # Add best solution metrics if available
    if nrow(df_critical) > 0
        best_idx = argmin(df_critical.val)
        best_point = df_critical[best_idx, :]
        θ_estimated = [best_point.alpha, best_point.beta, best_point.gamma, best_point.delta]
        
        experiment_results["best_solution"] = Dict(
            "estimated_parameters" => θ_estimated,
            "true_parameters" => config.true_params,
            "distance_from_true" => best_point.distance_from_true,
            "objective_value" => best_point.val,
            "gradient_norm" => best_point.grad_norm,
            "average_relative_error" => best_point.avg_rel_error,
            "individual_relative_errors" => [
                best_point.alpha_rel_error,
                best_point.beta_rel_error, 
                best_point.gamma_rel_error,
                best_point.delta_rel_error
            ],
            "within_bounds" => best_point.within_bounds
        )
        
        println("\nBest Parameter Estimate:")
        println("  Estimated: α=$(round(θ_estimated[1], digits=4)), β=$(round(θ_estimated[2], digits=4)), γ=$(round(θ_estimated[3], digits=4)), δ=$(round(θ_estimated[4], digits=4))")
        println("  True:      α=$(config.true_params[1]), β=$(config.true_params[2]), γ=$(config.true_params[3]), δ=$(config.true_params[4])")
        println("  Distance: $(round(best_point.distance_from_true, digits=4))")
        println("  Avg rel error: $(round(100*best_point.avg_rel_error, digits=2))%")
    end
    
    # Save all results
    @timeit to "save_results" begin
        # Save comprehensive experiment results
        open(joinpath(results_dir, "experiment_results.json"), "w") do io
            JSON.print(io, experiment_results, 2)
        end
        
        # Save critical points DataFrame
        if nrow(df_critical) > 0
            CSV.write(joinpath(results_dir, "parameter_estimates.csv"), df_critical)
        end
        
        # Save synthetic data
        data_df = DataFrame(
            time = t_obs,
            prey_observed = observed_data[:, 1],
            predator_observed = observed_data[:, 2],
            prey_true = true_solution[:, 1],
            predator_true = true_solution[:, 2]
        )
        CSV.write(joinpath(results_dir, "synthetic_data.csv"), data_df)
        
        # Save timing report
        open(joinpath(results_dir, "timing_report.txt"), "w") do io
            print(io, to)
        end
        
        # Save configuration for reproducibility
        open(joinpath(results_dir, "config.json"), "w") do io
            JSON.print(io, config_to_dict(config), 2)
        end
    end
    
    println("\n" * "="^80)
    println("Enhanced Experiment Completed!")
    println("Experiment ID: $(config.experiment_id)")
    println("Results saved in: $results_dir")
    println("="^80)
    
    return experiment_results, df_critical
end

# Command-line interface
if length(ARGS) >= 1
    config_file = ARGS[1]
    
    if isfile(config_file)
        # Load configuration from JSON file
        config_dict = JSON.parsefile(config_file)
        config = dict_to_config(config_dict)
        println("Loaded configuration from: $config_file")
    else
        println("Configuration file not found: $config_file")
        println("Using default configuration...")
        config = STANDARD_BASE_CONFIG
    end
    
    # Override with environment variables if present
    config = ExperimentConfig(
        GN = parse(Int, get(ENV, "GN", string(config.GN))),
        degree = parse(Int, get(ENV, "DEGREE", string(config.degree))),
        sample_range = parse(Float64, get(ENV, "SAMPLE_RANGE", string(config.sample_range))),
        sparsify_enabled = parse(Bool, get(ENV, "SPARSIFY", string(config.sparsify_enabled))),
        log_objective = parse(Bool, get(ENV, "LOG_OBJECTIVE", string(config.log_objective))),
        # Keep other parameters from config
        center = config.center,
        basis = config.basis,
        sparsify_threshold = config.sparsify_threshold,
        log_offset = config.log_offset,
        domain_bounds = config.domain_bounds,
        true_params = config.true_params,
        noise_level = config.noise_level,
        time_span = config.time_span,
        time_steps = config.time_steps,
        initial_conditions = config.initial_conditions,
        experiment_id = get(ENV, "EXPERIMENT_ID", config.experiment_id),
        description = config.description
    )
    
    # Run experiment
    results_dir = length(ARGS) >= 2 ? ARGS[2] : ""
    experiment_results, df_critical = run_enhanced_experiment(config; results_dir=results_dir)
    
    # Return DataFrame for potential REPL usage
    df_critical
else
    println("Usage: julia lotka_volterra_4d_enhanced.jl [config_file.json] [results_dir]")
    println("   Or set environment variables: GN, DEGREE, SAMPLE_RANGE, SPARSIFY, LOG_OBJECTIVE, EXPERIMENT_ID")
    println("\nExample configurations available:")
    println("  - STANDARD_BASE_CONFIG")
    println("  - HIGH_PRECISION_CONFIG")
    println("  - FAST_TEST_CONFIG")
end