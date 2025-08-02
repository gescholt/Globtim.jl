"""
Debug L2-norm Computation Issues

Step-by-step debugging for L2-norm recomputation and sparsification analysis.
"""

using Globtim
using LinearAlgebra
using Printf

println("🔍 Step 1: L2-norm Debugging")
println("=" ^ 50)

# ============================================================================
# STEP 1A: Basic L2-norm Computation Test
# ============================================================================

println("\n📊 Step 1A: Basic L2-norm Computation")
println("-" ^ 40)

# Create a simple test case
f_simple(x) = x[1]^2 + x[2]^2 + 0.1*x[1]*x[2]
TR_simple = test_input(f_simple, dim=2, center=[0.0, 0.0], sample_range=1.0)

println("Testing simple quadratic function: f(x) = x₁² + x₂² + 0.1*x₁*x₂")
println("Domain: [-1, 1]²")

# Test different degrees
for degree in [4, 6, 8]
    println("\n🔬 Testing degree $degree:")
    
    # Construct polynomial
    pol = Constructor(TR_simple, degree)
    
    println("  Original L2 error: $(pol.nrm)")
    println("  Coefficient count: $(length(pol.coeffs))")
    println("  Non-zero coefficients: $(count(x -> abs(x) > 1e-15, pol.coeffs))")
    
    # Manual L2 norm calculation
    manual_l2 = discrete_l2_norm_riemann(pol, TR_simple)
    println("  Manual L2 calculation: $manual_l2")
    println("  Difference: $(abs(pol.nrm - manual_l2))")
    
    # Test sparsification
    sparse_result = sparsify_polynomial(pol, 1e-6, mode=:absolute)
    println("  After sparsification (1e-6):")
    println("    L2 ratio: $(sparse_result.l2_ratio)")
    println("    Zeroed coefficients: $(length(sparse_result.zeroed_indices))")
    
    # Recompute L2 for sparse polynomial
    sparse_l2 = discrete_l2_norm_riemann(sparse_result.polynomial, TR_simple)
    println("    Sparse L2 error: $sparse_l2")
    println("    Expected L2 error: $(pol.nrm * sparse_result.l2_ratio)")
    println("    L2 computation consistent: $(abs(sparse_l2 - pol.nrm * sparse_result.l2_ratio) < 1e-10)")
end

# ============================================================================
# STEP 1B: 4D L2-norm Test
# ============================================================================

println("\n📊 Step 1B: 4D L2-norm Test")
println("-" ^ 40)

# Test with 4D Sphere function
f_sphere = Sphere
TR_sphere = test_input(f_sphere, dim=4, center=zeros(4), sample_range=2.0)

println("Testing 4D Sphere function")
println("Domain: [-2, 2]⁴")

degree = 6
pol_4d = Constructor(TR_sphere, degree)

println("\n🔬 4D Polynomial Analysis:")
println("  L2 error: $(pol_4d.nrm)")
println("  Total coefficients: $(length(pol_4d.coeffs))")

# Analyze coefficient distribution
coeffs_abs = abs.(pol_4d.coeffs)
sort!(coeffs_abs, rev=true)

println("  Coefficient statistics:")
println("    Largest: $(coeffs_abs[1])")
println("    Median: $(coeffs_abs[length(coeffs_abs)÷2])")
println("    Smallest non-zero: $(coeffs_abs[findfirst(x -> x > 1e-15, coeffs_abs[end:-1:1])])")

# Test multiple sparsification thresholds
thresholds = [1e-10, 1e-8, 1e-6, 1e-4]
println("\n  Sparsification analysis:")

for threshold in thresholds
    sparse_result = sparsify_polynomial(pol_4d, threshold, mode=:absolute)
    kept_coeffs = length(pol_4d.coeffs) - length(sparse_result.zeroed_indices)
    sparsity_percent = (length(sparse_result.zeroed_indices) / length(pol_4d.coeffs)) * 100
    
    println("    Threshold $threshold:")
    println("      Kept: $kept_coeffs, Sparsity: $(sparsity_percent)%")
    println("      L2 ratio: $(sparse_result.l2_ratio)")
    
    # Verify L2 computation
    sparse_l2 = discrete_l2_norm_riemann(sparse_result.polynomial, TR_sphere)
    expected_l2 = pol_4d.nrm * sparse_result.l2_ratio
    l2_consistent = abs(sparse_l2 - expected_l2) < 1e-10
    
    println("      L2 consistent: $l2_consistent")
    if !l2_consistent
        println("        Computed: $sparse_l2")
        println("        Expected: $expected_l2")
        println("        Difference: $(abs(sparse_l2 - expected_l2))")
    end
end

# ============================================================================
# STEP 1C: Investigate L2-norm Recomputation
# ============================================================================

println("\n📊 Step 1C: L2-norm Recomputation Investigation")
println("-" ^ 40)

# Test the specific case that's causing issues
println("Investigating the reported L2-norm issue...")
println("Current L2-norm: 120.08037327760198")

# Try to reproduce the issue
f_test(x) = sum(x.^2) + 0.1*sum(x[1:end-1] .* x[2:end])  # Simple test function
TR_test = test_input(f_test, dim=4, center=zeros(4), sample_range=3.0)

pol_test = Constructor(TR_test, 8)
println("\nTest polynomial (degree 8, 4D):")
println("  L2 error: $(pol_test.nrm)")
println("  Total terms: $(length(pol_test.coeffs))")

# Check if we can reproduce the specific numbers
if abs(pol_test.nrm - 120.08037327760198) < 1.0
    println("  ✅ Similar L2 error magnitude - investigating further")
    
    # Detailed coefficient analysis
    coeffs_abs = abs.(pol_test.coeffs)
    sort!(coeffs_abs, rev=true)
    
    println("  Largest coefficient: $(coeffs_abs[1])")
    println("  Smallest coefficient: $(coeffs_abs[end])")
    
    # Test the specific thresholds mentioned
    for threshold in [1e-10, 1e-8, 1e-6]
        sparse_result = sparsify_polynomial(pol_test, threshold, mode=:absolute)
        kept = length(pol_test.coeffs) - length(sparse_result.zeroed_indices)
        sparsity = (length(sparse_result.zeroed_indices) / length(pol_test.coeffs)) * 100
        
        println("  Threshold $threshold: $kept kept, $(sparsity)% sparse")
    end
else
    println("  Different L2 error: $(pol_test.nrm) vs 120.08037327760198")
end

# ============================================================================
# STEP 1D: Manual L2-norm Verification
# ============================================================================

println("\n📊 Step 1D: Manual L2-norm Verification")
println("-" ^ 40)

# Create a very simple case where we can verify manually
f_manual(x) = x[1]^2  # Simple function
TR_manual = test_input(f_manual, dim=1, center=[0.0], sample_range=1.0)

pol_manual = Constructor(TR_manual, 4)
println("Simple 1D test: f(x) = x²")
println("  L2 error: $(pol_manual.nrm)")

# Manual verification
# For f(x) = x², the exact polynomial should have very small error
# Let's check the coefficients
println("  Coefficients: $(pol_manual.coeffs)")

# Evaluate at test points
test_points = [-0.5, 0.0, 0.5]
println("  Function vs Polynomial evaluation:")
for pt in test_points
    f_val = f_manual([pt])
    p_val = pol_manual.polynomial([pt])
    error = abs(f_val - p_val)
    println("    x=$pt: f=$(f_val), p=$(p_val), error=$error")
end

println("\n✅ Step 1 Debugging Complete")
println("Check the output above for L2-norm computation consistency.")
