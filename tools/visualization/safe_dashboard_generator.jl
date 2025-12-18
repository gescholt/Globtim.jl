#!/usr/bin/env julia
"""
Safe Dashboard Generator

This script provides environment-isolated visualization dashboard generation
to avoid cross-environment MethodError issues.

Usage:
    julia tools/visualization/safe_dashboard_generator.jl <data_file> <output_dir>
"""

# Verify arguments
if length(ARGS) < 2
    println("❌ Error: Insufficient arguments")
    println("Usage: julia safe_dashboard_generator.jl <data_file> <output_dir>")
    exit(1)
end

data_file = ARGS[1]
output_dir = ARGS[2]

println("🎨 Safe Dashboard Generator")
println("   Data file: $data_file")
println("   Output directory: $output_dir")

# Change to globtimplots directory and activate its environment
globtimplots_path = abspath(joinpath(@__DIR__, "..", "..", "..", "globtimplots"))
if !isdir(globtimplots_path)
    println("❌ Error: @globtimplots not found at: $globtimplots_path")
    exit(1)
end

cd(globtimplots_path)
println("🔧 Working from: $(pwd())")
println("🔧 Activating @globtimplots environment...")

using Pkg
Pkg.activate(".")

# Load required packages
using CSV, DataFrames

# Include comparison plotting functions
comparison_plots_file = joinpath(pwd(), "src", "comparison_plots.jl")
if !isfile(comparison_plots_file)
    println("❌ Error: comparison_plots.jl not found at: $comparison_plots_file")
    exit(1)
end
include(comparison_plots_file)

# Change back to original directory for data access
original_dir = dirname(dirname(@__DIR__))
cd(original_dir)
println("🔧 Back to data directory: $(pwd())")

# Load data file
try
    combined_data = CSV.read(data_file, DataFrame)
    println("📊 Data loaded: $(nrow(combined_data)) × $(ncol(combined_data))")
    println("   Columns: $(names(combined_data))")

    # Verify data format
    if !("degree" in names(combined_data) && "z" in names(combined_data))
        println("❌ Error: Data file missing required columns 'degree' and 'z'")
        println("   Available columns: $(names(combined_data))")
        exit(1)
    end

    # Create output directory
    mkpath(output_dir)

    # Call visualization function (now in correct environment)
    println("🎯 Creating comprehensive comparison plots...")
    results = create_comparison_plots(combined_data; output_dir=output_dir)

    println("✨ SUCCESS! Visual dashboard generated")
    println("   📁 Dashboard directory: $output_dir/")
    println("   📊 Files created: $(length(results)) files")

    # Show results summary
    if haskey(results, "overview") && results["overview"] !== nothing
        overview_data = results["overview"]
        if isa(overview_data, DataFrame) && nrow(overview_data) > 0
            best_exp_idx = argmin(overview_data.best_l2)
            best_exp = overview_data[best_exp_idx, :]
            println("🏆 Best experiment: $(best_exp.experiment_id)")
            println("🎯 Best L2 norm: $(round(best_exp.best_l2, digits=8))")
        end
    end

catch e
    println("❌ Error during dashboard generation: $e")
    exit(1)
end