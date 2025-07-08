#!/usr/bin/env julia

# V4 Analysis: Theoretical Point-Centric Tables

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using CSV  # Load at top level
using Dates  # For timestamp generation

# Load V4 modules
include("src/TheoreticalPointTables.jl")
using .TheoreticalPointTables

# Load modules from parent directory in correct order
# Common4DDeuflhard must be loaded before TheoreticalPoints
include("../by_degree/src/Common4DDeuflhard.jl")
using .Common4DDeuflhard

include("../by_degree/src/SubdomainManagement.jl")
using .SubdomainManagement

include("../by_degree/src/TheoreticalPoints.jl")
using .TheoreticalPoints: load_theoretical_4d_points_orthant

# Instead of loading the full v3 analysis with plotting, we'll create a minimal version
# that just runs the analysis without plotting

# Include necessary analysis functions
include("src/run_analysis_no_plots.jl")
using .Main: run_enhanced_analysis_v2

# Include V4 plotting module if requested
include("src/V4Plotting.jl")
using .V4Plotting

# Run analysis
function run_v4_analysis(degrees=[3,4], GN=20; output_dir=nothing, plot_results=false, enhanced=false, tol_dist=0.05)
    # If enhanced mode requested, use the enhanced version
    if enhanced
        include(joinpath(@__DIR__, "run_v4_analysis_enhanced.jl"))
        return run_v4_analysis_enhanced(degrees, GN, 
                                      output_dir=output_dir, 
                                      plot_results=plot_results,
                                      compute_refined_points=true,
                                      tol_dist=tol_dist)
    end
    
    println("\n" * "="^80)
    println("🚀 V4 ANALYSIS: Theoretical Point-Centric Tables")
    println("="^80)
    
    # Step 1: Load theoretical points
    println("\n📊 Loading theoretical points...")
    theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
    println("   Loaded $(length(theoretical_points)) theoretical points")
    
    # Step 2: Generate subdomains
    println("\n📊 Generating subdomains...")
    subdomains = SubdomainManagement.generate_16_subdivisions_orthant()
    println("   Generated $(length(subdomains)) subdomains")
    
    # Step 3: Run existing analysis to get computed points
    println("\n📊 Running degree analysis...")
    l2_data, distance_data, subdomain_distance_data, all_critical_points_with_labels = run_enhanced_analysis_v2(
        degrees, GN, 
        analyze_global=false, 
        threshold=0.1
    )
    
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
    
    println("   Generated tables for $(length(subdomain_tables_v4)) subdomains")
    
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
            if !isnan(avg_row[col])
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
        
        for (label, table) in subdomain_tables_v4
            filename = joinpath(output_dir, "subdomain_$(label)_v4.csv")
            CSV.write(filename, table)
        end
        
        println("\n✅ Tables saved to: $output_dir")
    end
    
    # Step 5: Create plots if requested
    if plot_results
        println("\n📊 Creating V4 plots...")
        
        # Ensure output directory exists for plots
        if output_dir === nothing
            output_dir = joinpath(@__DIR__, "outputs", "v4_$(Dates.format(Dates.now(), "HH-MM"))")
            mkpath(output_dir)
        end
        
        # Create all plots
        plots = create_v4_plots(
            subdomain_tables_v4,
            degrees,
            l2_data,
            distance_data,
            subdomain_distance_data = subdomain_distance_data,
            output_dir = output_dir,
            plot_config = Dict("threshold" => 0.1)
        )
        
        println("\n✅ Plots saved to: $output_dir")
    end
    
    return subdomain_tables_v4
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    subdomain_tables = run_v4_analysis([3,4], 20)
    
    # Show sample table
    println("\n📊 Sample table (subdomain 0000):")
    if haskey(subdomain_tables, "0000")
        show(subdomain_tables["0000"], allrows=false, allcols=true)
    end
end