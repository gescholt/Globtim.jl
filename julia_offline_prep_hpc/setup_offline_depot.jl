# setup_offline_depot.jl
println("=== Creating Offline Julia Depot for GlobTim HPC ===")
println("Depot location: ", ENV["JULIA_DEPOT_PATH"])
println("Julia version: ", VERSION)

using Pkg

# Update registry first (needs internet)
println("\n1. Updating package registry...")
Pkg.Registry.update()

# Show current project
println("\n2. Current project: ", Base.active_project())

# Instantiate project dependencies
println("\n3. Installing all dependencies...")
Pkg.instantiate(verbose=true)

# Add commonly needed stdlib packages
println("\n4. Loading standard libraries...")
using LinearAlgebra
using SparseArrays
using Random
using Statistics
using Distributed
using SharedArrays
using Dates
using DelimitedFiles
using Test
using Printf

println("\n5. Precompiling all packages...")
Pkg.precompile()

# List all installed packages
println("\n6. Installed packages:")
Pkg.status()

# Get dependency count
deps = Pkg.dependencies()
println("\n7. Total dependencies: ", length(deps))

println("\n=== Depot Creation Complete ===")