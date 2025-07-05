using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using TheoreticalPoints
using Printf

println("Verifying 2D critical points in (+,-) orthant [0,1] × [-1,0]")
println("="^80)

# Load all 2D points
all_2d, all_types = load_2d_critical_points()
println("Total 2D critical points: $(length(all_2d))")

# Load orthant-specific points
orthant_2d, orthant_types = load_2d_critical_points_orthant()
println("Points in (+,-) orthant [0,1] × [-1,0]: $(length(orthant_2d))")

println("\nAll 2D critical points:")
for (i, (pt, ptype)) in enumerate(zip(all_2d, all_types))
    in_orthant = pt[1] >= 0 && pt[1] <= 1 && pt[2] >= -1 && pt[2] <= 0
    marker = in_orthant ? "✓" : " "
    println("  $marker Point $(@sprintf("%2d", i)): [$(@sprintf("%7.3f", pt[1])), $(@sprintf("%7.3f", pt[2]))] - $ptype")
end

println("\n2D Points in (+,-) orthant:")
for (i, (pt, ptype)) in enumerate(zip(orthant_2d, orthant_types))
    println("  Point $i: [$(@sprintf("%.3f", pt[1])), $(@sprintf("%.3f", pt[2]))] - $ptype")
end

# Show the coordinate ranges
if !isempty(orthant_2d)
    x_coords = [pt[1] for pt in orthant_2d]
    y_coords = [pt[2] for pt in orthant_2d]
    
    println("\nCoordinate ranges in (+,-) orthant:")
    println("  X range: [$(@sprintf("%.3f", minimum(x_coords))), $(@sprintf("%.3f", maximum(x_coords)))]")
    println("  Y range: [$(@sprintf("%.3f", minimum(y_coords))), $(@sprintf("%.3f", maximum(y_coords)))]")
    
    # Check subdivision boundaries
    println("\nSubdivision at x=0.5, y=-0.5:")
    println("  Points with x < 0.5: $(sum(x_coords .< 0.5))")
    println("  Points with x > 0.5: $(sum(x_coords .> 0.5))")
    println("  Points with y < -0.5: $(sum(y_coords .< -0.5))")
    println("  Points with y > -0.5: $(sum(y_coords .> -0.5))")
end

# Generate 4D points
println("\n4D Tensor Products:")
points_4d, values_4d, types_4d = load_theoretical_4d_points_orthant()
println("Total 4D points in (+,-,+,-) orthant: $(length(points_4d))")

# Check which subdomain each belongs to
println("\nSubdomain assignment for 4D points:")
subdomain_counts = Dict{String, Int}()
for pt in points_4d
    # Determine binary label based on midpoint divisions
    label = ""
    label *= pt[1] < 0.5 ? "0" : "1"
    label *= pt[2] < -0.5 ? "0" : "1"
    label *= pt[3] < 0.5 ? "0" : "1"
    label *= pt[4] < -0.5 ? "0" : "1"
    
    subdomain_counts[label] = get(subdomain_counts, label, 0) + 1
end

for (label, count) in sort(subdomain_counts)
    println("  Subdomain $label: $count points")
end

println("\n" * "="^80)
println("CONCLUSION:")
if length(subdomain_counts) == 1
    only_label = first(keys(subdomain_counts))
    println("✓ All $(length(points_4d)) points fall in subdomain $only_label")
    println("✓ This confirms the clustering phenomenon is real")
else
    println("✗ Points are distributed across $(length(subdomain_counts)) subdomains")
end