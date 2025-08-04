"""
Critical Points Analysis for 4D AdaptivePrecision Polynomials

This module integrates:
1. AdaptivePrecision polynomial construction
2. Sparsity analysis and truncation
3. Rational conversion for msolve compatibility
4. Homotopy continuation solving
5. Performance comparison (dense vs sparse)

Usage:
    julia --project=. Examples/critical_points_4d.jl
    
Or in REPL:
    include("Examples/critical_points_4d.jl")
    solve_critical_points_comparison(degree=6, samples=20)
"""

using Pkg
Pkg.activate(".")

# Core packages
using Globtim
using DynamicPolynomials
using HomotopyContinuation
using Printf
using Statistics
using LinearAlgebra
using Dates

# Load development utilities
include("adaptive_precision_4d_dev.jl")

println("🎯 Critical Points 4D Analysis System")
println("=" ^ 60)

# ============================================================================
# RATIONAL CONVERSION SYSTEM
# ============================================================================

"""
    to_rational_coefficients(poly, max_denominator=10^12)

Convert AdaptivePrecision polynomial coefficients to exact rationals for msolve.
Enhanced version with proper AdaptivePrecision handling.
"""
function to_rational_coefficients(poly, max_denominator=10^12)
    println("🔄 Converting to exact rational coefficients...")

    # Load enhanced conversion from basis comparison module
    if @isdefined(polynomial_to_exact_rationals)
        return polynomial_to_exact_rationals(poly)
    end

    # Fallback implementation
    @polyvar x[1:4]
    mono_poly = to_exact_monomial_basis(poly, variables=x)
    coeffs = [coefficient(t) for t in terms(mono_poly)]
    monomials = [monomial(t) for t in terms(mono_poly)]

    # Enhanced rational conversion
    rational_coeffs = []
    conversion_errors = []
    denominators = []

    for coeff in coeffs
        if isa(coeff, AdaptivePrecision)
            # Use high-precision BigFloat conversion
            high_prec_val = BigFloat(coeff)
            rational_coeff = rationalize(high_prec_val, tol=1e-50, max_denominator=max_denominator)
        else
            # Standard Float64 conversion
            rational_coeff = rationalize(Float64(coeff), tol=1e-15, max_denominator=max_denominator)
        end

        push!(rational_coeffs, rational_coeff)
        push!(denominators, denominator(rational_coeff))

        # Track conversion error
        error = abs(Float64(rational_coeff) - Float64(coeff))
        push!(conversion_errors, error)
    end

    max_error = maximum(conversion_errors)
    avg_error = mean(conversion_errors)
    max_denom = maximum(denominators)

    @printf "  Coefficients: %d\n" length(rational_coeffs)
    @printf "  Max conversion error: %.2e\n" max_error
    @printf "  Avg conversion error: %.2e\n" avg_error
    @printf "  Max denominator: %d\n" max_denom

    return rational_coeffs, monomials, conversion_errors, max_denom
end

"""
    create_sparse_polynomial(poly, threshold=1e-10)

Create sparse version by truncating small coefficients.
"""
function create_sparse_polynomial(poly, threshold=1e-10)
    println("✂️  Creating sparse polynomial (threshold=$(threshold))...")
    
    @polyvar x[1:4]
    mono_poly = to_exact_monomial_basis(poly, variables=x)
    
    # Filter terms by coefficient magnitude
    significant_terms = []
    for term in terms(mono_poly)
        coeff = coefficient(term)
        if abs(Float64(coeff)) > threshold
            push!(significant_terms, term)
        end
    end
    
    # Reconstruct polynomial with significant terms only
    sparse_poly = sum(significant_terms)
    
    original_terms = length(terms(mono_poly))
    sparse_terms = length(significant_terms)
    sparsity = (original_terms - sparse_terms) / original_terms * 100
    
    @printf "  Original terms: %d\n" original_terms
    @printf "  Sparse terms: %d\n" sparse_terms
    @printf "  Sparsity: %.1f%%\n" sparsity
    
    return sparse_poly, sparsity
end

# ============================================================================
# CRITICAL POINT SOLVING SYSTEM
# ============================================================================

"""
    solve_critical_points_homotopy(poly, method=:dense)

Solve critical points using homotopy continuation.
method: :dense (original) or :sparse (truncated)
"""
function solve_critical_points_homotopy(poly, method=:dense)
    println("🔍 Solving critical points via homotopy continuation ($method)...")
    
    @polyvar x[1:4]
    
    # Convert to monomial basis if needed
    if isa(poly, ApproxPoly)
        mono_poly = to_exact_monomial_basis(poly, variables=x)
    else
        mono_poly = poly
    end
    
    # Compute gradient system
    grad_system = [differentiate(mono_poly, x[i]) for i in 1:4]
    
    println("  Gradient system created: $(length(grad_system)) equations")
    
    # Solve using HomotopyContinuation
    start_time = time()
    
    try
        result = solve(grad_system)
        solve_time = time() - start_time
        
        # Extract real solutions
        real_solutions = real_solutions(result)
        complex_solutions = solutions(result)
        
        @printf "  Solve time: %.4fs\n" solve_time
        @printf "  Total solutions: %d\n" length(complex_solutions)
        @printf "  Real solutions: %d\n" length(real_solutions)
        
        return Dict(
            :method => method,
            :solve_time => solve_time,
            :total_solutions => length(complex_solutions),
            :real_solutions => length(real_solutions),
            :solutions => real_solutions,
            :all_solutions => complex_solutions,
            :success => true
        )
        
    catch e
        solve_time = time() - start_time
        println("  ❌ Solving failed: $e")
        
        return Dict(
            :method => method,
            :solve_time => solve_time,
            :success => false,
            :error => string(e)
        )
    end
end

"""
    solve_critical_points_comparison(degree=6, samples=20, threshold=1e-10)

Compare critical point solving: dense vs sparse polynomials.
"""
function solve_critical_points_comparison(degree=6, samples=20, threshold=1e-10)
    println("\n🎯 Critical Points Comparison: Dense vs Sparse")
    println("=" ^ 60)
    @printf "Parameters: degree=%d, samples=%d, threshold=%.0e\n" degree samples threshold
    
    # Step 1: Construct polynomial
    println("\n📊 Step 1: Polynomial Construction")
    TR = test_input(shubert_4d, dim=4, center=[0.0,0.0,0.0,0.0], GN=samples, 
                   sample_range=2.0, degree_max=degree+2)
    
    pol_adaptive = Constructor(TR, degree, basis=:chebyshev, precision=AdaptivePrecision, verbose=0)
    @printf "  Constructed polynomial: L2=%.6e, %d coefficients\n" pol_adaptive.nrm length(pol_adaptive.coeffs)
    
    # Step 2: Create sparse version
    println("\n✂️  Step 2: Sparsity Analysis")
    @polyvar x[1:4]
    mono_dense = to_exact_monomial_basis(pol_adaptive, variables=x)
    mono_sparse, sparsity = create_sparse_polynomial(pol_adaptive, threshold)
    
    # Step 3: Rational conversion
    println("\n🔄 Step 3: Rational Conversion")
    dense_rationals, dense_monomials, dense_errors = to_rational_coefficients(pol_adaptive)
    
    # For sparse: convert the sparse polynomial
    sparse_coeffs = [coefficient(t) for t in terms(mono_sparse)]
    sparse_rationals = [rationalize(Float64(c), tol=1e-15) for c in sparse_coeffs]
    
    @printf "  Dense rational coeffs: %d\n" length(dense_rationals)
    @printf "  Sparse rational coeffs: %d\n" length(sparse_rationals)
    
    # Step 4: Solve critical points
    println("\n🔍 Step 4: Critical Point Solving")
    
    # Solve dense system
    dense_result = solve_critical_points_homotopy(mono_dense, :dense)
    
    # Solve sparse system  
    sparse_result = solve_critical_points_homotopy(mono_sparse, :sparse)
    
    # Step 5: Comparison analysis
    println("\n📈 Step 5: Performance Comparison")
    display_comparison_results(dense_result, sparse_result, sparsity)
    
    return Dict(
        :degree => degree,
        :samples => samples,
        :threshold => threshold,
        :sparsity => sparsity,
        :dense_result => dense_result,
        :sparse_result => sparse_result,
        :polynomial_stats => Dict(
            :l2_norm => pol_adaptive.nrm,
            :dense_terms => length(terms(mono_dense)),
            :sparse_terms => length(terms(mono_sparse))
        )
    )
end

"""
    display_comparison_results(dense_result, sparse_result, sparsity)

Display formatted comparison of dense vs sparse solving results.
"""
function display_comparison_results(dense_result, sparse_result, sparsity)
    println("┌─────────────────────────────────────────────────────────┐")
    println("│                 SOLVING COMPARISON                      │")
    println("├─────────────────────────────────────────────────────────┤")
    
    if dense_result[:success] && sparse_result[:success]
        @printf "│ Method    │ Time (s) │ Solutions │ Real │ Speedup    │\n"
        println("├───────────┼──────────┼───────────┼──────┼────────────┤")
        @printf "│ Dense     │ %8.4f │ %9d │ %4d │     -      │\n" dense_result[:solve_time] dense_result[:total_solutions] dense_result[:real_solutions]
        @printf "│ Sparse    │ %8.4f │ %9d │ %4d │ %8.2fx │\n" sparse_result[:solve_time] sparse_result[:total_solutions] sparse_result[:real_solutions] (dense_result[:solve_time] / sparse_result[:solve_time])
        println("└───────────┴──────────┴───────────┴──────┴────────────┘")
        
        @printf "\n🎯 Sparsity: %.1f%% → %.2fx speedup\n" sparsity (dense_result[:solve_time] / sparse_result[:solve_time])
        
        # Solution accuracy check
        if dense_result[:real_solutions] == sparse_result[:real_solutions]
            println("✅ Same number of real solutions found")
        else
            println("⚠️  Different number of real solutions - investigate truncation threshold")
        end
        
    else
        println("│ ❌ One or both methods failed                           │")
        if !dense_result[:success]
            @printf "│ Dense method error: %s\n" dense_result[:error]
        end
        if !sparse_result[:success]
            @printf "│ Sparse method error: %s\n" sparse_result[:error]
        end
        println("└─────────────────────────────────────────────────────────┘")
    end
end

# ============================================================================
# BATCH TESTING SYSTEM
# ============================================================================

"""
    run_critical_points_study(degrees=[4,5,6], samples=[15,20,25])

Run comprehensive study across multiple parameter combinations.
"""
function run_critical_points_study(degrees=[4,5,6], samples=[15,20,25])
    println("\n🎯 Comprehensive Critical Points Study")
    println("=" ^ 60)
    
    results = []
    
    for degree in degrees
        for sample_count in samples
            println("\n" * "─"^50)
            @printf "Testing: degree=%d, samples=%d\n" degree sample_count
            println("─"^50)
            
            try
                result = solve_critical_points_comparison(degree, sample_count)
                push!(results, result)
                
                # Quick summary
                if result[:dense_result][:success] && result[:sparse_result][:success]
                    speedup = result[:dense_result][:solve_time] / result[:sparse_result][:solve_time]
                    @printf "✅ Success: %.1f%% sparse → %.2fx speedup\n" result[:sparsity] speedup
                else
                    println("❌ Failed")
                end
                
            catch e
                println("❌ Error: $e")
                continue
            end
        end
    end
    
    # Overall summary
    if !isempty(results)
        successful_results = filter(r -> r[:dense_result][:success] && r[:sparse_result][:success], results)
        
        if !isempty(successful_results)
            speedups = [r[:dense_result][:solve_time] / r[:sparse_result][:solve_time] for r in successful_results]
            sparsities = [r[:sparsity] for r in successful_results]
            
            println("\n🏆 Study Summary:")
            @printf "  Successful tests: %d/%d\n" length(successful_results) length(results)
            @printf "  Sparsity range: %.1f%% - %.1f%%\n" minimum(sparsities) maximum(sparsities)
            @printf "  Speedup range: %.2fx - %.2fx\n" minimum(speedups) maximum(speedups)
            @printf "  Average speedup: %.2fx\n" mean(speedups)
        end
    end
    
    return results
end

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Script is being run directly
    println("\n🚀 Running Critical Points Analysis...")
    
    # Single test
    result = solve_critical_points_comparison(5, 20)
    
    println("\n🎉 Analysis complete!")
    println("💡 Available functions:")
    println("  - solve_critical_points_comparison(degree, samples)")
    println("  - run_critical_points_study(degrees, samples)")
    println("  - to_rational_coefficients(poly)")
    println("  - create_sparse_polynomial(poly, threshold)")
    
else
    # Script is being included
    println("\n💡 Critical Points functions loaded:")
    println("  - solve_critical_points_comparison(degree, samples)")
    println("  - run_critical_points_study(degrees, samples)")
    println("  - to_rational_coefficients(poly)")
    println("  - create_sparse_polynomial(poly, threshold)")
    println("\n🚀 Ready for critical points analysis!")
end
