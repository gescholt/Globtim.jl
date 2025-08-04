"""
4D Benchmark Testing Framework

Comprehensive infrastructure for testing benchmark functions in 4D with:
- Sparsification analysis and tracking
- Convergence monitoring with ForwardDiff
- Distance to minimizers calculation
- Standardized plotting and labeling
- Systematic parameter studies

Usage:
    include("Examples/4d_benchmark_tests/benchmark_4d_framework.jl")
    
    # Quick test
    results = run_4d_benchmark_suite()
    
    # Specific function analysis
    analysis = analyze_4d_function(:Sphere, degrees=[4,6,8])
    
    # Convergence study
    conv_study = convergence_study_4d(:Rosenbrock, track_distance=true)
"""

using Globtim
using DataFrames
using LinearAlgebra
using ForwardDiff
using Statistics
using Printf
using Dates

# ============================================================================
# 4D BENCHMARK FUNCTION SELECTION
# ============================================================================

"""
Select benchmark functions that work well in 4D and have known global minima.
"""
const BENCHMARK_4D_FUNCTIONS = Dict(
    # Bowl-shaped (unimodal) - good for convergence studies
    :Sphere => (func=Sphere, domain=[-5.12, 5.12], global_min=zeros(4), f_min=0.0),
    :Rosenbrock => (func=Rosenbrock, domain=[-2.048, 2.048], global_min=ones(4), f_min=0.0),
    :Zakharov => (func=Zakharov, domain=[-5.0, 5.0], global_min=zeros(4), f_min=0.0),
    
    # Multimodal - good for sparsification studies
    :Griewank => (func=Griewank, domain=[-600.0, 600.0], global_min=zeros(4), f_min=0.0),
    :Rastringin => (func=Rastringin, domain=[-5.12, 5.12], global_min=zeros(4), f_min=0.0),
    :Levy => (func=Levy, domain=[-10.0, 10.0], global_min=ones(4), f_min=0.0),
    
    # Scalable functions
    :StyblinskiTang => (func=StyblinskiTang, domain=[-5.0, 5.0], 
                       global_min=fill(-2.903534, 4), f_min=-39.16599*4),
    :Michalewicz => (func=Michalewicz, domain=[0.0, π], 
                    global_min=nothing, f_min=nothing), # Dimension-dependent minimum
    
    # Higher-dimensional specific
    :Trid => (func=Trid, domain=[-16.0, 16.0], 
             global_min=[4.0, 6.0, 6.0, 4.0], f_min=-20.0),
    :RotatedHyperEllipsoid => (func=RotatedHyperEllipsoid, domain=[-65.536, 65.536], 
                              global_min=zeros(4), f_min=0.0)
)

# ============================================================================
# TESTING CONFIGURATIONS
# ============================================================================

"""
Standardized testing configurations for different analysis types.
"""

# Quick testing for development
const QUICK_4D_CONFIG = (
    degrees = [4, 6],
    sample_counts = [50, 100],
    sparsification_thresholds = [1e-3, 1e-4],
    functions = [:Sphere, :Rosenbrock, :Griewank]
)

# Standard comprehensive testing
const STANDARD_4D_CONFIG = (
    degrees = [4, 6, 8, 10],
    sample_counts = [100, 200, 500],
    sparsification_thresholds = [1e-2, 1e-3, 1e-4, 1e-5],
    functions = [:Sphere, :Rosenbrock, :Zakharov, :Griewank, :Rastringin, :Levy]
)

# Intensive testing for research
const INTENSIVE_4D_CONFIG = (
    degrees = [6, 8, 10, 12],
    sample_counts = [200, 500, 1000],
    sparsification_thresholds = [1e-2, 1e-3, 1e-4, 1e-5, 1e-6],
    functions = keys(BENCHMARK_4D_FUNCTIONS)
)

# ============================================================================
# CORE DATA STRUCTURES
# ============================================================================

"""
Results structure for 4D benchmark analysis.
"""
struct Benchmark4DResult
    function_name::Symbol
    degree::Int
    sample_count::Int
    
    # Polynomial approximation results
    l2_error::Float64
    sparsification_results::NamedTuple
    
    # Critical point analysis
    critical_points_df::DataFrame
    minimizers_df::DataFrame
    
    # Convergence tracking
    convergence_metrics::NamedTuple
    distance_to_global_min::Vector{Float64}
    
    # Performance metrics
    construction_time::Float64
    analysis_time::Float64
    
    # Metadata
    timestamp::String
    config_used::String
end

"""
Convergence tracking structure.
"""
struct ConvergenceTracker
    initial_points::Vector{Vector{Float64}}
    refined_points::Vector{Vector{Float64}}
    initial_values::Vector{Float64}
    refined_values::Vector{Float64}
    gradient_norms::Vector{Float64}
    distances_to_global::Vector{Float64}
    convergence_steps::Vector{Int}
    convergence_reasons::Vector{Symbol}
end

# ============================================================================
# DISTANCE CALCULATION UTILITIES
# ============================================================================

"""
    calculate_distance_to_global_minimum(points::Matrix{Float64}, global_min::Vector{Float64})

Calculate Euclidean distance from each point to the known global minimum.
"""
function calculate_distance_to_global_minimum(points::Matrix{Float64}, global_min::Vector{Float64})
    n_points = size(points, 1)
    distances = Vector{Float64}(undef, n_points)
    
    for i in 1:n_points
        distances[i] = norm(points[i, :] - global_min)
    end
    
    return distances
end

"""
    calculate_distance_to_global_minimum(df::DataFrame, global_min::Vector{Float64}, n_dims::Int=4)

Calculate distances for points stored in DataFrame format.
"""
function calculate_distance_to_global_minimum(df::DataFrame, global_min::Vector{Float64}, n_dims::Int=4)
    n_points = nrow(df)
    points = Matrix{Float64}(undef, n_points, n_dims)
    
    for i in 1:n_dims
        points[:, i] = df[!, Symbol("x$i")]
    end
    
    return calculate_distance_to_global_minimum(points, global_min)
end

"""
    track_convergence_to_minimum(initial_df::DataFrame, refined_df::DataFrame, 
                                global_min::Vector{Float64}, objective_func::Function)

Track convergence metrics including distance reduction and gradient norms.
"""
function track_convergence_to_minimum(initial_df::DataFrame, refined_df::DataFrame, 
                                     global_min::Vector{Float64}, objective_func::Function)
    n_dims = 4
    n_points = nrow(initial_df)
    
    # Extract points
    initial_points = Matrix{Float64}(undef, n_points, n_dims)
    refined_points = Matrix{Float64}(undef, n_points, n_dims)
    
    for i in 1:n_dims
        initial_points[:, i] = initial_df[!, Symbol("x$i")]
        refined_points[:, i] = refined_df[!, Symbol("x$i")]
    end
    
    # Calculate distances
    refined_distances = calculate_distance_to_global_minimum(refined_points, global_min)
    
    # Calculate gradient norms at refined points
    gradient_norms = compute_gradients(objective_func, refined_points)
    
    # Calculate convergence steps (if available)
    convergence_steps = haskey(refined_df, :steps) ? refined_df.steps : fill(-1, n_points)
    
    # Calculate convergence reasons (if available)
    convergence_reasons = haskey(refined_df, :converged) ? 
        [r ? :converged : :max_iterations for r in refined_df.converged] :
        fill(:unknown, n_points)
    
    return ConvergenceTracker(
        [initial_points[i, :] for i in 1:n_points],
        [refined_points[i, :] for i in 1:n_points],
        [objective_func(initial_points[i, :]) for i in 1:n_points],
        [objective_func(refined_points[i, :]) for i in 1:n_points],
        gradient_norms,
        refined_distances,
        convergence_steps,
        convergence_reasons
    )
end

# ============================================================================
# SPARSIFICATION ANALYSIS
# ============================================================================

"""
    analyze_sparsification_4d(pol::ApproxPoly, thresholds::Vector{Float64})

Comprehensive sparsification analysis for 4D polynomials.
"""
function analyze_sparsification_4d(pol::ApproxPoly, thresholds::Vector{Float64})
    results = []
    
    for threshold in thresholds
        # Perform sparsification
        sparse_result = sparsify_polynomial(pol, threshold, mode=:relative)
        
        # Calculate additional metrics
        original_nnz = count(x -> abs(x) > 1e-15, pol.coeffs)
        new_nnz = count(x -> abs(x) > 1e-15, sparse_result.polynomial.coeffs)
        
        sparsity_gain = 1.0 - (new_nnz / original_nnz)
        
        push!(results, (
            threshold = threshold,
            original_nnz = original_nnz,
            new_nnz = new_nnz,
            sparsity_gain = sparsity_gain,
            l2_ratio = sparse_result.l2_ratio,
            zeroed_count = length(sparse_result.zeroed_indices),
            sparse_polynomial = sparse_result.polynomial
        ))
    end
    
    return results
end

# ============================================================================
# LABELING AND METADATA SYSTEM
# ============================================================================

"""
    generate_experiment_label(func_name::Symbol, degree::Int, samples::Int, 
                             config_name::String, timestamp::String)

Generate standardized labels for experiments.
"""
function generate_experiment_label(func_name::Symbol, degree::Int, samples::Int, 
                                 config_name::String, timestamp::String)
    return "$(func_name)_d$(degree)_s$(samples)_$(config_name)_$(timestamp)"
end

"""
    create_metadata_dict(func_name::Symbol, degree::Int, samples::Int, config_name::String)

Create comprehensive metadata for tracking experiments.
"""
function create_metadata_dict(func_name::Symbol, degree::Int, samples::Int, config_name::String)
    func_info = BENCHMARK_4D_FUNCTIONS[func_name]
    
    return Dict(
        :function_name => func_name,
        :degree => degree,
        :samples => samples,
        :config => config_name,
        :domain => func_info.domain,
        :global_minimum => func_info.global_min,
        :global_minimum_value => func_info.f_min,
        :dimension => 4,
        :timestamp => Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    )
end

# ============================================================================
# CORE ANALYSIS FUNCTIONS
# ============================================================================

"""
    analyze_4d_function(func_name::Symbol; degrees=[4,6,8], samples=[100,200],
                        sparsification_thresholds=[1e-3,1e-4], track_convergence=true)

Comprehensive analysis of a single 4D benchmark function.
"""
function analyze_4d_function(func_name::Symbol;
                            degrees=[4,6,8],
                            samples=[100,200],
                            sparsification_thresholds=[1e-3,1e-4],
                            track_convergence=true,
                            config_name="custom")

    if !haskey(BENCHMARK_4D_FUNCTIONS, func_name)
        error("Function $func_name not found in BENCHMARK_4D_FUNCTIONS")
    end

    func_info = BENCHMARK_4D_FUNCTIONS[func_name]
    objective_func = func_info.func
    domain_range = func_info.domain[2] - func_info.domain[1]
    center = zeros(4)
    sample_range = domain_range / 2

    results = []

    println("🔍 Analyzing function: $func_name")
    println("📊 Domain: $(func_info.domain)")
    println("🎯 Global minimum: $(func_info.global_min)")
    println("=" ^ 60)

    for degree in degrees, sample_count in samples
        println("\n📈 Testing degree=$degree, samples=$sample_count")

        # Create test input
        TR = test_input(objective_func, dim=4, center=center, sample_range=sample_range)

        # Time polynomial construction
        construction_start = time()
        pol = Constructor(TR, degree)
        construction_time = time() - construction_start

        println("  ✓ Polynomial constructed (L2 error: $(pol.nrm), time: $(construction_time:.3f)s)")

        # Sparsification analysis
        sparsification_results = analyze_sparsification_4d(pol, sparsification_thresholds)
        println("  ✓ Sparsification analysis completed ($(length(sparsification_thresholds)) thresholds)")

        # Critical point analysis
        analysis_start = time()
        @polyvar x[1:4]
        solutions = solve_polynomial_system(x, 4, degree, pol.coeffs)
        df_initial = process_crit_pts(solutions, objective_func, TR)

        # Enhanced analysis with convergence tracking
        if track_convergence && nrow(df_initial) > 0
            df_refined, df_minimizers = analyze_critical_points(
                objective_func, df_initial, TR,
                enable_hessian=true, verbose=false
            )

            # Calculate distances to global minimum if known
            distance_to_global = Float64[]
            if func_info.global_min !== nothing
                distance_to_global = calculate_distance_to_global_minimum(
                    df_refined, func_info.global_min, 4
                )
            end

            # Track convergence metrics
            convergence_metrics = (
                total_points = nrow(df_initial),
                converged_points = sum(df_refined.converged),
                convergence_rate = sum(df_refined.converged) / nrow(df_initial),
                mean_gradient_norm = mean(skipmissing(df_refined.grad_norm)),
                mean_distance_to_global = func_info.global_min !== nothing ? mean(distance_to_global) : NaN
            )
        else
            df_refined = df_initial
            df_minimizers = DataFrame()
            distance_to_global = Float64[]
            convergence_metrics = (
                total_points = nrow(df_initial),
                converged_points = 0,
                convergence_rate = 0.0,
                mean_gradient_norm = NaN,
                mean_distance_to_global = NaN
            )
        end

        analysis_time = time() - analysis_start
        println("  ✓ Critical point analysis completed ($(nrow(df_initial)) points, time: $(analysis_time:.3f)s)")

        # Create result
        timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
        result = Benchmark4DResult(
            func_name,
            degree,
            sample_count,
            pol.nrm,
            (thresholds=sparsification_thresholds, results=sparsification_results),
            df_refined,
            df_minimizers,
            convergence_metrics,
            distance_to_global,
            construction_time,
            analysis_time,
            timestamp,
            config_name
        )

        push!(results, result)

        # Print summary
        println("  📊 Summary:")
        println("    - L2 error: $(pol.nrm)")
        println("    - Critical points found: $(nrow(df_initial))")
        println("    - Convergence rate: $(convergence_metrics.convergence_rate*100)%")
        if func_info.global_min !== nothing && !isempty(distance_to_global)
            println("    - Mean distance to global min: $(mean(distance_to_global))")
        end
    end

    return results
end

"""
    run_4d_benchmark_suite(config=QUICK_4D_CONFIG; track_convergence=true)

Run comprehensive benchmark suite on multiple 4D functions.
"""
function run_4d_benchmark_suite(config=QUICK_4D_CONFIG; track_convergence=true)
    println("🚀 Starting 4D Benchmark Suite")
    println("📋 Configuration: $(length(config.functions)) functions, $(length(config.degrees)) degrees")
    println("=" ^ 80)

    all_results = []

    for func_name in config.functions
        try
            func_results = analyze_4d_function(
                func_name,
                degrees=config.degrees,
                samples=config.sample_counts,
                sparsification_thresholds=config.sparsification_thresholds,
                track_convergence=track_convergence,
                config_name="benchmark_suite"
            )
            append!(all_results, func_results)
        catch e
            println("❌ Error analyzing $func_name: $e")
        end
    end

    println("\n✅ Benchmark suite completed!")
    println("📊 Total results: $(length(all_results))")

    return all_results
end

"""
    convergence_study_4d(func_name::Symbol; degrees=[4,6,8,10], track_distance=true)

Detailed convergence study for a specific function.
"""
function convergence_study_4d(func_name::Symbol; degrees=[4,6,8,10], track_distance=true)
    if !haskey(BENCHMARK_4D_FUNCTIONS, func_name)
        error("Function $func_name not found in BENCHMARK_4D_FUNCTIONS")
    end

    func_info = BENCHMARK_4D_FUNCTIONS[func_name]
    objective_func = func_info.func

    println("🎯 Convergence Study: $func_name")
    println("🔍 Tracking distance to global minimum: $track_distance")

    convergence_data = []

    for degree in degrees
        println("\n📈 Degree $degree analysis...")

        # Create test input
        domain_range = func_info.domain[2] - func_info.domain[1]
        TR = test_input(objective_func, dim=4, center=zeros(4), sample_range=domain_range/2)

        # Construct polynomial
        pol = Constructor(TR, degree)

        # Find critical points
        @polyvar x[1:4]
        solutions = solve_polynomial_system(x, 4, degree, pol.coeffs)
        df_initial = process_crit_pts(solutions, objective_func, TR)

        if nrow(df_initial) == 0
            println("  ⚠️  No critical points found for degree $degree")
            continue
        end

        # Enhanced BFGS refinement with detailed tracking
        config = BFGSConfig(
            max_iterations=200,
            show_trace=false,
            track_hyperparameters=true
        )

        df_enhanced = refine_with_enhanced_bfgs(df_initial, objective_func, config)

        # Track convergence to global minimum
        if track_distance && func_info.global_min !== nothing
            convergence_tracker = track_convergence_to_minimum(
                df_initial, df_enhanced, func_info.global_min, objective_func
            )

            push!(convergence_data, (
                degree = degree,
                l2_error = pol.nrm,
                tracker = convergence_tracker,
                initial_df = df_initial,
                refined_df = df_enhanced
            ))

            # Print convergence statistics
            mean_distance_reduction = mean(
                [norm(init - ref) for (init, ref) in zip(convergence_tracker.initial_points, convergence_tracker.refined_points)]
            )
            mean_final_distance = mean(convergence_tracker.distances_to_global)

            println("  📊 Convergence metrics:")
            println("    - Points analyzed: $(length(convergence_tracker.initial_points))")
            println("    - Mean distance reduction: $(mean_distance_reduction)")
            println("    - Mean final distance to global: $(mean_final_distance)")
            println("    - Mean gradient norm: $(mean(convergence_tracker.gradient_norms))")
        end
    end

    return convergence_data
end
