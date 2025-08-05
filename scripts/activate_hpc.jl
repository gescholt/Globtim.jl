#!/usr/bin/env julia

"""
Activation script for HPC environment with minimal dependencies.

Usage:
    julia scripts/activate_hpc.jl
    
Or include in your Julia session:
    include("scripts/activate_hpc.jl")
"""

using Pkg

# Get the project root directory
project_root = dirname(dirname(@__FILE__))
hpc_env_path = joinpath(project_root, "environments", "hpc")

println("🖥️  Activating HPC environment...")
println("📁 Environment path: $hpc_env_path")

# Activate the HPC environment
Pkg.activate(hpc_env_path)

# Instantiate if needed
if !isfile(joinpath(hpc_env_path, "Manifest.toml"))
    println("📦 Installing dependencies for HPC environment...")
    Pkg.instantiate()
    println("✅ HPC environment setup complete!")
else
    println("✅ HPC environment activated!")
end

# Load core packages for computational work
try
    println("🧮 Loading Globtim core...")
    @eval using Globtim
    println("✅ Globtim loaded (HPC mode - plotting via extensions only)")
    
    println("📊 Loading computational packages...")
    @eval using DataFrames, CSV, LinearAlgebra
    println("✅ Core computational packages loaded")
    
    println("\n🚀 Ready for HPC computations!")
    println("💡 Plotting available via: using CairoMakie; CairoMakie.activate!()")
    println("💡 Optimized for: Large-scale computations, minimal memory footprint")
    
catch e
    println("⚠️  Some packages failed to load: $e")
    println("💡 You may need to run: Pkg.instantiate()")
end
