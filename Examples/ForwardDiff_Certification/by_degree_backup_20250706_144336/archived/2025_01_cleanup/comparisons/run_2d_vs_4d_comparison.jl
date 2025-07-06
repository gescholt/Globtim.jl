# ================================================================================
# Run 2D vs 4D Critical Point Analysis Comparison
# ================================================================================

println("🚀 Starting 2D vs 4D Critical Point Analysis...")
println("=" ^ 80)

# Run the 2D analysis
println("\n📊 STEP 1: 2D Analysis")
println("-" ^ 40)
include("analyze_2d_orthant_classification.jl")

println("\n\n\n")
println("=" ^ 80)

# Run the comparison
println("\n📊 STEP 2: 2D vs 4D Comparison")
println("-" ^ 40)
include("compare_2d_vs_4d_analysis.jl")

println("\n\n")
println("🎉 Analysis complete!")
println("📄 Summary saved to: 2D_vs_4D_ANALYSIS_SUMMARY.md")