# Quick verification script for updated demos
#
# This script checks that the updated demo files load correctly
# and have access to the enhanced structures.

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))

println("=== Verifying Updated Demo Files ===\n")

# Test 1: Check includes work
println("1. Testing component includes...")
try
    redirect_stdout(devnull) do
        include("step1_bfgs_enhanced.jl")
        include("step4_ultra_precision.jl")
    end
    println("   ✓ Enhanced components loaded successfully")
catch e
    println("   ✗ Error loading components: $e")
end

# Test 2: Check structs are defined
println("\n2. Checking struct definitions...")
structs_to_check = [:BFGSConfig, :BFGSResult, :UltraPrecisionConfig, :StageResult]
for s in structs_to_check
    if isdefined(Main, s)
        println("   ✓ $s is defined")
    else
        println("   ✗ $s is NOT defined")
    end
end

# Test 3: Check functions are available
println("\n3. Checking function definitions...")
functions_to_check = [
    :enhanced_bfgs_refinement,
    :ultra_precision_refinement,
    :validate_precision_achievement,
    :format_stage_history_table
]
for f in functions_to_check
    if isdefined(Main, f)
        println("   ✓ $f is defined")
    else
        println("   ✗ $f is NOT defined")
    end
end

# Test 4: Quick functionality test
println("\n4. Quick functionality test...")
try
    config = BFGSConfig()
    println("   ✓ BFGSConfig creation works")
    println("     Default tolerance: $(config.standard_tolerance)")
    
    ultra_config = UltraPrecisionConfig()
    println("   ✓ UltraPrecisionConfig creation works")
    println("     Max stages: $(ultra_config.max_precision_stages)")
catch e
    println("   ✗ Error in functionality test: $e")
end

println("\n=== Verification Complete ===")
println("\nTo test the updated demos:")
println("1. Run: julia trefethen_3d_complete_demo.jl")
println("2. Run: julia deuflhard_4d_complete.jl")
println("3. For a quick test: julia demo_enhancements.jl")