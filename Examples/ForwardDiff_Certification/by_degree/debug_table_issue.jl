# Debug why subdomain distance plot has no data

using CSV, DataFrames, Statistics

# Check the generated tables
tables_dir = "outputs/enhanced_v3_17-00/critical_point_tables"

println("Checking tables in $tables_dir:")
for file in readdir(tables_dir)
    if endswith(file, ".csv")
        table = CSV.read(joinpath(tables_dir, file), DataFrame)
        println("\n$file:")
        println("  Columns: $(names(table))")
        println("  Rows: $(nrow(table))")
        
        # Check degree columns
        for col in names(table)
            if startswith(string(col), "degree_")
                distances = table[!, col]
                valid = filter(!isnan, distances)
                if !isempty(valid)
                    println("  $col: $(length(valid))/$(length(distances)) valid, mean=$(mean(valid))")
                else
                    println("  $col: ALL NaN")
                end
            end
        end
    end
end

# Also check the subdomain summary
summary_file = "outputs/enhanced_v3_17-00/subdomain_summary.csv"
if isfile(summary_file)
    println("\n\nSubdomain Summary:")
    summary = CSV.read(summary_file, DataFrame)
    display(summary)
end