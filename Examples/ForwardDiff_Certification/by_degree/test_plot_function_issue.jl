# Test the exact issue in plot_subdomain_distance_evolution
using DataFrames, Statistics

# Create mock subdomain tables exactly as CriticalPointTablesV2 would
subdomain_tables = Dict{String, DataFrame}()

# Create a table for subdomain "1010"
table = DataFrame(
    point_id = ["CP_001", "CP_002", "CP_003"],
    type = ["min", "saddle", "min"],
    x1 = [0.5, 0.5, 0.5],
    x2 = [0.5, 0.5, 0.5],
    x3 = [0.5, 0.5, 0.5],
    x4 = [0.5, 0.5, 0.5],
    degree_3 = [0.1, 0.2, 0.3]
)
subdomain_tables["1010"] = table

# Create empty table for subdomain "0000"
subdomain_tables["0000"] = DataFrame()

println("=== Testing Plot Function Logic ===\n")

# Step 1: Filter as done in plot function
println("Step 1: Filter active tables")
active_subdomain_tables = filter(x -> !isempty(x[2]), subdomain_tables)
println("  Original tables: $(length(subdomain_tables))")
println("  Active tables: $(length(active_subdomain_tables))")
println("  Type after filter: $(typeof(active_subdomain_tables))")

# Step 2: Try to iterate as in plot function
println("\nStep 2: Iterate over active tables")
subdomain_avg_distances = Dict{String, Vector{Float64}}()
degrees = [3]

for (subdomain_label, table) in active_subdomain_tables
    println("\n  Processing subdomain: $subdomain_label")
    println("    Table type: $(typeof(table))")
    println("    Table size: $(size(table))")
    
    avg_distances = Float64[]
    
    for degree in degrees
        col_name = Symbol("degree_$degree")
        println("    Looking for column: $col_name")
        println("    Available columns: $(names(table))")
        
        if col_name in names(table)
            println("    ✓ Column found!")
            
            # Get column
            distances = table[!, col_name]
            println("    Column type: $(typeof(distances))")
            println("    Column values: $distances")
            
            # Try filter
            try
                finite_distances = filter(!isnan, distances)
                println("    Filter succeeded: $(length(finite_distances)) values")
                
                if isempty(finite_distances)
                    push!(avg_distances, NaN)
                else
                    avg_dist = mean(finite_distances)
                    push!(avg_distances, avg_dist)
                    println("    Mean: $avg_dist")
                end
            catch e
                println("    ❌ Filter failed: $e")
                println("    Error type: $(typeof(e))")
            end
        else
            println("    ❌ Column not found!")
            push!(avg_distances, NaN)
        end
    end
    
    subdomain_avg_distances[subdomain_label] = avg_distances
end

println("\n\nStep 3: Results")
println("  subdomain_avg_distances: $subdomain_avg_distances")

# Step 4: Test the problematic filter directly
println("\n\nStep 4: Direct filter test")
test_vec = [0.1, 0.2, NaN, 0.3]
println("  Test vector: $test_vec")
println("  Type: $(typeof(test_vec))")

try
    result = filter(!isnan, test_vec)
    println("  ✓ Filter worked: $result")
catch e
    println("  ❌ Filter failed: $e")
end

# Step 5: Check if it's a DataFrame column issue
println("\n\nStep 5: DataFrame column test")
df = DataFrame(col = [0.1, 0.2, NaN, 0.3])
println("  DataFrame column type: $(typeof(df.col))")
println("  Column eltype: $(eltype(df.col))")

try
    result = filter(!isnan, df.col)
    println("  ✓ Filter on DataFrame column worked: $result")
catch e
    println("  ❌ Filter on DataFrame column failed: $e")
end