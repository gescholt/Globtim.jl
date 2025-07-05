# ================================================================================
# Local Minimizer Convergence Analysis - Second Plot Task
# ================================================================================
# 
# Based on the plan in first_plot_task.md:
# - Focus on convergence to local minimizers (min+min points)
# - Create histogram by degree showing:
#   - Total height: number of local minimizers BFGS converged to
#   - Contained bar: number within tolerance of actual critical points
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
using AnalysisUtilities
using Globtim
using DynamicPolynomials
using LinearAlgebra
using Optim
using ForwardDiff

# Standard packages
using Printf, Dates, Statistics
using CairoMakie
using DataFrames, CSV

# ================================================================================
# PARAMETERS
# ================================================================================

const MINIMIZER_DEGREES = [2, 3, 4, 5, 6]  # Degrees to test
const POINT_MATCHING_TOLERANCE = 1e-3      # Tolerance for matching points
const BFGS_TOLERANCE = 1e-8               # BFGS convergence tolerance

# ================================================================================
# CRITICAL POINT ANALYSIS USING EXISTING UTILITIES
# ================================================================================

function analyze_minimizers_for_degree_v2(degree::Int)
    """Analyze local minimizers using existing analysis utilities."""
    
    # Full domain parameters
    center = [0.5, -0.5, 0.5, -0.5]
    range = 0.5
    
    # Load all theoretical critical points
    theoretical_points, _, theoretical_types = 
        load_theoretical_4d_points_orthant()
    
    # Filter to get only min+min points
    min_min_indices = findall(t -> t == "min+min", theoretical_types)
    theoretical_minimizers = theoretical_points[min_min_indices]
    
    @info "Found $(length(theoretical_minimizers)) theoretical min+min points"
    
    # Run the standard analysis
    result = analyze_single_degree(
        deuflhard_4d_composite,
        degree,
        center,
        range,
        theoretical_points,
        theoretical_types,
        gn = GN_FIXED,
        tolerance_target = 0.01
    )
    
    # Extract computed points that are classified as minima
    computed_minimizers = Vector{Vector{Float64}}()
    
    # We need to re-compute the Hessian classification since we only have the points
    if !isempty(result.computed_points)
        # Create polynomial for Hessian evaluation
        TR = test_input(
            deuflhard_4d_composite,
            dim=4,
            center=center,
            sample_range=range,
            tolerance=0.01,
            GN=GN_FIXED
        )
        
        try
            pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
            
            # Classify each computed point
            @polyvar x[1:4]
            for pt in result.computed_points
                H = compute_hessian_at_point_forwarddiff(pol, pt)
                eigenvals = eigvals(H)
                
                # Check if all eigenvalues are positive (local minimum)
                if all(λ -> λ > 1e-6, eigenvals)
                    push!(computed_minimizers, pt)
                end
            end
        catch e
            @warn "Failed to classify points for degree $degree" error=e
        end
    end
    
    @info "Found $(length(computed_minimizers)) computed minimizers for degree $degree"
    
    # Run BFGS from each theoretical minimizer
    bfgs_converged_points = Vector{Vector{Float64}}()
    
    for theoretical_min in theoretical_minimizers
        # Use the actual function (not polynomial) for BFGS
        obj_func = x -> deuflhard_4d_composite(x)
        
        # Run BFGS
        result_bfgs = optimize(obj_func, theoretical_min, BFGS(), 
                        Optim.Options(
                            g_tol = BFGS_TOLERANCE,
                            f_abstol = 1e-20,
                            x_abstol = 1e-12
                        ))
        
        if Optim.converged(result_bfgs)
            push!(bfgs_converged_points, Optim.minimizer(result_bfgs))
        end
    end
    
    @info "BFGS converged to $(length(bfgs_converged_points)) points"
    
    # Count how many BFGS points are close to computed polynomial minimizers
    close_to_actual = 0
    for bfgs_pt in bfgs_converged_points
        # Find closest computed minimizer
        if !isempty(computed_minimizers)
            distances = [norm(bfgs_pt - min_pt) for min_pt in computed_minimizers]
            min_dist = minimum(distances)
            if min_dist < POINT_MATCHING_TOLERANCE
                close_to_actual += 1
            end
        end
    end
    
    return (
        degree = degree,
        n_theoretical_minimizers = length(theoretical_minimizers),
        n_polynomial_minimizers = length(computed_minimizers),
        n_bfgs_converged = length(bfgs_converged_points),
        n_close_to_actual = close_to_actual
    )
end

# ================================================================================
# HELPER FUNCTION FOR HESSIAN COMPUTATION
# ================================================================================

function compute_hessian_at_point_forwarddiff(pol::ApproxPoly, point::Vector{Float64})
    """Compute Hessian using ForwardDiff on the actual function."""
    
    # For now, compute Hessian of the actual function at the point
    # since we don't have a simple way to evaluate the polynomial
    H = ForwardDiff.hessian(deuflhard_4d_composite, point)
    return H
end

# ================================================================================
# PLOTTING FUNCTION
# ================================================================================

function plot_minimizer_convergence_histogram(results; save_plot=false, output_dir=".")
    """Create histogram showing BFGS convergence to local minimizers."""
    
    fig = Figure(size=(800, 600))
    
    ax = Axis(fig[1, 1],
        xlabel="Polynomial Degree",
        ylabel="Number of Local Minimizers",
        title="BFGS Convergence to Local Minimizers",
        xticks=MINIMIZER_DEGREES,
        xlabelsize=16,
        ylabelsize=16,
        titlesize=18
    )
    
    # Extract data
    degrees = [r.degree for r in results]
    n_bfgs_converged = [r.n_bfgs_converged for r in results]
    n_close_to_actual = [r.n_close_to_actual for r in results]
    
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
    
    # Plot close to actual (contained bar)
    barplot!(ax, x_positions, n_close_to_actual,
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
        println("Saved plot to $(joinpath(output_dir, "minimizer_convergence_histogram.png"))")
    end
    
    return fig
end

# ================================================================================
# MAIN ANALYSIS
# ================================================================================

function run_minimizer_convergence_analysis()
    @info "Starting Local Minimizer Convergence Analysis" timestamp=Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    @info "Parameters" degrees=MINIMIZER_DEGREES tolerance=POINT_MATCHING_TOLERANCE
    
    # Create output directory
    output_dir = joinpath(@__DIR__, "../outputs", "minimizer_" * Dates.format(now(), "HH-MM"))
    mkpath(output_dir)
    @info "Created output directory" path=output_dir
    
    # Analyze each degree
    results = []
    for degree in MINIMIZER_DEGREES
        @info "\nAnalyzing degree $degree..."
        result = analyze_minimizers_for_degree_v2(degree)
        push!(results, result)
        
        @info "Results for degree $degree" result...
    end
    
    # Generate the plot
    @info "\nGenerating minimizer convergence histogram..."
    fig = plot_minimizer_convergence_histogram(results, save_plot=true, output_dir=output_dir)
    
    # Display the plot
    display(fig)
    
    # Export results to CSV
    df = DataFrame(results)
    CSV.write(joinpath(output_dir, "minimizer_convergence_results.csv"), df)
    
    @info "Analysis complete!" output_dir=output_dir
    
    return results
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_minimizer_convergence_analysis()
end