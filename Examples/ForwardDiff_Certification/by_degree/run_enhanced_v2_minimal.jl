# Minimal test of enhanced analysis v2 with just degree 3

include("examples/degree_convergence_analysis_enhanced_v2.jl")

# Run with minimal parameters
println("🚀 Running minimal enhanced analysis (degree 3 only)...")
summary_df, distance_data = run_enhanced_analysis_v2(
    [3],  # Just one degree for quick test
    16,   # Grid points
    analyze_global = true
)

println("\n✅ Analysis completed!")
println("Summary data:")
println(summary_df)