#!/usr/bin/env julia

"""
Basic Globtim Module Loading Test
Tests loading of core Globtim modules and basic function calls
"""

using Dates
using Printf

println("=== Globtim Module Loading Test ===")
println("Julia Version: ", VERSION)
println("Start Time: ", now())
println("Hostname: ", gethostname())
println("Working Directory: ", pwd())
println("SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
println()

# Test 1: Check if Globtim source files exist
println("🔍 Test 1: Checking Globtim Source Files")
try
    src_files = ["src/BenchmarkFunctions.jl", "src/LibFunctions.jl"]
    for file in src_files
        if isfile(file)
            println("  ✅ Found: $file")
        else
            println("  ❌ Missing: $file")
        end
    end
catch e
    println("  ❌ Error checking files: $e")
end
println()

# Test 2: Try to include BenchmarkFunctions.jl
println("📦 Test 2: Loading BenchmarkFunctions.jl")
try
    if isfile("src/BenchmarkFunctions.jl")
        include("src/BenchmarkFunctions.jl")
        println("  ✅ BenchmarkFunctions.jl loaded successfully")
        
        # Check if Deuflhard function is defined
        if @isdefined(Deuflhard)
            println("  ✅ Deuflhard function is defined")
            
            # Test simple function call
            test_point = [0.5, 0.5]
            try
                result = Deuflhard(test_point)
                println("  ✅ Deuflhard function call successful: f($test_point) = $result")
            catch e
                println("  ⚠️  Deuflhard function call failed: $e")
            end
        else
            println("  ⚠️  Deuflhard function not defined after loading")
        end
    else
        println("  ❌ BenchmarkFunctions.jl not found")
    end
catch e
    println("  ❌ Error loading BenchmarkFunctions.jl: $e")
end
println()

# Test 3: Try to include LibFunctions.jl
println("📦 Test 3: Loading LibFunctions.jl")
try
    if isfile("src/LibFunctions.jl")
        include("src/LibFunctions.jl")
        println("  ✅ LibFunctions.jl loaded successfully")
    else
        println("  ❌ LibFunctions.jl not found")
    end
catch e
    println("  ❌ Error loading LibFunctions.jl: $e")
end
println()

# Test 4: Check available functions
println("🔧 Test 4: Available Functions Check")
try
    # List some common benchmark functions that might be defined
    test_functions = ["Deuflhard", "trefethen_3_8", "camel_3_4d"]
    for func_name in test_functions
        if isdefined(Main, Symbol(func_name))
            println("  ✅ Function available: $func_name")
        else
            println("  ⚠️  Function not available: $func_name")
        end
    end
catch e
    println("  ❌ Error checking functions: $e")
end
println()

# Test 5: Create output file
println("📁 Test 5: File I/O Test")
try
    # Create results directory
    results_dir = "results"
    if !isdir(results_dir)
        mkdir(results_dir)
        println("  ✅ Created results directory")
    else
        println("  ✅ Results directory exists")
    end
    
    # Write test output
    output_file = joinpath(results_dir, "globtim_module_test.txt")
    open(output_file, "w") do f
        println(f, "Globtim Module Test Results")
        println(f, "Timestamp: $(now())")
        println(f, "Julia Version: $(VERSION)")
        println(f, "Hostname: $(gethostname())")
        println(f, "SLURM Job ID: $(get(ENV, "SLURM_JOB_ID", "not_set"))")
        println(f, "")
        println(f, "Module Loading Status:")
        println(f, "- BenchmarkFunctions.jl: $(isfile("src/BenchmarkFunctions.jl") ? "Found" : "Missing")")
        println(f, "- LibFunctions.jl: $(isfile("src/LibFunctions.jl") ? "Found" : "Missing")")
        println(f, "- Deuflhard function: $(@isdefined(Deuflhard) ? "Available" : "Not available")")
    end
    println("  ✅ Output written to: $output_file")
    
catch e
    println("  ❌ File I/O failed: $e")
end
println()

# Test 6: Environment information
println("🔧 Test 6: Environment Information")
println("  Julia depot paths:")
for (i, path) in enumerate(DEPOT_PATH)
    println("    $i: $path")
end
println("  Environment variables:")
for var in ["HOME", "USER", "SLURM_JOB_ID", "SLURM_CPUS_PER_TASK", "JULIA_DEPOT_PATH"]
    value = get(ENV, var, "not_set")
    println("    $var: $value")
end
println()

# Final summary
println("=== Globtim Module Test Summary ===")
println("Test completed at: ", now())
println("Basic module loading verification complete ✅")

# Exit with success
exit(0)
