# 04_histogram_visualization.jl
# Example showing how to use the new histogram visualization functions
# with actual Deuflhard 4D analysis results

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../"))

using Globtim
using DynamicPolynomials
using CairoMakie
using Dates
using DataFrames
using CSV

# Add shared modules
push!(LOAD_PATH, joinpath(@__DIR__, "../shared"))
using Common4DDeuflhard
using AnalysisUtilities
using PlottingUtilities
using TheoreticalPoints

"""
Run analysis and create histogram visualizations
"""
function run_histogram_demo()
    println("=== Histogram Visualization Demo ===")
    println("Running Deuflhard 4D analysis with histogram plots...")
    
    # Analysis parameters
    degrees = 4:2:12  # Test degrees 4, 6, 8, 10, 12
    center = [0.0, 0.0, 0.0, 0.0]
    range_val = 0.5
    tolerance_target = 0.0007
    
    # Get theoretical points
    theoretical_points, theoretical_types = get_4d_deuflhard_theoretical_points()
    println("Number of theoretical critical points: $(length(theoretical_points))")
    
    # Run analysis for each degree
    results = DegreeAnalysisResult[]
    println("\nAnalyzing degrees: ", degrees)
    
    for degree in degrees
        println("\nDegree $degree:")
        result = analyze_single_degree(
            deuflhard_4d_composite,
            degree,
            center,
            range_val,
            theoretical_points,
            theoretical_types,
            gn=GN_FIXED,
            tolerance_target=tolerance_target,
            basis=:chebyshev
        )
        push!(results, result)
        
        println("  L²-norm: $(result.l2_norm)")
        println("  Found $(result.n_successful_recoveries)/$(result.n_theoretical_points) points")
        println("  Success rate: $(round(result.success_rate * 100, digits=1))%")
    end
    
    # Create output directory
    output_dir = joinpath(@__DIR__, "../outputs", Dates.format(now(), "mm-dd_HH-MM"))
    mkpath(output_dir)
    
    # Generate standard plots
    println("\nGenerating standard convergence plots...")
    
    # L² convergence plot
    fig_l2 = plot_l2_convergence(results, 
                                title="L²-Norm Convergence",
                                tolerance_line=tolerance_target)
    save(joinpath(output_dir, "l2_convergence.png"), fig_l2)
    
    # Recovery rates plot
    fig_rates = plot_recovery_rates(results,
                                   title="Success Rates by Degree")
    save(joinpath(output_dir, "recovery_rates.png"), fig_rates)
    
    # Generate new histogram visualizations
    println("\nGenerating histogram visualizations...")
    
    # Recovery histogram with legend
    fig_hist1 = plot_recovery_histogram(results,
                                       title="Critical Point Recovery Analysis",
                                       show_legend=true)
    save(joinpath(output_dir, "recovery_histogram.png"), fig_hist1)
    println("  Saved: recovery_histogram.png")
    
    # Recovery histogram without legend (cleaner look)
    fig_hist2 = plot_recovery_histogram(results,
                                       title="Critical Point Recovery",
                                       show_legend=false)
    save(joinpath(output_dir, "recovery_histogram_clean.png"), fig_hist2)
    println("  Saved: recovery_histogram_clean.png")
    
    # Save results to CSV for future use
    df = DataFrame(
        degree = [r.degree for r in results],
        l2_norm = [r.l2_norm for r in results],
        n_theoretical = [r.n_theoretical_points for r in results],
        n_computed = [r.n_computed_points for r in results],
        n_found = [r.n_successful_recoveries for r in results],
        success_rate = [r.success_rate for r in results],
        min_min_success_rate = [r.min_min_success_rate for r in results],
        runtime_seconds = [r.runtime_seconds for r in results],
        converged = [r.converged for r in results]
    )
    CSV.write(joinpath(output_dir, "histogram_demo_results.csv"), df)
    
    println("\nAnalysis complete!")
    println("Output directory: $output_dir")
    println("\nSummary:")
    println("  - Tested $(length(degrees)) polynomial degrees")
    println("  - Best success rate: $(round(maximum(r.success_rate for r in results) * 100, digits=1))%")
    println("  - Convergence achieved: $(any(r.converged for r in results))")
    
    return results, output_dir
end

# Run the demo if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    results, output_dir = run_histogram_demo()
    
    # Display the histogram in the terminal (if supported)
    try
        fig = plot_recovery_histogram(results, show_legend=true)
        display(fig)
    catch e
        println("\nNote: Could not display plot in terminal. Check output files.")
    end
end