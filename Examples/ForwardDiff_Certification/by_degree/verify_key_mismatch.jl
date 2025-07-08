# Verify the key mismatch issue

using CSV, DataFrames

# Load a subdomain table directly
table_1010 = CSV.read("outputs/enhanced_v3_17-00/critical_point_tables/subdomain_1010_critical_points.csv", DataFrame)
println("Table 1010 has $(nrow(table_1010)) rows")
println("Columns: $(names(table_1010))")

# Check what's in subdomain_tables keys
println("\nChecking subdomain table keys:")
tables_dir = "outputs/enhanced_v3_17-00/critical_point_tables"
for file in readdir(tables_dir)
    if endswith(file, ".csv") && startswith(file, "subdomain_")
        # Extract label from filename
        label = replace(file, "subdomain_" => "", "_critical_points.csv" => "")
        println("  File: $file -> Label: '$label' (type: $(typeof(label)))")
    end
end

# The issue: when CriticalPointTablesV2 returns subdomain_tables,
# the keys are strings like "0000", "1010", etc.
# But when we iterate through them, we need to make sure we're using
# the same string keys consistently.