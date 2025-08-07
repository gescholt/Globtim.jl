#!/usr/bin/env julia

"""
Test Parameters.jl Demo

Simple test to validate the Parameters.jl integration works correctly.
"""

println("🧪 Testing Parameters.jl Demo")
println("=" ^ 40)

try
    # Test the fixed parameters demo
    println("📁 Current directory: $(pwd())")
    println("📋 Available files:")
    for file in readdir(".")
        if endswith(file, ".jl") && contains(file, "parameters")
            println("  ✓ $file")
        end
    end
    
    println("\n🔍 Testing Examples/parameters_jl_demo.jl...")
    
    # Check if the file exists
    demo_file = "Examples/parameters_jl_demo.jl"
    if isfile(demo_file)
        println("✅ Found $demo_file")
        
        # Try to include and run it
        println("🚀 Running parameters demo...")
        include(demo_file)
        
        println("✅ Parameters.jl demo completed successfully!")
        
    else
        println("❌ $demo_file not found")
        println("📁 Available Examples files:")
        if isdir("Examples")
            for file in readdir("Examples")
                if endswith(file, ".jl")
                    println("  - $file")
                end
            end
        else
            println("❌ Examples directory not found")
        end
    end
    
catch e
    println("❌ Error running parameters demo:")
    println("   $e")
    
    # Try to provide helpful debugging info
    println("\n🔍 Debugging information:")
    println("📁 Current directory: $(pwd())")
    println("📋 Directory contents:")
    for item in readdir(".")
        println("  - $item")
    end
    
    if isdir("hpc")
        println("\n📋 HPC directory contents:")
        for item in readdir("hpc")
            println("  - hpc/$item")
        end
        
        if isdir("hpc/config")
            println("\n📋 HPC config directory:")
            for item in readdir("hpc/config")
                println("  - hpc/config/$item")
            end
        end
    end
end

println("\n" * "=" ^ 40)
println("🏁 Parameters.jl demo test completed")
