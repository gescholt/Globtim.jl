# Benchmark Test Plan: Type Accuracy Comparison

## Objective
Compare accuracy of polynomial approximation using different data types (Float64, Rational, BigFloat) with focus on n=4 (low monomial count) to establish baseline understanding.

## 5 Core Tests

### Test 1: Exact Polynomial Recovery
**Function**: `f(x,y) = x² + y²`  
**What we measure**:
- Approximation error (should be ~0 for Rational with degree ≥ 2)
- Coefficient exactness (compare to known exact coefficients)
- Conditioning of Vandermonde matrix

**Why this test**: Verifies that rational arithmetic can recover exact polynomials perfectly, establishing baseline trust.

**Adaptive strategy**: 
- If error = 0 with Rational → increase dimension to n=3,4
- If error > 0 with adequate degree → investigate basis conversion

### Test 2: Rational Function Approximation  
**Function**: `f(x,y) = 1/(1 + x² + y²)`  
**What we measure**:
- Convergence rate vs degree (2,4,6,8)
- Coefficient growth pattern
- Relative improvement of Rational vs Float64

**Why this test**: Non-polynomial function tests approximation quality and numerical stability.

**Adaptive strategy**:
- If Rational much better → test with poles closer to domain
- If similar performance → focus on computation time tradeoff

### Test 3: High-Frequency Oscillation
**Function**: `f(x,y) = cos(πx) * cos(πy)`  
**What we measure**:
- Spectral convergence rate
- Aliasing errors at low degrees
- Gibbs phenomenon near boundaries

**Why this test**: Tests ability to capture oscillatory behavior, sensitive to precision.

**Adaptive strategy**:
- If poor at low degrees → increase to 10,12,14
- If Rational helps → try higher frequencies

### Test 4: Near-Singular Function
**Function**: `f(x,y) = 1/(0.01 + x² + y²)`  
**What we measure**:
- Condition number explosion
- Maximum coefficient magnitude
- Error near singularity vs far from it

**Why this test**: Stress test for numerical conditioning, where exact arithmetic should excel.

**Adaptive strategy**:
- If conditioning > 1e12 → try different basis (Legendre vs Chebyshev)
- If Rational stable → decrease 0.01 → 0.001

### Test 5: Sparse Polynomial
**Function**: `f(x,y) = x⁴ + y⁴` (missing cross terms)  
**What we measure**:
- Sparsity detection (how many coeffs are "zero")
- Threshold for zero detection with different types
- Memory efficiency potential

**Why this test**: Tests whether exact arithmetic produces true zeros vs near-zeros.

**Adaptive strategy**:
- If high sparsity with Rational → test sparser patterns
- If no sparsity benefit → investigate tolerance settings

## Measurement Framework

```julia
struct TestMetrics
    # Primary metrics
    approximation_error::Float64      # ||f - p||_L2
    max_pointwise_error::Float64      # max|f(x) - p(x)| on test grid
    condition_number::Float64         # cond(Vandermonde)
    
    # Coefficient analysis  
    coefficient_norm::Float64         # ||coeffs||_2
    max_coefficient::Float64          # max|coeff|
    sparsity_ratio::Float64          # fraction < 1e-10
    exact_zeros::Int                 # count of exactly 0 (Rational only)
    
    # Performance metrics
    construction_time::Float64        # Time to build approximation
    evaluation_time::Float64          # Time to evaluate at 100 points
    memory_bytes::Int                # Total memory usage
    
    # Comparison metrics
    error_ratio_vs_float64::Float64  # For Rational/BigFloat
    time_ratio_vs_float64::Float64   # Performance penalty
end
```

## Test Execution Strategy

### Phase 1: Baseline (n=4, dim=2)
1. Run all 5 tests with degree = [2,4,6,8]
2. Compare Float64 vs Rational vs BigFloat
3. Identify winner scenarios

### Phase 2: Adaptive Exploration
Based on Phase 1 results:
- **If Rational shows 0 error on Test 1** → Try exact recovery of degree 10,20 polynomials
- **If Test 3 shows aliasing** → Increase degree range to [8,12,16,20]
- **If Test 4 conditioning explodes** → Try normalized basis, different grid
- **If Test 5 shows sparsity** → Design specific sparse polynomial tests

### Phase 3: Focused Deep Dive
Pick 1-2 most promising test/type combinations:
- Increase dimension to 3,4
- Test extreme parameters
- Benchmark practical applications

## Decision Tree

```
Start: Run 5 tests, degree 2-8, three types
    ↓
If Rational error = 0 on exact polynomial?
    Yes → Test higher degree exact recovery (10,20,30)
    No → Debug: check implementation
    ↓
If Rational significantly better on rational function?
    Yes → Test with harder singularities
    No → Focus on computational efficiency
    ↓
If conditioning much better with Rational?
    Yes → Implement adaptive precision switching
    No → Float64 sufficient for most cases
    ↓
If sparsity detected with Rational?
    Yes → Implement sparse polynomial format
    No → Dense format adequate
```

## Success Criteria

1. **Exact polynomial**: Rational achieves error < 1e-15
2. **Rational function**: >10x accuracy improvement with Rational
3. **Oscillatory**: Correct spectrum up to Nyquist frequency
4. **Near-singular**: Condition number improved by >100x
5. **Sparse**: >50% coefficients are exactly zero with Rational

This systematic approach ensures we understand when each precision type provides value, guiding implementation priorities.