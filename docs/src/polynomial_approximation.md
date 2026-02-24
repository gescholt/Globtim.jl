# Polynomial Approximation

This guide covers the polynomial approximation methods used in Globtim, including basis functions, L2-norm computation, and post-processing techniques.

## Overview

Globtim uses orthogonal polynomial bases (Chebyshev or Legendre) to approximate objective functions over compact domains. This approach provides:
- Well-conditioned basis representations (compared to monomial basis)
- Spectral convergence for smooth functions (exponential for analytic functions)
- Critical point finding via polynomial system solving, with solution count bounded by Bezout's theorem

## Basis Functions

### Chebyshev Polynomials

Default choice for most problems:
```julia
pol = Constructor(TR, degree, basis=:chebyshev)
```

**Advantages:**
- Near-minimax approximation at Chebyshev nodes (within a log factor of the best polynomial approximation)
- Extrema at grid boundaries minimize Runge phenomenon
- Exponential convergence for analytic functions; algebraic convergence for C^k functions

**Grid points:** Chebyshev extrema at cos(πk/n) for k=0,...,n

### Legendre Polynomials

Alternative basis with different properties:
```julia
pol = Constructor(TR, degree, basis=:legendre)
```

**Advantages:**
- Orthogonal with respect to uniform weight
- Nodes do not cluster at boundaries (unlike Chebyshev), which may reduce endpoint sensitivity
- Natural for probability-weighted problems

**Grid points:** Zeros of Legendre polynomials

## L2-Norm Computation

The L2-norm measures approximation quality and is used throughout Globtim for error tracking.

### Riemann Sum Method

Fast discrete approximation using grid points:
```julia
norm_riemann = discrete_l2_norm_riemann(polynomial, grid)
```

**Characteristics:**
- O(n^d) complexity for d dimensions
- Accuracy depends on grid density
- Suitable for quick estimates

### Quadrature Method

High-accuracy integration using Gaussian quadrature:
```julia
norm_quad = compute_l2_norm_quadrature(polynomial, grid_spec, basis=:chebyshev)
```

**Characteristics:**
- Exact for polynomials up to degree 2n-1
- Uses tensor product quadrature
- Supports anisotropic grids
- Higher accuracy than Riemann sums

**Example comparison:**
```julia
# Create polynomial approximation
pol = Constructor(TR, 10)

# Compare methods
norm_r = discrete_l2_norm_riemann(pol.polynomial, pol.grid)
norm_q = compute_l2_norm_quadrature(pol.polynomial, [11, 11], basis=:chebyshev)

println("Riemann norm: ", norm_r)
println("Quadrature norm: ", norm_q)
println("Relative difference: ", abs(norm_r - norm_q) / norm_q)
```

## Exact Arithmetic Conversion

Convert from orthogonal basis to exact monomial representation:

```julia
# Get exact monomial coefficients
exact_coeffs = to_exact_monomial_basis(pol, grid_points)

# Or directly from function
exact_coeffs = exact_polynomial_coefficients(f, degree, domain_bounds)
```

This enables:
- Symbolic manipulation
- Exact solver usage ([msolve](https://msolve.lip6.fr/))
- Sparsification analysis

## Post-Processing

### Sparsification

Remove small coefficients while tracking quality:
```julia
# Basic sparsification
sparse_poly, stats = sparsify_polynomial(polynomial, threshold=1e-10)

# Analyze tradeoffs
results = analyze_sparsification_tradeoff(
    polynomial,
    thresholds=logspace(-12, -6, 20),
    compute_error_norm=true
)
```

See [Polynomial Sparsification](sparsification.md) for detailed guide.

### Truncation

Alternative to sparsification that removes entire monomials:
```julia
# Truncate with L2-norm monitoring
truncated, removed_norm = truncate_polynomial(polynomial, threshold=1e-8)

# Analyze impact
impact = analyze_truncation_impact(polynomial, threshold)
```

## Anisotropic Grids

For functions with different scales per dimension:
```julia
# Different points per dimension
grid = generate_anisotropic_grid([20, 10, 5], basis=:chebyshev)
pol = Constructor(TR, grid)
```

## Best Practices

1. **Degree Selection**
   - Start with degree 6-8 for exploration
   - Increase to 10-12 for production runs
   - Monitor approximation error via `pol.nrm`

2. **Basis Choice**
   - Use Chebyshev (default) for general functions
   - Try Legendre for uniform-weighted problems
   - Both support exact conversion and sparsification

3. **L2-Norm Computation**
   - Use quadrature for final results
   - Riemann sums for quick iteration
   - Check relative difference for validation

4. **Memory Management**
   - Enable sparsification for high-degree polynomials
   - Use anisotropic grids for multiscale functions
   - Monitor coefficient growth with dimension

## Related Documentation

- [Core Algorithm](core_algorithm.md) - Overall optimization approach
- [Polynomial Sparsification](sparsification.md) - Memory optimization techniques
- [API Reference](api_reference.md) - Complete function documentation