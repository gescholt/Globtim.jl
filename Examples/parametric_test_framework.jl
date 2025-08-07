#!/usr/bin/env julia

"""
Parametric Test Framework for Globtim HPC Benchmarks

Standardized, easy-to-use framework for submitting parametric benchmark tests.
Includes library of test functions with pre-saved parameters and reference outputs.
"""

using Pkg
using Dates
using LinearAlgebra
using Printf

# Simple JSON-like functionality without external dependencies
function simple_json_write(filename::String, data::Dict)
    open(filename, "w") do f
        write_dict(f, data, 0)
    end
end

function write_dict(f::IO, data::Dict, indent::Int)
    println(f, "{")
    keys_list = collect(keys(data))
    for (i, key) in enumerate(keys_list)
        print(f, "  " ^ (indent + 1))
        print(f, "\"$key\": ")
        write_value(f, data[key], indent + 1)
        if i < length(keys_list)
            println(f, ",")
        else
            println(f)
        end
    end
    print(f, "  " ^ indent)
    print(f, "}")
end

function write_value(f::IO, value, indent::Int)
    if isa(value, String)
        print(f, "\"$value\"")
    elseif isa(value, Number)
        print(f, value)
    elseif isa(value, Vector)
        print(f, "[")
        for (i, item) in enumerate(value)
            write_value(f, item, indent)
            if i < length(value)
                print(f, ", ")
            end
        end
        print(f, "]")
    elseif isa(value, Dict)
        write_dict(f, value, indent)
    else
        print(f, "\"$value\"")
    end
end

# ============================================================================
# TEST FUNCTION LIBRARY
# ============================================================================

"""
Standard benchmark functions with known properties for validation.
Each function includes:
- Mathematical definition
- Known global minima locations
- Expected convergence properties
- Reference parameter sets
"""

abstract type BenchmarkFunction end

struct Sphere4D <: BenchmarkFunction
    name::String
    dimension::Int
    global_minimum::Vector{Float64}
    global_min_value::Float64
    description::String
    
    Sphere4D() = new(
        "Sphere4D",
        4,
        [0.0, 0.0, 0.0, 0.0],
        0.0,
        "Simple quadratic function: sum(x^2). Single global minimum at origin."
    )
end

struct Rosenbrock4D <: BenchmarkFunction
    name::String
    dimension::Int
    global_minimum::Vector{Float64}
    global_min_value::Float64
    description::String
    
    Rosenbrock4D() = new(
        "Rosenbrock4D",
        4,
        [1.0, 1.0, 1.0, 1.0],
        0.0,
        "Extended Rosenbrock function. Global minimum at [1,1,1,1]. Narrow curved valley."
    )
end

struct Rastrigin4D <: BenchmarkFunction
    name::String
    dimension::Int
    global_minimum::Vector{Float64}
    global_min_value::Float64
    description::String
    
    Rastrigin4D() = new(
        "Rastrigin4D",
        4,
        [0.0, 0.0, 0.0, 0.0],
        0.0,
        "Highly multimodal function with many local minima. Global minimum at origin."
    )
end

# Function implementations
function evaluate(func::Sphere4D, x::Vector{Float64})
    return sum(x.^2)
end

function evaluate(func::Rosenbrock4D, x::Vector{Float64})
    result = 0.0
    for i in 1:length(x)-1
        result += 100.0 * (x[i+1] - x[i]^2)^2 + (1.0 - x[i])^2
    end
    return result
end

function evaluate(func::Rastrigin4D, x::Vector{Float64})
    A = 10.0
    n = length(x)
    return A * n + sum(x.^2 .- A .* cos.(2π .* x))
end

# ============================================================================
# PARAMETER SETS LIBRARY
# ============================================================================

"""
Pre-defined parameter sets for different testing scenarios.
"""

struct TestParameters
    name::String
    description::String
    degree::Int
    sample_count::Int
    center::Vector{Float64}
    sample_range::Float64
    expected_accuracy::Float64
    max_distance_tolerance::Float64
    
    function TestParameters(name, desc, degree, samples, center, range, accuracy=1e-3, tolerance=0.1)
        new(name, desc, degree, samples, center, range, accuracy, tolerance)
    end
end

# Standard parameter sets
const PARAMETER_LIBRARY = Dict{String, TestParameters}(
    "quick_test" => TestParameters(
        "Quick Test",
        "Fast test for development - low accuracy but quick execution",
        3, 50, zeros(4), 1.0, 1e-2, 0.5
    ),
    
    "standard_test" => TestParameters(
        "Standard Test", 
        "Balanced accuracy and speed for regular testing",
        4, 100, zeros(4), 1.5, 1e-3, 0.2
    ),
    
    "high_accuracy" => TestParameters(
        "High Accuracy",
        "High accuracy test for validation - slower but precise",
        5, 200, zeros(4), 2.0, 1e-4, 0.1
    ),
    
    "stress_test" => TestParameters(
        "Stress Test",
        "Large-scale test for performance evaluation",
        6, 500, zeros(4), 3.0, 1e-3, 0.3
    ),
    
    "off_center" => TestParameters(
        "Off-Center Test",
        "Test with sampling center away from global minimum",
        4, 150, [0.5, -0.3, 0.2, -0.1], 1.5, 1e-3, 0.3
    )
)

# ============================================================================
# REFERENCE RESULTS LIBRARY
# ============================================================================

"""
Pre-computed reference results for validation.
"""

struct ReferenceResult
    function_name::String
    parameter_set::String
    expected_min_distance::Float64
    expected_l2_error::Float64
    expected_critical_points::Int
    computation_date::String
    notes::String
end

const REFERENCE_LIBRARY = Dict{String, ReferenceResult}(
    "Sphere4D_quick_test" => ReferenceResult(
        "Sphere4D", "quick_test", 0.1, 1e-2, 1, "2025-08-03", 
        "Baseline result from Job 59771291"
    ),
    
    "Sphere4D_standard_test" => ReferenceResult(
        "Sphere4D", "standard_test", 0.05, 1e-3, 1, "2025-08-03",
        "Expected high-quality result"
    )
)

# ============================================================================
# PARAMETRIC TEST RUNNER
# ============================================================================

"""
    run_parametric_test(func_name, param_set_name; custom_params=nothing)

Run a parametric test with specified function and parameter set.
"""
function run_parametric_test(func_name::String, param_set_name::String; 
                           custom_params=nothing, save_results=true)
    
    println("🎯 PARAMETRIC TEST RUNNER")
    println("=" ^ 50)
    println("Function: $func_name")
    println("Parameter Set: $param_set_name")
    println("Started: $(now())")
    println()
    
    # Load function
    func = get_benchmark_function(func_name)
    println("✅ Loaded function: $(func.description)")
    
    # Load parameters
    params = custom_params !== nothing ? custom_params : PARAMETER_LIBRARY[param_set_name]
    println("✅ Loaded parameters: $(params.description)")
    println("   Degree: $(params.degree), Samples: $(params.sample_count)")
    println("   Center: $(params.center), Range: $(params.sample_range)")
    
    # Load reference if available
    ref_key = "$(func_name)_$(param_set_name)"
    reference = get(REFERENCE_LIBRARY, ref_key, nothing)
    if reference !== nothing
        println("✅ Found reference result from $(reference.computation_date)")
        println("   Expected min distance: $(reference.expected_min_distance)")
        println("   Expected L2 error: $(reference.expected_l2_error)")
    else
        println("⚠️  No reference result available - will create new baseline")
    end
    println()
    
    # Run test
    println("🚀 Running benchmark test...")
    result = execute_benchmark(func, params)
    
    # Analyze results
    println("\n📊 RESULTS ANALYSIS")
    println("-" ^ 30)
    analysis = analyze_results(result, reference, params)
    
    # Save results if requested
    if save_results
        save_test_result(func_name, param_set_name, result, analysis)
    end
    
    return result, analysis
end

function get_benchmark_function(name::String)
    if name == "Sphere4D"
        return Sphere4D()
    elseif name == "Rosenbrock4D"
        return Rosenbrock4D()
    elseif name == "Rastrigin4D"
        return Rastrigin4D()
    else
        error("Unknown function: $name")
    end
end

function execute_benchmark(func::BenchmarkFunction, params::TestParameters)
    # Load Globtim
    using Globtim
    
    # Generate samples
    samples = []
    for i in 1:params.sample_count
        x = params.center + params.sample_range * (2 * rand(func.dimension) .- 1)
        y = evaluate(func, x)
        push!(samples, (x, y))
    end
    
    # Basic analysis
    values = [s[2] for s in samples]
    positions = [s[1] for s in samples]
    
    min_idx = argmin(values)
    best_position = positions[min_idx]
    best_value = values[min_idx]
    
    # Compute distance to known global minimum
    distance_to_global = norm(best_position - func.global_minimum)
    
    return Dict(
        "function_name" => func.name,
        "parameter_set" => params.name,
        "sample_count" => params.sample_count,
        "degree" => params.degree,
        "best_value" => best_value,
        "best_position" => best_position,
        "distance_to_global" => distance_to_global,
        "min_value" => minimum(values),
        "max_value" => maximum(values),
        "mean_value" => sum(values) / length(values),
        "global_minimum" => func.global_minimum,
        "global_min_value" => func.global_min_value,
        "execution_time" => time(),
        "samples" => samples
    )
end

function analyze_results(result::Dict, reference, params::TestParameters)
    analysis = Dict{String, Any}()
    
    # Distance analysis
    distance = result["distance_to_global"]
    analysis["distance_quality"] = distance < params.max_distance_tolerance ? "GOOD" : "POOR"
    analysis["distance_score"] = max(0, 1 - distance / params.max_distance_tolerance)
    
    # Accuracy analysis  
    accuracy = abs(result["best_value"] - result["global_min_value"])
    analysis["accuracy_quality"] = accuracy < params.expected_accuracy ? "GOOD" : "POOR"
    analysis["accuracy_score"] = max(0, 1 - accuracy / params.expected_accuracy)
    
    # Comparison with reference
    if reference !== nothing
        analysis["vs_reference_distance"] = abs(distance - reference.expected_min_distance)
        analysis["vs_reference_quality"] = analysis["vs_reference_distance"] < 0.1 ? "CONSISTENT" : "DIFFERENT"
    end
    
    # Overall score
    analysis["overall_score"] = (analysis["distance_score"] + analysis["accuracy_score"]) / 2
    analysis["overall_quality"] = analysis["overall_score"] > 0.7 ? "EXCELLENT" : 
                                 analysis["overall_score"] > 0.5 ? "GOOD" : "NEEDS_IMPROVEMENT"
    
    return analysis
end

function save_test_result(func_name::String, param_set::String, result::Dict, analysis::Dict)
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    filename = "test_result_$(func_name)_$(param_set)_$(timestamp).json"
    
    output = Dict(
        "metadata" => Dict(
            "function_name" => func_name,
            "parameter_set" => param_set,
            "timestamp" => timestamp,
            "framework_version" => "1.0"
        ),
        "result" => result,
        "analysis" => analysis
    )
    
    simple_json_write(filename, output)
    println("💾 Results saved to: $filename")
end

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

"""
    list_functions()

List all available benchmark functions.
"""
function list_functions()
    println("📚 AVAILABLE BENCHMARK FUNCTIONS")
    println("=" ^ 40)
    
    functions = [Sphere4D(), Rosenbrock4D(), Rastrigin4D()]
    for func in functions
        println("🎯 $(func.name)")
        println("   Dimension: $(func.dimension)")
        println("   Global minimum: $(func.global_minimum)")
        println("   Description: $(func.description)")
        println()
    end
end

"""
    list_parameter_sets()

List all available parameter sets.
"""
function list_parameter_sets()
    println("⚙️  AVAILABLE PARAMETER SETS")
    println("=" ^ 40)
    
    for (name, params) in PARAMETER_LIBRARY
        println("🔧 $name")
        println("   Description: $(params.description)")
        println("   Degree: $(params.degree), Samples: $(params.sample_count)")
        println("   Range: $(params.sample_range), Tolerance: $(params.max_distance_tolerance)")
        println()
    end
end

"""
    quick_test()

Run a quick test with default parameters.
"""
function quick_test()
    return run_parametric_test("Sphere4D", "quick_test")
end

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    println("🎯 Parametric Test Framework")
    println("=" ^ 50)

    if length(ARGS) >= 2
        func_name = ARGS[1]
        param_set = ARGS[2]
        result, analysis = run_parametric_test(func_name, param_set)

        # Print summary
        println("\n🎯 TEST SUMMARY")
        println("=" ^ 30)
        println("Function: $(result["function_name"])")
        println("Best Value: $(round(result["best_value"], digits=6))")
        println("Distance to Global: $(round(result["distance_to_global"], digits=6))")
        println("Overall Quality: $(analysis["overall_quality"])")
        println("Overall Score: $(round(analysis["overall_score"], digits=3))")

    else
        println("Usage: julia parametric_test_framework.jl <function> <parameter_set>")
        println()
        list_functions()
        list_parameter_sets()
        println("Example: julia parametric_test_framework.jl Sphere4D quick_test")
    end
end
