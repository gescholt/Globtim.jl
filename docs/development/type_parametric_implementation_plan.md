# Type-Parametric Implementation Plan for Symbolic Exactness

## Overview

Globtim already has a comprehensive exact arithmetic system with `PrecisionType` enum, `_convert_value` function, and exact polynomial construction through `construct_orthopoly_polynomial`. The critical blocker is that `lambda_vandermonde` in `ApproxConstruct.jl` is hardcoded to `Float64`, preventing the use of arbitrary precision types.

This plan focuses on fixing `lambda_vandermonde` and optimizing the symbolic computation pipeline to push exactness as far as possible before switching to numerical procedures.

## Core Philosophy

**Push symbolic exactness until the last responsible moment** - maintain exact representations through:
1. Rational arithmetic for algebraic values
2. Lazy evaluation for conversion matrices
3. Symbolic polynomial representations
4. Adaptive precision switching based on problem characteristics

## Phase 1: Fix lambda_vandermonde Type Parametrization

### 1.1 Make lambda_vandermonde Generic

The existing function at lines 112-188 in `ApproxConstruct.jl` needs to be made type-parametric:

```julia
function lambda_vandermonde(
    Lambda::NamedTuple, 
    S::Matrix{T}; 
    basis=:chebyshev,
    normalize=true
) where T<:Real
    n = size(S, 1)  # number of sample points
    m = Lambda.size[1]  # number of basis functions
    
    # Use the input type T throughout (currently hardcoded to Float64)
    V = zeros(T, n, m)  # Line 115: was zeros(Float64, n, m)
    
    # Type-stable caching
    eval_cache = Dict{Int,Vector{T}}()  # Line 128: was Dict{Int,Vector{Float64}}()
    
    # Rest of implementation needs T instead of Float64...
end
```

### 1.2 Update Call Sites

Fix all callers to pass properly typed matrices:
- `MainGenerate`: Pass grid with correct precision type
- `ApproxConstruct`: Ensure type consistency throughout

## Phase 2: Symbolic Computation Pipeline

### 2.1 Exact Grid Generation

```julia
# Generate exact rational coordinates for Chebyshev points
function chebyshev_points_exact(n::Int)
    # cos((2k+1)π/(2n+2)) for k=0:n-1
    # Use symbolic representation or high-precision rational approximation
    points = Vector{Rational{BigInt}}(undef, n)
    for k in 0:n-1
        # Strategy 1: Algebraic number representation
        # Strategy 2: High-precision rational approximation
        # Strategy 3: Lazy evaluation with exact formulas
    end
    return points
end
```

### 2.2 Leverage Existing Symbolic Infrastructure

Globtim already has exact polynomial evaluation through:
- `symbolic_chebyshev` and `symbolic_legendre` functions
- `evaluate_chebyshev` and `evaluate_legendre` functions
- `_convert_value` for type conversions

The key is to ensure `lambda_vandermonde` can use these existing functions by accepting the appropriate types.

### 2.3 Lazy Conversion Matrices

```julia
# Precompute exact conversion matrices for common degrees
struct ExactConversionMatrix{T}
    from_basis::Symbol
    to_basis::Symbol
    degree::Int
    matrix::Matrix{T}
end

# Cache of exact conversion matrices
const EXACT_CONVERSIONS = Dict{Tuple{Symbol,Symbol,Int}, ExactConversionMatrix}()

function get_exact_conversion(from::Symbol, to::Symbol, degree::Int, ::Type{T}) where T
    key = (from, to, degree)
    if haskey(EXACT_CONVERSIONS, key)
        return EXACT_CONVERSIONS[key]
    else
        # Compute exact conversion matrix
        matrix = compute_exact_conversion_matrix(from, to, degree, T)
        EXACT_CONVERSIONS[key] = ExactConversionMatrix(from, to, degree, matrix)
        return EXACT_CONVERSIONS[key]
    end
end
```

## Phase 3: Adaptive Precision Strategy

### 3.1 Integrate with Existing Precision System

Globtim already has a `PrecisionType` enum system:
- `Float64Precision`
- `RationalPrecision` 
- `BigFloatPrecision`
- `BigIntPrecision`

The Constructor function already accepts a `precision` parameter. We need to ensure this flows through to `lambda_vandermonde` by converting the grid to the appropriate type before calling it.

### 3.2 Precision Switching Points

```julia
# Define where to switch from symbolic to numeric
struct ComputationPlan
    vandermonde_type::Type
    leastsquares_type::Type
    conversion_type::Type
    output_type::Type
end

function plan_computation(
    problem::ProblemSpec,
    user_preference::Union{Symbol,Nothing}=nothing
)
    # Decision tree for precision switching
    if user_preference == :exact
        # Full symbolic pipeline
        return ComputationPlan(
            Rational{BigInt},
            Rational{BigInt},
            Rational{BigInt},
            Rational{BigInt}
        )
    elseif problem.conditioning > 1e12
        # High precision for ill-conditioned
        return ComputationPlan(
            BigFloat,
            BigFloat,
            Rational{BigInt},  # Exact conversion
            BigFloat
        )
    else
        # Standard precision with exact conversion
        return ComputationPlan(
            Float64,
            Float64,
            Rational{BigInt},  # Still use exact conversion
            Float64
        )
    end
end
```

## Phase 4: Implementation Strategy

### 4.1 Incremental Changes

1. **Week 1**: Fix lambda_vandermonde type parametrization
   - Update function signature
   - Fix all call sites
   - Add tests for different types

2. **Week 2**: Implement exact grid generation
   - Rational Chebyshev points
   - Type-stable grid construction
   - Benchmarks vs Float64

3. **Week 3**: Symbolic polynomial evaluation
   - Exact Chebyshev recurrence
   - Rational polynomial arithmetic
   - Integration with existing code

4. **Week 4**: Adaptive precision framework
   - Problem analysis functions
   - Precision recommendation system
   - User API design

### 4.2 Testing Strategy

```julia
@testset "Symbolic Exactness Tests" begin
    # Test 1: Exact polynomial approximation
    f = x -> x[1]^2 + x[2]^2  # Should be exactly representable
    
    # Test 2: Precision preservation
    # Verify no precision loss through pipeline
    
    # Test 3: Adaptive switching
    # Verify correct precision choices
    
    # Test 4: Performance vs accuracy tradeoffs
    # Benchmark different precision strategies
end
```

## Phase 5: API Design

### 5.1 User-Facing Interface

```julia
# Simple API with smart defaults
pol = approximate(f, dim, degree; 
    precision = :auto,      # :auto, :exact, :float64, :bigfloat
    symbolic_until = :conversion,  # :never, :vandermonde, :solve, :conversion, :always
    tolerance = 1e-10
)

# Advanced API for control
pol = approximate(f, dim, degree;
    grid_type = Rational{BigInt},
    vandermonde_type = Float64,
    solve_type = Float64,
    conversion_type = Rational{BigInt},
    output_type = Float64
)
```

### 5.2 Pipeline Visualization

```
Function f
    ↓
Grid Generation [Rational/Float64/BigFloat]
    ↓
Vandermonde Construction [Type T]
    ↓
Least Squares Solve [Type T or convert]
    ↓
Orthogonal Coefficients [Type T]
    ↓
Basis Conversion [Exact Rational preferred]
    ↓
Monomial Polynomial [Output type]
    ↓
Polynomial System Solver
```

## Benefits of This Approach

1. **Accuracy**: Maintain exactness where it matters most
2. **Flexibility**: Users can choose precision based on needs
3. **Performance**: Switch to numerics when symbolic is too slow
4. **Robustness**: Better conditioning for difficult problems
5. **Debugging**: Can run in exact mode to verify correctness

## Key Insights

1. **Conversion matrices** are where exactness matters most - they're reusable and small
2. **Grid points** benefit from exactness for polynomial evaluation
3. **Vandermonde** can often use numerics if well-conditioned
4. **Least squares** solve is where numerical methods shine
5. **Adaptive switching** based on problem analysis optimizes the tradeoff

## Next Steps

1. Implement type-parametric lambda_vandermonde (Critical)
2. Create exact Chebyshev evaluation functions
3. Design precision recommendation system
4. Build test suite for accuracy/performance tradeoffs
5. Document best practices for users