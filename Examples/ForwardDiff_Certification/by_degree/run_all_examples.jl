# ================================================================================
# Run Degree Convergence Analysis
# ================================================================================
#
# This script runs a comprehensive analysis of polynomial degree convergence for
# the 4D Deuflhard function, analyzing both minimizers and ALL critical points.
#
# Output Structure (all saved to outputs/enhanced_v3_HH-MM/):
# 
# From the main analysis (run_enhanced_analysis_v2):
# - enhanced_l2_convergence.png       : L2-norm convergence with subdomain traces
# - enhanced_distance_convergence.png : Distance convergence for MINIMIZERS with subdomain traces
# - summary.csv                       : Summary statistics by degree
# - recovery_degree_X.csv            : Detailed recovery data for each degree
#
# From the critical point analysis (NEW):
# - critical_point_distances.png             : Distance convergence for ALL 25 critical points
# - critical_point_distances_capture_rate.png : Percentage of critical points captured
# - critical_point_distances.csv             : Detailed distance statistics for all critical points
#
# ================================================================================

using Dates, CSV

# Polynomial degrees to test
const DEGREES = [2, 3, 4, 5, 6, 7, 8]

# Grid points per dimension (fixed - no tolerance adaptation)
const GN = 20

# threshold for capture of local minimizers
const TRESH = 0.1

# Load and run the enhanced analysis v3
include("examples/degree_convergence_analysis_enhanced_v3.jl")

println("\n🚀 Running Enhanced Analysis V3 with per-subdomain distance tracking...")
println("📊 This creates plots showing individual subdomain convergence traces")
println("   (similar to the L2-norm plot style)\n")

# CHANGE: Now capturing the additional computed points data AND output directory
summary_df, distance_data, all_computed_points, output_dir, computed_by_subdomain_by_degree = run_enhanced_analysis_v2(DEGREES, GN, analyze_global=true, threshold=TRESH)

# ================================================================================
# NEW: Analysis of ALL Critical Points (not just minima)
# ================================================================================

println("\n" * "="^80)
println("🔍 Analyzing distances to ALL critical points (minima AND saddles)...")
println("="^80)

# Load the critical point distance analysis module
include("examples/analyze_all_critical_point_distances.jl")

# Run the analysis
critical_results = analyze_critical_point_distances(all_computed_points, DEGREES, threshold=TRESH)

# Use the SAME output directory as the main analysis
plot_critical_point_distances(critical_results, 
                            output_file = joinpath(output_dir, "critical_point_distances.png"))

# Save the critical point analysis results
CSV.write(joinpath(output_dir, "critical_point_distances.csv"), critical_results)

println("\n📊 Critical point analysis complete!")
println("   All plots saved to: $(basename(output_dir))")

# ================================================================================
# NEW: Distance Matrix Analysis for ALL Critical Points
# ================================================================================

println("\n" * "="^80)
println("🔍 Creating distance matrix for all critical points...")
println("="^80)

# Load the distance matrix analysis module
include("examples/analyze_critical_point_distance_matrix.jl")

# Create and display the distance matrix
distance_matrix, matrix_df = create_critical_point_distance_matrix(all_computed_points, DEGREES)
display_distance_matrix(distance_matrix, DEGREES, 
                       CSV.read(joinpath(@__DIR__, "data/4d_all_critical_points_orthant.csv"), DataFrame),
                       threshold=TRESH)

# Save the distance matrix
CSV.write(joinpath(output_dir, "critical_point_distance_matrix.csv"), matrix_df)

# Load theoretical critical points for the plot
df_theory = CSV.read(joinpath(@__DIR__, "data/4d_all_critical_points_orthant.csv"), DataFrame)

# Create the new distance evolution plot
plot_distance_evolution(distance_matrix, DEGREES, df_theory,
                       output_file = joinpath(output_dir, "critical_point_distance_evolution.png"))

# Analyze convergence patterns
patterns = analyze_convergence_patterns(distance_matrix, DEGREES, df_theory)

println("\n📊 Convergence Analysis:")
if haskey(patterns, "min_convergence_rate")
    println("   Minima convergence rate: $(round(patterns["min_convergence_rate"], digits=2))")
end
if haskey(patterns, "saddle_convergence_rate")
    println("   Saddle convergence rate: $(round(patterns["saddle_convergence_rate"], digits=2))")
end

println("\n✅ Distance matrix saved to: $(joinpath(output_dir, "critical_point_distance_matrix.csv"))")

# ================================================================================
# Summary of Changes:
# ================================================================================
# 1. Modified run_enhanced_analysis_v2 to return all_computed_points_by_degree
# 2. Added analysis of distances to ALL 25 theoretical critical points
# 3. Created two new plots:
#    - critical_point_distances.png: Shows min/median/mean distances
#    - critical_point_distances_capture_rate.png: Shows % of points captured
# 4. Results show how well Globtim finds ALL critical points, not just minima