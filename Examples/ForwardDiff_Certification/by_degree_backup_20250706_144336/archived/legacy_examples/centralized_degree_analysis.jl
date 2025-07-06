# ================================================================================
# Centralized Degree Analysis for 4D Deuflhard Function
# ================================================================================
#
# This file provides a single, clear implementation of the Globtim approximation
# workflow with direct access to all parameters and hyperparameters.
#
# Workflow:
# 1. Construct Globtim polynomial approximants for each degree
# 2. Collect L²-norm errors
# 3. Solve for critical points
# 4. Analyze distances to theoretical minimizers
# 5. Generate visualization plots
#
# ================================================================================

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

# ================================================================================
# MAIN ANALYSIS FUNCTION
# ================================================================================

"""
    run_degree_analysis(; degrees, gn, tolerance, subdomain_strategy, output_dir)

Run the complete degree convergence analysis with centralized parameter control.

# Arguments
- `degrees`: Array of polynomial degrees to test
- `gn`: Grid points per dimension for L²-norm computation
- `tolerance`: Reference tolerance for adaptive degree selection
- `subdomain_strategy`: Either :full_domain or :orthant
- `output_dir`: Optional output directory (auto-generated if not provided)

# Workflow
1. Constructs Globtim approximants for each degree
2. Collects L²-norms for convergence analysis
3. Solves for critical points using the polynomial system
4. Computes distances to theoretical minimizers
5. Generates comprehensive visualization plots
"""
function run_degree_analysis(;
    degrees = [2, 3, 4, 5, 6, 7, 8],
    gn = 16,
    tolerance = 0.01,
    subdomain_strategy = :orthant,
    output_dir = nothing
)
    # ============================================================================
    # SETUP
    # ============================================================================
    
    # Create output directory
    if output_dir === nothing
        timestamp = Dates.format(now(), "HH-MM")
        output_dir = joinpath(@__DIR__, "../outputs", "analysis_$(timestamp)")
    end
    mkpath(output_dir)
    
    println("="^80)
    println("Centralized Degree Analysis for 4D Deuflhard Function")
    println("="^80)
    println("\nParameters:")
    println("  Degrees: ", degrees)
    println("  Grid points (GN): ", gn)
    println("  Tolerance: ", tolerance)
    println("  Subdomain strategy: ", subdomain_strategy)
    println("  Output directory: ", basename(output_dir))
    println()
    
    # ============================================================================
    # GENERATE SUBDOMAINS
    # ============================================================================
    
    if subdomain_strategy == :orthant
        subdomains = generate_16_subdivisions_orthant()
        println("Using 16 subdomains in (+,-,+,-) orthant")
        println("Stretched domain: [-0.1,1.1]×[-1.1,0.1]×[-0.1,1.1]×[-1.1,0.1]")
    else
        subdomains = generate_16_subdivisions()
        println("Using 16 subdomains of full [-1,1]⁴ domain")
    end
    
    # Load theoretical points
    theoretical_points_2d, theoretical_values_2d = load_theoretical_4d_points_orthant()
    println("\nLoaded $(length(theoretical_points_2d)) theoretical 2D critical points")
    
    # ============================================================================
    # MAIN ANALYSIS LOOP
    # ============================================================================
    
    # Storage for results
    all_results = []
    l2_norms_by_degree = Dict{Int, Vector{Float64}}()
    distances_by_degree = Dict{Int, Vector{Float64}}()
    
    for degree in degrees
        println("\n" * "-"^60)
        println("Analyzing degree $degree")
        println("-"^60)
        
        degree_l2_norms = Float64[]
        degree_distances = Float64[]
        
        for (idx, subdomain) in enumerate(subdomains)
            println("\n  Subdomain $(subdomain.label) ($(idx)/$(length(subdomains)))")
            
            # ========================================================================
            # STEP 1: CONSTRUCT GLOBTIM APPROXIMANT
            # ========================================================================
            # This is the key centralized construction with all parameters visible
            
            # Create test input structure with all hyperparameters
            TR = test_input(
                deuflhard_4d_composite,              # Objective function
                dim = 4,                             # Dimension
                center = subdomain.center,           # Subdomain center
                sample_range = subdomain.range,      # Subdomain radius
                tolerance = tolerance,               # L²-norm tolerance (used if GN=nothing)
                GN = gn,                            # Fixed grid size (disables adaptive)
                prec = (16, 8),                     # Precision parameters (α, δ)
                reduce_samples = 4                   # Sample reduction factor
            )
            
            # Construct polynomial approximation
            # Key parameters:
            # - degree: Starting/fixed polynomial degree
            # - basis: :chebyshev or :legendre
            # - verbose: 0 for minimal output, 1 for detailed
            # - precision: RationalPrecision or floating-point
            # - normalized: Use normalized basis polynomials
            # - power_of_two_denom: Ensure rational denominators are powers of 2
            pol = Constructor(
                TR, 
                degree,
                basis = :chebyshev,
                verbose = 0,
                precision = RationalPrecision,
                normalized = false,
                power_of_two_denom = false
            )
            
            # Collect L²-norm
            push!(degree_l2_norms, pol.nrm)
            println("    L²-norm: $(pol.nrm)")
            
            # ========================================================================
            # STEP 2: SOLVE FOR CRITICAL POINTS
            # ========================================================================
            
            # Set up polynomial variables
            @polyvar x[1:4]
            
            # Extract actual degree (handle both Int and Tuple types)
            actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
            
            # Solve polynomial system
            crit_pts_raw = solve_polynomial_system(x, 4, actual_degree, pol.coeffs)
            
            # Filter for real solutions (in [-1,1]^n normalized space)
            crit_pts_normalized = filter(pt -> all(isreal, pt), crit_pts_raw)
            
            # Transform critical points from [-1,1]^n to actual subdomain coordinates
            # Transformation: actual_point = subdomain.range * normalized_point + subdomain.center
            crit_pts_transformed = Vector{Vector{Float64}}()
            for pt in crit_pts_normalized
                # Transform each point
                pt_real = real.(pt)
                transformed_pt = subdomain.range .* pt_real .+ subdomain.center
                
                # Check if the transformed point is within subdomain bounds
                if is_in_subdomain(transformed_pt, subdomain)
                    push!(crit_pts_transformed, transformed_pt)
                end
            end
            
            println("    Found $(length(crit_pts_normalized)) real critical points in [-1,1]^4")
            println("    $(length(crit_pts_transformed)) are within subdomain after transformation")
            
            # ========================================================================
            # STEP 3: COMPUTE DISTANCES TO THEORETICAL MINIMIZERS
            # ========================================================================
            
            # Get theoretical min+min points in this subdomain
            theoretical_4d = generate_4d_tensor_products(theoretical_points_2d)
            min_min_mask = [v[1] == "min" && v[2] == "min" for v in theoretical_values_2d]
            theoretical_min_min = theoretical_4d[min_min_mask]
            theoretical_in_subdomain = filter(pt -> is_in_subdomain(pt, subdomain), theoretical_min_min)
            
            if !isempty(theoretical_in_subdomain) && !isempty(crit_pts_transformed)
                # Compute minimum distance from each theoretical point to any critical point
                for theo_pt in theoretical_in_subdomain
                    min_dist = minimum(norm(cp - theo_pt) for cp in crit_pts_transformed)
                    push!(degree_distances, min_dist)
                end
            end
            
            # Store detailed results
            push!(all_results, (
                degree = degree,
                subdomain = subdomain.label,
                l2_norm = pol.nrm,
                num_crit_pts = length(crit_pts_transformed),
                num_theoretical = length(theoretical_in_subdomain)
            ))
        end
        
        # Store degree-level results
        l2_norms_by_degree[degree] = degree_l2_norms
        distances_by_degree[degree] = degree_distances
        
        println("\n  Average L²-norm for degree $degree: $(mean(degree_l2_norms))")
        if !isempty(degree_distances)
            println("  Average distance to theoretical: $(mean(degree_distances))")
        end
    end
    
    # ============================================================================
    # STEP 4: GENERATE VISUALIZATION PLOTS
    # ============================================================================
    
    println("\n" * "="*60)
    println("Generating visualization plots...")
    
    # Create figure with subplots
    fig = Figure(size=(1200, 500))
    
    # Left plot: L²-norm convergence
    ax1 = Axis(fig[1, 1],
        title = "L²-norm Convergence by Degree",
        xlabel = "Polynomial Degree",
        ylabel = "L²-norm",
        yscale = log10
    )
    
    # Prepare data for L²-norm plot
    degrees_vec = sort(collect(keys(l2_norms_by_degree)))
    mean_l2_norms = [mean(l2_norms_by_degree[d]) for d in degrees_vec]
    
    # Plot L²-norm convergence
    lines!(ax1, degrees_vec, mean_l2_norms, 
           linewidth=3, color=:blue, label="16 Subdomains Average")
    scatter!(ax1, degrees_vec, mean_l2_norms, 
             markersize=12, color=:blue)
    
    # Add reference line for tolerance
    hlines!(ax1, [tolerance], color=:red, linestyle=:dash, 
            linewidth=2, label="Tolerance = $tolerance")
    
    axislegend(ax1, position=:rt)
    
    # Right plot: Average separation distance
    ax2 = Axis(fig[1, 2],
        title = "Average Separation Distance",
        xlabel = "Polynomial Degree",
        ylabel = "Distance",
        yscale = log10
    )
    
    # Prepare data for distance plot
    degrees_with_distances = sort([d for d in degrees_vec if !isempty(distances_by_degree[d])])
    mean_distances = [mean(distances_by_degree[d]) for d in degrees_with_distances]
    
    if !isempty(degrees_with_distances)
        lines!(ax2, degrees_with_distances, mean_distances,
               linewidth=3, color=:darkgreen, label="Average Distance")
        scatter!(ax2, degrees_with_distances, mean_distances,
                 markersize=12, color=:darkgreen)
        
        # Add reference line for matching tolerance
        hlines!(ax2, [1e-3], color=:red, linestyle=:dash,
                linewidth=2, label="Matching Tolerance")
        
        axislegend(ax2, position=:rt)
    end
    
    # Save plots
    save(joinpath(output_dir, "degree_convergence_analysis.png"), fig)
    display(fig)
    
    # ============================================================================
    # STEP 5: SAVE RESULTS TO CSV
    # ============================================================================
    
    # Convert results to DataFrame and save
    df = DataFrame(all_results)
    CSV.write(joinpath(output_dir, "analysis_results.csv"), df)
    
    # Save summary statistics
    summary_df = DataFrame(
        degree = degrees_vec,
        mean_l2_norm = mean_l2_norms,
        num_subdomains = [length(l2_norms_by_degree[d]) for d in degrees_vec]
    )
    
    # Add distance statistics if available
    if !isempty(degrees_with_distances)
        distance_summary = DataFrame(
            degree = degrees_with_distances,
            mean_distance = mean_distances,
            num_distances = [length(distances_by_degree[d]) for d in degrees_with_distances]
        )
        summary_df = outerjoin(summary_df, distance_summary, on=:degree)
    end
    
    CSV.write(joinpath(output_dir, "summary_statistics.csv"), summary_df)
    
    println("\n" * "="*80)
    println("Analysis complete!")
    println("Results saved to: ", basename(output_dir))
    println("="*80)
    
    return all_results, l2_norms_by_degree, distances_by_degree
end

# ================================================================================
# CONVENIENCE FUNCTION FOR DIRECT EXECUTION
# ================================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Run with default parameters when executed directly
    run_degree_analysis()
end