# Polynomial Sparsification and Exact Arithmetic

Globtim now includes advanced features for exact polynomial arithmetic, sparsification, and truncation analysis. These features help reduce polynomial complexity while maintaining approximation quality.

## Overview

The sparsification module provides:
- **Exact conversion** from orthogonal bases (Chebyshev/Legendre) to monomial basis
- **Intelligent sparsification** that zeros small coefficients while tracking L²-norm preservation
- **Truncation analysis** with quality metrics
- **Multiple L²-norm computation methods** for verification

## Basic Usage

### Exact Monomial Conversion

Convert a Globtim polynomial to exact monomial form:

```julia
using Globtim
using DynamicPolynomials

# Create a polynomial approximation
f = x -> sin(3*x[1])
TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
pol = Constructor(TR, 10, basis=:chebyshev)

# Convert to exact monomial basis
@polyvar x
mono_poly = to_exact_monomial_basis(pol, variables=[x])
```

### Polynomial Sparsification

Reduce polynomial complexity by removing small coefficients:

```julia
# Sparsify with 1% relative threshold
result = sparsify_polynomial(pol, 0.01, mode=:relative)

println("Achieved $(round((1-result.sparsity)*100))% sparsity")
println("L² norm preserved: $(round(result.l2_ratio*100, digits=1))%")
println("Removed $(length(result.zeroed_indices)) coefficients")
```

### Truncation Analysis

Analyze the impact of different truncation thresholds:

```julia
# Analyze truncation with multiple thresholds
domain = BoxDomain(1, 1.0)  # [-1,1] domain
thresholds = [1e-2, 1e-4, 1e-6, 1e-8]
results = analyze_truncation_impact(mono_poly, domain, thresholds=thresholds)

# Display results
for res in results
    println("Threshold $(res.threshold): $(res.remaining_terms)/$(res.original_terms) terms, L² ratio: $(round(res.l2_ratio, digits=4))")
end
```

## Advanced Features

### L²-Norm Computation Methods

Compare different L²-norm computation approaches:

```julia
# Method 1: Vandermonde-based (efficient for Globtim polynomials)
l2_vand = compute_l2_norm_vandermonde(pol)

# Method 2: Grid-based (for monomial polynomials)
domain = BoxDomain(1, 1.0)
l2_grid = compute_l2_norm(mono_poly, domain)

# Method 3: Modified coefficients
sparse_coeffs = copy(pol.coeffs)
sparse_coeffs[abs.(sparse_coeffs) .< 1e-6] .= 0
l2_sparse = compute_l2_norm_coeffs(pol, sparse_coeffs)
```

### Approximation Error Analysis

Track how sparsification affects approximation quality:

```julia
# Analyze approximation error vs sparsity tradeoff
results = analyze_approximation_error_tradeoff(f, pol, TR, 
                                              thresholds=[1e-4, 1e-6, 1e-8])

for res in results
    println("Threshold $(res.threshold):")
    println("  Sparsity: $(round((1-res.sparsity)*100))%")
    println("  Approximation error: $(res.approx_error)")
    println("  Error increase: $(round((res.approx_error_ratio-1)*100, digits=1))%")
end
```

### Preserving Important Coefficients

When sparsifying, you can preserve specific coefficients:

```julia
# Preserve the first 5 coefficients (often the most important)
result = sparsify_polynomial(pol, 1e-4, mode=:relative, 
                           preserve_indices=[1, 2, 3, 4, 5])
```

## Complete Workflow Example

Here's a complete workflow for polynomial approximation with sparsification:

```julia
using Globtim
using DynamicPolynomials

# 1. Define function and create approximation
f = x -> 1/(1 + 25*x[1]^2)  # Runge function
TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
pol = Constructor(TR, 20, basis=:chebyshev)

# 2. Analyze sparsification options
sparsity_analysis = analyze_sparsification_tradeoff(pol, 
                                                   thresholds=[1e-2, 1e-3, 1e-4, 1e-5])

# 3. Choose threshold based on analysis
chosen_threshold = 1e-4
sparse_pol = sparsify_polynomial(pol, chosen_threshold, mode=:relative).polynomial

# 4. Convert to exact monomial form
@polyvar x
mono_sparse = to_exact_monomial_basis(sparse_pol, variables=[x])

# 5. Verify quality
domain = BoxDomain(1, 1.0)
quality = verify_truncation_quality(
    to_exact_monomial_basis(pol, variables=[x]), 
    mono_sparse, 
    domain
)

println("Final polynomial has $(count(!iszero, sparse_pol.coeffs)) non-zero terms")
println("L² norm preservation: $(round(quality.l2_ratio*100, digits=1))%")
```

## Performance Considerations

1. **Vandermonde approach**: More efficient than polynomial construction for L² norms
2. **Sparsification benefits**: 
   - Significant sparsity achievable while preserving L² accuracy
   - Reduced memory usage and faster polynomial operations
3. **Exact arithmetic**: Use `RationalPrecision` for exact coefficients, `Float64Precision` for speed

## API Reference

### Main Functions

- `to_exact_monomial_basis(pol; variables)` - Convert to monomial basis
- `sparsify_polynomial(pol, threshold; mode, preserve_indices)` - Sparsify polynomial
- `truncate_polynomial(poly, threshold; mode, domain, l2_tolerance)` - Truncate with L² checking
- `compute_l2_norm_vandermonde(pol)` - Efficient L² norm computation
- `analyze_sparsification_tradeoff(pol; thresholds)` - Analyze sparsity options
- `verify_truncation_quality(original, truncated, domain)` - Verify L² preservation

### Types

- `BoxDomain{T}` - Represents box domain [-a,a]ⁿ
- `AbstractDomain` - Abstract type for integration domains