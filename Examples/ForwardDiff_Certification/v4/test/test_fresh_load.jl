#!/usr/bin/env julia

# Test script to ensure fresh module loading
println("Testing fresh module load...")

# First, let's check what's in a sample DataFrame
using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using DataFrames

# Create a test DataFrame similar to what run_analysis_with_refinement creates
test_df = DataFrame(
    x1 = [0.1],
    x2 = [0.2], 
    x3 = [0.3],
    x4 = [0.4],
    z = [1.0],
    region_id = [1],
    function_value_cluster = [1],
    nearest_neighbor_dist = [0.1],
    gradient_norm = [0.01],
    subdomain = ["0000"]
)

println("\nColumns in test DataFrame:")
println(names(test_df))

# Now load and test our module
include("src/FunctionValueErrorSummary.jl")
using .FunctionValueErrorSummary

println("\n✅ Module loaded successfully")
println("Ready to test with actual data")