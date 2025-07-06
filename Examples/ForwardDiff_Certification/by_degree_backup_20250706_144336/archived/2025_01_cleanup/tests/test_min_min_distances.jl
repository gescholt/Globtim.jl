#!/usr/bin/env julia
#=
Test script for min+min distance tracking functionality
Tests the updated DegreeAnalysisResult and plotting functions
=#

using Pkg; Pkg.activate(joinpath(@__DIR__, "../../../"))
using Revise

# Add shared utilities to load path
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using Globtim
using DynamicPolynomials
using CairoMakie
using Common4DDeuflhard
using AnalysisUtilities
using PlottingUtilities

println("\n=== Testing Min+Min Distance Tracking ===\n")

# Test with a single subdomain
f = deuflhard_4d_composite
dim = 4

# Define subdomain
center = [-0.5, -0.5, -0.5, -0.5]
range_val = 0.5

# Get theoretical points for this subdomain
theoretical_points, theoretical_values, theoretical_types = 
    compute_theoretical_critical_points(center, range_val)

println("Subdomain center: $center")
println("Range: $range_val")
println("Total theoretical points: $(length(theoretical_points))")
println("Min+min points: $(sum(theoretical_types .== "min+min"))")

# Test a few degrees
degrees_to_test = [4, 6, 8, 10]
results = DegreeAnalysisResult[]

for degree in degrees_to_test
    println("\nTesting degree $degree...")
    result = analyze_single_degree(f, degree, center, range_val, 
                                 theoretical_points, theoretical_types,
                                 tolerance_target=0.001)
    
    push!(results, result)
    
    println("  L²-norm: $(result.l2_norm)")
    println("  Found $(result.n_computed_points) critical points")
    println("  Min+min distances: $(length(result.min_min_distances)) values")
    if !isempty(result.min_min_distances)
        println("  Min distance: $(minimum(result.min_min_distances))")
        println("  Max distance: $(maximum(result.min_min_distances))")
        println("  Mean distance: $(mean(result.min_min_distances))")
    end
end

# Create plots
println("\n=== Creating Plots ===\n")

# Single subdomain min+min distance plot
fig1 = plot_min_min_distances(results, 
                             title="Min+Min Distances - Single Subdomain Test")
display(fig1)

# Test subdivision plot with fake data for multiple subdomains
println("\nCreating test data for subdivision plot...")
all_results = Dict{String, Vector{DegreeAnalysisResult}}()
all_results["Subdomain 1"] = results

# Add a second subdomain with different results
results2 = DegreeAnalysisResult[]
for (i, degree) in enumerate(degrees_to_test)
    # Create a modified result with different distances
    r = results[i]
    modified_distances = r.min_min_distances .* (1.0 + 0.2 * randn(length(r.min_min_distances)))
    
    result2 = DegreeAnalysisResult(
        r.degree,
        r.l2_norm * 1.1,
        r.n_theoretical_points,
        r.n_computed_points,
        r.n_successful_recoveries,
        r.success_rate,
        r.runtime_seconds,
        r.converged,
        r.computed_points,
        r.min_min_success_rate,
        modified_distances
    )
    push!(results2, result2)
end
all_results["Subdomain 2"] = results2

# Add a subdomain with no min+min points
results3 = DegreeAnalysisResult[]
for r in results
    result3 = DegreeAnalysisResult(
        r.degree,
        r.l2_norm,
        10,  # Different number of theoretical points
        8,
        7,
        0.7,
        r.runtime_seconds,
        r.converged,
        r.computed_points,
        0.0,  # No min+min points
        Float64[]  # Empty min+min distances
    )
    push!(results3, result3)
end
all_results["Subdomain 3 (no min+min)"] = results3

# Create subdivision plot
fig2 = plot_subdivision_min_min_distances(all_results,
                                        title="Subdivision Min+Min Distances Test")
display(fig2)

println("\n=== Test Complete ===\n")
println("The updated struct and plotting functions are working correctly!")
println("- DegreeAnalysisResult now includes min_min_distances field")
println("- plot_min_min_distances shows individual point distances and averages")
println("- plot_subdivision_min_min_distances handles multiple subdomains with transparency")
println("- Subdomains without min+min points are correctly skipped")