# Type Analysis and Optimization Plan for Globtim

## Overview

This document outlines a comprehensive plan to analyze the Globtim codebase for type safety and identify opportunities to use different data types (particularly rational/fraction types) to improve computational stability and performance.

## Current State Analysis

### 1. Orthogonal Basis Construction
**Location**: `src/Main_Gen.jl` and `src/ApproxConstruct.jl`
- **Function**: `MainGenerate` constructs approximants in orthogonal tensorized bases (Chebyshev/Legendre)
- **Process**: 
  - Samples function on tensorized grid of orthogonal polynomial nodes
  - Builds Vandermonde matrix using `lambda_vandermonde`
  - Solves least squares system: `(V'V)c = V'f`
  - Coefficients stored in `ApproxPoly` struct

### 2. Monomial Basis Expansion
**Location**: `src/exact_conversion.jl` and `src/OrthogonalInterface.jl`
- **Function**: `to_exact_monomial_basis` converts from orthogonal to monomial basis
- **Process**:
  - Calls `construct_orthopoly_polynomial` which delegates to:
    - `construct_chebyshev_approx` (in `src/cheb_pol.jl`)
    - `construct_legendre_approx` (in `src/lege_pol.jl`)
  - Expands tensor product of univariate orthogonal polynomials
  - Returns `DynamicPolynomials.Polynomial` in monomial basis

### 3. Type System
**Location**: `src/Globtim.jl`
- **Precision Types**: 
  ```julia
  @enum PrecisionType Float64Precision RationalPrecision BigFloatPrecision BigIntPrecision
  ```
- **Conversion Function**: `_convert_value` in `src/cheb_pol.jl`
  - Handles conversion between numeric types
  - Special handling for irrationals via `rationalize`

### 4. Rational Number Features
- **Power-of-2 Denominators**: `closest_pow2denom_rational` function
  - Converts rationals to have power-of-2 denominators
  - Useful for floating-point compatibility
- **Current Usage**: Optional feature via `power_of_two_denom` parameter

## Identified Opportunities

### 1. Critical Points for Rational Arithmetic

1. **Vandermonde Matrix Construction** (`lambda_vandermonde`)
   - Currently hardcoded to `Float64`
   - Could benefit from type-parametric implementation
   - Rational arithmetic would preserve exactness

2. **Least Squares Solution** (`MainGenerate`)
   - Linear solve: `(V'V)c = V'f`
   - Condition number issues with Float64
   - Rational arithmetic could improve stability

3. **Basis Conversion** (Chebyshev/Legendre → Monomial)
   - Conversion coefficients have known rational values
   - Currently using floating-point approximations
   - Exact rational arithmetic would eliminate conversion errors

4. **Polynomial Evaluation Points**
   - Chebyshev nodes: `cos((2k+1)π/(2n+2))` are algebraic numbers
   - Could use high-precision rational approximations

### 2. Places for Fraction Simplification

1. **After Basis Conversion**
   - Monomial coefficients often have common factors
   - GCD reduction could simplify expressions
   - Especially beneficial before polynomial system solving

2. **Sparsification** (`src/sparsification.jl`)
   - Small coefficients could be rational approximations
   - Controlled rounding with rational arithmetic

3. **Integration/Norm Computations**
   - L2 norm integrals have exact rational values for polynomials
   - Currently using floating-point approximations

## Proposed Implementation Plan

### Phase 1: Type Safety Audit
1. **Document all mathematical function signatures**
   - Add type annotations to function arguments
   - Document expected input/output types
   - Identify implicit type conversions

2. **Create type-stable versions of key functions**
   - `lambda_vandermonde` - make type-parametric
   - Grid generation functions
   - Norm computation functions

### Phase 2: Rational Arithmetic Infrastructure
1. **Implement rational-aware linear algebra**
   - Rational matrix operations
   - Exact QR/SVD for rational matrices
   - Rational condition number estimation

2. **Create rational basis conversion tables**
   - Precompute exact conversion matrices
   - Store as rational numbers
   - Cache for common polynomial degrees

### Phase 3: Optimization Points
1. **Implement smart fraction reduction**
   - After basis conversion
   - Before polynomial system solving
   - Configurable reduction strategies

2. **Add benchmarking suite**
   - Compare Float64 vs Rational performance
   - Measure accuracy improvements
   - Profile memory usage

### Phase 4: Integration
1. **Create unified type dispatch system**
   - Single entry point with type parameter
   - Automatic type promotion rules
   - Fallback to Float64 for performance

2. **Add user-facing options**
   - Precision selection in Constructor
   - Automatic precision recommendations
   - Warning system for precision loss

## Test Design

### 1. Type Correctness Tests
```julia
# Test that operations preserve types
@testset "Type preservation" begin
    for T in [Float64, Rational{BigInt}, BigFloat]
        pol = Constructor(TR, 10, precision=T)
        @test eltype(pol.coeffs) <: T
    end
end
```

### 2. Accuracy Tests
```julia
# Compare rational vs floating-point accuracy
@testset "Rational accuracy" begin
    f = x -> x[1]^2 + x[2]^2  # Polynomial with exact representation
    pol_float = Constructor(TR, 10, precision=Float64Precision)
    pol_rational = Constructor(TR, 10, precision=RationalPrecision)
    # Rational should be exact (within representation)
    @test pol_rational.nrm == 0
end
```

### 3. Performance Benchmarks
```julia
# Benchmark different precision types
@testset "Performance comparison" begin
    for precision in [Float64Precision, RationalPrecision]
        @btime Constructor($TR, 10, precision=$precision)
    end
end
```

### 4. Stability Tests
```julia
# Test numerical stability improvements
@testset "Condition number improvement" begin
    # High-degree polynomial approximation
    pol_float = Constructor(TR, 20, precision=Float64Precision)
    pol_rational = Constructor(TR, 20, precision=RationalPrecision)
    @test pol_rational.cond_vandermonde < pol_float.cond_vandermonde
end
```

## Implementation Priority

1. **High Priority**:
   - Type-parametric `lambda_vandermonde`
   - Rational basis conversion tables
   - Type safety documentation

2. **Medium Priority**:
   - Fraction simplification utilities
   - Rational linear algebra
   - Benchmarking suite

3. **Low Priority**:
   - Automatic precision selection
   - Advanced caching mechanisms
   - GUI integration

## Expected Benefits

1. **Accuracy**: Eliminate floating-point roundoff in exact computations
2. **Stability**: Better condition numbers for high-degree polynomials
3. **Verifiability**: Exact arithmetic allows formal verification
4. **Flexibility**: Users can choose precision based on needs
5. **Performance**: Rational arithmetic can be faster for small polynomials

## Next Steps

1. Begin with Phase 1 type safety audit
2. Create proof-of-concept for rational Vandermonde matrix
3. Benchmark rational vs float performance on test cases
4. Design user API for precision selection