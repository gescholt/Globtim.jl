#!/usr/bin/env julia

"""
Parameter Sweep Runner

Runs individual parameter combinations for systematic benchmarking.
"""

using Dates
using Printf

# Include our core benchmarking framework
include("core_globtim_benchmarking.jl")

function run_parameter_combination(func_name, degree, sample_count, domain_size, results_dir)
    println("🔬 Testing: $func_name (deg=$degree, samples=$sample_count, domain=$domain_size)")
    
    # Create custom parameter set
    params = Dict(
        "degree" => degree,
        "sample_count" => sample_count,
        "domain_size" => domain_size
    )
    
    # Load function library
    library = create_benchmark_library()
    func_info = library[func_name]
    
    # Create test input
    TR = test_input(
        f = func_info.func,
        dim = func_info.dimension,
        center = func_info.recommended_center,
        sample_range = domain_size,
        degree = degree,
        GN = sample_count
    )
    
    start_time = time()
    
    try
        # Execute core workflow
        pol = construct_polynomial_approximation(TR)
        critical_points = find_critical_points(TR, pol)
        
        if !isempty(critical_points)
            refined_points, converged = refine_critical_points(critical_points, func_info.func)
            minima = [refined_points[i] for i in 1:length(refined_points) if converged[i]]
            
            if !isempty(minima)
                hessian_eigenvals, critical_types = analyze_hessians(minima, func_info.func)
                actual_minima = [minima[i] for i in 1:length(minima) if critical_types[i] == :minimum]
                
                if !isempty(actual_minima)
                    distances_to_global, distances_to_local, recovery_rates = compute_distance_analysis(
                        actual_minima, func_info.global_minima, func_info.local_minima
                    )
                    
                    # Compute metrics
                    function_values = [func_info.func(pt) for pt in actual_minima]
                    
                    # Pass/fail analysis
                    distance_pass = !isempty(distances_to_global) && minimum(distances_to_global) < 0.1
                    l2_pass = pol.nrm < 1e-3
                    recovery_pass = get(recovery_rates, "global", 0.0) >= 0.8
                    
                    overall_pass = distance_pass && l2_pass && recovery_pass
                    quality_score = (distance_pass + l2_pass + get(recovery_rates, "global", 0.0)) / 3
                    
                    # Create result
                    result = Dict(
                        "function_name" => func_name,
                        "parameters" => params,
                        "timestamp" => string(now()),
                        "execution_time" => time() - start_time,
                        "l2_error" => pol.nrm,
                        "condition_number" => pol.cond_vandermonde,
                        "critical_points_found" => length(critical_points),
                        "minima_found" => length(actual_minima),
                        "distances_to_global" => distances_to_global,
                        "recovery_rates" => recovery_rates,
                        "overall_pass" => overall_pass,
                        "quality_score" => quality_score,
                        "distance_pass" => distance_pass,
                        "l2_pass" => l2_pass,
                        "recovery_pass" => recovery_pass
                    )
                    
                    # Save result
                    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
                    filename = "$results_dir/result_$(func_name)_deg$(degree)_s$(sample_count)_d$(domain_size)_$(timestamp).json"
                    
                    open(filename, "w") do f
                        println(f, "{")
                        for (i, (key, val)) in enumerate(result)
                            if isa(val, String)
                                println(f, "  \"$key\": \"$val\"$(i < length(result) ? "," : "")")
                            elseif isa(val, Vector)
                                println(f, "  \"$key\": [$(join(val, ", "))]$(i < length(result) ? "," : "")")
                            elseif isa(val, Dict)
                                println(f, "  \"$key\": {")
                                for (j, (k, v)) in enumerate(val)
                                    println(f, "    \"$k\": $v$(j < length(val) ? "," : "")")
                                end
                                println(f, "  }$(i < length(result) ? "," : "")")
                            else
                                println(f, "  \"$key\": $val$(i < length(result) ? "," : "")")
                            end
                        end
                        println(f, "}")
                    end
                    
                    println("✅ Success: $(overall_pass ? "PASS" : "FAIL") (quality: $(round(quality_score, digits=3)))")
                    return result
                end
            end
        end
        
        # Failure case
        println("❌ Failed: Insufficient critical points")
        return Dict("function_name" => func_name, "parameters" => params, "overall_pass" => false, "quality_score" => 0.0)
        
    catch e
        println("❌ Error: $e")
        return Dict("function_name" => func_name, "parameters" => params, "overall_pass" => false, "quality_score" => 0.0, "error" => string(e))
    end
end

# Main execution
if length(ARGS) >= 5
    func_name = ARGS[1]
    degree = parse(Int, ARGS[2])
    sample_count = parse(Int, ARGS[3])
    domain_size = parse(Float64, ARGS[4])
    results_dir = ARGS[5]
    
    result = run_parameter_combination(func_name, degree, sample_count, domain_size, results_dir)
else
    println("Usage: julia parameter_sweep_runner.jl <function> <degree> <sample_count> <domain_size> <results_dir>")
end
