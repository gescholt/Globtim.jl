# Test to verify subdomain table structure and data flow
using CSV, DataFrames, Statistics

println("=== Testing Subdomain Table Structure ===\n")

# Test 1: Load and verify saved CSV structure
println("Test 1: Verify saved CSV files")
tables_dir = "outputs/enhanced_v3_17-19/critical_point_tables"
if isdir(tables_dir)
    csv_files = filter(f -> endswith(f, ".csv"), readdir(tables_dir))
    println("Found $(length(csv_files)) CSV files")
    
    # Check a sample file
    if "subdomain_1010_critical_points.csv" in csv_files
        table = CSV.read(joinpath(tables_dir, "subdomain_1010_critical_points.csv"), DataFrame)
        println("\nSubdomain 1010 table structure:")
        println("  Columns: $(names(table))")
        println("  Rows: $(nrow(table))")
        
        # Check degree_3 column
        if :degree_3 in names(table)
            col = table.degree_3
            println("  degree_3 column:")
            println("    Type: $(typeof(col))")
            println("    Eltype: $(eltype(col))")
            finite_vals = filter(!isnan, col)
            println("    Non-NaN values: $(length(finite_vals))")
            if !isempty(finite_vals)
                println("    Mean: $(mean(finite_vals))")
            end
        end
    end
end

# Test 2: Simulate the table generation process
println("\n\nTest 2: Simulate table generation")
# Create a mock subdomain table structure
mock_table = DataFrame(
    point_id = ["CP_001", "CP_002", "CP_003"],
    type = ["min", "saddle", "min"],
    x1 = [0.5, 0.5, 0.5],
    x2 = [0.5, 0.5, 0.5],
    x3 = [0.5, 0.5, 0.5],
    x4 = [0.5, 0.5, 0.5],
    degree_3 = [0.1, 0.2, NaN]
)

println("Mock table structure:")
println("  Columns: $(names(mock_table))")
println("  degree_3 type: $(typeof(mock_table.degree_3))")

# Test filter operation
try
    filtered = filter(!isnan, mock_table.degree_3)
    println("  Filter worked: $(length(filtered)) values")
    println("  Mean: $(mean(filtered))")
catch e
    println("  Filter failed: $e")
end

# Test 3: Check Dict structure
println("\n\nTest 3: Dict structure test")
subdomain_tables = Dict{String, DataFrame}()
subdomain_tables["1010"] = mock_table
subdomain_tables["0000"] = similar(mock_table)

println("Dict structure:")
println("  Type: $(typeof(subdomain_tables))")
println("  Keys: $(sort(collect(keys(subdomain_tables))))")

# Simulate the plot function's processing
active_tables = filter(x -> !isempty(x[2]), subdomain_tables)
println("  Active tables: $(length(active_tables))")
println("  Type after filter: $(typeof(active_tables))")

# Test iteration
println("\nIteration test:")
for (label, table) in active_tables
    println("  Label: $label, type: $(typeof(label))")
    println("  Table type: $(typeof(table))")
    println("  Table columns: $(names(table))")
    
    # Test column access
    col_name = Symbol("degree_3")
    if col_name in names(table)
        println("  Column $col_name found!")
        col = table[!, col_name]
        println("  Column type: $(typeof(col))")
    end
end

# Test 4: Type preservation through operations
println("\n\nTest 4: Type preservation")
# This simulates what happens in the plot function
function process_tables(tables::Dict{String, DataFrame})
    # Filter operation
    active = filter(x -> !isempty(x[2]), tables)
    println("After filter: $(typeof(active))")
    
    # Convert to array of tuples
    as_array = [(label, table) for (label, table) in active]
    println("As array: $(typeof(as_array))")
    
    return active, as_array
end

active1, active2 = process_tables(subdomain_tables)

println("\nConclusion: The issue might be in how the filtered Dict is being iterated")