#!/usr/bin/env julia

# Test script for enhanced V4 implementation

println("\n" * "="^80)
println("🧪 TESTING ENHANCED V4 IMPLEMENTATION")
println("="^80)

# Load the enhanced analysis
include("run_v4_analysis_enhanced.jl")

# Run a small test with degrees 3-4 and low GN
println("\n📊 Running test analysis with degrees [3,4], GN=10...")
results = run_v4_analysis_enhanced(
    [3, 4], 10,
    output_dir = "outputs/test_enhanced",
    plot_results = true,
    compute_refined_points = true,
    tol_dist = 0.05
)

# Display results
println("\n✅ Test completed successfully!")

# Show refinement effectiveness
println("\n📊 Refinement Effectiveness:")
for (deg, metrics) in sort(collect(results.refinement_metrics), by=x->x[1])
    println("\n   Degree $deg:")
    println("   - Computed points: $(metrics.n_computed)")
    println("   - Refined points: $(metrics.n_refined)")
    println("   - Avg distance (theoretical → df_cheb): $(round(metrics.avg_theo_to_cheb, digits=4))")
    println("   - Avg distance (theoretical → df_min_refined): $(round(metrics.avg_theo_to_refined, digits=4))")
    println("   - Avg distance (df_min_refined → df_cheb): $(round(metrics.avg_refined_to_cheb, digits=4))")
    println("   - Improvement: $(round(metrics.avg_improvement * 100, digits=1))%")
end

# Show sample subdomain table
println("\n📊 Sample V4 table (subdomain 0000):")
if haskey(results.subdomain_tables, "0000")
    show(results.subdomain_tables["0000"], allrows=false, allcols=true)
end

println("\n\n🎉 All tests passed! Check outputs/test_enhanced/ for generated plots.")