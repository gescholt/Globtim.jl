# setup_offline_depot.jl
println("=== Creating Offline Julia Depot for Globtim HPC ===")
println("Depot location: ", ENV["JULIA_DEPOT_PATH"])

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
println("\n4. Adding standard libraries...")
using LinearAlgebra
using SparseArrays
using Random
using Statistics
using Distributed
using SharedArrays
using Dates
using DelimitedFiles

# Test loading key Globtim dependencies
println("\n5. Testing key HPC dependencies...")
try
    using ForwardDiff
    println("✅ ForwardDiff loaded")
catch e
    println("❌ ForwardDiff failed: ", e)
end

try
    using HomotopyContinuation
    println("✅ HomotopyContinuation loaded")
catch e
    println("❌ HomotopyContinuation failed: ", e)
end

try
    using DynamicPolynomials
    println("✅ DynamicPolynomials loaded")
catch e
    println("❌ DynamicPolynomials failed: ", e)
end

try
    using Optim
    println("✅ Optim loaded")
catch e
    println("❌ Optim failed: ", e)
end

try
    using BenchmarkTools
    println("✅ BenchmarkTools loaded")
catch e
    println("❌ BenchmarkTools failed: ", e)
end

println("\n6. Precompiling all packages...")
Pkg.precompile()

# List all installed packages
println("\n7. Installed packages:")
Pkg.status()

# Create package inventory
println("\n8. Creating package inventory...")
deps = Pkg.dependencies()
open("package_list_hpc.txt", "w") do io
    println(io, "Globtim HPC Package List - $(Dates.now())")
    println(io, "=" ^ 50)
    for (uuid, dep) in deps
        println(io, dep.name, " ", dep.version)
    end
end
println("Found ", length(deps), " packages")

println("\n=== Depot Creation Complete ===")
println("Next steps:")
println("1. Run dependency analysis")
println("2. Verify depot completeness")
println("3. Create bundle archive")
