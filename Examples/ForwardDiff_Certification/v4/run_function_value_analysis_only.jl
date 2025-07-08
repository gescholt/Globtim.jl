#!/usr/bin/env julia

# Function value analysis for v4 - Table output only
# Run this from the v4 directory

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using Dates
using DataFrames
using CSV
using Statistics
using LinearAlgebra

println("\n" * "="^80)
println("📊 FUNCTION VALUE ANALYSIS FOR V4 CRITICAL POINTS")
println("="^80)

# Parse command line arguments
degrees = length(ARGS) >= 1 ? parse.(Int, split(ARGS[1], ",")) : [3, 4]
GN = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20

println("\nParameters:")
println("  Degrees: $degrees")
println("  GN: $GN")

# Load required modules
println("\n📚 Loading modules...")

# Core modules
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

include("src/FunctionValueAnalysis.jl")
using .FunctionValueAnalysis

println("✅ Modules loaded")

# Step 1: Load theoretical points
println("\n📊 Loading theoretical points...")
theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
println("   Loaded $(length(theoretical_points)) theoretical points")

# Step 2: Generate subdomains
println("\n📊 Generating subdomains...")
subdomains = SubdomainManagement.generate_16_subdivisions_orthant()

# Step 3: Run analysis to get computed points
println("\n📊 Running analysis to get computed critical points...")
analysis_results = run_enhanced_analysis_with_refinement(
    degrees, GN,
    analyze_global=false,
    threshold=0.1,
    tol_dist=0.05
)

all_critical_points_with_labels = analysis_results.all_critical_points

# Step 4: Function Value Analysis
println("\n" * "="^80)
println("📊 FUNCTION VALUE COMPARISON RESULTS")
println("="^80)

# Collect all comparison tables
all_comparisons = DataFrame()

for degree in degrees
    println("\n🔹 Degree $degree:")
    println("-"^40)
    
    if haskey(all_critical_points_with_labels, degree)
        df_cheb = all_critical_points_with_labels[degree]
        
        degree_comparisons = DataFrame()
        
        for subdomain in subdomains
            subdomain_label = subdomain.label
            
            # Filter points for this subdomain
            subdomain_mask = df_cheb.subdomain .== subdomain_label
            subdomain_cheb = df_cheb[subdomain_mask, :]
            
            # Get theoretical points for this subdomain
            subdomain_theoretical_points = [p for (p, t) in zip(theoretical_points, theoretical_types) 
                if SubdomainManagement.is_point_in_subdomain(p, subdomain)]
            subdomain_theoretical_types = [t for (p, t) in zip(theoretical_points, theoretical_types) 
                if SubdomainManagement.is_point_in_subdomain(p, subdomain)]
            
            if !isempty(subdomain_theoretical_points) && nrow(subdomain_cheb) > 0
                fval_table = create_function_value_comparison_table(
                    subdomain_theoretical_points,
                    subdomain_theoretical_types,
                    subdomain_cheb,
                    deuflhard_4d_composite,
                    degree,
                    subdomain_label
                )
                
                degree_comparisons = vcat(degree_comparisons, fval_table; cols=:union)
            end
        end
        
        if nrow(degree_comparisons) > 0
            # Show summary by point type
            for ptype in unique(degree_comparisons.point_type)
                type_data = degree_comparisons[degree_comparisons.point_type .== ptype, :]
                
                # Calculate overall statistics
                total_theoretical = sum(type_data.n_theoretical)
                total_matched = sum(type_data.n_matched)
                valid_errors = filter(!isnan, type_data.avg_relative_error)
                
                if !isempty(valid_errors)
                    avg_error = mean(valid_errors)
                    max_error = maximum(filter(!isnan, type_data.max_relative_error))
                    
                    println("\n  Point type: $(uppercase(ptype))")
                    println("  Total theoretical points: $total_theoretical")
                    println("  Total matched points: $total_matched")
                    println("  Average relative error: $(round(avg_error * 100, digits=3))%")
                    println("  Maximum relative error: $(round(max_error * 100, digits=3))%")
                end
            end
            
            all_comparisons = vcat(all_comparisons, degree_comparisons; cols=:union)
        end
    end
end

# Step 5: Create summary table
println("\n" * "="^80)
println("📊 SUMMARY TABLE")
println("="^80)

if nrow(all_comparisons) > 0
    summary_df = summarize_function_value_errors(
        Dict("all" => all_comparisons)
    )
    
    # Format the summary table for display
    summary_display = select(summary_df,
        :degree => "Degree",
        :point_type => "Type",
        :total_theoretical => "Theoretical",
        :total_matched => "Matched",
        :avg_relative_error => (x -> round.(x * 100, digits=3)) => "Avg Error %",
        :max_relative_error => (x -> round.(x * 100, digits=3)) => "Max Error %",
        :median_relative_error => (x -> round.(x * 100, digits=3)) => "Median Error %"
    )
    
    println(summary_display)
    
    # Additional analysis: compare minima vs saddle points
    println("\n📊 PERFORMANCE BY POINT TYPE:")
    println("-"^40)
    
    for ptype in unique(summary_df.point_type)
        type_rows = summary_df[summary_df.point_type .== ptype, :]
        if nrow(type_rows) > 0
            avg_across_degrees = mean(type_rows.avg_relative_error)
            println("$(uppercase(ptype)) POINTS: Average error across all degrees = $(round(avg_across_degrees * 100, digits=3))%")
        end
    end
end

println("\n✅ Analysis complete!")