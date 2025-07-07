#!/usr/bin/env julia
# ================================================================================
# Generate Theoretical Critical Points for 4D Deuflhard
# ================================================================================
# 
# This script uses the TheoreticalPoints module to generate and save
# all theoretical critical points from the tensor product construction.
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Include required modules in order
include(joinpath(@__DIR__, "../src/Common4DDeuflhard.jl"))
include(joinpath(@__DIR__, "../src/SubdomainManagement.jl"))
include(joinpath(@__DIR__, "../src/TheoreticalPoints.jl"))

using .Common4DDeuflhard
using .SubdomainManagement
using .TheoreticalPoints

println("🔄 Generating theoretical critical points for 4D Deuflhard function...")
println("=" ^ 70)

# Generate and save all critical points
TheoreticalPoints.generate_and_save_all_4d_critical_points(
    output_dir = joinpath(@__DIR__, "../data"),
    save_full = true,
    save_orthant = true
)

println("\n✨ Generation complete!")