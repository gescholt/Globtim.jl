#!/usr/bin/env julia
# Package Setup Utility for Node Experiments
# Ensures all required packages are properly installed and configured on r04n02

using Pkg

println("Node Experiments Package Setup Utility")
println("="^50)
println("Checking and installing required packages for HPC node experiments...")

# Activate main globtim project
project_path = dirname(dirname(@__DIR__))
println("Activating project at: $project_path")
Pkg.activate(project_path)

# Check current package status
println("\nCurrent package status:")
try
    Pkg.status()
catch e
    println("Warning: Could not display package status: $e")
end

# Required packages that must be manually installed (not in Project.toml)
required_packages = [
    "JSON"  # Missing from Project.toml, needed for experiment output
]

# Weak dependencies that need activation
weak_dependencies = [
    "CSV"   # Weak dependency, activates GlobtimDataExt extension
]

println("\n" * "="^50)
println("Installing missing packages...")

for pkg in required_packages
    try
        println("Checking $pkg...")
        eval(Meta.parse("using $pkg"))
        println("✓ $pkg already available")
    catch
        println("Installing $pkg...")
        try
            Pkg.add(pkg)
            println("✓ $pkg installed successfully")
        catch e
            println("❌ Failed to install $pkg: $e")
        end
    end
end

println("\n" * "="^50)
println("Testing weak dependencies...")

for pkg in weak_dependencies
    try
        println("Testing $pkg extension...")
        eval(Meta.parse("using $pkg"))
        println("✓ $pkg extension loaded successfully")
    catch e
        println("⚠️  $pkg extension failed to load: $e")
        println("   This may be expected behavior for weak dependencies")
    end
end

println("\n" * "="^50)
println("Testing core experiment dependencies...")

# Test core packages needed for experiments
core_packages = [
    "Globtim",
    "DataFrames", 
    "Statistics",
    "DynamicPolynomials",
    "HomotopyContinuation",
    "ForwardDiff",
    "TimerOutputs",
    "LinearAlgebra"
]

failed_packages = []
for pkg in core_packages
    try
        eval(Meta.parse("using $pkg"))
        println("✓ $pkg loaded successfully")
    catch e
        println("❌ $pkg failed to load: $e")
        push!(failed_packages, pkg)
    end
end

println("\n" * "="^50)
println("Package Setup Summary")
println("="^50)

if isempty(failed_packages)
    println("✅ All required packages are working correctly!")
    println("Node experiments are ready to run.")
else
    println("❌ The following packages failed to load:")
    for pkg in failed_packages
        println("   - $pkg")
    end
    println("\nPlease resolve these issues before running experiments.")
    exit(1)
end

println("\nRecommended next steps:")
println("1. Run experiment verification: ./node_experiments/runners/experiment_runner.sh verify")
println("2. Start with simple test: ./node_experiments/runners/experiment_runner.sh test-2d")
println("3. Run main experiment: ./node_experiments/runners/experiment_runner.sh lotka-volterra-4d 8 10")

println("\n" * "="^50)