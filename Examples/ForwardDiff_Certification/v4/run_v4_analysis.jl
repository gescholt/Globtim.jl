#!/usr/bin/env julia

# Clean enhanced V4 analysis script
# Run this from the v4 directory

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using Dates

println("\n" * "="^80)
println("🚀 ENHANCED V4 ANALYSIS WITH REFINED POINTS")
println("="^80)

# Parse command line arguments if provided
degrees = length(ARGS) >= 1 ? parse.(Int, split(ARGS[1], ",")) : [3, 4]
GN = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20
output_dir = length(ARGS) >= 3 ? ARGS[3] : "outputs/enhanced_$(Dates.format(Dates.now(), "HH-MM"))"

println("\nParameters:")
println("  Degrees: $degrees")
println("  GN: $GN")
println("  Output: $output_dir")

# Load all required modules first
println("\n📚 Loading modules...")

# Core modules
include("src/TheoreticalPointTables.jl")
using .TheoreticalPointTables

# Load from parent directory
include("../by_degree/src/Common4DDeuflhard.jl")
using .Common4DDeuflhard

include("../by_degree/src/SubdomainManagement.jl")
using .SubdomainManagement

include("../by_degree/src/TheoreticalPoints.jl")
using .TheoreticalPoints: load_theoretical_4d_points_orthant

# Analysis modules
include("src/run_analysis_with_refinement.jl")
using .Main: run_enhanced_analysis_with_refinement

# Refined point analysis
include("src/RefinedPointAnalysis.jl")
using .RefinedPointAnalysis

# Enhanced plotting
include("src/V4PlottingEnhanced.jl")
using .V4PlottingEnhanced

# Function value analysis
include("src/FunctionValueAnalysis.jl")
using .FunctionValueAnalysis

# Function value error summary
include("src/FunctionValueErrorSummary.jl")
using .FunctionValueErrorSummary

# Additional dependencies
using CSV, DataFrames, Dates, Statistics, LinearAlgebra

println("✅ Modules loaded successfully")

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
all_critical_points_with_labels = analysis_results.all_critical_points  # Note: field name is all_critical_points
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
        # Get points for this degree
        df_cheb = all_critical_points_with_labels[degree]
        df_min_refined = all_min_refined_points[degree]
        
        # Initialize collection for refined to cheb distances
        all_refined_to_cheb = Float64[]
        
        # Create refined distance tables for each subdomain
        for subdomain in subdomains
            subdomain_label = subdomain.label
            
            # Filter points for this subdomain
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
                
                table_key = "$(subdomain_label)_d$(degree)"
                refined_tables[table_key] = refined_table
                
                # Collect refined to cheb distances
                append!(all_refined_to_cheb, refined_table[!, Symbol("d$degree")])
            end
        end
        
        # Store all refined to cheb distances for this degree
        refined_to_cheb_distances[degree] = all_refined_to_cheb
        
        # Calculate overall metrics
        # First extract theoretical minima
        theoretical_minima = [p for (p, t) in zip(theoretical_points, theoretical_types) if t == "min"]
        metrics = RefinedPointAnalysis.calculate_refinement_metrics(
            theoretical_minima,
            df_cheb,
            df_min_refined,
            degree
        )
        # Add counts to metrics
        avg_refined_to_cheb = isempty(all_refined_to_cheb) ? 0.0 : mean(all_refined_to_cheb)
        refinement_metrics[degree] = (
            n_computed = nrow(df_cheb),
            n_refined = nrow(df_min_refined),
            avg_theo_to_cheb = metrics.avg_theo_to_cheb,
            avg_theo_to_refined = metrics.avg_theo_to_refined,
            avg_refined_to_cheb = avg_refined_to_cheb,
            avg_improvement = metrics.avg_improvement
        )
        
        println("   Degree $degree: $(nrow(df_cheb)) → $(nrow(df_min_refined)) points")
        println("            Improvement: $(round(metrics.avg_improvement * 100, digits=1))%")
    end
end

# Step 6: Function Value Analysis
println("\n📊 Analyzing function values at critical points...")
function_value_tables = Dict{String, DataFrame}()
for degree in degrees
    if haskey(all_critical_points_with_labels, degree)
        df_cheb = all_critical_points_with_labels[degree]
        
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
                
                table_key = "$(subdomain_label)_d$(degree)"
                function_value_tables[table_key] = fval_table
            end
        end
    end
end

# Create summary of function value errors using new format
println("\n📊 Generating function value error summary...")
summary_table = generate_error_summary_table(
    all_critical_points_with_labels,
    theoretical_points,
    theoretical_types,
    degrees,
    deuflhard_4d_composite
)

print_error_summary_table(summary_table)

# Step 7: Save outputs
mkpath(output_dir)

# Save V4 tables
for (label, table) in subdomain_tables_v4
    filename = joinpath(output_dir, "subdomain_$(label)_v4.csv")
    CSV.write(filename, table)
end

# Save refinement summary
refinement_summary = DataFrame(
    degree = Int[],
    n_computed = Int[],
    n_refined = Int[],
    avg_theo_to_cheb = Float64[],
    avg_theo_to_refined = Float64[],
    avg_refined_to_cheb = Float64[],
    improvement_pct = Float64[]
)

for (deg, metrics) in sort(collect(refinement_metrics), by=x->x[1])
    push!(refinement_summary, (
        degree = deg,
        n_computed = metrics.n_computed,
        n_refined = metrics.n_refined,
        avg_theo_to_cheb = round(metrics.avg_theo_to_cheb, digits=4),
        avg_theo_to_refined = round(metrics.avg_theo_to_refined, digits=4),
        avg_refined_to_cheb = round(metrics.avg_refined_to_cheb, digits=4),
        improvement_pct = round(metrics.avg_improvement * 100, digits=1)
    ))
end

CSV.write(joinpath(output_dir, "refinement_summary.csv"), refinement_summary)

# Save function value analysis
if !isempty(function_value_tables)
    # Save individual tables
    for (label, table) in function_value_tables
        filename = joinpath(output_dir, "function_values_$(label).csv")
        CSV.write(filename, table)
    end
    
    # Save new summary table
    CSV.write(joinpath(output_dir, "function_value_error_summary.csv"), summary_table)
end

println("\n✅ Tables saved to: $output_dir")

# Step 8: Create enhanced plots
println("\n📊 Creating enhanced V4 plots...")

# Prepare data for enhanced plotting
plot_data = Dict(
    "subdomain_tables" => subdomain_tables_v4,
    "degrees" => degrees,
    "l2_data" => l2_data,
    "distance_data" => distance_data,
    "subdomain_distance_data" => subdomain_distance_data,
    "refined_to_cheb_distances" => refined_to_cheb_distances,
    "refinement_metrics" => refinement_metrics
)

# Create theoretical minima to refined distances data
minima_to_refined_by_degree = Dict{Int, Dict{String, Vector{Float64}}}()
for degree in degrees
    if haskey(all_min_refined_points, degree)
        minima_to_refined_by_degree[degree] = Dict{String, Vector{Float64}}()
        df_min_refined = all_min_refined_points[degree]
        
        for subdomain in subdomains
            # Get theoretical minima for this subdomain
            subdomain_minima = [p for (p, t) in zip(theoretical_points, theoretical_types) 
                if t == "min" && SubdomainManagement.is_point_in_subdomain(p, subdomain)]
            
            # Get refined points for this subdomain
            subdomain_mask = df_min_refined.subdomain .== subdomain.label
            subdomain_refined = df_min_refined[subdomain_mask, :]
            
            if !isempty(subdomain_minima) && nrow(subdomain_refined) > 0
                refined_points = [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(subdomain_refined)]
                distances = Float64[]
                for theo_min in subdomain_minima
                    min_dist = minimum(norm(theo_min - rp) for rp in refined_points)
                    push!(distances, min_dist)
                end
                minima_to_refined_by_degree[degree][subdomain.label] = distances
            end
        end
    end
end

plot_data["minima_to_refined_distances"] = minima_to_refined_by_degree

# Create all plots using V4PlottingEnhanced
plots = V4PlottingEnhanced.create_all_v4_plots(
    plot_data,
    output_dir = output_dir,
    plot_config = Dict("threshold" => 0.1)
)

println("\n✅ Enhanced plots saved to: $output_dir")

# Final summary
println("\n" * "="^80)
println("🎉 ENHANCED V4 ANALYSIS COMPLETE!")
println("="^80)
println("\nResults saved to: $output_dir/")
println("\nFiles generated:")
println("  - subdomain_*_v4.csv : V4 theoretical point tables")
println("  - refinement_summary.csv : BFGS refinement effectiveness")
println("  - function_values_*.csv : Function value comparisons by subdomain")
println("  - function_value_error_summary.csv : Summary of function value errors")
println("  - v4_*.png : Standard and enhanced visualization plots")

# Return results
(
    subdomain_tables = subdomain_tables_v4,
    refinement_metrics = refinement_metrics,
    all_min_refined_points = all_min_refined_points,
    function_value_error_summary = summary_table
)