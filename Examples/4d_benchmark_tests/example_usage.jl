"""
4D Benchmark Testing - Example Usage

This script demonstrates how to use the 4D benchmark testing infrastructure
with practical examples and explanations.

Run this script to see the framework in action with a simple example.
"""

using Pkg
Pkg.activate(".")

using Globtim
using DataFrames
using Printf

# Include our framework
include("benchmark_4d_framework.jl")
include("plotting_4d.jl")

println("🚀 4D Benchmark Framework - Example Usage")
println("=" * 60)

# ============================================================================
# EXAMPLE 1: SINGLE FUNCTION ANALYSIS
# ============================================================================

println("\n📊 Example 1: Analyzing Sphere function in 4D")
println("-" * 40)

# Analyze the Sphere function with different degrees
sphere_results = analyze_4d_function(
    :Sphere,
    degrees=[4, 6, 8],
    samples=[50, 100],
    sparsification_thresholds=[1e-3, 1e-4],
    track_convergence=true,
    config_name="example"
)

println("\n📈 Results Summary:")
for result in sphere_results
    println("  Degree $(result.degree), $(result.sample_count) samples:")
    println("    - L2 error: $(result.l2_error)")
    println("    - Convergence rate: $(result.convergence_metrics.convergence_rate*100)%")
    println("    - Mean distance to global min: $(result.convergence_metrics.mean_distance_to_global)")
    println("    - Construction time: $(result.construction_time)s")
end

# ============================================================================
# EXAMPLE 2: SPARSIFICATION ANALYSIS
# ============================================================================

println("\n📊 Example 2: Sparsification Analysis")
println("-" * 40)

# Take the first result for detailed sparsification analysis
if !isempty(sphere_results)
    result = sphere_results[1]
    
    println("Analyzing sparsification for Sphere function (degree $(result.degree)):")
    
    for (i, sparse_result) in enumerate(result.sparsification_results.results)
        println("  Threshold $(sparse_result.threshold):")
        println("    - Original coefficients: $(sparse_result.original_nnz)")
        println("    - After sparsification: $(sparse_result.new_nnz)")
        println("    - Sparsity gain: $(sparse_result.sparsity_gain*100)%")
        println("    - L2 ratio preserved: $(sparse_result.l2_ratio*100)%")
    end
end

# ============================================================================
# EXAMPLE 3: CONVERGENCE TRACKING
# ============================================================================

println("\n📊 Example 3: Convergence Tracking")
println("-" * 40)

# Run a detailed convergence study
convergence_data = convergence_study_4d(:Sphere, degrees=[4, 6], track_distance=true)

println("Convergence study results:")
for data in convergence_data
    println("  Degree $(data.degree):")
    println("    - L2 error: $(data.l2_error)")
    if haskey(data, :tracker)
        println("    - Points analyzed: $(length(data.tracker.initial_points))")
        println("    - Mean final distance to global: $(mean(data.tracker.distances_to_global))")
        println("    - Mean gradient norm: $(mean(data.tracker.gradient_norms))")
    end
end

# ============================================================================
# EXAMPLE 4: DISTANCE CALCULATIONS
# ============================================================================

println("\n📊 Example 4: Distance Calculations")
println("-" * 40)

# Demonstrate distance calculations
if !isempty(sphere_results)
    result = sphere_results[1]
    
    # Get the global minimum for Sphere function
    sphere_info = BENCHMARK_4D_FUNCTIONS[:Sphere]
    global_min = sphere_info.global_min
    
    println("Sphere function global minimum: $global_min")
    
    if nrow(result.critical_points_df) > 0
        # Calculate distances for first few critical points
        n_points = min(5, nrow(result.critical_points_df))
        
        println("Distance from first $n_points critical points to global minimum:")
        for i in 1:n_points
            point = [result.critical_points_df[i, Symbol("x$j")] for j in 1:4]
            distance = norm(point - global_min)
            function_value = result.critical_points_df[i, :z]
            
            println("  Point $i: distance = $(distance), f(x) = $(function_value)")
        end
    end
end

# ============================================================================
# EXAMPLE 5: COMPARISON ACROSS FUNCTIONS
# ============================================================================

println("\n📊 Example 5: Comparing Multiple Functions")
println("-" * 40)

# Compare a few functions quickly
comparison_functions = [:Sphere, :Rosenbrock, :Griewank]
comparison_results = []

for func_name in comparison_functions
    println("Analyzing $func_name...")
    try
        results = analyze_4d_function(
            func_name,
            degrees=[6],  # Single degree for quick comparison
            samples=[100],
            sparsification_thresholds=[1e-3],
            track_convergence=true,
            config_name="comparison"
        )
        append!(comparison_results, results)
    catch e
        println("  ❌ Error analyzing $func_name: $e")
    end
end

println("\nComparison Results:")
println("Function".ljust(15) * "L2 Error".ljust(12) * "Conv Rate".ljust(12) * "Mean Dist")
println("-" ^ 50)

for result in comparison_results
    l2_str = @sprintf("%.2e", result.l2_error)
    conv_str = @sprintf("%.1f%%", result.convergence_metrics.convergence_rate * 100)
    dist_str = isnan(result.convergence_metrics.mean_distance_to_global) ? 
               "N/A" : @sprintf("%.3f", result.convergence_metrics.mean_distance_to_global)
    
    println("$(string(result.function_name))".ljust(15) * 
            l2_str.ljust(12) * 
            conv_str.ljust(12) * 
            dist_str)
end

# ============================================================================
# EXAMPLE 6: CREATING PLOTS (if CairoMakie is available)
# ============================================================================

println("\n📊 Example 6: Creating Plots")
println("-" * 40)

try
    # Create a simple output directory for this example
    output_dir = "Examples/4d_benchmark_tests/example_output"
    if !isdir(output_dir)
        mkpath(output_dir)
    end
    
    # Generate plots if we have results
    if !isempty(comparison_results)
        println("Generating sparsification analysis plots...")
        plot_sparsification_analysis(comparison_results, output_dir, save_plots=true, show_plots=false)
        
        println("Generating convergence comparison plots...")
        plot_convergence_comparison(comparison_results, output_dir, save_plots=true, show_plots=false)
        
        println("✅ Plots saved to: $output_dir")
    end
    
    if !isempty(convergence_data)
        println("Generating distance to minimizers plots...")
        plot_distance_to_minimizers(convergence_data, output_dir, save_plots=true, show_plots=false)
    end
    
catch e
    println("⚠️  Plotting failed (CairoMakie may not be available): $e")
    println("   Install CairoMakie with: using Pkg; Pkg.add(\"CairoMakie\")")
end

# ============================================================================
# SUMMARY AND NEXT STEPS
# ============================================================================

println("\n✅ Example Usage Completed!")
println("=" * 60)

println("\n🎯 What you've seen:")
println("  ✓ Single function analysis with sparsification")
println("  ✓ Convergence tracking and distance calculations")
println("  ✓ Multi-function comparison")
println("  ✓ Automated plotting and visualization")

println("\n🚀 Next steps to try:")
println("  1. Run the full benchmark suite:")
println("     julia Examples/4d_benchmark_tests/run_4d_benchmark_study.jl quick")
println()
println("  2. Analyze a specific function in detail:")
println("     julia Examples/4d_benchmark_tests/run_4d_benchmark_study.jl custom Rosenbrock")
println()
println("  3. Run comprehensive analysis:")
println("     julia Examples/4d_benchmark_tests/run_4d_benchmark_study.jl standard")
println()
println("  4. Explore the framework functions:")
println("     - analyze_4d_function() for detailed single function analysis")
println("     - convergence_study_4d() for convergence tracking")
println("     - run_4d_benchmark_suite() for comprehensive testing")

println("\n📚 Available benchmark functions:")
for func_name in keys(BENCHMARK_4D_FUNCTIONS)
    func_info = BENCHMARK_4D_FUNCTIONS[func_name]
    println("  $func_name - Domain: $(func_info.domain), Global min: $(func_info.global_min)")
end

println("\n🎉 Happy benchmarking!")
