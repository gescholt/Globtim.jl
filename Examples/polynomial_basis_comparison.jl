"""
Polynomial Basis Comparison: Chebyshev vs Legendre

This module provides comprehensive comparison of:
1. Chebyshev vs Legendre polynomial construction
2. AdaptivePrecision → Exact Rational conversion
3. Sparsity patterns across different bases
4. Critical points solving performance
5. msolve compatibility analysis

Usage:
    julia --project=. Examples/polynomial_basis_comparison.jl
    
Or in REPL:
    include("Examples/polynomial_basis_comparison.jl")
    compare_polynomial_bases(degree=5, samples=20)
"""

using Pkg
Pkg.activate(".")

# Core packages
using Globtim
using DynamicPolynomials
using Printf
using Statistics
using LinearAlgebra
using Dates

# Load development utilities
include("adaptive_precision_4d_dev.jl")

println("🎯 Polynomial Basis Comparison System")
println("=" ^ 50)

# ============================================================================
# ENHANCED RATIONAL CONVERSION FOR MSOLVE
# ============================================================================

"""
    adaptive_to_exact_rational(coeff, max_denominator=10^15)

Convert AdaptivePrecision coefficient to exact rational with proper precision handling.
"""
function adaptive_to_exact_rational(coeff, max_denominator=10^15)
    if isa(coeff, AdaptivePrecision)
        # Get the high-precision value from AdaptivePrecision
        high_prec_val = BigFloat(coeff)
        
        # Convert to rational with controlled denominator
        rational_coeff = rationalize(high_prec_val, tol=1e-50, max_denominator=max_denominator)
        
        # Verify conversion accuracy
        conversion_error = abs(Float64(rational_coeff) - Float64(coeff))
        
        return rational_coeff, conversion_error
    else
        # Handle Float64 or other numeric types
        rational_coeff = rationalize(Float64(coeff), tol=1e-15, max_denominator=max_denominator)
        conversion_error = abs(Float64(rational_coeff) - Float64(coeff))
        
        return rational_coeff, conversion_error
    end
end

"""
    polynomial_to_exact_rationals(poly)

Convert polynomial with AdaptivePrecision coefficients to exact rationals.
Returns: (rational_coefficients, monomials, conversion_errors, max_denominator)
"""
function polynomial_to_exact_rationals(poly)
    println("🔄 Converting polynomial to exact rationals...")
    
    @polyvar x[1:4]
    
    # Convert to monomial basis
    if isa(poly, ApproxPoly)
        mono_poly = to_exact_monomial_basis(poly, variables=x)
    else
        mono_poly = poly
    end
    
    # Extract terms
    terms_list = terms(mono_poly)
    coeffs = [coefficient(t) for t in terms_list]
    monos = [monomial(t) for t in terms_list]
    
    # Convert each coefficient to exact rational
    rational_coeffs = []
    conversion_errors = []
    denominators = []
    
    for coeff in coeffs
        rational_coeff, error = adaptive_to_exact_rational(coeff)
        push!(rational_coeffs, rational_coeff)
        push!(conversion_errors, error)
        push!(denominators, denominator(rational_coeff))
    end
    
    max_error = maximum(conversion_errors)
    avg_error = mean(conversion_errors)
    max_denominator = maximum(denominators)
    
    @printf "  Terms converted: %d\n" length(rational_coeffs)
    @printf "  Max conversion error: %.2e\n" max_error
    @printf "  Avg conversion error: %.2e\n" avg_error
    @printf "  Max denominator: %d\n" max_denominator
    
    return rational_coeffs, monos, conversion_errors, max_denominator
end

"""
    format_for_msolve(rational_coeffs, monomials, var_names=["x1", "x2", "x3", "x4"])

Format rational polynomial for msolve input with proper syntax.
"""
function format_for_msolve(rational_coeffs, monomials, var_names=["x1", "x2", "x3", "x4"])
    terms_strings = []
    
    for (coeff, mono) in zip(rational_coeffs, monomials)
        # Format coefficient
        if coeff == 1
            coeff_str = ""
        elseif coeff == -1
            coeff_str = "-"
        else
            # Use exact rational representation
            if denominator(coeff) == 1
                coeff_str = string(numerator(coeff))
            else
                coeff_str = "$(numerator(coeff))/$(denominator(coeff))"
            end
        end
        
        # Format monomial
        mono_str = format_monomial_for_msolve(mono, var_names)
        
        # Combine
        if mono_str == "1"
            term_str = coeff_str == "" ? "1" : coeff_str
        else
            term_str = coeff_str == "" ? mono_str : coeff_str * "*" * mono_str
        end
        
        push!(terms_strings, term_str)
    end
    
    # Join with proper signs
    result = join(terms_strings, " + ")
    result = replace(result, "+ -" => "- ")
    
    return result
end

"""
    format_monomial_for_msolve(mono, var_names)

Format monomial for msolve with proper variable names and exponents.
"""
function format_monomial_for_msolve(mono, var_names)
    if isa(mono, Number) && mono == 1
        return "1"
    end
    
    # Get exponents
    exps = exponents(mono)
    
    if all(exp == 0 for exp in exps)
        return "1"
    end
    
    var_parts = []
    for (i, exp) in enumerate(exps)
        if exp > 0
            if exp == 1
                push!(var_parts, var_names[i])
            else
                push!(var_parts, "$(var_names[i])^$(exp)")
            end
        end
    end
    
    return join(var_parts, "*")
end

# ============================================================================
# POLYNOMIAL BASIS COMPARISON SYSTEM
# ============================================================================

"""
    construct_polynomial_both_bases(func, degree, samples, precision_type=AdaptivePrecision)

Construct polynomial using both Chebyshev and Legendre bases.
Handles AdaptivePrecision compatibility issues with Legendre polynomials.
"""
function construct_polynomial_both_bases(func, degree, samples, precision_type=AdaptivePrecision)
    println("🏗️  Constructing polynomials in both bases...")

    # Create test input
    TR = test_input(func, dim=4, center=[0.0,0.0,0.0,0.0], GN=samples,
                   sample_range=2.0, degree_max=degree+2)

    # Construct Chebyshev polynomial
    println("  Constructing Chebyshev polynomial...")
    @time cheb_poly = Constructor(TR, degree, basis=:chebyshev, precision=precision_type, verbose=0)
    @printf "  Chebyshev: L2=%.6e, %d coeffs\n" cheb_poly.nrm length(cheb_poly.coeffs)

    # Construct Legendre polynomial with error handling
    println("  Constructing Legendre polynomial...")
    leg_poly = nothing
    legendre_error = nothing

    try
        @time leg_poly = Constructor(TR, degree, basis=:legendre, precision=precision_type, verbose=0)
        @printf "  Legendre:  L2=%.6e, %d coeffs\n" leg_poly.nrm length(leg_poly.coeffs)
    catch e
        println("  ❌ Legendre construction failed with AdaptivePrecision: $e")
        println("  🔄 Trying with Float64Precision...")
        legendre_error = e

        try
            @time leg_poly = Constructor(TR, degree, basis=:legendre, precision=Float64Precision, verbose=0)
            @printf "  Legendre (Float64): L2=%.6e, %d coeffs\n" leg_poly.nrm length(leg_poly.coeffs)
            println("  ⚠️  Note: Legendre used Float64Precision due to AdaptivePrecision compatibility issue")
        catch e2
            println("  ❌ Legendre construction failed completely: $e2")
            leg_poly = nothing
        end
    end

    return cheb_poly, leg_poly, TR, legendre_error
end

"""
    analyze_basis_sparsity(cheb_poly, leg_poly, threshold=1e-10)

Analyze sparsity patterns for both polynomial bases with error handling.
"""
function analyze_basis_sparsity(cheb_poly, leg_poly, threshold=1e-10)
    println("✂️  Analyzing sparsity patterns...")

    @polyvar x[1:4]

    # Convert Chebyshev to monomial basis
    println("  Converting Chebyshev to monomial basis...")
    cheb_mono = nothing
    cheb_coeffs = nothing
    cheb_conversion_error = nothing

    try
        cheb_mono = to_exact_monomial_basis(cheb_poly, variables=x)
        cheb_coeffs = abs.(Float64.([coefficient(t) for t in terms(cheb_mono)]))
        println("  ✅ Chebyshev conversion successful")
    catch e
        println("  ❌ Chebyshev conversion failed: $e")
        cheb_conversion_error = e
    end

    # Convert Legendre to monomial basis
    println("  Converting Legendre to monomial basis...")
    leg_mono = nothing
    leg_coeffs = nothing
    leg_conversion_error = nothing

    try
        leg_mono = to_exact_monomial_basis(leg_poly, variables=x)
        leg_coeffs = abs.(Float64.([coefficient(t) for t in terms(leg_mono)]))
        println("  ✅ Legendre conversion successful")
    catch e
        println("  ❌ Legendre conversion failed: $e")
        println("     This is likely the AdaptivePrecision BigFloat // BigFloat issue")
        leg_conversion_error = e
    end

    # Handle partial failure
    if cheb_coeffs === nothing && leg_coeffs === nothing
        println("  ❌ Both conversions failed - cannot analyze sparsity")
        return nothing
    elseif leg_coeffs === nothing
        println("  ⚠️  Only Chebyshev analysis possible")
        return analyze_chebyshev_only_sparsity(cheb_coeffs, threshold, leg_conversion_error)
    elseif cheb_coeffs === nothing
        println("  ⚠️  Only Legendre analysis possible")
        return analyze_legendre_only_sparsity(leg_coeffs, threshold, cheb_conversion_error)
    end

    # Both conversions successful - full comparison
    cheb_significant = sum(cheb_coeffs .> threshold)
    leg_significant = sum(leg_coeffs .> threshold)

    total_terms = length(cheb_coeffs)
    cheb_sparsity = (total_terms - cheb_significant) / total_terms * 100
    leg_sparsity = (total_terms - leg_significant) / total_terms * 100

    # Coefficient statistics
    cheb_max = maximum(cheb_coeffs)
    cheb_min = minimum(cheb_coeffs[cheb_coeffs .> 0])
    leg_max = maximum(leg_coeffs)
    leg_min = minimum(leg_coeffs[leg_coeffs .> 0])

    println("📊 Sparsity Comparison:")
    println("┌─────────────┬───────────┬─────────────┬──────────────┬─────────────┐")
    println("│ Basis       │ Total     │ Significant │ Sparsity     │ Dyn. Range  │")
    println("├─────────────┼───────────┼─────────────┼──────────────┼─────────────┤")
    @printf "│ Chebyshev   │ %9d │ %11d │ %10.1f%% │ %11.2e │\n" total_terms cheb_significant cheb_sparsity (cheb_max/cheb_min)
    @printf "│ Legendre    │ %9d │ %11d │ %10.1f%% │ %11.2e │\n" total_terms leg_significant leg_sparsity (leg_max/leg_min)
    println("└─────────────┴───────────┴─────────────┴──────────────┴─────────────┘")

    return Dict(
        :chebyshev => Dict(:sparsity => cheb_sparsity, :significant => cheb_significant,
                          :dynamic_range => cheb_max/cheb_min, :coeffs => cheb_coeffs),
        :legendre => Dict(:sparsity => leg_sparsity, :significant => leg_significant,
                         :dynamic_range => leg_max/leg_min, :coeffs => leg_coeffs),
        :total_terms => total_terms,
        :conversion_errors => Dict(:chebyshev => cheb_conversion_error, :legendre => leg_conversion_error)
    )
end

"""
    analyze_chebyshev_only_sparsity(cheb_coeffs, threshold, leg_error)

Analyze sparsity for Chebyshev only when Legendre fails.
"""
function analyze_chebyshev_only_sparsity(cheb_coeffs, threshold, leg_error)
    cheb_significant = sum(cheb_coeffs .> threshold)
    total_terms = length(cheb_coeffs)
    cheb_sparsity = (total_terms - cheb_significant) / total_terms * 100

    cheb_max = maximum(cheb_coeffs)
    cheb_min = minimum(cheb_coeffs[cheb_coeffs .> 0])

    println("📊 Chebyshev-Only Sparsity Analysis:")
    println("┌─────────────┬───────────┬─────────────┬──────────────┬─────────────┐")
    println("│ Basis       │ Total     │ Significant │ Sparsity     │ Dyn. Range  │")
    println("├─────────────┼───────────┼─────────────┼──────────────┼─────────────┤")
    @printf "│ Chebyshev   │ %9d │ %11d │ %10.1f%% │ %11.2e │\n" total_terms cheb_significant cheb_sparsity (cheb_max/cheb_min)
    @printf "│ Legendre    │     ERROR │       ERROR │        ERROR │       ERROR │\n"
    println("└─────────────┴───────────┴─────────────┴──────────────┴─────────────┘")

    println("⚠️  Legendre analysis failed: $leg_error")

    return Dict(
        :chebyshev => Dict(:sparsity => cheb_sparsity, :significant => cheb_significant,
                          :dynamic_range => cheb_max/cheb_min, :coeffs => cheb_coeffs),
        :legendre => nothing,
        :total_terms => total_terms,
        :conversion_errors => Dict(:chebyshev => nothing, :legendre => leg_error),
        :analysis_type => :chebyshev_only
    )
end

"""
    compare_rational_conversion(cheb_poly, leg_poly)

Compare rational conversion quality for both bases with error handling.
"""
function compare_rational_conversion(cheb_poly, leg_poly)
    println("🔄 Comparing rational conversion...")

    # Convert Chebyshev to rationals
    println("  Converting Chebyshev coefficients...")
    cheb_rationals, cheb_monos, cheb_errors, cheb_max_denom = polynomial_to_exact_rationals(cheb_poly)

    # Convert Legendre to rationals (if possible)
    leg_rationals = nothing
    leg_monos = nothing
    leg_errors = nothing
    leg_max_denom = nothing
    leg_conversion_failed = false

    if leg_poly !== nothing
        println("  Converting Legendre coefficients...")
        try
            leg_rationals, leg_monos, leg_errors, leg_max_denom = polynomial_to_exact_rationals(leg_poly)
        catch e
            println("  ❌ Legendre rational conversion failed: $e")
            leg_conversion_failed = true
        end
    else
        println("  ⚠️  Legendre polynomial not available - skipping conversion")
        leg_conversion_failed = true
    end

    # Display results
    println("📊 Rational Conversion Comparison:")
    println("┌─────────────┬─────────────┬─────────────┬─────────────┐")
    println("│ Basis       │ Max Error   │ Avg Error   │ Max Denom   │")
    println("├─────────────┼─────────────┼─────────────┼─────────────┤")
    @printf "│ Chebyshev   │ %11.2e │ %11.2e │ %11d │\n" maximum(cheb_errors) mean(cheb_errors) cheb_max_denom

    if leg_conversion_failed
        @printf "│ Legendre    │       ERROR │       ERROR │       ERROR │\n"
    else
        @printf "│ Legendre    │ %11.2e │ %11.2e │ %11d │\n" maximum(leg_errors) mean(leg_errors) leg_max_denom
    end

    println("└─────────────┴─────────────┴─────────────┴─────────────┘")

    return Dict(
        :chebyshev => Dict(:rationals => cheb_rationals, :monomials => cheb_monos,
                          :errors => cheb_errors, :max_denom => cheb_max_denom),
        :legendre => leg_conversion_failed ? nothing : Dict(:rationals => leg_rationals, :monomials => leg_monos,
                         :errors => leg_errors, :max_denom => leg_max_denom),
        :legendre_failed => leg_conversion_failed
    )
end

"""
    compare_polynomial_bases(degree=5, samples=20, threshold=1e-10)

Comprehensive comparison of Chebyshev vs Legendre polynomial bases.
"""
function compare_polynomial_bases(degree=5, samples=20, threshold=1e-10)
    println("\n🎯 Comprehensive Polynomial Basis Comparison")
    println("=" ^ 60)
    @printf "Parameters: degree=%d, samples=%d, threshold=%.0e\n" degree samples threshold
    
    # Step 1: Construct polynomials in both bases
    println("\n🏗️  Step 1: Polynomial Construction")
    cheb_poly, leg_poly, TR, legendre_error = construct_polynomial_both_bases(shubert_4d, degree, samples)

    # Check if Legendre construction succeeded
    if leg_poly === nothing
        println("⚠️  Legendre polynomial construction failed - running Chebyshev-only analysis")
        return run_chebyshev_only_analysis(cheb_poly, degree, samples, threshold, legendre_error)
    end

    # Step 2: Sparsity analysis
    println("\n✂️  Step 2: Sparsity Analysis")
    sparsity_results = analyze_basis_sparsity(cheb_poly, leg_poly, threshold)
    
    # Step 3: Rational conversion comparison
    println("\n🔄 Step 3: Rational Conversion Analysis")
    rational_results = compare_rational_conversion(cheb_poly, leg_poly)
    
    # Step 4: msolve format generation
    println("\n📝 Step 4: msolve Format Generation")

    # Generate msolve string for Chebyshev
    cheb_msolve_str = format_for_msolve(rational_results[:chebyshev][:rationals],
                                       rational_results[:chebyshev][:monomials])
    @printf "  Chebyshev msolve string: %d characters\n" length(cheb_msolve_str)

    # Generate msolve string for Legendre (if available)
    leg_msolve_str = nothing
    if rational_results[:legendre] !== nothing
        leg_msolve_str = format_for_msolve(rational_results[:legendre][:rationals],
                                          rational_results[:legendre][:monomials])
        @printf "  Legendre msolve string:  %d characters\n" length(leg_msolve_str)
    else
        println("  Legendre msolve string:  Not available (conversion failed)")
    end
    
    # Step 5: Coefficient visualization (if available)
    println("\n📊 Step 5: Coefficient Visualization")
    visualization_result = nothing
    try
        include("coefficient_visualization.jl")
        if @isdefined(plot_coefficient_distribution)
            println("  Creating coefficient distribution plot...")
            fig, coeff_data, threshold_data = plot_coefficient_distribution(
                cheb_poly, [1e-12, 1e-10, 1e-8, 1e-6],
                title="Chebyshev Coefficient Distribution (deg=$degree, n=$samples)",
                save_path="chebyshev_coefficients_deg$(degree)_n$(samples).png"
            )
            visualization_result = Dict(:figure => fig, :data => coeff_data, :thresholds => threshold_data)
        end
    catch e
        println("  ⚠️  Visualization not available: $e")
    end

    # Step 6: Summary and recommendations
    println("\n📈 Step 6: Summary & Recommendations")
    display_basis_comparison_summary(sparsity_results, rational_results)
    
    return Dict(
        :degree => degree,
        :samples => samples,
        :threshold => threshold,
        :polynomials => Dict(:chebyshev => cheb_poly, :legendre => leg_poly),
        :sparsity => sparsity_results,
        :rationals => rational_results,
        :msolve_strings => Dict(:chebyshev => cheb_msolve_str, :legendre => leg_msolve_str),
        :legendre_error => legendre_error,
        :visualization => visualization_result
    )
end

"""
    run_chebyshev_only_analysis(cheb_poly, degree, samples, threshold, legendre_error)

Run analysis with only Chebyshev polynomial when Legendre fails.
"""
function run_chebyshev_only_analysis(cheb_poly, degree, samples, threshold, legendre_error)
    println("\n🔄 Running Chebyshev-only analysis...")

    # Sparsity analysis for Chebyshev only
    @polyvar x[1:4]
    cheb_mono = to_exact_monomial_basis(cheb_poly, variables=x)
    cheb_coeffs = abs.(Float64.([coefficient(t) for t in terms(cheb_mono)]))

    total_terms = length(cheb_coeffs)
    cheb_significant = sum(cheb_coeffs .> threshold)
    cheb_sparsity = (total_terms - cheb_significant) / total_terms * 100

    cheb_max = maximum(cheb_coeffs)
    cheb_min = minimum(cheb_coeffs[cheb_coeffs .> 0])

    println("📊 Chebyshev Analysis:")
    @printf "  Total terms: %d\n" total_terms
    @printf "  Significant terms: %d\n" cheb_significant
    @printf "  Sparsity: %.1f%%\n" cheb_sparsity
    @printf "  Dynamic range: %.2e\n" (cheb_max/cheb_min)

    # Rational conversion
    cheb_rationals, cheb_monos, cheb_errors, cheb_max_denom = polynomial_to_exact_rationals(cheb_poly)

    @printf "  Rational conversion: max_error=%.2e, max_denom=%d\n" maximum(cheb_errors) cheb_max_denom

    # msolve format
    cheb_msolve_str = format_for_msolve(cheb_rationals, cheb_monos)
    @printf "  msolve string: %d characters\n" length(cheb_msolve_str)

    println("\n⚠️  Legendre Analysis Skipped:")
    println("  Reason: AdaptivePrecision compatibility issue")
    println("  Error: $legendre_error")
    println("  Recommendation: Use Chebyshev basis with AdaptivePrecision")

    return Dict(
        :degree => degree,
        :samples => samples,
        :threshold => threshold,
        :polynomials => Dict(:chebyshev => cheb_poly, :legendre => nothing),
        :sparsity => Dict(
            :chebyshev => Dict(:sparsity => cheb_sparsity, :significant => cheb_significant,
                              :dynamic_range => cheb_max/cheb_min, :coeffs => cheb_coeffs),
            :legendre => nothing,
            :total_terms => total_terms
        ),
        :rationals => Dict(
            :chebyshev => Dict(:rationals => cheb_rationals, :monomials => cheb_monos,
                              :errors => cheb_errors, :max_denom => cheb_max_denom),
            :legendre => nothing
        ),
        :msolve_strings => Dict(:chebyshev => cheb_msolve_str, :legendre => nothing),
        :legendre_error => legendre_error,
        :analysis_type => :chebyshev_only
    )
end

"""
    display_basis_comparison_summary(sparsity_results, rational_results)

Display comprehensive summary of basis comparison.
"""
function display_basis_comparison_summary(sparsity_results, rational_results)
    println("┌─────────────────────────────────────────────────────────┐")
    println("│                 BASIS COMPARISON SUMMARY                │")
    println("├─────────────────────────────────────────────────────────┤")
    
    cheb_sparse = sparsity_results[:chebyshev][:sparsity]
    leg_sparse = sparsity_results[:legendre][:sparsity]
    
    cheb_max_denom = rational_results[:chebyshev][:max_denom]
    leg_max_denom = rational_results[:legendre][:max_denom]
    
    @printf "│ Sparsity:    Chebyshev %.1f%%, Legendre %.1f%%        │\n" cheb_sparse leg_sparse
    @printf "│ Denominators: Cheb %d, Leg %d                    │\n" cheb_max_denom leg_max_denom
    
    # Determine winner
    if cheb_sparse > leg_sparse
        println("│ 🏆 Chebyshev wins on sparsity                          │")
    elseif leg_sparse > cheb_sparse
        println("│ 🏆 Legendre wins on sparsity                           │")
    else
        println("│ 🤝 Tie on sparsity                                     │")
    end
    
    if cheb_max_denom < leg_max_denom
        println("│ 🏆 Chebyshev wins on rational simplicity               │")
    elseif leg_max_denom < cheb_max_denom
        println("│ 🏆 Legendre wins on rational simplicity                │")
    else
        println("│ 🤝 Tie on rational simplicity                          │")
    end
    
    println("└─────────────────────────────────────────────────────────┘")
    
    println("\n💡 Recommendations:")
    if cheb_sparse > leg_sparse && cheb_max_denom <= leg_max_denom
        println("  ✅ Use Chebyshev basis - better sparsity and simpler rationals")
    elseif leg_sparse > cheb_sparse && leg_max_denom <= cheb_max_denom
        println("  ✅ Use Legendre basis - better sparsity and simpler rationals")
    else
        println("  🤔 Mixed results - test both bases for your specific problem")
        if abs(cheb_sparse - leg_sparse) < 5.0
            println("     Similar sparsity - choose based on other criteria")
        end
    end
end

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Script is being run directly
    println("\n🚀 Running Polynomial Basis Comparison...")
    
    result = compare_polynomial_bases(5, 20)
    
    println("\n🎉 Comparison complete!")
    println("💡 Available functions:")
    println("  - compare_polynomial_bases(degree, samples)")
    println("  - polynomial_to_exact_rationals(poly)")
    println("  - format_for_msolve(rationals, monomials)")
    
else
    # Script is being included
    println("\n💡 Polynomial basis comparison functions loaded:")
    println("  - compare_polynomial_bases(degree, samples)")
    println("  - polynomial_to_exact_rationals(poly)")
    println("  - format_for_msolve(rationals, monomials)")

    # Load debug functions for workaround
    try
        include("debug_legendre_issue.jl")
        println("  - compare_bases_with_workaround(degree, samples) [from debug]")
    catch
        println("  ⚠️  debug_legendre_issue.jl not found - workaround functions not available")
    end

    println("\n🚀 Ready for basis comparison!")
end
