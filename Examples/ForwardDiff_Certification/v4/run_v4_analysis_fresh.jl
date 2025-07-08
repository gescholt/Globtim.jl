#!/usr/bin/env julia

# Fresh run script that avoids module caching issues
# This ensures the updated FunctionValueErrorSummary module is loaded

# First, manually include the wrapper to get the function
include("run_v4_analysis_wrapper.jl")

# Parse any command line arguments
degrees = length(ARGS) >= 1 ? parse.(Int, split(ARGS[1], ",")) : [3, 4]
GN = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20

println("\n🔄 Running V4 analysis with fresh module loading...")
println("   Degrees: $degrees")
println("   GN: $GN")

# Run the analysis
results = run_v4_analysis(degrees=degrees, GN=GN)

println("\n✅ Analysis complete!")
println("   Summary table has $(nrow(results.function_value_error_summary)) rows")