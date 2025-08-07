#!/usr/bin/env julia
"""
Simple test to verify package activation works correctly for JSON tracking system.
This script tests that all required packages can be loaded properly.
"""

println("🧪 Testing Package Activation for JSON Tracking System")
println("=" ^ 60)

# Test 1: Activate main project environment
println("📦 Step 1: Activating main Globtim project environment...")
try
    using Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
    println("✅ Project environment activated successfully")
    println("   Active project: $(Pkg.project().path)")
catch e
    println("❌ Failed to activate project environment: $e")
    exit(1)
end

# Test 2: Load required packages
println("\n📚 Step 2: Loading required packages...")

packages_to_test = [
    ("JSON3", "JSON serialization"),
    ("UUIDs", "Unique ID generation"),
    ("Dates", "Date/time handling"),
    ("DataFrames", "Data manipulation"),
    ("CSV", "CSV file I/O"),
    ("SHA", "Hash computation")
]

global all_loaded = true

for (pkg_name, description) in packages_to_test
    try
        eval(Meta.parse("using $pkg_name"))
        println("  ✅ $pkg_name loaded successfully ($description)")
    catch e
        println("  ❌ Failed to load $pkg_name: $e")
        global all_loaded = false
    end
end

if !all_loaded
    println("\n❌ Some packages failed to load. Please ensure they are installed:")
    println("   julia> using Pkg")
    println("   julia> Pkg.add([\"JSON3\", \"CSV\", \"SHA\"])")
    exit(1)
end

# Test 3: Test basic JSON functionality
println("\n🔧 Step 3: Testing basic JSON functionality...")
try
    test_data = Dict(
        "computation_id" => "test1234",
        "timestamp" => string(Dates.now()),
        "test_array" => [1, 2, 3],
        "test_nested" => Dict("key" => "value")
    )
    
    # Test serialization
    json_string = JSON3.write(test_data)
    println("  ✅ JSON serialization works")
    
    # Test deserialization
    parsed_data = JSON3.read(json_string, Dict)
    println("  ✅ JSON deserialization works")
    
    # Test file I/O
    temp_file = tempname() * ".json"
    open(temp_file, "w") do f
        JSON3.pretty(f, test_data)
    end

    loaded_data = JSON3.read(read(temp_file, String), Dict)
    rm(temp_file)
    
    if loaded_data["computation_id"] == "test1234"
        println("  ✅ JSON file I/O works")
    else
        println("  ❌ JSON file I/O failed - data mismatch")
        global all_loaded = false
    end

catch e
    println("  ❌ JSON functionality test failed: $e")
    global all_loaded = false
end

# Test 4: Test UUID generation
println("\n🆔 Step 4: Testing UUID generation...")
try
    using UUIDs
    id1 = string(uuid4())[1:8]
    id2 = string(uuid4())[1:8]
    
    if length(id1) == 8 && length(id2) == 8 && id1 != id2
        println("  ✅ UUID generation works (generated: $id1, $id2)")
    else
        println("  ❌ UUID generation failed")
        global all_loaded = false
    end
catch e
    println("  ❌ UUID test failed: $e")
    global all_loaded = false
end

# Test 5: Test SHA hashing
println("\n🔐 Step 5: Testing SHA hashing...")
try
    using SHA
    test_string = "test data for hashing"
    hash_result = bytes2hex(sha256(test_string))
    
    if length(hash_result) == 64
        println("  ✅ SHA256 hashing works (hash: $(hash_result[1:16])...)")
    else
        println("  ❌ SHA256 hashing failed - incorrect hash length")
        global all_loaded = false
    end
catch e
    println("  ❌ SHA hashing test failed: $e")
    global all_loaded = false
end

# Test 6: Test JSON I/O utilities loading
println("\n📄 Step 6: Testing JSON I/O utilities loading...")
try
    include("json_io.jl")
    println("  ✅ JSON I/O utilities loaded successfully")
    
    # Test a simple function
    comp_id = generate_computation_id()
    if length(comp_id) == 8
        println("  ✅ generate_computation_id() works (generated: $comp_id)")
    else
        println("  ❌ generate_computation_id() failed")
        global all_loaded = false
    end

catch e
    println("  ❌ Failed to load JSON I/O utilities: $e")
    global all_loaded = false
end

# Final summary
println("\n" * repeat("=", 60))
if all_loaded
    println("🎉 ALL TESTS PASSED!")
    println("✅ JSON tracking system packages are properly configured")
    println()
    println("You can now use the JSON tracking system:")
    println("  cd hpc/jobs/creation")
    println("  julia create_json_tracked_job.jl deuflhard quick")
else
    println("❌ SOME TESTS FAILED")
    println("⚠️  Please fix the issues above before using the JSON tracking system")
    println()
    println("Common fixes:")
    println("  1. Ensure you're in the main Globtim directory")
    println("  2. Add missing packages: julia> Pkg.add([\"JSON3\", \"CSV\", \"SHA\"])")
    println("  3. Check that Project.toml includes all dependencies")
end

println("\nTest completed: $(Dates.now())")
exit(all_loaded ? 0 : 1)
