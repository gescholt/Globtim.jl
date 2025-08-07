#!/usr/bin/env julia

"""
Benchmark Utilities for Globtim Testing

Collection of utility functions for benchmark analysis, including the 
compute_min_distances function and other analysis tools.
"""

using LinearAlgebra
using Statistics

"""
    compute_min_distances(critical_points, known_minima; tolerance=1e-6)

Compute minimum distances from critical points to known global minima.
This is the key function for validating benchmark results.

# Arguments
- `critical_points`: Vector of critical points found by Globtim
- `known_minima`: Vector of known global minimum locations  
- `tolerance`: Distance tolerance for considering points equivalent

# Returns
- `min_distances`: Vector of minimum distances for each critical point
- `closest_minima`: Vector of indices of closest known minima
- `recovery_rate`: Fraction of known minima recovered within tolerance
"""
function compute_min_distances(critical_points::Vector, known_minima::Vector; tolerance=1e-6)
    n_critical = length(critical_points)
    n_minima = length(known_minima)
    
    if n_critical == 0
        return Float64[], Int[], 0.0
    end
    
    if n_minima == 0
        return fill(Inf, n_critical), fill(0, n_critical), 0.0
    end
    
    # Compute distance matrix
    distances = zeros(n_critical, n_minima)
    for i in 1:n_critical
        for j in 1:n_minima
            distances[i, j] = norm(critical_points[i] - known_minima[j])
        end
    end
    
    # Find minimum distance for each critical point
    min_distances = [minimum(distances[i, :]) for i in 1:n_critical]
    closest_minima = [argmin(distances[i, :]) for i in 1:n_critical]
    
    # Compute recovery rate
    recovered_minima = Set{Int}()
    for i in 1:n_critical
        if min_distances[i] <= tolerance
            push!(recovered_minima, closest_minima[i])
        end
    end
    
    recovery_rate = length(recovered_minima) / n_minima
    
    return min_distances, closest_minima, recovery_rate
end

"""
    analyze_convergence(trajectory; window_size=10)

Analyze convergence properties of optimization trajectory.
"""
function analyze_convergence(trajectory::Vector{Float64}; window_size=10)
    n = length(trajectory)
    if n < window_size
        return Dict("status" => "insufficient_data")
    end
    
    # Compute moving average of improvements
    improvements = -diff(trajectory)  # Negative because we want decreasing values
    
    # Sliding window analysis
    convergence_rates = Float64[]
    for i in window_size:n-1
        window = improvements[i-window_size+1:i]
        rate = mean(window)
        push!(convergence_rates, rate)
    end
    
    # Overall statistics
    final_improvement = improvements[end]
    mean_rate = mean(convergence_rates)
    std_rate = std(convergence_rates)
    
    # Convergence assessment
    is_converging = mean_rate > 0 && final_improvement > -1e-10
    convergence_quality = is_converging ? "good" : "poor"
    
    return Dict(
        "status" => "analyzed",
        "final_value" => trajectory[end],
        "total_improvement" => trajectory[1] - trajectory[end],
        "mean_convergence_rate" => mean_rate,
        "std_convergence_rate" => std_rate,
        "final_improvement" => final_improvement,
        "is_converging" => is_converging,
        "convergence_quality" => convergence_quality,
        "trajectory_length" => n
    )
end

"""
    compute_sparsification_metrics(coefficients; threshold=1e-10)

Analyze sparsification properties of polynomial coefficients.
"""
function compute_sparsification_metrics(coefficients::Vector{Float64}; threshold=1e-10)
    n_total = length(coefficients)
    n_nonzero = sum(abs.(coefficients) .> threshold)
    n_zero = n_total - n_nonzero
    
    sparsity_ratio = n_zero / n_total
    
    # Coefficient magnitude analysis
    nonzero_coeffs = coefficients[abs.(coefficients) .> threshold]
    
    if length(nonzero_coeffs) > 0
        max_coeff = maximum(abs.(nonzero_coeffs))
        min_coeff = minimum(abs.(nonzero_coeffs))
        mean_coeff = mean(abs.(nonzero_coeffs))
        dynamic_range = log10(max_coeff / min_coeff)
    else
        max_coeff = min_coeff = mean_coeff = dynamic_range = 0.0
    end
    
    return Dict(
        "total_coefficients" => n_total,
        "nonzero_coefficients" => n_nonzero,
        "zero_coefficients" => n_zero,
        "sparsity_ratio" => sparsity_ratio,
        "max_coefficient" => max_coeff,
        "min_coefficient" => min_coeff,
        "mean_coefficient" => mean_coeff,
        "dynamic_range_log10" => dynamic_range
    )
end

"""
    validate_benchmark_result(result, expected; tolerances=Dict())

Validate benchmark result against expected values with specified tolerances.
"""
function validate_benchmark_result(result::Dict, expected::Dict; 
                                 tolerances=Dict("distance" => 0.1, "value" => 1e-3))
    
    validation = Dict{String, Any}()
    validation["overall_status"] = "PASS"
    validation["checks"] = Dict{String, Any}()
    
    # Distance validation
    if haskey(result, "distance_to_global") && haskey(expected, "distance_to_global")
        distance_diff = abs(result["distance_to_global"] - expected["distance_to_global"])
        distance_ok = distance_diff <= get(tolerances, "distance", 0.1)
        
        validation["checks"]["distance"] = Dict(
            "status" => distance_ok ? "PASS" : "FAIL",
            "actual" => result["distance_to_global"],
            "expected" => expected["distance_to_global"],
            "difference" => distance_diff,
            "tolerance" => get(tolerances, "distance", 0.1)
        )
        
        if !distance_ok
            validation["overall_status"] = "FAIL"
        end
    end
    
    # Value validation
    if haskey(result, "best_value") && haskey(expected, "best_value")
        value_diff = abs(result["best_value"] - expected["best_value"])
        value_ok = value_diff <= get(tolerances, "value", 1e-3)
        
        validation["checks"]["value"] = Dict(
            "status" => value_ok ? "PASS" : "FAIL",
            "actual" => result["best_value"],
            "expected" => expected["best_value"],
            "difference" => value_diff,
            "tolerance" => get(tolerances, "value", 1e-3)
        )
        
        if !value_ok
            validation["overall_status"] = "FAIL"
        end
    end
    
    # Recovery rate validation
    if haskey(result, "recovery_rate") && haskey(expected, "recovery_rate")
        recovery_diff = abs(result["recovery_rate"] - expected["recovery_rate"])
        recovery_ok = recovery_diff <= get(tolerances, "recovery", 0.2)
        
        validation["checks"]["recovery"] = Dict(
            "status" => recovery_ok ? "PASS" : "FAIL",
            "actual" => result["recovery_rate"],
            "expected" => expected["recovery_rate"],
            "difference" => recovery_diff,
            "tolerance" => get(tolerances, "recovery", 0.2)
        )
        
        if !recovery_ok
            validation["overall_status"] = "FAIL"
        end
    end
    
    return validation
end

"""
    create_benchmark_report(results::Vector{Dict})

Create comprehensive benchmark report from multiple test results.
"""
function create_benchmark_report(results::Vector{Dict})
    if isempty(results)
        return "No results to report"
    end
    
    report = String[]
    push!(report, "🎯 BENCHMARK RESULTS REPORT")
    push!(report, "=" ^ 50)
    push!(report, "Generated: $(now())")
    push!(report, "Total Tests: $(length(results))")
    push!(report, "")
    
    # Summary statistics
    successful_tests = [r for r in results if get(r, "success", false)]
    success_rate = length(successful_tests) / length(results)
    
    push!(report, "📊 SUMMARY STATISTICS")
    push!(report, "-" ^ 30)
    push!(report, "Success Rate: $(round(success_rate * 100, digits=1))%")
    push!(report, "Successful Tests: $(length(successful_tests))")
    push!(report, "Failed Tests: $(length(results) - length(successful_tests))")
    push!(report, "")
    
    if !isempty(successful_tests)
        # Distance analysis
        distances = [get(r, "distance_to_global", Inf) for r in successful_tests]
        push!(report, "🎯 DISTANCE TO GLOBAL MINIMUM")
        push!(report, "-" ^ 30)
        push!(report, "Mean Distance: $(round(mean(distances), digits=6))")
        push!(report, "Std Distance: $(round(std(distances), digits=6))")
        push!(report, "Min Distance: $(round(minimum(distances), digits=6))")
        push!(report, "Max Distance: $(round(maximum(distances), digits=6))")
        push!(report, "")
        
        # Function value analysis
        values = [get(r, "best_value", Inf) for r in successful_tests]
        push!(report, "📈 FUNCTION VALUES")
        push!(report, "-" ^ 30)
        push!(report, "Mean Best Value: $(round(mean(values), digits=6))")
        push!(report, "Std Best Value: $(round(std(values), digits=6))")
        push!(report, "Min Best Value: $(round(minimum(values), digits=6))")
        push!(report, "Max Best Value: $(round(maximum(values), digits=6))")
        push!(report, "")
    end
    
    # Individual test details
    push!(report, "📋 INDIVIDUAL TEST RESULTS")
    push!(report, "-" ^ 30)
    for (i, result) in enumerate(results)
        status = get(result, "success", false) ? "✅" : "❌"
        func_name = get(result, "function_name", "Unknown")
        param_set = get(result, "parameter_set", "Unknown")
        
        push!(report, "$status Test $i: $func_name ($param_set)")
        
        if get(result, "success", false)
            distance = get(result, "distance_to_global", "N/A")
            value = get(result, "best_value", "N/A")
            push!(report, "   Distance: $distance, Value: $value")
        else
            error_msg = get(result, "error", "Unknown error")
            push!(report, "   Error: $error_msg")
        end
        push!(report, "")
    end
    
    return join(report, "\n")
end

# Export main functions
export compute_min_distances, analyze_convergence, compute_sparsification_metrics,
       validate_benchmark_result, create_benchmark_report
