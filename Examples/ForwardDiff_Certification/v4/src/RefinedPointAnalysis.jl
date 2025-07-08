# RefinedPointAnalysis.jl - Analysis of BFGS-refined points for V4

module RefinedPointAnalysis

using DataFrames
using LinearAlgebra
using Statistics
using Printf

export create_refined_distance_table, calculate_refinement_metrics,
       create_refinement_summary, find_nearest_point_with_index

"""
    find_nearest_point_with_index(point, point_set)

Find the nearest point in point_set to the given point.
Returns (index, nearest_point, distance)
"""
function find_nearest_point_with_index(point::Vector{Float64}, point_set::Vector{Vector{Float64}})
    if isempty(point_set)
        return (0, Float64[], Inf)
    end
    
    min_dist = Inf
    min_idx = 0
    nearest_point = Float64[]
    
    for (idx, p) in enumerate(point_set)
        dist = norm(point - p)
        if dist < min_dist
            min_dist = dist
            min_idx = idx
            nearest_point = p
        end
    end
    
    return (min_idx, nearest_point, min_dist)
end

"""
    create_refined_distance_table(df_min_refined, df_cheb, subdomain_label, degree)

Create a table tracking distances from refined points (df_min_refined) to 
original computed points (df_cheb).
"""
function create_refined_distance_table(
    df_min_refined::DataFrame,
    df_cheb::DataFrame,
    subdomain_label::String,
    degree::Int
)
    # Extract point coordinates
    cheb_points = [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(df_cheb)]
    
    # Initialize table data
    refined_point_ids = String[]
    original_point_ids = String[]
    distances = Float64[]
    refined_coords = Vector{Vector{Float64}}()
    
    for (idx, row) in enumerate(eachrow(df_min_refined))
        refined_point = [row.x1, row.x2, row.x3, row.x4]
        
        # Find nearest point in df_cheb
        nearest_idx, nearest_point, dist = find_nearest_point_with_index(refined_point, cheb_points)
        
        if nearest_idx > 0
            push!(refined_point_ids, "RP_$(lpad(idx, 3, '0'))")
            push!(original_point_ids, "CP_$(lpad(nearest_idx, 3, '0'))")
            push!(distances, dist)
            push!(refined_coords, refined_point)
        end
    end
    
    # Create DataFrame
    table = DataFrame(
        refined_point_id = refined_point_ids,
        original_point_id = original_point_ids,
        x1 = [p[1] for p in refined_coords],
        x2 = [p[2] for p in refined_coords],
        x3 = [p[3] for p in refined_coords],
        x4 = [p[4] for p in refined_coords]
    )
    
    # Add distance column for this degree
    table[!, Symbol("d$degree")] = distances
    
    return table
end

"""
    calculate_refinement_metrics(theoretical_minima, df_cheb, df_min_refined, degree)

Calculate metrics comparing:
- Distances from theoretical minima to df_cheb
- Distances from theoretical minima to df_min_refined
- Improvement ratios
"""
function calculate_refinement_metrics(
    theoretical_minima::Vector{Vector{Float64}},
    df_cheb::DataFrame,
    df_min_refined::DataFrame,
    degree::Int
)
    # Extract point coordinates
    cheb_points = [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(df_cheb)]
    refined_points = [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(df_min_refined)]
    
    # Calculate distances from theoretical minima
    theo_to_cheb_dists = Float64[]
    theo_to_refined_dists = Float64[]
    
    for theo_min in theoretical_minima
        # Distance to nearest df_cheb point
        if !isempty(cheb_points)
            _, _, dist_cheb = find_nearest_point_with_index(theo_min, cheb_points)
            push!(theo_to_cheb_dists, dist_cheb)
        else
            push!(theo_to_cheb_dists, Inf)
        end
        
        # Distance to nearest df_min_refined point
        if !isempty(refined_points)
            _, _, dist_refined = find_nearest_point_with_index(theo_min, refined_points)
            push!(theo_to_refined_dists, dist_refined)
        else
            push!(theo_to_refined_dists, Inf)
        end
    end
    
    # Calculate improvement metrics
    improvements = Float64[]
    for i in 1:length(theoretical_minima)
        if theo_to_cheb_dists[i] > 0
            improvement = (theo_to_cheb_dists[i] - theo_to_refined_dists[i]) / theo_to_cheb_dists[i]
            push!(improvements, improvement)
        else
            push!(improvements, 0.0)
        end
    end
    
    return (
        theo_to_cheb = theo_to_cheb_dists,
        theo_to_refined = theo_to_refined_dists,
        improvements = improvements,
        avg_theo_to_cheb = mean(filter(isfinite, theo_to_cheb_dists)),
        avg_theo_to_refined = mean(filter(isfinite, theo_to_refined_dists)),
        avg_improvement = mean(filter(isfinite, improvements))
    )
end

"""
    create_refinement_summary(metrics_by_degree, degrees)

Create a summary table of refinement effectiveness across degrees.
"""
function create_refinement_summary(metrics_by_degree::Dict, degrees::Vector{Int})
    summary = DataFrame(
        degree = degrees,
        n_computed = Int[],
        n_refined = Int[],
        avg_dist_theoretical_to_cheb = Float64[],
        avg_dist_theoretical_to_refined = Float64[],
        avg_dist_refined_to_cheb = Float64[],
        improvement_ratio = Float64[]
    )
    
    for deg in degrees
        if haskey(metrics_by_degree, deg)
            metrics = metrics_by_degree[deg]
            push!(summary.n_computed, metrics.n_computed)
            push!(summary.n_refined, metrics.n_refined)
            push!(summary.avg_dist_theoretical_to_cheb, metrics.avg_theo_to_cheb)
            push!(summary.avg_dist_theoretical_to_refined, metrics.avg_theo_to_refined)
            push!(summary.avg_dist_refined_to_cheb, metrics.avg_refined_to_cheb)
            push!(summary.improvement_ratio, metrics.avg_improvement)
        else
            # Add placeholder values
            push!(summary.n_computed, 0)
            push!(summary.n_refined, 0)
            push!(summary.avg_dist_theoretical_to_cheb, NaN)
            push!(summary.avg_dist_theoretical_to_refined, NaN)
            push!(summary.avg_dist_refined_to_cheb, NaN)
            push!(summary.improvement_ratio, NaN)
        end
    end
    
    return summary
end

end # module