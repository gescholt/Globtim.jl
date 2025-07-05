# ================================================================================
# Enhanced Degree Convergence Analysis - Minimizer Recovery Only
# ================================================================================
# 
# Tracks recovery of 9 true minimizers from CSV file
# Analyzes distance convergence across polynomial degrees
# Uses simplified analysis focused on local minimizers only
#
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared utilities
include("../shared/Common4DDeuflhard.jl")
include("../shared/SubdomainManagement.jl")
using .Common4DDeuflhard
using .SubdomainManagement: Subdomain, generate_16_subdivisions_orthant, assign_point_to_unique_subdomain, is_point_in_subdomain

# Core packages
using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames, CSV
using Statistics
using CairoMakie
using Printf, Dates
using PrettyTables

# ================================================================================
# MINIMIZER ANALYSIS
# ================================================================================

"""
    load_true_minimizers(csv_path)

Load the 9 true minimizers from CSV file.

# Returns
- `Vector{Vector{Float64}}`: The 9 true minimizer coordinates
"""
function load_true_minimizers(csv_path::String)
    df = CSV.read(csv_path, DataFrame)
    return [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(df)]
end

"""
    compute_minimizer_recovery(true_minimizers, computed_points_by_subdomain, subdomains; threshold)

Compute minimizer recovery statistics.

# Returns
- `recovery_df`: DataFrame with recovery statistics per subdomain
- `global_stats`: Overall recovery statistics
"""
function compute_minimizer_recovery(true_minimizers::Vector{Vector{Float64}},
                                   computed_points_by_subdomain::Dict{String, Vector{Vector{Float64}}},
                                   subdomains::Vector{Subdomain};
                                   threshold::Float64 = 0.2)
    # Recovery data per subdomain
    recovery_data = []
    
    # Global tracking
    total_recovered = 0
    
    for subdomain in subdomains
        # Get computed points in this subdomain
        computed_pts = get(computed_points_by_subdomain, subdomain.label, Vector{Float64}[])
        
        # Count how many true minimizers are recovered by this subdomain
        minimizers_recovered = 0
        
        for true_min in true_minimizers
            if !isempty(computed_pts)
                min_dist = minimum(norm(cp - true_min) for cp in computed_pts)
                if min_dist < threshold
                    minimizers_recovered += 1
                end
            end
        end
        
        push!(recovery_data, (
            subdomain = subdomain.label,
            computed_points = length(computed_pts),
            minimizers_recovered = minimizers_recovered,
            recovery_rate = length(true_minimizers) > 0 ? 100.0 * minimizers_recovered / length(true_minimizers) : 0.0
        ))
        
        total_recovered += minimizers_recovered
    end
    
    recovery_df = DataFrame(recovery_data)
    
    # Global statistics
    global_stats = (
        total_minimizers = length(true_minimizers),
        total_recovered = total_recovered,
        global_recovery_rate = 100.0 * total_recovered / length(true_minimizers)
    )
    
    return recovery_df, global_stats
end

# ================================================================================
# MAIN ANALYSIS FUNCTION
# ================================================================================

"""
    run_enhanced_analysis(degrees, gn; output_dir, threshold)

Run degree convergence analysis with full critical point tracking.

# Arguments
- `degrees`: Polynomial degrees to test
- `gn`: Grid points per dimension
- `output_dir`: Output directory
- `threshold`: Recovery distance threshold

# Returns
- `summary_df`: Summary statistics by degree
- `distribution_df`: Theoretical point distribution
"""
function run_enhanced_analysis(degrees::Vector{Int}, gn::Int;
                             output_dir::Union{String,Nothing} = nothing,
                             threshold::Float64 = 0.2)
    
    # Load true minimizers from CSV
    true_minimizers = load_true_minimizers(joinpath(@__DIR__, "../points_deufl/4d_min_min_domain.csv"))
    
    # Setup
    if output_dir === nothing
        timestamp = Dates.format(now(), "HH-MM")
        output_dir = joinpath(@__DIR__, "../outputs", "minimizer_analysis_$(timestamp)")
    end
    mkpath(output_dir)
    
    # Generate subdomains
    subdomains = generate_16_subdivisions_orthant()
    
    # Main analysis loop
    summary_data = []
    all_recovery_details = Dict{Int, Any}()
    l2_data_by_degree = Dict{Int, Vector{Float64}}()
    distance_data = Dict{Int, Any}()
    
    for degree in degrees
        l2_norms = Float64[]
        computed_by_subdomain = Dict{String, Vector{Vector{Float64}}}()
        
        # Process each subdomain
        for subdomain in subdomains
            # Construct approximant
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
            subdomain_points = Vector{Float64}[]
            for row in eachrow(df_crit)
                pt = [row[Symbol("x$i")] for i in 1:4]
                if is_point_in_subdomain(pt, subdomain)
                    push!(subdomain_points, pt)
                end
            end
            
            computed_by_subdomain[subdomain.label] = subdomain_points
        end
        
        # Store L2 data for plotting
        l2_data_by_degree[degree] = l2_norms
        
        # Compute distances to true minimizers
        all_computed_points = Vector{Float64}[]
        for pts in values(computed_by_subdomain)
            append!(all_computed_points, pts)
        end
        
        # Calculate distance statistics
        if !isempty(all_computed_points)
            min_distances = Float64[]
            for computed_pt in all_computed_points
                distances_to_true = [norm(computed_pt - true_min) for true_min in true_minimizers]
                push!(min_distances, minimum(distances_to_true))
            end
            
            min_dist_to_true = minimum(min_distances)
            avg_dist_to_true = mean(min_distances)
            max_dist_to_true = maximum(min_distances)
        else
            min_dist_to_true = Inf
            avg_dist_to_true = Inf
            max_dist_to_true = Inf
        end
        
        distance_data[degree] = (min_distances=min_distances, min=min_dist_to_true, avg=avg_dist_to_true, max=max_dist_to_true)
        
        # Compute minimizer recovery
        recovery_df, global_stats = compute_minimizer_recovery(
            true_minimizers, computed_by_subdomain, subdomains, 
            threshold = threshold
        )
        
        all_recovery_details[degree] = (recovery_df, global_stats)
        
        # Summary statistics
        total_computed = sum(length(pts) for pts in values(computed_by_subdomain))
        
        push!(summary_data, (
            degree = degree,
            avg_l2_norm = mean(l2_norms),
            total_computed_points = total_computed,
            minimizers_recovered = global_stats.total_recovered,
            minimizer_recovery_rate = global_stats.global_recovery_rate,
            min_distance_to_true = min_dist_to_true,
            avg_distance_to_true = avg_dist_to_true,
            max_distance_to_true = max_dist_to_true
        ))
        
    end
    
    summary_df = DataFrame(summary_data)
    
    # Summary table
    println("📈 Minimizer Recovery Analysis")
    pretty_table(summary_df, 
                formatters = ft_printf("%.2e", [2, 6, 7, 8]),
                header = ["Degree", "Avg L²", "Computed", "Min Rec.", "Min %", "Min Dist", "Avg Dist", "Max Dist"])
    
    # Recovery details for highest degree
    highest_degree = maximum(degrees)
    rec_df, global_stats = all_recovery_details[highest_degree]
    
    println("\n🎯 Recovery by Subdomain (Degree $highest_degree)")
    println("Global: $(global_stats.total_recovered)/$(global_stats.total_minimizers) ($(global_stats.global_recovery_rate)%)")
    
    # Show only subdomains with recovery
    active_recovery = filter(row -> row.minimizers_recovered > 0, rec_df)
    if nrow(active_recovery) > 0
        pretty_table(active_recovery, header=["Subdomain", "Computed", "Recovered", "Rate %"])
    end
    
    # Generate plots
    create_enhanced_plots(summary_df, l2_data_by_degree, output_dir)
    
    # Save results
    CSV.write(joinpath(output_dir, "summary.csv"), summary_df)
    
    # Save detailed recovery for each degree
    for (deg, (rec_df, _)) in all_recovery_details
        CSV.write(joinpath(output_dir, "recovery_degree_$(deg).csv"), rec_df)
    end
    
    return summary_df, rec_df
end

# ================================================================================
# PLOTTING
# ================================================================================

"""
Create L2-norm convergence plot with multiple domains data.
"""
function create_l2_norm_plot(summary_df::DataFrame, l2_data_by_degree::Dict, output_dir::String)
    fig = Figure(size=(800, 600))
    
    ax = Axis(fig[1, 1], title = "L²-norm Convergence Across Multiple Domains", 
              xlabel = "Degree", ylabel = "L²-norm", yscale = log10)
    
    # Plot average L2-norm
    lines!(ax, summary_df.degree, summary_df.avg_l2_norm, 
           linewidth=3, color=:blue, label="Average")
    scatter!(ax, summary_df.degree, summary_df.avg_l2_norm, 
             markersize=12, color=:blue)
    
    # Plot individual domain L2-norms as lighter lines
    degrees = sort(collect(keys(l2_data_by_degree)))
    for i in 1:16  # 16 subdomains
        l2_vals = [l2_data_by_degree[d][i] for d in degrees]
        lines!(ax, degrees, l2_vals, 
               linewidth=1, color=(:gray, 0.4), alpha=0.6)
    end
    
    axislegend(ax, position=:lt)
    
    save(joinpath(output_dir, "l2_norm_convergence.png"), fig)
    display(fig)
end

"""
Create combined distance plot to true minimizers.
"""
function create_distance_plot(summary_df::DataFrame, output_dir::String)
    try
        fig = Figure(size=(800, 600))
        
        ax = Axis(fig[1, 1], title = "Distance to True 4D Minimizers", 
                  xlabel = "Degree", ylabel = "Distance", yscale = log10)
        
        degrees = summary_df.degree
        
        # Plot minimum distance
        lines!(ax, degrees, summary_df.min_distance_to_true, 
               linewidth=3, color=:red, label="Minimum distance")
        scatter!(ax, degrees, summary_df.min_distance_to_true, 
                 markersize=12, color=:red)
        
        # Plot average distance
        lines!(ax, degrees, summary_df.avg_distance_to_true, 
               linewidth=3, color=:green, label="Average distance")
        scatter!(ax, degrees, summary_df.avg_distance_to_true, 
                 markersize=12, color=:green)
        
        # Plot maximum distance
        lines!(ax, degrees, summary_df.max_distance_to_true, 
               linewidth=3, color=:blue, label="Maximum distance")
        scatter!(ax, degrees, summary_df.max_distance_to_true, 
                 markersize=12, color=:blue)
        
        axislegend(ax, position=:lt)
        
        save(joinpath(output_dir, "distance_to_true_minimizers.png"), fig)
        println("✓ Distance plot saved successfully")
    catch e
        println("⚠ Warning: Could not create distance plot: $e")
        println("Analysis will continue without distance plot.")
    end
end

"""
Create enhanced visualization plots.
"""
function create_enhanced_plots(summary_df::DataFrame, l2_data_by_degree::Dict, output_dir::String)
    # Create separate plots
    create_l2_norm_plot(summary_df, l2_data_by_degree, output_dir)
    create_distance_plot(summary_df, output_dir)
    
    # Create combined overview plot
    fig = Figure(size=(1000, 600))
    
    # Minimizer recovery rates
    ax1 = Axis(fig[1, 1], title = "Minimizer Recovery Rate", 
               xlabel = "Degree", ylabel = "Recovery Rate (%)")
    
    lines!(ax1, summary_df.degree, summary_df.minimizer_recovery_rate, 
           linewidth=3, color=:red, label="Minimizers")
    scatter!(ax1, summary_df.degree, summary_df.minimizer_recovery_rate, 
             markersize=12, color=:red)
    
    hlines!(ax1, [100], color=:black, linestyle=:dash, linewidth=1, alpha=0.5)
    axislegend(ax1, position=:rb)
    
    # Recovery counts
    ax2 = Axis(fig[1, 2], title = "Minimizer Recovery Count", 
               xlabel = "Degree", ylabel = "Count")
    
    x = summary_df.degree
    
    barplot!(ax2, x, summary_df.minimizers_recovered, 
             color=:orange, label="Recovered (of 9)")
    
    hlines!(ax2, [9], color=:orange, linestyle=:dash, linewidth=2)
    
    axislegend(ax2, position=:lt)
    
    save(joinpath(output_dir, "minimizer_recovery_overview.png"), fig)
    display(fig)
end

# ================================================================================
# EXECUTE IF RUN DIRECTLY
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    run_enhanced_analysis([2, 3, 4, 5, 6, 7, 8], 16)
end