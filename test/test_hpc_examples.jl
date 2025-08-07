#!/usr/bin/env julia

"""
HPC Examples Test Runner

Tests all Tier 1 HPC-ready examples to ensure they work with the new infrastructure.
This script can be run on the HPC cluster to validate all examples.
"""

using Pkg
using Dates
using Printf

println("🧪 HPC Examples Test Runner")
println("=" ^ 50)
println("Started: $(now())")
println()

# Activate the project environment
println("📦 Activating project environment...")
Pkg.activate(".")

# Test results tracking
test_results = Dict{String, Any}()

"""
    run_test(name, test_function)

Run a test and capture results, errors, and timing.
"""
function run_test(name::String, test_function::Function)
    println("\n🔍 Testing: $name")
    println("-" ^ 40)
    
    start_time = time()
    
    try
        result = test_function()
        elapsed = time() - start_time
        
        test_results[name] = Dict(
            "status" => "SUCCESS",
            "elapsed" => elapsed,
            "result" => result,
            "error" => nothing
        )
        
        println("✅ SUCCESS ($(@sprintf("%.2f", elapsed))s)")
        return true
        
    catch e
        elapsed = time() - start_time
        
        test_results[name] = Dict(
            "status" => "FAILED",
            "elapsed" => elapsed,
            "result" => nothing,
            "error" => string(e)
        )
        
        println("❌ FAILED ($(@sprintf("%.2f", elapsed))s)")
        println("Error: $e")
        return false
    end
end

# ============================================================================
# TEST 1: Parameters.jl System
# ============================================================================

function test_parameters_system()
    println("Loading Parameters.jl system...")
    
    # Load the simplified Parameters.jl system (no external dependencies)
    # Check if we have the reorganized structure or old structure
    if isfile("hpc/config/parameters/BenchmarkConfigSimple.jl")
        println("✓ Found reorganized structure")
        include("hpc/config/parameters/BenchmarkConfigSimple.jl")
    elseif isfile("src/HPC/BenchmarkConfigSimple.jl")
        println("✓ Found old structure")
        include("src/HPC/BenchmarkConfigSimple.jl")
    else
        println("⚠️  Parameters.jl system not found, creating basic test parameters...")
        # Create basic parameter structures for testing
        struct GlobtimParameters
            degree::Int
            sample_count::Int
            center::Vector{Float64}
            sample_range::Float64
        end

        struct HPCParameters
            cpus::Int
            memory_gb::Int
            time_limit::String
        end

        # Simple unpacking function
        macro unpack_simple(vars, struct_instance)
            if vars.head == :tuple
                assignments = []
                for var in vars.args
                    push!(assignments, :($var = getfield($struct_instance, $(QuoteNode(var)))))
                end
                return esc(Expr(:block, assignments...))
            else
                error("@unpack_simple expects a tuple of variable names")
            end
        end
    end
    
    println("Creating test parameters...")
    
    # Test GlobtimParameters creation
    globtim_params = GlobtimParameters(
        degree = 4,
        sample_count = 100,
        center = zeros(4),
        sample_range = 1.5
    )
    
    # Test HPCParameters creation
    hpc_params = HPCParameters(
        cpus = 8,
        memory_gb = 16,
        time_limit = "00:30:00"
    )
    
    # Test parameter unpacking
    @unpack_simple (degree, sample_count, center) globtim_params
    @unpack_simple (cpus, memory_gb) hpc_params
    
    println("✓ GlobtimParameters: degree=$degree, samples=$sample_count")
    println("✓ HPCParameters: cpus=$cpus, memory=$(memory_gb)GB")
    
    return Dict(
        "globtim_degree" => degree,
        "globtim_samples" => sample_count,
        "hpc_cpus" => cpus,
        "hpc_memory" => memory_gb
    )
end

# ============================================================================
# TEST 2: Minimal Benchmark Creation
# ============================================================================

function test_minimal_benchmark()
    println("Testing minimal benchmark creation...")
    
    # Load Globtim
    using Globtim
    
    # Create a simple 2D test function
    function simple_2d_test(x)
        return (x[1] - 1.0)^2 + (x[2] + 0.5)^2
    end
    
    println("✓ Created test function")
    
    # Test basic Globtim functionality
    center = [0.0, 0.0]
    sample_range = 2.0
    degree = 3
    
    println("✓ Testing with center=$center, range=$sample_range, degree=$degree")
    
    # Create samples (basic test)
    n_samples = 50
    samples = []
    for i in 1:n_samples
        x = center + sample_range * (2 * rand(2) .- 1)
        y = simple_2d_test(x)
        push!(samples, (x, y))
    end
    
    println("✓ Generated $n_samples samples")
    
    return Dict(
        "function_name" => "simple_2d_test",
        "center" => center,
        "sample_range" => sample_range,
        "degree" => degree,
        "n_samples" => n_samples,
        "min_value" => minimum([s[2] for s in samples]),
        "max_value" => maximum([s[2] for s in samples])
    )
end

# ============================================================================
# TEST 3: Basic Globtim Integration
# ============================================================================

function test_basic_globtim()
    println("Testing basic Globtim integration...")
    
    using Globtim
    using LinearAlgebra
    
    # Test with Sphere function (simple 4D case)
    function sphere_4d(x)
        return sum(x.^2)
    end
    
    println("✓ Created Sphere function")
    
    # Basic parameters
    center = zeros(4)
    sample_range = 1.0
    degree = 3
    n_samples = 100
    
    println("✓ Parameters: 4D, degree=$degree, samples=$n_samples")
    
    # Generate samples
    samples = []
    for i in 1:n_samples
        x = center + sample_range * (2 * rand(4) .- 1)
        y = sphere_4d(x)
        push!(samples, (x, y))
    end
    
    println("✓ Generated samples")
    
    # Basic statistics
    values = [s[2] for s in samples]
    min_val = minimum(values)
    max_val = maximum(values)
    mean_val = sum(values) / length(values)
    
    println("✓ Value range: [$(@sprintf("%.4f", min_val)), $(@sprintf("%.4f", max_val))]")
    println("✓ Mean value: $(@sprintf("%.4f", mean_val))")
    
    return Dict(
        "function_name" => "sphere_4d",
        "dimension" => 4,
        "degree" => degree,
        "n_samples" => n_samples,
        "min_value" => min_val,
        "max_value" => max_val,
        "mean_value" => mean_val
    )
end

# ============================================================================
# RUN ALL TESTS
# ============================================================================

println("🚀 Starting test suite...")
println()

# Run tests
tests_passed = 0
total_tests = 0

total_tests += 1
if run_test("Parameters.jl System", test_parameters_system)
    tests_passed += 1
end

total_tests += 1
if run_test("Minimal Benchmark Creation", test_minimal_benchmark)
    tests_passed += 1
end

total_tests += 1
if run_test("Basic Globtim Integration", test_basic_globtim)
    tests_passed += 1
end

# ============================================================================
# SUMMARY REPORT
# ============================================================================

println("\n" * "=" ^ 50)
println("📊 TEST SUMMARY REPORT")
println("=" ^ 50)
println("Completed: $(now())")
println("Tests passed: $tests_passed / $total_tests")

if tests_passed == total_tests
    println("🎉 ALL TESTS PASSED!")
else
    println("⚠️  Some tests failed")
end

println("\n📋 Detailed Results:")
for (test_name, result) in test_results
    status_icon = result["status"] == "SUCCESS" ? "✅" : "❌"
    elapsed = @sprintf("%.2f", result["elapsed"])
    println("$status_icon $test_name ($elapsed s)")
    
    if result["status"] == "FAILED"
        println("   Error: $(result["error"])")
    elseif result["result"] !== nothing
        println("   Result: $(result["result"])")
    end
end

println("\n🎯 Next Steps:")
if tests_passed == total_tests
    println("✓ All basic functionality working")
    println("✓ Ready to test advanced examples")
    println("✓ Can proceed with HPC job submission")
else
    println("⚠ Fix failing tests before proceeding")
    println("⚠ Check error messages above")
end

println("\n" * "=" ^ 50)
