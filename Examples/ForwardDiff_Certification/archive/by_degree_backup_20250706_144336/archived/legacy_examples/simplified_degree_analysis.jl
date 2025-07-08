# ================================================================================
# Simplified Degree Analysis for 4D Deuflhard Function
# ================================================================================
#
# Clean implementation focusing on polynomial degree convergence analysis
# Key principle: Let Globtim handle all domain transformations
#
# ================================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

# Add shared directory to load path
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))

# Load modules
using Common4DDeuflhard
using SubdomainManagement
using TheoreticalPoints
using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames, CSV
using Statistics
using CairoMakie
using Printf, Dates

# ================================================================================
# MAIN ANALYSIS FUNCTION
# ================================================================================

"""
    run_simplified_analysis(; degrees, gn, verbose, output_dir)

Run simplified degree convergence analysis.

# Arguments
- `degrees`: Vector of polynomial degrees to test (default: [2, 3, 4, 5, 6, 7, 8])
- `gn`: Grid points per dimension for fixed grid (default: 16)
- `verbose`: Print detailed output per degree (default: false)
- `output_dir`: Output directory for results (auto-generated if nothing)

# Returns
- `results`: DataFrame with per-subdomain results
- `l2_norms_by_degree`: Dict mapping degree to vector of L²-norms
- `distances_by_degree`: Dict mapping degree to vector of distances

# Workflow
1. For each degree and subdomain, construct Globtim approximant
2. Use process_crit_pts to get critical points (handles transformation)
3. Compute distances to theoretical minimizers
4. Generate convergence plots
"""
function run_simplified_analysis(;
    degrees = [2, 3, 4, 5, 6, 7, 8],
    gn = 16,                        # Fixed grid size (no tolerance adaptation)
    verbose = false,
    output_dir = nothing
)
    # Setup output directory
    if output_dir === nothing
        timestamp = Dates.format(now(), "HH-MM")
        output_dir = joinpath(@__DIR__, "../outputs", "simplified_$(timestamp)")
    end
    mkpath(output_dir)
    
    println("Simplified Degree Analysis")
    println("Degrees: ", degrees)
    println("Grid points: ", gn, " (fixed - no tolerance adaptation)")
    println()
    
    # Generate subdomains and load theoretical points
    subdomains = generate_16_subdivisions_orthant()
    
    # Load theoretical 4D points (returns points, values, and types)
    theoretical_4d, theoretical_values, theoretical_types = load_theoretical_4d_points_orthant()
    
    # Filter for min+min points only (local minimizers)
    min_min_mask = [contains(t, "min+min") for t in theoretical_types]
    theoretical_minimizers = theoretical_4d[min_min_mask]
    
    println("Setup: $(length(subdomains)) subdomains, $(length(theoretical_minimizers)) theoretical minimizers")
    println("-"^60)
    
    # Storage for results
    results = DataFrame()
    l2_norms_by_degree = Dict{Int, Vector{Float64}}()
    distances_by_degree = Dict{Int, Vector{Float64}}()
    recovery_by_degree = Dict{Int, Int}()  # Count of recovered minimizers
    
    # Main analysis loop
    for degree in degrees
        degree_l2_norms = Float64[]
        all_distances = Float64[]
        recovered_count = 0
        
        for subdomain in subdomains
            # Step 1: Create test input with subdomain specifications
            TR = test_input(
                deuflhard_4d_composite,
                dim = 4,
                center = subdomain.center,
                sample_range = subdomain.range,
                GN = gn,                    # Fixed grid -> no tolerance adaptation
                prec = (16, 8),
                reduce_samples = 4
            )
            
            # Step 2: Construct polynomial approximant
            pol = Constructor(TR, degree, verbose=0)
            push!(degree_l2_norms, pol.nrm)
            
            # Step 3: Solve and process critical points
            # process_crit_pts returns points in ACTUAL domain coordinates
            @polyvar x[1:4]
            actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
            
            # Get critical points using Globtim's processing
            # This automatically:
            # - Filters to [-1,1]^n in normalized space
            # - Transforms to actual domain coordinates
            # - Returns a DataFrame with points and values
            df_crit = process_crit_pts(
                solve_polynomial_system(x, 4, actual_degree, pol.coeffs),
                deuflhard_4d_composite,
                TR
            )
            
            # Filter for points in this subdomain
            crit_pts_in_subdomain = Vector{Float64}[]
            for row in eachrow(df_crit)
                pt = [row[Symbol("x$i")] for i in 1:4]
                if is_point_in_subdomain(pt, subdomain)
                    push!(crit_pts_in_subdomain, pt)
                end
            end
            
            # Step 4: Compute distances to theoretical minimizers in this subdomain
            theoretical_in_subdomain = filter(pt -> is_point_in_subdomain(pt, subdomain), theoretical_minimizers)
            
            for theo_pt in theoretical_in_subdomain
                if !isempty(crit_pts_in_subdomain)
                    min_dist = minimum(norm(cp - theo_pt) for cp in crit_pts_in_subdomain)
                    push!(all_distances, min_dist)
                    
                    # Count as recovered if distance < 1e-3
                    if min_dist < 1e-3
                        recovered_count += 1
                    end
                end
            end
            
            # Store detailed results
            push!(results, (
                degree = degree,
                subdomain = subdomain.label,
                l2_norm = pol.nrm,
                num_crit_pts = length(crit_pts_in_subdomain),
                num_theoretical = length(theoretical_in_subdomain)
            ))
        end
        
        # Store degree-level statistics
        l2_norms_by_degree[degree] = degree_l2_norms
        distances_by_degree[degree] = all_distances
        recovery_by_degree[degree] = recovered_count
        
        # Print summary for this degree
        avg_l2 = mean(degree_l2_norms)
        avg_dist = isempty(all_distances) ? NaN : mean(all_distances)
        total_theoretical = length(theoretical_minimizers)  # Total min+min points
        println(@sprintf("Degree %d: L²-norm = %.2e, Avg distance = %.2e, Recovered = %d/%d",
                degree, avg_l2, avg_dist, recovered_count, total_theoretical))
        
        if verbose
            println("  L²-norm range: [$(minimum(degree_l2_norms)), $(maximum(degree_l2_norms))]")
            if !isempty(all_distances)
                println("  Distance range: [$(minimum(all_distances)), $(maximum(all_distances))]")
            end
        end
    end
    
    # Generate plots
    println("\nGenerating plots...")
    fig = Figure(size=(1200, 400))
    
    # Left: L²-norm convergence
    ax1 = Axis(fig[1, 1],
        title = "L²-norm Convergence",
        xlabel = "Degree",
        ylabel = "Average L²-norm",
        yscale = log10
    )
    
    degrees_vec = sort(collect(keys(l2_norms_by_degree)))
    mean_l2s = [mean(l2_norms_by_degree[d]) for d in degrees_vec]
    
    lines!(ax1, degrees_vec, mean_l2s, linewidth=3, color=:blue)
    scatter!(ax1, degrees_vec, mean_l2s, markersize=12, color=:blue)
    
    # Middle: Distance convergence
    ax2 = Axis(fig[1, 2],
        title = "Distance to Theoretical Minimizers",
        xlabel = "Degree",
        ylabel = "Average Distance",
        yscale = log10
    )
    
    degrees_with_dist = [d for d in degrees_vec if !isempty(distances_by_degree[d])]
    if !isempty(degrees_with_dist)
        mean_dists = [mean(distances_by_degree[d]) for d in degrees_with_dist]
        lines!(ax2, degrees_with_dist, mean_dists, linewidth=3, color=:green)
        scatter!(ax2, degrees_with_dist, mean_dists, markersize=12, color=:green)
        hlines!(ax2, [1e-3], color=:red, linestyle=:dash, linewidth=2)
    end
    
    # Right: Recovery rate
    ax3 = Axis(fig[1, 3],
        title = "Minimizer Recovery",
        xlabel = "Degree",
        ylabel = "Recovered Count",
        limits = (nothing, nothing, 0, 150)
    )
    
    recovery_counts = [recovery_by_degree[d] for d in degrees_vec]
    barplot!(ax3, degrees_vec, recovery_counts, color=:orange, width=0.8)
    hlines!(ax3, [144], color=:red, linestyle=:dash, linewidth=2, label="Total (9×16)")
    axislegend(ax3, position=:lt)
    
    save(joinpath(output_dir, "degree_convergence.png"), fig)
    display(fig)
    
    # Save results
    CSV.write(joinpath(output_dir, "analysis_results.csv"), results)
    
    # Save summary
    summary = DataFrame(
        degree = degrees_vec,
        mean_l2_norm = mean_l2s,
        min_l2_norm = [minimum(l2_norms_by_degree[d]) for d in degrees_vec],
        max_l2_norm = [maximum(l2_norms_by_degree[d]) for d in degrees_vec],
        recovered_minimizers = recovery_counts
    )
    CSV.write(joinpath(output_dir, "summary.csv"), summary)
    
    println("\nResults saved to: ", basename(output_dir))
    
    # Verification check
    if maximum(recovery_counts) < 144
        println("\n⚠️  Warning: Not all theoretical minimizers were recovered.")
        println("   Maximum recovered: $(maximum(recovery_counts))/144")
        println("   This may indicate issues with polynomial degree or grid resolution.")
    else
        println("\n✓ All theoretical minimizers recovered at degree $(degrees_vec[findfirst(==(144), recovery_counts)])")
    end
    
    return results, l2_norms_by_degree, distances_by_degree
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_simplified_analysis(verbose=true)
end