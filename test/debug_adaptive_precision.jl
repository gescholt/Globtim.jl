"""
Debug script for AdaptivePrecision issues
Run this step by step to identify where the problem occurs
"""

println("=== AdaptivePrecision Debug Script ===")

# Step 1: Try to load Globtim
println("\nStep 1: Loading Globtim...")
try
    using Globtim
    println("✓ Globtim loaded successfully")
catch e
    println("✗ Failed to load Globtim: $e")
    exit(1)
end

# Step 2: Check if AdaptivePrecision exists
println("\nStep 2: Checking AdaptivePrecision...")
try
    @assert @isdefined AdaptivePrecision
    println("✓ AdaptivePrecision is defined")
    println("  Type: $(typeof(AdaptivePrecision))")
    println("  Value: $AdaptivePrecision")
catch e
    println("✗ AdaptivePrecision not defined: $e")
    exit(1)
end

# Step 3: Check PrecisionType enum
println("\nStep 3: Checking PrecisionType enum...")
try
    @assert AdaptivePrecision isa PrecisionType
    println("✓ AdaptivePrecision is a PrecisionType")

    # List all precision types
    println("  Available precision types:")
    for pt in instances(PrecisionType)
        println("    - $pt")
    end
catch e
    println("✗ PrecisionType issue: $e")
    exit(1)
end

# Step 4: Test simple function creation
println("\nStep 4: Testing simple function...")
try
    f = x -> x[1]^2
    println("✓ Simple function created")

    # Test function evaluation
    test_val = f([0.5])
    println("  f([0.5]) = $test_val")
    @assert test_val ≈ 0.25
    println("✓ Function evaluation works")
catch e
    println("✗ Function creation failed: $e")
    exit(1)
end

# Step 5: Test test_input creation
println("\nStep 5: Testing test_input...")
try
    f = x -> x[1]^2
    TR = test_input(f, dim=1, center=[0.0], sample_range=1.0, tolerance=nothing)
    println("✓ test_input created successfully")
    println("  Dimension: $(TR.dim)")
    println("  Grid size: $(size(TR.grid))")
catch e
    println("✗ test_input creation failed: $e")
    exit(1)
end

# Step 6: Test Constructor with Float64Precision first
println("\nStep 6: Testing Constructor with Float64Precision...")
try
    f = x -> x[1]^2
    TR = test_input(f, dim=1, center=[0.0], sample_range=1.0, tolerance=nothing)
    pol_float = Constructor(TR, 2, precision=Float64Precision, verbose=0)
    println("✓ Constructor with Float64Precision works")
    println("  Coefficient type: $(eltype(pol_float.coeffs))")
    println("  Number of coefficients: $(length(pol_float.coeffs))")
catch e
    println("✗ Constructor with Float64Precision failed: $e")
    exit(1)
end

# Step 7: Test Constructor with AdaptivePrecision
println("\nStep 7: Testing Constructor with AdaptivePrecision...")
try
    f = x -> x[1]^2
    TR = test_input(f, dim=1, center=[0.0], sample_range=1.0, tolerance=nothing)
    pol_adaptive = Constructor(TR, 2, precision=AdaptivePrecision, verbose=0)
    println("✓ Constructor with AdaptivePrecision works")
    println("  Coefficient type: $(eltype(pol_adaptive.coeffs))")
    println("  Number of coefficients: $(length(pol_adaptive.coeffs))")

    # Check that coefficients are BigFloat
    @assert eltype(pol_adaptive.coeffs) <: BigFloat
    println("✓ Coefficients are BigFloat as expected")
catch e
    println("✗ Constructor with AdaptivePrecision failed: $e")
    println("Error details:")
    showerror(stdout, e)
    println()
    exit(1)
end

println("\n=== All Debug Steps Passed! ===")
println("AdaptivePrecision is working correctly.")