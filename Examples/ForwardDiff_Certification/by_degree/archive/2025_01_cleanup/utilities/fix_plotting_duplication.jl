"""
Fix for the plotting duplication issue.
This demonstrates the corrected plotting logic that only plots subdomains with actual results.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

# Add shared directory to load path
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))

using CairoMakie
using DataFrames
using Statistics
using Printf

# Import the enhanced data structure
include("shared/EnhancedAnalysisUtilities.jl")
using .EnhancedAnalysisUtilities: EnhancedDegreeAnalysisResult

"""
Fixed plotting function that only plots subdomains with actual results.
"""
function plot_l2_convergence_fixed(results; 
                                 title::String="",
                                 tolerance_line::Union{Nothing,Float64}=nothing,
                                 save_plots::Bool=false, 
                                 plots_directory::String="plots")
    
    # Filter out empty subdomains
    non_empty_results = Dict{String, Vector{EnhancedDegreeAnalysisResult}}()
    
    for (label, result_vec) in results
        if !isempty(result_vec)
            non_empty_results[label] = result_vec
        end
    end
    
    println("Plotting $(length(non_empty_results)) non-empty subdomains out of $(length(results)) total")
    
    # Create figure
    fig = Figure(size=(1000, 600))
    
    if length(non_empty_results) > 1
        # Multi-domain case
        ax = Axis(fig[1, 1],
            xlabel="Polynomial Degree",
            ylabel="L² Error",
            title=isempty(title) ? "L² Convergence: Non-Empty Subdomains" : title,
            yscale=log10,
            xlabelsize=16,
            ylabelsize=16,
            titlesize=18,
            yminorticksvisible=true,
            yminorgridvisible=true
        )
        
        # Plot each non-empty subdomain
        colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray, :olive, :cyan]
        
        for (idx, (name, result_vec)) in enumerate(sort(collect(non_empty_results), by=x->x[1]))
            degrees = [r.degree for r in result_vec]
            l2_norms = [r.l2_norm for r in result_vec]
            color_idx = mod1(idx, length(colors))
            
            lines!(ax, degrees, l2_norms,
                color=colors[color_idx],
                linewidth=2,
                label=name)
            scatter!(ax, degrees, l2_norms,
                color=colors[color_idx],
                markersize=8)
        end
        
        axislegend(ax, position=:rt, labelsize=12)
        
    else
        # Single domain case
        ax = Axis(fig[1, 1],
            xlabel="Polynomial Degree",
            ylabel="L² Error",
            title=isempty(title) ? "L² Convergence: Single Domain" : title,
            yscale=log10,
            xlabelsize=16,
            ylabelsize=16,
            titlesize=18,
            yminorticksvisible=true,
            yminorgridvisible=true
        )
        
        # Plot the single subdomain
        if !isempty(non_empty_results)
            (name, result_vec) = first(non_empty_results)
            degrees = [r.degree for r in result_vec]
            l2_norms = [r.l2_norm for r in result_vec]
            
            lines!(ax, degrees, l2_norms,
                color=:blue,
                linewidth=2.5,
                label=name)
            scatter!(ax, degrees, l2_norms,
                color=:blue,
                markersize=10)
            
            axislegend(ax, position=:rt, labelsize=12)
        end
    end
    
    # Add tolerance line if specified
    if tolerance_line !== nothing
        hlines!(ax, [tolerance_line], color=:black, linestyle=:dash, 
               linewidth=2, label="Tolerance")
    end
    
    # Save or display
    if save_plots
        mkpath(plots_directory)
        filename = joinpath(plots_directory, "l2_convergence_fixed.png")
        save(filename, fig, px_per_unit=2)
        println("Saved corrected plot to: $filename")
    else
        display(fig)
    end
    
    return fig
end

# Test the fix with mock data
function test_plotting_fix()
    println("=== Testing Fixed Plotting Logic ===")
    
    # Create mock data that simulates the real issue
    # Only subdomain "1010" has results, all others are empty
    
    # Create a realistic result for subdomain 1010
    subdomain_results = Dict{String, Vector{EnhancedDegreeAnalysisResult}}()
    
    # Mock the single subdomain with results
    results_1010 = EnhancedDegreeAnalysisResult[]
    for degree in 2:6
        # Create a mock enhanced result
        result = EnhancedDegreeAnalysisResult(
            degree,                    # degree
            10.0^(-0.5 * degree),     # l2_norm (improving with degree)
            9,                        # n_theoretical_points
            min(degree * 5, 25),      # n_computed_points
            min(degree * 2, 9),       # n_successful_recoveries
            min(degree * 2, 9) / 9,   # success_rate
            degree^2 * 0.1,           # runtime_seconds
            degree >= 5,              # converged
            [rand(4) for _ in 1:min(degree * 5, 25)],  # computed_points
            min(degree - 1, 1),       # min_min_success_rate
            [0.1 / degree for _ in 1:3],  # min_min_distances
            [0.1 / degree for _ in 1:9],  # all_critical_distances
            [true, false, true],      # min_min_found_by_bfgs
            [true, true, degree >= 4], # min_min_within_tolerance
            fill("unknown", min(degree * 5, 25)), # point_classifications
            [rand(4) for _ in 1:9],   # theoretical_points
            "1010",                   # subdomain_label
            zeros(Int, min(degree * 5, 25)), # bfgs_iterations
            zeros(min(degree * 5, 25))  # function_values
        )
        push!(results_1010, result)
    end
    
    # Add this single subdomain to the dictionary
    subdomain_results["1010"] = results_1010
    
    # Add 15 empty subdomains (mimicking the real issue)
    for i in 0:15
        label = string(i, base=2, pad=4)
        if label != "1010"
            subdomain_results[label] = EnhancedDegreeAnalysisResult[]
        end
    end
    
    println("Created test data with:")
    println("  - 16 total subdomains")
    println("  - 1 subdomain with results (1010)")
    println("  - 15 empty subdomains")
    
    # Test the original plotting function (would create 16 identical curves)
    println("\nTesting fixed plotting function...")
    fig = plot_l2_convergence_fixed(
        subdomain_results,
        title="Fixed: L² Convergence (Non-Empty Subdomains Only)",
        tolerance_line=0.01,
        save_plots=true,
        plots_directory="test_outputs"
    )
    
    println("Fixed plotting complete!")
    
    return fig, subdomain_results
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    fig, data = test_plotting_fix()
end