#!/usr/bin/env julia

# Test the FunctionValueErrorSummary module
# Run this from the v4 directory

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using DataFrames
using LinearAlgebra

println("\n" * "="^80)
println("📊 TESTING FUNCTION VALUE ERROR SUMMARY MODULE")
println("="^80)

# Load modules
include("src/FunctionValueErrorSummary.jl")
using .FunctionValueErrorSummary

# Create test data with edge cases
println("\n📊 Creating test data with edge cases...")

# Theoretical points (5 minima, 3 saddle points)
theoretical_points = [
    # Minima
    [0.1, 0.1, 0.1, 0.1],  # Normal case
    [0.2, 0.2, 0.2, 0.2],  # Will be missing in degree 3
    [0.0, 0.0, 0.0, 0.0],  # Near zero function value
    [0.3, 0.3, 0.3, 0.3],  # Normal case
    [0.4, 0.4, 0.4, 0.4],  # Will have large error
    # Saddle points
    [0.5, 0.5, 0.5, 0.5],  # Normal case
    [0.6, 0.6, 0.6, 0.6],  # Will be missing in degree 4
    [0.7, 0.7, 0.7, 0.7]   # Normal case
]

theoretical_types = ["min", "min", "min", "min", "min", "saddle", "saddle", "saddle"]

# Test function that gives near-zero value at origin
f(x) = sum(x.^2) + 0.1 * sum(x.^4) - 0.01

# Create computed points with varying quality
degrees = [3, 4, 5]
all_critical_points_with_labels = Dict{Int, DataFrame}()

# Degree 3: Missing some points, larger errors
df3 = DataFrame()
# Add minima (skip point 2)
for i in [1, 3, 4, 5]
    pt = theoretical_points[i]
    noise = randn(4) * 0.01  # Larger noise
    push!(df3, (
        x1 = pt[1] + noise[1],
        x2 = pt[2] + noise[2],
        x3 = pt[3] + noise[3],
        x4 = pt[4] + noise[4],
        z = f(pt .+ noise),
        subdomain = "0000"
    ))
end
# Add saddle points (all 3)
for i in 6:8
    pt = theoretical_points[i]
    noise = randn(4) * 0.015
    push!(df3, (
        x1 = pt[1] + noise[1],
        x2 = pt[2] + noise[2],
        x3 = pt[3] + noise[3],
        x4 = pt[4] + noise[4],
        z = f(pt .+ noise),
        subdomain = "0000"
    ))
end
all_critical_points_with_labels[3] = df3

# Degree 4: Missing one saddle, medium errors
df4 = DataFrame()
# Add all minima
for i in 1:5
    pt = theoretical_points[i]
    noise = randn(4) * 0.005  # Medium noise
    push!(df4, (
        x1 = pt[1] + noise[1],
        x2 = pt[2] + noise[2],
        x3 = pt[3] + noise[3],
        x4 = pt[4] + noise[4],
        z = f(pt .+ noise),
        subdomain = "0000"
    ))
end
# Add saddle points (skip point 7)
for i in [6, 8]
    pt = theoretical_points[i]
    noise = randn(4) * 0.008
    push!(df4, (
        x1 = pt[1] + noise[1],
        x2 = pt[2] + noise[2],
        x3 = pt[3] + noise[3],
        x4 = pt[4] + noise[4],
        z = f(pt .+ noise),
        subdomain = "0000"
    ))
end
all_critical_points_with_labels[4] = df4

# Degree 5: All points captured, small errors
df5 = DataFrame()
for (i, (pt, ptype)) in enumerate(zip(theoretical_points, theoretical_types))
    noise = randn(4) * 0.001  # Small noise
    push!(df5, (
        x1 = pt[1] + noise[1],
        x2 = pt[2] + noise[2],
        x3 = pt[3] + noise[3],
        x4 = pt[4] + noise[4],
        z = f(pt .+ noise),
        subdomain = "0000"
    ))
end
all_critical_points_with_labels[5] = df5

# Test summary table generation
println("\n📊 Generating summary table...")

summary_table = generate_error_summary_table(
    all_critical_points_with_labels,
    theoretical_points,
    theoretical_types,
    degrees,
    f
)

# Display results
print_error_summary_table(summary_table)

# Verify edge cases
println("\n📊 Edge Case Verification:")
println("-"^40)

# Check that we handle missing points correctly
println("Degree 3 should show 4/5 minima captured (missing one)")
println("Degree 4 should show 5/5 minima and 2/3 saddles")
println("Degree 5 should show all points captured")

# Check function value near zero handling
println("\nFunction value at origin: ", f([0.0, 0.0, 0.0, 0.0]))
println("This tests relative error calculation when f ≈ 0")

# Test with empty DataFrame
println("\n📊 Testing with empty data for degree 6...")
all_critical_points_with_labels[6] = DataFrame()
degrees_with_empty = [3, 4, 5, 6]

summary_table_empty = generate_error_summary_table(
    all_critical_points_with_labels,
    theoretical_points,
    theoretical_types,
    degrees_with_empty,
    f
)

println("\nDegree 6 row (should show 0 captured):")
for row in eachrow(summary_table_empty)
    if row.Degree == 6
        println(row)
    end
end

println("\n✅ Test complete!")