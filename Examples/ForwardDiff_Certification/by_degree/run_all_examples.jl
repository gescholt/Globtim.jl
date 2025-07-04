# ================================================================================
# Run Analysis for First Plot Task
# ================================================================================
#
# Based on first_plot_task.md:
# - First: Simplified polynomial construction and L²-norm analysis
# - Second: Local minimizer convergence histogram
# - Third: Distance convergence from theoretical minimizers to critical points
# - Fourth: Manual distance computation for all 9 minimizers across 16 subdomains
#

println("="^80)
println("Running Analysis Based on first_plot_task.md")
println("="^80)

# Test shared utilities first
println("\n1. Testing shared utilities...")
include("test/test_shared_utilities.jl")

println("\n" * "="^80)

# Run combined L²-norm and distance analysis
println("\n2. Running L²-norm and Distance Analysis")
println("   - 16 subdomains of (+,-,+,-) orthant")
println("   - Fixed degrees [2, 3, 4, 5, 6]")
println("   - L²-norm convergence plot (16 subdomains vs full domain)")
println("   - Average separation distance (9 minimizers to all critical points)")
println()

include("examples/simplified_subdomain_analysis_new_distance.jl")
run_new_distance_analysis()

println("\n" * "="^80)
println("\nAll analyses completed!")
println("Check the outputs/ directory for results:")
println("  - outputs/analysis_HH-MM/ - Contains:")
println("    • L²-norm convergence plot")
println("    • Average separation distance plot")
println("    • CSV files with detailed results")
println("="^80)