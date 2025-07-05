"""
Enhanced analysis utilities for comprehensive degree convergence analysis.
Extends the basic DegreeAnalysisResult with additional metrics for advanced plotting.
"""

module EnhancedAnalysisUtilities

using DataFrames
using LinearAlgebra
using Statistics
using Printf

# Enhanced result structure with additional metrics for plotting
struct EnhancedDegreeAnalysisResult
    # Core fields from original DegreeAnalysisResult
    degree::Int
    l2_norm::Float64
    n_theoretical_points::Int
    n_computed_points::Int
    n_successful_recoveries::Int
    success_rate::Float64
    runtime_seconds::Float64
    converged::Bool
    computed_points::Vector{Vector{Float64}}
    min_min_success_rate::Float64
    min_min_distances::Vector{Float64}
    
    # Enhanced fields for comprehensive plotting
    all_critical_distances::Vector{Float64}      # Distances to ALL theoretical points
    min_min_found_by_bfgs::Vector{Bool}          # Which min+min points required BFGS
    min_min_within_tolerance::Vector{Bool}       # Which min+min within initial tolerance
    point_classifications::Vector{String}         # Type of each computed point
    theoretical_points::Vector{Vector{Float64}}   # All theoretical critical points
    subdomain_label::String                      # Domain identifier (e.g., "0000", "full")
    bfgs_iterations::Vector{Int}                 # Number of BFGS iterations per point
    function_values::Vector{Float64}             # Function values at computed points
end

"""
    convert_to_enhanced(result, theoretical_points, min_min_indices, subdomain_label; kwargs...)

Convert analysis results to an EnhancedDegreeAnalysisResult with additional computed metrics.
The input result should have fields: degree, l2_norm, n_theoretical_points, n_computed_points,
n_successful_recoveries, success_rate, runtime_seconds, converged, computed_points,
min_min_success_rate, min_min_distances.
"""
function convert_to_enhanced(
    result,  # Generic to avoid dependency on DegreeAnalysisResult type
    theoretical_points::Vector{Vector{Float64}},
    min_min_indices::Vector{Int},
    subdomain_label::String="full";
    bfgs_data::Union{Nothing,Dict}=nothing,
    classification_data::Union{Nothing,Vector{String}}=nothing
)
    # Extract all distances to theoretical points
    all_distances = compute_all_point_distances(
        result.computed_points, 
        theoretical_points
    )
    
    # Analyze min+min capture methods
    min_min_analysis = analyze_min_min_capture(
        result.computed_points,
        theoretical_points[min_min_indices],
        result.min_min_distances,
        bfgs_data
    )
    
    # Default classifications if not provided
    if classification_data === nothing
        classification_data = fill("unknown", length(result.computed_points))
    end
    
    # Default BFGS iterations if not provided
    bfgs_iterations = if bfgs_data !== nothing && haskey(bfgs_data, :iterations)
        bfgs_data[:iterations]
    else
        zeros(Int, length(result.computed_points))
    end
    
    # Compute function values (placeholder - would need actual function)
    function_values = zeros(length(result.computed_points))
    
    return EnhancedDegreeAnalysisResult(
        result.degree,
        result.l2_norm,
        result.n_theoretical_points,
        result.n_computed_points,
        result.n_successful_recoveries,
        result.success_rate,
        result.runtime_seconds,
        result.converged,
        result.computed_points,
        result.min_min_success_rate,
        result.min_min_distances,
        all_distances,
        min_min_analysis.found_by_bfgs,
        min_min_analysis.within_tolerance,
        classification_data,
        theoretical_points,
        subdomain_label,
        bfgs_iterations,
        function_values
    )
end

"""
    compute_all_point_distances(computed_points, theoretical_points)

Compute minimum distances from each theoretical point to the closest computed point.
Returns a vector of distances ordered by theoretical point index.
"""
function compute_all_point_distances(
    computed_points::Vector{Vector{Float64}},
    theoretical_points::Vector{Vector{Float64}}
)
    distances = Float64[]
    
    for theo_pt in theoretical_points
        if isempty(computed_points)
            push!(distances, Inf)
        else
            min_dist = minimum(norm(comp_pt - theo_pt) for comp_pt in computed_points)
            push!(distances, min_dist)
        end
    end
    
    return distances
end

"""
    analyze_min_min_capture(computed_points, min_min_points, min_distances, bfgs_data)

Analyze how min+min points were captured - by direct approximation or BFGS refinement.
"""
function analyze_min_min_capture(
    computed_points::Vector{Vector{Float64}},
    min_min_points::Vector{Vector{Float64}},
    min_distances::Vector{Float64},
    bfgs_data::Union{Nothing,Dict}
)
    n_min_min = length(min_min_points)
    found_by_bfgs = fill(false, n_min_min)
    within_tolerance = fill(false, n_min_min)
    
    # Default tolerance from original implementation
    tolerance = 0.05
    
    for (i, dist) in enumerate(min_distances)
        if dist < tolerance
            within_tolerance[i] = true
            
            # Check if BFGS was used for this point
            if bfgs_data !== nothing && haskey(bfgs_data, :refined_indices)
                # Find which computed point corresponds to this min+min
                for (j, comp_pt) in enumerate(computed_points)
                    if norm(comp_pt - min_min_points[i]) ≈ dist
                        if j in bfgs_data[:refined_indices]
                            found_by_bfgs[i] = true
                        end
                        break
                    end
                end
            end
        end
    end
    
    return (found_by_bfgs=found_by_bfgs, within_tolerance=within_tolerance)
end

"""
    aggregate_enhanced_results(results::Vector{EnhancedDegreeAnalysisResult})

Aggregate multiple enhanced results for summary statistics and plotting.
"""
function aggregate_enhanced_results(results::Vector{EnhancedDegreeAnalysisResult})
    degrees = [r.degree for r in results]
    
    # Aggregate metrics
    total_points = [r.n_computed_points for r in results]
    min_min_found = [sum(r.min_min_within_tolerance) for r in results]
    min_min_by_bfgs = [sum(r.min_min_found_by_bfgs) for r in results]
    
    # Average distances
    avg_all_distances = [mean(r.all_critical_distances[isfinite.(r.all_critical_distances)]) 
                        for r in results]
    avg_min_min_distances = [mean(r.min_min_distances[isfinite.(r.min_min_distances)]) 
                            for r in results]
    
    return Dict(
        :degrees => degrees,
        :total_points => total_points,
        :min_min_found => min_min_found,
        :min_min_by_bfgs => min_min_by_bfgs,
        :avg_all_distances => avg_all_distances,
        :avg_min_min_distances => avg_min_min_distances,
        :l2_norms => [r.l2_norm for r in results],
        :success_rates => [r.success_rate for r in results],
        :min_min_success_rates => [r.min_min_success_rate for r in results]
    )
end

"""
    collect_subdomain_statistics(subdomain_results::Dict{String,Vector{EnhancedDegreeAnalysisResult}})

Collect and organize statistics across all subdomains for multi-domain plotting.
"""
function collect_subdomain_statistics(subdomain_results::Dict{String,Vector{EnhancedDegreeAnalysisResult}})
    # Initialize collections
    all_degrees = Int[]
    all_l2_norms = Dict{Int,Vector{Float64}}()
    all_min_distances = Dict{Int,Vector{Float64}}()
    
    # Collect by degree across subdomains
    for (label, results) in subdomain_results
        for r in results
            if !(r.degree in keys(all_l2_norms))
                all_l2_norms[r.degree] = Float64[]
                all_min_distances[r.degree] = Float64[]
            end
            
            push!(all_l2_norms[r.degree], r.l2_norm)
            push!(all_min_distances[r.degree], 
                  mean(r.min_min_distances[isfinite.(r.min_min_distances)]))
        end
    end
    
    # Compute statistics per degree
    degrees = sort(collect(keys(all_l2_norms)))
    
    stats = Dict(
        :degrees => degrees,
        :l2_norm_mean => [mean(all_l2_norms[d]) for d in degrees],
        :l2_norm_std => [std(all_l2_norms[d]) for d in degrees],
        :l2_norm_min => [minimum(all_l2_norms[d]) for d in degrees],
        :l2_norm_max => [maximum(all_l2_norms[d]) for d in degrees],
        :min_dist_mean => [mean(all_min_distances[d]) for d in degrees],
        :min_dist_std => [std(all_min_distances[d]) for d in degrees],
        :subdomain_count => length(subdomain_results)
    )
    
    return stats
end

# Export all functions
export EnhancedDegreeAnalysisResult, convert_to_enhanced, 
       compute_all_point_distances, analyze_min_min_capture,
       aggregate_enhanced_results, collect_subdomain_statistics

end # module