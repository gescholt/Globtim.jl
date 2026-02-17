#!/usr/bin/env julia

"""
Comprehensive Benchmarking Framework for Globtim

Advanced pass/fail testing environment with statistical tracking and 
systematic parameter exploration for optimization benchmarks.
"""

using Globtim
using DataFrames
using Statistics
using LinearAlgebra
using JSON3
using Dates
using ForwardDiff

# ============================================================================
# CORE DATA STRUCTURES
# ============================================================================

"""
Comprehensive benchmark result with all tracked statistics.
"""
struct BenchmarkResult
    # Test Configuration
    function_name::String
    parameter_set_name::String
    test_id::String
    timestamp::String
    
    # Domain Configuration
    domain_size::Float64
    center::Vector{Float64}
    l2_tolerance::Float64
    degree::Int
    sample_count::Int
    
    # Ground Truth Information
    true_local_minima_known::Bool
    true_global_minimum_known::Bool
    known_global_minima::Vector{Vector{Float64}}
    known_local_minima::Vector{Vector{Float64}}
    
    # Computed Results
    computed_critical_points::Vector{Vector{Float64}}
    function_values::Vector{Float64}
    gradient_norms::Vector{Float64}
    hessian_eigenvalues::Vector{Vector{Float64}}
    critical_point_types::Vector{Symbol}
    
    # Distance Analysis (Order-sensitive!)
    distances_to_approximant_critical_points::Vector{Float64}
    distances_to_known_global_minima::Vector{Float64}
    distances_to_known_local_minima::Vector{Float64}
    recovery_rates::Dict{String, Float64}
    
    # Performance Metrics
    construction_time::Float64
    analysis_time::Float64
    l2_error_achieved::Float64
    vandermonde_condition_number::Float64
    
    # Pass/Fail Classification
    overall_status::Symbol
    failure_reasons::Vector{String}
    quality_score::Float64
    detailed_checks::Dict{String, Any}
end

"""
Pass/fail criteria for benchmark validation.
"""
struct PassFailCriteria
    # Distance-based criteria
    max_distance_to_global::Float64
    min_recovery_rate_global::Float64
    min_recovery_rate_local::Float64
    
    # Accuracy criteria
    max_l2_error::Float64
    max_function_value_error::Float64
    max_gradient_norm::Float64
    
    # Stability criteria
    max_condition_number::Float64
    min_eigenvalue_separation::Float64
    
    # Performance criteria
    max_construction_time::Float64
    min_critical_points_found::Int
    
    # Constructor with defaults
    function PassFailCriteria(;
        max_distance_to_global = 0.1,
        min_recovery_rate_global = 0.8,
        min_recovery_rate_local = 0.6,
        max_l2_error = 1e-3,
        max_function_value_error = 1e-6,
        max_gradient_norm = 1e-4,
        max_condition_number = 1e12,
        min_eigenvalue_separation = 1e-8,
        max_construction_time = 300.0,
        min_critical_points_found = 1
    )
        new(max_distance_to_global, min_recovery_rate_global, min_recovery_rate_local,
            max_l2_error, max_function_value_error, max_gradient_norm,
            max_condition_number, min_eigenvalue_separation,
            max_construction_time, min_critical_points_found)
    end
end

"""
Enhanced benchmark function with complete metadata.
"""
struct EnhancedBenchmarkFunction
    name::String
    func::Function
    dimension::Int
    description::String
    
    # Ground truth data
    global_minima::Vector{Vector{Float64}}
    global_minimum_value::Float64
    local_minima::Vector{Vector{Float64}}
    
    # Function properties
    category::String  # "unimodal", "multimodal", "separable", etc.
    difficulty::Symbol  # :easy, :medium, :hard
    known_challenges::Vector{String}
    
    # Recommended test parameters
    recommended_domain_size::Float64
    recommended_center::Vector{Float64}
    recommended_degree_range::Tuple{Int, Int}
    recommended_sample_count_range::Tuple{Int, Int}
end

# ============================================================================
# BENCHMARK FUNCTION LIBRARY
# ============================================================================

"""
Create enhanced benchmark function library with complete metadata.
"""
function create_benchmark_library()
    library = Dict{String, EnhancedBenchmarkFunction}()
    
    # Sphere Function (4D)
    library["Sphere4D"] = EnhancedBenchmarkFunction(
        "Sphere4D",
        x -> sum(x.^2),
        4,
        "Simple quadratic function with single global minimum at origin",
        [[0.0, 0.0, 0.0, 0.0]],  # global minima
        0.0,  # global minimum value
        Vector{Vector{Float64}}(),  # no additional local minima
        "unimodal",
        :easy,
        ["none"],
        2.0,  # recommended domain size
        [0.0, 0.0, 0.0, 0.0],  # recommended center
        (3, 6),  # degree range
        (50, 200)  # sample count range
    )
    
    # Rosenbrock Function (4D)
    library["Rosenbrock4D"] = EnhancedBenchmarkFunction(
        "Rosenbrock4D",
        x -> sum(100.0 * (x[2:end] - x[1:end-1].^2).^2 + (1.0 .- x[1:end-1]).^2),
        4,
        "Extended Rosenbrock function with narrow curved valley",
        [[1.0, 1.0, 1.0, 1.0]],
        0.0,
        Vector{Vector{Float64}}(),
        "unimodal",
        :hard,
        ["narrow valley", "ill-conditioned", "slow convergence"],
        3.0,
        [0.5, 0.5, 0.5, 0.5],
        (4, 8),
        (100, 500)
    )
    
    # Rastrigin Function (4D)
    library["Rastrigin4D"] = EnhancedBenchmarkFunction(
        "Rastrigin4D",
        x -> 10*length(x) + sum(x.^2 - 10*cos.(2π*x)),
        4,
        "Highly multimodal function with many local minima",
        [[0.0, 0.0, 0.0, 0.0]],
        0.0,
        Vector{Vector{Float64}}(),  # Too many local minima to list
        "multimodal",
        :hard,
        ["many local minima", "high frequency oscillations"],
        2.0,
        [0.0, 0.0, 0.0, 0.0],
        (5, 10),
        (200, 1000)
    )
    
    return library
end

# ============================================================================
# COMPREHENSIVE BENCHMARK EXECUTION
# ============================================================================

"""
Execute comprehensive benchmark with full statistical tracking.
"""
function execute_comprehensive_benchmark(
    func_name::String,
    parameter_set::Dict{String, Any};
    criteria::PassFailCriteria = PassFailCriteria(),
    enable_hessian::Bool = true,
    verbose::Bool = true
)
    
    benchmark_start_time = time()
    test_id = string(uuid4())[1:8]
    
    if verbose
        println("🎯 COMPREHENSIVE BENCHMARK EXECUTION")
        println("=" ^ 50)
        println("Function: $func_name")
        println("Test ID: $test_id")
        println("Started: $(now())")
        println()
    end
    
    # Load function from library
    library = create_benchmark_library()
    if !haskey(library, func_name)
        error("Unknown function: $func_name")
    end
    
    enhanced_func = library[func_name]
    f = enhanced_func.func
    
    # Extract parameters
    center = parameter_set["center"]
    domain_size = parameter_set["domain_size"]
    degree = parameter_set["degree"]
    sample_count = parameter_set["sample_count"]
    l2_tolerance = get(parameter_set, "l2_tolerance", 1e-6)
    
    if verbose
        println("📋 Configuration:")
        println("   Center: $center")
        println("   Domain size: $domain_size")
        println("   Degree: $degree")
        println("   Sample count: $sample_count")
        println("   L2 tolerance: $l2_tolerance")
        println()
    end
    
    # Execute Globtim workflow
    construction_start = time()
    
    try
        # Direct API calls (no fallback wrappers)
        dim = enhanced_func.dimension
        TR = test_input(f; dim=dim, center=center, sample_range=domain_size, GN=sample_count)
        pol = Constructor(TR, degree; basis=:chebyshev, precision=Float64Precision)
        @polyvar x[1:dim]
        solutions = solve_polynomial_system(x, pol)
        df_critical = process_crit_pts(solutions, f, TR)
        df_enhanced = DataFrame()
        df_min = DataFrame()
        if nrow(df_critical) > 0
            df_enhanced, df_min = analyze_critical_points(f, df_critical, TR; enable_hessian=enable_hessian)
        else
            df_enhanced = df_critical
        end
        globtim_results = (
            test_input = TR,
            polynomial = pol,
            critical_points = df_critical,
            critical_points_enhanced = df_enhanced,
            minima = df_min,
        )
        
        construction_time = time() - construction_start
        
        if verbose
            println("✅ Globtim execution completed")
            println("   Construction time: $(round(construction_time, digits=2))s")
            println("   L2 error: $(globtim_results.polynomial.nrm)")
            println("   Critical points: $(nrow(globtim_results.critical_points))")
            println("   Minimizers: $(nrow(globtim_results.minima))")
            println()
        end
        
        # Perform comprehensive analysis
        analysis_start = time()
        result = analyze_benchmark_results(
            globtim_results, enhanced_func, parameter_set, 
            criteria, test_id, construction_time, verbose
        )
        analysis_time = time() - analysis_start
        
        # Update timing
        result = BenchmarkResult(
            result.function_name, result.parameter_set_name, result.test_id, result.timestamp,
            result.domain_size, result.center, result.l2_tolerance, result.degree, result.sample_count,
            result.true_local_minima_known, result.true_global_minimum_known,
            result.known_global_minima, result.known_local_minima,
            result.computed_critical_points, result.function_values, result.gradient_norms,
            result.hessian_eigenvalues, result.critical_point_types,
            result.distances_to_approximant_critical_points, result.distances_to_known_global_minima,
            result.distances_to_known_local_minima, result.recovery_rates,
            construction_time, analysis_time, result.l2_error_achieved, result.vandermonde_condition_number,
            result.overall_status, result.failure_reasons, result.quality_score, result.detailed_checks
        )
        
        if verbose
            println("📊 BENCHMARK COMPLETED")
            println("   Overall Status: $(result.overall_status)")
            println("   Quality Score: $(round(result.quality_score, digits=3))")
            println("   Total Time: $(round(time() - benchmark_start_time, digits=2))s")
            
            if result.overall_status == :FAIL
                println("   Failure Reasons:")
                for reason in result.failure_reasons
                    println("     - $reason")
                end
            end
        end
        
        return result
        
    catch e
        if verbose
            println("❌ Benchmark execution failed: $e")
        end
        
        # Return failure result
        return create_failure_result(func_name, parameter_set, test_id, string(e))
    end
end

"""
Analyze Globtim results and create comprehensive benchmark result.
"""
function analyze_benchmark_results(
    globtim_results, enhanced_func, parameter_set, criteria, test_id, construction_time, verbose
)

    # Extract computed critical points
    computed_points = Vector{Vector{Float64}}()
    function_values = Float64[]
    gradient_norms = Float64[]
    critical_point_types = Symbol[]

    # Process minimizers
    if nrow(globtim_results.minima) > 0
        for i in 1:nrow(globtim_results.minima)
            point = [globtim_results.minima[i, j] for j in 1:enhanced_func.dimension]
            push!(computed_points, point)
            push!(function_values, enhanced_func.func(point))

            # Compute gradient norm
            try
                grad = ForwardDiff.gradient(enhanced_func.func, point)
                push!(gradient_norms, norm(grad))
            catch e
                @warn "Gradient computation failed" point exception=(e, catch_backtrace())
                push!(gradient_norms, Inf)
            end

            push!(critical_point_types, :minimum)
        end
    end

    # Compute distance analysis using existing utilities
    distances_to_global = Float64[]
    recovery_rates = Dict{String, Float64}()

    if !isempty(computed_points) && !isempty(enhanced_func.global_minima)
        min_distances, closest_minima, recovery_rate = compute_min_distances(
            computed_points, enhanced_func.global_minima, tolerance=0.1
        )
        distances_to_global = min_distances
        recovery_rates["global"] = recovery_rate
    end

    # Perform pass/fail analysis
    detailed_checks = Dict{String, Any}()
    failure_reasons = String[]

    # Distance check
    if !isempty(distances_to_global)
        min_distance = minimum(distances_to_global)
        distance_pass = min_distance <= criteria.max_distance_to_global
        detailed_checks["distance_to_global"] = Dict(
            "value" => min_distance,
            "threshold" => criteria.max_distance_to_global,
            "status" => distance_pass ? "PASS" : "FAIL"
        )
        if !distance_pass
            push!(failure_reasons, "Minimum distance to global minimum too large: $min_distance > $(criteria.max_distance_to_global)")
        end
    end

    # L2 error check
    l2_error = globtim_results.polynomial.nrm
    l2_pass = l2_error <= criteria.max_l2_error
    detailed_checks["l2_error"] = Dict(
        "value" => l2_error,
        "threshold" => criteria.max_l2_error,
        "status" => l2_pass ? "PASS" : "FAIL"
    )
    if !l2_pass
        push!(failure_reasons, "L2 error too large: $l2_error > $(criteria.max_l2_error)")
    end

    # Critical points count check
    n_critical = length(computed_points)
    count_pass = n_critical >= criteria.min_critical_points_found
    detailed_checks["critical_points_count"] = Dict(
        "value" => n_critical,
        "threshold" => criteria.min_critical_points_found,
        "status" => count_pass ? "PASS" : "FAIL"
    )
    if !count_pass
        push!(failure_reasons, "Too few critical points found: $n_critical < $(criteria.min_critical_points_found)")
    end

    # Overall status and quality score
    overall_status = isempty(failure_reasons) ? :PASS : :FAIL
    quality_score = compute_quality_score(detailed_checks, recovery_rates)

    return BenchmarkResult(
        enhanced_func.name,
        get(parameter_set, "name", "custom"),
        test_id,
        string(now()),
        parameter_set["domain_size"],
        parameter_set["center"],
        get(parameter_set, "l2_tolerance", 1e-6),
        parameter_set["degree"],
        parameter_set["sample_count"],
        !isempty(enhanced_func.local_minima),
        !isempty(enhanced_func.global_minima),
        enhanced_func.global_minima,
        enhanced_func.local_minima,
        computed_points,
        function_values,
        gradient_norms,
        Vector{Vector{Float64}}(),  # hessian_eigenvalues - would need implementation
        critical_point_types,
        Float64[],  # distances_to_approximant_critical_points - would need implementation
        distances_to_global,
        Float64[],  # distances_to_known_local_minima - would need implementation
        recovery_rates,
        construction_time,
        0.0,  # analysis_time - updated later
        l2_error,
        0.0,  # vandermonde_condition_number - would need implementation
        overall_status,
        failure_reasons,
        quality_score,
        detailed_checks
    )
end

"""
Compute quality score from detailed checks.
"""
function compute_quality_score(detailed_checks, recovery_rates)
    score = 0.0
    total_weight = 0.0

    # Distance score (weight: 0.4)
    if haskey(detailed_checks, "distance_to_global")
        distance_score = detailed_checks["distance_to_global"]["status"] == "PASS" ? 1.0 : 0.0
        score += 0.4 * distance_score
        total_weight += 0.4
    end

    # L2 error score (weight: 0.3)
    if haskey(detailed_checks, "l2_error")
        l2_score = detailed_checks["l2_error"]["status"] == "PASS" ? 1.0 : 0.0
        score += 0.3 * l2_score
        total_weight += 0.3
    end

    # Recovery rate score (weight: 0.3)
    if haskey(recovery_rates, "global")
        recovery_score = min(1.0, recovery_rates["global"])
        score += 0.3 * recovery_score
        total_weight += 0.3
    end

    return total_weight > 0 ? score / total_weight : 0.0
end

"""
Create failure result for failed benchmark execution.
"""
function create_failure_result(func_name, parameter_set, test_id, error_message)
    return BenchmarkResult(
        func_name,
        get(parameter_set, "name", "custom"),
        test_id,
        string(now()),
        get(parameter_set, "domain_size", 0.0),
        get(parameter_set, "center", Float64[]),
        get(parameter_set, "l2_tolerance", 1e-6),
        get(parameter_set, "degree", 0),
        get(parameter_set, "sample_count", 0),
        false, false,
        Vector{Vector{Float64}}(), Vector{Vector{Float64}}(),
        Vector{Vector{Float64}}(), Float64[], Float64[],
        Vector{Vector{Float64}}(), Symbol[],
        Float64[], Float64[], Float64[],
        Dict{String, Float64}(),
        0.0, 0.0, Inf, Inf,
        :FAIL,
        ["Execution failed: $error_message"],
        0.0,
        Dict{String, Any}()
    )
end

export BenchmarkResult, PassFailCriteria, EnhancedBenchmarkFunction
export execute_comprehensive_benchmark, create_benchmark_library
