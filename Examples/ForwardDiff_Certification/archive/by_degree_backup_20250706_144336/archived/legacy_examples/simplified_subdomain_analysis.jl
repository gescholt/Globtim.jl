# ================================================================================
# Simplified Subdomain Analysis - Focus on Polynomial Construction and L²-norm
# ================================================================================
# 
# Based on the plan in first_plot_task.md:
# - Divide domain into 16 subdomains
# - Use same number of samples (GN) for each subdomain and degree
# - Increase degree through specified range [2,3,4,5,6]
# - Record L²-norm for each subdomain as degree increases
# - Display all 16 L²-norm curves in one plot (semi-transparent)
# - Show full domain L²-norm on right y-axis in different color
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
# SIMPLE ANALYSIS FUNCTION
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

# ================================================================================
# PLOTTING FUNCTION
# ================================================================================

function plot_l2_convergence_simplified(subdomain_results, full_domain_results; 
                                       save_plot=false, output_dir=".")
    """Create the first plot as specified in the task."""
    
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
                   color=(:red, 0.5),  # Semi-transparent red (increased opacity)
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
    
    # Add tolerance reference line
    hlines!(ax, [TOLERANCE], color=:green, linestyle=:dash, linewidth=2)
    
    # Add legend
    axislegend(ax, position=:rt, labelsize=12)
    
    # Save if requested
    if save_plot
        save(joinpath(output_dir, "l2_convergence_simplified.png"), fig)
        println("Saved plot to $(joinpath(output_dir, "l2_convergence_simplified.png"))")
    end
    
    return fig
end

# ================================================================================
# MINIMIZER ANALYSIS FOR HISTOGRAM
# ================================================================================

function analyze_minimizers_for_degree_combined(degree::Int, subdivisions::Vector{Subdomain})
    """Analyze local minimizers from all subdomains combined for the histogram plot."""
    
    # Load theoretical minimizers
    theoretical_points, _, theoretical_types = load_theoretical_4d_points_orthant()
    
    # Filter to get only min+min points
    min_min_indices = findall(t -> t == "min+min", theoretical_types)
    theoretical_minimizers = theoretical_points[min_min_indices]
    
    @info "Found $(length(theoretical_minimizers)) theoretical min+min points for degree $degree"
    
    # Check if theoretical minimizers are in the expected domain
    if length(theoretical_minimizers) > 0
        theoretical_bounds = [extrema([pt[i] for pt in theoretical_minimizers]) for i in 1:4]
        @info "Theoretical minimizers bounds:" x1=theoretical_bounds[1] x2=theoretical_bounds[2] x3=theoretical_bounds[3] x4=theoretical_bounds[4]
    end
    
    # Collect all BFGS-refined points from all subdomains
    all_bfgs_points = Vector{Vector{Float64}}()
    all_polynomial_minimizers = Vector{Vector{Float64}}()
    
    # Process each subdomain
    subdomain_stats = []
    for (idx, subdomain) in enumerate(subdivisions)
        @info "Processing subdomain $(subdomain.label) ($idx/$(length(subdivisions)))"
        
        # Create test input for the subdomain
        TR = test_input(
            deuflhard_4d_composite,
            dim=4,
            center=subdomain.center,
            sample_range=subdomain.range,
            tolerance=TOLERANCE,
            GN=GN
        )
        
        subdomain_bfgs_count = 0
        subdomain_min_count = 0
        
        try
            pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
            
            # Find critical points of the polynomial
            @polyvar x[1:4]
            actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
            solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
            
            if !isempty(solutions)
                @info "Found $(length(solutions)) solutions for subdomain $(subdomain.label)"
                
                # Check if solutions are in range
                in_range_count = count(p -> all(-1 .<= p .<= 1), solutions)
                @info "Solutions in [-1,1] range: $in_range_count/$(length(solutions))"
                
                df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR, skip_filtering=true)
                
                # Skip if no valid critical points were found
                if nrow(df_crit) == 0 || !("z" in names(df_crit))
                    @info "No valid critical points found in subdomain $(subdomain.label) ($(length(solutions)) solutions filtered out)"
                    continue
                end
                
                @info "Processing $(nrow(df_crit)) critical points for subdomain $(subdomain.label)"
                
                # Analyze the critical points before BFGS
                if nrow(df_crit) > 0
                    z_values = df_crit.z
                    @info "Critical point function values before BFGS:" min=minimum(z_values) max=maximum(z_values) mean=mean(z_values)
                    
                    # Check how many are in subdomain bounds
                    in_bounds_count = 0
                    for i in 1:nrow(df_crit)
                        pt = [df_crit[i, Symbol("x$j")] for j in 1:4]
                        if all(abs.(pt[j] - subdomain.center[j]) <= subdomain.range for j in 1:4)
                            in_bounds_count += 1
                        end
                    end
                    @info "Critical points within subdomain bounds: $in_bounds_count/$(nrow(df_crit))"
                end
                
                # Run analyze_critical_points to get BFGS-refined results and classification
                @info "Starting BFGS optimization for $(nrow(df_crit)) critical points in subdomain $(subdomain.label)"
                
                # Create a copy of verbose setting for BFGS analysis
                bfgs_verbose = false  # Set to true to see detailed BFGS progress
                
                # Use custom BFGS tolerances for better convergence
                # The default x_abstol=0 might be too strict!
                df_enhanced, df_min = analyze_critical_points(
                    deuflhard_4d_composite, 
                    df_crit, 
                    TR, 
                    enable_hessian=true,
                    verbose=bfgs_verbose,
                    bfgs_g_tol=1e-8,      # Gradient tolerance
                    bfgs_f_abstol=1e-12,  # Function absolute tolerance (tighter)
                    bfgs_x_abstol=1e-10   # Parameter absolute tolerance (relaxed from 0)
                )
                
                @info "Enhanced analysis complete: $(nrow(df_enhanced)) points, $(nrow(df_min)) unique minimizers"
                
                # Log BFGS convergence details
                bfgs_attempted = nrow(df_enhanced)
                bfgs_converged = count(df_enhanced.converged)
                bfgs_failed = bfgs_attempted - bfgs_converged
                
                @info "BFGS optimization summary for subdomain $(subdomain.label):" attempted=bfgs_attempted converged=bfgs_converged failed=bfgs_failed
                
                # Also check df_min which has the deduplicated minimizers
                if nrow(df_min) > 0
                    @info "df_min contains $(nrow(df_min)) unique minimizers (already deduplicated by analyze_critical_points)"
                    # Show bounds of these minimizers
                    min_bounds = [extrema([df_min[i, Symbol("x$j")] for i in 1:nrow(df_min)]) for j in 1:4]
                    @info "Bounds of unique minimizers in df_min:" x1=min_bounds[1] x2=min_bounds[2] x3=min_bounds[3] x4=min_bounds[4]
                end
                
                if bfgs_failed > 0
                    # Show details of failed optimizations
                    failed_indices = findall(.!df_enhanced.converged)
                    for (idx_count, idx) in enumerate(failed_indices[1:min(3, length(failed_indices))])
                        pt = [df_enhanced[idx, Symbol("x$j")] for j in 1:4]
                        steps = df_enhanced[idx, :steps]
                        @info "  Failed point $idx_count/$(bfgs_failed): x=$(round.(pt, digits=4)), steps=$steps"
                    end
                    if bfgs_failed > 3
                        @info "  ... and $(bfgs_failed - 3) more failed points"
                    end
                end
                
                # Option 1: Use df_min which already has unique minimizers
                USE_DF_MIN = true  # Set to false to use all converged points from df_enhanced
                
                if USE_DF_MIN && nrow(df_min) > 0
                    # Use the already deduplicated minimizers from df_min
                    @info "Using df_min with $(nrow(df_min)) unique minimizers"
                    for i in 1:nrow(df_min)
                        min_pt = [df_min[i, Symbol("x$j")] for j in 1:4]
                        
                        # Check if minimizer is within subdomain bounds
                        within_bounds = all(abs.(min_pt[j] - subdomain.center[j]) <= subdomain.range for j in 1:4)
                        if within_bounds
                            push!(all_bfgs_points, min_pt)
                        end
                    end
                    # Count how many were added from this subdomain
                    points_added = 0
                    for i in 1:nrow(df_min)
                        min_pt = [df_min[i, Symbol("x$j")] for j in 1:4]
                        if all(abs.(min_pt[j] - subdomain.center[j]) <= subdomain.range for j in 1:4)
                            points_added += 1
                        end
                    end
                    subdomain_bfgs_count = points_added
                    @info "Found $subdomain_bfgs_count unique minimizers within subdomain bounds"
                else
                    # Option 2: Collect all converged BFGS points from df_enhanced
                    converged_count = 0
                    converged_within_bounds = 0
                    for i in 1:nrow(df_enhanced)
                        if df_enhanced[i, :converged]
                            converged_count += 1
                            bfgs_pt = [df_enhanced[i, Symbol("y$j")] for j in 1:4]
                            
                            # Check if BFGS point is within subdomain bounds
                            within_bounds = all(abs.(bfgs_pt[j] - subdomain.center[j]) <= subdomain.range for j in 1:4)
                            if within_bounds
                                converged_within_bounds += 1
                                push!(all_bfgs_points, bfgs_pt)
                            else
                                @debug "BFGS point outside subdomain bounds: pt=$(round.(bfgs_pt, digits=4)), center=$(subdomain.center), range=$(subdomain.range)"
                            end
                        end
                    end
                    subdomain_bfgs_count = converged_within_bounds
                    @info "Found $converged_count converged BFGS points, $converged_within_bounds within subdomain bounds"
                end
                
                # Collect polynomial minimizers
                if "critical_point_type" in names(df_enhanced)
                    min_indices = findall(t -> t == :minimum, df_enhanced.critical_point_type)
                    subdomain_min_count = length(min_indices)
                    @info "Found $(length(min_indices)) points classified as minima in subdomain $(subdomain.label)"
                    for idx in min_indices
                        pt = [df_enhanced[idx, Symbol("x$j")] for j in 1:4]
                        push!(all_polynomial_minimizers, pt)
                    end
                else
                    @warn "No critical_point_type column in df_enhanced for subdomain $(subdomain.label)"
                end
            else
                @info "No solutions found for subdomain $(subdomain.label)"
            end
        catch e
            @warn "Failed to process subdomain $(subdomain.label)" error=e
        end
        
        push!(subdomain_stats, (label=subdomain.label, bfgs_count=subdomain_bfgs_count, min_count=subdomain_min_count))
    end
    
    # Print summary statistics
    @info "Subdomain processing summary for degree $degree:"
    total_crit_points = sum(stat.bfgs_count > 0 || stat.min_count > 0 ? 1 : 0 for stat in subdomain_stats)
    @info "  Subdomains with critical points: $total_crit_points/$(length(subdomain_stats))"
    
    for stat in subdomain_stats
        if stat.bfgs_count > 0 || stat.min_count > 0
            @info "  $(stat.label): $(stat.bfgs_count) BFGS converged within bounds, $(stat.min_count) classified as minima"
        end
    end
    
    @info "Collected $(length(all_bfgs_points)) total BFGS points from all subdomains (before deduplication)"
    @info "Collected $(length(all_polynomial_minimizers)) total polynomial minimizers from all subdomains (before deduplication)"
    
    # Remove duplicate points (points that appear in multiple subdomains)
    unique_bfgs_points = Vector{Vector{Float64}}()
    for pt in all_bfgs_points
        is_duplicate = false
        for unique_pt in unique_bfgs_points
            if norm(pt - unique_pt) < POINT_MATCHING_TOLERANCE
                is_duplicate = true
                break
            end
        end
        if !is_duplicate
            push!(unique_bfgs_points, pt)
        end
    end
    
    unique_polynomial_minimizers = Vector{Vector{Float64}}()
    for pt in all_polynomial_minimizers
        is_duplicate = false
        for unique_pt in unique_polynomial_minimizers
            if norm(pt - unique_pt) < POINT_MATCHING_TOLERANCE
                is_duplicate = true
                break
            end
        end
        if !is_duplicate
            push!(unique_polynomial_minimizers, pt)
        end
    end
    
    @info "After removing duplicates: $(length(unique_bfgs_points)) unique BFGS points, $(length(unique_polynomial_minimizers)) unique polynomial minimizers"
    
    # Print bounds of unique BFGS points to verify they're in the right domain
    if length(unique_bfgs_points) > 0
        bfgs_bounds = [extrema([pt[i] for pt in unique_bfgs_points]) for i in 1:4]
        @info "Unique BFGS points bounds:" x1=bfgs_bounds[1] x2=bfgs_bounds[2] x3=bfgs_bounds[3] x4=bfgs_bounds[4]
    end
    
    # Count how many theoretical minimizers are recovered by BFGS from combined subdomains
    bfgs_converged_count = 0
    close_to_polynomial_count = 0
    distance_distribution = Float64[]
    
    for theoretical_min in theoretical_minimizers
        # Check if this theoretical minimizer is close to any unique BFGS-refined point
        min_distance_to_bfgs = Inf
        
        for bfgs_pt in unique_bfgs_points
            dist = norm(theoretical_min - bfgs_pt)
            min_distance_to_bfgs = min(min_distance_to_bfgs, dist)
        end
        
        push!(distance_distribution, min_distance_to_bfgs)
        
        if min_distance_to_bfgs < POINT_MATCHING_TOLERANCE
            bfgs_converged_count += 1
            
            # Now check if it's also close to a polynomial minimizer
            if !isempty(unique_polynomial_minimizers)
                distances = [norm(theoretical_min - poly_min) for poly_min in unique_polynomial_minimizers]
                min_dist = minimum(distances)
                if min_dist < POINT_MATCHING_TOLERANCE
                    close_to_polynomial_count += 1
                end
            end
        end
    end
    
    # Print distance statistics
    if length(distance_distribution) > 0
        @info "Distance distribution from theoretical to nearest BFGS:" min=minimum(distance_distribution) max=maximum(distance_distribution) median=median(distance_distribution) matching_tolerance=POINT_MATCHING_TOLERANCE
    end
    
    @info "BFGS converged to $bfgs_converged_count theoretical minimizers for degree $degree (combined from all subdomains)"
    @info "$close_to_polynomial_count are within tolerance of polynomial minimizers"
    
    return (
        degree = degree,
        n_bfgs_converged = bfgs_converged_count,
        n_close_to_polynomial = close_to_polynomial_count
    )
end

function plot_minimizer_histogram(results; save_plot=false, output_dir=".")
    """Create histogram showing BFGS convergence to local minimizers."""
    
    fig = Figure(size=(800, 600))
    
    ax = Axis(fig[1, 1],
        xlabel="Polynomial Degree",
        ylabel="Number of Local Minimizers",
        title="BFGS Convergence to Local Minimizers (Combined from 16 Subdomains)",
        xticks=DEGREES,
        xlabelsize=16,
        ylabelsize=16,
        titlesize=18
    )
    
    # Extract data
    degrees = [r.degree for r in results]
    n_bfgs_converged = [r.n_bfgs_converged for r in results]
    n_close_to_polynomial = [r.n_close_to_polynomial for r in results]
    
    # Create grouped bar plot
    x_positions = Float64.(degrees)
    bar_width = 0.8
    
    # Plot total BFGS converged (full bar)
    barplot!(ax, x_positions, n_bfgs_converged,
             color=:lightblue,
             strokecolor=:black,
             strokewidth=1,
             width=bar_width,
             label="BFGS converged points")
    
    # Plot close to polynomial minimizers (contained bar)
    barplot!(ax, x_positions, n_close_to_polynomial,
             color=:darkblue,
             strokecolor=:black,
             strokewidth=1,
             width=bar_width,
             label="Within tolerance of polynomial minimizers")
    
    # Add legend
    axislegend(ax, position=:rt, labelsize=12)
    
    # Add grid
    ax.ygridvisible = true
    ax.xgridvisible = false
    
    # Save if requested
    if save_plot
        save(joinpath(output_dir, "minimizer_convergence_histogram.png"), fig)
        println("Saved histogram to $(joinpath(output_dir, "minimizer_convergence_histogram.png"))")
    end
    
    return fig
end

# ================================================================================
# DISTANCE ANALYSIS - MINIMIZERS TO CRITICAL POINTS
# ================================================================================

function analyze_subdomain_distances(subdomain::Subdomain, degree::Int)
    """Analyze distances from theoretical minimizers to critical points in a subdomain."""
    
    # Load theoretical minimizers
    theoretical_points, _, theoretical_types = load_theoretical_4d_points_orthant()
    min_min_indices = findall(t -> t == "min+min", theoretical_types)
    theoretical_minimizers = theoretical_points[min_min_indices]
    
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
        pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
        
        # Log the L²-norm for debugging
        @debug "Polynomial constructed" subdomain=subdomain.label degree=degree L2_norm=pol.nrm
        
        # Find critical points of the polynomial
        @polyvar x[1:4]
        actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
        solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
        
        if isempty(solutions)
            @debug "No solutions found from polynomial system" subdomain=subdomain.label degree=degree
            return (degree=degree, avg_min_distance=NaN, min_min_distance=NaN, n_minimizers=0, n_critical_points=0)
        end
        
        # Process critical points
        df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR, skip_filtering=true)
        
        if nrow(df_crit) == 0
            return (degree=degree, avg_min_distance=NaN, min_min_distance=NaN, n_minimizers=0, n_critical_points=0)
        end
        
        # Extract critical points coordinates
        critical_points = [
            [df_crit[i, Symbol("x$j")] for j in 1:4] 
            for i in 1:nrow(df_crit)
        ]
        
        # Filter theoretical minimizers that are within this subdomain
        subdomain_minimizers = filter(theoretical_minimizers) do pt
            all(abs.(pt[j] - subdomain.center[j]) <= subdomain.range * 1.1 for j in 1:4)
        end
        
        if isempty(subdomain_minimizers)
            return (degree=degree, avg_min_distance=NaN, min_min_distance=NaN, 
                   n_minimizers=0, n_critical_points=length(critical_points))
        end
        
        # Compute minimal distances from each theoretical minimizer to nearest critical point
        min_distances = Float64[]
        for theo_min in subdomain_minimizers
            if isempty(critical_points)
                push!(min_distances, Inf)
            else
                distances = [norm(theo_min - crit_pt) for crit_pt in critical_points]
                push!(min_distances, minimum(distances))
            end
        end
        
        # Calculate statistics
        avg_min_distance = mean(min_distances)
        min_min_distance = minimum(min_distances)
        
        return (
            degree = degree,
            avg_min_distance = avg_min_distance,
            min_min_distance = min_min_distance,
            n_minimizers = length(subdomain_minimizers),
            n_critical_points = length(critical_points)
        )
        
    catch e
        @warn "Failed to analyze distances" subdomain=subdomain.label degree=degree error=e
        return (degree=degree, avg_min_distance=NaN, min_min_distance=NaN, n_minimizers=0, n_critical_points=0)
    end
end

function analyze_full_domain_distances(degree::Int)
    """Analyze distances for the full domain."""
    
    # Load theoretical minimizers
    theoretical_points, _, theoretical_types = load_theoretical_4d_points_orthant()
    min_min_indices = findall(t -> t == "min+min", theoretical_types)
    theoretical_minimizers = theoretical_points[min_min_indices]
    
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
    
    try
        pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
        
        # Find critical points
        @polyvar x[1:4]
        actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
        solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
        
        if isempty(solutions)
            return (degree=degree, avg_min_distance=NaN, min_min_distance=NaN)
        end
        
        # Process critical points
        df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR, skip_filtering=true)
        
        if nrow(df_crit) == 0
            return (degree=degree, avg_min_distance=NaN, min_min_distance=NaN)
        end
        
        # Extract critical points
        critical_points = [
            [df_crit[i, Symbol("x$j")] for j in 1:4] 
            for i in 1:nrow(df_crit)
        ]
        
        # Compute minimal distances
        min_distances = Float64[]
        for theo_min in theoretical_minimizers
            distances = [norm(theo_min - crit_pt) for crit_pt in critical_points]
            push!(min_distances, minimum(distances))
        end
        
        avg_min_distance = mean(min_distances)
        min_min_distance = minimum(min_distances)
        
        return (degree=degree, avg_min_distance=avg_min_distance, min_min_distance=min_min_distance)
        
    catch e
        @warn "Failed to analyze full domain distances" degree=degree error=e
        return (degree=degree, avg_min_distance=NaN, min_min_distance=NaN)
    end
end

function plot_distance_convergence(subdomain_results, full_domain_results; 
                                 save_plot=false, output_dir=".")
    """Create plot showing distance from theoretical minimizers to critical points."""
    
    fig = Figure(size=(1000, 600))
    
    # Create axis for distance plot
    ax = Axis(fig[1, 1],
        xlabel="Polynomial Degree",
        ylabel="Distance to Nearest Critical Point",
        title="Distance from Theoretical Minimizers to Polynomial Critical Points\n(Data from all 16 Subdomains + Full Domain)",
        yscale=log10,
        xlabelsize=16,
        ylabelsize=16,
        titlesize=16,
        yminorticksvisible=true,
        yminorgridvisible=true
    )
    
    # Collect all data by degree for subdomain analysis
    subdomain_data_by_degree = Dict{Int, NamedTuple}()
    
    for degree in DEGREES
        all_avg_distances = Float64[]
        all_min_distances = Float64[]
        subdomain_count = 0
        
        # Collect data from all subdomains for this degree
        for (label, results) in subdomain_results
            for r in results
                if r.degree == degree
                    subdomain_count += 1
                    if !isnan(r.avg_min_distance)
                        push!(all_avg_distances, r.avg_min_distance)
                        push!(all_min_distances, r.min_min_distance)
                    end
                end
            end
        end
        
        if !isempty(all_avg_distances)
            subdomain_data_by_degree[degree] = (
                avg_of_avgs = mean(all_avg_distances),  # Average separating distance
                max_of_mins = maximum(all_min_distances),  # Maximum of minimum distances
                all_mins = all_min_distances,
                n_valid = length(all_avg_distances),
                n_total = subdomain_count
            )
        end
    end
    
    # Plot subdomain aggregate results
    if !isempty(subdomain_data_by_degree)
        degrees_sub = sort(collect(keys(subdomain_data_by_degree)))
        
        # Average separating distance (average of all subdomain averages)
        avg_separating = [subdomain_data_by_degree[d].avg_of_avgs for d in degrees_sub]
        lines!(ax, degrees_sub, avg_separating,
               color=(:red, 0.8),
               linewidth=2.5,
               linestyle=:dash,
               label="Subdomains: Average Separating Distance")
        
        # Maximum of minimum distances across all subdomains
        max_of_mins = [subdomain_data_by_degree[d].max_of_mins for d in degrees_sub]
        lines!(ax, degrees_sub, max_of_mins,
               color=(:darkred, 0.8),
               linewidth=2.5,
               label="Subdomains: Maximum of Minimum Distances")
        
        # Plot individual subdomain minima as semi-transparent scatter
        for degree in degrees_sub
            scatter!(ax, fill(degree, length(subdomain_data_by_degree[degree].all_mins)), 
                    subdomain_data_by_degree[degree].all_mins,
                    color=(:red, 0.2),
                    markersize=6)
        end
        
        # Add note about data availability
        @info "Subdomain distance data available" degrees=degrees_sub 
        for d in degrees_sub
            data = subdomain_data_by_degree[d]
            @info "  Degree $d: $(data.n_valid)/$(data.n_total) subdomains with valid distances"
        end
    else
        # Add text annotation explaining no subdomain data
        text!(ax, 3.5, 1e-1, text="Note: No subdomain data available\n(minimizers outside subdomain bounds)",
              color=(:red, 0.7), fontsize=14, align=(:center, :center))
    end
    
    # Plot full domain results in distinctive blue colors
    degrees_full = [r.degree for r in full_domain_results if !isnan(r.avg_min_distance)]
    avg_distances_full = [r.avg_min_distance for r in full_domain_results if !isnan(r.avg_min_distance)]
    min_distances_full = [r.min_min_distance for r in full_domain_results if !isnan(r.min_min_distance)]
    
    if !isempty(degrees_full)
        # Full domain average distance
        lines!(ax, degrees_full, avg_distances_full,
               color=(:blue, 0.8),
               linewidth=3,
               linestyle=:dash,
               label="Full Domain: Average Distance")
        
        # Full domain minimum distance
        lines!(ax, degrees_full, min_distances_full,
               color=(:darkblue, 0.8),
               linewidth=3,
               label="Full Domain: Minimum Distance")
        
        # Mark full domain points
        scatter!(ax, degrees_full, min_distances_full,
                color=:darkblue,
                markersize=10,
                marker=:diamond)
    end
    
    # Add reference line for matching tolerance
    hlines!(ax, [POINT_MATCHING_TOLERANCE], 
            color=:green, 
            linestyle=:dash, 
            linewidth=2,
            label="Matching Tolerance")
    
    # Add legend with better organization
    axislegend(ax, position=:rt, labelsize=12, nbanks=2)
    
    # Save if requested
    if save_plot
        save(joinpath(output_dir, "distance_convergence.png"), fig)
        println("Saved plot to $(joinpath(output_dir, "distance_convergence.png"))")
    end
    
    return fig
end

# ================================================================================
# MANUAL DISTANCE COMPUTATION - ALL 9 MINIMIZERS
# ================================================================================

function compute_manual_distances_all_minimizers(degree::Int, subdivisions::Vector{Subdomain})
    """
    Manually compute distances from theoretical minimizers that belong to each subdomain 
    to critical points in that subdomain for a given polynomial degree.
    """
    
    # Load all theoretical points
    theoretical_points, _, theoretical_types = load_theoretical_4d_points_orthant()
    
    # Extract only the 9 min+min points (local minimizers)
    min_min_indices = findall(t -> t == "min+min", theoretical_types)
    all_minimizers = theoretical_points[min_min_indices]
    
    @info "Computing manual distances for degree $degree with $(length(all_minimizers)) theoretical minimizers"
    
    # Results storage
    results_by_subdomain = Dict{String, NamedTuple}()
    detailed_distances = Dict{String, Matrix{Float64}}()  # subdomain -> matrix of distances
    
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
            pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
            
            # Find critical points of the polynomial
            @polyvar x[1:4]
            actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
            solutions = solve_polynomial_system(x, 4, actual_degree, pol.coeffs, basis=:chebyshev)
            
            if isempty(solutions)
                results_by_subdomain[subdomain.label] = (
                    n_critical_points = 0,
                    n_minimizers_in_subdomain = 0,
                    minimizer_indices = Int[],
                    distances_matrix = Matrix{Float64}(undef, 0, 0),
                    min_distance_per_minimizer = Float64[],
                    overall_min_distance = NaN,
                    overall_avg_distance = NaN
                )
                continue
            end
            
            # Process critical points
            df_crit = process_crit_pts(solutions, deuflhard_4d_composite, TR, skip_filtering=true)
            
            if nrow(df_crit) == 0
                results_by_subdomain[subdomain.label] = (
                    n_critical_points = 0,
                    n_minimizers_in_subdomain = 0,
                    minimizer_indices = Int[],
                    distances_matrix = Matrix{Float64}(undef, 0, 0),
                    min_distance_per_minimizer = Float64[],
                    overall_min_distance = NaN,
                    overall_avg_distance = NaN
                )
                continue
            end
            
            # Extract critical points
            critical_points = [
                [df_crit[i, Symbol("x$j")] for j in 1:4] 
                for i in 1:nrow(df_crit)
            ]
            
            # Filter minimizers that belong to this subdomain
            subdomain_minimizers = Vector{Vector{Float64}}()
            subdomain_minimizer_indices = Int[]
            
            for (idx, minimizer) in enumerate(all_minimizers)
                if is_point_in_subdomain(minimizer, subdomain, tolerance=0.0)
                    push!(subdomain_minimizers, minimizer)
                    push!(subdomain_minimizer_indices, idx)
                end
            end
            
            if isempty(subdomain_minimizers)
                @info "  Subdomain $(subdomain.label): no theoretical minimizers in this subdomain"
                results_by_subdomain[subdomain.label] = (
                    n_critical_points = n_crit,
                    n_minimizers_in_subdomain = 0,
                    minimizer_indices = Int[],
                    distances_matrix = Matrix{Float64}(undef, 0, 0),
                    min_distance_per_minimizer = Float64[],
                    overall_min_distance = NaN,
                    overall_avg_distance = NaN
                )
                continue
            end
            
            # Compute distance matrix: rows = subdomain minimizers, columns = critical points
            n_min = length(subdomain_minimizers)
            n_crit = length(critical_points)
            distance_matrix = Matrix{Float64}(undef, n_min, n_crit)
            
            for i in 1:n_min
                for j in 1:n_crit
                    distance_matrix[i, j] = norm(subdomain_minimizers[i] - critical_points[j])
                end
            end
            
            # Compute statistics
            min_distance_per_minimizer = [minimum(distance_matrix[i, :]) for i in 1:n_min]
            overall_min_distance = minimum(distance_matrix)
            overall_avg_distance = mean(min_distance_per_minimizer)
            
            results_by_subdomain[subdomain.label] = (
                n_critical_points = n_crit,
                n_minimizers_in_subdomain = n_min,
                minimizer_indices = subdomain_minimizer_indices,
                distances_matrix = distance_matrix,
                min_distance_per_minimizer = min_distance_per_minimizer,
                overall_min_distance = overall_min_distance,
                overall_avg_distance = overall_avg_distance
            )
            
            detailed_distances[subdomain.label] = distance_matrix
            
        catch e
            @warn "Failed to analyze subdomain $(subdomain.label)" error=e
            results_by_subdomain[subdomain.label] = (
                n_critical_points = -1,
                n_minimizers_in_subdomain = 0,
                minimizer_indices = Int[],
                distances_matrix = Matrix{Float64}(undef, 0, 0),
                min_distance_per_minimizer = Float64[],
                overall_min_distance = NaN,
                overall_avg_distance = NaN
            )
        end
    end
    
    # Print detailed report
    @info "\nDetailed Distance Report for Degree $degree:"
    @info "=" ^ 80
    
    # First report which minimizers belong to which subdomains
    @info "\nMinimizer Distribution Across Subdomains:"
    for (idx, minimizer) in enumerate(all_minimizers)
        @info "Minimizer $idx: $(round.(minimizer, digits=4))"
        
        # Find which subdomains contain this minimizer
        containing_subdomains = String[]
        for (label, result) in results_by_subdomain
            if idx in result.minimizer_indices
                push!(containing_subdomains, label)
            end
        end
        
        if !isempty(containing_subdomains)
            @info "  Found in subdomains: $(join(containing_subdomains, ", "))"
        else
            @info "  Not found in any subdomain (boundary point?)"
        end
    end
    
    @info "\nDistance Analysis by Subdomain:"
    for (label, result) in sort(collect(results_by_subdomain))
        if result.n_minimizers_in_subdomain > 0 && result.n_critical_points > 0
            @info "Subdomain $label: $(result.n_minimizers_in_subdomain) minimizers, $(result.n_critical_points) critical points"
            @info "  Min distance: $(round(result.overall_min_distance, digits=6))"
            @info "  Avg min distance: $(round(result.overall_avg_distance, digits=6))"
            
            # Report per-minimizer distances
            for (local_idx, global_idx) in enumerate(result.minimizer_indices)
                @info "  Minimizer $global_idx: min dist = $(round(result.min_distance_per_minimizer[local_idx], digits=6))"
            end
        elseif result.n_minimizers_in_subdomain == 0
            @info "Subdomain $label: no theoretical minimizers"
        else
            @info "Subdomain $label: no critical points found"
        end
    end
    
    @info "=" ^ 80
    
    # Summary statistics
    all_min_distances = Float64[]
    total_minimizers_analyzed = 0
    for result in values(results_by_subdomain)
        if result.n_critical_points > 0 && result.n_minimizers_in_subdomain > 0
            append!(all_min_distances, result.min_distance_per_minimizer)
            total_minimizers_analyzed += result.n_minimizers_in_subdomain
        end
    end
    
    if !isempty(all_min_distances)
        @info "\nOverall Summary:"
        @info "  Total subdomains with critical points: $(sum(r.n_critical_points > 0 for r in values(results_by_subdomain)))/16"
        @info "  Total subdomains with minimizers: $(sum(r.n_minimizers_in_subdomain > 0 for r in values(results_by_subdomain)))/16"
        @info "  Total minimizer-subdomain pairs analyzed: $total_minimizers_analyzed"
        @info "  Global minimum distance: $(round(minimum(all_min_distances), digits=6))"
        @info "  Global average minimum distance: $(round(mean(all_min_distances), digits=6))"
        @info "  Number of matches within tolerance ($(POINT_MATCHING_TOLERANCE)): $(sum(all_min_distances .< POINT_MATCHING_TOLERANCE))"
    end
    
    return results_by_subdomain, detailed_distances
end

function plot_manual_distance_analysis(manual_results_by_degree, degrees; 
                                     save_plot=false, output_dir=".")
    """Create visualization of manual distance analysis across all degrees and minimizers."""
    
    fig = Figure(size=(1200, 800))
    
    # Main title
    Label(fig[0, :], "Manual Distance Analysis: 9 Minimizers × 16 Subdomains",
          fontsize=20, font="bold")
    
    # Create a heatmap showing minimum distances
    ax = Axis(fig[1, 1],
        xlabel="Subdomain",
        ylabel="Theoretical Minimizer Index",
        title="Minimum Distance to Nearest Critical Point (log scale)",
        xlabelsize=14,
        ylabelsize=14,
        titlesize=16
    )
    
    # Collect data for heatmap (focus on highest degree for best approximation)
    highest_degree = maximum(degrees)
    results = manual_results_by_degree[highest_degree].results
    
    # Get sorted subdomain labels
    subdomain_labels = sort(collect(keys(results)))
    
    # Create distance matrix for heatmap
    n_minimizers = 9
    n_subdomains = length(subdomain_labels)
    distance_matrix_plot = fill(NaN, n_minimizers, n_subdomains)
    
    for (j, label) in enumerate(subdomain_labels)
        result = results[label]
        if result.n_critical_points > 0 && result.n_minimizers_in_subdomain > 0
            # Map global minimizer indices to their distances
            for (local_idx, global_idx) in enumerate(result.minimizer_indices)
                distance_matrix_plot[global_idx, j] = result.min_distance_per_minimizer[local_idx]
            end
        end
    end
    
    # Use log scale for better visualization
    log_distances = log10.(distance_matrix_plot)
    log_distances[isnan.(distance_matrix_plot)] .= NaN
    
    # Create heatmap
    hm = heatmap!(ax, log_distances,
                  colormap=:viridis,
                  colorrange=(-6, 0),  # 10^-6 to 10^0
                  nan_color=:gray)
    
    # Customize axis
    ax.xticks = (1:n_subdomains, subdomain_labels)
    ax.xticklabelrotation = π/4
    ax.yticks = (1:n_minimizers, ["Min $i" for i in 1:n_minimizers])
    
    # Add colorbar
    cb = Colorbar(fig[1, 2], hm, 
                  label="log₁₀(distance)",
                  labelsize=14)
    
    # Add degree progression plot
    ax2 = Axis(fig[2, 1],
        xlabel="Polynomial Degree",
        ylabel="Fraction of Minimizers Captured",
        title="Minimizer Recovery Rate (distance < $(POINT_MATCHING_TOLERANCE))",
        xlabelsize=14,
        ylabelsize=14,
        titlesize=16,
        xticks=degrees
    )
    
    # Calculate recovery rate for each degree
    recovery_rates = Float64[]
    for degree in degrees
        results = manual_results_by_degree[degree].results
        
        # Count how many minimizer-subdomain pairs have distance < tolerance
        n_captured = 0
        n_total = 0
        
        for (label, result) in results
            if result.n_critical_points > 0 && result.n_minimizers_in_subdomain > 0
                for dist in result.min_distance_per_minimizer
                    n_total += 1
                    if dist < POINT_MATCHING_TOLERANCE
                        n_captured += 1
                    end
                end
            end
        end
        
        rate = n_total > 0 ? n_captured / n_total : 0.0
        push!(recovery_rates, rate)
    end
    
    lines!(ax2, degrees, recovery_rates,
           color=:blue,
           linewidth=3,
           marker=:circle,
           markersize=12)
    
    # Add reference line at 100%
    hlines!(ax2, [1.0], color=:green, linestyle=:dash, linewidth=2)
    
    # Set y-axis limits
    ylims!(ax2, 0, 1.1)
    
    # Save if requested
    if save_plot
        save(joinpath(output_dir, "manual_distance_analysis.png"), fig)
        println("Saved manual distance analysis plot to $(joinpath(output_dir, "manual_distance_analysis.png"))")
    end
    
    return fig
end

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

function run_simplified_analysis()
    @info "Starting Simplified Subdomain Analysis" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    @info "Parameters" degrees=DEGREES GN=GN tolerance=TOLERANCE
    
    # Generate 16 subdomains
    subdivisions = generate_16_subdivisions_orthant()
    @info "Generated $(length(subdivisions)) subdomains in (+,-,+,-) orthant"
    
    # Create output directory
    output_dir = joinpath(@__DIR__, "../outputs", "simplified_" * Dates.format(now(), "HH-MM"))
    mkpath(output_dir)
    @info "Created output directory" path=output_dir
    
    # Results storage
    subdomain_results = Dict{String, Vector{NamedTuple}}()
    full_domain_results = Vector{NamedTuple}()
    
    # First, analyze full domain at each degree
    @info "\nAnalyzing full domain..."
    for degree in DEGREES
        result = analyze_full_domain_simple(degree)
        push!(full_domain_results, result)
        @info "Full domain degree $degree" L2_norm=@sprintf("%.2e", result.l2_norm)
    end
    
    # Analyze each subdomain at each degree
    @info "\nAnalyzing subdomains..."
    for subdomain in subdivisions
        @info "Analyzing subdomain $(subdomain.label)"
        results = Vector{NamedTuple}()
        
        for degree in DEGREES
            result = analyze_subdomain_simple(subdomain, degree)
            push!(results, result)
            
            if !isnan(result.l2_norm)
                @info "  Degree $degree" L2_norm=@sprintf("%.2e", result.l2_norm) converged=result.converged
            else
                @warn "  Degree $degree failed"
            end
        end
        
        subdomain_results[subdomain.label] = results
    end
    
    # Generate the plot
    @info "\nGenerating L²-convergence plot..."
    fig = plot_l2_convergence_simplified(subdomain_results, full_domain_results, 
                                       save_plot=true, output_dir=output_dir)
    
    # Also display the plot
    display(fig)
    
    # Export results to CSV
    @info "\nExporting results to CSV..."
    
    # Create DataFrame for subdomain results
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
    
    CSV.write(joinpath(output_dir, "subdomain_results.csv"), df_subdomain)
    
    # Create DataFrame for full domain results
    df_full = DataFrame(full_domain_results)
    CSV.write(joinpath(output_dir, "full_domain_results.csv"), df_full)
    
    # ================================================================================
    # HISTOGRAM ANALYSIS
    # ================================================================================
    
    @info "\nStarting minimizer convergence analysis for histogram (combined from all subdomains)..."
    
    # Analyze minimizers for each degree
    minimizer_results = []
    for degree in DEGREES
        @info "Analyzing minimizers for degree $degree..."
        result = analyze_minimizers_for_degree_combined(degree, subdivisions)
        push!(minimizer_results, result)
        
        @info "Results" n_bfgs_converged=result.n_bfgs_converged n_close_to_polynomial=result.n_close_to_polynomial
    end
    
    # Generate the histogram
    @info "\nGenerating minimizer convergence histogram..."
    fig_hist = plot_minimizer_histogram(minimizer_results, save_plot=true, output_dir=output_dir)
    
    # Display the histogram
    display(fig_hist)
    
    # Export minimizer results to CSV
    df_minimizers = DataFrame(minimizer_results)
    CSV.write(joinpath(output_dir, "minimizer_convergence_results.csv"), df_minimizers)
    
    # ================================================================================
    # DISTANCE ANALYSIS
    # ================================================================================
    
    @info "\nStarting distance analysis..."
    
    # Storage for distance results
    subdomain_distance_results = Dict{String, Vector{NamedTuple}}()
    full_domain_distance_results = Vector{NamedTuple}()
    
    # Analyze full domain distances
    @info "Analyzing full domain distances..."
    for degree in DEGREES
        result = analyze_full_domain_distances(degree)
        push!(full_domain_distance_results, result)
        if !isnan(result.avg_min_distance)
            @info "Full domain degree $degree" avg_distance=@sprintf("%.2e", result.avg_min_distance) min_distance=@sprintf("%.2e", result.min_min_distance)
        end
    end
    
    # Analyze subdomain distances
    @info "\nAnalyzing subdomain distances..."
    for subdomain in subdivisions
        @info "Analyzing distances for subdomain $(subdomain.label)"
        results = Vector{NamedTuple}()
        
        for degree in DEGREES
            result = analyze_subdomain_distances(subdomain, degree)
            push!(results, result)
            
            if !isnan(result.avg_min_distance)
                @info "  Degree $degree" avg_distance=@sprintf("%.2e", result.avg_min_distance) min_distance=@sprintf("%.2e", result.min_min_distance) n_minimizers=result.n_minimizers n_critical_points=result.n_critical_points
            else
                # Provide more details about why there's no valid data
                if result.n_critical_points == 0
                    @info "  Degree $degree: no critical points found in polynomial"
                elseif result.n_minimizers == 0
                    @info "  Degree $degree: no theoretical minimizers in this subdomain ($(result.n_critical_points) critical points found)"
                else
                    @info "  Degree $degree: analysis failed"
                end
            end
        end
        
        subdomain_distance_results[subdomain.label] = results
    end
    
    # Generate the distance plot
    @info "\nGenerating distance convergence plot..."
    fig_dist = plot_distance_convergence(subdomain_distance_results, full_domain_distance_results, 
                                       save_plot=true, output_dir=output_dir)
    
    # Display the distance plot
    display(fig_dist)
    
    # Export distance results to CSV
    @info "\nExporting distance results to CSV..."
    
    # Create DataFrame for subdomain distance results
    df_subdomain_dist = DataFrame(
        subdomain = String[],
        degree = Int[],
        avg_min_distance = Float64[],
        min_min_distance = Float64[],
        n_minimizers = Int[],
        n_critical_points = Int[]
    )
    
    for (label, results) in subdomain_distance_results
        for r in results
            push!(df_subdomain_dist, (label, r.degree, r.avg_min_distance, r.min_min_distance, 
                                     r.n_minimizers, r.n_critical_points))
        end
    end
    
    CSV.write(joinpath(output_dir, "subdomain_distance_results.csv"), df_subdomain_dist)
    
    # Create DataFrame for full domain distance results
    df_full_dist = DataFrame(full_domain_distance_results)
    CSV.write(joinpath(output_dir, "full_domain_distance_results.csv"), df_full_dist)
    
    # ================================================================================
    # MANUAL DISTANCE COMPUTATION FOR ALL 9 MINIMIZERS
    # ================================================================================
    
    @info "\nStarting manual distance computation for all 9 minimizers..."
    @info "This will compute distances from each minimizer to all critical points in each subdomain"
    
    # Perform manual distance analysis for each degree
    manual_distance_results = Dict{Int, Any}()
    for degree in DEGREES
        @info "\n" * "="^80
        @info "Manual distance analysis for degree $degree"
        results, distances = compute_manual_distances_all_minimizers(degree, subdivisions)
        manual_distance_results[degree] = (results=results, distances=distances)
    end
    
    # Save manual distance results
    manual_output_path = joinpath(output_dir, "manual_distance_analysis.txt")
    open(manual_output_path, "w") do io
        println(io, "Manual Distance Analysis Results")
        println(io, "="^80)
        println(io, "Computed distances from theoretical minimizers to critical points")
        println(io, "Only considering minimizers that belong to each subdomain")
        println(io, "Analysis for degrees: $(join(DEGREES, ", "))")
        println(io, "")
        
        for degree in DEGREES
            println(io, "\nDegree $degree:")
            println(io, "-"^40)
            results = manual_distance_results[degree].results
            
            # Summary table
            println(io, "Subdomain | #Minimizers | #CritPts | MinDist    | AvgMinDist | MinimizerIndices")
            println(io, "-"^80)
            
            for subdomain in subdivisions
                if haskey(results, subdomain.label)
                    r = results[subdomain.label]
                    if r.n_critical_points > 0 && r.n_minimizers_in_subdomain > 0
                        minimizer_str = join(r.minimizer_indices, ",")
                        println(io, @sprintf("%-9s | %11d | %8d | %.8f | %.8f | %s", 
                            subdomain.label, r.n_minimizers_in_subdomain, r.n_critical_points, 
                            r.overall_min_distance, r.overall_avg_distance, minimizer_str))
                    elseif r.n_minimizers_in_subdomain == 0
                        println(io, @sprintf("%-9s | %11d | %8s | %10s | %10s | %s", 
                            subdomain.label, 0, "-", "-", "-", "none"))
                    else
                        println(io, @sprintf("%-9s | %11d | %8d | %10s | %10s | %s", 
                            subdomain.label, r.n_minimizers_in_subdomain, 0, "N/A", "N/A", 
                            join(r.minimizer_indices, ",")))
                    end
                end
            end
            
            # Summary stats for this degree
            n_subdomains_with_minimizers = sum(r.n_minimizers_in_subdomain > 0 for r in values(results))
            n_successful_matches = sum(r.n_minimizers_in_subdomain > 0 && r.n_critical_points > 0 && 
                                     r.overall_min_distance < POINT_MATCHING_TOLERANCE for r in values(results))
            println(io, "\nSummary for degree $degree:")
            println(io, "  Subdomains with minimizers: $n_subdomains_with_minimizers/16")
            println(io, "  Successful matches (distance < $(POINT_MATCHING_TOLERANCE)): $n_successful_matches")
        end
    end
    
    @info "Manual distance analysis saved to: $(basename(manual_output_path))"
    
    # Create visualization for manual distance analysis
    @info "\nGenerating manual distance analysis visualization..."
    fig_manual = plot_manual_distance_analysis(manual_distance_results, DEGREES,
                                             save_plot=true, output_dir=output_dir)
    
    # Display the manual analysis plot
    display(fig_manual)
    
    @info "Analysis complete!" output_dir=output_dir
    
    return subdomain_results, full_domain_results, minimizer_results, subdomain_distance_results, full_domain_distance_results, manual_distance_results
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_simplified_analysis()
end