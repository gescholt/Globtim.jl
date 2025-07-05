# ================================================================================
# Degree Convergence Analysis V2 - Tracking All Critical Points
# ================================================================================
# 
# Enhanced version that:
# 1. Generates all 25 (5×5) critical points from 2D (+,-) orthant
# 2. Tracks which are local minimizers (9 min+min points)
# 3. Analyzes recovery of all critical points with special focus on minimizers
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
# THEORETICAL CRITICAL POINTS WITH CLASSIFICATION
# ================================================================================

"""
    CriticalPointInfo

Stores information about a critical point including its type.

# Fields
- `point::Vector{Float64}`: Coordinates of the critical point
- `type::String`: Classification (e.g., "min+min", "min+saddle", etc.)
- `is_minimizer::Bool`: True if this is a local minimizer (min+min)
"""
struct CriticalPointInfo
    point::Vector{Float64}
    type::String
    is_minimizer::Bool
end

"""
    generate_all_theoretical_points()

Generate all 25 theoretical critical points for 4D Deuflhard from the 5 critical 
points in the 2D (+,-) orthant, with classification.

# Returns
- `Vector{CriticalPointInfo}`: All 25 critical points with type information
"""
function generate_all_theoretical_points()
    # All 5 critical points in 2D (+,-) orthant with their types
    critical_2d = [
        ([0.126217280731679, -0.126217280731682], "saddle"),  # Near origin
        ([0.507030772828217, -0.917350578608486], "min"),     # Minimizer 1
        ([0.74115190368376, -0.741151903683748], "min"),      # Minimizer 2  
        ([0.917350578608475, -0.50703077282823], "min"),      # Minimizer 3
        ([0.459896075906281, -0.459896075906281], "saddle")   # Central saddle
    ]
    
    # Generate all 25 tensor products (5×5)
    theoretical_points = CriticalPointInfo[]
    
    for (pt1, type1) in critical_2d
        for (pt2, type2) in critical_2d
            # Create 4D point
            point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
            
            # Combine types
            combined_type = "$(type1)+$(type2)"
            
            # Check if it's a minimizer (both components are minima)
            is_min = (type1 == "min" && type2 == "min")
            
            push!(theoretical_points, CriticalPointInfo(point_4d, combined_type, is_min))
        end
    end
    
    println("Generated $(length(theoretical_points)) theoretical critical points:")
    
    # Count by type
    type_counts = Dict{String,Int}()
    for pt_info in theoretical_points
        type_counts[pt_info.type] = get(type_counts, pt_info.type, 0) + 1
    end
    
    for (t, c) in sort(collect(type_counts))
        println("  $t: $c")
    end
    
    minimizer_count = count(pt -> pt.is_minimizer, theoretical_points)
    println("  Total minimizers (min+min): $minimizer_count")
    
    return theoretical_points
end

"""
    compute_recovery_metrics(theoretical_points::Vector{CriticalPointInfo}, 
                           computed_points::Vector{Vector{Float64}};
                           threshold::Float64 = 1e-3)

Compute recovery metrics for all theoretical points and separately for minimizers.

# Arguments
- `theoretical_points`: All theoretical critical points with classification
- `computed_points`: Critical points found by polynomial approximation
- `threshold`: Distance threshold for considering a point "recovered"

# Returns
- `all_distances`: Minimum distances for all theoretical points
- `minimizer_distances`: Minimum distances for just the minimizers
- `recovery_stats`: Dict with recovery statistics
"""
function compute_recovery_metrics(theoretical_points::Vector{CriticalPointInfo}, 
                                computed_points::Vector{Vector{Float64}};
                                threshold::Float64 = 1e-3)
    all_distances = Float64[]
    minimizer_distances = Float64[]
    
    # Track recovery by type
    recovery_by_type = Dict{String,Int}()
    total_by_type = Dict{String,Int}()
    
    for theo_info in theoretical_points
        # Count total by type
        total_by_type[theo_info.type] = get(total_by_type, theo_info.type, 0) + 1
        
        # Compute minimum distance
        if isempty(computed_points)
            min_dist = Inf
        else
            min_dist = minimum(norm(cp - theo_info.point) for cp in computed_points)
        end
        
        push!(all_distances, min_dist)
        
        if theo_info.is_minimizer
            push!(minimizer_distances, min_dist)
        end
        
        # Track recovery
        if min_dist < threshold
            recovery_by_type[theo_info.type] = get(recovery_by_type, theo_info.type, 0) + 1
        end
    end
    
    # Compute statistics
    recovery_stats = Dict(
        "total_recovered" => count(d -> d < threshold, all_distances),
        "total_theoretical" => length(theoretical_points),
        "minimizers_recovered" => count(d -> d < threshold, minimizer_distances),
        "total_minimizers" => length(minimizer_distances),
        "recovery_by_type" => recovery_by_type,
        "total_by_type" => total_by_type
    )
    
    return all_distances, minimizer_distances, recovery_stats
end

# ================================================================================
# MAIN ANALYSIS WITH ENHANCED TRACKING
# ================================================================================

"""
    run_enhanced_degree_analysis(degrees, gn; output_dir, recovery_threshold)

Analyze degree convergence with full critical point tracking.

# Arguments
- `degrees`: Vector of polynomial degrees to test
- `gn`: Grid points per dimension
- `output_dir`: Output directory (auto-generated if nothing)
- `recovery_threshold`: Distance threshold for recovery (default: 1e-3)

# Returns
- `summary`: DataFrame with comprehensive statistics
"""
function run_enhanced_degree_analysis(degrees::Vector{Int}, gn::Int; 
                                    output_dir::Union{String,Nothing}=nothing,
                                    recovery_threshold::Float64=1e-3)
    # Setup
    if output_dir === nothing
        timestamp = Dates.format(now(), "HH-MM")
        output_dir = joinpath(@__DIR__, "../outputs", "enhanced_analysis_$(timestamp)")
    end
    mkpath(output_dir)
    
    println("Enhanced Degree Convergence Analysis")
    println("="^60)
    
    # Generate all theoretical points with classification
    theoretical_points = generate_all_theoretical_points()
    subdomains = generate_16_subdivisions_orthant()
    
    println("\nConfiguration:")
    println("  Degrees: ", degrees)
    println("  Grid: ", gn, "^4 points per subdomain")
    println("  Subdomains: ", length(subdomains))
    println("  Recovery threshold: ", recovery_threshold)
    println("-"^60)
    
    # Storage
    summary_data = []
    detailed_recovery = Dict{Int, Dict}()  # Store recovery stats by degree
    
    # Analyze each degree
    for degree in degrees
        l2_norms = Float64[]
        all_computed_points = Vector{Vector{Float64}}()
        
        # Process subdomains
        for subdomain in subdomains
            # Create approximant
            TR = test_input(
                deuflhard_4d_composite,
                dim = 4,
                center = subdomain.center,
                sample_range = subdomain.range,
                GN = gn
            )
            
            pol = Constructor(TR, degree, verbose=0)
            push!(l2_norms, pol.nrm)
            
            # Find critical points
            @polyvar x[1:4]
            actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
            
            df_crit = process_crit_pts(
                solve_polynomial_system(x, 4, actual_degree, pol.coeffs),
                deuflhard_4d_composite,
                TR
            )
            
            # Collect points in subdomain
            for row in eachrow(df_crit)
                pt = [row[Symbol("x$i")] for i in 1:4]
                if is_point_in_subdomain(pt, subdomain)
                    push!(all_computed_points, pt)
                end
            end
        end
        
        # Get theoretical points in the orthant
        theo_in_orthant = filter(pt_info -> all(i -> is_in_orthant_bounds(pt_info.point[i], i), 1:4), 
                               theoretical_points)
        
        # Compute recovery metrics
        all_dists, min_dists, recovery_stats = compute_recovery_metrics(
            theo_in_orthant, 
            all_computed_points,
            threshold = recovery_threshold
        )
        
        detailed_recovery[degree] = recovery_stats
        
        # Summary statistics
        avg_l2 = mean(l2_norms)
        avg_all_dist = isempty(all_dists) ? Inf : mean(all_dists)
        avg_min_dist = isempty(min_dists) ? Inf : mean(min_dists)
        
        push!(summary_data, (
            degree = degree,
            avg_l2_norm = avg_l2,
            avg_distance_all = avg_all_dist,
            avg_distance_minimizers = avg_min_dist,
            recovered_all = recovery_stats["total_recovered"],
            total_all = recovery_stats["total_theoretical"],
            recovered_minimizers = recovery_stats["minimizers_recovered"],
            total_minimizers = recovery_stats["total_minimizers"],
            total_computed_points = length(all_computed_points)
        ))
        
        println(@sprintf("Degree %d: L²=%.2e, All recovered=%d/%d, Minimizers=%d/%d",
                degree, avg_l2, 
                recovery_stats["total_recovered"], recovery_stats["total_theoretical"],
                recovery_stats["minimizers_recovered"], recovery_stats["total_minimizers"]))
    end
    
    # Create summary DataFrame
    summary = DataFrame(summary_data)
    
    # Enhanced plots
    create_enhanced_plots(summary, detailed_recovery, output_dir)
    
    # Save results
    CSV.write(joinpath(output_dir, "enhanced_summary.csv"), summary)
    
    # Save detailed recovery statistics
    open(joinpath(output_dir, "recovery_details.txt"), "w") do io
        for degree in sort(collect(keys(detailed_recovery)))
            println(io, "\nDegree $degree recovery by type:")
            stats = detailed_recovery[degree]
            for (type, total) in sort(collect(stats["total_by_type"]))
                recovered = get(stats["recovery_by_type"], type, 0)
                println(io, "  $type: $recovered/$total")
            end
        end
    end
    
    println("\nResults saved to: $(basename(output_dir))")
    
    return summary, detailed_recovery
end

# ================================================================================
# HELPER FUNCTIONS
# ================================================================================

"""
Check if a coordinate is within the orthant bounds for dimension i.
"""
function is_in_orthant_bounds(coord::Float64, dim::Int)
    bounds = [(-0.1, 1.1), (-1.1, 0.1), (-0.1, 1.1), (-1.1, 0.1)]
    return bounds[dim][1] <= coord <= bounds[dim][2]
end

# ================================================================================
# ENHANCED PLOTTING
# ================================================================================

"""
Create enhanced plots showing recovery of all critical points and minimizers separately.
"""
function create_enhanced_plots(summary::DataFrame, detailed_recovery::Dict, output_dir::String)
    fig = Figure(size=(1600, 800))
    
    # Top row: Standard metrics
    ax1 = Axis(fig[1, 1], title = "L²-norm Convergence", xlabel = "Degree", 
               ylabel = "Average L²-norm", yscale = log10)
    
    lines!(ax1, summary.degree, summary.avg_l2_norm, linewidth=3, color=:blue)
    scatter!(ax1, summary.degree, summary.avg_l2_norm, markersize=12, color=:blue)
    
    # Distance comparison
    ax2 = Axis(fig[1, 2], title = "Average Distance to Theoretical Points", 
               xlabel = "Degree", ylabel = "Average Distance", yscale = log10)
    
    valid_all = summary[summary.avg_distance_all .< Inf, :]
    valid_min = summary[summary.avg_distance_minimizers .< Inf, :]
    
    if !isempty(valid_all)
        lines!(ax2, valid_all.degree, valid_all.avg_distance_all, 
               linewidth=3, color=:green, label="All points")
        scatter!(ax2, valid_all.degree, valid_all.avg_distance_all, 
                 markersize=10, color=:green)
    end
    
    if !isempty(valid_min)
        lines!(ax2, valid_min.degree, valid_min.avg_distance_minimizers, 
               linewidth=3, color=:red, label="Minimizers only")
        scatter!(ax2, valid_min.degree, valid_min.avg_distance_minimizers, 
                 markersize=10, color=:red)
    end
    
    hlines!(ax2, [1e-3], color=:black, linestyle=:dash, linewidth=2)
    axislegend(ax2, position=:rt)
    
    # Recovery comparison
    ax3 = Axis(fig[1, 3], title = "Recovery Count", xlabel = "Degree", ylabel = "Count")
    
    x = summary.degree
    width = 0.35
    
    barplot!(ax3, x .- width/2, summary.recovered_all, width=width, 
             color=:lightblue, label="All critical points")
    barplot!(ax3, x .+ width/2, summary.recovered_minimizers, width=width, 
             color=:orange, label="Minimizers")
    
    # Add totals as horizontal lines
    hlines!(ax3, [maximum(summary.total_all)], color=:lightblue, 
            linestyle=:dash, linewidth=2)
    hlines!(ax3, [maximum(summary.total_minimizers)], color=:orange, 
            linestyle=:dash, linewidth=2)
    
    axislegend(ax3, position=:lt)
    
    # Bottom row: Recovery by type
    ax4 = Axis(fig[2, 1:3], title = "Recovery by Critical Point Type", 
               xlabel = "Degree", ylabel = "Recovery Rate (%)")
    
    # Extract recovery rates by type
    degrees = sort(collect(keys(detailed_recovery)))
    types = ["min+min", "min+saddle", "saddle+min", "saddle+saddle"]
    colors = [:red, :orange, :green, :blue]
    
    for (i, type) in enumerate(types)
        rates = Float64[]
        for d in degrees
            stats = detailed_recovery[d]
            total = get(stats["total_by_type"], type, 0)
            recovered = get(stats["recovery_by_type"], type, 0)
            rate = total > 0 ? 100 * recovered / total : 0
            push!(rates, rate)
        end
        
        if any(rates .> 0)
            lines!(ax4, degrees, rates, linewidth=3, color=colors[i], label=type)
            scatter!(ax4, degrees, rates, markersize=10, color=colors[i])
        end
    end
    
    axislegend(ax4, position=:rb)
    
    save(joinpath(output_dir, "enhanced_convergence.png"), fig)
    display(fig)
end

# ================================================================================
# EXECUTE IF RUN DIRECTLY
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    summary, recovery_details = run_enhanced_degree_analysis([2, 3, 4, 5, 6, 7, 8], 16)
end