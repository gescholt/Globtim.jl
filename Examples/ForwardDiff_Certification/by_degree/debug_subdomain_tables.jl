#!/usr/bin/env julia
# ================================================================================
# Debug Subdomain Tables
# ================================================================================
# This script helps debug why only 3 subdomains are being plotted despite having 9
# subdomains in the positive orthant.
# ================================================================================

using DataFrames
using CSV
using Statistics
using LinearAlgebra

println("\n" * "="^80)
println("🔍 DEBUGGING SUBDOMAIN TABLES")
println("="^80)

# Load modules exactly as run_all_examples.jl does
include("src/CriticalPointTablesV2.jl")
using .CriticalPointTablesV2

include("src/TheoreticalPoints.jl")
using .TheoreticalPoints: load_theoretical_4d_points_orthant

include("src/SubdomainManagement.jl")
using .SubdomainManagement

# Configuration from run_all_examples.jl
const DEGREES = [3,4]
const GN = 20
const TRESH = 0.1

# Step 1: Load theoretical points and subdomains
println("\n📊 Step 1: Loading theoretical points and subdomains...")
theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
subdomains = SubdomainManagement.generate_16_subdivisions_orthant()

println("   Theoretical points loaded: $(length(theoretical_points))")
println("   Theoretical types: $(unique(theoretical_types))")
println("   Subdomains generated: $(length(subdomains))")

# List all subdomain labels
println("\n📋 All subdomain labels:")
for (i, subdomain) in enumerate(subdomains)
    println("   $i. $(subdomain.label)")
end

# Step 2: Check theoretical point assignments to subdomains
println("\n📊 Step 2: Checking theoretical point assignments...")
theory_assignments = Dict{String, Vector{Int}}()
subdomain_labels = [subdomain.label for subdomain in subdomains]

for label in subdomain_labels
    theory_assignments[label] = Int[]
end

# Assign theoretical points to subdomains
for (idx, point) in enumerate(theoretical_points)
    assigned = false
    for subdomain in subdomains
        if SubdomainManagement.is_point_in_subdomain(point, subdomain, tolerance=0.0)
            push!(theory_assignments[subdomain.label], idx)
            assigned = true
            break
        end
    end
    if !assigned
        println("   ⚠️  Point $idx not assigned to any subdomain: $point")
    end
end

println("\n📊 Theoretical points per subdomain:")
for (label, indices) in sort(theory_assignments)
    n_points = length(indices)
    if n_points > 0
        types = [theoretical_types[idx] for idx in indices]
        n_min = count(t -> t == "Minimum", types)
        n_saddle = count(t -> t == "Saddle", types)
        println("   $label: $n_points points ($n_min min, $n_saddle saddle)")
    else
        println("   $label: 0 points ❌")
    end
end

# Step 3: Actually run the analysis to get real computed points
println("\n📊 Step 3: Running analysis to get computed points...")
include("examples/degree_convergence_analysis_enhanced_v3.jl")

# Run with analyze_global=false to focus on subdomain analysis
summary_df, distance_data, all_computed_points, output_dir, computed_by_subdomain_by_degree, all_critical_points_with_labels = run_enhanced_analysis_v2(DEGREES, GN, analyze_global=false, threshold=TRESH)

println("\n📊 Computed critical points summary:")
for degree in DEGREES
    if haskey(all_critical_points_with_labels, degree)
        df = all_critical_points_with_labels[degree]
        active_subdomains = unique(df.subdomain)
        println("   Degree $degree: $(nrow(df)) points in $(length(active_subdomains)) subdomains")
        println("      Subdomains: $(join(sort(active_subdomains), ", "))")
    else
        println("   Degree $degree: No data!")
    end
end

# Step 4: Generate subdomain tables
println("\n📊 Step 4: Generating subdomain tables...")
subdomain_tables = CriticalPointTablesV2.generate_subdomain_critical_point_tables(
    theoretical_points, 
    theoretical_types,
    all_critical_points_with_labels,
    DEGREES,
    subdomains,
    tolerance = 0.0,
    is_point_in_subdomain_func = SubdomainManagement.is_point_in_subdomain
)

println("\n📊 Generated tables summary:")
println("   Total tables generated: $(length(subdomain_tables))")

# Step 5: Analyze each subdomain table
println("\n📊 Step 5: Detailed analysis of each subdomain table:")
println("="^80)

for (subdomain_label, table) in sort(subdomain_tables)
    println("\n📋 Subdomain: $subdomain_label")
    println("   Table size: $(nrow(table)) rows × $(ncol(table)) columns")
    println("   Column names: $(names(table))")
    
    if nrow(table) == 0
        println("   ⚠️  EMPTY TABLE!")
    else
        # Show sample data
        println("   First few rows:")
        show(stdout, first(table, min(3, nrow(table))), allrows=false, allcols=true)
        println()
        
        # Check degree columns
        for degree in DEGREES
            col_name = Symbol("degree_$degree")
            if col_name in names(table)
                values = table[!, col_name]
                n_valid = count(!isnan, values)
                if n_valid > 0
                    min_val = minimum(filter(!isnan, values))
                    max_val = maximum(filter(!isnan, values))
                    avg_val = mean(filter(!isnan, values))
                    println("   degree_$degree: $n_valid valid values, range [$min_val, $max_val], avg=$(round(avg_val, digits=6))")
                else
                    println("   degree_$degree: ALL NaN values ❌")
                end
            else
                println("   degree_$degree: COLUMN MISSING ❌")
            end
        end
    end
end

# Step 6: Check what data would be extracted for plotting
println("\n" * "="^80)
println("📊 Step 6: Data extraction for plotting (simulating plot_subdomain_distance_evolution)")
println("="^80)

# This simulates the data extraction in plot_subdomain_distance_evolution
plotting_data = []

for (subdomain_label, table) in subdomain_tables
    if nrow(table) == 0
        println("   ⚠️  Skipping $subdomain_label - empty table")
        continue
    end
    
    # Calculate average distances for each degree
    avg_distances = Float64[]
    
    for degree in DEGREES
        col_name = Symbol("degree_$degree")
        if col_name in names(table)
            col_data = table[!, col_name]
            valid_data = filter(!isnan, col_data)
            
            if !isempty(valid_data)
                avg_dist = mean(valid_data)
                push!(avg_distances, avg_dist)
            else
                push!(avg_distances, NaN)
            end
        else
            push!(avg_distances, NaN)
        end
    end
    
    # Count point types
    n_min = count(t -> t == "Minimum", table.type)
    n_saddle = count(t -> t == "Saddle", table.type)
    
    # Check if we have any valid data
    if any(!isnan, avg_distances)
        push!(plotting_data, (
            label = subdomain_label,
            avg_distances = avg_distances,
            n_min = n_min,
            n_saddle = n_saddle
        ))
        println("   ✅ $subdomain_label: Will be plotted with avg distances [$(join(round.(avg_distances, digits=6), ", "))]")
    else
        println("   ❌ $subdomain_label: All NaN distances, will NOT be plotted")
    end
end

println("\n📊 SUMMARY:")
println("   Subdomains with theoretical points: $(length(filter(kv -> !isempty(kv[2]), theory_assignments)))")
println("   Tables generated: $(length(subdomain_tables))")
println("   Subdomains that would be plotted: $(length(plotting_data))")

if length(plotting_data) < length(filter(kv -> !isempty(kv[2]), theory_assignments))
    println("\n⚠️  ISSUE IDENTIFIED:")
    println("   Not all subdomains with theoretical points will be plotted!")
    println("   This is likely because computed points are only found in some subdomains.")
    
    # Identify which subdomains are missing
    plotted_labels = Set([pd.label for pd in plotting_data])
    theory_labels = Set([label for (label, indices) in theory_assignments if !isempty(indices)])
    missing_labels = setdiff(theory_labels, plotted_labels)
    
    println("\n   Missing subdomains: $(join(sort(collect(missing_labels)), ", "))")
    
    println("\n   To fix this, ensure that:")
    println("   1. The grid resolution (GN=$GN) is sufficient to capture points in all subdomains")
    println("   2. The optimization is finding critical points in all subdomains")
    println("   3. The subdomain assignment in computed points matches the theoretical assignment")
end

println("\n✅ Debug analysis complete!")