using DataFrames

# Create test DataFrame
df = DataFrame(degree_3 = [1.0, 2.0, 3.0])

println("Column names: $(names(df))")
println("Column names type: $(typeof(names(df)))")
println("First column name: $(names(df)[1])")
println("First column name type: $(typeof(names(df)[1]))")

# Test symbol comparison
col_name = Symbol("degree_3")
println("\nSymbol test:")
println("  col_name = Symbol(\"degree_3\") = $col_name")
println("  Type: $(typeof(col_name))")
degree_3_sym = :degree_3
println("  :degree_3 == col_name: $(degree_3_sym == col_name)")
str_result = "degree_3" == string(col_name)
println("  \"degree_3\" == string(col_name): $str_result")

# Test with names()
println("\nColumn lookup test:")
println("  col_name in names(df): $(col_name in names(df))")
str_in_names = "degree_3" in names(df)
println("  \"degree_3\" in names(df): $str_in_names")
println("  :degree_3 in propertynames(df): $(:degree_3 in propertynames(df))")

# The issue: names() returns Vector{String}, not Vector{Symbol}!
println("\nThe fix:")
println("  String(col_name) in names(df): $(String(col_name) in names(df))")