using CSV, DataFrames
using LinearAlgebra
using Statistics

include("shared/SubdomainManagement.jl")
using .SubdomainManagement

# Load the true minimizers
true_minimizers = []
csv_data = CSV.read(joinpath(@__DIR__, "points_deufl/4d_min_min_domain.csv"), DataFrame)
for row in eachrow(csv_data)
    if row.is_minimizer
        push!(true_minimizers, [row.x1, row.x2, row.x3, row.x4])
    end
end

println("Number of true minimizers: ", length(true_minimizers))

# Generate subdomains
subdomains = generate_16_subdivisions_orthant()

# Check domain coverage
println("\nSubdomain stretching analysis:")
println("Original orthant: [0,1] × [-1,0] × [0,1] × [-1,0]")
println("Stretched orthant: [-0.1,1.1] × [-1.1,0.1] × [-0.1,1.1] × [-1.1,0.1]")

# Analyze true minimizer distribution
println("\n\nTrue minimizer distribution by subdomain:")
subdomain_counts = Dict{String, Int}()
for subdomain in subdomains
    subdomain_counts[subdomain.label] = 0
end

for true_min in true_minimizers
    assigned_subdomain = assign_point_to_unique_subdomain(true_min, subdomains)
    if assigned_subdomain !== nothing
        subdomain_counts[assigned_subdomain.label] += 1
    end
end

for (label, count) in sort(subdomain_counts)
    println("  Subdomain $label: $count minimizers")
end

# Simulate what happens in the distance calculation
println("\n\nSimulating distance calculation logic:")
println("=" ^ 60)

# Example: Simulating results from multiple subdomains
# Let's say we have some computed points (these would come from critical point finding)
simulated_computed_points = [
    # Points near true minimizers
    [0.25, -1.01, 0.25, -1.01],  # Close to minimizer 1
    [0.74, -0.74, 0.74, -0.74],  # Close to minimizer 5
    [1.01, -0.25, 1.01, -0.25],  # Close to minimizer 9
    
    # Points far from true minimizers (spurious critical points)
    [0.0, 0.0, 0.0, 0.0],        # At origin
    [-0.05, -0.5, -0.05, -0.5],  # In stretched region
    [0.5, -0.5, 0.5, -0.5],      # In middle of domain
    [1.05, -0.05, 1.05, -0.05],  # Near boundary
]

# Calculate distances as done in the original code
all_min_distances = Float64[]
for computed_pt in simulated_computed_points
    distances_to_true = [norm(computed_pt - true_min) for true_min in true_minimizers]
    min_dist = minimum(distances_to_true)
    push!(all_min_distances, min_dist)
    
    println("\nPoint: ", computed_pt)
    println("  Min distance to true minimizer: ", round(min_dist, digits=4))
    
    # Which subdomain would this point belong to?
    assigned = assign_point_to_unique_subdomain(computed_pt, subdomains)
    if assigned !== nothing
        println("  Assigned to subdomain: ", assigned.label)
    else
        println("  NOT IN ANY SUBDOMAIN!")
    end
end

println("\n\nDistance statistics from simulated points:")
println("  Min distance: ", round(minimum(all_min_distances), digits=4))
println("  Max distance: ", round(maximum(all_min_distances), digits=4))
println("  Mean distance: ", round(mean(all_min_distances), digits=4))

# Analyze potential issues
println("\n\nPotential issues in distance calculation:")
println("=" ^ 60)

println("\n1. Domain Stretching Effect:")
println("   - Subdomains are stretched by 0.1 on each side")
println("   - This allows polynomial approximation to capture behavior near boundaries")
println("   - BUT: Critical points can appear in stretched regions far from true minimizers")

println("\n2. All Critical Points vs Subdomain Points:")
println("   - The code finds ALL critical points of the polynomial")
println("   - Then filters to keep only those in the subdomain")
println("   - BUT: The distance calculation uses ALL computed points from ALL subdomains")

println("\n3. Maximum Distance Issue:")
println("   - Max distance of ~1.4 is approximately sqrt(2) ≈ 1.414")
println("   - This suggests points at opposite corners of the domain")
println("   - Example: distance from [0,0,0,0] to [1,-1,1,-1] = sqrt(4) = 2.0")
println("   - Example: distance from [0.5,-0.5,0.5,-0.5] to minimizer at corner ≈ 1.4")

# Calculate theoretical maximum possible distance
println("\n\nTheoretical maximum distances:")
domain_corners = [
    [-0.1, -1.1, -0.1, -1.1],
    [-0.1, -1.1, -0.1, 0.1],
    [-0.1, -1.1, 1.1, -1.1],
    [-0.1, -1.1, 1.1, 0.1],
    [-0.1, 0.1, -0.1, -1.1],
    [-0.1, 0.1, -0.1, 0.1],
    [-0.1, 0.1, 1.1, -1.1],
    [-0.1, 0.1, 1.1, 0.1],
    [1.1, -1.1, -0.1, -1.1],
    [1.1, -1.1, -0.1, 0.1],
    [1.1, -1.1, 1.1, -1.1],
    [1.1, -1.1, 1.1, 0.1],
    [1.1, 0.1, -0.1, -1.1],
    [1.1, 0.1, -0.1, 0.1],
    [1.1, 0.1, 1.1, -1.1],
    [1.1, 0.1, 1.1, 0.1],
]

max_possible_dist = 0.0
worst_corner = nothing
worst_minimizer = nothing

for corner in domain_corners
    for true_min in true_minimizers
        dist = norm(corner - true_min)
        if dist > max_possible_dist
            global max_possible_dist = dist
            global worst_corner = corner
            global worst_minimizer = true_min
        end
    end
end

println("\nWorst case distance in stretched domain:")
println("  From corner: ", worst_corner)
println("  To minimizer: ", worst_minimizer)
println("  Distance: ", round(max_possible_dist, digits=4))

println("\n\nConclusion:")
println("The high max distances (~1.4) likely come from:")
println("1. Spurious critical points in the polynomial approximation")
println("2. These points being far from any true minimizer")
println("3. The stretched domain allowing points up to 0.1 outside the original orthant")
println("4. The aggregation of ALL computed points from ALL subdomains before distance calculation")