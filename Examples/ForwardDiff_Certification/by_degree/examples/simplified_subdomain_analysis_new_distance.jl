# ================================================================================
# Modified version of simplified_subdomain_analysis.jl with new distance approach
# ================================================================================
# 
# Key change: Distance plot now shows the average separation distance
# computed from all 9 local minimizers to all critical points across all 16 subdomains
#

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared directory to load path
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))

# Load shared utilities
using Common4DDeuflhard
using SubdomainManagement
using TheoreticalPoints
using TheoreticalPoints: load_theoretical_4d_points_orthant
using Globtim
using DynamicPolynomials
using LinearAlgebra

# Standard packages
using Printf, Dates, Statistics
using CairoMakie
using DataFrames, CSV
using Statistics: mean, median  # Ensure we have mean and median

# ================================================================================
# PARAMETERS
# ================================================================================

const DEGREES = [2, 3, 4, 5, 6]  # Degrees to test
const GN = 16                     # Grid points per dimension for L²-norm
const TOLERANCE = 0.01            # Reference tolerance for L²-norm
const POINT_MATCHING_TOLERANCE = 1e-3  # Tolerance for matching critical points
const BFGS_TOLERANCE = 1e-8            # BFGS convergence tolerance

# ================================================================================
# L2-NORM ANALYSIS FUNCTIONS (from original file)
# ================================================================================

function analyze_subdomain_simple(subdomain::Subdomain, degree::Int)
    """Analyze a single subdomain at a given degree - simplified version."""
    
    # Create test input for the subdomain
    TR = test_input(
        deuflhard_4d_composite,
        dim=4,
        center=subdomain.center,
        sample_range=subdomain.range,
        tolerance=TOLERANCE,
        GN=GN
    )
    
    # Construct polynomial (no adaptive behavior)
    try
        pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
        
        # Get L²-norm from the polynomial approximation
        l2_norm = pol.nrm
        
        return (degree=degree, l2_norm=l2_norm, converged=(l2_norm < TOLERANCE))
    catch e
        @warn "Failed to construct polynomial" subdomain=subdomain.label degree=degree error=e
        return (degree=degree, l2_norm=NaN, converged=false)
    end
end

function analyze_full_domain_simple(degree::Int)
    """Analyze the full (+,-,+,-) orthant at a given degree."""
    
    # Full domain parameters
    center = [0.5, -0.5, 0.5, -0.5]
    range = 0.5
    
    # Create test input for full domain
    TR = test_input(
        deuflhard_4d_composite,
        dim=4,
        center=center,
        sample_range=range,
        tolerance=TOLERANCE,
        GN=GN
    )
    
    # Construct polynomial
    try
        pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
        
        # Get L²-norm from the polynomial approximation
        l2_norm = pol.nrm
        
        return (degree=degree, l2_norm=l2_norm)
    catch e
        @warn "Failed to construct polynomial for full domain" degree=degree error=e
        return (degree=degree, l2_norm=NaN)
    end
end

function plot_l2_convergence_simplified(subdomain_results, full_domain_results; 
                                       save_plot=false, output_dir=".")
    """Create the L2 convergence plot."""
    
    fig = Figure(size=(1000, 600))
    
    # Create single axis for all curves
    ax = Axis(fig[1, 1],
        xlabel="Polynomial Degree",
        ylabel="L² Error",
        title="L² Convergence: 16 Subdomains vs Full Domain",
        yscale=log10,
        xlabelsize=16,
        ylabelsize=16,
        titlesize=18,
        yminorticksvisible=true,
        yminorgridvisible=true
    )
    
    # Plot all 16 subdomain curves in semi-transparent red
    for (label, results) in subdomain_results
        degrees = [r.degree for r in results if !isnan(r.l2_norm)]
        l2_norms = [r.l2_norm for r in results if !isnan(r.l2_norm)]
        
        if !isempty(degrees)
            lines!(ax, degrees, l2_norms, 
                   color=(:red, 0.5),  # Semi-transparent red
                   linewidth=1.5)
        end
    end
    
    # Plot full domain curve in blue on same axis
    degrees = [r.degree for r in full_domain_results if !isnan(r.l2_norm)]
    l2_norms = [r.l2_norm for r in full_domain_results if !isnan(r.l2_norm)]
    
    if !isempty(degrees)
        lines!(ax, degrees, l2_norms,
               color=:blue,
               linewidth=3,
               label="Full Domain")
    end
    
    # Add reference line for tolerance
    hlines!(ax, [TOLERANCE], 
            color=:green, 
            linestyle=:dash, 
            linewidth=2,
            label="Tolerance ($(TOLERANCE))")
    
    # Add labels for the subdomain curves (just once)
    # Create a dummy line for the legend
    lines!(ax, [NaN], [NaN], 
           color=(:red, 0.5), 
           linewidth=1.5, 
           label="Subdomains (16)")
    
    # Add legend
    axislegend(ax, position=:rt, labelsize=14)
    
    # Save if requested
    if save_plot
        save(joinpath(output_dir, "l2_convergence_simplified.png"), fig)
        println("Saved plot to $(joinpath(output_dir, "l2_convergence_simplified.png"))")
    end
    
    return fig
end

# ================================================================================
# NEW DISTANCE ANALYSIS FUNCTIONS
# ================================================================================

function collect_all_critical_points_for_degree(degree::Int, subdivisions::Vector{Subdomain})
    """Collect all critical points from all subdomains for a given degree."""
    all_points = Vector{Vector{Float64}}()
    
    for subdomain in subdivisions
        # Create test input for the subdomain
        TR = test_input(
            deuflhard_4d_composite,
            dim=4,
            center=subdomain.center,
            sample_range=subdomain.range,
            tolerance=TOLERANCE,
            GN=GN
        )
        
        try
            # Construct polynomial
            pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
            
            # Solve for critical points
            @polyvar x[1:4]
            actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
            crit_pts = solve_polynomial_system(x, 4, actual_degree, pol.coeffs)
            
            # Add to collection
            append!(all_points, crit_pts)
            
        catch e
            @warn "Failed to compute critical points" subdomain=subdomain.label degree=degree error=e
        end
    end
    
    return all_points
end

function compute_minimizer_separation_distances(degree::Int, subdivisions::Vector{Subdomain})
    """
    Compute separation distances from all 9 theoretical minimizers 
    to the combined set of critical points from all subdomains.
    """
    
    # Get the 9 theoretical minimizers
    theoretical_minimizers = [
        [0.0, 0.0, 0.0, 0.0],          # Central minimizer
        [0.0, -1.0, 0.0, 0.0],         # Face centers
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, -1.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, -1.0],
        [0.0, 0.0, 0.0, 1.0],
        [-1.0, 0.0, 0.0, 0.0],
        [1.0, 0.0, 0.0, 0.0]
    ]
    
    # Collect all critical points
    all_critical_points = collect_all_critical_points_for_degree(degree, subdivisions)
    
    if isempty(all_critical_points)
        return (
            degree = degree,
            avg_separation = NaN,
            min_separation = NaN,
            max_separation = NaN,
            std_separation = NaN,
            num_critical_points = 0,
            individual_distances = Float64[]
        )
    end
    
    # For each minimizer, find distance to nearest critical point
    distances = Float64[]
    for minimizer in theoretical_minimizers
        min_dist = minimum(norm(minimizer - cp) for cp in all_critical_points)
        push!(distances, min_dist)
    end
    
    return (
        degree = degree,
        avg_separation = mean(distances),
        min_separation = minimum(distances),
        max_separation = maximum(distances),
        std_separation = std(distances),
        num_critical_points = length(all_critical_points),
        individual_distances = distances
    )
end

function plot_minimizer_separation_convergence(separation_results; 
                                             save_plot=false, output_dir=".")
    """Create plot showing the new minimizer separation analysis."""
    
    fig = Figure(size=(1000, 600))
    
    # Extract data
    degrees = [r.degree for r in separation_results if !isnan(r.avg_separation)]
    avg_separations = [r.avg_separation for r in separation_results if !isnan(r.avg_separation)]
    min_separations = [r.min_separation for r in separation_results if !isnan(r.avg_separation)]
    max_separations = [r.max_separation for r in separation_results if !isnan(r.avg_separation)]
    std_separations = [r.std_separation for r in separation_results if !isnan(r.avg_separation)]
    
    # Create single axis for separation plot
    ax = Axis(fig[1, 1],
        xlabel="Polynomial Degree",
        ylabel="Average Separation Distance",
        title="Average Distance from 9 Theoretical Minimizers to Nearest Critical Points\n(Computed from all 16 Subdomains)",
        yscale=log10,
        xlabelsize=16,
        ylabelsize=16,
        titlesize=18,
        yminorticksvisible=true,
        yminorgridvisible=true
    )
    
    # Plot average with error bars
    scatterlines!(ax, degrees, avg_separations,
           color=:blue,
           linewidth=3,
           marker=:circle,
           markersize=12,
           label="Average Separation")
    
    errorbars!(ax, degrees, avg_separations, std_separations,
               color=:blue,
               whiskerwidth=10)
    
    # Add min/max envelope
    band!(ax, degrees, min_separations, max_separations,
          color=(:blue, 0.2),
          label="Min-Max Range")
    
    # Add reference line for matching tolerance
    hlines!(ax, [POINT_MATCHING_TOLERANCE],
            color=:green,
            linestyle=:dash,
            linewidth=2,
            label="Matching Tolerance")
    
    # Legend
    axislegend(ax, position=:rt, labelsize=14)
    
    # Save if requested
    if save_plot
        save(joinpath(output_dir, "minimizer_separation_convergence.png"), fig)
        println("Saved plot to $(joinpath(output_dir, "minimizer_separation_convergence.png"))")
    end
    
    return fig
end

# ================================================================================
# MAIN ANALYSIS FUNCTION (MODIFIED)
# ================================================================================

function run_new_distance_analysis()
    """Run the complete analysis with L2-norm and new distance approach."""
    
    timestamp = Dates.format(now(), "HH-MM")
    output_dir = mkpath(joinpath(@__DIR__, "../outputs", "analysis_$timestamp"))
    
    println("\n" * "="^80)
    println("Running L²-norm and Distance Analysis")
    println("="^80)
    println("Output directory: $output_dir")
    println("Degrees to analyze: $DEGREES")
    println("Number of subdomains: 16")
    println("Theoretical minimizers: 9")
    
    # Generate 16 subdomains
    subdivisions = generate_16_subdivisions_orthant()
    
    # ================================================================================
    # L2-NORM ANALYSIS
    # ================================================================================
    
    println("\n--- L²-norm Analysis ---")
    
    # Results storage for L2-norm
    subdomain_results = Dict{String, Vector{NamedTuple}}()
    full_domain_results = Vector{NamedTuple}()
    
    # First, analyze full domain at each degree
    println("\nAnalyzing full domain...")
    for degree in DEGREES
        result = analyze_full_domain_simple(degree)
        push!(full_domain_results, result)
        println("Full domain degree $degree: L²-norm = $(round(result.l2_norm, sigdigits=3))")
    end
    
    # Analyze each subdomain at each degree
    println("\nAnalyzing subdomains...")
    for subdomain in subdivisions
        results = Vector{NamedTuple}()
        
        for degree in DEGREES
            result = analyze_subdomain_simple(subdomain, degree)
            push!(results, result)
        end
        
        subdomain_results[subdomain.label] = results
    end
    
    # Generate L2 convergence plot
    println("\nGenerating L²-convergence plot...")
    fig_l2 = plot_l2_convergence_simplified(subdomain_results, full_domain_results, 
                                           save_plot=true, output_dir=output_dir)
    display(fig_l2)
    
    # ================================================================================
    # SEPARATION DISTANCE ANALYSIS
    # ================================================================================
    
    println("\n--- Separation Distance Analysis ---")
    
    # Compute separation distances for each degree
    separation_results = []
    
    for degree in DEGREES
        println("\nProcessing degree $degree...")
        result = compute_minimizer_separation_distances(degree, subdivisions)
        push!(separation_results, result)
        
        println("Average separation: $(round(result.avg_separation, sigdigits=3))")
        println("Min separation: $(round(result.min_separation, sigdigits=3))")
        println("Max separation: $(round(result.max_separation, sigdigits=3))")
        println("Critical points found: $(result.num_critical_points)")
    end
    
    # Create separation distance visualization
    println("\nGenerating separation distance plot...")
    fig_sep = plot_minimizer_separation_convergence(separation_results, 
                                                   save_plot=true, 
                                                   output_dir=output_dir)
    display(fig_sep)
    
    # ================================================================================
    # SAVE RESULTS
    # ================================================================================
    
    # Save L2-norm results to CSV
    df_subdomain = DataFrame(
        subdomain = String[],
        degree = Int[],
        l2_norm = Float64[],
        converged = Bool[]
    )
    
    for (label, results) in subdomain_results
        for r in results
            push!(df_subdomain, (label, r.degree, r.l2_norm, r.converged))
        end
    end
    
    CSV.write(joinpath(output_dir, "subdomain_l2_results.csv"), df_subdomain)
    
    df_full = DataFrame(full_domain_results)
    CSV.write(joinpath(output_dir, "full_domain_l2_results.csv"), df_full)
    
    # Save separation distance results to CSV
    df_sep = DataFrame(separation_results)
    select!(df_sep, :degree, :avg_separation, :min_separation, :max_separation, 
            :std_separation, :num_critical_points)
    CSV.write(joinpath(output_dir, "minimizer_separation_results.csv"), df_sep)
    
    println("\n" * "="^80)
    println("Analysis complete!")
    println("Results saved to: $output_dir")
    println("  - L²-norm convergence plot")
    println("  - Minimizer separation distance plot")
    println("  - CSV files with detailed results")
    println("="^80)
    
    return (subdomain_results, full_domain_results, separation_results)
end

# Allow running as standalone script
if abspath(PROGRAM_FILE) == @__FILE__
    run_new_distance_analysis()
end