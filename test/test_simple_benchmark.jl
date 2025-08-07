#!/usr/bin/env julia

"""
Test Simple Benchmark Creation

Tests the create_minimal_benchmark.jl example.
"""

println("🧪 Testing Simple Benchmark Creation")
println("=" ^ 40)

try
    using Globtim
    println("✅ Globtim loaded successfully")
    
    # Test basic functionality
    println("\n🔍 Testing basic Globtim functionality...")
    
    # Simple 2D test function
    function simple_test_function(x)
        return (x[1] - 1.0)^2 + (x[2] + 0.5)^2
    end
    
    println("✅ Created test function")
    
    # Test parameters
    center = [0.0, 0.0]
    sample_range = 2.0
    degree = 3
    n_samples = 20  # Small number for quick test
    
    println("✅ Parameters: center=$center, range=$sample_range, degree=$degree")
    
    # Generate test samples
    samples = []
    for i in 1:n_samples
        x = center + sample_range * (2 * rand(2) .- 1)
        y = simple_test_function(x)
        push!(samples, (x, y))
    end
    
    println("✅ Generated $n_samples samples")
    
    # Basic statistics
    values = [s[2] for s in samples]
    min_val = minimum(values)
    max_val = maximum(values)
    mean_val = sum(values) / length(values)
    
    println("📊 Results:")
    println("   Min value: $(round(min_val, digits=4))")
    println("   Max value: $(round(max_val, digits=4))")
    println("   Mean value: $(round(mean_val, digits=4))")
    
    # Test if create_minimal_benchmark.jl exists
    benchmark_file = "Examples/create_minimal_benchmark.jl"
    if isfile(benchmark_file)
        println("\n🔍 Testing $benchmark_file...")
        try
            include(benchmark_file)
            println("✅ Minimal benchmark example completed successfully!")
        catch e
            println("⚠️  Error in minimal benchmark: $e")
        end
    else
        println("⚠️  $benchmark_file not found")
    end
    
    println("\n✅ Simple benchmark test completed successfully!")
    
catch e
    println("❌ Error in simple benchmark test:")
    println("   $e")
    
    # Check if Globtim is available
    try
        using Pkg
        Pkg.status("Globtim")
    catch
        println("❌ Globtim package not available")
    end
end

println("\n" * "=" ^ 40)
println("🏁 Simple benchmark test completed")
