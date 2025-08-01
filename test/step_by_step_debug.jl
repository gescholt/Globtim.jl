"""
Comprehensive Step-by-Step Debug Script for AdaptivePrecision

Run this and tell me exactly where it fails and what error message you get.
I'll then provide specific fixes for each issue.
"""

println("=" ^ 60)
println("COMPREHENSIVE ADAPTIVEPRECISION DEBUG")
println("=" ^ 60)

# Step 0: Environment check
println("\n[STEP 0] Environment Check")
println("Julia version: ", VERSION)
println("Working directory: ", pwd())
println("LOAD_PATH: ", LOAD_PATH)

# Step 1: Basic module loading
println("\n[STEP 1] Testing basic module loading...")
try
    # First try to load without using
    println("  Attempting to load Globtim module...")
    import Globtim
    println("  ✓ Globtim imported successfully")

    # Now try using
    println("  Attempting to use Globtim...")
    using Globtim
    println("  ✓ Globtim using successful")

catch e
    println("  ✗ FAILED at module loading")
    println("  Error type: ", typeof(e))
    println("  Error message: ", e)
    println("\n  DIAGNOSIS: Module loading issue")
    println("  SOLUTION: Check if Globtim.jl is in the right location and has no syntax errors")
    exit(1)
end

# Step 2: Check enum definition
println("\n[STEP 2] Testing PrecisionType enum...")
try
    println("  Checking if PrecisionType is defined...")
    @assert @isdefined PrecisionType
    println("  ✓ PrecisionType is defined")

    println("  Listing all PrecisionType instances...")
    all_types = instances(PrecisionType)
    for (i, pt) in enumerate(all_types)
        println("    $i. $pt")
    end

    println("  Checking if AdaptivePrecision exists...")
    if @isdefined AdaptivePrecision
        println("  ✓ AdaptivePrecision is defined")
        println("    Type: $(typeof(AdaptivePrecision))")
        println("    Value: $AdaptivePrecision")
    else
        println("  ✗ AdaptivePrecision is NOT defined")
        println("\n  DIAGNOSIS: AdaptivePrecision not in enum or not exported")
        println("  SOLUTION: Check src/Globtim.jl enum definition and exports")
        exit(1)
    end

catch e
    println("  ✗ FAILED at enum check")
    println("  Error: ", e)
    exit(1)
end

# Step 3: Test internal function access
println("\n[STEP 3] Testing internal function access...")
try
    println("  Checking if _convert_value is accessible...")
    if hasmethod(Globtim._convert_value, (Any, PrecisionType))
        println("  ✓ _convert_value method exists")

        # Test with Float64Precision first
        println("  Testing _convert_value with Float64Precision...")
        val_f64 = Globtim._convert_value(1.0, Float64Precision)
        println("    Result: $val_f64 (type: $(typeof(val_f64)))")

        # Test with AdaptivePrecision
        println("  Testing _convert_value with AdaptivePrecision...")
        val_adaptive = Globtim._convert_value(1.0, AdaptivePrecision)
        println("    Result: $val_adaptive (type: $(typeof(val_adaptive)))")

        if val_adaptive isa BigFloat
            println("  ✓ AdaptivePrecision produces BigFloat")
        else
            println("  ✗ AdaptivePrecision does NOT produce BigFloat")
            println("    Expected: BigFloat, Got: $(typeof(val_adaptive))")
        end

    else
        println("  ✗ _convert_value method not found")
        println("  Available methods:")
        for m in methods(Globtim._convert_value)
            println("    ", m)
        end
    end

catch e
    println("  ✗ FAILED at internal function test")
    println("  Error: ", e)
    println("\n  DIAGNOSIS: Internal function issue")
    println("  SOLUTION: Check _convert_value implementation in src/cheb_pol.jl")
    exit(1)
end