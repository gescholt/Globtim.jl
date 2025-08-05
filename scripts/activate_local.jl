#!/usr/bin/env julia

"""
Activation script for local development environment with full plotting capabilities.

Usage:
    julia scripts/activate_local.jl
    
Or include in your Julia session:
    include("scripts/activate_local.jl")
"""

using Pkg

# Get the project root directory
project_root = dirname(dirname(@__FILE__))
local_env_path = joinpath(project_root, "environments", "local")

println("🔧 Activating local development environment...")
println("📁 Environment path: $local_env_path")

# Activate the local environment
Pkg.activate(local_env_path)

# Instantiate if needed
if !isfile(joinpath(local_env_path, "Manifest.toml"))
    println("📦 Installing dependencies for local environment...")
    Pkg.instantiate()
    println("✅ Local environment setup complete!")
else
    println("✅ Local environment activated!")
end

# Load commonly used packages for interactive development
try
    println("🎨 Loading plotting backends...")
    @eval using CairoMakie
    CairoMakie.activate!()
    println("✅ CairoMakie activated")
    
    @eval using GLMakie  
    println("✅ GLMakie available")
    
    println("📊 Loading Globtim...")
    @eval using Globtim
    println("✅ Globtim loaded with full plotting capabilities")
    
    println("\n🚀 Ready for local development!")
    println("💡 Available plotting backends: CairoMakie (active), GLMakie")
    println("💡 Development tools: Revise, ProfileView, BenchmarkTools")
    
catch e
    println("⚠️  Some packages failed to load: $e")
    println("💡 You may need to run: Pkg.instantiate()")
end
