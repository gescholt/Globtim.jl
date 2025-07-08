#!/usr/bin/env julia

# Analyze function values from existing CSV files
# This script reads pre-computed results and analyzes function value errors

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using DataFrames
using CSV
using Statistics
using LinearAlgebra

println("\n" * "="^80)
println("📊 FUNCTION VALUE ANALYSIS FROM EXISTING RESULTS")
println("="^80)

# Load modules
include("src/FunctionValueAnalysis.jl")
using .FunctionValueAnalysis

include("../by_degree/src/Common4DDeuflhard.jl")
using .Common4DDeuflhard

include("../by_degree/src/SubdomainManagement.jl")
using .SubdomainManagement

include("../by_degree/src/TheoreticalPoints.jl")
using .TheoreticalPoints: load_theoretical_4d_points_orthant

# Find the most recent output directory
output_dirs = filter(d -> startswith(d, "enhanced_"), readdir("outputs"))
if isempty(output_dirs)
    error("No output directories found. Please run run_v4_analysis.jl first.")
end

# Sort by modification time and use the most recent
output_dir = joinpath("outputs", last(sort(output_dirs)))
println("\nUsing output directory: $output_dir")

# Load theoretical points
println("\n📊 Loading theoretical points...")
theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()

# Generate subdomains
subdomains = SubdomainManagement.generate_16_subdivisions_orthant()

# Process each subdomain table
println("\n📊 Analyzing function values by subdomain...")

all_results = DataFrame()
degrees = Int[]

for file in readdir(output_dir)
    if startswith(file, "subdomain_") && endswith(file, "_v4.csv")
        # Extract subdomain label
        parts = split(file, "_")
        subdomain_label = parts[2]
        
        # Read the CSV file
        df = CSV.read(joinpath(output_dir, file), DataFrame)
        
        # Extract unique degrees from the DataFrame
        for col in names(df)
            if startswith(string(col), "d") && tryparse(Int, string(col)[2:end]) !== nothing
                deg = parse(Int, string(col)[2:end])
                if deg ∉ degrees
                    push!(degrees, deg)
                end
            end
        end
    end
end

sort!(degrees)
println("Found degrees: $degrees")

# Now analyze function values for each degree
println("\n" * "="^80)
println("📊 FUNCTION VALUE ERROR ANALYSIS")
println("="^80)

for degree in degrees
    println("\n🔹 Degree $degree")
    println("-"^40)
    
    # Collect results for this degree
    degree_results = DataFrame(
        subdomain = String[],
        point_type = String[],
        n_theoretical = Int[],
        n_matched = Int[],
        avg_f_error_pct = Float64[],
        max_f_error_pct = Float64[]
    )
    
    for subdomain in subdomains
        subdomain_label = subdomain.label
        filename = joinpath(output_dir, "subdomain_$(subdomain_label)_v4.csv")
        
        if !isfile(filename)
            continue
        end
        
        # Read subdomain data
        df = CSV.read(filename, DataFrame)
        degree_col = Symbol("d$degree")
        
        if degree_col ∉ names(df)
            continue
        end
        
        # Get theoretical points for this subdomain
        subdomain_theoretical_points = [p for (p, t) in zip(theoretical_points, theoretical_types) 
            if SubdomainManagement.is_point_in_subdomain(p, subdomain)]
        subdomain_theoretical_types = [t for (p, t) in zip(theoretical_points, theoretical_types) 
            if SubdomainManagement.is_point_in_subdomain(p, subdomain)]
        
        if isempty(subdomain_theoretical_points)
            continue
        end
        
        # Group by point type
        for ptype in unique(subdomain_theoretical_types)
            type_mask = subdomain_theoretical_types .== ptype
            type_theoretical_points = subdomain_theoretical_points[type_mask]
            
            # Count matches (distance < 0.05)
            n_matched = sum(df[!, degree_col] .< 0.05)
            
            if n_matched > 0
                # Calculate function value errors for matched points
                f_errors = Float64[]
                
                for (i, theo_pt) in enumerate(type_theoretical_points)
                    # Find row with minimum distance
                    if i <= nrow(df)
                        dist = df[i, degree_col]
                        if dist < 0.05  # Matched
                            # Extract computed point from DataFrame
                            computed_pt = [df[i, :x1], df[i, :x2], df[i, :x3], df[i, :x4]]
                            
                            # Calculate function values
                            f_theo = deuflhard_4d_composite(theo_pt)
                            f_comp = deuflhard_4d_composite(computed_pt)
                            
                            # Relative error
                            if abs(f_theo) > 1e-10
                                rel_error = abs(f_comp - f_theo) / abs(f_theo) * 100
                            else
                                rel_error = abs(f_comp - f_theo) * 100
                            end
                            
                            push!(f_errors, rel_error)
                        end
                    end
                end
                
                if !isempty(f_errors)
                    push!(degree_results, (
                        subdomain = subdomain_label,
                        point_type = ptype,
                        n_theoretical = length(type_theoretical_points),
                        n_matched = n_matched,
                        avg_f_error_pct = mean(f_errors),
                        max_f_error_pct = maximum(f_errors)
                    ))
                end
            end
        end
    end
    
    # Display results for this degree
    if nrow(degree_results) > 0
        # Summary by point type
        for ptype in unique(degree_results.point_type)
            type_data = degree_results[degree_results.point_type .== ptype, :]
            
            total_theoretical = sum(type_data.n_theoretical)
            total_matched = sum(type_data.n_matched)
            avg_error = mean(type_data.avg_f_error_pct)
            max_error = maximum(type_data.max_f_error_pct)
            
            println("\n  $(uppercase(ptype)) POINTS:")
            println("    Total theoretical: $total_theoretical")
            println("    Total matched: $total_matched ($(round(total_matched/total_theoretical*100, digits=1))%)")
            println("    Average function error: $(round(avg_error, digits=3))%")
            println("    Maximum function error: $(round(max_error, digits=3))%")
        end
    end
end

# Overall comparison between minima and saddle points
println("\n" * "="^80)
println("📊 OVERALL COMPARISON: MINIMA vs SADDLE POINTS")
println("="^80)

overall_summary = DataFrame(
    degree = Int[],
    point_type = String[],
    avg_error_pct = Float64[]
)

# Re-analyze for overall summary
for degree in degrees
    min_errors = Float64[]
    saddle_errors = Float64[]
    
    for subdomain in subdomains
        subdomain_label = subdomain.label
        filename = joinpath(output_dir, "subdomain_$(subdomain_label)_v4.csv")
        
        if !isfile(filename)
            continue
        end
        
        df = CSV.read(filename, DataFrame)
        degree_col = Symbol("d$degree")
        
        if degree_col ∉ names(df)
            continue
        end
        
        # Get theoretical points
        subdomain_theoretical_points = [p for (p, t) in zip(theoretical_points, theoretical_types) 
            if SubdomainManagement.is_point_in_subdomain(p, subdomain)]
        subdomain_theoretical_types = [t for (p, t) in zip(theoretical_points, theoretical_types) 
            if SubdomainManagement.is_point_in_subdomain(p, subdomain)]
        
        for (i, (theo_pt, ptype)) in enumerate(zip(subdomain_theoretical_points, subdomain_theoretical_types))
            if i <= nrow(df) && df[i, degree_col] < 0.05
                computed_pt = [df[i, :x1], df[i, :x2], df[i, :x3], df[i, :x4]]
                
                f_theo = deuflhard_4d_composite(theo_pt)
                f_comp = deuflhard_4d_composite(computed_pt)
                
                rel_error = abs(f_comp - f_theo) / abs(f_theo) * 100
                
                if ptype == "min"
                    push!(min_errors, rel_error)
                else
                    push!(saddle_errors, rel_error)
                end
            end
        end
    end
    
    if !isempty(min_errors)
        push!(overall_summary, (degree = degree, point_type = "min", avg_error_pct = mean(min_errors)))
    end
    if !isempty(saddle_errors)
        push!(overall_summary, (degree = degree, point_type = "saddle", avg_error_pct = mean(saddle_errors)))
    end
end

# Display final comparison
println("\n📊 Summary Table:")
println(overall_summary)

println("\n📊 Key Findings:")
for deg in degrees
    deg_data = overall_summary[overall_summary.degree .== deg, :]
    if nrow(deg_data) == 2
        min_err = deg_data[deg_data.point_type .== "min", :avg_error_pct][1]
        saddle_err = deg_data[deg_data.point_type .== "saddle", :avg_error_pct][1]
        
        println("\nDegree $deg:")
        println("  - Minima average error: $(round(min_err, digits=3))%")
        println("  - Saddle average error: $(round(saddle_err, digits=3))%") 
        println("  - Saddle points are $(round(saddle_err/min_err, digits=1))x worse than minima")
    end
end

println("\n✅ Analysis complete!")