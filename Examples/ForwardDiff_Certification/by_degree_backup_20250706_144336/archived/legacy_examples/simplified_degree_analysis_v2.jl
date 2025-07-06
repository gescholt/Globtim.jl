# ================================================================================
# Simplified Degree Analysis V2 - Direct and Simple Approach
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))

using Common4DDeuflhard
using SubdomainManagement
using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames, CSV
using Statistics
using CairoMakie
using Printf, Dates

# ================================================================================
# GENERATE MIN+MIN POINTS DIRECTLY
# ================================================================================

"""
    generate_min_min_points()

Generate all 9 min+min points for the 4D Deuflhard function.
Based on the 3 local minimizers in the 2D (+,-) orthant.

# Returns
- `min_min_points::Vector{Vector{Float64}}`: The 9 min+min points in 4D
"""
function generate_min_min_points()
    # The 3 local minimizers in the 2D (+,-) orthant
    minimizers_2d = [
        [0.507030772828217, -0.917350578608486],
        [0.74115190368376, -0.741151903683748],
        [0.917350578608475, -0.50703077282823]
    ]
    
    # Generate all 9 tensor products (3×3)
    min_min_points = Vector{Vector{Float64}}()
    for min1 in minimizers_2d
        for min2 in minimizers_2d
            # 4D point: [x1, y1, x2, y2] where (x1,y1) and (x2,y2) are 2D minimizers
            push!(min_min_points, [min1[1], min1[2], min2[1], min2[2]])
        end
    end
    
    println("Generated $(length(min_min_points)) min+min points")
    return min_min_points
end

# ================================================================================
# DISTANCE COMPUTATION FUNCTION
# ================================================================================

"""
    compute_min_distances(theoretical_minimizers::Vector{Vector{Float64}}, 
                         critical_points::Vector{Vector{Float64}})

Compute minimum distances from theoretical minimizers to critical points.

# Arguments
- `theoretical_minimizers`: Known local minimizers
- `critical_points`: Computed critical points to test

# Returns
- `distances::Vector{Float64}`: Minimum distance for each theoretical minimizer
"""
function compute_min_distances(theoretical_minimizers::Vector{Vector{Float64}}, 
                              critical_points::Vector{Vector{Float64}})
    distances = Float64[]
    
    for theo_pt in theoretical_minimizers
        if isempty(critical_points)
            push!(distances, Inf)
        else
            min_dist = minimum(norm(cp - theo_pt) for cp in critical_points)
            push!(distances, min_dist)
        end
    end
    
    return distances
end

# ================================================================================
# MAIN ANALYSIS FUNCTION
# ================================================================================

"""
    run_analysis_v2(; degrees, gn, verbose, output_dir)

Run degree convergence analysis with simplified approach.

# Arguments
- `degrees`: Polynomial degrees to test
- `gn`: Grid points per dimension
- `verbose`: Print detailed output
- `output_dir`: Output directory for results

# Returns
- `results_df`: DataFrame with analysis results
- `summary_stats`: Summary statistics by degree
"""
function run_analysis_v2(;
    degrees = [2, 3, 4, 5, 6, 7, 8],
    gn = 16,
    verbose = false,
    output_dir = nothing
)
    # Setup
    if output_dir === nothing
        timestamp = Dates.format(now(), "HH-MM")
        output_dir = joinpath(@__DIR__, "../outputs", "analysis_v2_$(timestamp)")
    end
    mkpath(output_dir)
    
    println("="^60)
    println("Degree Convergence Analysis - Simplified V2")
    println("="^60)
    println("Degrees: ", degrees)
    println("Grid points: ", gn)
    println()
    
    # Generate theoretical min+min points once
    theoretical_minimizers = generate_min_min_points()
    
    # Generate subdomains
    subdomains = generate_16_subdivisions_orthant()
    println("Using $(length(subdomains)) subdomains")
    println("-"^60)
    
    # Storage
    results = []
    summary_by_degree = Dict()
    
    # Main loop
    for degree in degrees
        degree_l2_norms = Float64[]
        all_distances = Float64[]
        total_crit_pts = 0
        
        for subdomain in subdomains
            # Step 1: Construct Globtim approximant
            TR = test_input(
                deuflhard_4d_composite,
                dim = 4,
                center = subdomain.center,
                sample_range = subdomain.range,
                GN = gn,
                prec = (16, 8),
                reduce_samples = 4
            )
            
            pol = Constructor(TR, degree, verbose=0)
            push!(degree_l2_norms, pol.nrm)
            
            # Step 2: Get critical points
            @polyvar x[1:4]
            actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
            
            # Use process_crit_pts for automatic transformation
            df_crit = process_crit_pts(
                solve_polynomial_system(x, 4, actual_degree, pol.coeffs),
                deuflhard_4d_composite,
                TR
            )
            
            # Extract points in subdomain
            crit_pts_in_subdomain = Vector{Float64}[]
            for row in eachrow(df_crit)
                pt = [row[Symbol("x$i")] for i in 1:4]
                if is_point_in_subdomain(pt, subdomain)
                    push!(crit_pts_in_subdomain, pt)
                end
            end
            
            total_crit_pts += length(crit_pts_in_subdomain)
            
            # Step 3: Find theoretical minimizers in this subdomain
            theo_in_subdomain = filter(pt -> is_point_in_subdomain(pt, subdomain), 
                                     theoretical_minimizers)
            
            # Step 4: Compute distances
            if !isempty(theo_in_subdomain)
                distances = compute_min_distances(theo_in_subdomain, crit_pts_in_subdomain)
                append!(all_distances, distances)
            end
            
            # Store results
            push!(results, (
                degree = degree,
                subdomain = subdomain.label,
                l2_norm = pol.nrm,
                num_crit_pts = length(crit_pts_in_subdomain),
                num_theoretical = length(theo_in_subdomain)
            ))
        end
        
        # Summary for this degree
        avg_l2 = mean(degree_l2_norms)
        avg_dist = isempty(all_distances) ? Inf : mean(all_distances)
        min_dist = isempty(all_distances) ? Inf : minimum(all_distances)
        recovered = count(d -> d < 1e-3, all_distances)
        
        summary_by_degree[degree] = (
            avg_l2_norm = avg_l2,
            avg_distance = avg_dist,
            min_distance = min_dist,
            recovered_count = recovered,
            total_crit_pts = total_crit_pts
        )
        
        println(@sprintf("Degree %d: L²=%.2e, AvgDist=%.2e, MinDist=%.2e, Recovered=%d/%d",
                degree, avg_l2, avg_dist, min_dist, recovered, length(all_distances)))
    end
    
    # Create plots
    println("\nGenerating plots...")
    fig = Figure(size=(1200, 400))
    
    degrees_vec = collect(degrees)
    
    # Left: L²-norm
    ax1 = Axis(fig[1, 1],
        title = "L²-norm Convergence",
        xlabel = "Degree",
        ylabel = "Average L²-norm",
        yscale = log10
    )
    
    l2_norms = [summary_by_degree[d].avg_l2_norm for d in degrees_vec]
    lines!(ax1, degrees_vec, l2_norms, linewidth=3, color=:blue)
    scatter!(ax1, degrees_vec, l2_norms, markersize=12, color=:blue)
    
    # Middle: Average distance
    ax2 = Axis(fig[1, 2],
        title = "Average Distance to Minimizers",
        xlabel = "Degree",
        ylabel = "Average Distance",
        yscale = log10
    )
    
    avg_dists = [summary_by_degree[d].avg_distance for d in degrees_vec]
    lines!(ax2, degrees_vec, avg_dists, linewidth=3, color=:green)
    scatter!(ax2, degrees_vec, avg_dists, markersize=12, color=:green)
    hlines!(ax2, [1e-3], color=:red, linestyle=:dash, linewidth=2)
    
    # Right: Recovery count
    ax3 = Axis(fig[1, 3],
        title = "Recovered Minimizers",
        xlabel = "Degree",
        ylabel = "Count"
    )
    
    recovered = [summary_by_degree[d].recovered_count for d in degrees_vec]
    barplot!(ax3, degrees_vec, recovered, color=:orange, width=0.8)
    
    save(joinpath(output_dir, "convergence_analysis.png"), fig)
    display(fig)
    
    # Save results
    results_df = DataFrame(results)
    CSV.write(joinpath(output_dir, "detailed_results.csv"), results_df)
    
    summary_df = DataFrame([
        (degree = d,
         avg_l2_norm = summary_by_degree[d].avg_l2_norm,
         avg_distance = summary_by_degree[d].avg_distance,
         min_distance = summary_by_degree[d].min_distance,
         recovered_count = summary_by_degree[d].recovered_count,
         total_crit_pts = summary_by_degree[d].total_crit_pts)
        for d in degrees_vec
    ])
    CSV.write(joinpath(output_dir, "summary_stats.csv"), summary_df)
    
    println("\nResults saved to: ", basename(output_dir))
    
    return results_df, summary_df
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_analysis_v2(verbose=true)
end