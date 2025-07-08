#!/usr/bin/env julia

# Example: Plot from existing V4 tables without re-running analysis

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

using CSV, DataFrames

# Include plotting module
include("../src/V4Plotting.jl")
using .V4Plotting

# Function to load tables from a directory
function load_v4_tables(table_dir::String)
    subdomain_tables = Dict{String, DataFrame}()
    
    # Find all subdomain CSV files
    for file in readdir(table_dir)
        if startswith(file, "subdomain_") && endswith(file, "_v4.csv")
            # Extract subdomain label from filename
            label = replace(file, "subdomain_" => "", "_v4.csv" => "")
            
            # Load table
            table_path = joinpath(table_dir, file)
            subdomain_tables[label] = CSV.read(table_path, DataFrame)
        end
    end
    
    return subdomain_tables
end

# Example usage
function plot_from_existing_tables(table_dir::String; degrees=[3,4])
    println("\n📊 Loading V4 tables from: $table_dir")
    
    # Load tables
    subdomain_tables = load_v4_tables(table_dir)
    println("   Loaded $(length(subdomain_tables)) subdomain tables")
    
    # Create output directory for plots
    plot_dir = joinpath(dirname(table_dir), "plots_$(basename(table_dir))")
    mkpath(plot_dir)
    
    # Create critical point distance evolution plot
    println("\n📊 Creating critical point distance evolution plot...")
    
    # Plot all points
    fig1 = plot_critical_point_distance_evolution(
        subdomain_tables, degrees,
        output_dir = plot_dir,
        plot_all_points = true
    )
    
    # Plot averages only
    fig2 = plot_critical_point_distance_evolution(
        subdomain_tables, degrees,
        output_dir = plot_dir,
        plot_all_points = false
    )
    
    # Plot with specific subdomain highlighted
    fig3 = plot_critical_point_distance_evolution(
        subdomain_tables, degrees,
        output_dir = plot_dir,
        plot_all_points = true,
        highlight_subdomain = "0000"
    )
    
    println("\n✅ Plots saved to: $plot_dir")
    
    return subdomain_tables
end

# If run directly, show example usage
if abspath(PROGRAM_FILE) == @__FILE__
    println("\n" * "="^80)
    println("📊 V4 PLOTTING FROM EXISTING TABLES - EXAMPLE")
    println("="^80)
    
    println("\nUsage:")
    println("  julia plot_existing_tables.jl <path_to_table_directory>")
    println("\nExample:")
    println("  julia plot_existing_tables.jl ../outputs/v4_output")
    
    # Check if directory argument provided
    if length(ARGS) > 0
        table_dir = ARGS[1]
        if isdir(table_dir)
            plot_from_existing_tables(table_dir)
        else
            println("\n❌ Error: Directory not found: $table_dir")
        end
    else
        println("\n💡 Tip: Provide a directory containing V4 tables as an argument")
    end
end