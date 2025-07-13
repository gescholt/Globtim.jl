# polynomial_display_utils.jl
# Utilities for displaying polynomials in tensorized and monomial forms

using DynamicPolynomials
using Printf
using Globtim
using ExactCoefficients

"""
    format_tensorized_term(coeff::Float64, multi_idx, basis::Symbol)

Format a single term in the tensorized basis representation.
"""
function format_tensorized_term(coeff::Float64, multi_idx, basis::Symbol)
    # Show coefficient with limited precision
    coeff_str = @sprintf("%.10g", coeff)
    
    # Build basis polynomial product
    basis_char = basis == :chebyshev ? "T" : "L"
    terms = String[]
    for (i, deg) in enumerate(multi_idx)
        if deg > 0
            push!(terms, "$(basis_char)_$(deg)(x_$i)")
        end
    end
    
    if isempty(terms)
        return coeff_str  # Constant term
    else
        return "$coeff_str * " * join(terms, " * ")
    end
end

"""
    display_tensorized_form(pol::Globtim.ApproxPoly; max_terms::Int=50)

Display polynomial in tensorized basis form (Chebyshev or Legendre).
"""
function display_tensorized_form(pol::Globtim.ApproxPoly; max_terms::Int=50)
    println("Tensorized $(pol.basis) form (Float64 coefficients):")
    println()
    
    # Count non-zero terms
    nonzero_indices = findall(!iszero, pol.coeffs)
    n_nonzero = length(nonzero_indices)
    
    if n_nonzero == 0
        println("   (zero polynomial)")
        return
    end
    
    # Display terms
    terms_shown = 0
    for idx in nonzero_indices
        if terms_shown >= max_terms
            println("   ... ($(n_nonzero - terms_shown) more terms)")
            break
        end
        
        coeff = pol.coeffs[idx]
        multi_idx = pol.support[idx]
        term_str = format_tensorized_term(coeff, multi_idx, pol.basis)
        
        # Add + or - sign
        if terms_shown == 0
            println("   $term_str")
        else
            if coeff >= 0
                println(" + $term_str")
            else
                # Remove the minus sign from coeff_str since we're adding it explicitly
                term_str_positive = format_tensorized_term(abs(coeff), multi_idx, pol.basis)
                println(" - $term_str_positive")
            end
        end
        
        terms_shown += 1
    end
end

"""
    convert_to_rational(coeffs::Vector{Float64}; precision_digits::Int=15)

Convert Float64 coefficients to Rational{BigInt} for exact arithmetic.
"""
function convert_to_rational(coeffs::Vector{Float64}; precision_digits::Int=15)
    return [rationalize(BigInt, c, tol=10^(-precision_digits)) for c in coeffs]
end

"""
    convert_to_monomial_exact(pol::Globtim.ApproxPoly; rational_precision::Int=15)

Convert ApproxPoly from tensorized basis to monomial form using exact arithmetic.
"""
function convert_to_monomial_exact(pol::Globtim.ApproxPoly; rational_precision::Int=15)
    # Get dimension from support
    dim = length(pol.support[1])
    
    # Create polynomial variables
    vars = [@polyvar(x)[1] for _ in 1:dim]
    
    # Convert coefficients to rational
    rational_coeffs = convert_to_rational(pol.coeffs, precision_digits=rational_precision)
    
    # Use Globtim's construct_orthopoly_polynomial
    poly_monomial = Globtim.construct_orthopoly_polynomial(
        vars,
        rational_coeffs,
        pol.degree,
        pol.basis,
        Globtim.RationalPrecision;
        normalized=true,
        power_of_two_denom=false
    )
    
    return poly_monomial
end

"""
    display_monomial_polynomial(poly_monomial; max_terms::Int=50)

Display a polynomial in monomial form with rational coefficients.
"""
function display_monomial_polynomial(poly_monomial; max_terms::Int=50)
    terms = DynamicPolynomials.terms(poly_monomial)
    n_terms = length(terms)
    
    if n_terms == 0
        println("   (zero polynomial)")
        return
    end
    
    # Sort terms by total degree and then lexicographically
    sorted_terms = sort(collect(terms), by = t -> (
        DynamicPolynomials.degree(DynamicPolynomials.monomial(t)),
        DynamicPolynomials.monomial(t)
    ))
    
    terms_shown = 0
    for (i, term) in enumerate(sorted_terms)
        if terms_shown >= max_terms
            println("   ... ($(n_terms - terms_shown) more terms)")
            break
        end
        
        coeff = DynamicPolynomials.coefficient(term)
        monom = DynamicPolynomials.monomial(term)
        
        # Format coefficient
        if isa(coeff, Rational)
            if denominator(coeff) == 1
                coeff_str = string(numerator(coeff))
            else
                coeff_str = "$(numerator(coeff))/$(denominator(coeff))"
            end
        else
            coeff_str = string(coeff)
        end
        
        # Format the term
        if monom == 1
            term_str = coeff_str
        else
            term_str = "$coeff_str * $monom"
        end
        
        # Add appropriate sign
        if i == 1
            println("   $term_str")
        else
            if coeff >= 0
                println(" + $term_str")
            else
                # For negative coefficients, we need to handle the sign properly
                if isa(coeff, Rational)
                    if denominator(coeff) == 1
                        coeff_str_positive = string(abs(numerator(coeff)))
                    else
                        coeff_str_positive = "$(abs(numerator(coeff)))/$(denominator(coeff))"
                    end
                else
                    coeff_str_positive = string(abs(coeff))
                end
                
                if monom == 1
                    term_str_positive = coeff_str_positive
                else
                    term_str_positive = "$coeff_str_positive * $monom"
                end
                println(" - $term_str_positive")
            end
        end
        
        terms_shown += 1
    end
end

"""
    show_basis_definitions(basis::Symbol, max_degree::Int)

Show the definitions of basis polynomials up to a given degree.
"""
function show_basis_definitions(basis::Symbol, max_degree::Int)
    basis_char = basis == :chebyshev ? "T" : "L"
    basis_name = basis == :chebyshev ? "Chebyshev" : "Legendre"
    
    println("$basis_name polynomial definitions:")
    
    # Create a single variable for showing expansions
    @polyvar x
    
    for d in 0:min(max_degree, 5)  # Show up to degree 5
        if basis == :chebyshev
            # Get Chebyshev polynomial expansion
            if d == 0
                poly_str = "1"
            elseif d == 1
                poly_str = "x"
            elseif d == 2
                poly_str = "2x² - 1"
            elseif d == 3
                poly_str = "4x³ - 3x"
            elseif d == 4
                poly_str = "8x⁴ - 8x² + 1"
            elseif d == 5
                poly_str = "16x⁵ - 20x³ + 5x"
            end
        else  # Legendre
            if d == 0
                poly_str = "1"
            elseif d == 1
                poly_str = "x"
            elseif d == 2
                poly_str = "(3x² - 1)/2"
            elseif d == 3
                poly_str = "(5x³ - 3x)/2"
            elseif d == 4
                poly_str = "(35x⁴ - 30x² + 3)/8"
            elseif d == 5
                poly_str = "(63x⁵ - 70x³ + 15x)/8"
            end
        end
        
        println("   $(basis_char)_$d(x) = $poly_str")
    end
    
    if max_degree > 5
        println("   ... (higher degree polynomials follow recurrence relations)")
    end
end

"""
    count_monomial_support(poly_monomial)

Count the number of non-zero monomial terms in a polynomial.
"""
function count_monomial_support(poly_monomial)
    return length(DynamicPolynomials.terms(poly_monomial))
end

"""
    display_polynomial_comparison(pol::Globtim.ApproxPoly; 
                                rational_precision::Int=15,
                                max_terms::Int=20)

Display a polynomial in both tensorized and monomial forms with statistics.
"""
function display_polynomial_comparison(pol::Globtim.ApproxPoly; 
                                     rational_precision::Int=15,
                                     max_terms::Int=20)
    println("="^70)
    println("POLYNOMIAL REPRESENTATION COMPARISON")
    println("="^70)
    
    # Step 1: Tensorized form
    println("\n1. TENSORIZED $(uppercase(string(pol.basis))) FORM")
    println("   Coefficient type: Float64")
    println("   Non-zero terms: $(count(!iszero, pol.coeffs))")
    println("   Total dimension: $(length(pol.coeffs))")
    println()
    display_tensorized_form(pol, max_terms=max_terms)
    
    # Step 2: Show basis definitions
    println("\n2. BASIS POLYNOMIAL DEFINITIONS")
    max_degree = maximum(maximum.(pol.support))
    show_basis_definitions(pol.basis, max_degree)
    
    # Step 3: Convert to monomial
    println("\n3. CONVERTING TO MONOMIAL FORM")
    println("   Converting Float64 → Rational{BigInt}")
    println("   Rational precision: $rational_precision digits")
    
    poly_monomial = convert_to_monomial_exact(pol, rational_precision=rational_precision)
    
    println("\n4. MONOMIAL FORM (Exact Arithmetic)")
    println("   Coefficient type: Rational{BigInt}")
    println("   Non-zero terms: $(count_monomial_support(poly_monomial))")
    println()
    display_monomial_polynomial(poly_monomial, max_terms=max_terms)
    
    # Step 5: Summary statistics
    println("\n5. SUMMARY STATISTICS")
    println("   Tensorized non-zero terms: $(count(!iszero, pol.coeffs))")
    println("   Monomial non-zero terms: $(count_monomial_support(poly_monomial))")
    println("   Expansion factor: $(round(count_monomial_support(poly_monomial) / count(!iszero, pol.coeffs), digits=2))")
end

"""
    analyze_truncation_effect(pol::Globtim.ApproxPoly, threshold::Real; 
                            rational_precision::Int=15)

Analyze how truncation in tensorized basis affects monomial support.
"""
function analyze_truncation_effect(pol::Globtim.ApproxPoly, threshold::Real; 
                                 rational_precision::Int=15)
    # Original monomial expansion
    poly_mono_original = convert_to_monomial_exact(pol, rational_precision=rational_precision)
    
    # Truncate in tensorized basis
    result = ExactCoefficients.sparsify_polynomial(pol, threshold)
    poly_mono_truncated = convert_to_monomial_exact(result.polynomial, rational_precision=rational_precision)
    
    # Statistics
    stats = (
        tensorized_original = count(!iszero, pol.coeffs),
        tensorized_truncated = count(!iszero, result.polynomial.coeffs),
        monomial_original = count_monomial_support(poly_mono_original),
        monomial_truncated = count_monomial_support(poly_mono_truncated),
        threshold = threshold
    )
    
    println("\nTRUNCATION ANALYSIS (threshold = $threshold)")
    println("Tensorized basis:")
    println("   Original terms: $(stats.tensorized_original)")
    println("   After truncation: $(stats.tensorized_truncated)")
    println("   Reduction: $(round((1 - stats.tensorized_truncated/stats.tensorized_original)*100, digits=1))%")
    println("\nMonomial basis:")
    println("   Original terms: $(stats.monomial_original)")
    println("   After truncation: $(stats.monomial_truncated)")
    println("   Reduction: $(round((1 - stats.monomial_truncated/stats.monomial_original)*100, digits=1))%")
    
    return stats
end

# Export all functions
export format_tensorized_term, display_tensorized_form, convert_to_rational,
       convert_to_monomial_exact, display_monomial_polynomial, show_basis_definitions,
       count_monomial_support, display_polynomial_comparison, analyze_truncation_effect