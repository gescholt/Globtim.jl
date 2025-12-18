# Sparse Polynomial Optimization Architecture

**Version**: 1.0
**Date**: 2025-11-19
**Status**: Design Document

---

## Executive Summary

This document describes the architecture for **high-precision sparsity-constrained polynomial optimization** in Globtim. The system enables:

1. **Coefficient truncation** with L2-norm preservation
2. **High-precision re-optimization** for ill-conditioned monomial basis
3. **Local refinement** with sparse polynomials
4. **Abstract type hierarchies** for clean, extensible code

**Key Innovation**: Re-optimize least squares problem after truncation using high-precision arithmetic, preserving approximation quality despite monomial basis ill-conditioning.

---

## System Overview

### The Problem

```
Orthogonal Basis (Chebyshev/Legendre)
  ↓ Well-conditioned, reasonable coefficients
  ↓ cond(Vandermonde) ~ 10²

Expand to Monomial Basis
  ↓ BIG FRACTIONS: 12589/16384 → 0.768
  ↓ cond(Vandermonde) ~ 10⁸
  ↓ Many terms evaluate to tiny values

Simple Truncation
  ↓ Remove small coefficients
  ↓ PROBLEM: Loses accuracy due to ill-conditioning
  ✗ Poor approximation
```

### The Solution

```
Orthogonal LS
  ↓ Compute coefficients in stable basis

Expand to Monomials
  ↓ Identify sparsity pattern from coefficient magnitudes

Re-optimize in High Precision
  ↓ Solve sparse least squares: minimize ||V_sparse*c - F||²
  ↓ Use BigFloat arithmetic to handle ill-conditioning
  ↓ Only optimize over non-zero terms
  ✓ Accurate sparse approximation
```

---

## Architecture Layers

### Layer 1: Basis Representation (Foundation)

```
AbstractBasis
├── OrthogonalBasis
│   ├── ChebyshevBasis(normalized, power_of_two_denom)
│   └── LegendreBasis(normalized)
└── MonomialBasis
    ├── StandardMonomialBasis()
    └── SparseMonomialBasis(active_indices, threshold)
```

**Responsibility**: Type-safe representation of polynomial bases

**Files**:
- `src/basis_types.jl` - Type definitions
- `src/cheb_pol.jl` - Chebyshev implementation
- `src/lege_pol.jl` - Legendre implementation

**Key Functions**:
- `is_orthogonal(basis)` - Query basis properties
- `is_normalized(basis)` - Check normalization
- `symbol_to_basis(sym)` - Backward compatibility

---

### Layer 2: Polynomial Approximation (Core)

```
AbstractPolynomial
├── ApproxPoly{T,S,B<:AbstractBasis}
│   ├── coeffs::Vector{T}           # Orthogonal basis coeffs
│   ├── basis::B                     # Basis type
│   └── grid::Matrix{Float64}        # Evaluation points
└── SparseApproxPoly{T,S,B}  (future)
    ├── coeffs::SparseVector{T}
    └── active_indices::Vector{Int}
```

**Responsibility**: Polynomial representation and storage

**Files**:
- `src/Structures.jl` - Type definitions
- `src/Main_Gen.jl` - Constructor (approximation)
- `src/ApproxConstruct.jl` - Vandermonde matrices

**Key Functions**:
- `Constructor(TR, degree, ...)` - Create approximation
- `lambda_vandermonde(...)` - Build Vandermonde matrix
- `get_basis(pol)` - Query basis type

---

### Layer 3: Basis Conversion (Critical Path)

```
OrthogonalBasis → MonomialBasis
           ↓
construct_orthopoly_polynomial()
           ↓
    [Chebyshev]          [Legendre]
           ↓                  ↓
construct_chebyshev_approx()  construct_legendre_approx()
           ↓                  ↓
           └──────────────────┘
                     ↓
         DynamicPolynomials.Polynomial
         (Monomial basis, BIG FRACTIONS)
```

**Responsibility**: Convert between bases (where ill-conditioning appears!)

**Files**:
- `src/OrthogonalInterface.jl` - Main conversion interface
- `src/cheb_pol.jl` - Chebyshev expansion
- `src/lege_pol.jl` - Legendre expansion

**Key Functions**:
- `to_exact_monomial_basis(pol)` - Convert to monomials
- `construct_orthopoly_polynomial(...)` - Core expansion
- `construct_chebyshev_approx(...)` - Chebyshev-specific

**⚠️ This is where big fractions appear!**

---

### Layer 4: Sparsification (New!)

```
┌─────────────────────────────────────┐
│  Sparsification Layer               │
├─────────────────────────────────────┤
│                                     │
│  Phase 1: Identify Sparsity         │
│  ┌─────────────────────────────┐   │
│  │ sparsify_polynomial()       │   │
│  │ (orthogonal basis)          │   │
│  └─────────────────────────────┘   │
│           ↓                         │
│  Phase 2: Convert to Monomials      │
│  ┌─────────────────────────────┐   │
│  │ to_exact_monomial_basis()   │   │
│  │ (BIG FRACTIONS appear)      │   │
│  └─────────────────────────────┘   │
│           ↓                         │
│  Phase 3: Truncate                  │
│  ┌─────────────────────────────┐   │
│  │ truncate_polynomial()       │   │
│  │ OR (NEW!)                   │   │
│  │ reoptimize_sparse_monomial()│   │
│  └─────────────────────────────┘   │
│           ↓                         │
│  Result: Sparse Accurate Polynomial │
└─────────────────────────────────────┘
```

**Responsibility**: Remove small coefficients while preserving accuracy

**Files**:
- `src/advanced_l2_analysis.jl` - Sparsification in orthogonal basis
- `src/truncation_analysis.jl` - Simple truncation in monomial basis
- `src/sparse_monomial_optimization.jl` - **Re-optimization (NEW!)**
- `src/monomial_vandermonde.jl` - **High-precision Vandermonde (NEW!)**

**Key Functions**:
- `sparsify_polynomial(pol, threshold)` - Orthogonal basis sparsification
- `truncate_polynomial(mono_poly, threshold)` - Simple truncation
- `reoptimize_sparse_monomial(pol, mono_poly, pattern, precision)` - **Core innovation**
- `to_exact_monomial_basis_sparse(...)` - **Unified interface**

---

### Layer 5: High-Precision Linear Algebra (Critical!)

```
AbstractLinearSolver
├── LUSolver()              # Fast, moderate stability
├── QRSolver()              # Stable, recommended
├── SVDSolver()             # Most stable, slowest
├── HighPrecisionSolver{P}  # Wrapper for high precision
└── SparseConstrainedSolver{P}  # For sparsity-constrained LS
```

**Responsibility**: Solve ill-conditioned systems in high precision

**Files**:
- `src/solver_types.jl` - Solver hierarchy (future)
- `src/sparse_monomial_optimization.jl` - High-precision LS solver

**Key Functions**:
- `solve_linear_system(solver, A, b)` - Dispatch to solver
- `solve_high_precision_ls(G, b, solver)` - High-precision solve
- `build_monomial_vandermonde(grid, monomials, precision)` - High-precision Vandermonde

**Why This Matters**:
```julia
# Monomial Gram matrix in Float64
G_f64 = V' * V  # cond(G) ~ 10⁸
c_f64 = G_f64 \ b  # ✗ Unstable!

# Monomial Gram matrix in BigFloat
G_bf = BigFloat.(V)' * BigFloat.(V)  # cond(G) still ~ 10⁸
c_bf = G_bf \ BigFloat.(b)  # ✓ Accurate!
```

---

### Layer 6: Analysis & Validation

```
Analysis Tools
├── L2-Norm Computation
│   ├── compute_l2_norm_vandermonde()  # Using grid
│   ├── compute_l2_norm()              # Using quadrature
│   └── compute_l2_norm_coeffs()       # Modified coeffs
├── Sparsity Metrics
│   ├── analyze_sparsification_tradeoff()
│   ├── find_optimal_sparsity_threshold()
│   └── compute_sparsification_metrics()
└── Validation
    ├── verify_truncation_quality()
    ├── compare_sparse_methods()
    └── analyze_truncation_impact()
```

**Responsibility**: Measure quality, guide decisions

**Files**:
- `src/advanced_l2_analysis.jl` - L2-norm computation
- `src/truncation_analysis.jl` - Truncation analysis
- `tools/benchmarking/benchmark_utilities.jl` - Metrics

**Key Functions**:
- `compute_l2_norm(poly, domain)` - Approximate L2-norm
- `verify_truncation_quality(orig, trunc, domain)` - Compare polynomials
- `analyze_sparsification_tradeoff(pol, thresholds)` - Threshold sweep

---

### Layer 7: Integration & Workflows

```
High-Level Interfaces
├── Constructor() with sparsity options
├── StandardExperiment with sparsity config
├── Configuration file support (.toml)
└── Local refinement integration
```

**Responsibility**: Make features accessible to users

**Files**:
- `src/Main_Gen.jl` - Constructor integration
- `src/StandardExperiment.jl` - Experiment framework
- `src/config.jl` - Configuration parsing
- `src/refining.jl` - Critical point solver

**Key Workflows**:
```julia
# Workflow 1: Simple sparsification
pol = Constructor(TR, 15, sparsify=true, sparsity_threshold=1e-6)

# Workflow 2: Sparse monomial with re-optimization
result = Constructor(
    TR, 15,
    return_sparse_monomial = true,
    sparsify_reoptimize = true,
    sparsify_precision = BigFloat
)

# Workflow 3: Local refinement
pol_global = Constructor(TR_global, 12, sparsify=true)
cps = find_critical_points(pol_global, TR_global)
for cp in cps
    pol_local = Constructor(TR_local(cp), 8, return_sparse_monomial=true)
end
```

---

## Data Flow

### Complete Workflow: Constructor → Sparse Monomial

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER INPUT                                               │
│    TR = test_input(f, dim=2)                               │
│    Constructor(TR, 15, return_sparse_monomial=true, ...)   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. GRID GENERATION                                          │
│    grid = generate_grid(n, GN, basis=:chebyshev)           │
│    matrix_from_grid = [x_1, x_2, ..., x_N]                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. VANDERMONDE MATRIX (Orthogonal Basis)                   │
│    VL = lambda_vandermonde(Lambda, grid, basis=:chebyshev) │
│    Condition: cond(VL) ~ 10²                               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. LEAST SQUARES (Well-Conditioned)                        │
│    G = VL' * VL     (Gram matrix)                          │
│    F = [f(x_1), f(x_2), ..., f(x_N)]                      │
│    RHS = VL' * F                                            │
│    coeffs = G \ RHS  (LU factorization)                    │
│    Result: coeffs in Chebyshev basis                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. APPROX_POLY CONSTRUCTION                                │
│    ApproxPoly{T,S,ChebyshevBasis}(                         │
│        coeffs, support, degree, nrm, ...                   │
│    )                                                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓ (if sparsify=true)
┌─────────────────────────────────────────────────────────────┐
│ 6. SPARSIFICATION (Optional, in orthogonal basis)          │
│    sparsify_polynomial(pol, threshold=1e-6)                │
│    Zero out small coefficients                             │
│    Compute L2-norm impact                                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓ (if return_sparse_monomial=true)
┌─────────────────────────────────────────────────────────────┐
│ 7. EXPANSION TO MONOMIAL BASIS                             │
│    to_exact_monomial_basis(pol)                            │
│    ↓                                                        │
│    construct_orthopoly_polynomial(...)                     │
│    ↓                                                        │
│    construct_chebyshev_approx(...)                         │
│    ↓                                                        │
│    For each term: ∑ coeff_j * ∏ T_αᵢ(xᵢ)                  │
│    ↓                                                        │
│    Expand each T_n(x) to monomials: T_n = ∑ a_k x^k       │
│    ↓                                                        │
│    Result: DynamicPolynomials.Polynomial                   │
│    ⚠️  BIG FRACTIONS: 12589/16384, 7853/8192, ...         │
│    ⚠️  Condition: cond(monomial_vandermonde) ~ 10⁸        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. IDENTIFY SPARSITY PATTERN                               │
│    coeffs = [coefficient(t) for t in terms(mono_poly)]     │
│    coeff_mags = [abs(Float64(c)) for c in coeffs]          │
│    threshold = 1e-6 * max(coeff_mags)  (relative)          │
│    sparsity_pattern = coeff_mags .> threshold              │
│    active_indices = findall(sparsity_pattern)              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓ (if reoptimize=false)
                         │ Simple Truncation
                         │ ┌───────────────────────────┐
                         │ │ truncate_polynomial()     │
                         │ │ Just zero small terms     │
                         │ │ ✗ Loses accuracy          │
                         │ └───────────────────────────┘
                         │
                         ↓ (if reoptimize=true) ← THE KEY!
┌─────────────────────────────────────────────────────────────┐
│ 9. RE-OPTIMIZATION (High Precision, Sparse LS)             │
│    reoptimize_sparse_monomial(pol, mono_poly, pattern, P)  │
│    ↓                                                        │
│    A. Extract sparse terms:                                │
│       sparse_terms = terms(mono_poly)[active_indices]      │
│    ↓                                                        │
│    B. Build high-precision sparse Vandermonde:             │
│       grid_hp = convert.(BigFloat, pol.grid)               │
│       V_sparse = build_sparse_monomial_vandermonde(        │
│           grid_hp, sparse_terms, BigFloat                  │
│       )                                                     │
│       Size: n_points × n_active_terms                      │
│    ↓                                                        │
│    C. Convert function values to high precision:           │
│       F_hp = convert.(BigFloat, pol.z)                     │
│    ↓                                                        │
│    D. Form Gram matrix in high precision:                  │
│       G_hp = V_sparse' * V_sparse  (BigFloat arithmetic)   │
│       Condition: cond(G_hp) ~ 10⁸ (still ill-conditioned!) │
│       But: BigFloat has enough precision to handle it      │
│    ↓                                                        │
│    E. Form RHS in high precision:                          │
│       b_hp = V_sparse' * F_hp                              │
│    ↓                                                        │
│    F. Solve high-precision least squares:                  │
│       if solver == :qr                                     │
│           Q, R = qr(G_hp)                                  │
│           c_hp = R \ (Q' * b_hp)                           │
│       elseif solver == :svd                                │
│           U, S, V = svd(G_hp)                              │
│           c_hp = V * Diagonal(1 ./ S) * U' * b_hp          │
│       end                                                   │
│       ✓ High precision handles ill-conditioning!          │
│    ↓                                                        │
│    G. Reconstruct polynomial:                              │
│       result = ∑ c_hp[i] * sparse_terms[i]                │
│    ↓                                                        │
│    H. Validate:                                            │
│       l2_original = compute_l2_norm(pol)                   │
│       l2_sparse = compute_l2_norm(result, domain)          │
│       l2_ratio = l2_sparse / l2_original                   │
│       @assert l2_ratio > 0.95  # Should preserve accuracy  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 10. RETURN RESULT                                          │
│     (                                                       │
│         polynomial = sparse_optimized_poly,                │
│         sparsity_info = (new_nnz, original_nnz, ...),     │
│         optimization_info = (cond_number, solver, ...),   │
│         l2_ratio = l2_sparse / l2_original                 │
│     )                                                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Algorithms

### Algorithm 1: High-Precision Sparse Re-optimization

```
Input:
  - pol: ApproxPoly (orthogonal basis approximation)
  - mono_poly: DynamicPolynomials.Polynomial (expanded to monomials)
  - sparsity_pattern: BitVector (which terms to keep)
  - precision: Type{<:AbstractFloat} (e.g., BigFloat)

Output:
  - Optimized sparse polynomial in monomial basis

Procedure:
  1. sparse_terms ← terms(mono_poly)[sparsity_pattern]
  2. grid_hp ← convert.(precision, pol.grid)
  3. F_hp ← convert.(precision, pol.z)
  4. V_sparse ← zeros(precision, size(grid_hp, 1), length(sparse_terms))
  5. for j in 1:length(sparse_terms)
       exponents ← get_exponents(sparse_terms[j])
       for i in 1:size(grid_hp, 1)
           V_sparse[i,j] ← ∏ grid_hp[i,k]^exponents[k]
       end
     end
  6. G_hp ← V_sparse' * V_sparse
  7. b_hp ← V_sparse' * F_hp
  8. c_hp ← solve_with_high_precision(G_hp, b_hp)
  9. result ← ∑ c_hp[i] * sparse_terms[i]
 10. return result

Complexity:
  - Time: O(N * M * d) + O(M³) where N=grid points, M=sparse terms, d=dimension
  - Space: O(N * M) + O(M²) in high precision
  - Memory: ~10x more than Float64 for BigFloat
```

### Algorithm 2: Adaptive Threshold Selection

```
Input:
  - pol: ApproxPoly
  - max_l2_degradation: Float64 (e.g., 0.01 for 1%)
  - reoptimize: Bool

Output:
  - optimal_threshold: Float64

Procedure:
  1. mono_poly ← to_exact_monomial_basis(pol)
  2. l2_original ← compute_l2_norm(pol)
  3. coeffs ← coefficients(mono_poly)
  4. sorted_mags ← sort(abs.(coeffs), rev=true)
  5. threshold_candidates ← unique(sorted_mags)
  6. for threshold in threshold_candidates
       sparse_result ← to_exact_monomial_basis_sparse(
           pol, threshold, reoptimize=reoptimize
       )
       l2_degradation ← abs(sparse_result.l2_ratio - 1.0)
       if l2_degradation <= max_l2_degradation
           return threshold
       end
     end
  7. return minimum(threshold_candidates)  # Most conservative

Complexity:
  - Time: O(T * Cost(reoptimize)) where T = number of unique coefficient magnitudes
  - Can be expensive; consider binary search for large T
```

---

## Performance Characteristics

### Computational Costs

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| Orthogonal LS | O(N*M²) + O(M³) | N=grid, M=basis size |
| Expand to monomials | O(M * d^k) | k=degree, d=dimension |
| Truncation | O(M) | Simple filtering |
| Monomial Vandermonde | O(N*M_sparse*d) | Only sparse terms |
| High-precision LS | O(M_sparse³) | In BigFloat: ~10x slower |
| **Total re-optimization** | **O(N*M_sparse²)** | Dominated by Vandermonde |

### Memory Usage

| Component | Storage | Notes |
|-----------|---------|-------|
| ApproxPoly | O(M + N) | Coeffs + grid |
| Dense monomial | O(M_mono) | Can be >> M |
| Sparse monomial | O(M_sparse) | Reduced |
| High-precision data | O((N + M_sparse²) * P) | P=precision factor (~10 for BigFloat) |

### Precision Trade-offs

| Precision | Speed | Accuracy | Use Case |
|-----------|-------|----------|----------|
| Float64 | 1.0x | Good | cond(G) < 10⁶ |
| BigFloat (256 bits) | 0.1x | Excellent | cond(G) < 10²⁰ |
| BigFloat (512 bits) | 0.03x | Extreme | cond(G) > 10²⁰ |

---

## Error Analysis

### Sources of Error

1. **Approximation Error**: `||f - p_orthogonal||₂`
   - From finite degree
   - Measured in `pol.nrm`

2. **Basis Conversion Error**: `||p_orthogonal - p_monomial||₂`
   - Should be machine epsilon (exact conversion)
   - Watch for: numerical cancellation in big fractions

3. **Truncation Error**: `||p_monomial - p_sparse_truncated||₂`
   - Depends on threshold
   - Can be large if ill-conditioned

4. **Re-optimization Error**: `||p_monomial - p_sparse_reoptimized||₂`
   - Should be minimal (re-fitting to same data)
   - High precision mitigates ill-conditioning

### Error Bounds

Theoretical bound for re-optimization:
```
||f - p_sparse_reoptimized||₂ ≤ ||f - p_orthogonal||₂ + ε_precision

where ε_precision depends on:
  - Condition number of sparse Gram matrix
  - Precision of arithmetic
  - Solver stability
```

**In practice**: Re-optimization with BigFloat typically achieves:
```
l2_ratio = ||p_sparse_reoptimized||₂ / ||p_orthogonal||₂ > 0.95
```

---

## Testing Strategy

### Unit Tests
- Each layer independently tested
- Mock data for reproducibility
- Edge cases (empty sparsity, all zeros, etc.)

### Integration Tests
- End-to-end workflows
- Realistic test functions
- Performance benchmarks

### Validation Tests
- Known polynomial examples (exact recovery)
- Comparison with reference implementations
- Convergence studies

### Stress Tests
- High dimension (d > 5)
- High degree (> 20)
- Very ill-conditioned problems
- Extreme sparsity (> 90% zeros)

---

## Future Extensions

### Short-term
1. Automatic precision selection (adaptive)
2. Parallel sparse Vandermonde construction
3. Cached Vandermonde for threshold sweeps
4. Compressed storage for very sparse polynomials

### Medium-term
1. Iterative refinement (start Float64, upgrade if needed)
2. Block-sparse patterns (group monomials)
3. Anisotropic sparsity (different thresholds per variable)
4. GPU acceleration for Vandermonde construction

### Long-term
1. Automatic basis selection (orthogonal vs monomial)
2. Adaptive multi-resolution (coarse global + fine local)
3. Certified error bounds
4. Integration with tensor decomposition

---

## Related Work

### Sparse Polynomial Approximation
- Compressed sensing techniques
- L1-regularized least squares (LASSO)
- Stepwise regression
- **Our approach**: Threshold + re-optimization (simpler, effective)

### High-Precision Linear Algebra
- Iterative refinement
- Mixed-precision algorithms
- **Our approach**: Direct high-precision solve (robust for ill-conditioned)

### Basis Conversion
- Clenshaw algorithm (evaluation)
- DCT-based conversion
- **Our approach**: Exact symbolic expansion + high-precision LS

---

## Conclusion

This architecture enables **accurate sparse polynomial approximations** by:

1. **Identifying sparsity** in well-conditioned orthogonal basis
2. **Re-optimizing** in ill-conditioned monomial basis using high precision
3. **Preserving accuracy** despite aggressive coefficient reduction
4. **Integrating seamlessly** with local refinement workflows

**Key Innovation**: High-precision re-optimization bridges the gap between sparsity (efficiency) and accuracy (quality).

---

## References

### Internal Documentation
- `OPTION_2_IMPLEMENTATION_PLAN.md` - Implementation details
- `PHASE_A_ABSTRACT_TYPES.md` - Type system design
- `PHASE_C_TESTING.md` - Test suite specification
- `PHASE_D_INTEGRATION.md` - Production integration

### Code Locations
- `src/sparse_monomial_optimization.jl` - Core re-optimization
- `src/monomial_vandermonde.jl` - High-precision Vandermonde
- `src/advanced_l2_analysis.jl` - Sparsification & analysis
- `src/truncation_analysis.jl` - Truncation methods

### Examples
- `Examples/sparse_reoptimization_demo.jl` - Basic demo
- `Examples/sparsification_demo.jl` - Existing sparsity demo
- `test/test_sparse_refinement.jl` - Comprehensive tests
