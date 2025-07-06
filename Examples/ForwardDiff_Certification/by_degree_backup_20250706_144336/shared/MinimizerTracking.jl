# MinimizerTracking.jl - Module for tracking minimizers across subdomains

module MinimizerTracking

using LinearAlgebra
using DataFrames
using ..SubdomainManagement: Subdomain, is_point_in_subdomain

export assign_minimizers_to_subdomains, compute_subdomain_distances
export SubdomainDistanceData

"""
Container for per-subdomain distance data
"""
struct SubdomainDistanceData
    subdomain_label::String
    degree::Int
    distances_to_minimizers::Vector{Float64}  # One per minimizer in this subdomain
    has_minimizers::Bool
    n_minimizers::Int
end

"""
    assign_minimizers_to_subdomains(true_minimizers, subdomains)

Assign each true minimizer to its containing subdomain.

# Returns
- Dict{String, Vector{Int}}: subdomain_label => indices of minimizers in that subdomain
"""
function assign_minimizers_to_subdomains(true_minimizers::Vector{Vector{Float64}}, 
                                       subdomains::Vector{Subdomain})
    assignment = Dict{String, Vector{Int}}()
    
    # Initialize empty arrays for each subdomain
    for subdomain in subdomains
        assignment[subdomain.label] = Int[]
    end
    
    # Assign each minimizer to its subdomain
    for (idx, minimizer) in enumerate(true_minimizers)
        for subdomain in subdomains
            if is_point_in_subdomain(minimizer, subdomain, tolerance=0.0)
                push!(assignment[subdomain.label], idx)
                break  # Each minimizer belongs to exactly one subdomain
            end
        end
    end
    
    return assignment
end

"""
    compute_subdomain_distances(computed_points, true_minimizers, minimizer_indices)

For a specific subdomain, compute distances from its true minimizers to computed points.

# Arguments
- `computed_points`: Vector of computed critical points in the subdomain
- `true_minimizers`: Vector of all true minimizers
- `minimizer_indices`: Indices of minimizers that belong to this subdomain

# Returns
- Vector{Float64}: Distance from each subdomain minimizer to nearest computed point
"""
function compute_subdomain_distances(computed_points::Vector{Vector{Float64}},
                                   true_minimizers::Vector{Vector{Float64}},
                                   minimizer_indices::Vector{Int})
    if isempty(minimizer_indices) || isempty(computed_points)
        return Float64[]
    end
    
    distances = Float64[]
    for idx in minimizer_indices
        min_dist = minimum(norm(computed_points[j] - true_minimizers[idx]) 
                          for j in 1:length(computed_points))
        push!(distances, min_dist)
    end
    
    return distances
end

end # module