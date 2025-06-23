# Degree Formats in Globtim

This document explains the three degree format options in Globtim: `:one_d_for_all`, `:one_d_per_dim`, and `:fully_custom`.

## Overview

The degree parameter in Globtim functions like `SupportGen`, `Constructor`, and `solve_polynomial_system` uses a tuple format `(format_symbol, value)` to specify how polynomial degrees are handled across dimensions.

## Format Options

### 1. `:one_d_for_all`
**Usage**: `(:one_d_for_all, degree)`

- Applies the same maximum degree to all dimensions
- Creates a standard total degree polynomial space
- Most commonly used format

**Example**:
```julia
d = (:one_d_for_all, 10)  # Max total degree 10 in all dimensions
```

**Behavior**:
- For 3 variables with degree 10, generates all monomials where the sum of exponents ≤ 10
- Examples: x₁¹⁰, x₁⁵x₂³x₃², x₁x₂x₃⁸, etc.

### 2. `:one_d_per_dim`
**Usage**: `(:one_d_per_dim, [d₁, d₂, ..., dₙ])`

- Specifies different maximum degrees per dimension
- Creates a tensor product polynomial space
- Useful for anisotropic problems

**Example**:
```julia
d = (:one_d_per_dim, [10, 2, 13])  # Different max degree per variable
```

**Behavior**:
- For the example above:
  - x₁ can have degree up to 10
  - x₂ can have degree up to 2
  - x₃ can have degree up to 13
- Generates tensor product: all combinations where x₁^i₁ × x₂^i₂ × x₃^i₃ with i₁ ≤ 10, i₂ ≤ 2, i₃ ≤ 13

### 3. `:fully_custom`
**Usage**: `(:fully_custom, custom_support)`

- Allows complete control over the monomial support
- User provides exact exponent vectors
- For advanced use cases with specific polynomial structures

**Example**:
```julia
# Using EllipseSupport function
d = (:fully_custom, EllipseSupport([0, 0, 0], [1, 1, 1], 300))
```

**Behavior**:
- Uses only the monomials specified by the custom support
- No automatic generation of monomials
- Complete flexibility but requires manual specification

## Implementation Status

### ✅ Fully Implemented in:
1. **`get_lambda_exponent_vectors`** (src/ApproxConstruct.jl)
   - Core function that generates exponent vectors
   - All three formats properly handled

2. **`SupportGen`** (src/ApproxConstruct.jl)
   - Wrapper that creates support matrices
   - All formats supported with proper error handling

3. **`MainGenerate`** (src/Main_Gen.jl)
   - Handles degree extraction for computing space dimension
   - All formats recognized

### ⚠️ Integration Issues Fixed:
Previously, several functions were calling `SupportGen` with plain integer degrees instead of the tuple format. These have been fixed:
- `construct_chebyshev_approx` (src/cheb_pol.jl)
- `construct_legendre_approx` (src/lege_pol.jl)
- `construct_orthopoly_polynomial` (src/OrthogonalInterface.jl)
- `Constructor` function in Main_Gen.jl

### Current Usage Pattern:
```julia
# Standard workflow
n = 3  # dimensions
d = (:one_d_for_all, 10)  # degree format
TR = test_input(f, dim=n, center=[0,0,0], sample_range=1.0)
pol = Constructor(TR, d)  # Now expects tuple format
solutions = solve_polynomial_system(x, n, d, pol.coeffs)
```

### Backward Compatibility:
For convenience, all major functions now accept plain integers which are automatically converted to `(:one_d_for_all, degree)`:
```julia
# These are equivalent:
pol = Constructor(TR, 10)  # Automatically converted
pol = Constructor(TR, (:one_d_for_all, 10))  # Explicit format

# Also works for solve_polynomial_system:
solutions = solve_polynomial_system(x, n, 10, pol.coeffs)  # Auto-converted
solutions = solve_polynomial_system(x, n, (:one_d_for_all, 10), pol.coeffs)  # Explicit
```

## Examples from Tests

From `experiments/week2/custom_support.jl`:
```julia
# Example 1: Standard total degree
d = (:one_d_for_all, 10)

# Example 2: Per-dimension degrees
d = (:one_d_per_dim, [10, 2, 13])

# Example 3: Custom elliptical support
d = (:fully_custom, EllipseSupport([0, 0, 0], [1, 1, 1], 300))
```

## Notes

1. All major functions (`Constructor`, `solve_polynomial_system`, `construct_chebyshev_approx`, `construct_legendre_approx`, `construct_orthopoly_polynomial`, `main_nd`) now automatically wrap simple integer degrees as `(:one_d_for_all, degree)` for backward compatibility.

2. The `:fully_custom` option requires the user to provide a properly formatted list of exponent vectors.

3. Error messages guide users to use the correct format when invalid input is provided.

4. The degree format affects:
   - The polynomial space dimension
   - The monomial basis used
   - The computational complexity
   - The approximation properties

## Performance Considerations

- `:one_d_for_all`: Standard choice, balanced performance
- `:one_d_per_dim`: Can reduce dimension if some variables need lower degrees
- `:fully_custom`: Most flexible but requires careful design of support