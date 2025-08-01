# Extended Precision Polynomial Basis Conversion Implementation Plan

## Executive Summary

This document outlines a comprehensive plan for implementing extended precision coefficients for expanding polynomial approximants from tensorized orthogonal basis (Chebyshev/Legendre) to standard monomial basis. The goal is to maintain numerical accuracy through proper type tracking and adaptive precision management while addressing current precision bottlenecks in the Globtim.jl package.

**Key Finding**: The Globtim.jl package already has excellent precision infrastructure! The main bottlenecks are minor and can be addressed with targeted fixes rather than a complete overhaul.

## Summary of Findings

### ✅ What's Already Working Well

1. **Type-Parametric Vandermonde Matrices**: Both `lambda_vandermonde` and `lambda_vandermonde_anisotropic` are fully type-parametric and preserve input precision.

2. **Comprehensive Precision System**: The existing `PrecisionType` enum with `Float64Precision`, `RationalPrecision`, `BigFloatPrecision`, and `BigIntPrecision` covers most use cases.

3. **Robust Type Conversion**: The `_convert_value` function handles conversions between numeric types correctly.

4. **Exact Basis Functions**: `symbolic_chebyshev` and `symbolic_legendre` generate exact coefficients with proper precision handling.

5. **Monomial Conversion**: The `construct_orthopoly_polynomial` pipeline preserves precision through to the final `DynamicPolynomials.Polynomial` result.

### ⚠️ Minor Issues to Address

1. **Legendre Evaluation Precision Loss**: Lines 145-149 in `ApproxConstruct.jl` convert through Float64 unnecessarily.

2. **Grid Generation**: Chebyshev nodes are always generated as Float64, which could benefit from extended precision.

3. **Linear System Solving**: Coefficient solving uses Float64 arithmetic, limiting final precision.

### 🚀 Opportunities for Enhancement

**UPDATED BASED ON USER REQUIREMENTS:**

1. **AdaptivePrecision for Polynomial Expansion**:
   - Use extended precision (BigFloat) for polynomial coefficient expansion and basis conversion
   - Keep Float64 for function evaluation at sample points (performance critical)
   - Enable easy integration with coefficient truncation for sparsity

2. **Hybrid Precision Pipeline**:
   ```
   Function Evaluation (Float64) → Coefficient Solving (Float64) →
   Basis Conversion (AdaptivePrecision/BigFloat) → Truncation (Extended Precision)
   ```

3. **Smart Coefficient Truncation**: Extended precision enables accurate identification of truly small coefficients vs numerical noise.

## Current State Analysis

### Existing Precision Infrastructure

Globtim.jl already has a solid foundation for precision handling:

1. **PrecisionType Enum**: `Float64Precision`, `RationalPrecision`, `BigFloatPrecision`, `BigIntPrecision`
2. **Type Conversion**: `_convert_value` function handles conversions between numeric types
3. **Exact Arithmetic**: Support for rational arithmetic with `Rational{BigInt}`
4. **Basis Functions**: Symbolic generation of Chebyshev and Legendre polynomials with exact coefficients

### Identified Precision Bottlenecks

#### 1. Hardcoded Float64 in lambda_vandermonde (Critical Issue)

**Location**: `src/ApproxConstruct.jl`, lines 115-188

```julia
# HARDCODED Float64 - Major bottleneck
V = zeros(Float64, n, m)  # Line 115
eval_cache = Dict{Int,Vector{Float64}}()  # Line 128
```

**Impact**: Forces all Vandermonde matrix computations to Float64 precision, regardless of input precision.

#### 2. Type Inconsistency in Basis Conversion

**Location**: `src/cheb_pol.jl`, `src/lege_pol.jl`

- `construct_chebyshev_approx` and `construct_legendre_approx` convert coefficients but may lose precision during polynomial construction
- Monomial expansion uses `DynamicPolynomials` which may not preserve extended precision types

#### 3. Precision Loss in Polynomial Construction

**Location**: `src/OrthogonalInterface.jl`, `construct_orthopoly_polynomial`

- Type conversion happens early but precision may be lost during tensor product computation
- No adaptive precision selection based on problem characteristics

### Current Type Flow Analysis

**UPDATED ANALYSIS**: The lambda_vandermonde functions have been updated to be type-parametric!

```
ApproxPoly.coeffs (Various types)
    ↓ _convert_value()
Converted coefficients (Target precision)
    ↓ lambda_vandermonde() [✓ NOW TYPE-PARAMETRIC]
Vandermonde matrix (Preserves input type T)
    ↓ construct_orthopoly_polynomial()
Monomial polynomial (Target precision preserved)
```

**Remaining Bottlenecks Identified:**

1. **Legendre Polynomial Generation** (Line 145 in ApproxConstruct.jl):
   ```julia
   poly = symbolic_legendre(degree, precision = Float64Precision, normalized = true)
   ```
   Still uses Float64Precision for polynomial generation, then converts to type T.

2. **Type Conversion in Evaluation** (Line 149):
   ```julia
   eval_cache[degree] = map(point -> T(evaluate_legendre(poly, Float64(point))), unique_points)
   ```
   Converts to Float64 for evaluation, then back to T - potential precision loss.

3. **Basis Function Construction**: Need to verify that construct_chebyshev_approx and construct_legendre_approx fully preserve extended precision types.

## Detailed Type Flow Analysis

### Complete Pipeline Trace

```
1. ApproxPoly Creation (MainGenerate/Constructor)
   ├─ Input: Function f, degree d, precision P
   ├─ Grid Generation: S::Matrix{Float64} (always Float64 from Chebyshev nodes)
   ├─ Function Evaluation: f_vals::Vector{Float64}
   └─ Coefficient Solving: coeffs::Vector{Float64} (from linear solve)

2. Precision Conversion (construct_orthopoly_polynomial)
   ├─ Input: coeffs::Vector{Float64}, precision::PrecisionType
   ├─ Conversion: coeffs_converted = map(c -> _convert_value(c, precision), coeffs)
   └─ Output: coeffs_converted::Vector{T} where T depends on precision

3. Basis Coefficient Generation (get_chebyshev_coeffs/get_legendre_coeffs)
   ├─ Input: max_degree, precision::PrecisionType
   ├─ Symbolic Generation: symbolic_chebyshev(deg, precision=precision)
   └─ Output: Vector{Vector{T}} where T matches precision

4. Polynomial Construction (construct_chebyshev_approx/construct_legendre_approx)
   ├─ Input: coeffs_converted::Vector{T}, chebyshev_coeffs::Vector{Vector{T}}
   ├─ Monomial Expansion: term *= sum(coeff_vec .* monom_vec)
   └─ Output: DynamicPolynomials.Polynomial with coefficients of type T

5. Final Result
   └─ Monomial polynomial with preserved precision type T
```

### Key Findings

**✅ GOOD**: Most of the pipeline preserves precision correctly!

1. **Type-Parametric Vandermonde**: ✅ Already implemented
2. **Precision-Aware Coefficient Generation**: ✅ Working correctly
3. **Basis Function Construction**: ✅ Preserves types through DynamicPolynomials

**⚠️ REMAINING ISSUES**:

1. **Grid Generation Bottleneck**:
   - Chebyshev nodes always generated as Float64
   - Could benefit from extended precision node generation

2. **Linear System Solving**:
   - Currently uses Float64 arithmetic for coefficient solving
   - Extended precision linear algebra could improve accuracy

3. **Legendre Evaluation Precision Loss**:
   - Line 145-149 in ApproxConstruct.jl still converts through Float64

## Extended Precision Architecture Design

### 1. Extended PrecisionType System

Based on the analysis, the current system is already quite robust. The main improvements needed are:

**Current System (Working Well):**
```julia
@enum PrecisionType Float64Precision RationalPrecision BigFloatPrecision BigIntPrecision
```

**UPDATED FOR ADAPTIVE PRECISION FOCUS:**
```julia
@enum PrecisionType begin
    # Existing types (keep as-is)
    Float64Precision
    RationalPrecision      # Rational{BigInt} - avoid for performance
    BigFloatPrecision      # BigFloat - good for extended precision
    BigIntPrecision        # BigInt - limited use

    # NEW: AdaptivePrecision - the main focus
    AdaptivePrecision      # BigFloat for expansion, Float64 for evaluation

    # Future extensions
    QuadPrecision         # Float128 (if available)
end
```

**AdaptivePrecision Design Principles:**
1. **Hybrid Pipeline**: Float64 evaluation → Extended precision expansion → Smart truncation
2. **Performance Focus**: Avoid rational arithmetic overhead
3. **Sparsity Integration**: Extended precision enables accurate coefficient truncation
4. **Seamless Integration**: Works with existing truncation/sparsification tools

**AdaptivePrecision Behavior:**
- **Function Evaluation**: Always Float64 (fast, sufficient for sampling)
- **Coefficient Solving**: Float64 (existing linear algebra performance)
- **Basis Conversion**: BigFloat with adaptive precision (256-1024 bits based on degree)
- **Coefficient Analysis**: Extended precision for accurate truncation decisions

### 2. Type-Parametric Function Design

#### Core Principle: Preserve Input Types Throughout Pipeline

```julia
function lambda_vandermonde(
    Lambda::NamedTuple,
    S::Matrix{T};
    basis::Symbol = :chebyshev
) where {T<:Real}
    # Return Matrix{T} instead of Matrix{Float64}
    V = zeros(T, n, m)  # Type-parametric allocation
    # ... rest of computation preserves T
end
```

### 3. Adaptive Precision Strategy

#### Precision Selection Framework

The adaptive precision system will automatically select the most appropriate precision type based on problem characteristics:

```julia
"""
    PrecisionSelector

Manages automatic precision selection based on problem characteristics.
"""
struct PrecisionSelector
    degree_threshold_high::Int      # Degree above which to use high precision
    degree_threshold_extreme::Int   # Degree above which to use extreme precision
    condition_threshold::Float64    # Condition number threshold
    accuracy_threshold::Float64     # Target accuracy threshold
    performance_weight::Float64     # Weight for performance vs accuracy trade-off
end

# Default selector with conservative settings
const DEFAULT_SELECTOR = PrecisionSelector(12, 20, 1e10, 1e-12, 0.5)

"""
    select_precision(selector::PrecisionSelector, problem_info::ProblemInfo)::PrecisionType

Select optimal precision based on problem characteristics.
"""
function select_precision(selector::PrecisionSelector, problem_info::ProblemInfo)::PrecisionType
    degree = problem_info.degree
    condition_est = problem_info.condition_estimate
    target_accuracy = problem_info.target_accuracy
    function_type = problem_info.function_type

    # Rule-based precision selection
    if function_type == :exact_polynomial
        # For exact polynomials, use rational arithmetic
        return degree > selector.degree_threshold_high ? HighPrecisionRational : RationalPrecision
    elseif degree > selector.degree_threshold_extreme
        # Very high degree - use adaptive precision
        return AdaptivePrecision
    elseif degree > selector.degree_threshold_high || condition_est > selector.condition_threshold
        # High degree or ill-conditioned - use high precision
        return target_accuracy < 1e-15 ? BigFloatPrecision : HighPrecisionRational
    elseif target_accuracy < selector.accuracy_threshold
        # High accuracy required
        return BigFloatPrecision
    else
        # Standard case - use rational for better accuracy than Float64
        return RationalPrecision
    end
end

"""
    ProblemInfo

Contains information about the problem for precision selection.
"""
struct ProblemInfo
    degree::Int
    dimension::Int
    condition_estimate::Float64
    target_accuracy::Float64
    function_type::Symbol  # :smooth, :oscillatory, :exact_polynomial, :rational, :unknown
    grid_size::Int
end
```

#### Enhanced _convert_value Function

```julia
"""
    _convert_value_extended(val, precision::PrecisionType, context::PrecisionContext=DEFAULT_CONTEXT)

Enhanced version of _convert_value with context-aware conversion.
"""
function _convert_value_extended(val, precision::PrecisionType, context::PrecisionContext=DEFAULT_CONTEXT)
    if precision == Float64Precision
        return Float64(val)
    elseif precision == RationalPrecision
        return _convert_to_rational(val, context.rational_precision)
    elseif precision == HighPrecisionRational
        return _convert_to_rational(val, context.high_rational_precision)
    elseif precision == BigFloatPrecision
        # Set BigFloat precision based on context
        old_precision = Base.precision(BigFloat)
        Base.setprecision(BigFloat, context.bigfloat_bits)
        result = BigFloat(val)
        Base.setprecision(BigFloat, old_precision)
        return result
    elseif precision == AdaptivePrecision
        # Dynamically select precision based on value magnitude and context
        return _adaptive_convert(val, context)
    else
        # Fallback to original implementation
        return _convert_value(val, precision)
    end
end

struct PrecisionContext
    rational_precision::Int        # Number of bits for rational denominators
    high_rational_precision::Int   # Higher precision for challenging problems
    bigfloat_bits::Int            # Precision in bits for BigFloat
    adaptive_threshold::Float64    # Threshold for adaptive precision switching
end

const DEFAULT_CONTEXT = PrecisionContext(256, 1024, 256, 1e-12)
```

## Implementation Strategy

### Phase 1: Analysis and Documentation ✓ (Current)

1. **Document Current Bottlenecks** ✓
2. **Analyze Type Flow** (In Progress)
3. **Benchmark Current vs Ideal** (Next)

### Phase 2: Core Infrastructure

1. **Extend PrecisionType Enum**
   - Add new precision types
   - Update `_convert_value` function
   - Add precision selection utilities

2. **Type-Parametric lambda_vandermonde**
   - Remove hardcoded Float64 types
   - Preserve input precision throughout
   - Support both isotropic and anisotropic grids

3. **Extended Precision Basis Functions**
   - Update `construct_chebyshev_approx`
   - Update `construct_legendre_approx`
   - Ensure coefficient type preservation

### Phase 3: Integration and Testing

1. **Comprehensive Test Suite**
   - Accuracy validation against exact solutions
   - Performance benchmarks
   - Numerical stability analysis

2. **API Integration**
   - Update `Constructor` and `MainGenerate`
   - Maintain backward compatibility
   - Add precision selection options

## Testing Strategy

### 1. Accuracy Validation Tests

```julia
@testset "Extended Precision Accuracy" begin
    # Test against known exact polynomials
    f_exact = x -> x[1]^4 + 2*x[1]^2*x[2]^2 + x[2]^4

    # Compare different precision levels
    for precision in [Float64Precision, RationalPrecision, ExtendedRationalPrecision]
        pol = Constructor(TR, 4, precision=precision)
        mono_poly = to_exact_monomial_basis(pol)

        # Measure approximation error
        error = compute_approximation_error(f_exact, mono_poly)
        @test error < precision_threshold(precision)
    end
end
```

### 2. Performance Benchmarks

```julia
@testset "Extended Precision Performance" begin
    degrees = [4, 8, 12, 16, 20]
    precisions = [Float64Precision, RationalPrecision, ExtendedRationalPrecision]

    for degree in degrees, precision in precisions
        @benchmark Constructor(TR, $degree, precision=$precision)
    end
end
```

### 3. Numerical Stability Tests

```julia
@testset "Numerical Stability" begin
    # Test high-degree polynomials
    # Test ill-conditioned problems
    # Test condition number preservation
end
```

## Expected Benefits

### 1. Accuracy Improvements

- **Exact Polynomial Representation**: For polynomial functions, achieve machine-precision accuracy
- **Reduced Approximation Error**: Maintain precision throughout basis conversion
- **Better High-Degree Behavior**: Stable computation for degrees > 20

### 2. Numerical Stability

- **Condition Number Preservation**: Avoid precision loss in ill-conditioned problems
- **Stable Basis Conversion**: Reliable conversion even for challenging functions
- **Predictable Behavior**: Consistent results across different problem types

### 3. Flexibility

- **Adaptive Precision**: Automatic selection based on problem characteristics
- **User Control**: Fine-grained precision control when needed
- **Backward Compatibility**: Existing code continues to work

## Implementation Timeline

1. **Week 1-2**: Complete analysis phase, implement extended PrecisionType
2. **Week 3-4**: Implement type-parametric lambda_vandermonde
3. **Week 5-6**: Update basis conversion functions
4. **Week 7-8**: Integration, testing, and documentation
5. **Week 9-10**: Performance optimization and final validation

## Risk Mitigation

### 1. Performance Concerns

- **Benchmark Early**: Measure overhead of extended precision
- **Selective Application**: Use extended precision only when needed
- **Optimization**: Profile and optimize critical paths

### 2. Compatibility Issues

- **Gradual Migration**: Implement alongside existing functions
- **Extensive Testing**: Test with existing examples and notebooks
- **Fallback Options**: Maintain Float64 paths for compatibility

### 3. Complexity Management

- **Modular Design**: Keep precision logic separate from core algorithms
- **Clear Interfaces**: Well-defined APIs for precision selection
- **Documentation**: Comprehensive guides for users and developers

## Success Metrics

1. **Accuracy**: 10x improvement in approximation accuracy for high-degree polynomials
2. **Stability**: Successful computation of degree 30+ polynomials
3. **Performance**: <2x computational overhead for extended precision
4. **Usability**: Seamless integration with existing workflows
5. **Coverage**: 100% test coverage for new precision features

## Detailed Implementation Plan

### Priority 1: Critical Fixes (Week 1-2)

#### 1.1 Fix Legendre Polynomial Precision Loss
**File**: `src/ApproxConstruct.jl`, lines 145-149

**Current Issue**:
```julia
poly = symbolic_legendre(degree, precision = Float64Precision, normalized = true)
eval_cache[degree] = map(point -> T(evaluate_legendre(poly, Float64(point))), unique_points)
```

**Fix**:
```julia
# Use target precision for polynomial generation
poly = symbolic_legendre(degree, precision = precision_from_type(T), normalized = true)
eval_cache[degree] = map(point -> evaluate_legendre_typed(poly, point, T), unique_points)
```

#### 1.2 Add Precision Detection Utility
**File**: `src/cheb_pol.jl` (new function)

```julia
"""
    precision_from_type(::Type{T}) -> PrecisionType

Determine the appropriate PrecisionType from a numeric type.
"""
function precision_from_type(::Type{T}) where T
    if T <: Float64
        return Float64Precision
    elseif T <: Rational{BigInt}
        return RationalPrecision
    elseif T <: BigFloat
        return BigFloatPrecision
    elseif T <: BigInt
        return BigIntPrecision
    else
        return Float64Precision  # Safe fallback
    end
end
```

### Priority 2: Extended Precision Types (Week 3-4)

#### 2.1 Extend PrecisionType Enum
**File**: `src/Globtim.jl`, line 19

**Current**:
```julia
@enum PrecisionType Float64Precision RationalPrecision BigFloatPrecision BigIntPrecision
```

**Extended**:
```julia
@enum PrecisionType begin
    Float64Precision
    RationalPrecision
    BigFloatPrecision
    BigIntPrecision
    HighPrecisionRational    # Enhanced rational arithmetic
    AdaptivePrecision       # Context-aware precision selection
    QuadPrecision          # 128-bit float (if available)
end
```

#### 2.2 Enhanced _convert_value Function
**File**: `src/cheb_pol.jl`, function `_convert_value`

Add support for new precision types with context-aware conversion.

### Priority 3: Adaptive Precision System (Week 5-6)

#### 3.1 Problem Analysis Integration
**File**: `src/Main_Gen.jl`, function `MainGenerate`

Add automatic problem analysis and precision selection:

```julia
function MainGenerate(
    f, n::Int, d, delta::Float64, alpha::Float64,
    scale_factor, scl::Float64;
    precision::Union{PrecisionType, Symbol} = :adaptive,  # New option
    # ... other parameters
)
    # Analyze problem characteristics
    if precision == :adaptive
        problem_info = analyze_problem(f, n, d, delta, alpha)
        precision = select_precision(DEFAULT_SELECTOR, problem_info)
        verbose > 0 && println("Selected precision: $precision")
    end

    # Continue with existing logic using selected precision
    # ...
end
```

#### 3.2 Problem Analysis Function
**File**: `src/precision_analysis.jl` (new file)

```julia
"""
    analyze_problem(f, n, d, delta, alpha) -> ProblemInfo

Analyze problem characteristics to guide precision selection.
"""
function analyze_problem(f, n::Int, d, delta::Float64, alpha::Float64)
    # Estimate function type by sampling
    function_type = classify_function_type(f, n)

    # Estimate condition number from degree and dimension
    condition_estimate = estimate_condition_number(d, n)

    # Determine target accuracy from delta
    target_accuracy = delta / 10  # Conservative estimate

    # Extract degree information
    degree = extract_degree(d)

    return ProblemInfo(
        degree, n, condition_estimate, target_accuracy,
        function_type, calculate_grid_size(d, n)
    )
end
```

### Priority 4: Integration and Testing (Week 7-8)

#### 4.1 Update User-Facing APIs
**File**: `src/Main_Gen.jl`, function `Constructor`

Add precision selection options:

```julia
function Constructor(
    TR::test_input,
    degree;
    precision::Union{PrecisionType, Symbol} = :adaptive,
    precision_selector::Union{PrecisionSelector, Nothing} = nothing,
    # ... other parameters
)
    # Handle precision selection
    if precision == :adaptive
        selector = precision_selector !== nothing ? precision_selector : DEFAULT_SELECTOR
        problem_info = analyze_test_input(TR, degree)
        precision = select_precision(selector, problem_info)
    end

    # Continue with MainGenerate call
    return MainGenerate(TR.f, TR.dim, degree, TR.delta, TR.alpha,
                       TR.scale_factor, TR.scl; precision=precision, ...)
end
```

#### 4.2 Comprehensive Test Suite
**File**: `test/test_extended_precision.jl`

Implement the benchmark suite created earlier with additional tests for:
- Precision selection accuracy
- Performance regression testing
- Numerical stability validation
- Edge case handling

### Priority 5: Documentation and Examples (Week 9-10)

#### 5.1 User Documentation
**File**: `docs/src/extended_precision.md`

Create comprehensive guide covering:
- When to use different precision types
- Performance vs accuracy trade-offs
- Automatic precision selection
- Manual precision control
- Troubleshooting precision issues

#### 5.2 Example Notebooks
**Directory**: `Examples/ExtendedPrecision/`

Create examples demonstrating:
- High-degree polynomial approximation
- Exact polynomial representation
- Challenging function approximation
- Performance comparison studies

## Implementation Checklist

### Phase 1: Analysis ✅
- [x] Document current bottlenecks
- [x] Analyze type flow
- [x] Create benchmark suite

### Phase 2: Core Fixes
- [ ] Fix Legendre precision loss
- [ ] Add precision detection utilities
- [ ] Extend PrecisionType enum
- [ ] Enhance _convert_value function

### Phase 3: Adaptive System
- [ ] Implement problem analysis
- [ ] Create precision selection logic
- [ ] Integrate with MainGenerate
- [ ] Add user-facing options

### Phase 4: Testing & Integration
- [ ] Run comprehensive benchmarks
- [ ] Validate precision improvements
- [ ] Test performance impact
- [ ] Update existing examples

### Phase 5: Documentation
- [ ] Write user guide
- [ ] Create example notebooks
- [ ] Update API documentation
- [ ] Performance tuning guide

This plan provides a roadmap for implementing extended precision support while maintaining the robustness and usability of the Globtim.jl package.