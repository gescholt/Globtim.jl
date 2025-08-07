#!/usr/bin/env julia

"""
Simple Parametric Test (No External Dependencies)

Lightweight parametric test that works without complex dependencies.
Tests basic functionality and validates the JSON3 fix.
"""

using LinearAlgebra
using Statistics
using Dates
using Printf

# Simple JSON-like output
function write_simple_json(filename::String, data::Dict)
    open(filename, "w") do f
        println(f, "{")
        keys_list = collect(keys(data))
        for (i, key) in enumerate(keys_list)
            print(f, "  \"$key\": ")
            if isa(data[key], String)
                print(f, "\"$(data[key])\"")
            elseif isa(data[key], Vector)
                print(f, "[")
                for (j, item) in enumerate(data[key])
                    print(f, item)
                    if j < length(data[key])
                        print(f, ", ")
                    end
                end
                print(f, "]")
            else
                print(f, data[key])
            end
            if i < length(keys_list)
                println(f, ",")
            else
                println(f)
            end
        end
        println(f, "}")
    end
end

# Simple benchmark functions
function sphere_4d(x::Vector{Float64})
    return sum(x.^2)
end

function rosenbrock_4d(x::Vector{Float64})
    result = 0.0
    for i in 1:length(x)-1
        result += 100.0 * (x[i+1] - x[i]^2)^2 + (1.0 - x[i])^2
    end
    return result
end

function rastrigin_4d(x::Vector{Float64})
    A = 10.0
    n = length(x)
    return A * n + sum(x.^2 .- A .* cos.(2π .* x))
end

# Get function by name
function get_function(name::String)
    if name == "Sphere4D"
        return sphere_4d, [0.0, 0.0, 0.0, 0.0], 0.0
    elseif name == "Rosenbrock4D"
        return rosenbrock_4d, [1.0, 1.0, 1.0, 1.0], 0.0
    elseif name == "Rastrigin4D"
        return rastrigin_4d, [0.0, 0.0, 0.0, 0.0], 0.0
    else
        error("Unknown function: $name")
    end
end

# Parameter sets
function get_parameter_set(name::String)
    if name == "quick_test"
        return Dict(
            "degree" => 3,
            "sample_count" => 50,
            "center" => [0.0, 0.0, 0.0, 0.0],
            "sample_range" => 1.0,
            "description" => "Fast test for development"
        )
    elseif name == "standard_test"
        return Dict(
            "degree" => 4,
            "sample_count" => 100,
            "center" => [0.0, 0.0, 0.0, 0.0],
            "sample_range" => 1.5,
            "description" => "Balanced accuracy and speed"
        )
    else
        error("Unknown parameter set: $name")
    end
end

# Distance computation
function compute_min_distances(points::Vector{Vector{Float64}}, targets::Vector{Vector{Float64}})
    if isempty(points) || isempty(targets)
        return Float64[], 0.0
    end
    
    min_distances = Float64[]
    for point in points
        min_dist = minimum([norm(point - target) for target in targets])
        push!(min_distances, min_dist)
    end
    
    # Recovery rate (points within tolerance of 0.1)
    recovery_rate = sum(min_distances .< 0.1) / length(targets)
    
    return min_distances, recovery_rate
end

# Main parametric test function
function run_simple_parametric_test(function_name::String, parameter_set_name::String)
    println("🎯 SIMPLE PARAMETRIC TEST")
    println("=" ^ 40)
    println("Function: $function_name")
    println("Parameter Set: $parameter_set_name")
    println("Started: $(now())")
    println()
    
    # Get function and parameters
    func, global_minimum, global_min_value = get_function(function_name)
    params = get_parameter_set(parameter_set_name)
    
    println("📋 Configuration:")
    println("   Function: $function_name")
    println("   Global minimum: $global_minimum")
    println("   Center: $(params["center"])")
    println("   Sample range: $(params["sample_range"])")
    println("   Degree: $(params["degree"])")
    println("   Sample count: $(params["sample_count"])")
    println()
    
    # Generate samples
    println("🔬 Generating samples...")
    samples = []
    for i in 1:params["sample_count"]
        x = params["center"] + params["sample_range"] * (2 * rand(4) .- 1)
        y = func(x)
        push!(samples, (x, y))
    end
    
    # Basic analysis
    values = [s[2] for s in samples]
    positions = [s[1] for s in samples]
    
    min_idx = argmin(values)
    best_position = positions[min_idx]
    best_value = values[min_idx]
    
    # Compute distance to global minimum
    distance_to_global = norm(best_position - global_minimum)
    
    # Compute gradient norm at best point
    h = 1e-8
    grad_norm = 0.0
    for i in 1:4
        x_plus = copy(best_position)
        x_minus = copy(best_position)
        x_plus[i] += h
        x_minus[i] -= h
        grad_i = (func(x_plus) - func(x_minus)) / (2 * h)
        grad_norm += grad_i^2
    end
    grad_norm = sqrt(grad_norm)
    
    # Pass/fail analysis
    distance_pass = distance_to_global < 0.1
    value_pass = abs(best_value - global_min_value) < 1e-3
    gradient_pass = grad_norm < 1e-2
    
    overall_pass = distance_pass && value_pass && gradient_pass
    
    # Quality score
    distance_score = max(0, 1 - distance_to_global / 0.1)
    value_score = max(0, 1 - abs(best_value - global_min_value) / 1e-3)
    gradient_score = max(0, 1 - grad_norm / 1e-2)
    quality_score = (distance_score + value_score + gradient_score) / 3
    
    println("📊 RESULTS:")
    println("   Best position: [$(join([round(x, digits=4) for x in best_position], ", "))]")
    println("   Best value: $(round(best_value, digits=6))")
    println("   Distance to global: $(round(distance_to_global, digits=6))")
    println("   Gradient norm: $(round(grad_norm, digits=6))")
    println("   Min sample value: $(round(minimum(values), digits=6))")
    println("   Max sample value: $(round(maximum(values), digits=6))")
    println("   Mean sample value: $(round(mean(values), digits=6))")
    println()
    
    println("✅ PASS/FAIL ANALYSIS:")
    println("   Distance check: $(distance_pass ? "PASS" : "FAIL") ($(round(distance_to_global, digits=6)) < 0.1)")
    println("   Value check: $(value_pass ? "PASS" : "FAIL") (error: $(round(abs(best_value - global_min_value), digits=6)))")
    println("   Gradient check: $(gradient_pass ? "PASS" : "FAIL") (norm: $(round(grad_norm, digits=6)))")
    println("   Overall status: $(overall_pass ? "PASS" : "FAIL")")
    println("   Quality score: $(round(quality_score, digits=3))")
    println()
    
    # Create result dictionary
    result = Dict(
        "function_name" => function_name,
        "parameter_set_name" => parameter_set_name,
        "timestamp" => string(now()),
        "test_type" => "simple_parametric",
        "configuration" => params,
        "results" => Dict(
            "best_position" => best_position,
            "best_value" => best_value,
            "distance_to_global" => distance_to_global,
            "gradient_norm" => grad_norm,
            "sample_statistics" => Dict(
                "min_value" => minimum(values),
                "max_value" => maximum(values),
                "mean_value" => mean(values),
                "sample_count" => length(values)
            )
        ),
        "pass_fail_analysis" => Dict(
            "distance_pass" => distance_pass,
            "value_pass" => value_pass,
            "gradient_pass" => gradient_pass,
            "overall_pass" => overall_pass,
            "quality_score" => quality_score
        ),
        "known_solution" => Dict(
            "global_minimum" => global_minimum,
            "global_min_value" => global_min_value
        )
    )
    
    # Save results
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    filename = "simple_test_$(function_name)_$(parameter_set_name)_$(timestamp).json"
    write_simple_json(filename, result)
    
    println("💾 Results saved to: $filename")
    println()
    
    println("🎯 TEST SUMMARY:")
    println("   Function: $function_name")
    println("   Parameter Set: $parameter_set_name")
    println("   Overall Status: $(overall_pass ? "✅ PASS" : "❌ FAIL")")
    println("   Quality Score: $(round(quality_score, digits=3))")
    println("   Distance to Global: $(round(distance_to_global, digits=6))")
    
    return result
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) >= 2
        function_name = ARGS[1]
        parameter_set = ARGS[2]
        result = run_simple_parametric_test(function_name, parameter_set)
    else
        println("Usage: julia simple_parametric_test.jl <function> <parameter_set>")
        println("Available functions: Sphere4D, Rosenbrock4D, Rastrigin4D")
        println("Available parameter sets: quick_test, standard_test")
        println("Example: julia simple_parametric_test.jl Sphere4D quick_test")
    end
end
