#!/usr/bin/env julia

# Test summary row calculation
include("../src/TheoreticalPointTables.jl")
using .TheoreticalPointTables
using DataFrames

println("Testing summary row...")

# Create test table
theoretical_points = [
    [0.5, 0.5, 0.5, 0.5],
    [0.707, 0.707, 0.0, 0.0],
    [1.0, 0.0, 0.0, 0.0]
]
theoretical_types = ["min", "saddle", "saddle"]
degrees = [3, 4]

df = create_theoretical_point_table(theoretical_points, theoretical_types, degrees)

# Populate with test distances
df.d3 = [0.1, 0.2, NaN]  # Average should be 0.15
df.d4 = [0.05, 0.15, 0.10]  # Average should be 0.10

# Add summary row
df_with_summary = add_summary_row(df)

println("✓ Summary row added")

# Verify structure
@assert nrow(df_with_summary) == 4 "Expected 4 rows (3 points + 1 summary)"
@assert df_with_summary.theoretical_point_id[end] == "AVERAGE" "Last row should be AVERAGE"
@assert df_with_summary.type[end] == "-" "Summary type should be -"

# Verify calculations
@assert df_with_summary.d3[end] ≈ 0.15 "d3 average should be 0.15"
@assert df_with_summary.d4[end] ≈ 0.10 "d4 average should be 0.10"

println("✓ Averages calculated correctly")

# Test with all NaN column
df2 = create_theoretical_point_table([[0.0, 0.0, 0.0, 0.0]], ["min"], [5])
df2.d5 = [NaN]
df2_summary = add_summary_row(df2)
@assert isnan(df2_summary.d5[end]) "All NaN column should have NaN average"

println("✓ NaN handling works correctly")

println("\n✅ All summary tests passed!")

# Display final table
println("\nTable with summary:")
show(df_with_summary, allrows=true, allcols=true)