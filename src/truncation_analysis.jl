# truncation_analysis.jl
# Functions for polynomial truncation with L²-norm analysis

using DynamicPolynomials
using MultivariatePolynomials
using LinearAlgebra

"""
    truncate_polynomial(poly, coeff_threshold::Real = 1e-12; mode=:relative, 
                       domain::BoxDomain = BoxDomain(length(variables(poly)), 1.0),
                       l2_tolerance::Real = 0.05)

Remove terms with small coefficients from a polynomial while monitoring L²-norm preservation.

# Arguments
- `poly`: Polynomial to truncate
- `coeff_threshold`: Threshold for coefficient removal
- `mode`: `:relative` (relative to max coefficient) or `:absolute`
- `domain`: Domain for L²-norm computation
- `l2_tolerance`: Maximum acceptable L²-norm reduction (warns if exceeded)

# Returns
- NamedTuple with:
  - `polynomial`: Truncated polynomial
  - `removed_terms`: List of removed terms
  - `l2_ratio`: L²-norm preservation ratio
  - `original_terms`: Number of terms before truncation
  - `remaining_terms`: Number of terms after truncation

# Example
```julia
@polyvar x y
poly = x^2 + y^2 + 0.001*x*y + 0.0001*x^3
result = truncate_polynomial(poly, 0.01, mode=:relative)
```
"""
function truncate_polynomial(poly, coeff_threshold::Real = 1e-12; 
                           mode::Symbol = :relative,
                           domain::BoxDomain = BoxDomain(length(variables(poly)), 1.0),
                           l2_tolerance::Real = 0.05)
    
    # Get coefficients and monomials
    coeffs = coefficients(poly)
    monoms = monomials(poly)
    
    # Determine threshold
    if mode == :relative
        max_coeff = maximum(abs.(coeffs))
        actual_threshold = coeff_threshold * max_coeff
    else
        actual_threshold = coeff_threshold
    end
    
    # Find terms to keep
    keep_indices = findall(c -> abs(c) >= actual_threshold, coeffs)
    remove_indices = findall(c -> abs(c) < actual_threshold, coeffs)
    
    # Create truncated polynomial
    if isempty(keep_indices)
        # All coefficients are below threshold
        # Use zero(poly) which properly returns a zero polynomial of the same type
        truncated = zero(poly)
        removed_terms = [(monom=monoms[i], coeff=coeffs[i]) for i in eachindex(monoms)]
    else
        kept_coeffs = coeffs[keep_indices]
        kept_monoms = monoms[keep_indices]
        if length(kept_coeffs) == 1
            # Single term case: ensure we get a polynomial, not just a term
            truncated = polynomial(kept_coeffs[1] * kept_monoms[1])
        else
            truncated = sum(kept_coeffs[i] * kept_monoms[i] for i in eachindex(kept_coeffs))
        end
        removed_terms = [(monom=monoms[i], coeff=coeffs[i]) for i in remove_indices]
    end
    
    # Compute L²-norm ratio
    l2_original = compute_l2_norm(poly, domain)
    l2_truncated = iszero(truncated) ? 0.0 : compute_l2_norm(truncated, domain)
    l2_ratio = l2_truncated / l2_original
    
    # Warn if L²-norm reduction exceeds tolerance
    if 1 - l2_ratio > l2_tolerance
        @warn "L²-norm reduction ($(round((1-l2_ratio)*100, digits=1))%) exceeds tolerance ($(l2_tolerance*100)%)"
    end
    
    return (
        polynomial = truncated,
        removed_terms = removed_terms,
        l2_ratio = l2_ratio,
        original_terms = length(monoms),
        remaining_terms = length(keep_indices)
    )
end

"""
    monomial_l2_contributions(poly, domain::BoxDomain)

Compute the L²-norm contribution of each monomial term.

# Arguments
- `poly`: Polynomial to analyze
- `domain`: Integration domain

# Returns
- Vector of named tuples with fields:
  - `monomial`: The monomial
  - `coefficient`: The coefficient
  - `l2_contribution`: L²-norm contribution of this term

The results are sorted by L²-norm contribution in descending order.
"""
function monomial_l2_contributions(poly, domain::BoxDomain)
    coeffs = coefficients(poly)
    monoms = monomials(poly)
    
    contributions = []
    
    for (coeff, monom) in zip(coeffs, monoms)
        # For a monomial c*x^α, its L²-norm is |c| * sqrt(∫ x^(2α) dx)
        # Get exponents
        vars = variables(poly)
        exponents = [degree(monom, var) for var in vars]
        doubled_exponents = 2 .* exponents
        
        # Compute integral of x^(2α)
        integral = integrate_monomial(doubled_exponents, domain)
        
        # L²-norm contribution
        l2_contrib = abs(coeff) * sqrt(integral)
        
        push!(contributions, (
            monomial = monom,
            coefficient = coeff,
            l2_contribution = l2_contrib
        ))
    end
    
    # Sort by L²-norm contribution (descending)
    sort!(contributions, by=x->x.l2_contribution, rev=true)
    
    return contributions
end

"""
    analyze_truncation_impact(poly, domain::BoxDomain; 
                            thresholds = [1e-2, 1e-4, 1e-6, 1e-8, 1e-10])

Analyze the impact of truncation for different threshold values.

# Arguments
- `poly`: Polynomial to analyze
- `domain`: Integration domain
- `thresholds`: Vector of threshold values to test

# Returns
- Vector of results for each threshold
"""
function analyze_truncation_impact(poly, domain::BoxDomain;
                                 thresholds = [1e-2, 1e-4, 1e-6, 1e-8, 1e-10])
    results = []
    
    for thresh in thresholds
        result = truncate_polynomial(poly, thresh, mode=:relative, domain=domain)
        
        push!(results, (
            threshold = thresh,
            original_terms = result.original_terms,
            remaining_terms = result.remaining_terms,
            removed_terms = length(result.removed_terms),
            sparsity = result.remaining_terms / result.original_terms,
            l2_ratio = result.l2_ratio
        ))
    end
    
    return results
end