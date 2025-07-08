"""
Debug script to identify why all 16 curves in L2 convergence plot are identical.
This script will examine the subdivision generation and theoretical point loading.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

# Add shared directory to load path
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

# Load shared utilities
using Common4DDeuflhard
using SubdomainManagement
using TheoreticalPoints

using Printf
using DataFrames
using CSV

println("=== Debugging Subdivision Issue ===")
println()

# 1. Check subdomain generation
println("1. Generating 16 subdivisions for orthant...")
subdivisions = generate_16_subdivisions_orthant()
println("Generated $(length(subdivisions)) subdivisions")

for (i, sub) in enumerate(subdivisions)
    println("  $i. Label: $(sub.label), Center: $(sub.center), Bounds: $(sub.bounds)")
end

println()

# 2. Load all theoretical points for orthant
println("2. Loading theoretical points for orthant...")
all_theo_points, all_theo_values, all_theo_types = load_theoretical_4d_points_orthant()
println("Total theoretical points: $(length(all_theo_points))")

# Show the first few theoretical points
println("First 5 theoretical points:")
for i in 1:min(5, length(all_theo_points))
    println("  $i. $(all_theo_points[i]) - $(all_theo_types[i])")
end

println()

# 3. Check which subdomains contain theoretical points
println("3. Checking theoretical point distribution across subdomains...")
point_counts = Dict{String, Int}()

for (i, subdomain) in enumerate(subdivisions)
    filtered_points, filtered_values, filtered_types = 
        load_theoretical_points_for_subdomain_orthant(subdomain)
    
    point_counts[subdomain.label] = length(filtered_points)
    
    if length(filtered_points) > 0
        println("  Subdomain $(subdomain.label): $(length(filtered_points)) points")
        println("    Bounds: $(subdomain.bounds)")
        println("    Points: $(filtered_points)")
        println("    Types: $(filtered_types)")
    else
        println("  Subdomain $(subdomain.label): 0 points")
    end
end

println()

# 4. Summary statistics
println("4. Summary statistics:")
non_empty_subdomains = [label for (label, count) in point_counts if count > 0]
total_points_in_subdomains = sum(values(point_counts))

println("  - Non-empty subdomains: $(length(non_empty_subdomains))")
println("  - Labels with points: $(sort(non_empty_subdomains))")
println("  - Total points across all subdomains: $(total_points_in_subdomains)")
println("  - Total points from full orthant: $(length(all_theo_points))")

if total_points_in_subdomains != length(all_theo_points)
    println("  ⚠️  ISSUE: Point count mismatch! Some points are not being assigned to subdomains.")
end

# 5. Examine point bounds vs orthant bounds
println()
println("5. Examining theoretical point bounds vs orthant bounds:")
println("  Orthant bounds: [0,1] × [-1,0] × [0,1] × [-1,0]")

if !isempty(all_theo_points)
    # Check if all theoretical points are within orthant bounds
    for (i, pt) in enumerate(all_theo_points)
        in_orthant = (pt[1] >= 0 && pt[1] <= 1 && 
                     pt[2] >= -1 && pt[2] <= 0 && 
                     pt[3] >= 0 && pt[3] <= 1 && 
                     pt[4] >= -1 && pt[4] <= 0)
        
        if !in_orthant
            println("  Point $i OUTSIDE orthant bounds: $(pt)")
        else
            println("  Point $i within orthant bounds: $(pt)")
        end
    end
end

# 6. Check specific subdomain bounds vs theoretical points
println()
println("6. Detailed subdomain containment check:")

# Focus on subdomain "1010" since that's the only one with results
subdomain_1010 = subdivisions[findfirst(s -> s.label == "1010", subdivisions)]
println("  Subdomain 1010 bounds: $(subdomain_1010.bounds)")

filtered_points_1010, _, _ = load_theoretical_points_for_subdomain_orthant(subdomain_1010)
println("  Points in subdomain 1010: $(length(filtered_points_1010))")

# Check all theoretical points against subdomain 1010 bounds manually
println("  Manual containment check for all theoretical points:")
for (i, pt) in enumerate(all_theo_points)
    is_contained = is_point_in_subdomain(pt, subdomain_1010, tolerance=0.0)
    println("    Point $i: $(pt) -> $(is_contained ? "CONTAINED" : "not contained")")
end

println()
println("=== Debug Complete ===")