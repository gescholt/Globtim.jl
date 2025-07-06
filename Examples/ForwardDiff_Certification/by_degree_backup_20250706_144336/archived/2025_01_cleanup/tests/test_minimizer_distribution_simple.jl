using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim
using CSV
using DataFrames
using LinearAlgebra
using ForwardDiff
using Printf

println("Analyzing theoretical minimizer distribution across subdomains...")
println("="^70)

# Define the 4D composite function
function deuflhard_4d_composite(x::AbstractVector)::Float64
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# Load 2D critical points from CSV
csv_path = joinpath(@__DIR__, "../../../data/matlab_critical_points/valid_points_deuflhard.csv")
if !isfile(csv_path)
    error("Critical points CSV file not found at: $csv_path")
end

csv_data = CSV.read(csv_path, DataFrame)
critical_2d = [[row.x, row.y] for row in eachrow(csv_data)]

# Classify 2D points using Hessian analysis
critical_2d_types = String[]
for pt in critical_2d
    hess = ForwardDiff.hessian(Deuflhard, pt)
    eigenvals = eigvals(hess)
    
    if all(eigenvals .> 1e-6)
        push!(critical_2d_types, "min")
    elseif all(eigenvals .< -1e-6)
        push!(critical_2d_types, "max")
    else
        push!(critical_2d_types, "saddle")
    end
end

println("\n2D critical points found: $(length(critical_2d))")
println("Types: $(join(unique(critical_2d_types), ", "))")

# Generate 4D tensor products - only minimizers
theoretical_points = Vector{Vector{Float64}}()
theoretical_values = Float64[]

for (i, pt1) in enumerate(critical_2d)
    for (j, pt2) in enumerate(critical_2d)
        if critical_2d_types[i] == "min" && critical_2d_types[j] == "min"
            point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
            value_4d = deuflhard_4d_composite(point_4d)
            
            push!(theoretical_points, point_4d)
            push!(theoretical_values, value_4d)
        end
    end
end

println("\nTotal theoretical minimizers (min+min): $(length(theoretical_points))")
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
overlap_count = 0
for (min_idx, min_pt) in enumerate(theoretical_points)
    local count = 0
    local subdomains = Int[]
    for (sub_idx, assignments) in enumerate(minimizer_assignments)
        if min_idx in assignments
            count += 1
            push!(subdomains, sub_idx)
        end
    end
    if count > 1
        global overlap_count += 1
        println("Minimizer $min_idx is in $(count) subdomains: $(join(subdomains, ", "))")
    end
end
if overlap_count == 0
    println("No minimizers found in multiple subdomains.")
end

# Analyze the bounds more carefully
println("\n" * "="^70)
println("Analyzing subdomain bounds:")
println("="^70)
for (i, center) in enumerate(subdomain_centers[1:3])  # Just show first 3 for brevity
    println("\nSubdomain $i:")
    println("  Center: [$(join(map(x -> @sprintf("%.2f", x), center), ", "))]")
    println("  Bounds: [$(join(map(j -> @sprintf("[%.2f, %.2f]", center[j]-0.5, center[j]+0.5), 1:4), ", "))]")
end
println("... ($(length(subdomain_centers) - 3) more subdomains)")

# Check if theoretical minimizers are within overall search space
println("\n" * "="^70)
println("Checking if minimizers are within overall search space:")
println("="^70)
overall_bounds = [-0.75, 0.75]  # Based on the subdomain layout
out_of_bounds_count = 0
for (i, pt) in enumerate(theoretical_points)
    local in_bounds = true
    for dim in 1:4
        if pt[dim] < overall_bounds[1] || pt[dim] > overall_bounds[2]
            in_bounds = false
            println("Minimizer $i is OUT OF BOUNDS in dimension $dim: $(pt[dim])")
            global out_of_bounds_count += 1
            break
        end
    end
end
println("\nTotal minimizers out of overall bounds: $out_of_bounds_count")

# Additional analysis: Check coordinate ranges
println("\n" * "="^70)
println("Coordinate ranges of theoretical minimizers:")
println("="^70)
for dim in 1:4
    coords = [pt[dim] for pt in theoretical_points]
    min_coord = minimum(coords)
    max_coord = maximum(coords)
    println("Dimension $dim: min = $(@sprintf("%.6f", min_coord)), max = $(@sprintf("%.6f", max_coord))")
end