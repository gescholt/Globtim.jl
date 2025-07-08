#!/usr/bin/env julia

# Quick test to understand the subdomain count mismatch

using CSV, DataFrames

# Load theoretical points
df_theory = CSV.read("data/4d_all_critical_points_orthant.csv", DataFrame)

# Count theoretical points
println("Total theoretical critical points: $(nrow(df_theory))")
println("  - Minima: $(sum(df_theory.type_4d .== "min"))")
println("  - Saddles: $(sum(df_theory.type_4d .== "saddle"))")

# Load subdomain management
include("src/SubdomainManagement.jl")
using .SubdomainManagement: generate_16_subdivisions_orthant, is_point_in_subdomain

# Generate subdomains
subdomains = generate_16_subdivisions_orthant()
println("\nTotal subdomains generated: $(length(subdomains))")

# Assign theoretical points to subdomains
subdomain_assignments = Dict{String, Vector{Int}}()
for subdomain in subdomains
    subdomain_assignments[subdomain.label] = Int[]
end

for (idx, row) in enumerate(eachrow(df_theory))
    theoretical_point = [row.x1, row.x2, row.x3, row.x4]
    for subdomain in subdomains
        if is_point_in_subdomain(theoretical_point, subdomain, tolerance=0.0)
            push!(subdomain_assignments[subdomain.label], idx)
            break
        end
    end
end

# Count subdomains with theoretical points
subdomains_with_theory = filter(x -> !isempty(x[2]), subdomain_assignments)
println("\nSubdomains with theoretical critical points: $(length(subdomains_with_theory))")

# List them
println("\nSubdomains with theoretical points:")
for (label, indices) in sort(collect(subdomains_with_theory), by=x->x[1])
    n_min = sum(df_theory.type_4d[indices] .== "min")
    n_saddle = sum(df_theory.type_4d[indices] .== "saddle")
    println("  $label: $(length(indices)) points ($n_min min, $n_saddle saddle)")
end

println("\n🔍 Key insight:")
println("Only $(length(subdomains_with_theory)) out of 16 subdomains contain theoretical critical points.")
println("This explains why subdomain_tables only has $(length(subdomains_with_theory)) entries.")