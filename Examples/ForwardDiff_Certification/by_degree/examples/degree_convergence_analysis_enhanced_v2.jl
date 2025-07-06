# ================================================================================
# Enhanced Degree Convergence Analysis V2 - With Improved Visualizations
# ================================================================================
# 
# Implements high priority improvements:
# 1. Remove histogram/barplot of captured minimizers
# 2. Enhanced distance plot with median, quartiles and shaded ranges
# 3. Add global domain approximant comparison
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
# DATA STRUCTURES
# ================================================================================

"""
Enhanced distance statistics with quartile information
"""
struct EnhancedDistanceStats
    all_distances::Vector{Float64}
    min::Float64
    median::Float64
    mean::Float64
    max::Float64
    q10::Float64
    q25::Float64
    q75::Float64
    q90::Float64
    n_near::Int
    n_far::Int
    near_distances::Vector{Float64}
    far_distances::Vector{Float64}
end

# ================================================================================
# MINIMIZER ANALYSIS FUNCTIONS
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
    compute_enhanced_distance_stats(computed_points, true_minimizers; threshold)

Compute enhanced distance statistics with quartiles and point classification.

# Returns
- `EnhancedDistanceStats`: Comprehensive distance statistics
"""
function compute_enhanced_distance_stats(computed_points::Vector{Vector{Float64}}, 
                                       true_minimizers::Vector{Vector{Float64}};
                                       threshold::Float64 = 0.2)
    if isempty(computed_points)
        return EnhancedDistanceStats(
            Float64[], Inf, NaN, NaN, -Inf,
            NaN, NaN, NaN, NaN,
            0, 0, Float64[], Float64[]
        )
    end
    
    # Compute all distances
    distances = [minimum(norm(cp - tm) for tm in true_minimizers) for cp in computed_points]
    
    # Classify points
    near_mask = distances .< threshold
    near_distances = distances[near_mask]
    far_distances = distances[.!near_mask]
    
    return EnhancedDistanceStats(
        distances,
        minimum(distances),
        median(distances),
        mean(distances),
        maximum(distances),
        quantile(distances, 0.10),
        quantile(distances, 0.25),
        quantile(distances, 0.75),
        quantile(distances, 0.90),
        length(near_distances),
        length(far_distances),
        near_distances,
        far_distances
    )
end

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
                                   threshold::Float64 = 0.2)
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
        if subdomain_has_minimizer && !isempty(computed_pts)
            # Check if we found the minimizer in this subdomain
            min_dist = minimum(norm(cp - true_minimizers[subdomain_minimizer_idx]) for cp in computed_pts)
            if min_dist < threshold
                found_minimizer = true
                minimizers_recovered[subdomain_minimizer_idx] = true
            end
        end
        
        push!(recovery_data, (
            subdomain = subdomain.label,
            computed_points = length(computed_pts),
            has_minimizer = subdomain_has_minimizer,
            found_minimizer = found_minimizer,
            accuracy = subdomain_has_minimizer ? (found_minimizer ? 100.0 : 0.0) : 
                      (isempty(computed_pts) ? 100.0 : 0.0)  # No false positives is good
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

# ================================================================================
# GLOBAL DOMAIN ANALYSIS
# ================================================================================

"""
    analyze_global_domain(degree, gn, true_minimizers)

Analyze the global domain approximation for comparison.

# Returns
- Distance statistics for global approximation
"""
function analyze_global_domain(degree::Int, gn::Int, true_minimizers::Vector{Vector{Float64}})
    # Global domain covers all subdomains
    global_center = [0.5, -0.5, 0.5, -0.5]
    global_range = 0.6  # From -0.1 to 1.1 is 1.2, so range is 0.6
    
    # Construct global approximant
    TR = test_input(
        deuflhard_4d_composite,
        dim = 4,
        center = global_center,
        sample_range = global_range,
        GN = gn
    )
    
    pol = Constructor(TR, degree, verbose=0)
    
    # Find critical points
    @polyvar x[1:4]
    actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
    
    df_crit = process_crit_pts(
        solve_polynomial_system(x, 4, actual_degree, pol.coeffs),
        deuflhard_4d_composite,
        TR
    )
    
    # Collect all points
    global_points = Vector{Float64}[]
    for row in eachrow(df_crit)
        pt = [row[Symbol("x$i")] for i in 1:4]
        push!(global_points, pt)
    end
    
    # Compute distance statistics
    stats = compute_enhanced_distance_stats(global_points, true_minimizers)
    
    return stats, pol.nrm
end

# ================================================================================
# MAIN ANALYSIS FUNCTION
# ================================================================================

"""
    run_enhanced_analysis_v2(degrees, gn; output_dir, threshold, analyze_global)

Run enhanced degree convergence analysis with improved visualizations.

# Arguments
- `degrees`: Polynomial degrees to test
- `gn`: Grid points per dimension
- `output_dir`: Output directory
- `threshold`: Recovery distance threshold
- `analyze_global`: Whether to include global domain comparison

# Returns
- `summary_df`: Summary statistics by degree
- `distance_data`: Enhanced distance statistics by degree
"""
function run_enhanced_analysis_v2(degrees::Vector{Int}, gn::Int;
                                 output_dir::Union{String,Nothing} = nothing,
                                 threshold::Float64 = 0.2,
                                 analyze_global::Bool = true)
    
    # Load true minimizers
    true_minimizers = load_true_minimizers(joinpath(@__DIR__, "../points_deufl/4d_min_min_domain.csv"))
    
    # Setup output directory
    if output_dir === nothing
        timestamp = Dates.format(now(), "HH-MM")
        output_dir = joinpath(@__DIR__, "../outputs", "enhanced_v2_$(timestamp)")
    end
    mkpath(output_dir)
    
    # Generate subdomains
    subdomains = generate_16_subdivisions_orthant()
    
    # Main analysis loop
    summary_data = []
    distance_data = Dict{Int, EnhancedDistanceStats}()
    global_distance_data = Dict{Int, EnhancedDistanceStats}()
    l2_data_by_degree = Dict{Int, Vector{Float64}}()
    global_l2_by_degree = Dict{Int, Float64}()
    
    for degree in degrees
        println("\n🔄 Processing degree $degree...")
        
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
        
        # Store L2 data
        l2_data_by_degree[degree] = l2_norms
        
        # Aggregate all computed points
        all_computed_points = Vector{Float64}[]
        for pts in values(computed_by_subdomain)
            append!(all_computed_points, pts)
        end
        
        # Compute enhanced distance statistics
        stats = compute_enhanced_distance_stats(all_computed_points, true_minimizers, threshold=threshold)
        distance_data[degree] = stats
        
        # Compute minimizer recovery
        recovery_df, global_stats = compute_minimizer_recovery(
            true_minimizers, computed_by_subdomain, subdomains, 
            threshold = threshold
        )
        
        # Summary statistics
        push!(summary_data, (
            degree = degree,
            avg_l2_norm = mean(l2_norms),
            total_computed_points = length(all_computed_points),
            minimizers_recovered = global_stats.total_recovered,
            recovery_rate = global_stats.global_recovery_rate,
            min_distance = stats.min,
            median_distance = stats.median,
            mean_distance = stats.mean,
            max_distance = stats.max,
            q25_distance = stats.q25,
            q75_distance = stats.q75,
            points_near_minimizers = stats.n_near,
            spurious_points = stats.n_far
        ))
        
        # Global domain analysis
        if analyze_global
            println("  Analyzing global domain...")
            global_stats, global_l2 = analyze_global_domain(degree, gn, true_minimizers)
            global_distance_data[degree] = global_stats
            global_l2_by_degree[degree] = global_l2
        end
        
        # Save recovery details
        CSV.write(joinpath(output_dir, "recovery_degree_$(degree).csv"), recovery_df)
    end
    
    summary_df = DataFrame(summary_data)
    
    # Display summary
    println("\n📊 Enhanced Analysis Summary")
    pretty_table(summary_df, 
                formatters = ft_printf("%.2e", [2, 6, 7, 8, 9, 10, 11]),
                header = ["Deg", "Avg L²", "Points", "Min Rec", "Rec %", 
                         "Min D", "Med D", "Mean D", "Max D", "Q25", "Q75", "Near", "Far"])
    
    # Create enhanced plots
    create_enhanced_plots_v2(summary_df, distance_data, global_distance_data, 
                            l2_data_by_degree, global_l2_by_degree, output_dir)
    
    # Save results
    CSV.write(joinpath(output_dir, "summary.csv"), summary_df)
    
    return summary_df, distance_data
end

# ================================================================================
# ENHANCED PLOTTING FUNCTIONS
# ================================================================================

"""
Create enhanced distance plot with clean visualization showing average and min-max range.
"""
function create_enhanced_distance_plot(distance_data::Dict{Int, EnhancedDistanceStats},
                                     global_data::Dict{Int, EnhancedDistanceStats},
                                     output_dir::String)
    fig = Figure(size=(1000, 600))
    ax = Axis(fig[1, 1], 
              title = "Distance to True Minimizers",
              xlabel = "Polynomial Degree", 
              ylabel = "Distance to Nearest True Minimizer", 
              yscale = log10)
    
    degrees = sort(collect(keys(distance_data)))
    
    # Combined subdomains data (all critical points from 16 subdomains)
    subdomain_means = [distance_data[d].mean for d in degrees]
    subdomain_mins = [distance_data[d].min for d in degrees]
    subdomain_maxs = [distance_data[d].max for d in degrees]
    
    # Plot combined subdomains with min-max range
    band!(ax, degrees, subdomain_mins, subdomain_maxs, 
          color=(:orange, 0.3), label="Range (combined subdomains)")
    lines!(ax, degrees, subdomain_means, 
           linewidth=3, color=:orange, label="Average (combined subdomains)")
    scatter!(ax, degrees, subdomain_means, markersize=10, color=:orange)
    
    # Global approximant data (critical points from single polynomial on whole domain)
    if !isempty(global_data)
        global_means = [global_data[d].mean for d in degrees]
        global_mins = [global_data[d].min for d in degrees]
        global_maxs = [global_data[d].max for d in degrees]
        
        # Plot global approximant with min-max range
        band!(ax, degrees, global_mins, global_maxs, 
              color=(:blue, 0.3), label="Range (global)")
        lines!(ax, degrees, global_means, 
               linewidth=3, color=:blue, label="Average (global)")
        scatter!(ax, degrees, global_means, markersize=10, color=:blue)
    end
    
    # Add threshold line
    hlines!(ax, [0.2], color=:black, linestyle=:dot, linewidth=2, 
            label="Recovery threshold")
    
    # Clean legend in top right corner
    axislegend(ax, position=:rt, framevisible=false)
    
    save(joinpath(output_dir, "enhanced_distance_convergence.png"), fig)
    display(fig)
end

"""
Create L2-norm convergence plot with individual domain traces.
"""
function create_enhanced_l2_plot(summary_df::DataFrame, 
                               l2_data_by_degree::Dict,
                               global_l2_by_degree::Dict, 
                               output_dir::String)
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], 
              title = "L²-norm Convergence: Subdivided vs Global", 
              xlabel = "Polynomial Degree", 
              ylabel = "L²-norm", 
              yscale = log10)
    
    # Plot average L2-norm for subdivided
    lines!(ax, summary_df.degree, summary_df.avg_l2_norm, 
           linewidth=3, color=:blue, label="Average (16 subdomains)")
    scatter!(ax, summary_df.degree, summary_df.avg_l2_norm, 
             markersize=12, color=:blue)
    
    # Plot individual subdomain L2-norms as lighter lines
    degrees = sort(collect(keys(l2_data_by_degree)))
    for i in 1:16
        l2_vals = [l2_data_by_degree[d][i] for d in degrees]
        lines!(ax, degrees, l2_vals, 
               linewidth=0.5, color=(:blue, 0.3), alpha=0.5)
    end
    
    # Add global L2-norm if available
    if !isempty(global_l2_by_degree)
        global_l2s = [global_l2_by_degree[d] for d in degrees]
        lines!(ax, degrees, global_l2s, 
               linewidth=3, color=:red, label="Global domain")
        scatter!(ax, degrees, global_l2s, 
                 markersize=12, color=:red)
    end
    
    axislegend(ax, position=:rt)
    
    save(joinpath(output_dir, "enhanced_l2_convergence.png"), fig)
    display(fig)
end


"""
Create all enhanced plots.
"""
function create_enhanced_plots_v2(summary_df::DataFrame,
                                distance_data::Dict{Int, EnhancedDistanceStats},
                                global_data::Dict{Int, EnhancedDistanceStats},
                                l2_data_by_degree::Dict,
                                global_l2_by_degree::Dict,
                                output_dir::String)
    # Create individual plots
    create_enhanced_distance_plot(distance_data, global_data, output_dir)
    create_enhanced_l2_plot(summary_df, l2_data_by_degree, global_l2_by_degree, output_dir)
    
    println("\n✅ All plots saved to: $(basename(output_dir))")
end

# ================================================================================
# EXECUTE IF RUN DIRECTLY
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Run with default parameters
    summary_df, distance_data = run_enhanced_analysis_v2(
        [2, 3, 4, 5, 6], 
        16,
        analyze_global = true
    )
end