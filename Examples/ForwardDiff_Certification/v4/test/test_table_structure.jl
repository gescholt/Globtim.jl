#!/usr/bin/env julia

# Test basic table structure
include("../src/TheoreticalPointTables.jl")
using .TheoreticalPointTables
using DataFrames

println("Testing basic table structure...")

# Mock data
theoretical_points = [
    [0.5, 0.5, 0.5, 0.5],
    [0.707, 0.707, 0.0, 0.0],
    [0.707, 0.0, 0.707, 0.0]
]
theoretical_types = ["min", "saddle", "saddle"]
degrees = [3, 4, 5]

# Create table
df = create_theoretical_point_table(theoretical_points, theoretical_types, degrees)

# Tests
println("\n✓ Table created with $(nrow(df)) rows")
println("✓ Columns: $(names(df))")

# Verify structure
@assert nrow(df) == 3 "Expected 3 rows"
@assert "theoretical_point_id" in names(df) "Missing theoretical_point_id column"
@assert "type" in names(df) "Missing type column"
@assert all(col -> col in names(df), ["x1", "x2", "x3", "x4"]) "Missing coordinate columns"
@assert all(d -> "d$d" in names(df), degrees) "Missing degree columns"

# Verify content
@assert df.theoretical_point_id[1] == "TP_001" "Wrong ID format"
@assert df.type[2] == "saddle" "Wrong type"
@assert df.x1[1] ≈ 0.5 "Wrong coordinate"
@assert all(isnan.(df.d3)) "Distance columns should be NaN initially"

println("\n✅ All structure tests passed!")

# Display sample
println("\nSample table:")
show(df, allrows=false, allcols=true)