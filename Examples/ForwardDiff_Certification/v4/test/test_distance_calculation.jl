#!/usr/bin/env julia

# Test distance calculation
include("../src/TheoreticalPointTables.jl")
using .TheoreticalPointTables
using DataFrames

println("Testing distance calculation...")

# Test 1: Basic distance calculation
theory_point = [0.0, 0.0, 0.0, 0.0]
computed_points = [
    [1.0, 0.0, 0.0, 0.0],  # distance = 1
    [0.0, 2.0, 0.0, 0.0],  # distance = 2
    [0.5, 0.5, 0.5, 0.5]   # distance = 1
]

dist = calculate_minimal_distance(theory_point, computed_points)
@assert dist ≈ 1.0 "Expected minimum distance of 1.0, got $dist"
println("✓ Basic distance calculation works")

# Test 2: Empty computed points
dist_empty = calculate_minimal_distance(theory_point, Vector{Float64}[])
@assert isnan(dist_empty) "Expected NaN for empty computed points"
println("✓ Empty points returns NaN")

# Test 3: Full table population
theoretical_points = [
    [0.5, 0.5, 0.5, 0.5],
    [0.707, 0.707, 0.0, 0.0]
]
theoretical_types = ["min", "saddle"]
degrees = [3, 4]

# Create mock computed points
computed_by_degree = Dict(
    3 => DataFrame(
        x1 = [0.51, 0.70],
        x2 = [0.49, 0.71],
        x3 = [0.50, 0.01],
        x4 = [0.52, 0.02],
        subdomain = ["0000", "0000"]
    ),
    4 => DataFrame(
        x1 = [0.501, 0.708],
        x2 = [0.499, 0.706],
        x3 = [0.500, 0.001],
        x4 = [0.502, 0.001],
        subdomain = ["0000", "0000"]
    )
)

# Create and populate table
df = create_theoretical_point_table(theoretical_points, theoretical_types, degrees)
df = populate_distances_for_subdomain(df, [1, 2], theoretical_points, computed_by_degree, "0000")

println("\n✓ Table populated with distances")
println("  Point 1: d3=$(df.d3[1]), d4=$(df.d4[1])")
println("  Point 2: d3=$(df.d3[2]), d4=$(df.d4[2])")

# Verify distances are reasonable
@assert df.d3[1] < 0.1 "Distance for point 1, degree 3 too large"
@assert df.d4[1] < df.d3[1] "Degree 4 should be more accurate than degree 3"

println("\n✅ All distance tests passed!")

# Display table
println("\nFinal table:")
show(df, allrows=true, allcols=true)