# Test script for the new minimizer-focused plot

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using Revise
includet("run_v4_analysis_function.jl")

# Run with small degrees for quick test
println("🔬 Testing minimizer-focused plot with degrees [3,4]...")
results = run_v4_enhanced(degrees=[3,4], GN=20)

println("\n✅ Test complete! Check the output directory for:")
println("   - v4_minimizer_distance_evolution.png")
println("   - v4_minimizer_info_table.png")