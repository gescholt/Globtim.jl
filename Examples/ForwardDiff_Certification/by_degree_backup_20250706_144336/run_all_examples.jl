# ================================================================================
# Run Degree Convergence Analysis
# ================================================================================

# Polynomial degrees to test
const DEGREES = [2, 3, 4, 5, 6, 7, 8, 9, 10]

# Grid points per dimension (fixed - no tolerance adaptation)
const GN = 16

# threshold for capture of local minimizers
const TRESH = 0.1

# Load and run the enhanced analysis v3
include("examples/degree_convergence_analysis_enhanced_v3.jl")

println("\n🚀 Running Enhanced Analysis V3 with per-subdomain distance tracking...")
println("📊 This creates plots showing individual subdomain convergence traces")
println("   (similar to the L2-norm plot style)\n")

summary_df, distance_data = run_enhanced_analysis_v2(DEGREES, GN, analyze_global=true, threshold=TRESH)