using CSV, DataFrames, Statistics

table = CSV.read("outputs/enhanced_v3_17-00/critical_point_tables/subdomain_1010_critical_points.csv", DataFrame)
d3 = filter(!isnan, table.degree_3)
d4 = filter(!isnan, table.degree_4)

println("Subdomain 1010:")
println("  Degree 3: $(length(d3)) values, mean = $(mean(d3))")
println("  Degree 4: $(length(d4)) values, mean = $(mean(d4))")
println("  This should give avg_distances = [$(mean(d3)), $(mean(d4))]")