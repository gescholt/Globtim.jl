using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim
using DynamicPolynomials
using DataFrames
using Printf

# Include necessary modules
include(joinpath(@__DIR__, "shared/Common4DDeuflhard.jl"))
include(joinpath(@__DIR__, "shared/SubdomainManagement.jl"))
include(joinpath(@__DIR__, "shared/TheoreticalPoints.jl"))
using .Common4DDeuflhard
using .SubdomainManagement
using .TheoreticalPoints

println("Analyzing theoretical minimizer distribution across subdomains...")
println("="^70)

# Load theoretical minimizers
theoretical_points, theoretical_values, theoretical_types = load_theoretical_4d_points()

# Filter for only minimizers
minimizer_indices = findall(contains("min+min"), theoretical_types)
theoretical_points = theoretical_points[minimizer_indices]
theoretical_values = theoretical_values[minimizer_indices]

println("\nTotal theoretical minimizers: $(length(theoretical_points))")
println("\nTheoretical minimizer coordinates:")
for (i, pt) in enumerate(theoretical_points)
    println("  $i: [$(join(map(x -> @sprintf("%.6f", x), pt), ", "))]")
end

# Define the subdomain grid
subdomain_centers = [
    [0.0, 0.0, 0.0, 0.0],
    [0.25, 0.0, 0.0, 0.0],
    [-0.25, 0.0, 0.0, 0.0],
    [0.0, 0.25, 0.0, 0.0],
    [0.0, -0.25, 0.0, 0.0],
    [0.0, 0.0, 0.25, 0.0],
    [0.0, 0.0, -0.25, 0.0],
    [0.0, 0.0, 0.0, 0.25],
    [0.0, 0.0, 0.0, -0.25]
]

# Check which minimizers belong to which subdomain
println("\n" * "="^70)
println("Checking subdomain membership (sample_range = 0.5):")
println("="^70)

subdomain_counts = zeros(Int, length(subdomain_centers))
minimizer_assignments = Vector{Vector{Int}}(undef, length(subdomain_centers))
for i in 1:length(subdomain_centers)
    minimizer_assignments[i] = Int[]
end

for (min_idx, min_pt) in enumerate(theoretical_points)
    println("\nMinimizer $min_idx: [$(join(map(x -> @sprintf("%.6f", x), min_pt), ", "))]")
    
    belongs_to = Int[]
    for (sub_idx, center) in enumerate(subdomain_centers)
        # Check if point is within subdomain bounds
        in_bounds = true
        for dim in 1:4
            if abs(min_pt[dim] - center[dim]) > 0.5
                in_bounds = false
                break
            end
        end
        
        if in_bounds
            push!(belongs_to, sub_idx)
            push!(minimizer_assignments[sub_idx], min_idx)
            subdomain_counts[sub_idx] += 1
            
            # Calculate distance to center
            dist = sqrt(sum((min_pt[i] - center[i])^2 for i in 1:4))
            println("  ✓ In subdomain $sub_idx (center: [$(join(map(x -> @sprintf("%.2f", x), center), ", "))], distance: $(@sprintf("%.6f", dist)))")
        end
    end
    
    if isempty(belongs_to)
        println("  ✗ Not in any subdomain!")
    end
end

# Summary
println("\n" * "="^70)
println("SUMMARY: Minimizer counts per subdomain")
println("="^70)
for (i, center) in enumerate(subdomain_centers)
    println("Subdomain $i (center: [$(join(map(x -> @sprintf("%.2f", x), center), ", "))]): $(subdomain_counts[i]) minimizers")
    if subdomain_counts[i] > 0
        println("  Contains minimizers: $(join(minimizer_assignments[i], ", "))")
    end
end

# Check overlaps
println("\n" * "="^70)
println("Checking for minimizers in multiple subdomains:")
println("="^70)
for (min_idx, min_pt) in enumerate(theoretical_points)
    count = 0
    subdomains = Int[]
    for (sub_idx, assignments) in enumerate(minimizer_assignments)
        if min_idx in assignments
            count += 1
            push!(subdomains, sub_idx)
        end
    end
    if count > 1
        println("Minimizer $min_idx is in $(count) subdomains: $(join(subdomains, ", "))")
    end
end

# Analyze the bounds more carefully
println("\n" * "="^70)
println("Analyzing subdomain bounds:")
println("="^70)
for (i, center) in enumerate(subdomain_centers)
    println("\nSubdomain $i:")
    println("  Center: [$(join(map(x -> @sprintf("%.2f", x), center), ", "))]")
    println("  Bounds: [$(join(map(j -> @sprintf("[%.2f, %.2f]", center[j]-0.5, center[j]+0.5), 1:4), ", "))]")
end

# Check if theoretical minimizers are within overall search space
println("\n" * "="^70)
println("Checking if minimizers are within overall search space:")
println("="^70)
overall_bounds = [-0.75, 0.75]  # Based on the subdomain layout
out_of_bounds = 0
for (i, pt) in enumerate(theoretical_points)
    in_bounds = true
    for dim in 1:4
        if pt[dim] < overall_bounds[1] || pt[dim] > overall_bounds[2]
            in_bounds = false
            println("Minimizer $i is OUT OF BOUNDS in dimension $dim: $(pt[dim])")
            out_of_bounds += 1
            break
        end
    end
end
println("\nTotal minimizers out of overall bounds: $out_of_bounds")