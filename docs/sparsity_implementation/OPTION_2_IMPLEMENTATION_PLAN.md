# Option 2: Core Re-Optimization Implementation Plan

**Goal**: Implement high-precision sparsity-constrained re-optimization for polynomial approximations

**Timeline**: 6-8 hours of development + 2-4 hours testing

**Priority**: 🔴 HIGH - Critical for sparsity truncation with accuracy preservation

---

## Overview

This plan implements the workflow:
```
Orthogonal LS → Expand to monomials → Identify small coeffs
              → Re-solve LS with sparsity constraints (HIGH PRECISION)
              → Return optimized sparse polynomial
```

**Why This Matters**: When expanding from orthogonal basis (Chebyshev/Legendre) to monomial basis, many coefficients become large fractions that evaluate to small values. Simple truncation loses accuracy due to ill-conditioning. Re-optimization in high precision preserves approximation quality.

---

## Implementation Steps

### Step 1: Create Monomial Vandermonde Builder (2 hours)

**File**: `src/monomial_vandermonde.jl`

**Functions to Implement**:

#### 1.1 Core Vandermonde Builder

```julia
function build_monomial_vandermonde(
    grid::Matrix{T},
    monomials::Vector{<:Monomial},
    precision::Type{P} = Float64
) where {T, P <: AbstractFloat}
```

**Purpose**: Build Vandermonde matrix for monomial basis in specified precision

**Algorithm**:
```
Input:
  - grid: n_points × dim matrix
  - monomials: list of monomial terms
  - precision: Float64, BigFloat, etc.

Output:
  - V: n_points × n_monomials matrix

For each grid point i, monomial j:
  V[i,j] = ∏ᵈ grid[i,k]^exponent[j,k]
```

**Key Features**:
- High-precision arithmetic (BigFloat support)
- Efficient evaluation using pre-computed powers
- Handles multi-dimensional grids
- Validated against orthogonal Vandermonde

#### 1.2 Sparse Vandermonde (Only Active Terms)

```julia
function build_sparse_monomial_vandermonde(
    grid::Matrix{T},
    monomials::Vector{<:Monomial},
    active_indices::Vector{Int},
    precision::Type{P} = Float64
) where {T, P <: AbstractFloat}
```

**Purpose**: Build Vandermonde for subset of monomials (sparsity pattern)

**Optimization**: Only compute columns for non-zero coefficients

#### 1.3 Condition Number Analysis

```julia
function analyze_monomial_conditioning(
    grid::Matrix{Float64},
    monomials::Vector{<:Monomial};
    precision_types = [Float64, BigFloat]
)
```

**Purpose**: Compare condition numbers in different precisions

**Output**: Report showing why high precision is necessary

**Deliverables**:
- [ ] `src/monomial_vandermonde.jl` created
- [ ] Unit tests in `test/test_monomial_vandermonde.jl`
- [ ] Benchmark vs orthogonal Vandermonde
- [ ] Condition number analysis examples

---

### Step 2: Implement High-Precision Sparse Re-Optimization (3-4 hours)

**File**: `src/sparse_monomial_optimization.jl`

**Functions to Implement**:

#### 2.1 Core Re-Optimization Function

```julia
function reoptimize_sparse_monomial(
    pol::ApproxPoly,
    mono_poly,
    sparsity_pattern::BitVector,
    precision::Type{P} = BigFloat;
    solver::Symbol = :qr,
    validate::Bool = true
) where {P <: AbstractFloat}
```

**Algorithm**:
```
1. Extract sparse monomial terms from mono_poly using sparsity_pattern
2. Convert grid to high precision: grid_hp = convert.(precision, pol.grid)
3. Build sparse Vandermonde: V_sparse = build_sparse_monomial_vandermonde(...)
4. Convert function values: F_hp = convert.(precision, pol.z)
5. Solve least squares in high precision:
   - Gram matrix: G = V_sparse' * V_sparse
   - RHS: b = V_sparse' * F_hp
   - Solve: c_sparse = solve_high_precision(G, b, solver)
6. Reconstruct polynomial with optimized coefficients
7. Validate: compare L2-norm with original
```

**Solver Options**:
- `:lu` - LU factorization (fast, less stable)
- `:qr` - QR factorization (stable, recommended)
- `:svd` - SVD (most stable, slowest)

**Key Features**:
- All arithmetic in specified precision
- Sparsity pattern enforced (only optimize non-zero terms)
- L2-norm validation
- Return metadata (condition number, residual, etc.)

#### 2.2 Unified Sparse Interface

```julia
function to_exact_monomial_basis_sparse(
    pol::ApproxPoly;
    threshold::Real = 1e-10,
    mode::Symbol = :relative,
    reoptimize::Bool = true,
    precision::Type = BigFloat,
    solver::Symbol = :qr,
    variables = nothing
)
```

**Purpose**: Single function that does everything

**Workflow**:
```
1. Expand to monomial basis: mono_poly = to_exact_monomial_basis(pol)
2. Identify sparsity pattern:
   - Extract coefficients
   - Compute magnitudes
   - Apply threshold (relative or absolute)
3. If reoptimize = false:
   - Simple truncation (existing behavior)
4. If reoptimize = true:
   - Call reoptimize_sparse_monomial(...)
   - Return high-precision optimized polynomial
```

**Return Type**: Named tuple with:
- `polynomial`: Optimized sparse polynomial
- `sparsity_info`: Metadata about sparsification
- `optimization_info`: Solver details, condition number, etc.
- `l2_ratio`: L2-norm preservation

#### 2.3 High-Precision Linear Solver

```julia
function solve_high_precision_ls(
    G::Matrix{P},
    b::Vector{P},
    solver::Symbol = :qr
) where {P <: AbstractFloat}
```

**Purpose**: Solve Gram matrix system in high precision

**Solvers**:
```julia
if solver == :lu
    sol = G \ b  # LU factorization
elseif solver == :qr
    Q, R = qr(G)
    sol = R \ (Q' * b)
elseif solver == :svd
    U, S, V = svd(G)
    sol = V * Diagonal(1 ./ S) * U' * b
end
```

**Error Handling**:
- Check condition number
- Warn if ill-conditioned
- Compute residual norm
- Validate solution

#### 2.4 Validation & Comparison

```julia
function compare_sparse_methods(
    pol::ApproxPoly,
    threshold::Real = 1e-6;
    domain::BoxDomain = BoxDomain(size(pol.grid, 2), 1.0),
    n_test_points::Int = 100
)
```

**Purpose**: Compare truncation vs re-optimization

**Metrics**:
- L2-norm preservation
- Max pointwise error
- Coefficient distribution
- Sparsity achieved
- Computation time

**Output**: Report table showing method comparison

**Deliverables**:
- [ ] `src/sparse_monomial_optimization.jl` created
- [ ] All 4 functions implemented
- [ ] Integration tests
- [ ] Comparison benchmarks

---

### Step 3: Testing on Simple Examples (1 hour)

**Purpose**: Validate implementation before complex use cases

#### 3.1 Test Functions

**1D Test Cases**:
```julia
# Polynomial (should have exact sparsity pattern)
f1(x) = x[1]^4 - 2*x[1]^2 + 1

# Smooth function (dense in monomial basis)
f2(x) = 1 / (1 + 25*x[1]^2)  # Runge function

# Oscillatory (challenging)
f3(x) = sin(5π*x[1])
```

**2D Test Cases**:
```julia
# Naturally sparse
f4(x) = x[1]^2 + x[2]^2

# Dense expansion
f5(x) = exp(x[1] * x[2])

# Multi-scale
f6(x) = sin(2π*x[1]) + 0.1*cos(10π*x[2])
```

#### 3.2 Validation Protocol

For each test function:

```julia
# Step 1: Create approximation
TR = test_input(f, dim=..., center=[0.0, ...], sample_range=1.0)
pol = Constructor(TR, degree=10, basis=:chebyshev)

# Step 2: Simple truncation
truncated = to_exact_monomial_basis_sparse(
    pol, threshold=1e-6, reoptimize=false
)

# Step 3: Re-optimization
reoptimized = to_exact_monomial_basis_sparse(
    pol, threshold=1e-6, reoptimize=true, precision=BigFloat
)

# Step 4: Compare
comparison = compare_sparse_methods(pol, 1e-6)
display(comparison)
```

**Success Criteria**:
- Re-optimization L2-norm ≥ truncation L2-norm (always!)
- Re-optimization error < truncation error (usually)
- High-precision solver completes without warnings
- Sparsity achieved matches expectation

**Deliverables**:
- [ ] Test script: `test/manual/test_sparse_simple.jl`
- [ ] Results logged for each test function
- [ ] Validation that re-optimization improves accuracy

---

### Step 4: Integration with Existing Codebase (30 min)

#### 4.1 Export New Functions

**File**: `src/Globtim.jl`

Add to exports:
```julia
export build_monomial_vandermonde,
       reoptimize_sparse_monomial,
       to_exact_monomial_basis_sparse,
       compare_sparse_methods
```

#### 4.2 Include New Files

```julia
include("monomial_vandermonde.jl")
include("sparse_monomial_optimization.jl")
```

#### 4.3 Update Existing Functions

**File**: `src/OrthogonalInterface.jl`

Add deprecation notice to `to_exact_monomial_basis`:
```julia
"""
Note: For sparse polynomials with re-optimization, use
`to_exact_monomial_basis_sparse()` instead.
"""
```

**Deliverables**:
- [ ] Functions exported
- [ ] Files included
- [ ] Documentation updated

---

### Step 5: Create Demonstration Example (30 min)

**File**: `Examples/sparse_reoptimization_demo.jl`

**Content**:
```julia
# Demonstrate the difference between truncation and re-optimization

using Globtim
using DynamicPolynomials
using Printf

# Test function: Runge function (challenging for polynomial approximation)
f(x) = 1 / (1 + 25*x[1]^2)

# Create high-degree approximation
TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)
pol = Constructor(TR, 20, basis=:chebyshev)

println("Original polynomial:")
println("  Degree: 20")
println("  Coefficients: $(length(pol.coeffs))")
println("  L2-norm: $(pol.nrm)")

# Method 1: Simple truncation
println("\n=== Method 1: Simple Truncation ===")
result_trunc = to_exact_monomial_basis_sparse(
    pol, threshold=1e-4, reoptimize=false
)
println("  Non-zero terms: $(result_trunc.sparsity_info.new_nnz)")
println("  L2-norm ratio: $(result_trunc.l2_ratio)")

# Method 2: Re-optimization
println("\n=== Method 2: Re-optimization (BigFloat) ===")
result_reopt = to_exact_monomial_basis_sparse(
    pol, threshold=1e-4, reoptimize=true, precision=BigFloat
)
println("  Non-zero terms: $(result_reopt.sparsity_info.new_nnz)")
println("  L2-norm ratio: $(result_reopt.l2_ratio)")
println("  Condition number: $(result_reopt.optimization_info.condition_number)")

# Method 3: Re-optimization (Float64 - for comparison)
println("\n=== Method 3: Re-optimization (Float64) ===")
result_f64 = to_exact_monomial_basis_sparse(
    pol, threshold=1e-4, reoptimize=true, precision=Float64
)
println("  L2-norm ratio: $(result_f64.l2_ratio)")

# Comparison table
println("\n=== Accuracy Comparison ===")
comparison = compare_sparse_methods(pol, 1e-4)
display(comparison)

# Conclusion
println("\n=== Key Insight ===")
println("High-precision re-optimization preserves approximation quality")
println("even when removing $(100*(1-result_reopt.l2_ratio))% of coefficients!")
```

**Deliverables**:
- [ ] Demo file created
- [ ] Runs without errors
- [ ] Output clearly shows benefit of re-optimization

---

## File Structure After Implementation

```
src/
├── Globtim.jl                          (updated: exports)
├── monomial_vandermonde.jl             ← NEW
├── sparse_monomial_optimization.jl     ← NEW
├── OrthogonalInterface.jl              (updated: documentation)
├── advanced_l2_analysis.jl             (existing)
└── truncation_analysis.jl              (existing)

test/
├── test_monomial_vandermonde.jl        ← NEW
├── test_sparse_monomial_optimization.jl ← NEW
└── manual/
    └── test_sparse_simple.jl           ← NEW

Examples/
└── sparse_reoptimization_demo.jl       ← NEW

docs/sparsity_implementation/
├── OPTION_2_IMPLEMENTATION_PLAN.md     (this file)
├── PHASE_A_ABSTRACT_TYPES.md           (future)
├── PHASE_C_TESTING.md                  (future)
└── PHASE_D_INTEGRATION.md              (future)
```

---

## Implementation Checklist

### Core Infrastructure
- [ ] **Step 1**: Monomial Vandermonde builder
  - [ ] `build_monomial_vandermonde()` function
  - [ ] `build_sparse_monomial_vandermonde()` function
  - [ ] `analyze_monomial_conditioning()` function
  - [ ] Unit tests
  - [ ] Benchmarks

- [ ] **Step 2**: Sparse re-optimization
  - [ ] `reoptimize_sparse_monomial()` function
  - [ ] `to_exact_monomial_basis_sparse()` function
  - [ ] `solve_high_precision_ls()` function
  - [ ] `compare_sparse_methods()` function
  - [ ] Integration tests

### Validation
- [ ] **Step 3**: Testing
  - [ ] Test on 1D polynomials
  - [ ] Test on 1D smooth functions
  - [ ] Test on 2D cases
  - [ ] Validation protocol complete
  - [ ] Success criteria met

### Integration
- [ ] **Step 4**: Codebase integration
  - [ ] Functions exported
  - [ ] Files included
  - [ ] Documentation updated
  - [ ] Precompilation works

- [ ] **Step 5**: Demonstration
  - [ ] Demo file created
  - [ ] Output validated
  - [ ] Clear benefit shown

---

## Success Metrics

1. **Correctness**: Re-optimized polynomials have L2-norm ≥ truncated polynomials
2. **Precision**: BigFloat solver handles ill-conditioned problems
3. **Performance**: Re-optimization completes in reasonable time (<10s for degree 20)
4. **Usability**: Single function call for complete workflow
5. **Documentation**: Clear examples showing when to use each method

---

## Risk Mitigation

### Risk 1: Monomial basis too ill-conditioned

**Symptoms**: Even BigFloat solver fails or gives poor results

**Mitigation**:
- Use SVD solver instead of QR
- Increase BigFloat precision (setprecision(256))
- Add regularization term to Gram matrix
- Document when re-optimization is not recommended

### Risk 2: Re-optimization slower than expected

**Symptoms**: BigFloat arithmetic too slow for practical use

**Mitigation**:
- Implement adaptive precision (start Float64, upgrade if needed)
- Cache Vandermonde matrix if multiple thresholds tested
- Parallelize if multiple re-optimizations needed
- Profile and optimize hot paths

### Risk 3: L2-norm validation fails

**Symptoms**: Re-optimized polynomial has worse L2-norm

**Mitigation**:
- Check grid coverage (ensure it matches original approximation)
- Verify sparsity pattern extraction
- Test with simple polynomial first
- Add detailed error reporting

---

## Next Steps After Option 2 Complete

1. **Immediate**: Test on your actual use case
   - Apply to local refinement problem
   - Verify integration with `refining.jl`
   - Measure impact on critical point accuracy

2. **Short-term**: Add comprehensive tests (Phase C)
   - Create test suite as outlined in main review
   - Add benchmarks
   - Validate edge cases

3. **Medium-term**: Abstract type refactoring (Phase A)
   - Makes code more extensible
   - Better type safety
   - Cleaner architecture

4. **Long-term**: Full integration (Phase D)
   - Add to Constructor options
   - Configuration file support
   - Production-ready workflows

---

## Time Estimates

| Step | Optimistic | Realistic | Pessimistic |
|------|-----------|-----------|-------------|
| Step 1: Vandermonde | 1.5h | 2h | 3h |
| Step 2: Re-optimization | 2.5h | 3-4h | 5h |
| Step 3: Testing | 0.5h | 1h | 2h |
| Step 4: Integration | 0.25h | 0.5h | 1h |
| Step 5: Demo | 0.25h | 0.5h | 1h |
| **Total** | **5h** | **7-8h** | **12h** |

**Recommendation**: Budget 2 work days (8-10 hours) for complete implementation and testing.

---

## Questions to Resolve During Implementation

1. Should we support sparse storage (SparseArrays.jl) for very sparse polynomials?
2. What's the default precision? BigFloat or adaptive?
3. Should re-optimization be opt-in or opt-out?
4. How to handle edge case where all coefficients below threshold?
5. Should we cache Vandermonde matrices for repeated calls?

Document answers in implementation comments!
