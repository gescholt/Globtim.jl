# Comparison of Chebyshev vs Monomial Basis Truncation

## Overview

This document outlines the implementation plan for comparing two different polynomial truncation strategies:
1. **Chebyshev Truncation**: Truncate coefficients in the Chebyshev basis (current approach)
2. **Monomial Truncation**: Convert to monomial basis first, then truncate

The key question: Which method produces sparser polynomials for msolve while maintaining accuracy?

## Core Implementation

### 1. Convert ApproxPoly to Monomial Basis with Exact Arithmetic

```julia
using DynamicPolynomials
using Globtim
using ExactCoefficients

function convert_to_monomial_exact(pol::Globtim.ApproxPoly)
    # Create polynomial variables
    dim = length(pol.support[1])  # Get dimension from support
    @polyvar x[1:dim]
    
    # Convert coefficients to exact rational arithmetic
    rational_coeffs = [Rational{BigInt}(c) for c in pol.coeffs]
    
    # Use Globtim's construct_orthopoly_polynomial to get monomial expansion
    poly_monomial = Globtim.construct_orthopoly_polynomial(
        x,
        rational_coeffs,
        pol.degree,
        pol.basis,
        Globtim.RationalPrecision;
        normalized=true,
        power_of_two_denom=false
    )
    
    return poly_monomial
end
```

### 2. Truncate Small Monomial Coefficients

```julia
function truncate_monomial_polynomial(poly_monomial, threshold::Real; mode=:relative)
    # Extract terms and coefficients
    terms = DynamicPolynomials.terms(poly_monomial)
    
    if isempty(terms)
        return poly_monomial
    end
    
    # Get coefficient magnitudes
    coeffs = [DynamicPolynomials.coefficient(t) for t in terms]
    coeffs_abs = [abs(Float64(c)) for c in coeffs]  # Convert to Float64 for comparison
    
    # Determine actual threshold
    if mode == :relative
        max_coeff = maximum(coeffs_abs)
        actual_threshold = threshold * max_coeff
    else
        actual_threshold = threshold
    end
    
    # Build truncated polynomial
    truncated_poly = zero(poly_monomial)
    for (i, term) in enumerate(terms)
        if coeffs_abs[i] >= actual_threshold
            truncated_poly += term
        end
    end
    
    return truncated_poly
end
```

### 3. Count Monomial Support

```julia
function count_monomial_support(poly_monomial)
    terms = DynamicPolynomials.terms(poly_monomial)
    return length(terms)
end
```

### 4. Analysis Function Comparing Both Truncation Methods

```julia
function compare_truncation_methods(pol::Globtim.ApproxPoly, threshold::Real)
    # Method 1: Truncate in Chebyshev basis
    result_cheb = ExactCoefficients.sparsify_polynomial(pol, threshold)
    poly_cheb_sparse_mono = convert_to_monomial_exact(result_cheb.polynomial)
    
    # Method 2: Convert to monomial, then truncate
    poly_monomial = convert_to_monomial_exact(pol)
    poly_mono_truncated = truncate_monomial_polynomial(poly_monomial, threshold)
    
    # Count support sizes
    nnz_original_cheb = count(!iszero, pol.coeffs)
    nnz_sparse_cheb = count(!iszero, result_cheb.polynomial.coeffs)
    nnz_original_mono = count_monomial_support(poly_monomial)
    nnz_cheb_sparse_mono = count_monomial_support(poly_cheb_sparse_mono)
    nnz_mono_truncated = count_monomial_support(poly_mono_truncated)
    
    return (
        # Chebyshev basis counts
        cheb_original = nnz_original_cheb,
        cheb_sparse = nnz_sparse_cheb,
        cheb_reduction = 1 - nnz_sparse_cheb/nnz_original_cheb,
        
        # Monomial basis counts
        mono_original = nnz_original_mono,
        mono_after_cheb_truncation = nnz_cheb_sparse_mono,
        mono_after_mono_truncation = nnz_mono_truncated,
        
        # Comparison
        mono_reduction_cheb_method = 1 - nnz_cheb_sparse_mono/nnz_original_mono,
        mono_reduction_mono_method = 1 - nnz_mono_truncated/nnz_original_mono,
        
        # The polynomials themselves
        poly_cheb_method = poly_cheb_sparse_mono,
        poly_mono_method = poly_mono_truncated
    )
end
```

## Usage Example

```julia
# Load packages
using Globtim
using ExactCoefficients

# Create polynomial approximation (e.g., Deuflhard function)
f(x) = exp(x[1]) / (1 + 100*(x[1] - x[2])^2)
TR = Globtim.test_input(f, dim=2, center=[0.5, 0.5], sample_range=0.5, test_type=:function)
pol = Globtim.Constructor(TR, 20, basis=:chebyshev)

# Compare truncation methods
threshold = 1e-8
results = compare_truncation_methods(pol, threshold)

# Display results
println("Original Chebyshev coefficients: ", results.cheb_original)
println("Sparse Chebyshev coefficients: ", results.cheb_sparse)
println("Chebyshev reduction: ", round(results.cheb_reduction * 100, digits=1), "%")
println()
println("Original monomial terms: ", results.mono_original)
println("Monomials after Chebyshev truncation: ", results.mono_after_cheb_truncation)
println("Monomials after monomial truncation: ", results.mono_after_mono_truncation)
println()
println("Monomial reduction (Cheb method): ", round(results.mono_reduction_cheb_method * 100, digits=1), "%")
println("Monomial reduction (Mono method): ", round(results.mono_reduction_mono_method * 100, digits=1), "%")
```

## Key Analysis Points

### 1. Sparsity Comparison
- How many monomials are eliminated by each method?
- Which method gives better sparsity for msolve?

### 2. Threshold Equivalence
- Same threshold value has different meanings in each basis
- Need to find equivalent thresholds for fair comparison

### 3. Accuracy Analysis
- Compute approximation errors for both methods
- Compare L²-norm preservation

### 4. Computational Efficiency
- Cost of basis conversion
- msolve runtime with different sparsity levels

## Expected Insights

1. **Chebyshev Truncation Effects**:
   - Removing one Chebyshev coefficient affects multiple monomials
   - High-degree Chebyshev polynomials expand to many monomials
   - May not achieve desired monomial sparsity

2. **Monomial Truncation Effects**:
   - Direct control over which monomials remain
   - More predictable sparsity for msolve
   - May lose orthogonality benefits

3. **Trade-offs**:
   - Chebyshev: Better numerical properties, less monomial control
   - Monomial: Direct sparsity control, potential numerical issues

## Next Steps

1. Implement the functions in a new Julia file
2. Test with Deuflhard and other test functions
3. Create visualization of sparsity patterns
4. Benchmark msolve performance with both methods
5. Determine guidelines for choosing truncation strategy

## Implementation Notes

- Use exact rational arithmetic to avoid floating-point errors
- Leverage Globtim's existing conversion infrastructure
- Ensure compatibility with ExactCoefficients.jl functions
- Consider memory usage for high-degree polynomials