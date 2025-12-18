# Sparse Re-Optimization: Comparison Benchmark Procedure

**Purpose**: Rigorously test whether high-precision re-optimization justifies the computational overhead compared to simple truncation

**Focus**: 3D and 4D examples where complexity and ill-conditioning become significant

---

## Benchmark Design Principles

### Why 3D and 4D?

1. **Complexity Scaling**: Number of terms grows as O(d^k) where d=dimension, k=degree
   - 2D, degree 10: ~66 terms
   - 3D, degree 10: ~286 terms
   - 4D, degree 10: ~1001 terms

2. **Ill-Conditioning**: Monomial Vandermonde condition number grows exponentially with dimension
   - 2D: cond ~ 10⁶
   - 3D: cond ~ 10⁸
   - 4D: cond ~ 10¹⁰⁺

3. **Sparsity Benefit**: More terms → more opportunity for sparsification

4. **Practical Relevance**: Real problems often 3D+ (spatial + time, multi-parameter)

---

## Test Function Categories

### Category 1: Naturally Sparse Functions (Re-optimization should help)

```julia
# 3D Examples
f1_3d(x) = x[1]^4 + x[2]^4 + x[3]^4
# True polynomial, exactly sparse in monomial basis

f2_3d(x) = x[1]^2 * x[2]^2 + x[2]^2 * x[3]^2 + x[1]^2 * x[3]^2
# Tensor product structure, moderately sparse

f3_3d(x) = (x[1]^2 + x[2]^2 + x[3]^2 - 1)^2
# Sphere function, naturally sparse

# 4D Examples
f1_4d(x) = sum(x[i]^4 for i in 1:4)
# Additive separable

f2_4d(x) = x[1]^2 * x[2]^2 + x[3]^2 * x[4]^2
# Paired interactions

f3_4d(x) = (sum(x[i]^2 for i in 1:4) - 1)^2
# Hypersphere
```

### Category 2: Dense Functions (Re-optimization critical)

```julia
# 3D Examples
f4_3d(x) = 1 / (1 + 25*(x[1]^2 + x[2]^2 + x[3]^2))
# 3D Runge function - very dense in monomials

f5_3d(x) = exp(x[1] * x[2] * x[3])
# Exponential interaction - extremely dense

f6_3d(x) = sin(2π*x[1]) * cos(2π*x[2]) * sin(2π*x[3])
# Oscillatory product - dense expansion

# 4D Examples
f4_4d(x) = 1 / (1 + 25*sum(x[i]^2 for i in 1:4))
# 4D Runge function

f5_4d(x) = exp(sum(x[i]*x[i+1] for i in 1:3))
# Chained interactions

f6_4d(x) = prod(sin(π*x[i]) for i in 1:4)
# Oscillatory product
```

### Category 3: Multi-Scale Functions (Local refinement test)

```julia
# 3D Examples
f7_3d(x) = sin(2π*x[1]) * sin(2π*x[2]) * sin(2π*x[3]) +
           5*exp(-50*(x[1]^2 + x[2]^2 + x[3]^2))
# Smooth background + localized peak

f8_3d(x) = x[1]^2 + x[2]^2 + x[3]^2 +
           10*exp(-100*((x[1]-0.5)^2 + (x[2]-0.5)^2 + (x[3]-0.5)^2))
# Quadratic + sharp peak

# 4D Examples
f7_4d(x) = sum(sin(2π*x[i]) for i in 1:4) +
           5*exp(-50*sum(x[i]^2 for i in 1:4))
# Additive oscillations + peak

f8_4d(x) = sum(x[i]^2 for i in 1:4) +
           10*exp(-100*sum((x[i]-0.3)^2 for i in 1:4))
# Quadratic + localized feature
```

---

## Metrics to Collect

### Accuracy Metrics

1. **L2-Norm Ratio**: `||p_sparse||₂ / ||p_original||₂`
   - Target: > 0.95 (preserve 95% of norm)
   - Critical indicator of approximation quality

2. **Max Pointwise Error**: `max|f(x) - p_sparse(x)|` over test grid
   - Measure worst-case accuracy
   - Important for local refinement

3. **Mean Absolute Error**: `mean|f(x) - p_sparse(x)|`
   - Average accuracy over domain

4. **Relative L∞ Error**: `||f - p||_∞ / ||f||_∞`
   - Normalized worst-case error

### Sparsity Metrics

5. **Sparsity Ratio**: `n_nonzero / n_total`
   - How many coefficients retained
   - Target: < 0.5 (50%+ reduction)

6. **Compression Factor**: `n_total / n_nonzero`
   - How much compression achieved

7. **Effective Dimension**: Count of truly active monomials
   - After accounting for threshold

### Computational Metrics

8. **Construction Time**: Time for initial approximation
   - Baseline cost

9. **Truncation Time**: Time for simple truncation
   - Fast baseline

10. **Re-optimization Time**: Time for sparse re-optimization
    - Higher cost, hopefully worth it

11. **Evaluation Time**: Time to evaluate polynomial (10k points)
    - Benefit of sparsity

12. **Memory Usage**: Storage for polynomial representation
    - Dense vs sparse

### Conditioning Metrics

13. **Orthogonal Condition Number**: `cond(Vandermonde_chebyshev)`
    - Should be moderate (10²-10⁴)

14. **Monomial Condition Number**: `cond(Vandermonde_monomial)`
    - Will be large (10⁶-10¹²)

15. **Sparse Gram Condition**: `cond(G_sparse)` for re-optimization
    - Still large, but BigFloat handles it

---

## Benchmark Test Matrix

### Dimension: 3D

| Function | Degree | Threshold | Expected Sparsity | Expected Improvement |
|----------|--------|-----------|------------------|---------------------|
| f1_3d (x^4) | 10 | 1e-6 | ~10% | High (exact) |
| f1_3d | 12 | 1e-6 | ~8% | High |
| f1_3d | 15 | 1e-6 | ~5% | High |
| f2_3d (x²y²) | 10 | 1e-6 | ~15% | High |
| f3_3d (sphere) | 10 | 1e-6 | ~20% | Medium |
| f4_3d (Runge) | 10 | 1e-6 | ~60% | Medium |
| f4_3d | 12 | 1e-6 | ~50% | High |
| f4_3d | 15 | 1e-6 | ~40% | High |
| f5_3d (exp) | 10 | 1e-6 | ~80% | Low (too dense) |
| f5_3d | 12 | 1e-5 | ~60% | Medium |
| f6_3d (osc) | 10 | 1e-6 | ~70% | Medium |
| f7_3d (multi) | 10 | 1e-6 | ~50% | High |
| f8_3d (peak) | 12 | 1e-6 | ~40% | High |

### Dimension: 4D

| Function | Degree | Threshold | Expected Sparsity | Expected Improvement |
|----------|--------|-----------|------------------|---------------------|
| f1_4d (x^4) | 8 | 1e-6 | ~5% | Very High |
| f1_4d | 10 | 1e-6 | ~3% | Very High |
| f2_4d (pairs) | 8 | 1e-6 | ~10% | High |
| f3_4d (hypersphere) | 8 | 1e-6 | ~15% | High |
| f4_4d (Runge) | 8 | 1e-6 | ~50% | High |
| f4_4d | 10 | 1e-6 | ~40% | High |
| f5_4d (chained) | 8 | 1e-5 | ~60% | Medium |
| f6_4d (osc) | 8 | 1e-6 | ~70% | Medium |
| f7_4d (multi) | 8 | 1e-6 | ~50% | High |
| f8_4d (peak) | 8 | 1e-6 | ~40% | High |

**Total Tests**: ~24 test cases

---

## Benchmark Execution Protocol

### Phase 1: Baseline Construction (No Sparsity)

```julia
for (fname, f, dim) in test_functions
    TR = test_input(f, dim=dim, center=zeros(dim), sample_range=1.0)

    # Measure construction time
    t_construct = @elapsed begin
        pol_baseline = Constructor(TR, degree, basis=:chebyshev)
    end

    # Collect metrics
    results[fname]["baseline"] = Dict(
        :construction_time => t_construct,
        :n_coeffs => length(pol_baseline.coeffs),
        :l2_norm => pol_baseline.nrm,
        :cond_vandermonde => pol_baseline.cond_vandermonde
    )
end
```

### Phase 2: Simple Truncation

```julia
for (fname, f, dim) in test_functions
    pol_baseline = load_baseline(fname)

    # Truncation time
    t_truncate = @elapsed begin
        result_trunc = to_exact_monomial_basis_sparse(
            pol_baseline,
            threshold = threshold,
            reoptimize = false
        )
    end

    # Accuracy metrics
    test_grid = generate_test_grid(dim, n_test=100)
    errors_trunc = [abs(f(pt) - result_trunc.polynomial(pt...)) for pt in test_grid]

    results[fname]["truncation"] = Dict(
        :time => t_truncate,
        :sparsity => result_trunc.sparsity_info.new_nnz / length(pol_baseline.coeffs),
        :l2_ratio => result_trunc.l2_ratio,
        :max_error => maximum(errors_trunc),
        :mean_error => mean(errors_trunc)
    )
end
```

### Phase 3: Re-optimization (Float64)

```julia
for (fname, f, dim) in test_functions
    pol_baseline = load_baseline(fname)

    t_reopt_f64 = @elapsed begin
        result_reopt_f64 = to_exact_monomial_basis_sparse(
            pol_baseline,
            threshold = threshold,
            reoptimize = true,
            precision = Float64
        )
    end

    test_grid = generate_test_grid(dim, n_test=100)
    errors_reopt_f64 = [abs(f(pt) - result_reopt_f64.polynomial(pt...)) for pt in test_grid]

    results[fname]["reopt_float64"] = Dict(
        :time => t_reopt_f64,
        :sparsity => result_reopt_f64.sparsity_info.new_nnz / length(pol_baseline.coeffs),
        :l2_ratio => result_reopt_f64.l2_ratio,
        :max_error => maximum(errors_reopt_f64),
        :mean_error => mean(errors_reopt_f64),
        :cond_number => result_reopt_f64.optimization_info.condition_number
    )
end
```

### Phase 4: Re-optimization (BigFloat)

```julia
for (fname, f, dim) in test_functions
    pol_baseline = load_baseline(fname)

    t_reopt_bf = @elapsed begin
        result_reopt_bf = to_exact_monomial_basis_sparse(
            pol_baseline,
            threshold = threshold,
            reoptimize = true,
            precision = BigFloat
        )
    end

    test_grid = generate_test_grid(dim, n_test=100)
    errors_reopt_bf = [abs(f(pt) - result_reopt_bf.polynomial(pt...)) for pt in test_grid]

    results[fname]["reopt_bigfloat"] = Dict(
        :time => t_reopt_bf,
        :sparsity => result_reopt_bf.sparsity_info.new_nnz / length(pol_baseline.coeffs),
        :l2_ratio => result_reopt_bf.l2_ratio,
        :max_error => maximum(errors_reopt_bf),
        :mean_error => mean(errors_reopt_bf),
        :cond_number => result_reopt_bf.optimization_info.condition_number
    )
end
```

### Phase 5: Evaluation Speed Comparison

```julia
for (fname, f, dim) in test_functions
    # Load all polynomial variants
    poly_dense = to_exact_monomial_basis(load_baseline(fname))
    poly_trunc = results[fname]["truncation"].polynomial
    poly_reopt = results[fname]["reopt_bigfloat"].polynomial

    # Generate large test set
    eval_grid = [randn(dim) for _ in 1:10000]

    # Time each
    t_dense = @elapsed for pt in eval_grid; poly_dense(pt...); end
    t_trunc = @elapsed for pt in eval_grid; poly_trunc(pt...); end
    t_reopt = @elapsed for pt in eval_grid; poly_reopt(pt...); end

    results[fname]["evaluation"] = Dict(
        :time_dense => t_dense,
        :time_truncated => t_trunc,
        :time_reoptimized => t_reopt,
        :speedup_trunc => t_dense / t_trunc,
        :speedup_reopt => t_dense / t_reopt
    )
end
```

---

## Analysis & Decision Criteria

### Primary Decision: Is Re-optimization Worth It?

**Re-optimization is worth the overhead if**:

1. **Accuracy Improvement > 10%**:
   ```julia
   improvement = (error_truncation - error_reoptimized) / error_truncation
   improvement > 0.1  # 10% better
   ```

2. **L2-Norm Preservation Much Better**:
   ```julia
   l2_ratio_reopt > l2_ratio_trunc + 0.05  # 5% better norm preservation
   ```

3. **Ill-Conditioning Matters**:
   ```julia
   cond_number > 1e8  # Very ill-conditioned
   # → BigFloat likely helps significantly
   ```

4. **Time Overhead Acceptable**:
   ```julia
   time_reopt < 10 * time_truncate  # Less than 10x slower
   # AND
   time_reopt < 60 seconds  # Practical for interactive use
   ```

5. **Total Workflow Benefit**:
   ```julia
   # If used for local refinement:
   time_saved_in_refinement = speedup_evaluation * n_refinement_iterations
   time_saved_in_refinement > time_reopt_overhead
   ```

### Secondary Analysis: When to Use Each Method

**Use Simple Truncation**:
- Low-dimensional (d ≤ 2)
- Low degree (< 10)
- Moderately sparse functions
- Exploratory analysis
- Time-critical applications

**Use Float64 Re-optimization**:
- Moderate conditioning (10⁶ < cond < 10⁹)
- 3D problems
- Balance speed/accuracy

**Use BigFloat Re-optimization**:
- High-dimensional (d ≥ 3)
- High degree (≥ 12)
- Severely ill-conditioned (cond > 10⁹)
- Dense functions expanded to monomials
- Production-quality approximations
- Local refinement workflows

---

## Reporting Template

### Summary Table (Per Test Case)

| Metric | Baseline | Truncation | Reopt (F64) | Reopt (BF) | Winner |
|--------|----------|------------|-------------|------------|--------|
| L2-norm ratio | 1.0 | 0.92 | 0.96 | 0.98 | BigFloat |
| Max error | - | 0.045 | 0.021 | 0.015 | BigFloat |
| Mean error | - | 0.008 | 0.004 | 0.003 | BigFloat |
| Sparsity | 0% | 70% | 70% | 70% | Tie |
| Time (s) | 0.5 | 0.1 | 1.2 | 8.5 | Truncation |
| Eval speedup | 1.0x | 3.2x | 3.1x | 3.0x | All sparse |

### Decision Matrix

| Function Type | Dimension | Degree | Recommendation |
|---------------|-----------|--------|----------------|
| Sparse poly | 3D | 10 | Truncation sufficient |
| Sparse poly | 4D | 10 | Float64 reopt |
| Dense (Runge) | 3D | 12 | BigFloat reopt ✓ |
| Dense (Runge) | 4D | 10 | BigFloat reopt ✓ |
| Multi-scale | 3D | 12 | BigFloat reopt ✓ |
| Multi-scale | 4D | 10 | BigFloat reopt ✓ |
| Oscillatory | 3D | 10 | Float64 reopt |
| Very dense | Any | Any | May not sparsify well |

### Overall Recommendation

Based on benchmark results:

**✓ Recommended for Re-optimization**:
- Functions: [list]
- Dimensions: 3D+
- Degrees: 10+
- Sparsity achieved: >30%
- Accuracy improvement: >10%

**✗ Not Recommended**:
- Functions: [list]
- Reasons: [minimal improvement / too slow / insufficient sparsity]

---

## Implementation: Automated Benchmark Suite

**File**: `test/benchmarks/sparse_comparison_3d_4d.jl`

```julia
using Globtim
using DataFrames
using CSV
using Printf
using Statistics

include("benchmark_test_functions.jl")  # Function definitions

function run_full_benchmark(;
    dims = [3, 4],
    degrees = [8, 10, 12],
    thresholds = [1e-6, 1e-5, 1e-4],
    n_test_points = 100
)
    results = DataFrame()

    for dim in dims
        test_funcs = get_test_functions(dim)

        for (fname, f) in test_funcs
            for degree in degrees
                for threshold in thresholds
                    println("Testing: $fname ($(dim)D), degree=$degree, threshold=$threshold")

                    row = run_single_test(
                        fname, f, dim, degree, threshold, n_test_points
                    )

                    push!(results, row)
                end
            end
        end
    end

    return results
end

function run_single_test(fname, f, dim, degree, threshold, n_test)
    # Phase 1: Baseline
    TR = test_input(f, dim=dim, center=zeros(dim), sample_range=1.0)

    t_baseline = @elapsed pol = Constructor(TR, degree, basis=:chebyshev)

    # Phase 2: Truncation
    t_trunc = @elapsed result_trunc = to_exact_monomial_basis_sparse(
        pol, threshold=threshold, reoptimize=false
    )

    # Phase 3: Float64 reopt
    t_reopt_f64 = @elapsed result_f64 = to_exact_monomial_basis_sparse(
        pol, threshold=threshold, reoptimize=true, precision=Float64
    )

    # Phase 4: BigFloat reopt
    t_reopt_bf = @elapsed result_bf = to_exact_monomial_basis_sparse(
        pol, threshold=threshold, reoptimize=true, precision=BigFloat
    )

    # Test errors
    test_grid = generate_test_grid(dim, n_test)
    errors_trunc = [abs(f(pt) - result_trunc.polynomial(pt...)) for pt in test_grid]
    errors_f64 = [abs(f(pt) - result_f64.polynomial(pt...)) for pt in test_grid]
    errors_bf = [abs(f(pt) - result_bf.polynomial(pt...)) for pt in test_grid]

    # Return row
    return (
        function_name = fname,
        dimension = dim,
        degree = degree,
        threshold = threshold,
        n_coeffs_baseline = length(pol.coeffs),
        n_coeffs_sparse = result_bf.sparsity_info.new_nnz,
        sparsity_ratio = result_bf.sparsity_info.new_nnz / length(pol.coeffs),

        time_baseline = t_baseline,
        time_truncation = t_trunc,
        time_reopt_f64 = t_reopt_f64,
        time_reopt_bf = t_reopt_bf,

        l2_ratio_trunc = result_trunc.l2_ratio,
        l2_ratio_f64 = result_f64.l2_ratio,
        l2_ratio_bf = result_bf.l2_ratio,

        max_error_trunc = maximum(errors_trunc),
        max_error_f64 = maximum(errors_f64),
        max_error_bf = maximum(errors_bf),

        mean_error_trunc = mean(errors_trunc),
        mean_error_f64 = mean(errors_f64),
        mean_error_bf = mean(errors_bf),

        cond_baseline = pol.cond_vandermonde,
        cond_sparse = result_bf.optimization_info.condition_number
    )
end

# Run benchmark
results = run_full_benchmark()

# Save results
CSV.write("benchmark_results_3d_4d.csv", results)

# Generate report
generate_comparison_report(results)
```

---

## Expected Outcomes

### Hypothesis 1: Re-optimization Helps for Dense Functions
**Test**: 3D/4D Runge function, degree 10-12
**Expected**: BigFloat re-optimization preserves L2-norm 5-10% better than truncation
**Measure**: `l2_ratio_bf - l2_ratio_trunc > 0.05`

### Hypothesis 2: High Dimension Amplifies Benefit
**Test**: Same function, 3D vs 4D
**Expected**: 4D shows larger improvement from re-optimization
**Measure**: `improvement_4d > improvement_3d + 0.03`

### Hypothesis 3: Time Overhead Acceptable
**Test**: All cases
**Expected**: BigFloat re-optimization < 30 seconds for degree 12
**Measure**: `time_reopt_bf < 30`

### Hypothesis 4: Evaluation Speedup Compensates
**Test**: Local refinement simulation (100 iterations)
**Expected**: Time saved in evaluation > time spent in re-optimization
**Measure**: `speedup * 100 * eval_time > reopt_time`

---

## Success Criteria

**Re-optimization is validated if**:

1. ✅ **Accuracy**: Mean improvement >10% in 60% of test cases
2. ✅ **L2-Norm**: Better preservation in 80% of test cases
3. ✅ **Practicality**: <30s for all 3D cases, <2min for 4D cases
4. ✅ **Scaling**: Benefit increases with dimension/degree
5. ✅ **Workflow**: Net time saving in local refinement scenarios

---

## Deliverables

1. **Benchmark Script**: `test/benchmarks/sparse_comparison_3d_4d.jl`
2. **Test Functions**: `test/benchmarks/benchmark_test_functions.jl`
3. **Results CSV**: Tabulated results for all test cases
4. **Analysis Report**: Summary with recommendations
5. **Visualization**: Plots comparing methods

**Timeline**: 2-3 hours to implement and run full benchmark suite
