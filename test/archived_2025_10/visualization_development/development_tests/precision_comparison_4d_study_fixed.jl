#!/usr/bin/env julia
"""
Enhanced 4D Precision Comparison Study with Hessian Eigenvalue Collection

This experiment compares Float64Precision vs AdaptivePrecision, collects optimized points
and Hessian eigenvalues, and uses refined domain ranges based on previous successful results.

Improvements over previous experiments:
- Precision comparison between Float64 and Adaptive
- Hessian eigenvalue collection for all critical points
- Refined domain ranges (0.125, 0.15, 0.175) for better parameter space coverage
- Increased GN from 14 to 16 for higher resolution
- Robust infrastructure with no "fails" - proper error handling
- Comprehensive results collection and analysis
"""

using Pkg
Pkg.activate(get(ENV, "JULIA_PROJECT", "/home/scholten/globtimcore"))

using Globtim
using DynamicPolynomials
using DataFrames
using CSV
using JSON3
using TimerOutputs
using StaticArrays
using LinearAlgebra
using Statistics
using Dates
using ForwardDiff

# Define experiment configuration
struct PrecisionComparisonConfig
    experiment_id::String
    description::String

    # Model parameters
    true_params::Vector{Float64}
    center_params::Vector{Float64}
    domain_ranges::Vector{Float64}  # Multiple domain ranges to test
    dimension::Int

    # Sampling parameters
    GN::Int                         # Increased from 14 to 16
    degree_range::UnitRange{Int}
    basis::Symbol

    # Time integration parameters
    time_interval::Vector{Float64}
    initial_conditions::Vector{Float64}

    # Precision comparison
    precision_types::Vector{PrecisionType}

    # Analysis options
    enable_hessian::Bool
    enable_sparsification::Bool
    sparsification_threshold::Float64

    # Output control
    results_base_dir::String
    created_at::DateTime
end

# Enhanced configuration based on successful previous results
function create_enhanced_config()
    return PrecisionComparisonConfig(
        "precision_comparison_4d_enhanced_$(Dates.format(now(), "yyyymmdd_HHMMSS"))",
        "Enhanced 4D Precision Comparison with Hessian Collection and Refined Domain Ranges",

        # Model parameters (same as successful experiment)
        [0.2, 0.3, 0.5, 0.6],  # true Lotka-Volterra parameters
        [0.173, 0.297, 0.465, 0.624],  # slightly offset center for robustness
        [0.125, 0.15, 0.175],  # refined domain ranges - slightly larger than successful 0.1
        4,

        # Enhanced sampling (increased resolution)
        16,  # Increased from 14 - should give 16^4 = 65,536 sample points per experiment
        4:12,  # same degree range as successful experiments
        :chebyshev,

        # Time parameters (same as previous)
        [0.0, 10.0],
        [1.0, 2.0, 1.0, 1.0],

        # Precision comparison (key enhancement)
        [Float64Precision, AdaptivePrecision],

        # Analysis options (enhanced)
        true,   # enable_hessian - collect eigenvalues
        false,  # disable sparsification for precision comparison clarity
        1e-8,

        # Output
        joinpath(@__DIR__, "precision_comparison_results"),
        now()
    )
end

"""
Define enhanced 4D Lotka-Volterra test model with proper error handling
"""
function define_enhanced_4d_model(true_params::Vector{Float64},
                                 time_interval::Vector{Float64},
                                 initial_conditions::Vector{Float64})

    # Extract parameters for reference
    t_span = (time_interval[1], time_interval[2])
    x₀, y₀, z₀, w₀ = initial_conditions

    function enhanced_4d_objective(θ::AbstractVector)
        if length(θ) != 4
            return 1e8  # Large penalty for wrong dimensionality
        end

        α, β, γ, δ = θ

        # Parameter bounds checking (prevent negative parameters)
        if any(θ .≤ 0.0) || any(θ .≥ 2.0)
            return 1e8
        end

        try
            # Enhanced 4D Lotka-Volterra system
            function enhanced_lotka_volterra!(du, u, p, _)
                x, y, z, w = u
                α, β, γ, δ = p

                du[1] = α*x - β*x*y           # Prey 1
                du[2] = γ*x*y - δ*y           # Predator 1
                du[3] = α*z - β*z*w           # Prey 2
                du[4] = γ*z*w - δ*w           # Predator 2
            end

            # Simple numerical integration (avoiding ODE solver dependency issues)
            dt = 0.01
            t_vals = t_span[1]:dt:t_span[2]
            n_steps = length(t_vals)

            # State variables
            u = [x₀, y₀, z₀, w₀]
            du = zeros(4)

            # Euler integration
            for i in 1:(n_steps-1)
                enhanced_lotka_volterra!(du, u, θ, t_vals[i])
                u .+= dt .* du

                # Stability check
                if any(isnan.(u)) || any(u .< 0.0) || any(u .> 100.0)
                    return 1e8
                end
            end

            # True solution at final time
            u_true = [x₀, y₀, z₀, w₀]
            du_true = zeros(4)
            for i in 1:(n_steps-1)
                enhanced_lotka_volterra!(du_true, u_true, true_params, t_vals[i])
                u_true .+= dt .* du_true
            end

            # Objective: L2 distance from true solution
            return sum((u .- u_true).^2)

        catch e
            @warn "Objective evaluation failed for θ=$θ: $e"
            return 1e8
        end
    end

    return enhanced_4d_objective
end

"""
Run single precision experiment with comprehensive error handling
"""
function run_precision_experiment(config::PrecisionComparisonConfig,
                                 domain_range::Float64,
                                 precision_type::PrecisionType,
                                 results_dir::String)

    println("\n" * "="^100)
    println("PRECISION EXPERIMENT: $(precision_type) | Domain Range: $(domain_range)")
    println("="^100)

    experiment_name = "range_$(domain_range)_precision_$(precision_type)"
    experiment_dir = joinpath(results_dir, experiment_name)
    mkpath(experiment_dir)

    to = TimerOutput()

    try
        # Create objective function
        @timeit to "objective_creation" begin
            objective_func = define_enhanced_4d_model(config.true_params,
                                                    config.time_interval,
                                                    config.initial_conditions)
        end

        # Generate parameter samples
        println("Step 1: Generating parameter space samples...")
        @timeit to "parameter_sampling" begin
            TR = test_input(
                objective_func,
                dim = config.dimension,
                center = config.center_params,
                GN = config.GN,
                sample_range = domain_range
            )
        end
        println("✓ Generated $(TR.GN^config.dimension) parameter combinations")

        # Results storage
        degree_results = Dict()

        for degree in config.degree_range
            println("\n--- Processing Degree $(degree) ---")
            degree_timer = TimerOutput()

            try
                # Polynomial construction
                @timeit degree_timer "polynomial_construction" begin
                    pol = Constructor(
                        TR,
                        degree,
                        basis = config.basis,
                        precision = precision_type,  # KEY: precision comparison
                        verbose = false
                    )
                end

                println("✓ Polynomial constructed (condition: $(round(pol.cond_vandermonde, digits=2)), L2: $(round(pol.nrm, digits=4)))")

                # Critical point solving
                @polyvar(x[1:config.dimension])
                @timeit degree_timer "critical_point_solving" begin
                    critical_points, (system, n_solutions) = solve_polynomial_system(
                        x,
                        config.dimension,
                        degree,
                        pol.coeffs;
                        basis = config.basis,
                        precision = precision_type,
                        return_system = true
                    )
                end

                println("✓ Found $(length(critical_points)) real critical points ($(n_solutions) total solutions)")

                # Process critical points with Hessian analysis
                @timeit degree_timer "critical_point_processing" begin
                    if length(critical_points) > 0
                        df_critical = process_crit_pts(critical_points, objective_func, TR)

                        # Add Hessian eigenvalue analysis if enabled
                        if config.enable_hessian && nrow(df_critical) > 0
                            println("  Computing Hessian eigenvalues for $(nrow(df_critical)) critical points...")

                            # Add Hessian columns
                            hessian_eigenvalues = [Float64[] for _ in 1:config.dimension]

                            for i in 1:nrow(df_critical)
                                try
                                    point = df_critical[i, :x]
                                    hess = ForwardDiff.hessian(objective_func, point)
                                    eigenvals = eigvals(hess)

                                    # Store eigenvalues
                                    for j in 1:config.dimension
                                        push!(hessian_eigenvalues[j], real(eigenvals[j]))
                                    end

                                catch e
                                    @warn "Hessian computation failed for point $i: $e"
                                    for j in 1:config.dimension
                                        push!(hessian_eigenvalues[j], NaN)
                                    end
                                end
                            end

                            # Add eigenvalue columns to DataFrame
                            for j in 1:config.dimension
                                df_critical[!, Symbol("hessian_eigenvalue_$j")] = hessian_eigenvalues[j]
                            end

                            println("  ✓ Hessian eigenvalues computed")
                        else
                            df_critical = DataFrame()  # Empty DataFrame for failed cases
                        end
                    else
                        df_critical = DataFrame()
                    end
                end

                # Store results
                degree_results[degree] = Dict(
                    "success" => true,
                    "condition_number" => pol.cond_vandermonde,
                    "L2_norm" => pol.nrm,
                    "total_solutions" => n_solutions,
                    "real_critical_points" => length(critical_points),
                    "processed_critical_points" => nrow(df_critical),
                    "timing" => Dict(string(timer.name) => timer.time for timer in TimerOutputs.flatten(degree_timer).children),
                    "critical_points_dataframe" => df_critical
                )

                # Save individual degree results
                if nrow(df_critical) > 0
                    CSV.write(joinpath(experiment_dir, "critical_points_deg_$(degree).csv"), df_critical)
                end

            catch e
                @error "Degree $(degree) failed: $e"
                degree_results[degree] = Dict(
                    "success" => false,
                    "error" => string(e),
                    "timing" => Dict()
                )
            end
        end

        # Create experiment summary
        experiment_summary = Dict(
            "experiment_id" => config.experiment_id,
            "precision_type" => string(precision_type),
            "domain_range" => domain_range,
            "configuration" => Dict(
                "true_params" => config.true_params,
                "center_params" => config.center_params,
                "GN" => config.GN,
                "dimension" => config.dimension,
                "degree_range" => [config.degree_range.start, config.degree_range.stop],
                "basis" => string(config.basis),
                "time_interval" => config.time_interval,
                "initial_conditions" => config.initial_conditions,
                "enable_hessian" => config.enable_hessian
            ),
            "results_by_degree" => degree_results,
            "total_timing" => Dict(string(timer.name) => timer.time for timer in TimerOutputs.flatten(to).children),
            "completed_at" => string(now())
        )

        # Save experiment summary
        open(joinpath(experiment_dir, "experiment_summary.json"), "w") do io
            JSON3.pretty(io, experiment_summary)
        end

        # Save timing report
        open(joinpath(experiment_dir, "timing_report.txt"), "w") do io
            print(io, to)
        end

        println("✓ Experiment completed successfully: $(experiment_name)")
        return experiment_summary

    catch e
        @error "Experiment failed: $(experiment_name) - $e"

        # Save error information
        error_info = Dict(
            "experiment_id" => config.experiment_id,
            "precision_type" => string(precision_type),
            "domain_range" => domain_range,
            "error" => string(e),
            "failed_at" => string(now())
        )

        open(joinpath(experiment_dir, "error_report.json"), "w") do io
            JSON3.pretty(io, error_info)
        end

        return error_info
    end
end

"""
Run comprehensive precision comparison study
"""
function run_comprehensive_precision_study()
    config = create_enhanced_config()

    println("\n" * "="^120)
    println("COMPREHENSIVE 4D PRECISION COMPARISON STUDY")
    println("="^120)
    println("Experiment ID: $(config.experiment_id)")
    println("Description: $(config.description)")
    println("Created: $(config.created_at)")
    println("="^120)

    # Create results directory
    mkpath(config.results_base_dir)

    # Save configuration
    config_dict = Dict(
        "experiment_id" => config.experiment_id,
        "description" => config.description,
        "true_params" => config.true_params,
        "center_params" => config.center_params,
        "domain_ranges" => config.domain_ranges,
        "dimension" => config.dimension,
        "GN" => config.GN,
        "degree_range" => [config.degree_range.start, config.degree_range.stop],
        "basis" => string(config.basis),
        "precision_types" => [string(pt) for pt in config.precision_types],
        "time_interval" => config.time_interval,
        "initial_conditions" => config.initial_conditions,
        "enable_hessian" => config.enable_hessian,
        "enable_sparsification" => config.enable_sparsification,
        "created_at" => string(config.created_at)
    )

    open(joinpath(config.results_base_dir, "study_configuration.json"), "w") do io
        JSON3.pretty(io, config_dict)
    end

    # Run all experiments
    all_results = Dict()

    for precision_type in config.precision_types
        for domain_range in config.domain_ranges
            experiment_key = "$(precision_type)_range_$(domain_range)"
            println("\n\nStarting: $(experiment_key)")

            result = run_precision_experiment(config, domain_range, precision_type, config.results_base_dir)
            all_results[experiment_key] = result

            println("Completed: $(experiment_key)")
        end
    end

    # Create comprehensive summary
    study_summary = Dict(
        "study_configuration" => config_dict,
        "all_experiment_results" => all_results,
        "study_completed_at" => string(now())
    )

    open(joinpath(config.results_base_dir, "comprehensive_study_results.json"), "w") do io
        JSON3.pretty(io, study_summary)
    end

    # Generate analysis report
    generate_precision_analysis_report(config, all_results)

    println("\n" * "="^120)
    println("COMPREHENSIVE STUDY COMPLETED!")
    println("Results directory: $(config.results_base_dir)")
    println("="^120)

    return study_summary
end

"""
Generate comprehensive analysis report comparing precisions
"""
function generate_precision_analysis_report(config::PrecisionComparisonConfig, all_results::Dict)
    report_path = joinpath(config.results_base_dir, "PRECISION_ANALYSIS_REPORT.md")

    open(report_path, "w") do io
        write(io, """
# 4D Precision Comparison Analysis Report

**Study ID**: $(config.experiment_id)
**Generated**: $(now())
**Enhanced Features**: Hessian eigenvalue collection, refined domain ranges, increased resolution

## Executive Summary

This study compares Float64Precision vs AdaptivePrecision across multiple domain ranges with enhanced analysis capabilities:

- **Precision Types**: Float64Precision vs AdaptivePrecision
- **Domain Ranges**: $(join(config.domain_ranges, ", "))
- **Resolution**: GN=$(config.GN) ($(config.GN^4) sample points per experiment)
- **Polynomial Degrees**: $(config.degree_range.start)-$(config.degree_range.stop)
- **Enhanced Analysis**: Hessian eigenvalue collection enabled
- **True Parameters**: α=$(config.true_params[1]), β=$(config.true_params[2]), γ=$(config.true_params[3]), δ=$(config.true_params[4])

## Results by Domain Range and Precision

""")

        for domain_range in config.domain_ranges
            write(io, "### Domain Range: ±$(domain_range)\n\n")

            for precision_type in config.precision_types
                experiment_key = "$(precision_type)_range_$(domain_range)"

                if haskey(all_results, experiment_key)
                    result = all_results[experiment_key]

                    write(io, "#### $(precision_type)\n\n")

                    if haskey(result, "results_by_degree")
                        successful_degrees = []
                        failed_degrees = []

                        for degree in config.degree_range
                            if haskey(result["results_by_degree"], degree)
                                degree_result = result["results_by_degree"][degree]
                                if get(degree_result, "success", false)
                                    push!(successful_degrees, degree)

                                    # Extract best results if available
                                    if haskey(degree_result, "critical_points_dataframe")
                                        df = degree_result["critical_points_dataframe"]
                                        if nrow(df) > 0
                                            best_obj = minimum(df.z)
                                            n_points = nrow(df)

                                            write(io, "- **Degree $(degree)**: $(n_points) critical points, best objective: $(round(best_obj, digits=4))\n")

                                            # Report Hessian eigenvalues if available
                                            hessian_cols = [name for name in names(df) if occursin("hessian_eigenvalue", string(name))]
                                            if !isempty(hessian_cols)
                                                write(io, "  - Hessian eigenvalues collected: $(length(hessian_cols)) dimensions\n")
                                            end
                                        else
                                            write(io, "- **Degree $(degree)**: No critical points found\n")
                                        end
                                    end
                                else
                                    push!(failed_degrees, degree)
                                end
                            end
                        end

                        write(io, "\n**Summary**: $(length(successful_degrees))/$(length(config.degree_range)) degrees successful\n")
                        if !isempty(failed_degrees)
                            write(io, "**Failed degrees**: $(join(failed_degrees, ", "))\n")
                        end
                    end

                    write(io, "\n")
                else
                    write(io, "#### $(precision_type): EXPERIMENT FAILED\n\n")
                end
            end

            write(io, "\n---\n\n")
        end

        write(io, """
## Technical Improvements

### Infrastructure Enhancements
- **No "fails"**: Robust error handling prevents infrastructure failures
- **Increased Resolution**: GN=16 provides $(16^4) sample points (vs. $(14^4) previously)
- **Refined Domain Ranges**: Based on successful 0.1 range, testing 0.125, 0.15, 0.175
- **Hessian Collection**: Complete eigenvalue analysis for all critical points

### Precision Comparison Methodology
- **Float64Precision**: Standard double-precision arithmetic
- **AdaptivePrecision**: BigFloat with adaptive precision based on value magnitude
- **Consistent Evaluation**: Same objective function and parameter space for both precisions
- **Comprehensive Analysis**: Condition numbers, L2 norms, and eigenvalue spectra collected

### Expected Outcomes
- **Precision Impact**: Comparison of numerical accuracy between precision types
- **Critical Point Quality**: Hessian eigenvalue analysis reveals optimization landscape
- **Computational Efficiency**: Timing comparison between precision approaches
- **Domain Sensitivity**: Parameter estimation quality vs domain size analysis

## File Structure

```
$(config.results_base_dir)/
├── study_configuration.json          # Complete study configuration
├── comprehensive_study_results.json  # All results summary
├── PRECISION_ANALYSIS_REPORT.md      # This report
└── [precision]_range_[domain]/       # Individual experiment directories
    ├── experiment_summary.json       # Experiment-specific results
    ├── timing_report.txt             # Performance analysis
    └── critical_points_deg_[N].csv   # Critical points with Hessian eigenvalues
```

---

**Study Status**: $(length(all_results)) experiments completed
**Analysis Framework**: Enhanced 4D mathematical pipeline with precision comparison capabilities
""")
    end

    println("✓ Analysis report generated: $(report_path)")
end

# Execute study if run as script
if abspath(PROGRAM_FILE) == @__FILE__
    println("Starting comprehensive 4D precision comparison study...")
    study_results = run_comprehensive_precision_study()
    println("Study complete!")
end