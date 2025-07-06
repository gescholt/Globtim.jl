# PlotDescriptions.jl - Generate textual descriptions of plots

module PlotDescriptions

using Printf
using Statistics

export describe_l2_convergence, describe_recovery_rates, describe_min_min_distances,
       describe_subdivision_convergence, describe_subdivision_recovery_rates, 
       describe_subdivision_min_min_distances

"""
    describe_l2_convergence(results; tolerance_line=nothing)

Generate a textual description of the L²-norm convergence behavior.
"""
function describe_l2_convergence(results; tolerance_line=nothing)
    degrees = [r.degree for r in results]
    l2_norms = [r.l2_norm for r in results]
    
    valid_indices = findall(isfinite.(l2_norms) .&& (l2_norms .> 0))
    if isempty(valid_indices)
        return "No valid L²-norm data available."
    end
    
    valid_degrees = degrees[valid_indices]
    valid_l2_norms = l2_norms[valid_indices]
    
    desc = String[]
    push!(desc, "L²-Norm Convergence Analysis:")
    push!(desc, "  Degree range: $(minimum(valid_degrees)) to $(maximum(valid_degrees))")
    push!(desc, "  L²-norm range: $(Printf.@sprintf("%.2e", minimum(valid_l2_norms))) to $(Printf.@sprintf("%.2e", maximum(valid_l2_norms)))")
    
    # Check convergence trend
    if length(valid_degrees) > 1
        if valid_l2_norms[end] < valid_l2_norms[1]
            reduction = valid_l2_norms[1] / valid_l2_norms[end]
            push!(desc, "  Convergence: $(Printf.@sprintf("%.1f", reduction))x reduction from degree $(valid_degrees[1]) to $(valid_degrees[end])")
        end
    end
    
    # Check against tolerance
    if tolerance_line !== nothing && tolerance_line > 0
        converged_degrees = valid_degrees[valid_l2_norms .<= tolerance_line]
        if !isempty(converged_degrees)
            push!(desc, "  Tolerance $(Printf.@sprintf("%.2e", tolerance_line)) achieved at degree $(minimum(converged_degrees))")
        else
            push!(desc, "  Tolerance $(Printf.@sprintf("%.2e", tolerance_line)) not achieved (best: $(Printf.@sprintf("%.2e", minimum(valid_l2_norms))))")
        end
    end
    
    return join(desc, "\n")
end

"""
    describe_recovery_rates(results)

Generate a textual description of critical point recovery rates.
"""
function describe_recovery_rates(results)
    degrees = [r.degree for r in results]
    all_rates = [r.success_rate * 100 for r in results]
    min_min_rates = [r.min_min_success_rate * 100 for r in results]
    
    desc = String[]
    push!(desc, "Critical Point Recovery Analysis:")
    push!(desc, "  Degree range: $(minimum(degrees)) to $(maximum(degrees))")
    
    # All critical points
    push!(desc, "  All critical points:")
    push!(desc, "    Success rate range: $(Printf.@sprintf("%.1f", minimum(all_rates)))% to $(Printf.@sprintf("%.1f", maximum(all_rates)))%")
    best_all_idx = argmax(all_rates)
    push!(desc, "    Best performance: $(Printf.@sprintf("%.1f", all_rates[best_all_idx]))% at degree $(degrees[best_all_idx])")
    
    # Min+min points
    push!(desc, "  Min+min points only:")
    push!(desc, "    Success rate range: $(Printf.@sprintf("%.1f", minimum(min_min_rates)))% to $(Printf.@sprintf("%.1f", maximum(min_min_rates)))%")
    best_minmin_idx = argmax(min_min_rates)
    push!(desc, "    Best performance: $(Printf.@sprintf("%.1f", min_min_rates[best_minmin_idx]))% at degree $(degrees[best_minmin_idx])")
    
    # Check 90% threshold
    above_90_all = degrees[all_rates .>= 90]
    above_90_minmin = degrees[min_min_rates .>= 90]
    
    if !isempty(above_90_all)
        push!(desc, "  90% threshold achieved for all points at degree $(minimum(above_90_all))")
    end
    if !isempty(above_90_minmin)
        push!(desc, "  90% threshold achieved for min+min points at degree $(minimum(above_90_minmin))")
    end
    
    return join(desc, "\n")
end

"""
    describe_min_min_distances(results; tolerance_line=1e-4)

Generate a textual description of min+min distance behavior.
"""
function describe_min_min_distances(results; tolerance_line=1e-4)
    degrees = [r.degree for r in results]
    
    # Collect all distances
    all_distances = Float64[]
    distances_by_degree = Dict{Int, Vector{Float64}}()
    
    for result in results
        if !isempty(result.min_min_distances)
            distances_by_degree[result.degree] = result.min_min_distances
            append!(all_distances, result.min_min_distances)
        end
    end
    
    if isempty(all_distances)
        return "No min+min distance data available."
    end
    
    desc = String[]
    push!(desc, "Min+Min Distance Analysis:")
    push!(desc, "  Degree range: $(minimum(degrees)) to $(maximum(degrees))")
    push!(desc, "  Total min+min points tracked: $(length(all_distances))")
    
    # Overall statistics
    push!(desc, "  Overall distance statistics:")
    push!(desc, "    Minimum: $(Printf.@sprintf("%.2e", minimum(all_distances)))")
    push!(desc, "    Maximum: $(Printf.@sprintf("%.2e", maximum(all_distances)))")
    push!(desc, "    Mean: $(Printf.@sprintf("%.2e", mean(all_distances)))")
    
    # Progress by degree
    if length(distances_by_degree) > 1
        sorted_degrees = sort(collect(keys(distances_by_degree)))
        first_deg = sorted_degrees[1]
        last_deg = sorted_degrees[end]
        
        first_mean = mean(distances_by_degree[first_deg])
        last_mean = mean(distances_by_degree[last_deg])
        
        if last_mean < first_mean
            improvement = first_mean / last_mean
            push!(desc, "  Distance improvement: $(Printf.@sprintf("%.1f", improvement))x from degree $first_deg to $last_deg")
        end
    end
    
    # Tolerance analysis
    within_tol = sum(all_distances .<= tolerance_line)
    push!(desc, "  Points within tolerance ($(Printf.@sprintf("%.0e", tolerance_line))): $within_tol/$(length(all_distances)) ($(Printf.@sprintf("%.1f", 100*within_tol/length(all_distances)))%)")
    
    return join(desc, "\n")
end

"""
    describe_subdivision_convergence(all_results; tolerance_line=nothing)

Generate a textual description of subdivision L²-norm convergence.
"""
function describe_subdivision_convergence(all_results; tolerance_line=nothing)
    n_subdomains = length(all_results)
    
    # Collect statistics across all subdomains
    all_l2_by_degree = Dict{Int, Vector{Float64}}()
    
    for (_, results) in all_results
        for result in results
            if !haskey(all_l2_by_degree, result.degree)
                all_l2_by_degree[result.degree] = Float64[]
            end
            if isfinite(result.l2_norm) && result.l2_norm > 0
                push!(all_l2_by_degree[result.degree], result.l2_norm)
            end
        end
    end
    
    if isempty(all_l2_by_degree)
        return "No valid subdivision convergence data available."
    end
    
    desc = String[]
    push!(desc, "Subdivision L²-Norm Convergence Analysis:")
    push!(desc, "  Number of subdomains: $n_subdomains")
    
    # Statistics by degree
    sorted_degrees = sort(collect(keys(all_l2_by_degree)))
    push!(desc, "  Degree range: $(minimum(sorted_degrees)) to $(maximum(sorted_degrees))")
    
    for degree in sorted_degrees
        l2_values = all_l2_by_degree[degree]
        if !isempty(l2_values)
            push!(desc, "  Degree $degree:")
            push!(desc, "    Subdomains analyzed: $(length(l2_values))")
            push!(desc, "    L²-norm range: $(Printf.@sprintf("%.2e", minimum(l2_values))) to $(Printf.@sprintf("%.2e", maximum(l2_values)))")
            push!(desc, "    Mean L²-norm: $(Printf.@sprintf("%.2e", mean(l2_values)))")
        end
    end
    
    # Convergence analysis
    if tolerance_line !== nothing && tolerance_line > 0
        converged_by_degree = Dict{Int, Int}()
        for degree in sorted_degrees
            l2_values = all_l2_by_degree[degree]
            converged_by_degree[degree] = sum(l2_values .<= tolerance_line)
        end
        
        push!(desc, "  Convergence to tolerance $(Printf.@sprintf("%.2e", tolerance_line)):")
        for degree in sorted_degrees
            n_conv = converged_by_degree[degree]
            n_total = length(all_l2_by_degree[degree])
            push!(desc, "    Degree $degree: $n_conv/$n_total subdomains ($(Printf.@sprintf("%.1f", 100*n_conv/n_total))%)")
        end
    end
    
    return join(desc, "\n")
end

"""
    describe_subdivision_recovery_rates(all_results)

Generate a textual description of subdivision recovery rates.
"""
function describe_subdivision_recovery_rates(all_results)
    n_subdomains = length(all_results)
    
    # Collect statistics
    all_rates_by_degree = Dict{Int, Vector{Float64}}()
    minmin_rates_by_degree = Dict{Int, Vector{Float64}}()
    
    for (_, results) in all_results
        for result in results
            if !haskey(all_rates_by_degree, result.degree)
                all_rates_by_degree[result.degree] = Float64[]
                minmin_rates_by_degree[result.degree] = Float64[]
            end
            push!(all_rates_by_degree[result.degree], result.success_rate * 100)
            if result.min_min_success_rate >= 0  # -1 indicates no min+min points
                push!(minmin_rates_by_degree[result.degree], result.min_min_success_rate * 100)
            end
        end
    end
    
    desc = String[]
    push!(desc, "Subdivision Recovery Rate Analysis:")
    push!(desc, "  Number of subdomains: $n_subdomains")
    
    sorted_degrees = sort(collect(keys(all_rates_by_degree)))
    push!(desc, "  Degree range: $(minimum(sorted_degrees)) to $(maximum(sorted_degrees))")
    
    # All critical points analysis
    push!(desc, "  All critical points recovery:")
    for degree in sorted_degrees
        rates = all_rates_by_degree[degree]
        push!(desc, "    Degree $degree: mean $(Printf.@sprintf("%.1f", mean(rates)))%, range $(Printf.@sprintf("%.1f", minimum(rates)))-$(Printf.@sprintf("%.1f", maximum(rates)))%")
    end
    
    # Min+min points analysis
    push!(desc, "  Min+min points recovery:")
    for degree in sorted_degrees
        rates = minmin_rates_by_degree[degree]
        if !isempty(rates)
            push!(desc, "    Degree $degree: mean $(Printf.@sprintf("%.1f", mean(rates)))%, range $(Printf.@sprintf("%.1f", minimum(rates)))-$(Printf.@sprintf("%.1f", maximum(rates)))% ($(length(rates)) subdomains with min+min)")
        else
            push!(desc, "    Degree $degree: no subdomains with min+min points")
        end
    end
    
    return join(desc, "\n")
end

"""
    describe_subdivision_min_min_distances(all_results; tolerance_line=1e-4)

Generate a textual description of subdivision min+min distances.
"""
function describe_subdivision_min_min_distances(all_results; tolerance_line=1e-4)
    n_subdomains = length(all_results)
    
    # Collect all distances by degree
    distances_by_degree = Dict{Int, Vector{Float64}}()
    subdomains_with_minmin = Set{String}()
    
    for (label, results) in all_results
        for result in results
            if !isempty(result.min_min_distances)
                push!(subdomains_with_minmin, label)
                if !haskey(distances_by_degree, result.degree)
                    distances_by_degree[result.degree] = Float64[]
                end
                append!(distances_by_degree[result.degree], result.min_min_distances)
            end
        end
    end
    
    n_with_minmin = length(subdomains_with_minmin)
    
    desc = String[]
    push!(desc, "Subdivision Min+Min Distance Analysis:")
    push!(desc, "  Total subdomains: $n_subdomains")
    push!(desc, "  Subdomains with min+min points: $n_with_minmin")
    
    if isempty(distances_by_degree)
        push!(desc, "  No min+min distance data available.")
        return join(desc, "\n")
    end
    
    sorted_degrees = sort(collect(keys(distances_by_degree)))
    push!(desc, "  Degree range: $(minimum(sorted_degrees)) to $(maximum(sorted_degrees))")
    
    # Statistics by degree
    for degree in sorted_degrees
        dists = distances_by_degree[degree]
        push!(desc, "  Degree $degree:")
        push!(desc, "    Points tracked: $(length(dists))")
        push!(desc, "    Distance range: $(Printf.@sprintf("%.2e", minimum(dists))) to $(Printf.@sprintf("%.2e", maximum(dists)))")
        push!(desc, "    Mean distance: $(Printf.@sprintf("%.2e", mean(dists)))")
        
        within_tol = sum(dists .<= tolerance_line)
        push!(desc, "    Within tolerance: $within_tol/$(length(dists)) ($(Printf.@sprintf("%.1f", 100*within_tol/length(dists)))%)")
    end
    
    # Overall improvement
    if length(sorted_degrees) > 1
        first_mean = mean(distances_by_degree[sorted_degrees[1]])
        last_mean = mean(distances_by_degree[sorted_degrees[end]])
        if last_mean < first_mean
            improvement = first_mean / last_mean
            push!(desc, "  Overall improvement: $(Printf.@sprintf("%.1f", improvement))x from degree $(sorted_degrees[1]) to $(sorted_degrees[end])")
        end
    end
    
    return join(desc, "\n")
end

end # module