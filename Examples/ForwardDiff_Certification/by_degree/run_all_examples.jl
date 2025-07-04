# ================================================================================
# Run All 4D Deuflhard Examples - (+,-,+,-) Orthant
# ================================================================================
#
# This script runs all three main examples in sequence for the (+,-,+,-) orthant.
# All outputs are saved to a single shared directory with HH-MM timestamp.
#

println("="^80)
println("4D Deuflhard Degree Analysis Examples - (+,-,+,-) Orthant")
println("="^80)
println("\nAll outputs will be saved to: outputs/HH-MM/")

# Test shared utilities first
println("\n1. Testing shared utilities...")
include("test/test_shared_utilities.jl")

# Add shared directory to load path for enhanced utilities
push!(LOAD_PATH, joinpath(@__DIR__, "shared"))
using EnhancedAnalysisUtilities
using EnhancedPlottingUtilities

println("\n" * "="^80)

# Example A: Orthant domain analysis
println("\n2. Running Example A: (+,-,+,-) Orthant Analysis")
println("   - Single polynomial on [0,1]×[-1,0]×[0,1]×[-1,0]")
println("   - Degree sweep from 2 to 6")
println("   - Expected runtime: 1-2 minutes")
println()

include("examples/01_full_domain.jl")
run_orthant_domain_analysis()

println("\n" * "="^80)

# Example B: Fixed degree subdivision
println("\n3. Running Example B: Fixed Degree Subdivision")
println("   - Testing degrees [2, 3, 4, 5, 6] on all 16 subdomains")
println("   - Identifies spatial difficulty patterns")
println("   - Expected runtime: 3-5 minutes total")
println()

include("examples/02_subdivided_fixed.jl")
run_fixed_degree_subdivision_analysis()

println("\n" * "="^80)

# Example C: Adaptive subdivision
println("\n4. Running Example C: Adaptive Subdivision")
println("   - Adaptively increase degree until L²-tolerance met")
println("   - Maps computational requirements per region")
println("   - Expected runtime: 5-10 minutes")
println()

include("examples/03_subdivided_adaptive.jl")
all_results, degree_requirements, output_dir = run_adaptive_subdivision_analysis()

println("\n" * "="^80)
println("\nAll examples completed!")
println("Check the outputs/ directory for results:")
println("  - outputs/full_domain_*/")
println("  - outputs/subdivided_fixed_*/")
println("  - outputs/subdivided_adaptive_*/")
println("="^80)