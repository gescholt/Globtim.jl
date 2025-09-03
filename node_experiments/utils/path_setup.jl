#!/usr/bin/env julia
# Path Setup Utility for Node Experiments  
# Validates and configures proper paths for HPC node execution

println("Node Experiments Path Setup Utility")
println("="^50)

# Determine paths
script_dir = @__DIR__
node_experiments_dir = dirname(script_dir)
globtim_dir = dirname(node_experiments_dir)

println("Path Configuration:")
println("  Script location: $script_dir")
println("  Node experiments: $node_experiments_dir") 
println("  GlobTim root: $globtim_dir")

# Validate directory structure
required_dirs = [
    joinpath(node_experiments_dir, "scripts"),
    joinpath(node_experiments_dir, "runners"), 
    joinpath(node_experiments_dir, "outputs"),
    joinpath(node_experiments_dir, "utils"),
    joinpath(globtim_dir, "src"),
    joinpath(globtim_dir, "hpc")
]

println("\n" * "="^50)
println("Directory Structure Validation:")

global all_valid = true
for dir in required_dirs
    if isdir(dir)
        println("✓ $dir")
    else
        println("❌ $dir (missing)")
        global all_valid = false
    end
end

# Check critical files
critical_files = [
    joinpath(globtim_dir, "Project.toml"),
    joinpath(node_experiments_dir, "README.md"),
    joinpath(node_experiments_dir, "runners", "experiment_runner.sh"),
    joinpath(node_experiments_dir, "scripts", "lotka_volterra_4d.jl")
]

println("\n" * "="^50) 
println("Critical Files Validation:")

for file in critical_files
    if isfile(file)
        println("✓ $file")
    else
        println("❌ $file (missing)")
        global all_valid = false
    end
end

# Test package activation path
println("\n" * "="^50)
println("Package Activation Test:")

try
    using Pkg
    Pkg.activate(globtim_dir)
    println("✓ Successfully activated project at: $globtim_dir")
    
    # Test that we can access Globtim
    try
        using Globtim
        println("✓ Globtim package loaded successfully")
    catch e
        println("❌ Failed to load Globtim: $e")
        global all_valid = false
    end
catch e
    println("❌ Failed to activate project: $e") 
    all_valid = false
end

# Environment variable recommendations
println("\n" * "="^50)
println("Environment Configuration:")

if haskey(ENV, "GLOBTIM_DIR")
    println("✓ GLOBTIM_DIR = $(ENV["GLOBTIM_DIR"])")
else
    println("⚠️  GLOBTIM_DIR not set (will use default: /home/scholten/globtim)")
end

if haskey(ENV, "JULIA_PROJECT")
    println("✓ JULIA_PROJECT = $(ENV["JULIA_PROJECT"])")
else
    println("⚠️  JULIA_PROJECT not set (will be set by experiment runner)")
end

# Summary
println("\n" * "="^50)
println("Path Setup Summary")
println("="^50)

if all_valid
    println("✅ All paths and files are properly configured!")
    println("Node experiments are ready to run.")
    
    println("\nRecommended usage patterns:")
    println("1. Experiment scripts should use: Pkg.activate(dirname(@__DIR__))")
    println("2. Output paths: node_experiments/outputs/<experiment_name>")
    println("3. Temp files: node_experiments/scripts/temp/")
    println("4. Never use /tmp/ - always use project-relative paths")
else
    println("❌ Some paths or files are missing!")
    println("Please resolve these issues before running experiments.")
    exit(1)
end

println("\nPath configuration complete.")
println("="^50)