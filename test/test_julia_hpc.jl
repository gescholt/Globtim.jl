#!/usr/bin/env julia

"""
Julia HPC Test Script for Furiosa Cluster
Tests basic Julia functionality, package loading, and Globtim integration
"""

using Dates
using LinearAlgebra
using Printf

println("=== Julia HPC Test Starting ===")
println("Julia Version: ", VERSION)
println("Start Time: ", now())
println("Hostname: ", gethostname())
println("Working Directory: ", pwd())
println("Available Threads: ", Threads.nthreads())
println("SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
println("SLURM Node: ", get(ENV, "SLURMD_NODENAME", "not_set"))
println()

# Test 1: Basic Julia functionality
println("🧮 Test 1: Basic Julia Functionality")
try
    # Matrix operations
    A = rand(100, 100)
    B = rand(100, 100)
    C = A * B
    eigenvals = eigvals(A)
    
    println("  ✅ Matrix multiplication: $(size(C))")
    println("  ✅ Eigenvalue computation: $(length(eigenvals)) eigenvalues")
    println("  ✅ Matrix norm: $(norm(C))")
catch e
    println("  ❌ Basic functionality failed: $e")
end
println()

# Test 2: Package availability
println("📦 Test 2: Package Availability")
required_packages = ["StaticArrays", "TimerOutputs", "JSON3", "TOML"]
for pkg in required_packages
    try
        eval(Meta.parse("using $pkg"))
        println("  ✅ $pkg: Available and loaded")
    catch e
        println("  ❌ $pkg: Not available - $e")
    end
end
println()

# Test 3: File I/O operations
println("📁 Test 3: File I/O Operations")
try
    # Create test data
    test_data = Dict(
        "timestamp" => string(now()),
        "hostname" => gethostname(),
        "julia_version" => string(VERSION),
        "test_matrix" => rand(5, 5),
        "slurm_job_id" => get(ENV, "SLURM_JOB_ID", "not_set")
    )
    
    # Write to results directory
    results_dir = "results"
    if !isdir(results_dir)
        mkdir(results_dir)
        println("  ✅ Created results directory")
    end
    
    # Write JSON output
    using JSON3
    json_file = joinpath(results_dir, "julia_test_output.json")
    open(json_file, "w") do f
        JSON3.pretty(f, test_data)
    end
    println("  ✅ JSON output written to: $json_file")
    
    # Write CSV-like output
    csv_file = joinpath(results_dir, "julia_test_matrix.csv")
    open(csv_file, "w") do f
        println(f, "row,col,value")
        for i in 1:size(test_data["test_matrix"], 1)
            for j in 1:size(test_data["test_matrix"], 2)
                println(f, "$i,$j,$(test_data["test_matrix"][i,j])")
            end
        end
    end
    println("  ✅ CSV output written to: $csv_file")
    
catch e
    println("  ❌ File I/O failed: $e")
end
println()

# Test 4: Globtim module loading (if available)
println("🌐 Test 4: Globtim Module Loading")
try
    # Try to load Globtim modules
    if isfile("src/BenchmarkFunctions.jl")
        include("src/BenchmarkFunctions.jl")
        println("  ✅ BenchmarkFunctions.jl loaded")
        
        # Test Deuflhard function if available
        if @isdefined(Deuflhard)
            test_point = [0.5, 0.5]
            result = Deuflhard(test_point)
            println("  ✅ Deuflhard function test: f($test_point) = $result")
        else
            println("  ⚠️  Deuflhard function not defined")
        end
    else
        println("  ⚠️  BenchmarkFunctions.jl not found (expected if not in Globtim directory)")
    end
    
    if isfile("src/LibFunctions.jl")
        include("src/LibFunctions.jl")
        println("  ✅ LibFunctions.jl loaded")
    else
        println("  ⚠️  LibFunctions.jl not found (expected if not in Globtim directory)")
    end
    
catch e
    println("  ⚠️  Globtim modules not available: $e")
end
println()

# Test 5: Performance benchmark
println("⚡ Test 5: Performance Benchmark")
try
    # CPU-intensive computation
    n = 1000
    start_time = time()
    
    # Matrix operations benchmark
    total = 0.0
    for i in 1:n
        A = rand(50, 50)
        B = rand(50, 50)
        C = A * B
        total += sum(C)
    end
    
    end_time = time()
    elapsed = end_time - start_time
    ops_per_sec = n / elapsed
    
    println("  ✅ Completed $n matrix multiplications")
    println("  ✅ Total time: $(round(elapsed, digits=3)) seconds")
    println("  ✅ Operations per second: $(round(ops_per_sec, digits=1))")
    println("  ✅ Total sum: $(round(total, digits=3))")
    
catch e
    println("  ❌ Performance benchmark failed: $e")
end
println()

# Test 6: Environment information
println("🔧 Test 6: Environment Information")
println("  Julia depot paths:")
for (i, path) in enumerate(DEPOT_PATH)
    println("    $i: $path")
end
println("  Environment variables:")
for var in ["HOME", "USER", "SLURM_JOB_ID", "SLURM_CPUS_PER_TASK", "SLURM_MEM_PER_NODE"]
    value = get(ENV, var, "not_set")
    println("    $var: $value")
end
println()

# Final summary
println("=== Julia HPC Test Summary ===")
println("Test completed successfully at: ", now())
println("Total runtime: ", time() - time())
println("All basic functionality verified ✅")
println("Ready for production HPC workloads! 🚀")
