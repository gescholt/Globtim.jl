#!/usr/bin/env julia

# Function-based V4 analysis for interactive use with Revise
# This wraps the main run_v4_analysis.jl logic in a function

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

# Load all required modules first
include("src/TheoreticalPointTables.jl")
using .TheoreticalPointTables

include("../by_degree/src/Common4DDeuflhard.jl")
using .Common4DDeuflhard

include("../by_degree/src/SubdomainManagement.jl")
using .SubdomainManagement

include("../by_degree/src/TheoreticalPoints.jl")
using .TheoreticalPoints: load_theoretical_4d_points_orthant

include("src/run_analysis_with_refinement.jl")
using .Main: run_enhanced_analysis_with_refinement

include("src/RefinedPointAnalysis.jl")
using .RefinedPointAnalysis

include("src/V4PlottingEnhanced.jl")
using .V4PlottingEnhanced

using CSV, DataFrames, Dates, Statistics, LinearAlgebra

"""
    run_v4_enhanced(; degrees=[3,4], GN=20, output_dir=nothing)

Run enhanced V4 analysis with custom parameters.

# Keyword Arguments
- `degrees`: Vector of polynomial degrees (default: [3,4])
- `GN`: Grid resolution (default: 20)
- `output_dir`: Output directory (auto-generated if nothing)

# Returns
Named tuple with:
- `subdomain_tables`: V4 tables for each subdomain
- `refinement_metrics`: BFGS refinement effectiveness metrics
- `all_min_refined_points`: Refined points by degree

# Examples
```julia
# Default run
results = run_v4_enhanced()

# Higher degrees
results = run_v4_enhanced(degrees=[3,4,5,6], GN=30)

# Custom output
results = run_v4_enhanced(degrees=[3,4,5,6,7,8], GN=40, output_dir="outputs/high_degree")
```
"""
function run_v4_enhanced(; degrees=[3,4], GN=20, output_dir=nothing)
    
    # Set output directory
    if output_dir === nothing
        output_dir = "outputs/enhanced_$(Dates.format(Dates.now(), "HH-MM"))"
    end
    
    println("\n" * "="^80)
    println("🚀 ENHANCED V4 ANALYSIS WITH REFINED POINTS")
    println("="^80)
    println("\nParameters:")
    println("  Degrees: $degrees")
    println("  GN: $GN")
    println("  Output: $output_dir")
    
    # Create output directory
    mkpath(output_dir)
    
    # Step 1: Load theoretical points
    println("\n📊 Loading theoretical points...")
    theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
    println("   Loaded $(length(theoretical_points)) theoretical points")
    
    # Step 2: Generate subdomains
    println("\n📊 Generating subdomains...")
    subdomains = SubdomainManagement.generate_16_subdivisions_orthant()
    println("   Generated $(length(subdomains)) subdomains")
    
    # Step 3: Run enhanced analysis with refinement
    println("\n📊 Running enhanced analysis with BFGS refinement...")
    println("   This may take a few minutes...")
    
    analysis_results = run_enhanced_analysis_with_refinement(
        degrees, GN,
        analyze_global=false,
        threshold=0.1,
        tol_dist=0.05
    )
    
    # Unpack results
    l2_data = analysis_results.l2_data
    distance_data = analysis_results.distance_data
    subdomain_distance_data = analysis_results.subdomain_distance_data
    all_critical_points_with_labels = analysis_results.all_critical_points
    all_min_refined_points = analysis_results.all_min_refined_points
    
    # Step 4: Generate V4 tables
    println("\n📊 Generating V4 theoretical point tables...")
    subdomain_tables_v4 = generate_theoretical_point_tables(
        theoretical_points,
        theoretical_types,
        all_critical_points_with_labels,
        degrees,
        subdomains,
        SubdomainManagement.is_point_in_subdomain
    )
    
    # Step 5: Analyze refined points
    println("\n📊 Analyzing refined points...")
    refinement_metrics = Dict{Int, Any}()
    refined_tables = Dict{String, DataFrame}()
    refined_to_cheb_distances = Dict{Int, Vector{Float64}}()
    
    for degree in degrees
        if haskey(all_critical_points_with_labels, degree) && haskey(all_min_refined_points, degree)
            df_cheb = all_critical_points_with_labels[degree]
            df_min_refined = all_min_refined_points[degree]
            
            all_refined_to_cheb = Float64[]
            
            for subdomain in subdomains
                subdomain_label = subdomain.label
                
                cheb_mask = df_cheb.subdomain .== subdomain_label
                refined_mask = df_min_refined.subdomain .== subdomain_label
                
                subdomain_cheb = df_cheb[cheb_mask, :]
                subdomain_refined = df_min_refined[refined_mask, :]
                
                if nrow(subdomain_refined) > 0 && nrow(subdomain_cheb) > 0
                    refined_table = RefinedPointAnalysis.create_refined_distance_table(
                        subdomain_refined,
                        subdomain_cheb,
                        subdomain_label,
                        degree
                    )
                    
                    refined_tables["$(subdomain_label)_d$(degree)"] = refined_table
                    append!(all_refined_to_cheb, refined_table[!, Symbol("d$degree")])
                end
            end
            
            refined_to_cheb_distances[degree] = all_refined_to_cheb
            
            # Extract theoretical minima
            theoretical_minima = [p for (p, t) in zip(theoretical_points, theoretical_types) if t == "min"]
            
            metrics = RefinedPointAnalysis.calculate_refinement_metrics(
                theoretical_minima, df_cheb, df_min_refined, degree
            )
            refinement_metrics[degree] = metrics
        end
    end
    
    # Step 6: Save results
    println("\n💾 Saving results...")
    
    # Save V4 tables
    for (label, table) in subdomain_tables_v4
        CSV.write(joinpath(output_dir, "subdomain_$(label)_v4.csv"), table)
    end
    
    # Create refinement summary
    refinement_summary = DataFrame(
        degree = Int[],
        total_computed = Int[],
        total_refined = Int[],
        avg_improvement = Float64[]
    )
    
    for degree in sort(collect(keys(refinement_metrics)))
        if haskey(all_critical_points_with_labels, degree) && haskey(all_min_refined_points, degree)
            metrics = refinement_metrics[degree]
            df_cheb = all_critical_points_with_labels[degree]
            df_min_refined = all_min_refined_points[degree]
            
            push!(refinement_summary, (
                degree = degree,
                total_computed = nrow(df_cheb),
                total_refined = nrow(df_min_refined),
                avg_improvement = metrics.avg_improvement
            ))
        end
    end
    
    CSV.write(joinpath(output_dir, "refinement_summary.csv"), refinement_summary)
    
    # Step 7: Generate plots
    println("\n🎨 Generating enhanced plots...")
    
    # Prepare data for plotting
    plot_data = Dict(
        "subdomain_tables" => subdomain_tables_v4,
        "degrees" => degrees,
        "l2_data" => l2_data,
        "distance_data" => distance_data,
        "subdomain_distance_data" => subdomain_distance_data,
        "all_min_refined_points" => all_min_refined_points,
        "refinement_metrics" => refinement_summary,
        "refined_to_cheb_distances" => refined_to_cheb_distances
    )
    
    # Generate all plots
    V4PlottingEnhanced.create_all_v4_plots(plot_data, output_dir=output_dir)
    
    println("\n" * "="^80)
    println("✅ ENHANCED V4 ANALYSIS COMPLETE!")
    println("="^80)
    println("\nResults saved to: $output_dir/")
    println("\nFiles generated:")
    println("  - subdomain_*_v4.csv : V4 theoretical point tables")
    println("  - refinement_summary.csv : BFGS refinement effectiveness")
    println("  - v4_*.png : Standard and enhanced visualization plots")
    
    # Return results
    return (
        subdomain_tables = subdomain_tables_v4,
        refinement_metrics = refinement_summary,
        all_min_refined_points = all_min_refined_points
    )
end

# Print usage information
println("\n✅ V4 Enhanced Analysis Function Loaded!")
println("\nUsage:")
println("  results = run_v4_enhanced()                    # Default: degrees [3,4], GN=20")
println("  results = run_v4_enhanced(degrees=[3,4,5,6])   # Custom degrees")
println("  results = run_v4_enhanced(degrees=[3,4,5,6,7,8], GN=40)  # Higher degrees & resolution")
println("\nThe function returns:")
println("  - results.subdomain_tables   # V4 tables by subdomain")
println("  - results.refinement_metrics # BFGS refinement summary")
println("  - results.all_min_refined_points # Refined points by degree")