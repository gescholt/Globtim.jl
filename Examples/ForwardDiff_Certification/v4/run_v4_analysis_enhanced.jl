#!/usr/bin/env julia

# V4 Enhanced Analysis: With BFGS Refined Point Collection

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using CSV
using Dates
using DataFrames
using LinearAlgebra

# Load V4 modules
include("src/TheoreticalPointTables.jl")
using .TheoreticalPointTables

include("src/RefinedPointAnalysis.jl")
using .RefinedPointAnalysis

# Load modules from parent directory in correct order
include("../by_degree/src/Common4DDeuflhard.jl")
using .Common4DDeuflhard

include("../by_degree/src/SubdomainManagement.jl")
using .SubdomainManagement

include("../by_degree/src/TheoreticalPoints.jl")
using .TheoreticalPoints: load_theoretical_4d_points_orthant

# Include enhanced analysis with refinement
include("src/run_analysis_with_refinement.jl")
using .Main: run_enhanced_analysis_with_refinement

# Include enhanced V4 plotting module
include("src/V4PlottingEnhanced.jl")
using .V4PlottingEnhanced

"""
    run_v4_analysis_enhanced(degrees, GN; kwargs...)

Run enhanced V4 analysis with BFGS refined point collection and additional plots.

# Arguments
- `degrees`: Vector of polynomial degrees to analyze
- `GN`: Grid resolution parameter

# Keyword Arguments
- `output_dir`: Directory to save outputs (default: auto-generated)
- `plot_results`: Whether to generate plots (default: false)
- `compute_refined_points`: Whether to collect df_min_refined (default: true)
- `tol_dist`: Distance tolerance for analyze_critical_points (default: 0.05)
"""
function run_v4_analysis_enhanced(degrees=[3,4], GN=20; 
                                output_dir=nothing, 
                                plot_results=false,
                                compute_refined_points=true,
                                tol_dist=0.05)
    
    println("\n" * "="^80)
    println("🚀 V4 ENHANCED ANALYSIS: With BFGS Refined Points")
    println("="^80)
    
    # Step 1: Load theoretical points
    println("\n📊 Loading theoretical points...")
    theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
    println("   Loaded $(length(theoretical_points)) theoretical points")
    
    # Separate theoretical minima for refined analysis
    theoretical_minima = [p for (p, t) in zip(theoretical_points, theoretical_types) if t == "min"]
    println("   Including $(length(theoretical_minima)) theoretical minima")
    
    # Step 2: Generate subdomains
    println("\n📊 Generating subdomains...")
    subdomains = SubdomainManagement.generate_16_subdivisions_orthant()
    println("   Generated $(length(subdomains)) subdomains")
    
    # Step 3: Run enhanced analysis with refinement
    println("\n📊 Running enhanced degree analysis...")
    if compute_refined_points
        analysis_results = run_enhanced_analysis_with_refinement(
            degrees, GN, 
            analyze_global=false, 
            threshold=0.1,
            tol_dist=tol_dist
        )
        
        l2_data = analysis_results.l2_data
        distance_data = analysis_results.distance_data
        subdomain_distance_data = analysis_results.subdomain_distance_data
        all_critical_points_with_labels = analysis_results.all_critical_points
        all_refined_points = analysis_results.all_refined_points
        all_min_refined_points = analysis_results.all_min_refined_points
    else
        # Fall back to standard analysis
        include("src/run_analysis_no_plots.jl")
        using .Main: run_enhanced_analysis_v2
        
        l2_data, distance_data, subdomain_distance_data, all_critical_points_with_labels = 
            run_enhanced_analysis_v2(degrees, GN, analyze_global=false, threshold=0.1)
        all_refined_points = Dict{Int, DataFrame}()
        all_min_refined_points = Dict{Int, DataFrame}()
    end
    
    # Step 4: Generate V4 tables (standard)
    println("\n📊 Generating V4 theoretical point tables...")
    subdomain_tables_v4 = generate_theoretical_point_tables(
        theoretical_points,
        theoretical_types,
        all_critical_points_with_labels,
        degrees,
        subdomains,
        SubdomainManagement.is_point_in_subdomain
    )
    
    # Step 5: Generate refined point analysis tables
    refined_distance_tables = Dict{String, DataFrame}()
    refinement_metrics_by_degree = Dict{Int, Any}()
    minima_to_refined_by_degree = Dict{Int, Dict{String, Vector{Float64}}}()
    refined_to_cheb_distances = Dict{Int, Vector{Float64}}()
    
    if compute_refined_points
        println("\n📊 Analyzing refined points...")
        
        for degree in degrees
            # Initialize storage for this degree
            minima_to_refined_by_degree[degree] = Dict{String, Vector{Float64}}()
            all_refined_to_cheb = Float64[]
            
            # Get data for this degree
            df_cheb = all_critical_points_with_labels[degree]
            df_min_refined = all_min_refined_points[degree]
            
            # Process each subdomain
            for subdomain in subdomains
                # Filter points for this subdomain
                cheb_mask = df_cheb.subdomain .== subdomain.label
                refined_mask = df_min_refined.subdomain .== subdomain.label
                
                subdomain_cheb = df_cheb[cheb_mask, :]
                subdomain_refined = df_min_refined[refined_mask, :]
                
                if nrow(subdomain_refined) > 0 && nrow(subdomain_cheb) > 0
                    # Create refined distance table
                    refined_table = create_refined_distance_table(
                        subdomain_refined, subdomain_cheb, subdomain.label, degree
                    )
                    
                    # Store or update table
                    key = "$(subdomain.label)_refined"
                    if haskey(refined_distance_tables, key)
                        # Merge with existing table
                        existing = refined_distance_tables[key]
                        for row in eachrow(refined_table)
                            push!(existing, row)
                        end
                    else
                        refined_distance_tables[key] = refined_table
                    end
                    
                    # Collect refined to cheb distances
                    append!(all_refined_to_cheb, refined_table[!, Symbol("d$degree")])
                end
                
                # Calculate distances from theoretical minima to refined points
                subdomain_theoretical_minima = [p for (p, t, s) in 
                    zip(theoretical_points, theoretical_types, 
                        [SubdomainManagement.is_point_in_subdomain(p, subdomain) 
                         for p in theoretical_points])
                    if t == "min" && s]
                
                if !isempty(subdomain_theoretical_minima) && nrow(subdomain_refined) > 0
                    refined_points = [[row.x1, row.x2, row.x3, row.x4] 
                                    for row in eachrow(subdomain_refined)]
                    
                    distances = Float64[]
                    for theo_min in subdomain_theoretical_minima
                        min_dist = minimum(norm(theo_min - rp) for rp in refined_points)
                        push!(distances, min_dist)
                    end
                    
                    minima_to_refined_by_degree[degree][subdomain.label] = distances
                end
            end
            
            # Store all refined to cheb distances for this degree
            refined_to_cheb_distances[degree] = all_refined_to_cheb
            
            # Calculate refinement metrics for this degree
            metrics = calculate_refinement_metrics(
                theoretical_minima, df_cheb, df_min_refined, degree
            )
            
            refinement_metrics_by_degree[degree] = (
                n_computed = nrow(df_cheb),
                n_refined = nrow(df_min_refined),
                avg_theo_to_cheb = metrics.avg_theo_to_cheb,
                avg_theo_to_refined = metrics.avg_theo_to_refined,
                avg_refined_to_cheb = mean(filter(isfinite, all_refined_to_cheb)),
                avg_improvement = metrics.avg_improvement
            )
            
            println("   Degree $degree: $(nrow(df_min_refined)) refined points, " *
                   "avg improvement $(round(metrics.avg_improvement*100, digits=1))%")
        end
    end
    
    # Display summary
    println("\n📊 Summary of V4 tables:")
    for (label, table) in sort(collect(subdomain_tables_v4), by=x->x[1])
        n_points = nrow(table) - 1  # Exclude AVERAGE row
        avg_row = table[end, :]
        
        print("   $label: $n_points theoretical points")
        
        # Show average distances
        avg_dists = []
        for d in degrees
            col = Symbol("d$d")
            if hasproperty(avg_row, col) && !isnan(avg_row[col])
                push!(avg_dists, "d$d=$(round(avg_row[col], digits=4))")
            end
        end
        
        if !isempty(avg_dists)
            println(" | Avg: $(join(avg_dists, ", "))")
        else
            println(" | No valid distances")
        end
    end
    
    # Save tables if output directory specified
    if output_dir !== nothing
        mkpath(output_dir)
        
        # Save standard V4 tables
        for (label, table) in subdomain_tables_v4
            filename = joinpath(output_dir, "subdomain_$(label)_v4.csv")
            CSV.write(filename, table)
        end
        
        # Save refined distance tables
        if compute_refined_points
            for (label, table) in refined_distance_tables
                filename = joinpath(output_dir, "$(label)_distances.csv")
                CSV.write(filename, table)
            end
            
            # Save refinement summary
            summary = create_refinement_summary(refinement_metrics_by_degree, degrees)
            CSV.write(joinpath(output_dir, "refinement_summary.csv"), summary)
        end
        
        println("\n✅ Tables saved to: $output_dir")
    end
    
    # Create plots if requested
    if plot_results
        println("\n📊 Creating enhanced V4 plots...")
        
        # Ensure output directory exists for plots
        if output_dir === nothing
            output_dir = joinpath(@__DIR__, "outputs", "v4_enhanced_$(Dates.format(Dates.now(), "HH-MM"))")
            mkpath(output_dir)
        end
        
        # Prepare data for plotting
        plot_data = Dict(
            "subdomain_tables" => subdomain_tables_v4,
            "degrees" => degrees,
            "l2_data" => l2_data,
            "distance_data" => distance_data,
            "subdomain_distance_data" => subdomain_distance_data
        )
        
        if compute_refined_points
            # Calculate refined distance data for plotting
            refined_distance_data = Dict{Int, Vector{Float64}}()
            for degree in degrees
                refined_distance_data[degree] = refined_to_cheb_distances[degree]
            end
            
            plot_data["refined_distance_data"] = refined_distance_data
            plot_data["minima_to_refined_distances"] = minima_to_refined_by_degree
            plot_data["refinement_metrics"] = refinement_metrics_by_degree
            plot_data["refined_to_cheb_distances"] = refined_to_cheb_distances
        end
        
        # Create all plots
        plots = create_all_v4_plots(
            plot_data,
            output_dir = output_dir,
            plot_config = Dict("threshold" => 0.1)
        )
        
        println("\n✅ Plots saved to: $output_dir")
    end
    
    return (
        subdomain_tables = subdomain_tables_v4,
        refined_distance_tables = refined_distance_tables,
        refinement_metrics = refinement_metrics_by_degree,
        all_critical_points = all_critical_points_with_labels,
        all_min_refined_points = all_min_refined_points
    )
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    results = run_v4_analysis_enhanced([3,4], 20, plot_results=true)
    
    # Show sample refined metrics
    if haskey(results.refinement_metrics, 4)
        println("\n📊 Refinement metrics for degree 4:")
        metrics = results.refinement_metrics[4]
        println("   Points: $(metrics.n_computed) → $(metrics.n_refined) (refined)")
        println("   Avg distance improvement: $(round(metrics.avg_improvement*100, digits=1))%")
    end
end