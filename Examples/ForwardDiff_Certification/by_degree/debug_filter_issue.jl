using CSV, DataFrames, Statistics

# Load a table from the current run
table = CSV.read("outputs/enhanced_v3_17-19/critical_point_tables/subdomain_1010_critical_points.csv", DataFrame)

println("Table info:")
println("  Columns: $(names(table))")
println("  Rows: $(nrow(table))")

# Check the degree_3 column
col = table.degree_3
println("\nColumn degree_3:")
println("  Type: $(typeof(col))")
println("  Eltype: $(eltype(col))")
println("  First few values: $(first(col, min(3, length(col))))")

# Try the filter
try
    filtered = filter(!isnan, col)
    println("  Filter worked! Got $(length(filtered)) values")
    println("  Mean: $(mean(filtered))")
catch e
    println("  Filter failed: $e")
    # Try alternative approach
    println("  Trying alternative filter...")
    filtered = [x for x in col if !ismissing(x) && !isnan(x)]
    println("  Got $(length(filtered)) values")
    if !isempty(filtered)
        println("  Mean: $(mean(filtered))")
    end
end