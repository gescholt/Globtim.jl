"""
Debug Legendre + AdaptivePrecision Issue

This script investigates and provides workarounds for the Legendre polynomial
construction issue with AdaptivePrecision.

The issue: Legendre polynomial code tries to use `//` (rational division) 
with BigFloat types from AdaptivePrecision, but BigFloat doesn't support `//`.

Usage:
    julia --project=. Examples/debug_legendre_issue.jl
"""

using Pkg
Pkg.activate(".")

using Globtim
using DynamicPolynomials
using Printf

println("🔍 Debugging Legendre + AdaptivePrecision Issue")
println("=" ^ 50)

# ============================================================================
# ISSUE REPRODUCTION
# ============================================================================

"""
    test_legendre_issue()

Reproduce the Legendre + AdaptivePrecision issue.
"""
function test_legendre_issue()
    println("\n🧪 Reproducing the issue...")
    
    # Create simple test input
    TR = test_input(shubert_4d, dim=4, center=[0.0,0.0,0.0,0.0], GN=6, 
                   sample_range=2.0, degree_max=6)
    
    # Test Chebyshev (should work)
    println("Testing Chebyshev + AdaptivePrecision...")
    try
        cheb_poly = Constructor(TR, 4, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
        println("✅ Chebyshev works: L2=$(cheb_poly.nrm)")
    catch e
        println("❌ Chebyshev failed: $e")
    end
    
    # Test Legendre (should fail)
    println("\nTesting Legendre + AdaptivePrecision...")
    try
        leg_poly = Constructor(TR, 4, basis=:legendre, precision=AdaptivePrecision, verbose=0)
        println("✅ Legendre works: L2=$(leg_poly.nrm)")
    catch e
        println("❌ Legendre failed: $e")
        println("   This is the expected error due to BigFloat // BigFloat issue")
    end
    
    # Test Legendre with Float64 (should work)
    println("\nTesting Legendre + Float64Precision...")
    try
        leg_poly_f64 = Constructor(TR, 4, basis=:legendre, precision=Float64Precision, verbose=0)
        println("✅ Legendre + Float64 works: L2=$(leg_poly_f64.nrm)")
    catch e
        println("❌ Legendre + Float64 failed: $e")
    end
end

# ============================================================================
# WORKAROUND SOLUTIONS
# ============================================================================

"""
    compare_bases_with_workaround(degree=4, samples=6)

Compare Chebyshev vs Legendre with proper error handling.
"""
function compare_bases_with_workaround(degree=4, samples=6)
    println("\n🔧 Basis Comparison with Workaround")
    println("-" ^ 40)
    
    # Create test input
    TR = test_input(shubert_4d, dim=4, center=[0.0,0.0,0.0,0.0], GN=samples, 
                   sample_range=2.0, degree_max=degree+2)
    
    # Construct Chebyshev with AdaptivePrecision
    println("Constructing Chebyshev (AdaptivePrecision)...")
    cheb_adaptive = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
    
    # Construct Chebyshev with Float64 for comparison
    println("Constructing Chebyshev (Float64)...")
    cheb_f64 = Constructor(TR, degree, basis=:chebyshev, precision=Float64Precision, verbose=0)
    
    # Construct Legendre with Float64 (workaround)
    println("Constructing Legendre (Float64 - workaround)...")
    leg_f64 = Constructor(TR, degree, basis=:legendre, precision=Float64Precision, verbose=0)
    
    # Analysis
    println("\n📊 Results:")
    @printf "Chebyshev (Adaptive): L2=%.6e, coeffs=%d\n" cheb_adaptive.nrm length(cheb_adaptive.coeffs)
    @printf "Chebyshev (Float64):  L2=%.6e, coeffs=%d\n" cheb_f64.nrm length(cheb_f64.coeffs)
    @printf "Legendre  (Float64):  L2=%.6e, coeffs=%d\n" leg_f64.nrm length(leg_f64.coeffs)
    
    # Sparsity comparison (using Float64 versions for fair comparison)
    println("\n✂️  Sparsity Analysis (Float64 for fair comparison):")
    
    @polyvar x[1:4]
    
    # Convert to monomial basis
    cheb_mono = to_exact_monomial_basis(cheb_f64, variables=x)
    leg_mono = to_exact_monomial_basis(leg_f64, variables=x)
    
    # Analyze coefficients
    cheb_coeffs = abs.(Float64.([coefficient(t) for t in terms(cheb_mono)]))
    leg_coeffs = abs.(Float64.([coefficient(t) for t in terms(leg_mono)]))
    
    threshold = 1e-10
    cheb_significant = sum(cheb_coeffs .> threshold)
    leg_significant = sum(leg_coeffs .> threshold)
    
    total_terms = length(cheb_coeffs)
    cheb_sparsity = (total_terms - cheb_significant) / total_terms * 100
    leg_sparsity = (total_terms - leg_significant) / total_terms * 100
    
    println("┌─────────────┬───────────┬─────────────┬──────────────┐")
    println("│ Basis       │ Total     │ Significant │ Sparsity     │")
    println("├─────────────┼───────────┼─────────────┼──────────────┤")
    @printf "│ Chebyshev   │ %9d │ %11d │ %10.1f%% │\n" total_terms cheb_significant cheb_sparsity
    @printf "│ Legendre    │ %9d │ %11d │ %10.1f%% │\n" total_terms leg_significant leg_sparsity
    println("└─────────────┴───────────┴─────────────┴──────────────┘")
    
    # Determine winner
    if cheb_sparsity > leg_sparsity
        @printf "\n🏆 Chebyshev wins: %.1f%% vs %.1f%% sparsity\n" cheb_sparsity leg_sparsity
    elseif leg_sparsity > cheb_sparsity
        @printf "\n🏆 Legendre wins: %.1f%% vs %.1f%% sparsity\n" leg_sparsity cheb_sparsity
    else
        println("\n🤝 Tie in sparsity")
    end
    
    return Dict(
        :chebyshev_adaptive => cheb_adaptive,
        :chebyshev_f64 => cheb_f64,
        :legendre_f64 => leg_f64,
        :sparsity => Dict(:chebyshev => cheb_sparsity, :legendre => leg_sparsity),
        :significant_terms => Dict(:chebyshev => cheb_significant, :legendre => leg_significant)
    )
end

# ============================================================================
# RECOMMENDATIONS
# ============================================================================

"""
    provide_recommendations()

Provide recommendations based on the analysis.
"""
function provide_recommendations()
    println("\n💡 Recommendations for AdaptivePrecision + Polynomial Bases")
    println("=" ^ 60)
    
    println("🎯 Current Status:")
    println("  ✅ Chebyshev + AdaptivePrecision: WORKS")
    println("  ❌ Legendre + AdaptivePrecision: BROKEN (BigFloat // BigFloat issue)")
    println("  ✅ Legendre + Float64Precision: WORKS")
    
    println("\n🔧 Immediate Solutions:")
    println("  1. Use Chebyshev basis with AdaptivePrecision (recommended)")
    println("  2. Use Legendre basis with Float64Precision (if Legendre preferred)")
    println("  3. Fix the Globtim Legendre implementation (long-term)")
    
    println("\n🚀 For Your msolve Integration:")
    println("  ✅ Chebyshev + AdaptivePrecision → Exact Rationals works")
    println("  ✅ This gives you the high-precision benefits you need")
    println("  ✅ Sparsity analysis works with Chebyshev")
    println("  ✅ Critical points solving will work")
    
    println("\n🔍 To Fix Legendre + AdaptivePrecision (for developers):")
    println("  - Modify src/lege_pol.jl lines 73-74")
    println("  - Replace `//` with regular division `/` for BigFloat types")
    println("  - Add type checking for AdaptivePrecision")
    
    println("\n📊 Bottom Line:")
    println("  Use Chebyshev basis with AdaptivePrecision for now")
    println("  This gives you all the benefits you need for msolve integration")
    println("  Legendre comparison can wait until the bug is fixed")
end

# ============================================================================
# EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Run the debug analysis
    test_legendre_issue()
    
    println("\n" * "="^50)
    
    # Run workaround comparison
    result = compare_bases_with_workaround(4, 6)
    
    println("\n" * "="^50)
    
    # Provide recommendations
    provide_recommendations()
    
    println("\n🎉 Debug analysis complete!")
    
else
    println("💡 Debug functions loaded:")
    println("  - test_legendre_issue()")
    println("  - compare_bases_with_workaround(degree, samples)")
    println("  - provide_recommendations()")
end
