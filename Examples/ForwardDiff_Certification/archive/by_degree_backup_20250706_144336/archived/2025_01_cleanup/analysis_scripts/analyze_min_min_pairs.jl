# ================================================================================
# Analyze Min+Min Pairs from 2D Deuflhard Critical Points
# ================================================================================

using CSV
using DataFrames
using Printf

# Read the CSV file
csv_path = "points_deufl/2d_coords.csv"
df = CSV.read(csv_path, DataFrame)

println("📊 2D Critical Points Analysis")
println("=" ^ 50)

# Display all points
println("\nAll 2D critical points:")
for i in 1:nrow(df)
    println(@sprintf("  Point %2d: [%8.5f, %8.5f] %s", 
                     i, df.x[i], df.y[i], df.label[i]))
end

# ================================================================================
# 1. Identify points in [0,1] × [-1,0] domain
# ================================================================================

println("\n🎯 Step 1: Identify points in [0,1] × [-1,0] domain")
println("-" ^ 50)

# Filter points in the [0,1] × [-1,0] domain
domain_mask = (df.x .>= 0.0) .& (df.x .<= 1.0) .& (df.y .>= -1.0) .& (df.y .<= 0.0)
domain_points = df[domain_mask, :]

println("Points in [0,1] × [-1,0] domain:")
for i in 1:nrow(domain_points)
    println(@sprintf("  Point %2d: [%8.5f, %8.5f] %s", 
                     i, domain_points.x[i], domain_points.y[i], domain_points.label[i]))
end

# ================================================================================
# 2. Extract minimizers only
# ================================================================================

println("\n🎯 Step 2: Extract minimizers from domain points")
println("-" ^ 50)

# Filter for minimizers only
minimizer_mask = domain_points.label .== "min"
minimizers = domain_points[minimizer_mask, :]

println("Minimizers in [0,1] × [-1,0] domain:")
for i in 1:nrow(minimizers)
    println(@sprintf("  Min %2d: [%8.5f, %8.5f]", 
                     i, minimizers.x[i], minimizers.y[i]))
end

println("\nTotal minimizers found: $(nrow(minimizers))")

# ================================================================================
# 3. Generate all 4D min+min pairs
# ================================================================================

println("\n🎯 Step 3: Generate all 4D min+min pairs")
println("-" ^ 50)

# Generate all pairs of minimizers for 4D min+min combinations
min_min_pairs = []
pair_count = 0

for i in 1:nrow(minimizers)
    for j in 1:nrow(minimizers)
        pair_count += 1
        
        # Create 4D point: [x1, y1, x2, y2]
        point_4d = [minimizers.x[i], minimizers.y[i], minimizers.x[j], minimizers.y[j]]
        
        push!(min_min_pairs, (
            pair_id = pair_count,
            min1_index = i,
            min2_index = j,
            point_4d = point_4d,
            min1_coords = [minimizers.x[i], minimizers.y[i]],
            min2_coords = [minimizers.x[j], minimizers.y[j]]
        ))
    end
end

println("Generated $(length(min_min_pairs)) min+min pairs:")
println("\nDetailed 4D min+min pairs:")
for (idx, pair) in enumerate(min_min_pairs)
    println(@sprintf("  Pair %2d: Min%d × Min%d", idx, pair.min1_index, pair.min2_index))
    println(@sprintf("    Min1: [%8.5f, %8.5f]", pair.min1_coords[1], pair.min1_coords[2]))
    println(@sprintf("    Min2: [%8.5f, %8.5f]", pair.min2_coords[1], pair.min2_coords[2]))
    println(@sprintf("    4D:   [%8.5f, %8.5f, %8.5f, %8.5f]", 
                     pair.point_4d[1], pair.point_4d[2], pair.point_4d[3], pair.point_4d[4]))
    println()
end

# ================================================================================
# 4. Summary statistics
# ================================================================================

println("📊 Summary Statistics")
println("=" ^ 50)

total_points = nrow(df)
domain_count = nrow(domain_points)
minimizer_count = nrow(minimizers)
expected_pairs = minimizer_count * minimizer_count

println("Total 2D critical points: $total_points")
println("Points in [0,1] × [-1,0]: $domain_count")
println("Minimizers in domain: $minimizer_count")
println("Expected 4D min+min pairs: $minimizer_count × $minimizer_count = $expected_pairs")
println("Generated 4D min+min pairs: $(length(min_min_pairs))")
println("✅ Verification: $(expected_pairs == length(min_min_pairs) ? "PASSED" : "FAILED")")

# ================================================================================
# 5. Export results
# ================================================================================

println("\n📁 Exporting results...")

# Export minimizers
minimizers_output = DataFrame(
    index = 1:nrow(minimizers),
    x = minimizers.x,
    y = minimizers.y,
    label = minimizers.label
)

CSV.write("minimizers_in_domain.csv", minimizers_output)
println("✅ Minimizers exported to: minimizers_in_domain.csv")

# Export 4D min+min pairs
pairs_output = DataFrame(
    pair_id = [p.pair_id for p in min_min_pairs],
    min1_index = [p.min1_index for p in min_min_pairs],
    min2_index = [p.min2_index for p in min_min_pairs],
    x1 = [p.point_4d[1] for p in min_min_pairs],
    y1 = [p.point_4d[2] for p in min_min_pairs],
    x2 = [p.point_4d[3] for p in min_min_pairs],
    y2 = [p.point_4d[4] for p in min_min_pairs]
)

CSV.write("min_min_pairs_4d.csv", pairs_output)
println("✅ 4D min+min pairs exported to: min_min_pairs_4d.csv")

println("\n🎉 Analysis complete!")