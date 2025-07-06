# ================================================================================
# Run Degree Convergence Analysis
# ================================================================================

# Polynomial degrees to test
const DEGREES = [2, 3, 4, 5, 6]

# Grid points per dimension (fixed - no tolerance adaptation)
const GN = 20

# Load and run the enhanced analysis v2
include("examples/degree_convergence_analysis_enhanced_v2.jl")

println("\n🚀 Running Enhanced Analysis V2 with improved visualizations...")
summary_df, distance_data = run_enhanced_analysis_v2(DEGREES, GN, analyze_global=true)