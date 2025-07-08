# Fixed version of compute_minimizer_recovery function

"""
    compute_minimizer_recovery(true_minimizers, computed_points_by_subdomain, subdomains; threshold)

Compute minimizer recovery statistics with improved metrics.

# Returns
- `recovery_df`: DataFrame with recovery statistics per subdomain
- `global_stats`: Overall recovery statistics
"""
function compute_minimizer_recovery(true_minimizers::Vector{Vector{Float64}},
                                   computed_points_by_subdomain::Dict{String, Vector{Vector{Float64}}},
                                   subdomains::Vector{Subdomain};
                                   threshold::Float64 = TRESH)
    # Recovery data per subdomain
    recovery_data = []
    
    # Track which minimizers are recovered globally
    minimizers_recovered = falses(length(true_minimizers))
    
    for subdomain in subdomains
        # Get computed points in this subdomain
        computed_pts = get(computed_points_by_subdomain, subdomain.label, Vector{Float64}[])
        
        # Check if subdomain contains any true minimizers
        subdomain_has_minimizer = false
        subdomain_minimizer_idx = 0
        
        for (idx, tm) in enumerate(true_minimizers)
            if is_point_in_subdomain(tm, subdomain, tolerance=0.0)
                subdomain_has_minimizer = true
                subdomain_minimizer_idx = idx
                break
            end
        end
        
        # Compute recovery status
        found_minimizer = false
        min_distance = Inf
        
        if subdomain_has_minimizer && !isempty(computed_pts)
            # Calculate distance from the true minimizer to nearest computed point
            true_min = true_minimizers[subdomain_minimizer_idx]
            min_distance = minimum(norm(true_min - cp) for cp in computed_pts)
            
            if min_distance < threshold
                found_minimizer = true
                minimizers_recovered[subdomain_minimizer_idx] = true
            end
        end
        
        # Calculate accuracy:
        # - If subdomain has minimizer: 100% if found, 0% if not
        # - If subdomain has no minimizer: 100% if no computed points (no false positives), 0% if has points
        accuracy = if subdomain_has_minimizer
            found_minimizer ? 100.0 : 0.0
        else
            isempty(computed_pts) ? 100.0 : 0.0
        end
        
        push!(recovery_data, (
            subdomain = subdomain.label,
            computed_points = length(computed_pts),
            has_minimizer = subdomain_has_minimizer,
            found_minimizer = found_minimizer,
            min_distance = subdomain_has_minimizer ? min_distance : NaN,
            accuracy = accuracy
        ))
    end
    
    recovery_df = DataFrame(recovery_data)
    
    # Global statistics
    global_stats = (
        total_minimizers = length(true_minimizers),
        total_recovered = sum(minimizers_recovered),
        global_recovery_rate = 100.0 * sum(minimizers_recovered) / length(true_minimizers)
    )
    
    return recovery_df, global_stats
end

# Enhanced version with more debugging info
function compute_minimizer_recovery_enhanced(true_minimizers::Vector{Vector{Float64}},
                                           computed_points_by_subdomain::Dict{String, Vector{Vector{Float64}}},
                                           subdomains::Vector{Subdomain};
                                           threshold::Float64 = TRESH,
                                           minimizer_assignment::Dict{String, Vector{Int}} = Dict{String, Vector{Int}}())
    # Recovery data per subdomain
    recovery_data = []
    
    # Track which minimizers are recovered globally
    minimizers_recovered = falses(length(true_minimizers))
    
    for subdomain in subdomains
        # Get computed points in this subdomain
        computed_pts = get(computed_points_by_subdomain, subdomain.label, Vector{Float64}[])
        
        # Get expected minimizers from assignment if provided
        expected_minimizers = get(minimizer_assignment, subdomain.label, Int[])
        
        # Check if subdomain contains any true minimizers
        subdomain_has_minimizer = false
        subdomain_minimizer_indices = Int[]
        
        for (idx, tm) in enumerate(true_minimizers)
            if is_point_in_subdomain(tm, subdomain, tolerance=0.0)
                subdomain_has_minimizer = true
                push!(subdomain_minimizer_indices, idx)
            end
        end
        
        # Compute recovery status for each minimizer in subdomain
        found_minimizers = Int[]
        min_distances = Float64[]
        
        if subdomain_has_minimizer && !isempty(computed_pts)
            for min_idx in subdomain_minimizer_indices
                true_min = true_minimizers[min_idx]
                min_distance = minimum(norm(true_min - cp) for cp in computed_pts)
                push!(min_distances, min_distance)
                
                if min_distance < threshold
                    push!(found_minimizers, min_idx)
                    minimizers_recovered[min_idx] = true
                end
            end
        end
        
        # Calculate accuracy
        accuracy = if subdomain_has_minimizer
            length(found_minimizers) / length(subdomain_minimizer_indices) * 100.0
        else
            isempty(computed_pts) ? 100.0 : 0.0
        end
        
        push!(recovery_data, (
            subdomain = subdomain.label,
            computed_points = length(computed_pts),
            has_minimizer = subdomain_has_minimizer,
            expected_minimizers = length(subdomain_minimizer_indices),
            found_minimizers = length(found_minimizers),
            min_distances = isempty(min_distances) ? [NaN] : min_distances,
            accuracy = accuracy
        ))
    end
    
    recovery_df = DataFrame(recovery_data)
    
    # Global statistics
    global_stats = (
        total_minimizers = length(true_minimizers),
        total_recovered = sum(minimizers_recovered),
        global_recovery_rate = 100.0 * sum(minimizers_recovered) / length(true_minimizers),
        recovered_indices = findall(minimizers_recovered)
    )
    
    return recovery_df, global_stats
end