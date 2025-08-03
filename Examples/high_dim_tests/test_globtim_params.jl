"""
Test Globtim Parameters

Simple test to verify Globtim is using the correct parameters.
"""

using Globtim
using Printf

println("=== Testing Globtim Parameters ===")

# Simple 4D test function
function simple_4d_function(y)
    return sum(y.^2) + 0.1 * prod(y)
end

println("\n1. Testing with degree=2, samples=120...")

try
    results = safe_globtim_workflow(
        simple_4d_function,
        dim=4,
        center=zeros(4),
        sample_range=1.0,
        degree=2,                 # Explicitly degree 2
        GN=120,                  # 120 samples
        enable_hessian=false,    # Disable for speed
        basis=:chebyshev,
        precision=RationalPrecision,
        max_retries=1
    )
    
    println("✅ SUCCESS with degree=2!")
    println("   - L2 error: $(@sprintf("%.2e", results.polynomial.nrm))")
    println("   - Critical points: $(nrow(results.critical_points))")
    println("   - Minima: $(nrow(results.minima))")
    
catch e
    println("❌ FAILED with degree=2: $e")
end

println("\n2. Testing with degree=1, samples=50...")

try
    results = safe_globtim_workflow(
        simple_4d_function,
        dim=4,
        center=zeros(4),
        sample_range=1.0,
        degree=1,                 # Very low degree
        GN=50,                   # Fewer samples
        enable_hessian=false,
        basis=:chebyshev,
        precision=RationalPrecision,
        max_retries=1
    )
    
    println("✅ SUCCESS with degree=1!")
    println("   - L2 error: $(@sprintf("%.2e", results.polynomial.nrm))")
    println("   - Critical points: $(nrow(results.critical_points))")
    println("   - Minima: $(nrow(results.minima))")
    
catch e
    println("❌ FAILED with degree=1: $e")
end

println("\n3. Testing what parameters Globtim actually uses...")

# Let's see what the minimum requirements are
println("Checking Globtim's parameter validation...")

for degree in [1, 2, 3]
    for samples in [20, 50, 100, 150, 200]
        try
            # Just test the parameter validation, don't run full workflow
            println("   Testing degree=$degree, samples=$samples...")
            
            results = safe_globtim_workflow(
                simple_4d_function,
                dim=4,
                center=zeros(4),
                sample_range=0.5,  # Small range for speed
                degree=degree,
                GN=samples,
                enable_hessian=false,
                max_retries=1
            )
            
            println("   ✅ degree=$degree, samples=$samples WORKS")
            break  # Found working combination for this degree
            
        catch e
            if occursin("sufficient samples", string(e))
                continue  # Try more samples
            else
                println("   ❌ degree=$degree, samples=$samples: $e")
                break
            end
        end
    end
end
