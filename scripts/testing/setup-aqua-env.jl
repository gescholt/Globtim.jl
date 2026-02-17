#!/usr/bin/env julia
"""
Setup script for Aqua.jl testing environment

This script sets up the proper environment for running Aqua tests without
polluting the main package environment.

Usage: julia scripts/setup-aqua-env.jl
"""

using Pkg

println("🔧 Setting up Aqua.jl testing environment...")

# First, ensure we're in the package root
if !isfile("Project.toml")
    error("Please run this script from the package root directory")
end

# Check if Aqua is in test dependencies
test_project_file = "test/Project.toml"
if isfile(test_project_file)
    println("✅ Found test/Project.toml")
    
    # Activate test environment and check Aqua
    Pkg.activate("test")
    
    try
        using Aqua
        println("✅ Aqua.jl is available in test environment")
    catch e
        @info "Aqua.jl not found, installing..." exception=(e, catch_backtrace())
        Pkg.add("Aqua")
        println("✅ Aqua.jl added successfully")
    end
    
    # Ensure all test dependencies are installed
    println("📦 Installing test dependencies...")
    Pkg.instantiate()
    
    # Return to main environment
    Pkg.activate(".")
    
    println("✅ Test environment setup complete!")
    println("💡 You can now run: julia --project=test scripts/run-aqua-tests.jl")
    
else
    # No test environment, add Aqua to main environment temporarily
    println("⚠️  No test/Project.toml found, adding Aqua to main environment")
    
    Pkg.activate(".")
    
    # Check if Aqua is already available
    try
        using Aqua
        println("✅ Aqua.jl already available")
    catch e
        @info "Aqua.jl not found, installing..." exception=(e, catch_backtrace())
        Pkg.add("Aqua")
        println("✅ Aqua.jl added successfully")
    end
    
    println("✅ Setup complete!")
    println("💡 You can now run: julia scripts/run-aqua-tests.jl")
end

println("\n🎯 Next steps:")
println("1. Run quick check: julia scripts/quick-aqua-check.jl")
println("2. Run full analysis: julia scripts/run-aqua-tests.jl --verbose")
println("3. Fix any issues found")
println("4. Add to CI pipeline when ready")
