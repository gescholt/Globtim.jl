#!/usr/bin/env julia

# Standalone script to run enhanced V4 analysis
# This avoids module redefinition issues

# Navigate to v4 directory if needed
cd(@__DIR__)

# Load and run enhanced analysis
include("run_v4_analysis_enhanced.jl")

# Run with your parameters
println("\n🚀 Running enhanced V4 analysis...")
results = run_v4_analysis_enhanced(
    [3, 4], 20,
    output_dir = "outputs/enhanced_analysis",
    plot_results = true,
    compute_refined_points = true
)

println("\n✅ Analysis complete! Check outputs/enhanced_analysis/ for results.")

# Display refinement metrics
if isa(results, NamedTuple) && haskey(results, :refinement_metrics)
    println("\n📊 Refinement Effectiveness:")
    for (deg, metrics) in sort(collect(results.refinement_metrics), by=x->x[1])
        println("   Degree $deg: $(metrics.n_computed) → $(metrics.n_refined) points")
        println("            Improvement: $(round(metrics.avg_improvement * 100, digits=1))%")
    end
end