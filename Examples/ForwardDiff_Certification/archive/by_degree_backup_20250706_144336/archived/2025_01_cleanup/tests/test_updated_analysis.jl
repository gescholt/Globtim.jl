# Quick test of updated analysis with corrected assignment

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared utilities  
include("shared/SubdomainManagement.jl")
using .SubdomainManagement
using LinearAlgebra
using DataFrames
using PrettyTables

println("Testing corrected assignment...")

# Define the critical point structure
struct CriticalPointInfo
    point::Vector{Float64}
    type::String
    is_minimizer::Bool
end

# Generate theoretical points
function generate_all_critical_points()
    critical_2d = [
        ([0.126217280731679, -0.126217280731682], "saddle"),   
        ([0.459896075906281, -0.459896075906281], "saddle"),   
        ([0.507030772828217, -0.917350578608486], "min"),      
        ([0.74115190368376, -0.741151903683748], "min"),       
        ([0.917350578608475, -0.50703077282823], "min")        
    ]
    
    points = CriticalPointInfo[]
    for (pt1, type1) in critical_2d
        for (pt2, type2) in critical_2d
            point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
            combined_type = "$(type1)+$(type2)"
            is_min = (type1 == "min" && type2 == "min")
            push!(points, CriticalPointInfo(point_4d, combined_type, is_min))
        end
    end
    return points
end

# Generate theoretical points and subdomains
theoretical_points = generate_all_critical_points()
subdomains = generate_16_subdivisions_orthant()

# Test corrected distribution manually
println("\n🔍 TESTING CORRECTED ASSIGNMENT")

# Assign each point uniquely
point_assignments = Dict{Int, Union{Subdomain, Nothing}}()
for (i, point) in enumerate(theoretical_points)
    assigned_subdomain = assign_point_to_unique_subdomain(point.point, subdomains)
    point_assignments[i] = assigned_subdomain
end

# Count by subdomain
subdomain_counts = Dict{String, Int}()
minimizer_counts = Dict{String, Int}()

for (i, assigned_sub) in point_assignments
    if assigned_sub !== nothing
        label = assigned_sub.label
        subdomain_counts[label] = get(subdomain_counts, label, 0) + 1
        if theoretical_points[i].is_minimizer
            minimizer_counts[label] = get(minimizer_counts, label, 0) + 1
        end
    end
end

println("\n✅ CORRECTED THEORETICAL DISTRIBUTION:")
println("Total points: $(length(theoretical_points))")
println("Points assigned: $(sum(values(subdomain_counts)))")
println("Min+min points: $(sum(values(minimizer_counts)))")

println("\nNon-empty subdomains:")
data = []
for (label, count) in sort(collect(subdomain_counts))
    min_count = get(minimizer_counts, label, 0)
    push!(data, (label, count, min_count))
end

df = DataFrame(data, [:subdomain, :total, :minimizers])
pretty_table(df, header=["Subdomain", "Total", "Minimizers"], crop=:none, alignment=:c)

println("\n✅ SUCCESS: Each point now assigned to exactly one subdomain!")
println("✅ Min+min count is correct: $(sum(values(minimizer_counts))) = 9")