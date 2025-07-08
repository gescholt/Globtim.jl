"""
Verification script to check the implementation strategy for subdivided analysis
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using SubdomainManagement
using TheoreticalPoints
using Printf

println("="^80)
println("VERIFICATION: Implementation Strategy Check")
println("="^80)

# Step 1: Verify main domain bounds
println("\nStep 1: Verify main orthant domain")
println("-"^40)
println("Expected: [0,1] × [-1,0] × [0,1] × [-1,0]")

# Step 2: Check subdivision generation
println("\nStep 2: Verify 16-way subdivision")
println("-"^40)
subdivisions = generate_16_subdivisions_orthant()
println("Number of subdomains generated: $(length(subdivisions))")

# Display first few subdomains to verify pattern
println("\nFirst 4 subdomains:")
for (i, subdomain) in enumerate(subdivisions[1:4])
    println("  $(subdomain.label): center=$(subdomain.center), range=$(subdomain.range)")
    println("    Bounds: $(subdomain.bounds)")
end

# Step 3: Load theoretical points and check distribution
println("\nStep 3: Verify theoretical point distribution")
println("-"^40)
points_2d, types_2d = load_2d_critical_points_orthant()
points_4d, values_4d, types_4d = generate_4d_tensor_products_orthant(points_2d, types_2d)

println("Total 4D theoretical points: $(length(points_4d))")
println("Point type breakdown:")
type_counts = Dict{String,Int}()
for t in types_4d
    type_counts[t] = get(type_counts, t, 0) + 1
end
for (ptype, count) in sort(collect(type_counts))
    println("  $ptype: $count points")
end

# Step 4: Check point assignment to subdomains
println("\nStep 4: Verify point assignment to subdomains")
println("-"^40)
subdomain_point_counts = Dict{String,Dict{String,Int}}()

for subdomain in subdivisions
    subdomain_point_counts[subdomain.label] = Dict{String,Int}()
    
    for (i, pt) in enumerate(points_4d)
        # Check if point is in subdomain bounds
        in_bounds = true
        for (j, coord) in enumerate(pt)
            if coord < subdomain.bounds[j][1] || coord > subdomain.bounds[j][2]
                in_bounds = false
                break
            end
        end
        
        if in_bounds
            ptype = types_4d[i]
            subdomain_point_counts[subdomain.label][ptype] = 
                get(subdomain_point_counts[subdomain.label], ptype, 0) + 1
        end
    end
end

# Display distribution
println("Theoretical points per subdomain:")
for label in sort(collect(keys(subdomain_point_counts)))
    counts = subdomain_point_counts[label]
    total = sum(values(counts))
    if total > 0
        println("  $label: $total points")
        for (ptype, count) in sort(collect(counts))
            println("    - $ptype: $count")
        end
    end
end

# Count how many subdomains have points
subdomains_with_points = count(d -> sum(values(d)) > 0, values(subdomain_point_counts))
println("\nSubdomains with theoretical points: $subdomains_with_points/16")

# Step 5: Verify subdomain bounds consistency
println("\nStep 5: Verify subdomain bounds consistency")
println("-"^40)

# Check that subdomains cover the full orthant
all_centers = [s.center for s in subdivisions]
all_ranges = [s.range for s in subdivisions]

# Check bounds coverage
dim_coverage = [[1.0, -1.0, 1.0, -1.0] for _ in 1:4]  # min/max for each dimension
for subdomain in subdivisions
    for d in 1:4
        dim_coverage[d][1] = min(dim_coverage[d][1], subdomain.bounds[d][1])
        dim_coverage[d][2] = max(dim_coverage[d][2], subdomain.bounds[d][2])
    end
end

println("Dimension coverage (should match orthant bounds):")
expected = [[0.0, 1.0], [-1.0, 0.0], [0.0, 1.0], [-1.0, 0.0]]
for d in 1:4
    actual = [dim_coverage[d][1], dim_coverage[d][2]]
    match = actual ≈ expected[d]
    println("  Dim $d: $actual $(match ? "✓" : "✗ Expected $(expected[d])")")
end

# Step 6: Check for overlaps or gaps
println("\nStep 6: Check for overlaps or gaps between subdomains")
println("-"^40)

# Simple check: all ranges should be the same
unique_ranges = unique(all_ranges)
println("Unique subdomain ranges: $unique_ranges")
println("All ranges equal: $(length(unique_ranges) == 1)")

# Check that centers form a grid
println("\nCenter grid check:")
for d in 1:4
    centers_d = sort(unique([c[d] for c in all_centers]))
    println("  Dim $d centers: $centers_d")
end

println("\n" * "="^80)
println("VERIFICATION COMPLETE")
println("="^80)