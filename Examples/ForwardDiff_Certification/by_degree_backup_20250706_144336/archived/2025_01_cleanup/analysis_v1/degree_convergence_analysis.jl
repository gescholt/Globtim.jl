# ================================================================================
# Degree Convergence Analysis for 4D Deuflhard Function
# ================================================================================
# 
# Clean implementation showing how polynomial degree affects:
# 1. L²-norm approximation error
# 2. Critical point recovery
# 3. Distance to known local minimizers
#
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared utilities
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))
using Common4DDeuflhard
using SubdomainManagement

# Core packages
using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames, CSV
using Statistics
using CairoMakie
using Printf, Dates

# ================================================================================
# THEORETICAL MINIMIZERS
# ================================================================================

"""
    generate_theoretical_minimizers()

Generate all 9 theoretical local minimizers (min+min points) for 4D Deuflhard.
These come from the tensor product of 3 minimizers in the 2D (+,-) orthant.

# Returns
- `Vector{Vector{Float64}}`: 9 points in 4D
"""
function generate_theoretical_minimizers()
    # The 3 local minimizers in 2D (+,-) orthant [x>0, y<0]
    minimizers_2d = [
        [0.507030772828217, -0.917350578608486],
        [0.74115190368376, -0.741151903683748],
        [0.917350578608475, -0.50703077282823]
    ]
    
    # Generate 3×3 = 9 tensor products for 4D
    minimizers_4d = Vector{Vector{Float64}}()
    for m1 in minimizers_2d
        for m2 in minimizers_2d
            # 4D point: [x₁, y₁, x₂, y₂]
            push!(minimizers_4d, [m1[1], m1[2], m2[1], m2[2]])
        end
    end
    
    return minimizers_4d
end

"""
    compute_recovery_distances(theoretical_points::Vector, computed_points::Vector)

For each theoretical point, find the minimum distance to any computed point.

# Arguments
- `theoretical_points`: Known exact minimizers
- `computed_points`: Critical points found by polynomial approximation

# Returns
- `Vector{Float64}`: Minimum distance for each theoretical point
"""
function compute_recovery_distances(theoretical_points::Vector{Vector{Float64}}, 
                                  computed_points::Vector{Vector{Float64}})
    distances = Float64[]
    
    for theo_pt in theoretical_points
        if isempty(computed_points)
            push!(distances, Inf)
        else
            min_dist = minimum(norm(cp - theo_pt) for cp in computed_points)
            push!(distances, min_dist)
        end
    end
    
    return distances
end

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

"""
    run_degree_convergence_analysis(degrees, gn; output_dir)

Analyze how polynomial degree affects approximation quality and minimizer recovery.

# Arguments
- `degrees`: Vector of polynomial degrees to test
- `gn`: Grid points per dimension (fixed - no tolerance adaptation)
- `output_dir`: Directory for results (auto-generated if not specified)

# Returns
- `summary`: DataFrame with convergence statistics by degree
"""
function run_degree_convergence_analysis(degrees::Vector{Int}, gn::Int; 
                                       output_dir::Union{String,Nothing}=nothing)
    # Setup output directory
    if output_dir === nothing
        timestamp = Dates.format(now(), "HH-MM")
        output_dir = joinpath(@__DIR__, "../outputs", "degree_analysis_$(timestamp)")
    end
    mkpath(output_dir)
    
    println("Degree Convergence Analysis")
    println("Degrees: ", degrees, ", Grid: ", gn, "^4 points")
    
    # Generate theoretical minimizers and subdomains
    theoretical_minimizers = generate_theoretical_minimizers()
    subdomains = generate_16_subdivisions_orthant()
    
    println("Theoretical minimizers: ", length(theoretical_minimizers))
    println("Subdomains: ", length(subdomains))
    println("-"^60)
    
    # Storage for results
    summary_data = []
    
    # Analyze each degree
    for degree in degrees
        l2_norms = Float64[]
        all_distances = Float64[]
        total_critical_points = 0
        
        # Process each subdomain
        for subdomain in subdomains
            # Create Globtim approximant
            TR = test_input(
                deuflhard_4d_composite,
                dim = 4,
                center = subdomain.center,
                sample_range = subdomain.range,
                GN = gn  # Fixed grid - no adaptation
            )
            
            pol = Constructor(TR, degree, verbose=0)
            push!(l2_norms, pol.nrm)
            
            # Find critical points (process_crit_pts handles coordinate transformation)
            @polyvar x[1:4]
            actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
            
            df_crit = process_crit_pts(
                solve_polynomial_system(x, 4, actual_degree, pol.coeffs),
                deuflhard_4d_composite,
                TR
            )
            
            # Extract points in this subdomain
            critical_points = Vector{Vector{Float64}}()
            for row in eachrow(df_crit)
                pt = [row[Symbol("x$i")] for i in 1:4]
                if is_point_in_subdomain(pt, subdomain)
                    push!(critical_points, pt)
                end
            end
            
            total_critical_points += length(critical_points)
            
            # Compute distances for theoretical minimizers in this subdomain
            theo_in_subdomain = filter(pt -> is_point_in_subdomain(pt, subdomain), 
                                     theoretical_minimizers)
            
            if !isempty(theo_in_subdomain)
                distances = compute_recovery_distances(theo_in_subdomain, critical_points)
                append!(all_distances, distances)
            end
        end
        
        # Compute statistics for this degree
        avg_l2 = mean(l2_norms)
        avg_dist = isempty(all_distances) ? Inf : mean(all_distances)
        min_dist = isempty(all_distances) ? Inf : minimum(all_distances)
        recovered = count(d -> d < 1e-3, all_distances)
        
        push!(summary_data, (
            degree = degree,
            avg_l2_norm = avg_l2,
            min_l2_norm = minimum(l2_norms),
            max_l2_norm = maximum(l2_norms),
            avg_distance = avg_dist,
            min_distance = min_dist,
            recovered_minimizers = recovered,
            total_distances = length(all_distances),
            total_critical_points = total_critical_points
        ))
        
        println(@sprintf("Degree %d: L²=%.2e, Distance=%.2e, Recovered=%d/%d",
                degree, avg_l2, avg_dist, recovered, length(all_distances)))
    end
    
    # Create summary DataFrame
    summary = DataFrame(summary_data)
    
    # Generate plots
    create_convergence_plots(summary, output_dir)
    
    # Save results
    CSV.write(joinpath(output_dir, "convergence_summary.csv"), summary)
    
    println("\nResults saved to: $(basename(output_dir))")
    
    return summary
end

# ================================================================================
# PLOTTING
# ================================================================================

"""
    create_convergence_plots(summary::DataFrame, output_dir::String)

Create visualization plots for degree convergence analysis.
"""
function create_convergence_plots(summary::DataFrame, output_dir::String)
    fig = Figure(size=(1200, 400))
    
    # L²-norm convergence
    ax1 = Axis(fig[1, 1],
        title = "L²-norm Convergence",
        xlabel = "Polynomial Degree",
        ylabel = "Average L²-norm",
        yscale = log10
    )
    
    lines!(ax1, summary.degree, summary.avg_l2_norm, 
           linewidth=3, color=:blue, label="Average")
    scatter!(ax1, summary.degree, summary.avg_l2_norm, 
             markersize=12, color=:blue)
    
    # Add min/max band
    band!(ax1, summary.degree, summary.min_l2_norm, summary.max_l2_norm,
          color=(:blue, 0.2))
    
    # Distance convergence
    ax2 = Axis(fig[1, 2],
        title = "Distance to Theoretical Minimizers",
        xlabel = "Polynomial Degree",
        ylabel = "Average Distance",
        yscale = log10
    )
    
    valid_dists = summary[summary.avg_distance .< Inf, :]
    if !isempty(valid_dists)
        lines!(ax2, valid_dists.degree, valid_dists.avg_distance,
               linewidth=3, color=:green)
        scatter!(ax2, valid_dists.degree, valid_dists.avg_distance,
                 markersize=12, color=:green)
        hlines!(ax2, [1e-3], color=:red, linestyle=:dash, linewidth=2,
                label="Recovery threshold")
    end
    
    # Recovery rate
    ax3 = Axis(fig[1, 3],
        title = "Minimizer Recovery",
        xlabel = "Polynomial Degree",
        ylabel = "Recovered Count"
    )
    
    barplot!(ax3, summary.degree, summary.recovered_minimizers,
             color=:orange, width=0.8)
    
    # Add total line
    if maximum(summary.total_distances) > 0
        hlines!(ax3, [maximum(summary.total_distances)], 
                color=:red, linestyle=:dash, linewidth=2,
                label="Total possible")
    end
    
    save(joinpath(output_dir, "degree_convergence.png"), fig)
    display(fig)
end

# ================================================================================
# EXECUTE IF RUN DIRECTLY
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    summary = run_degree_convergence_analysis([2, 3, 4, 5, 6, 7, 8], 16)
end