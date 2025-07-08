#!/usr/bin/env julia

# Test script for function value analysis
# This demonstrates the function value comparison between theoretical and computed critical points

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

println("\n" * "="^80)
println("🧪 FUNCTION VALUE ANALYSIS TEST")
println("="^80)

# Load required modules
include("src/FunctionValueAnalysis.jl")
using .FunctionValueAnalysis

include("../by_degree/src/Common4DDeuflhard.jl")
using .Common4DDeuflhard

using DataFrames
using Statistics
using LinearAlgebra

# Create some test data
println("\n📊 Creating test data...")

# Theoretical critical points (minima)
theoretical_points = [
    [0.0, 0.0, 0.0, 0.0],           # Global minimum
    [0.5, 0.5, 0.0, 0.0],           # Local minimum
    [-0.5, -0.5, 0.0, 0.0]          # Another local minimum
]
theoretical_types = ["min", "min", "min"]

# Simulated computed critical points (with some error)
computed_points_data = []
for (i, pt) in enumerate(theoretical_points)
    # Add small perturbation to simulate numerical error
    error_magnitude = 0.01 * i  # Increasing error
    perturbed_pt = pt .+ error_magnitude * randn(4)
    push!(computed_points_data, (
        x1 = perturbed_pt[1],
        x2 = perturbed_pt[2], 
        x3 = perturbed_pt[3],
        x4 = perturbed_pt[4],
        z = deuflhard_4d_composite(perturbed_pt)  # Function value
    ))
end

# Add one extra computed point (false positive)
extra_pt = [0.1, 0.1, 0.1, 0.1]
push!(computed_points_data, (
    x1 = extra_pt[1],
    x2 = extra_pt[2],
    x3 = extra_pt[3], 
    x4 = extra_pt[4],
    z = deuflhard_4d_composite(extra_pt)
))

computed_df = DataFrame(computed_points_data)

# Run function value analysis
println("\n📊 Running function value comparison...")
comparison_table = create_function_value_comparison_table(
    theoretical_points,
    theoretical_types,
    computed_df,
    deuflhard_4d_composite,  # function
    4,  # degree
    "test_subdomain"
)

println("\n📋 Function Value Comparison Table:")
println(comparison_table)

# Calculate individual function values
println("\n📊 Detailed Function Values:")
println("\nTheoretical Critical Points:")
for (i, pt) in enumerate(theoretical_points)
    fval = deuflhard_4d_composite(pt)
    println("  Point $i: f = $fval")
end

println("\nComputed Critical Points:")
for (i, row) in enumerate(eachrow(computed_df))
    pt = [row.x1, row.x2, row.x3, row.x4]
    fval = deuflhard_4d_composite(pt)
    
    # Find closest theoretical point
    distances = [norm(pt - tp) for tp in theoretical_points]
    min_dist = minimum(distances)
    closest_idx = argmin(distances)
    
    if min_dist < 0.1
        theo_fval = deuflhard_4d_composite(theoretical_points[closest_idx])
        rel_error = abs(fval - theo_fval) / abs(theo_fval)
        println("  Point $i: f = $fval (matched to theoretical $closest_idx, rel_error = $(round(rel_error, digits=6)))")
    else
        println("  Point $i: f = $fval (unmatched)")
    end
end

# Summary statistics
if comparison_table.n_matched[1] > 0
    println("\n📊 Summary Statistics:")
    println("  Average relative error: $(round(comparison_table.avg_relative_error[1], digits=6))")
    println("  Maximum relative error: $(round(comparison_table.max_relative_error[1], digits=6))")
    println("  Median relative error: $(round(comparison_table.median_relative_error[1], digits=6))")
end

println("\n✅ Test completed!")