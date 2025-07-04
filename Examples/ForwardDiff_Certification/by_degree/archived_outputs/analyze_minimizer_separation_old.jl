using Pkg; using Revise
Pkg.activate(joinpath(@__DIR__, "../../../"))
using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames
using Statistics
using Dates
using CairoMakie
using CSV
CairoMakie.activate!()

# Function definition
function deuflhard_4d_composite(x::Vector{T}) where T
    x1, x2, x3, x4 = x
    term1 = exp(5*(x1 - 0.2*x2^2 - x3^3 - x4^2))
    term2 = exp(5*(-x1 + 0.2*x2^2 + x3^3 - x4^2))
    term3 = exp(x2^2 + x3^2 + x4^2)
    return term1 + term2 + term3
end

# Known theoretical minimizers (9 in total)
function get_theoretical_minimizers()
    return [
        [0.0, 0.0, 0.0, 0.0],          # Central minimizer
        [0.0, -1.0, 0.0, 0.0],         # Face centers (±1 in one coordinate)
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, -1.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, -1.0],
        [0.0, 0.0, 0.0, 1.0],
        [-1.0, 0.0, 0.0, 0.0],
        [1.0, 0.0, 0.0, 0.0]
    ]
end

# Generate 16 subdomain centers (2x2x2x2 grid)
function generate_subdomain_centers()
    centers = Vector{Vector{Float64}}()
    for i1 in [-0.5, 0.5], i2 in [-0.5, 0.5], i3 in [-0.5, 0.5], i4 in [-0.5, 0.5]
        push!(centers, [i1, i2, i3, i4])
    end
    return centers
end

# Compute critical points for a single subdomain
function compute_critical_points_for_subdomain(center, degree)
    TR = test_input(deuflhard_4d_composite, dim=4, center=center, 
                   sample_range=0.5, tolerance=0.0007)
    pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
    
    @polyvar x[1:4]
    actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree
    try
        crit_pts = solve_polynomial_system(x, 4, actual_degree, pol.coeffs)
        return crit_pts
    catch e
        println("Error for degree $degree at center $center: $e")
        return Vector{Float64}[]
    end
end

# Collect all critical points from all subdomains for a given degree
function collect_all_critical_points(degree)
    centers = generate_subdomain_centers()
    all_points = Vector{Vector{Float64}}()
    
    for (idx, center) in enumerate(centers)
        println("Processing subdomain $idx/16 for degree $degree...")
        points = compute_critical_points_for_subdomain(center, degree)
        append!(all_points, points)
    end
    
    return all_points
end

# Compute minimum distance from a point to a set of points
function min_distance_to_set(point, point_set)
    if isempty(point_set)
        return Inf
    end
    return minimum(norm(point - p) for p in point_set)
end

# Analyze separation distances for all minimizers
function analyze_minimizer_separation(degrees)
    minimizers = get_theoretical_minimizers()
    results = DataFrame()
    
    for degree in degrees
        println("\n=== Processing degree $degree ===")
        
        # Collect all critical points
        all_critical_points = collect_all_critical_points(degree)
        println("Total critical points collected: $(length(all_critical_points))")
        
        # For each minimizer, find max distance to nearest critical point
        max_distances = Float64[]
        for (i, minimizer) in enumerate(minimizers)
            dist = min_distance_to_set(minimizer, all_critical_points)
            push!(max_distances, dist)
            println("Minimizer $i: max distance = $dist")
        end
        
        # Compute statistics
        avg_distance = mean(max_distances)
        min_distance = minimum(max_distances)
        max_distance = maximum(max_distances)
        std_distance = std(max_distances)
        
        push!(results, (
            degree = degree,
            avg_separation = avg_distance,
            min_separation = min_distance,
            max_separation = max_distance,
            std_separation = std_distance,
            num_critical_points = length(all_critical_points)
        ))
    end
    
    return results
end

# Create visualization
function plot_minimizer_separation(results)
    fig = Figure(resolution=(1200, 800))
    
    # Plot 1: Average separation distance
    ax1 = Axis(fig[1, 1], 
        xlabel="Polynomial Degree",
        ylabel="Average Separation Distance",
        title="Average Distance from Minimizers to Nearest Critical Points",
        yscale=log10
    )
    
    lines!(ax1, results.degree, results.avg_separation, 
           linewidth=3, color=:blue, marker=:circle, markersize=12,
           label="Average")
    
    # Add error bars
    errorbars!(ax1, results.degree, results.avg_separation, 
               results.std_separation, color=:blue, whiskerwidth=10)
    
    # Plot 2: Min/Max separation
    ax2 = Axis(fig[1, 2],
        xlabel="Polynomial Degree",
        ylabel="Separation Distance",
        title="Min/Max Separation Distances",
        yscale=log10
    )
    
    lines!(ax2, results.degree, results.min_separation,
           linewidth=2, color=:red, marker=:square, markersize=10,
           label="Minimum")
    lines!(ax2, results.degree, results.max_separation,
           linewidth=2, color=:green, marker=:diamond, markersize=10,
           label="Maximum")
    
    axislegend(ax2, position=:rt)
    
    # Plot 3: Number of critical points
    ax3 = Axis(fig[2, 1:2],
        xlabel="Polynomial Degree",
        ylabel="Number of Critical Points",
        title="Total Critical Points Across All 16 Subdomains"
    )
    
    lines!(ax3, results.degree, results.num_critical_points,
           linewidth=3, color=:purple, marker=:hexagon, markersize=12)
    
    # Save results to CSV
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    output_dir = joinpath(@__DIR__, "outputs")
    mkpath(output_dir)
    
    CSV.write(joinpath(output_dir, "minimizer_separation_analysis_$timestamp.csv"), results)
    
    # Display and save plot
    display(fig)
    save(joinpath(output_dir, "minimizer_separation_analysis_$timestamp.png"), fig)
    
    return fig
end

# Main execution
function main()
    degrees = 4:2:16  # Even degrees from 4 to 16
    
    println("Starting minimizer separation analysis...")
    println("Analyzing $(length(degrees)) polynomial degrees")
    println("Processing 16 subdomains per degree")
    
    results = analyze_minimizer_separation(degrees)
    
    println("\n=== Summary Results ===")
    println(results)
    
    plot_minimizer_separation(results)
    
    return results
end

# Run the analysis
results = main()