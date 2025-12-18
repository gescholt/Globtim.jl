# Sparsification Testing Guide

This guide explains how to test the new sparsification features in Globtim.

## Overview

The sparsification implementation includes comprehensive test coverage across multiple dimensions and complexity levels:

1. **Unit Tests** - Standard test suite for core functionality
2. **3D Extensive Tests** - Comprehensive 3D polynomial sparsification
3. **4D Extensive Tests** - Comprehensive 4D polynomial sparsification
4. **Documentation Verification** - Tests all examples from documentation

## Test Files

### Core Test Suite

| File | Purpose | Dimensions |
|------|---------|-----------|
| `test_sparsification.jl` | Core sparsification tests | 1D, 2D |
| `test_truncation.jl` | Truncation analysis tests | 1D, 2D |
| `verify_sparsification_examples.jl` | Documentation examples | 1D |

### Extensive Test Suites

| File | Purpose | Tests |
|------|---------|-------|
| `sparsification_3d_extensive.jl` | 3D comprehensive tests | 8 test scenarios |
| `sparsification_4d_extensive.jl` | 4D comprehensive tests | 10 test scenarios |

## Running the Tests

### Quick Start - Run All Unit Tests

```bash
# From project root
julia --project=. test/runtests.jl
```

This runs the standard test suite including:
- `test_sparsification.jl`
- `test_truncation.jl`
- All other Globtim tests

### Run Specific Test Files

#### 1D/2D Unit Tests

```bash
julia --project=. test/test_sparsification.jl
julia --project=. test/test_truncation.jl
```

#### Documentation Examples

```bash
julia --project=. test/verify_sparsification_examples.jl
```

Expected output: 7 examples with ✓ checkmarks

#### 3D Extensive Tests

```bash
julia --project=. test/sparsification_3d_extensive.jl
```

Tests performed:
1. 3D Trigonometric product across degrees (6,8,10,12)
2. 3D Gaussian-like function with multiple thresholds
3. 3D Polynomial with known structure
4. 3D Approximation error analysis
5. 3D Truncation analysis on monomial form
6. 3D L²-norm computation method comparison
7. 3D Coefficient preservation
8. 3D Monomial L² contributions

**Runtime:** ~2-5 minutes depending on hardware

#### 4D Extensive Tests

```bash
julia --project=. test/sparsification_4d_extensive.jl
```

Tests performed:
1. 4D Shubert function across degrees (4,5,6,7)
2. 4D Deuflhard function with detailed tradeoffs
3. 4D Camel function with multi-level sparsification
4. 4D Gaussian product with error analysis
5. 4D Truncation analysis
6. 4D L²-norm computation consistency
7. 4D Moderate-degree polynomial sparsification (5-8)
8. 4D Coefficient importance ranking
9. 4D Monomial L² contributions
10. 4D Complete workflow validation

**Runtime:** ~3-8 minutes depending on hardware
**Memory:** ~2-8GB RAM (degree 7-8 in 4D)

### Run All Sparsification Tests

```bash
# Run all in sequence
julia --project=. -e '
using Pkg
Pkg.activate(".")
include("test/test_sparsification.jl")
include("test/test_truncation.jl")
include("test/verify_sparsification_examples.jl")
include("test/sparsification_3d_extensive.jl")
include("test/sparsification_4d_extensive.jl")
'
```

## What Each Test Suite Covers

### `test_sparsification.jl` (Unit Tests)

Tests core functionality:
- ✓ Basic sparsification (relative/absolute modes)
- ✓ Coefficient preservation
- ✓ L²-norm computation methods
- ✓ Sparsification analysis
- ✓ Approximation error tradeoff
- ✓ Exact monomial conversion
- ✓ Truncation quality verification
- ✓ Edge cases
- ✓ BoxDomain integration

### `test_truncation.jl` (Unit Tests)

Tests truncation features:
- ✓ Basic truncation (relative/absolute)
- ✓ L² tolerance warnings
- ✓ Monomial L² contributions
- ✓ Truncation impact analysis
- ✓ Complete workflow
- ✓ Edge cases
- ✓ Different domain sizes
- ✓ L² computation consistency
- ✓ Term preservation

### `verify_sparsification_examples.jl` (Documentation)

Validates all examples from `docs/src/sparsification.md`:
1. Exact monomial conversion
2. Polynomial sparsification
3. Truncation analysis
4. L²-norm computation methods
5. Approximation error analysis
6. Coefficient preservation
7. Complete workflow

### `sparsification_3d_extensive.jl` (3D Tests)

Comprehensive 3D testing with:
- Multiple polynomial degrees (6,8,10,12)
- Various threshold levels (1e-2 to 1e-6)
- Different function types (trig, gaussian, polynomial)
- L²-norm method comparisons
- Coefficient preservation strategies
- Monomial contribution analysis

### `sparsification_4d_extensive.jl` (4D Tests)

Comprehensive 4D testing with:
- Benchmark functions (Shubert, Deuflhard, Camel)
- High-degree polynomials (up to degree 14)
- Multi-level sparsification comparison
- Approximation error vs sparsity tradeoffs
- L²-norm computation accuracy in high dimensions
- Coefficient importance ranking
- Complete workflow validation

## Expected Results

### Typical Performance Metrics

| Threshold | L² Preserved | Coefficient Reduction |
|-----------|-------------|---------------------|
| 1e-3 | 95-98% | 50-70% |
| 1e-4 | 96-99% | 40-60% |
| 1e-5 | 98-99.5% | 30-50% |
| 1e-6 | 99-99.9% | 20-40% |

### L²-Norm Computation Agreement

Different methods should agree within:
- **1D-2D:** < 5% difference
- **3D:** < 10% difference
- **4D:** < 15% difference

Higher dimensions have larger differences due to quadrature error accumulation.

## Interpreting Test Output

### Success Indicators

✓ All tests pass without errors
✓ L² preservation > 95% for threshold 1e-4
✓ Sparsity achieved: 30-70% coefficient reduction
✓ Approximation error increases < 5% with sparsification
✓ Preserved coefficients remain intact

### What to Check

1. **L² Ratio**: Should be close to 1.0 (>0.95 for typical thresholds)
2. **Sparsity**: Higher sparsity = more coefficients removed
3. **Error Ratio**: How much approximation error increases (should be < 1.1)
4. **Term Counts**: Monomial terms should decrease significantly

## Troubleshooting

### Tests Take Too Long

- 4D tests with high degrees can be slow (3-8 minutes is normal)
- Reduce polynomial degrees in extensive tests if needed
- Use fewer quadrature points for L² norm computation

### L² Norm Methods Disagree

- In high dimensions (4D), 15-20% difference is acceptable
- Grid-based L² needs more points per dimension for accuracy
- Increase `n_points` parameter if needed

### Memory Issues / Process Killed

**Symptoms:** Process killed during Vandermonde matrix computation in 4D tests

**Cause:** High-degree 4D polynomials require massive memory:
- Degree 8: ~2-4GB RAM (495 coefficients)
- Degree 10: ~10-20GB RAM (1001 coefficients)
- Degree 12+: >50GB RAM (not recommended)

**Solutions:**
1. The tests have been limited to degree 8 maximum for typical systems
2. If still experiencing OOM, edit the test files to reduce degrees further:
   ```julia
   # In sparsification_4d_extensive.jl
   degrees = [4, 5, 6]  # Instead of [4, 5, 6, 7]
   ```
3. Close other applications to free memory
4. Monitor memory usage: `htop` or `top` in another terminal
5. For very large polynomials, use HPC systems with >32GB RAM

## Advanced Usage

### Run Tests with Custom Parameters

```julia
using Globtim
using DynamicPolynomials

# Create custom test
f = x -> your_function(x)
TR = test_input(f, dim=4, center=zeros(4), sample_range=1.0)
pol = Constructor(TR, 10, basis=:chebyshev)

# Analyze sparsification
results = analyze_sparsification_tradeoff(pol,
    thresholds=[1e-3, 1e-4, 1e-5, 1e-6])

# Display results
for res in results
    println("Threshold $(res.threshold): $(res.new_nnz) non-zero, L²=$(res.l2_ratio)")
end
```

### Custom Domain Testing

```julia
# Test with custom domain
domain = BoxDomain(4, 2.0)  # [-2,2]^4
l2_norm = compute_l2_norm(poly, domain, n_points=20)
```

## Integration with CI/CD

The unit tests (`test_sparsification.jl` and `test_truncation.jl`) are included in `runtests.jl` and run automatically in CI/CD pipelines.

The extensive tests can be run separately for detailed validation:

```bash
# In CI script
julia --project=. test/sparsification_3d_extensive.jl || exit 1
julia --project=. test/sparsification_4d_extensive.jl || exit 1
```

## Performance Benchmarks

Typical runtimes on modern hardware:

| Test Suite | Dimensions | Runtime |
|-----------|-----------|---------|
| Unit tests | 1D-2D | 30-60s |
| Documentation verification | 1D | 10-20s |
| 3D extensive | 3D | 2-5 min |
| 4D extensive | 4D | 5-10 min |

## References

- Documentation: `docs/src/sparsification.md`
- Examples: `Examples/sparsification_demo.jl`
- Source code: `src/advanced_l2_analysis.jl`, `src/truncation_analysis.jl`
