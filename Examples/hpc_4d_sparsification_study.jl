#!/usr/bin/env julia
"""
4D Lotka-Volterra Sparsification Accuracy Comparison Study
=========================================================

Systematic comparison of root computation accuracy with and without coefficient sparsification.
This study addresses the critical question: How does sparsification affect the accuracy of 
critical point finding in polynomial parameter estimation?

Research Design:
- Paired experiments (identical conditions ± sparsification)
- Multiple sparsification thresholds
- Comprehensive accuracy metrics
- Statistical analysis of results

Usage:
------
./Examples/hpc_4d_sparsification_study.jl [output_dir]

Environment Variables:
- SAMPLES_PER_DIM: Sample density (default: 8)
- DEGREE: Polynomial degree (default: 10)  
- STUDY_TYPE: "quick", "standard", "comprehensive" (default: standard)

Author: GlobTim Team
Date: September 2025
Purpose: Sparsification impact analysis for Issue #41 validation
"""

using Pkg
Pkg.activate(get(ENV, "JULIA_PROJECT", "/home/scholten/globtim"))

using Globtim
using DynamicPolynomials
using DataFrames
using CSV
using JSON
using TimerOutputs
using Statistics
using LinearAlgebra
using Dates
using Printf

# Study configuration with user-specified parameters
const STUDY_TYPE = get(ENV, "STUDY_TYPE", "standard")
const BASE_SAMPLES_PER_DIM = parse(Int, get(ENV, "SAMPLES_PER_DIM", "12"))  # Updated to 12 as requested
const BASE_DEGREE = parse(Int, get(ENV, "DEGREE", "10"))

# Study parameters based on type - Updated with degree range [4, 6, 8, 10] and GN=12
const STUDY_CONFIG = Dict(
    "quick" => Dict(
        :configurations => [(GN=12, degree=4), (GN=12, degree=6)],
        :thresholds => [1e-6, 1e-4],
        :description => "Quick sparsification validation - 12 samples/dim, degrees 4-6"
    ),
    "standard" => Dict(
        :configurations => [(GN=12, degree=4), (GN=12, degree=6), (GN=12, degree=8), (GN=12, degree=10)],
        :thresholds => [1e-8, 1e-6, 1e-4, 1e-2],
        :description => "Standard sparsification accuracy study - 12 samples/dim, degrees 4-10"
    ),
    "comprehensive" => Dict(
        :configurations => [(GN=12, degree=4), (GN=12, degree=6), (GN=12, degree=8), (GN=12, degree=10)],
        :thresholds => [1e-10, 1e-8, 1e-6, 1e-4, 1e-2, 1e-1],
        :description => "Comprehensive sparsification analysis - 12 samples/dim, degrees 4-10, extended thresholds"
    )
)[STUDY_TYPE]

# Results directory
results_dir = length(ARGS) > 0 ? ARGS[1] : joinpath(dirname(@__DIR__), "results", "sparsification_study_$(Dates.format(now(), "yyyymmdd_HHMMSS"))")
mkpath(results_dir)

println("\n" * "="^90)
println("4D Lotka-Volterra Sparsification Accuracy Comparison Study")
println("="^90)
println("Study Type: $(STUDY_TYPE)")
println("Description: $(STUDY_CONFIG[:description])")
println("Configurations: $(length(STUDY_CONFIG[:configurations]))")
println("Sparsification thresholds: $(length(STUDY_CONFIG[:thresholds]))")
println("Total experiments: $((length(STUDY_CONFIG[:configurations]) * (length(STUDY_CONFIG[:thresholds]) + 1)))")
println("Results directory: $results_dir")
println("="^90)

# Fixed problem setup (consistent across all experiments)
const θ_true = [1.5, 1.0, 0.75, 1.25]  # True parameters
const θ_center = [1.0, 1.0, 1.0, 1.0]  # Parameter space center  
const θ_range = 0.8  # Parameter space range
const t_obs = collect(0:0.2:5.0)  # Time points
const x0 = [10.0, 5.0]  # Initial conditions
const noise_level = 0.1  # Noise level

# Generate synthetic data (same for all experiments)
println("Generating synthetic reference data...")
function lotka_volterra_solution(θ, x0, t_obs)
    α, β, γ, δ = θ
    dt = t_obs[2] - t_obs[1]
    sol = zeros(length(t_obs), 2)
    sol[1, :] = x0
    
    for i in 2:length(t_obs)
        x, y = sol[i-1, :]
        x = max(x, 0.0); y = max(y, 0.0)  # Biological constraints
        dx_dt = α*x - β*x*y
        dy_dt = γ*x*y - δ*y
        sol[i, :] = [x + dt*dx_dt, y + dt*dy_dt]
    end
    return sol
end

const true_solution = lotka_volterra_solution(θ_true, x0, t_obs)
const observed_data = true_solution + noise_level * randn(size(true_solution))

println("✓ Synthetic data generated: $(size(observed_data)) observations")

# Parameter estimation objective
function create_objective_function()
    function objective(θ::AbstractVector)
        if any(θ .<= 0) || any(θ .> 5.0)
            return 1e6
        end
        
        try
            predicted = lotka_volterra_solution(θ, x0, t_obs)
            if any(!isfinite.(predicted))
                return 1e6
            end
            return sum((predicted - observed_data).^2)
        catch
            return 1e6
        end
    end
    return objective
end

# Sparsification function
function apply_sparsification(pol, threshold)
    n_coeffs = length(pol.coeffs)
    abs_coeffs = abs.(pol.coeffs)
    small_indices = abs_coeffs .< threshold
    
    # Create sparsified copy
    sparse_coeffs = copy(pol.coeffs)
    sparse_coeffs[small_indices] .= 0.0
    
    n_removed = sum(small_indices)
    sparsification_ratio = n_removed / n_coeffs
    
    return sparse_coeffs, n_removed, sparsification_ratio
end

# Single experiment execution
function run_single_experiment(GN, degree, sparsification_threshold=nothing; experiment_id="")
    println("\n" * "-"^60)
    println("Experiment: GN=$GN, degree=$degree, sparse_thresh=$(sparsification_threshold)")
    println("-"^60)
    
    to = TimerOutput()
    
    # Parameter space sampling
    @timeit to "sampling" begin
        objective = create_objective_function()
        TR = test_input(
            objective,
            dim = 4,
            center = θ_center,
            GN = GN,  # Fixed GN parameter
            sample_range = θ_range
        )
    end
    println("✓ Parameter samples: $(TR.GN)")
    
    # Polynomial approximation
    @timeit to "approximation" begin
        pol = Constructor(
            TR,
            (:one_d_for_all, degree),
            basis = :chebyshev,
            precision = Float64Precision,
            verbose = false
        )
    end
    
    original_l2_norm = pol.nrm
    original_condition = pol.cond_vandermonde
    
    println("✓ Original approximation - L2: $(Printf.@sprintf("%.2e", original_l2_norm)), Condition: $(Printf.@sprintf("%.2e", original_condition))")
    
    # Apply sparsification if requested
    coeffs_to_use = pol.coeffs
    sparsification_info = Dict("enabled" => false)
    
    if sparsification_threshold !== nothing
        @timeit to "sparsification" begin
            sparse_coeffs, n_removed, sparse_ratio = apply_sparsification(pol, sparsification_threshold)
            coeffs_to_use = sparse_coeffs
            sparsification_info = Dict(
                "enabled" => true,
                "threshold" => sparsification_threshold,
                "coefficients_removed" => n_removed,
                "total_coefficients" => length(pol.coeffs),
                "sparsification_ratio" => sparse_ratio
            )
        end
        println("✓ Sparsification: $(n_removed)/$(length(pol.coeffs)) coeffs removed ($(Printf.@sprintf("%.1f", 100*sparse_ratio))%)")
    end
    
    # Solve polynomial system
    @timeit to "root_finding" begin
        @polyvar(x[1:4])
        real_pts, (system, nsols) = solve_polynomial_system(
            x, 4, (:one_d_for_all, degree), coeffs_to_use;
            basis = :chebyshev, precision = Float64Precision, return_system = true
        )
    end
    println("✓ Root finding: $nsols total, $(length(real_pts)) real solutions")
    
    # Local optimization
    @timeit to "optimization" begin
        df_critical = process_crit_pts(real_pts, objective, TR)
    end
    
    # Enhanced analysis
    n_critical = nrow(df_critical)
    if n_critical > 0
        # Add parameter analysis
        df_critical[!, :alpha] = [pt[1] for pt in df_critical.x]
        df_critical[!, :beta] = [pt[2] for pt in df_critical.x]
        df_critical[!, :gamma] = [pt[3] for pt in df_critical.x]
        df_critical[!, :delta] = [pt[4] for pt in df_critical.x]
        
        # Distance metrics
        df_critical[!, :distance_from_true] = [norm([pt[1], pt[2], pt[3], pt[4]] - θ_true) for pt in df_critical.x]
        df_critical[!, :alpha_error] = abs.(df_critical.alpha .- θ_true[1])
        df_critical[!, :beta_error] = abs.(df_critical.beta .- θ_true[2])
        df_critical[!, :gamma_error] = abs.(df_critical.gamma .- θ_true[3])
        df_critical[!, :delta_error] = abs.(df_critical.delta .- θ_true[4])
        
        # Relative errors
        df_critical[!, :alpha_rel_error] = df_critical.alpha_error / θ_true[1]
        df_critical[!, :beta_rel_error] = df_critical.beta_error / θ_true[2]
        df_critical[!, :gamma_rel_error] = df_critical.gamma_error / θ_true[3]
        df_critical[!, :delta_rel_error] = df_critical.delta_error / θ_true[4]
        df_critical[!, :avg_rel_error] = (df_critical.alpha_rel_error + df_critical.beta_rel_error + 
                                         df_critical.gamma_rel_error + df_critical.delta_rel_error) / 4
        
        # Validity checks
        df_critical[!, :biologically_valid] = [all(pt .> 0) && all(pt .< 5.0) for pt in df_critical.x]
        
        # Best solution metrics
        best_idx = argmin(df_critical.val)
        best_point = df_critical[best_idx, :]
        best_distance = best_point.distance_from_true
        best_avg_error = best_point.avg_rel_error
        n_valid = sum(df_critical.biologically_valid)
        
        println("✓ Critical point analysis:")
        println("  Best distance from true: $(Printf.@sprintf("%.4f", best_distance))")
        println("  Best avg relative error: $(Printf.@sprintf("%.2f", 100*best_avg_error))%")
        println("  Biologically valid: $n_valid/$n_critical")
    else
        best_distance = Inf
        best_avg_error = Inf
        n_valid = 0
        println("⚠️  No critical points found")
    end
    
    # Compile experiment results
    experiment_results = Dict(
        "experiment_id" => experiment_id,
        "configuration" => Dict("GN" => GN, "degree" => degree),
        "sparsification" => sparsification_info,
        
        # Polynomial quality
        "approximation_quality" => Dict(
            "original_L2_norm" => original_l2_norm,
            "original_condition_number" => original_condition,
            "total_samples" => TR.GN
        ),
        
        # Solution statistics  
        "solution_statistics" => Dict(
            "total_polynomial_solutions" => nsols,
            "real_solutions" => length(real_pts),
            "critical_points_found" => n_critical,
            "biologically_valid_points" => n_valid
        ),
        
        # Accuracy metrics
        "accuracy_metrics" => Dict(
            "best_distance_from_true" => best_distance,
            "best_avg_relative_error" => best_avg_error,
            "valid_solution_fraction" => n_critical > 0 ? n_valid / n_critical : 0.0
        ),
        
        # Performance timing
        "timing" => Dict(string(timer.name) => timer.time for timer in TimerOutputs.flatten(to).children),
        
        "completed_at" => string(now())
    )
    
    return experiment_results, df_critical
end

# Main study execution
println("\n🔬 Starting sparsification accuracy comparison study...")

all_results = []
comparison_data = []

experiment_counter = 1
total_experiments = length(STUDY_CONFIG[:configurations]) * (length(STUDY_CONFIG[:thresholds]) + 1)

for (GN, degree) in STUDY_CONFIG[:configurations]
    println("\n" * "="^70)
    println("Configuration: GN=$GN, degree=$degree")
    println("="^70)
    
    # 1. Baseline experiment (no sparsification)
    baseline_id = "baseline_GN$(GN)_deg$(degree)"
    println("\n[$experiment_counter/$total_experiments] Running baseline (no sparsification)...")
    baseline_results, baseline_df = run_single_experiment(GN, degree; experiment_id=baseline_id)
    push!(all_results, baseline_results)
    experiment_counter += 1
    
    # 2. Sparsification experiments
    for threshold in STUDY_CONFIG[:thresholds]
        sparse_id = "sparse_GN$(GN)_deg$(degree)_thresh$(threshold)"
        println("\n[$experiment_counter/$total_experiments] Running sparsified (threshold=$threshold)...")
        sparse_results, sparse_df = run_single_experiment(GN, degree, threshold; experiment_id=sparse_id)
        push!(all_results, sparse_results)
        
        # Create comparison record
        comparison = Dict(
            "configuration" => Dict("GN" => GN, "degree" => degree),
            "sparsification_threshold" => threshold,
            
            # Sparsification statistics
            "coefficients_removed" => sparse_results["sparsification"]["coefficients_removed"],
            "sparsification_ratio" => sparse_results["sparsification"]["sparsification_ratio"],
            
            # Accuracy comparison
            "baseline_best_distance" => baseline_results["accuracy_metrics"]["best_distance_from_true"],
            "sparse_best_distance" => sparse_results["accuracy_metrics"]["best_distance_from_true"],
            "distance_change" => sparse_results["accuracy_metrics"]["best_distance_from_true"] - baseline_results["accuracy_metrics"]["best_distance_from_true"],
            "distance_relative_change" => isfinite(baseline_results["accuracy_metrics"]["best_distance_from_true"]) && baseline_results["accuracy_metrics"]["best_distance_from_true"] > 0 ? 
                (sparse_results["accuracy_metrics"]["best_distance_from_true"] - baseline_results["accuracy_metrics"]["best_distance_from_true"]) / baseline_results["accuracy_metrics"]["best_distance_from_true"] : NaN,
            
            # Solution count comparison
            "baseline_critical_points" => baseline_results["solution_statistics"]["critical_points_found"],
            "sparse_critical_points" => sparse_results["solution_statistics"]["critical_points_found"],
            "critical_points_change" => sparse_results["solution_statistics"]["critical_points_found"] - baseline_results["solution_statistics"]["critical_points_found"],
            
            # Valid solution comparison
            "baseline_valid_points" => baseline_results["solution_statistics"]["biologically_valid_points"],
            "sparse_valid_points" => sparse_results["solution_statistics"]["biologically_valid_points"],
            "valid_points_change" => sparse_results["solution_statistics"]["biologically_valid_points"] - baseline_results["solution_statistics"]["biologically_valid_points"],
            
            # Performance comparison
            "baseline_total_time" => sum(values(baseline_results["timing"])),
            "sparse_total_time" => sum(values(sparse_results["timing"])),
            "time_change" => sum(values(sparse_results["timing"])) - sum(values(baseline_results["timing"]))
        )
        
        push!(comparison_data, comparison)
        experiment_counter += 1
    end
end

println("\n" * "="^90)
println("🎯 SPARSIFICATION STUDY COMPLETED!")
println("="^90)
println("Total experiments run: $(length(all_results))")
println("Comparisons generated: $(length(comparison_data))")

# Save comprehensive results
println("\n📊 Saving results...")

# 1. Save all experiment results
open(joinpath(results_dir, "all_experiments.json"), "w") do io
    JSON.print(io, all_results, 2)
end

# 2. Save comparison analysis
open(joinpath(results_dir, "sparsification_comparison.json"), "w") do io
    JSON.print(io, comparison_data, 2)
end

# 3. Create comparison DataFrame for easy analysis
comparison_df = DataFrame(comparison_data)
CSV.write(joinpath(results_dir, "sparsification_comparison.csv"), comparison_df)

# 4. Generate summary statistics
summary_stats = Dict(
    "study_configuration" => STUDY_CONFIG,
    "total_experiments" => length(all_results),
    "total_comparisons" => length(comparison_data),
    
    # Overall accuracy impact statistics
    "accuracy_impact_summary" => Dict(
        "mean_distance_change" => mean(skipmissing(comparison_df.distance_change)),
        "median_distance_change" => median(skipmissing(comparison_df.distance_change)),
        "std_distance_change" => std(skipmissing(comparison_df.distance_change)),
        "accuracy_improved_count" => sum(comparison_df.distance_change .< 0),
        "accuracy_degraded_count" => sum(comparison_df.distance_change .> 0),
        "accuracy_unchanged_count" => sum(comparison_df.distance_change .== 0)
    ),
    
    # Solution count impact
    "solution_count_impact" => Dict(
        "mean_critical_points_change" => mean(comparison_df.critical_points_change),
        "more_solutions_count" => sum(comparison_df.critical_points_change .> 0),
        "fewer_solutions_count" => sum(comparison_df.critical_points_change .< 0),
        "unchanged_solutions_count" => sum(comparison_df.critical_points_change .== 0)
    ),
    
    "study_completed_at" => string(now())
)

open(joinpath(results_dir, "study_summary.json"), "w") do io
    JSON.print(io, summary_stats, 2)
end

# Print final summary
println("✅ Results saved to: $results_dir")
println("\n📈 Quick Summary:")
println("  Mean distance change: $(Printf.@sprintf("%.4f", summary_stats["accuracy_impact_summary"]["mean_distance_change"]))")
println("  Accuracy improved: $(summary_stats["accuracy_impact_summary"]["accuracy_improved_count"]) cases")
println("  Accuracy degraded: $(summary_stats["accuracy_impact_summary"]["accuracy_degraded_count"]) cases")
println("  Mean solution count change: $(Printf.@sprintf("%.1f", summary_stats["solution_count_impact"]["mean_critical_points_change"]))")

println("\n" * "="^90)
println("Sparsification accuracy comparison study completed successfully!")
println("Results ready for analysis and publication.")
println("="^90)

# Return comparison data for programmatic access
comparison_df