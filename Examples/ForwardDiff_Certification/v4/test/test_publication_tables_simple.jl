#!/usr/bin/env julia

# Test the simplified PublicationTables module
# Run this from the v4 directory

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using DataFrames
using LinearAlgebra

println("\n" * "="^80)
println("📊 TESTING SIMPLIFIED PUBLICATION TABLES MODULE")
println("="^80)

# Load modules
include("src/PublicationTablesSimple.jl")
using .PublicationTablesSimple

# Create test data
println("\n📊 Creating test data...")

# Theoretical points (3 minima, 4 saddle points)
theoretical_points = [
    # Minima
    [0.1, 0.1, 0.1, 0.1],
    [0.2, 0.2, 0.2, 0.2],
    [0.3, 0.3, 0.3, 0.3],
    # Saddle points
    [0.4, 0.4, 0.4, 0.4],
    [0.5, 0.5, 0.5, 0.5],
    [0.6, 0.6, 0.6, 0.6],
    [0.7, 0.7, 0.7, 0.7]
]

theoretical_types = ["min", "min", "min", "saddle", "saddle", "saddle", "saddle"]

# Simple test function
f(x) = sum(x.^2) + 0.1 * sum(x.^4)

# Create computed points with small perturbations
degrees = [3, 4, 5]
all_critical_points_with_labels = Dict{Int, DataFrame}()

for degree in degrees
    # Create computed points with perturbations that decrease with degree
    perturbation_scale = 0.01 / degree
    
    computed_data = DataFrame()
    
    # Add perturbed versions of theoretical points
    for (i, (pt, ptype)) in enumerate(zip(theoretical_points, theoretical_types))
        # Add some noise
        noise = randn(4) * perturbation_scale
        comp_pt = pt + noise
        
        # Sometimes miss a point (to test unmatched cases)
        if !(degree == 3 && i == 2)  # Skip second minimum for degree 3
            push!(computed_data, (
                x1 = comp_pt[1],
                x2 = comp_pt[2], 
                x3 = comp_pt[3],
                x4 = comp_pt[4],
                type_classification = ptype,
                subdomain = "0000"
            ))
        end
    end
    
    all_critical_points_with_labels[degree] = computed_data
end

# Test table generation
println("\n📊 Generating tables...")

min_table, saddle_table = generate_function_value_error_tables_simple(
    all_critical_points_with_labels,
    theoretical_points,
    theoretical_types,
    degrees,
    f
)

# Display results
print_publication_tables_simple(min_table, saddle_table)

# Verify results
println("\n📊 Verification:")
println("-"^40)

# Check that we have the right number of rows
expected_min_rows = 3 + 3  # 3 points + 3 summary rows
expected_saddle_rows = 4 + 3  # 4 points + 3 summary rows

println("Minima table rows: $(nrow(min_table)) (expected: $expected_min_rows)")
println("Saddle table rows: $(nrow(saddle_table)) (expected: $expected_saddle_rows)")

# Check that summary rows have values
println("\nChecking summary rows:")
avg_rel_row_idx = nrow(min_table) - 1
avg_raw_row_idx = nrow(min_table)

println("Minima table average relative error row:")
for degree in degrees
    col = Symbol("Degree_$degree")
    if col in names(min_table)
        val = min_table[avg_rel_row_idx, col]
        println("  Degree $degree: $val")
    end
end

println("\n✅ Test complete!")