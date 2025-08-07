#!/usr/bin/env julia

"""
Full Globtim Parametric Test (No Plotting Dependencies)

Uses complete Globtim workflow including:
- Polynomial approximation construction
- Critical point analysis with polynomial system solving
- BFGS refinement and Hessian analysis
- Complete statistical tracking

But excludes plotting functionality to avoid dependency conflicts.
"""

# Load Globtim with core functionality only
using Globtim
using DataFrames
using Statistics
using LinearAlgebra
using Dates
using Printf
using DynamicPolynomials

# Simple JSON output (dependency-free)
function write_comprehensive_json(filename::String, data::Dict)
    open(filename, "w") do f
        println(f, "{")
        write_dict_content(f, data, 1)
        println(f, "}")
    end
end

function write_dict_content(f::IO, data::Dict, indent::Int)
    keys_list = collect(keys(data))
    for (i, key) in enumerate(keys_list)
        print(f, "  " ^ indent)
        print(f, "\"$key\": ")
        write_json_value(f, data[key], indent)
        if i < length(keys_list)
            println(f, ",")
        else
            println(f)
        end
    end
end

function write_json_value(f::IO, value, indent::Int)
    if isa(value, String)
        print(f, "\"$value\"")
    elseif isa(value, Number)
        print(f, value)
    elseif isa(value, Bool)
        print(f, value ? "true" : "false")
    elseif isa(value, Vector)
        print(f, "[")
        for (i, item) in enumerate(value)
            write_json_value(f, item, indent)
            if i < length(value)
                print(f, ", ")
            end
        end
        print(f, "]")
    elseif isa(value, Dict)
        println(f, "{")
        write_dict_content(f, value, indent + 1)
        print(f, "  " ^ indent)
        print(f, "}")
    else
        print(f, "\"$value\"")
    end
end

# Enhanced benchmark functions with known solutions
function get_enhanced_function(name::String)
    if name == "Sphere4D"
        return (
            func = x -> sum(x.^2),
            global_minima = [[0.0, 0.0, 0.0, 0.0]],
            global_min_value = 0.0,
            local_minima = Vector{Vector{Float64}}(),
            description = "Simple quadratic function with single global minimum"
        )
    elseif name == "Rosenbrock4D"
        return (
            func = x -> sum(100.0 * (x[2:end] - x[1:end-1].^2).^2 + (1.0 .- x[1:end-1]).^2),
            global_minima = [[1.0, 1.0, 1.0, 1.0]],
            global_min_value = 0.0,
            local_minima = Vector{Vector{Float64}}(),
            description = "Extended Rosenbrock function with narrow curved valley"
        )
    elseif name == "Rastrigin4D"
        return (
            func = x -> 10*length(x) + sum(x.^2 - 10*cos.(2π*x)),
            global_minima = [[0.0, 0.0, 0.0, 0.0]],
            global_min_value = 0.0,
            local_minima = Vector{Vector{Float64}}(),  # Too many to list
            description = "Highly multimodal function with many local minima"
        )
    else
        error("Unknown function: $name")
    end
end

# Enhanced parameter sets
function get_enhanced_parameter_set(name::String)
    if name == "quick_test"
        return Dict(
            "degree" => 4,
            "sample_count" => 100,
            "center" => [0.0, 0.0, 0.0, 0.0],
            "sample_range" => 1.5,
            "basis" => :chebyshev,
            "precision" => Float64Precision,
            "enable_hessian" => true,
            "description" => "Fast test with moderate accuracy"
        )
    elseif name == "standard_test"
        return Dict(
            "degree" => 6,
            "sample_count" => 200,
            "center" => [0.0, 0.0, 0.0, 0.0],
            "sample_range" => 2.0,
            "basis" => :chebyshev,
            "precision" => Float64Precision,
            "enable_hessian" => true,
            "description" => "Balanced accuracy and performance"
        )
    elseif name == "high_accuracy"
        return Dict(
            "degree" => 8,
            "sample_count" => 500,
            "center" => [0.0, 0.0, 0.0, 0.0],
            "sample_range" => 2.5,
            "basis" => :chebyshev,
            "precision" => Float64Precision,
            "enable_hessian" => true,
            "description" => "High accuracy test with comprehensive analysis"
        )
    else
        error("Unknown parameter set: $name")
    end
end

# Distance computation using existing Globtim utilities
function compute_comprehensive_distances(computed_points::Vector{Vector{Float64}}, 
                                       known_global::Vector{Vector{Float64}},
                                       known_local::Vector{Vector{Float64}})
    
    distances_to_global = Float64[]
    distances_to_local = Float64[]
    recovery_rates = Dict{String, Float64}()
    
    if !isempty(computed_points)
        # Distance to global minima
        if !isempty(known_global)
            for point in computed_points
                min_dist = minimum([norm(point - global_min) for global_min in known_global])
                push!(distances_to_global, min_dist)
            end
            
            # Recovery rate for global minima
            tolerance = 0.1
            recovered_global = Set{Int}()
            for (i, point) in enumerate(computed_points)
                for (j, global_min) in enumerate(known_global)
                    if norm(point - global_min) <= tolerance
                        push!(recovered_global, j)
                    end
                end
            end
            recovery_rates["global"] = length(recovered_global) / length(known_global)
        end
        
        # Distance to local minima
        if !isempty(known_local)
            for point in computed_points
                min_dist = minimum([norm(point - local_min) for local_min in known_local])
                push!(distances_to_local, min_dist)
            end
            
            # Recovery rate for local minima
            tolerance = 0.1
            recovered_local = Set{Int}()
            for (i, point) in enumerate(computed_points)
                for (j, local_min) in enumerate(known_local)
                    if norm(point - local_min) <= tolerance
                        push!(recovered_local, j)
                    end
                end
            end
            recovery_rates["local"] = length(recovered_local) / length(known_local)
        end
    end
    
    return distances_to_global, distances_to_local, recovery_rates
end

# Main comprehensive parametric test
function run_full_globtim_parametric_test(function_name::String, parameter_set_name::String)
    println("🎯 FULL GLOBTIM PARAMETRIC TEST")
    println("=" ^ 50)
    println("Function: $function_name")
    println("Parameter Set: $parameter_set_name")
    println("Started: $(now())")
    println()
    
    # Get function and parameters
    func_info = get_enhanced_function(function_name)
    params = get_enhanced_parameter_set(parameter_set_name)
    
    println("📋 Configuration:")
    println("   Function: $function_name")
    println("   Description: $(func_info.description)")
    println("   Global minima: $(length(func_info.global_minima)) known")
    println("   Center: $(params["center"])")
    println("   Sample range: $(params["sample_range"])")
    println("   Degree: $(params["degree"])")
    println("   Sample count: $(params["sample_count"])")
    println("   Basis: $(params["basis"])")
    println("   Enable Hessian: $(params["enable_hessian"])")
    println()
    
    # Execute full Globtim workflow
    println("🚀 Executing Globtim workflow...")
    workflow_start_time = time()
    
    try
        # Use safe_globtim_workflow for robust execution
        globtim_results = safe_globtim_workflow(
            func_info.func,
            dim = 4,
            center = params["center"],
            sample_range = params["sample_range"],
            degree = params["degree"],
            GN = params["sample_count"],
            enable_hessian = params["enable_hessian"],
            basis = params["basis"],
            precision = params["precision"],
            max_retries = 3
        )
        
        workflow_time = time() - workflow_start_time
        
        println("✅ Globtim workflow completed successfully!")
        println("   Construction time: $(round(workflow_time, digits=2))s")
        println("   L2 error: $(globtim_results.polynomial.nrm)")
        println("   Condition number: $(globtim_results.polynomial.cond_vandermonde)")
        println("   Critical points found: $(nrow(globtim_results.critical_points))")
        println("   Minimizers identified: $(nrow(globtim_results.minima))")
        println()
        
        # Extract computed results
        computed_critical_points = Vector{Vector{Float64}}()
        computed_minima = Vector{Vector{Float64}}()
        function_values = Float64[]
        gradient_norms = Float64[]
        critical_point_types = Symbol[]
        
        # Process all critical points
        if nrow(globtim_results.critical_points) > 0
            for i in 1:nrow(globtim_results.critical_points)
                point = [globtim_results.critical_points[i, j] for j in 1:4]
                push!(computed_critical_points, point)
                push!(function_values, func_info.func(point))
                
                # Compute gradient norm
                try
                    grad = ForwardDiff.gradient(func_info.func, point)
                    push!(gradient_norms, norm(grad))
                catch
                    push!(gradient_norms, Inf)
                end
                
                # Determine type (simplified)
                push!(critical_point_types, :critical_point)
            end
        end
        
        # Process minimizers specifically
        if nrow(globtim_results.minima) > 0
            for i in 1:nrow(globtim_results.minima)
                point = [globtim_results.minima[i, j] for j in 1:4]
                push!(computed_minima, point)
            end
        end
        
        # Comprehensive distance analysis
        println("📊 Computing distance analysis...")
        distances_to_global, distances_to_local, recovery_rates = compute_comprehensive_distances(
            computed_minima, func_info.global_minima, func_info.local_minima
        )
        
        # Pass/fail analysis
        println("✅ Performing pass/fail analysis...")
        
        # Distance criteria
        distance_pass = !isempty(distances_to_global) && minimum(distances_to_global) < 0.1
        
        # L2 error criteria
        l2_pass = globtim_results.polynomial.nrm < 1e-3
        
        # Recovery rate criteria
        recovery_pass = get(recovery_rates, "global", 0.0) >= 0.8
        
        # Gradient criteria
        gradient_pass = !isempty(gradient_norms) && minimum(gradient_norms) < 1e-4
        
        # Overall status
        overall_pass = distance_pass && l2_pass && recovery_pass && gradient_pass
        
        # Quality score computation
        distance_score = distance_pass ? 1.0 : 0.0
        l2_score = l2_pass ? 1.0 : 0.0
        recovery_score = get(recovery_rates, "global", 0.0)
        gradient_score = gradient_pass ? 1.0 : 0.0
        quality_score = (distance_score + l2_score + recovery_score + gradient_score) / 4
        
        # Display results
        println("📊 COMPREHENSIVE RESULTS:")
        println("   Critical points found: $(length(computed_critical_points))")
        println("   Minimizers found: $(length(computed_minima))")
        println("   L2 approximation error: $(round(globtim_results.polynomial.nrm, digits=8))")
        println("   Vandermonde condition: $(round(globtim_results.polynomial.cond_vandermonde, digits=2))")
        
        if !isempty(distances_to_global)
            println("   Min distance to global: $(round(minimum(distances_to_global), digits=6))")
            println("   Mean distance to global: $(round(mean(distances_to_global), digits=6))")
        end
        
        if !isempty(gradient_norms)
            println("   Min gradient norm: $(round(minimum(gradient_norms), digits=6))")
            println("   Mean gradient norm: $(round(mean(gradient_norms), digits=6))")
        end
        
        println("   Global recovery rate: $(round(get(recovery_rates, "global", 0.0), digits=3))")
        println()
        
        println("✅ PASS/FAIL ANALYSIS:")
        println("   Distance check: $(distance_pass ? "PASS" : "FAIL")")
        println("   L2 error check: $(l2_pass ? "PASS" : "FAIL")")
        println("   Recovery rate check: $(recovery_pass ? "PASS" : "FAIL")")
        println("   Gradient check: $(gradient_pass ? "PASS" : "FAIL")")
        println("   Overall status: $(overall_pass ? "✅ PASS" : "❌ FAIL")")
        println("   Quality score: $(round(quality_score, digits=3))")
        println()
        
        # Create comprehensive result structure
        result = Dict(
            "test_metadata" => Dict(
                "function_name" => function_name,
                "parameter_set_name" => parameter_set_name,
                "timestamp" => string(now()),
                "test_type" => "full_globtim_parametric",
                "workflow_time" => workflow_time
            ),
            "configuration" => params,
            "function_properties" => Dict(
                "description" => func_info.description,
                "global_minima" => func_info.global_minima,
                "global_min_value" => func_info.global_min_value,
                "local_minima" => func_info.local_minima
            ),
            "globtim_results" => Dict(
                "l2_error" => globtim_results.polynomial.nrm,
                "condition_number" => globtim_results.polynomial.cond_vandermonde,
                "critical_points_count" => length(computed_critical_points),
                "minimizers_count" => length(computed_minima),
                "construction_time" => workflow_time
            ),
            "computed_results" => Dict(
                "critical_points" => computed_critical_points,
                "minimizers" => computed_minima,
                "function_values" => function_values,
                "gradient_norms" => gradient_norms,
                "critical_point_types" => string.(critical_point_types)
            ),
            "distance_analysis" => Dict(
                "distances_to_global_minima" => distances_to_global,
                "distances_to_local_minima" => distances_to_local,
                "recovery_rates" => recovery_rates
            ),
            "pass_fail_analysis" => Dict(
                "distance_pass" => distance_pass,
                "l2_pass" => l2_pass,
                "recovery_pass" => recovery_pass,
                "gradient_pass" => gradient_pass,
                "overall_pass" => overall_pass,
                "quality_score" => quality_score
            )
        )
        
        # Save comprehensive results
        timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
        filename = "full_globtim_$(function_name)_$(parameter_set_name)_$(timestamp).json"
        write_comprehensive_json(filename, result)
        
        println("💾 Comprehensive results saved to: $filename")
        println()
        
        println("🎯 FINAL SUMMARY:")
        println("   Function: $function_name")
        println("   Parameter Set: $parameter_set_name")
        println("   Overall Status: $(overall_pass ? "✅ PASS" : "❌ FAIL")")
        println("   Quality Score: $(round(quality_score, digits=3))")
        println("   L2 Error: $(round(globtim_results.polynomial.nrm, digits=8))")
        println("   Critical Points: $(length(computed_critical_points))")
        println("   Minimizers: $(length(computed_minima))")
        if !isempty(distances_to_global)
            println("   Best Distance to Global: $(round(minimum(distances_to_global), digits=6))")
        end
        println("   Execution Time: $(round(workflow_time, digits=2))s")
        
        return result
        
    catch e
        println("❌ Globtim workflow failed: $e")
        println("Stacktrace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
        
        # Return failure result
        return Dict(
            "test_metadata" => Dict(
                "function_name" => function_name,
                "parameter_set_name" => parameter_set_name,
                "timestamp" => string(now()),
                "test_type" => "full_globtim_parametric",
                "workflow_time" => 0.0
            ),
            "error" => string(e),
            "pass_fail_analysis" => Dict(
                "overall_pass" => false,
                "quality_score" => 0.0
            )
        )
    end
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) >= 2
        function_name = ARGS[1]
        parameter_set = ARGS[2]
        result = run_full_globtim_parametric_test(function_name, parameter_set)
    else
        println("Usage: julia full_globtim_parametric_test.jl <function> <parameter_set>")
        println("Available functions: Sphere4D, Rosenbrock4D, Rastrigin4D")
        println("Available parameter sets: quick_test, standard_test, high_accuracy")
        println("Example: julia full_globtim_parametric_test.jl Sphere4D quick_test")
    end
end
