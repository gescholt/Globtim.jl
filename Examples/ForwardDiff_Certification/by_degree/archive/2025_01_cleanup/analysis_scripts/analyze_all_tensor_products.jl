using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using TheoreticalPoints
using Printf

println("Analyzing ALL possible tensor products for (+,-,+,-) orthant")
println("="^80)

# Load ALL 2D critical points
all_2d, all_types = load_2d_critical_points()
println("Total 2D critical points: $(length(all_2d))")

# Generate ALL possible 4D tensor products that fall in (+,-,+,-) orthant
println("\nChecking which tensor products fall in (+,-,+,-) orthant:")
println("Required: x1 ∈ [0,1], x2 ∈ [-1,0], x3 ∈ [0,1], x4 ∈ [-1,0]")

valid_4d_points = Vector{Vector{Float64}}()
valid_4d_types = String[]

for (i, pt1) in enumerate(all_2d)
    for (j, pt2) in enumerate(all_2d)
        # Create 4D point: [pt1[1], pt1[2], pt2[1], pt2[2]]
        point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
        
        # Check if it's in (+,-,+,-) orthant
        if (0 <= point_4d[1] <= 1 && 
            -1 <= point_4d[2] <= 0 && 
            0 <= point_4d[3] <= 1 && 
            -1 <= point_4d[4] <= 0)
            
            push!(valid_4d_points, point_4d)
            push!(valid_4d_types, "$(all_types[i])+$(all_types[j])")
        end
    end
end

println("\nFound $(length(valid_4d_points)) valid 4D points in (+,-,+,-) orthant")

# Now check subdomain distribution
println("\nSubdomain assignment (split at 0.5, -0.5, 0.5, -0.5):")
subdomain_counts = Dict{String, Int}()

for pt in valid_4d_points
    # Determine binary label based on midpoint divisions
    label = ""
    label *= pt[1] < 0.5 ? "0" : "1"
    label *= pt[2] < -0.5 ? "0" : "1"
    label *= pt[3] < 0.5 ? "0" : "1"
    label *= pt[4] < -0.5 ? "0" : "1"
    
    subdomain_counts[label] = get(subdomain_counts, label, 0) + 1
end

println("\nPoints per subdomain:")
for (label, count) in sort(subdomain_counts)
    println("  Subdomain $label: $count points")
end

# Show coordinate ranges
if !isempty(valid_4d_points)
    println("\nCoordinate ranges of valid 4D points:")
    for dim in 1:4
        coords = [pt[dim] for pt in valid_4d_points]
        println("  Dim $dim: [$(minimum(coords)), $(maximum(coords))]")
    end
end

# List some example points from different subdomains
println("\nExample points from each subdomain:")
for (label, _) in sort(subdomain_counts)
    for (i, pt) in enumerate(valid_4d_points)
        pt_label = ""
        pt_label *= pt[1] < 0.5 ? "0" : "1"
        pt_label *= pt[2] < -0.5 ? "0" : "1"
        pt_label *= pt[3] < 0.5 ? "0" : "1"
        pt_label *= pt[4] < -0.5 ? "0" : "1"
        
        if pt_label == label
            println("  $label: [$(join([@sprintf("%.3f", x) for x in pt], ", "))] - $(valid_4d_types[i])")
            break
        end
    end
end