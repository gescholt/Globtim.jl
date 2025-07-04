# ================================================================================
# Run All 4D Deuflhard Examples
# ================================================================================
#
# This script runs all three main examples in sequence.
# Each example saves its outputs to a timestamped directory.
#

println("="^80)
println("4D Deuflhard Degree Analysis Examples")
println("="^80)

# Test shared utilities first
println("\n1. Testing shared utilities...")
include("test/test_shared_utilities.jl")

println("\n" * "="^80)
println("\nPress Enter to continue with Example A: Full Domain Analysis...")
readline()

# Example A: Full domain analysis
println("\n2. Running Example A: Full Domain Analysis")
println("   - Single polynomial on [-1,1]⁴")
println("   - Degree sweep from 2 to 12")
println("   - Expected runtime: 2-5 minutes")
println()

include("examples/01_full_domain.jl")

println("\n" * "="^80)
println("\nPress Enter to continue with Example B: Fixed Degree Subdivision...")
readline()

# Example B: Fixed degree subdivision
println("\n3. Running Example B: Fixed Degree Subdivision")
println("   - Testing degrees [4, 6, 8] on all 16 subdomains")
println("   - Identifies spatial difficulty patterns")
println("   - Expected runtime: 5-10 minutes per degree")
println()

include("examples/02_subdivided_fixed.jl")

println("\n" * "="^80)
println("\nPress Enter to continue with Example C: Adaptive Subdivision...")
readline()

# Example C: Adaptive subdivision
println("\n4. Running Example C: Adaptive Subdivision")
println("   - Adaptively increase degree until L²-tolerance met")
println("   - Maps computational requirements per region")
println("   - Expected runtime: 10-20 minutes")
println()

include("examples/03_subdivided_adaptive.jl")

println("\n" * "="^80)
println("\nAll examples completed!")
println("Check the outputs/ directory for results:")
println("  - outputs/full_domain_*/")
println("  - outputs/subdivided_fixed_*/")
println("  - outputs/subdivided_adaptive_*/")
println("="^80)