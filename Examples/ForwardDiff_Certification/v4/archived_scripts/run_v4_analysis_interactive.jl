#!/usr/bin/env julia

# Interactive V4 analysis script for use with Revise
# This version defines a function that can be called multiple times

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using Dates
using DataFrames
using CSV
using Statistics
using LinearAlgebra
using Globtim
using DynamicPolynomials
using CairoMakie

# Load V4 modules
include("src/TheoreticalPointTables.jl")
using .TheoreticalPointTables

# Load from parent by_degree directory
include("../by_degree/src/Common4DDeuflhard.jl")
using .Common4DDeuflhard

include("../by_degree/src/SubdomainManagement.jl")
using .SubdomainManagement

include("../by_degree/src/TheoreticalPoints.jl")
using .TheoreticalPoints: load_theoretical_4d_points_orthant

# Analysis modules
include("src/run_analysis_with_refinement.jl")
using .Main: run_enhanced_analysis_with_refinement

# Load local modules
include("src/RefinedPointAnalysis.jl")
using .RefinedPointAnalysis

include("src/V4PlottingEnhanced.jl")
using .V4PlottingEnhanced

"""
    run_enhanced_v4_analysis(degrees=[3,4], GN=20; output_dir=nothing, verbose=true)

Run enhanced V4 analysis with custom parameters.

# Arguments
- `degrees`: Vector of polynomial degrees to analyze
- `GN`: Grid resolution
- `output_dir`: Output directory (auto-generated if nothing)
- `verbose`: Print progress messages
"""
function run_enhanced_v4_analysis(degrees::Vector{Int}=[3,4], GN::Int=20; 
                                  output_dir=nothing, verbose=true)
    
    # Set output directory
    if output_dir === nothing
        output_dir = "outputs/enhanced_$(Dates.format(Dates.now(), "HH-MM"))"
    end
    
    if verbose
        println("\n" * "="^80)
        println("🚀 ENHANCED V4 ANALYSIS WITH REFINED POINTS")
        println("="^80)
        println("\nParameters:")
        println("  Degrees: $degrees")
        println("  GN: $GN")
        println("  Output: $output_dir")
    end
    
    # Create output directory
    mkpath(output_dir)
    
    # Step 1: Load theoretical critical points
    verbose && println("\n📌 Step 1: Loading theoretical critical points...")
    all_theoretical_points = get_all_theoretical_critical_points()
    verbose && println("   ✓ Found $(length(all_theoretical_points)) theoretical critical points")
    
    # Step 2: Define subdomains
    verbose && println("\n📊 Step 2: Defining subdomains...")
    subdomains = get_standard_subdomains()
    verbose && println("   ✓ Created $(length(subdomains)) subdomains")
    
    # Step 3: Initialize V4 tables
    verbose && println("\n📋 Step 3: Initializing V4 tables...")
    subdomain_tables_v4 = Dict{String, DataFrame}()
    
    # Step 4: Process each degree
    all_results = Dict{Int, SubdomainResults}()
    all_min_refined_points = Dict{Int, Vector{Vector{Float64}}}()
    
    for degree in degrees
        verbose && println("\n" * "-"^60)
        verbose && println("🔍 Processing degree $degree...")
        
        results = analyze_subdomain_critical_points(
            Globtim.deuflhard_4d_composite,
            subdomains,
            degree,
            GN;
            verbose=false,
            return_full_results=true
        )
        all_results[degree] = results
    end
    
    # Step 5: Populate V4 tables with distances and collect refined points
    verbose && println("\n📈 Step 5: Populating V4 tables and collecting refined points...")
    
    # Initialize collection for refined to cheb distances
    refined_to_cheb_distances = Dict{Int, Vector{Float64}}()
    
    for (label, subdomain) in subdomains
        verbose && println("\n   Processing subdomain $label...")
        
        # Create table for this subdomain
        table = TheoreticalPointTables.create_theoretical_point_table(degrees)
        
        # Get theoretical points in this subdomain
        theoretical_in_subdomain = TheoreticalPointTables.filter_points_in_subdomain(
            all_theoretical_points, subdomain
        )
        
        # Populate table with theoretical points
        table = TheoreticalPointTables.add_theoretical_points!(
            table, theoretical_in_subdomain
        )
        
        # Add distances for each degree
        for degree in degrees
            verbose && println("     - Degree $degree")
            
            # Get computed points for this subdomain
            if haskey(all_results[degree].subdomain_dataframes, label)
                df_cheb = all_results[degree].subdomain_dataframes[label]
                
                # Calculate distances
                table = TheoreticalPointTables.populate_distances_for_subdomain(
                    table, theoretical_in_subdomain, df_cheb, degree
                )
                
                # Collect min_refined points if available
                if haskey(all_results[degree].analysis_results, label)
                    analysis = all_results[degree].analysis_results[label]
                    if !isempty(analysis.min_refined_points)
                        if !haskey(all_min_refined_points, degree)
                            all_min_refined_points[degree] = Vector{Vector{Float64}}()
                        end
                        append!(all_min_refined_points[degree], analysis.min_refined_points)
                    end
                end
                
                # Calculate refined to cheb distances
                if haskey(all_results[degree].analysis_results, label)
                    analysis = all_results[degree].analysis_results[label]
                    if !isempty(analysis.min_refined_points)
                        # Create refined distance table
                        refined_table = RefinedPointAnalysis.create_refined_distance_table(
                            analysis.min_refined_points,
                            df_cheb,
                            theoretical_in_subdomain,
                            degree
                        )
                        
                        # Initialize collection for this degree if needed
                        if !haskey(refined_to_cheb_distances, degree)
                            refined_to_cheb_distances[degree] = Float64[]
                        end
                        
                        # Collect refined to cheb distances
                        append!(refined_to_cheb_distances[degree], refined_table[!, Symbol("d$degree")])
                    end
                end
            end
        end
        
        # Add summary row
        table = TheoreticalPointTables.add_summary_row(table, degrees)
        
        # Save table
        subdomain_tables_v4[label] = table
        CSV.write(joinpath(output_dir, "subdomain_$(label)_v4.csv"), table)
    end
    
    # Step 6: Calculate refinement metrics
    verbose && println("\n📊 Step 6: Calculating refinement metrics...")
    refinement_metrics = DataFrame(degree = Int[], 
                                   total_computed = Int[], 
                                   total_refined = Int[],
                                   avg_improvement = Float64[])
    
    for degree in degrees
        total_computed = sum(nrow(df) for df in values(all_results[degree].subdomain_dataframes))
        total_refined = haskey(all_min_refined_points, degree) ? length(all_min_refined_points[degree]) : 0
        
        # Calculate average improvement
        avg_improvement = 0.0
        if total_refined > 0 && haskey(refined_to_cheb_distances, degree)
            avg_improvement = mean(refined_to_cheb_distances[degree])
        end
        
        push!(refinement_metrics, (degree=degree, 
                                   total_computed=total_computed,
                                   total_refined=total_refined, 
                                   avg_improvement=avg_improvement))
    end
    
    # Save metrics
    CSV.write(joinpath(output_dir, "refinement_summary.csv"), refinement_metrics)
    
    # Step 7: Generate plots
    verbose && println("\n🎨 Step 7: Generating enhanced plots...")
    
    # Prepare data for plotting
    plot_data = Dict(
        :subdomain_tables => subdomain_tables_v4,
        :degrees => degrees,
        :all_results => all_results,
        :all_min_refined_points => all_min_refined_points,
        :refinement_metrics => refinement_metrics,
        :refined_to_cheb_distances => refined_to_cheb_distances,
        :output_dir => output_dir
    )
    
    # Generate all plots
    V4PlottingEnhanced.create_all_v4_plots(plot_data)
    
    # Final summary
    verbose && println("\n" * "="^80)
    verbose && println("✅ ENHANCED V4 ANALYSIS COMPLETE!")
    verbose && println("="^80)
    verbose && println("\nResults saved to: $output_dir/")
    verbose && println("\nFiles generated:")
    verbose && println("  - subdomain_*_v4.csv : V4 theoretical point tables")
    verbose && println("  - refinement_summary.csv : BFGS refinement effectiveness")
    verbose && println("  - v4_*.png : Standard and enhanced visualization plots")
    
    # Return results
    return (
        subdomain_tables = subdomain_tables_v4,
        refinement_metrics = refinement_metrics,
        all_min_refined_points = all_min_refined_points
    )
end

# Export the function for easy access
export run_enhanced_v4_analysis

println("\n✅ Interactive V4 analysis loaded!")
println("\nUsage examples:")
println("  results = run_enhanced_v4_analysis([3,4], 20)")
println("  results = run_enhanced_v4_analysis([3,4,5,6], 30)")
println("  results = run_enhanced_v4_analysis([3,4,5,6,7,8], 40, output_dir=\"outputs/high_degree\")")