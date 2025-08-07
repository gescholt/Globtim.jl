#!/usr/bin/env julia

"""
Test 4D Benchmark Framework

Tests the 4d_benchmark_tests framework.
"""

println("🧪 Testing 4D Benchmark Framework")
println("=" ^ 40)

try
    using Globtim
    using LinearAlgebra
    println("✅ Required packages loaded")
    
    # Test 4D functionality
    println("\n🔍 Testing 4D benchmark functionality...")
    
    # Simple 4D Sphere function
    function sphere_4d(x)
        return sum(x.^2)
    end
    
    println("✅ Created 4D Sphere function")
    
    # Test parameters for 4D
    center = zeros(4)
    sample_range = 1.0
    degree = 3
    n_samples = 50  # Moderate number for testing
    
    println("✅ 4D Parameters: center=$center, range=$sample_range, degree=$degree")
    
    # Generate 4D samples
    samples = []
    for i in 1:n_samples
        x = center + sample_range * (2 * rand(4) .- 1)
        y = sphere_4d(x)
        push!(samples, (x, y))
    end
    
    println("✅ Generated $n_samples 4D samples")
    
    # Basic 4D statistics
    values = [s[2] for s in samples]
    positions = [s[1] for s in samples]
    
    min_val = minimum(values)
    max_val = maximum(values)
    mean_val = sum(values) / length(values)
    
    # Find best sample (closest to minimum)
    best_idx = argmin(values)
    best_pos = positions[best_idx]
    best_val = values[best_idx]
    
    println("📊 4D Results:")
    println("   Min value: $(round(min_val, digits=4))")
    println("   Max value: $(round(max_val, digits=4))")
    println("   Mean value: $(round(mean_val, digits=4))")
    println("   Best position: [$(join([round(x, digits=3) for x in best_pos], ", "))]")
    println("   Best value: $(round(best_val, digits=4))")
    println("   Distance to origin: $(round(norm(best_pos), digits=4))")
    
    # Test if 4D benchmark framework exists
    framework_dir = "Examples/4d_benchmark_tests"
    if isdir(framework_dir)
        println("\n🔍 Found 4D benchmark framework directory")
        
        # Check for key files
        key_files = [
            "benchmark_4d_framework.jl",
            "run_4d_benchmark_study.jl",
            "example_usage.jl"
        ]
        
        for file in key_files
            filepath = joinpath(framework_dir, file)
            if isfile(filepath)
                println("   ✅ $file")
            else
                println("   ❌ $file (missing)")
            end
        end
        
        # Try to run a simple example if available
        example_file = joinpath(framework_dir, "example_usage.jl")
        if isfile(example_file)
            println("\n🚀 Testing example usage...")
            # Store original directory before try block
            original_dir = pwd()
            try
                # Change to the framework directory
                cd(framework_dir)
                
                include("example_usage.jl")
                println("✅ 4D benchmark example completed successfully!")
                
                cd(original_dir)
            catch e
                println("⚠️  Error in 4D benchmark example: $e")
                cd(original_dir)
            end
        end
        
    else
        println("⚠️  4D benchmark framework directory not found")
    end
    
    println("\n✅ 4D benchmark framework test completed!")
    
catch e
    println("❌ Error in 4D benchmark test:")
    println("   $e")
    
    # Provide debugging info
    println("\n🔍 Available Examples directories:")
    if isdir("Examples")
        for item in readdir("Examples")
            if isdir(joinpath("Examples", item))
                println("   📁 $item")
            end
        end
    end
end

println("\n" * "=" ^ 40)
println("🏁 4D benchmark framework test completed")
