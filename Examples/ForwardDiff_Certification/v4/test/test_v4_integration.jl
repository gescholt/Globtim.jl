#!/usr/bin/env julia

# Test V4 integration and compare key metrics

println("Testing V4 integration with small example...")

# Run V4 analysis with minimal configuration
include("../run_v4_analysis.jl")

# Use small degree range for quick test
subdomain_tables = run_v4_analysis([3,4], 20)

println("\n📊 V4 Integration Test Results:")

# Check we got tables
@assert length(subdomain_tables) > 0 "No subdomain tables generated"
println("✓ Generated $(length(subdomain_tables)) subdomain tables")

# Check table structure for each subdomain
for (label, table) in subdomain_tables
    # Verify columns
    expected_cols = ["theoretical_point_id", "type", "x1", "x2", "x3", "x4", "d3", "d4"]
    @assert all(col -> col in names(table), expected_cols) "Missing columns in $label"
    
    # Verify AVERAGE row exists
    @assert table.theoretical_point_id[end] == "AVERAGE" "Missing AVERAGE row in $label"
    
    # Check that distances are improving (d4 < d3 on average)
    avg_row = table[end, :]
    if !isnan(avg_row.d3) && !isnan(avg_row.d4)
        if avg_row.d4 < avg_row.d3
            println("✓ Subdomain $label shows improvement: d3=$(round(avg_row.d3, digits=4)) → d4=$(round(avg_row.d4, digits=4))")
        else
            println("⚠️  Subdomain $label no improvement: d3=$(round(avg_row.d3, digits=4)) → d4=$(round(avg_row.d4, digits=4))")
        end
    end
end

# Count theoretical points across all subdomains
total_theoretical = sum(nrow(table) - 1 for (_, table) in subdomain_tables)
println("\n✓ Total theoretical points tracked: $total_theoretical")

# Check a specific subdomain if it exists
if haskey(subdomain_tables, "0000")
    table_0000 = subdomain_tables["0000"]
    n_points = nrow(table_0000) - 1
    println("\n📊 Subdomain 0000 details:")
    println("   Theoretical points: $n_points")
    
    # Check distance values
    valid_d3 = count(!isnan, table_0000.d3[1:end-1])
    valid_d4 = count(!isnan, table_0000.d4[1:end-1])
    println("   Valid distances: d3=$valid_d3/$n_points, d4=$valid_d4/$n_points")
end

println("\n✅ V4 integration test completed successfully!")