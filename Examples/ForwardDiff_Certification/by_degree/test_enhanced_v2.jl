# Quick test of enhanced analysis v2

include("examples/degree_convergence_analysis_enhanced_v2.jl")

# Run with just 2 degrees for quick testing
println("🧪 Running quick test with degrees [3, 4]...")
summary_df, distance_data = run_enhanced_analysis_v2([3, 4], 16, analyze_global=true)

println("\n✅ Test completed successfully!")