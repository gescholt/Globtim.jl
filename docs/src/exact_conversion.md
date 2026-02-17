# Exact Polynomial Conversion

## Overview

Globtim provides functionality to convert polynomial approximations from orthogonal bases (Chebyshev or Legendre) to exact monomial form. This is useful for:

- Symbolic manipulation of polynomials
- Integration with computer algebra systems
- Understanding polynomial structure
- Exact arithmetic operations
- Finding critical points symbolically

## Main Functions

### `to_exact_monomial_basis`

Converts a polynomial from orthogonal basis to monomial basis using exact arithmetic.

```julia
to_exact_monomial_basis(pol::ApproxPoly; variables=nothing)
```

**Arguments:**
- `pol::ApproxPoly`: Polynomial approximation from Globtim
- `variables`: Array of polynomial variables (created automatically if not provided)

**Returns:**
- `DynamicPolynomials.Polynomial`: Polynomial in monomial basis with exact coefficients

**Example:**
```julia
using Globtim
using DynamicPolynomials

# Create a polynomial approximation
TR = TestInput(x -> sin(π*x[1])*cos(π*x[2]), dim=2, center=[0.0, 0.0], sample_range=1.0)
pol = Constructor(TR, 8, basis=:chebyshev, precision=RationalPrecision)

# Convert to monomial basis
@polyvar x y
mono_poly = to_exact_monomial_basis(pol, variables=[x, y])
```

### `exact_polynomial_coefficients`

Convenience function to get exact monomial coefficients directly from a function.

```julia
exact_polynomial_coefficients(f::Function, dim::Int, degree::Int; kwargs...)
```

**Arguments:**
- `f::Function`: Function to approximate
- `dim::Int`: Dimension of the input
- `degree::Int`: Maximum polynomial degree
- `basis::Symbol = :chebyshev`: Basis to use (`:chebyshev` or `:legendre`)
- `center::Vector = zeros(dim)`: Center of approximation domain
- `sample_range::Real = 1.0`: Radius of approximation domain
- `tolerance::Real = 0.5`: Tolerance for approximation
- `precision = Float64Precision`: Arithmetic precision

**Returns:**
- `DynamicPolynomials.Polynomial`: Polynomial in monomial basis

**Example:**
```julia
# Direct conversion from function to monomial polynomial
f = x -> x[1]^2 + x[2]^2 - x[1]*x[2]
mono_poly = exact_polynomial_coefficients(f, 2, 4, basis=:chebyshev)
```

## Using Rational Arithmetic

The Constructor function supports exact rational arithmetic through the `precision` parameter:

```julia
pol = Constructor(TR, degree, 
    basis = :chebyshev,
    precision = RationalPrecision,  # Use exact rational arithmetic
    normalized = false,             # Use unnormalized basis functions
    power_of_two_denom = false     # Don't restrict to power-of-2 denominators
)
```

## Example: Complete Workflow

```julia
using Globtim
using DynamicPolynomials

# Define a test function
f = x -> exp(-x[1]^2 - x[2]^2)

# Create test input
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=1.0)

# Construct polynomial with rational coefficients
pol = Constructor(TR, 6, basis=:legendre, precision=RationalPrecision)

# Convert to monomial basis
@polyvar x y
mono_poly = to_exact_monomial_basis(pol, variables=[x, y])

# Now you can:
# 1. Take derivatives symbolically
dx = differentiate(mono_poly, x)
dy = differentiate(mono_poly, y)

# 2. Evaluate at specific points
point_value = substitute(mono_poly, x => 0.5, y => 0.5)

# 3. Extract coefficients
terms_list = terms(mono_poly)
for term in terms_list[1:min(5, length(terms_list))]
    coeff = coefficient(term)
    mon = monomial(term)
    println("$coeff * $mon")
end
```

## Finding Critical Points

Once you have the polynomial in either orthogonal or monomial form, you can find critical points:

```julia
# Using the orthogonal polynomial directly (more efficient)
@polyvar x_vars[1:2]
real_pts = solve_polynomial_system(
    x_vars, 
    2,  # dimension
    pol.degree, 
    pol.coeffs;
    basis = pol.basis,
    precision = pol.precision,
    normalized = pol.normalized
)

# Process the critical points
df_crit = process_crit_pts(real_pts, f, TR)
```

## Implementation Details

The exact conversion functionality leverages existing Globtim components:

1. **`Constructor`** with `precision=RationalPrecision` computes exact rational coefficients
2. **`construct_orthopoly_polynomial`** (internal) builds the polynomial in monomial form
3. **`to_exact_monomial_basis`** provides a clean API and handles domain scaling

The conversion preserves numerical precision and allows for exact symbolic manipulation of the resulting polynomial.

## See Also

- [Polynomial Approximation](polynomial_approximation.md) - General polynomial approximation
- [Critical Point Analysis](critical_point_analysis.md) - Finding and analyzing critical points
- [Examples](examples.md) - More examples of using Globtim