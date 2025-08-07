#!/usr/bin/env julia

"""
Basic Julia Test Script for HPC Cluster
========================================

This is a minimal test script to validate the input/run/output pipeline
on the HPC cluster without complex dependencies.

Usage:
    julia basic_julia_test.jl [input_file] [output_dir]
"""

using Pkg
using Dates
using JSON3

println("🚀 Basic Julia Test Script Starting")
println("=" ^ 50)
println("Julia Version: $(VERSION)")
println("Start Time: $(now())")
println("Hostname: $(gethostname())")
println("Working Directory: $(pwd())")
println("Available Threads: $(Threads.nthreads())")
println()

# Parse command line arguments
input_file = length(ARGS) >= 1 ? ARGS[1] : "input_config.json"
output_dir = length(ARGS) >= 2 ? ARGS[2] : "test_output"

println("📋 Configuration:")
println("  Input file: $input_file")
println("  Output directory: $output_dir")
println()

# Create output directory
try
    mkpath(output_dir)
    println("✅ Output directory created: $output_dir")
catch e
    println("⚠️  Output directory already exists or creation failed: $e")
end

# Test 1: Basic computation
println("🧮 Test 1: Basic Mathematical Computation")
try
    # Simple mathematical operations
    x = rand(100)
    y = sin.(x)
    z = sum(y)
    
    println("  ✅ Generated 100 random numbers")
    println("  ✅ Computed sine values")
    println("  ✅ Sum of sine values: $z")
    
    # Save basic results
    basic_results = Dict(
        "test_name" => "basic_math",
        "timestamp" => string(now()),
        "input_size" => length(x),
        "sum_result" => z,
        "mean_result" => z / length(x),
        "julia_version" => string(VERSION),
        "hostname" => gethostname()
    )
    
    open(joinpath(output_dir, "basic_math_results.json"), "w") do f
        JSON3.pretty(f, basic_results, indent=2)
    end
    
    println("  ✅ Results saved to basic_math_results.json")
    
catch e
    println("  ❌ Basic computation failed: $e")
    exit(1)
end

println()

# Test 2: File I/O operations
println("📁 Test 2: File I/O Operations")
try
    # Create test data
    test_data = Dict(
        "test_id" => "file_io_test",
        "timestamp" => string(now()),
        "data" => collect(1:10),
        "metadata" => Dict(
            "created_by" => "basic_julia_test.jl",
            "purpose" => "HPC cluster validation"
        )
    )
    
    # Write JSON file
    json_file = joinpath(output_dir, "test_data.json")
    open(json_file, "w") do f
        JSON3.pretty(f, test_data, indent=2)
    end
    println("  ✅ JSON file written: $json_file")
    
    # Read it back
    read_data = open(json_file, "r") do f
        JSON3.read(f)
    end
    println("  ✅ JSON file read back successfully")
    
    # Write CSV-like data
    csv_file = joinpath(output_dir, "test_data.csv")
    open(csv_file, "w") do f
        println(f, "index,value,squared")
        for i in 1:10
            println(f, "$i,$i,$(i^2)")
        end
    end
    println("  ✅ CSV file written: $csv_file")
    
catch e
    println("  ❌ File I/O test failed: $e")
    exit(1)
end

println()

# Test 3: Environment and system info
println("🖥️  Test 3: System Information Collection")
try
    system_info = Dict(
        "julia_version" => string(VERSION),
        "hostname" => gethostname(),
        "pwd" => pwd(),
        "threads" => Threads.nthreads(),
        "timestamp" => string(now()),
        "environment_variables" => Dict(
            "JULIA_NUM_THREADS" => get(ENV, "JULIA_NUM_THREADS", "not_set"),
            "SLURM_JOB_ID" => get(ENV, "SLURM_JOB_ID", "not_set"),
            "SLURM_CPUS_PER_TASK" => get(ENV, "SLURM_CPUS_PER_TASK", "not_set"),
            "HOME" => get(ENV, "HOME", "not_set")
        ),
        "julia_depot_path" => DEPOT_PATH,
        "julia_load_path" => LOAD_PATH
    )
    
    open(joinpath(output_dir, "system_info.json"), "w") do f
        JSON3.pretty(f, system_info, indent=2)
    end
    
    println("  ✅ System information collected and saved")
    
    # Print key info
    println("  📊 Key System Info:")
    println("    Julia Version: $(system_info["julia_version"])")
    println("    Hostname: $(system_info["hostname"])")
    println("    Threads: $(system_info["threads"])")
    println("    SLURM Job ID: $(system_info["environment_variables"]["SLURM_JOB_ID"])")
    
catch e
    println("  ❌ System info collection failed: $e")
    exit(1)
end

println()

# Final summary
println("📊 FINAL SUMMARY")
println("=" ^ 50)

# List all output files
println("📁 Generated Files:")
try
    for file in readdir(output_dir)
        file_path = joinpath(output_dir, file)
        file_size = filesize(file_path)
        println("  📄 $file ($file_size bytes)")
    end
catch e
    println("  ❌ Error listing output files: $e")
end

println()
println("🎉 ALL TESTS COMPLETED SUCCESSFULLY!")
println("End Time: $(now())")
println("Output Directory: $output_dir")
println()
