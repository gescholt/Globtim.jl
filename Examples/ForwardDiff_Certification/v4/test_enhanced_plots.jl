#!/usr/bin/env julia

# Test script for enhanced V4 plots with nodes at each degree
# This creates a minimal example to verify the plot enhancements

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using DataFrames
using Dates

println("\n" * "="^80)
println("📊 TESTING ENHANCED V4 PLOTS")
println("="^80)

# Include the enhanced plotting module
include("src/V4PlottingEnhanced.jl")
using .V4PlottingEnhanced

# Create minimal test data
degrees = [3, 4, 5, 6]
println("\nTest degrees: $degrees")

# Test data for L2 convergence
l2_data = Dict{Int, Dict{String, Float64}}()
for deg in degrees
    l2_data[deg] = Dict{String, Float64}()
    # Create data for 4 subdomains with decreasing L2 norms
    for i in 1:4
        subdomain = @sprintf("%04d", i-1)
        l2_data[deg][subdomain] = 0.1 * exp(-0.5 * deg) * (1 + 0.2 * randn())
    end
end

# Test data for critical point distance evolution
subdomain_tables = Dict{String, DataFrame}()
for i in 1:4
    subdomain = @sprintf("%04d", i-1)
    
    # Create table with 2 minima and 1 saddle point
    table_data = DataFrame()
    
    # Add minima
    for j in 1:2
        row = Dict(
            :theoretical_point_id => "TP_$(i)_MIN_$j",
            :type => "min",
            :x1 => 0.5 * randn(),
            :x2 => 0.5 * randn(),
            :x3 => 0.5 * randn(),
            :x4 => 0.5 * randn()
        )
        
        # Add distance columns
        for deg in degrees
            row[Symbol("d$deg")] = 0.1 * exp(-0.3 * deg) * (1 + 0.1 * randn())
        end
        
        push!(table_data, row)
    end
    
    # Add saddle point
    row = Dict(
        :theoretical_point_id => "TP_$(i)_SADDLE",
        :type => "saddle",
        :x1 => 0.5 * randn(),
        :x2 => 0.5 * randn(),
        :x3 => 0.5 * randn(),
        :x4 => 0.5 * randn()
    )
    
    for deg in degrees
        row[Symbol("d$deg")] = 0.15 * exp(-0.25 * deg) * (1 + 0.15 * randn())
    end
    
    push!(table_data, row)
    
    # Add AVERAGE row
    avg_row = Dict(
        :theoretical_point_id => "AVERAGE",
        :type => "-",
        :x1 => NaN,
        :x2 => NaN,
        :x3 => NaN,
        :x4 => NaN
    )
    
    for deg in degrees
        avg_row[Symbol("d$deg")] = mean(table_data[!, Symbol("d$deg")])
    end
    
    push!(table_data, avg_row)
    
    subdomain_tables[subdomain] = table_data
end

# Create output directory
timestamp = Dates.format(Dates.now(), "HH-MM")
output_dir = "outputs/test_enhanced_$timestamp"
mkpath(output_dir)

println("\n📊 Generating enhanced plots...")

# Test 1: L2 convergence plot with nodes on subdomain traces
println("\n1. Testing L2 convergence plot with subdomain nodes...")
l2_fig, l2_legend = plot_v4_l2_convergence(degrees, l2_data, output_dir=output_dir)
println("   ✅ L2 convergence plot created")

# Test 2: Critical point distance evolution with nodes at each degree
println("\n2. Testing critical point distance evolution with nodes...")
evolution_fig, evolution_legend = plot_critical_point_distance_evolution(
    subdomain_tables, degrees, 
    output_dir=output_dir,
    plot_all_points=true
)
println("   ✅ Critical point distance evolution plot created")

# Test 3: Minimizer-focused plot (should also have nodes)
println("\n3. Testing minimizer distance evolution plot...")
min_fig, min_info = plot_minimizer_distance_evolution(
    subdomain_tables, degrees,
    output_dir=output_dir
)
println("   ✅ Minimizer distance evolution plot created")

println("\n✅ All enhanced plots generated successfully!")
println("\n📁 Plots saved to: $output_dir")
println("\nPlease check the following files:")
println("   - v4_l2_convergence.png: Should show subdomain traces with small nodes")
println("   - v4_critical_point_distance_evolution.png: Should show nodes at each degree")
println("   - v4_minimizer_distance_evolution.png: Should show nodes for minimizers")

# Display plots in windows for visual inspection
println("\n📊 Displaying plots in windows...")
display(l2_fig)
display(evolution_fig)
display(min_fig)

println("\n✨ Test complete!")