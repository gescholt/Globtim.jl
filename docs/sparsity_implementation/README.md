# Sparsity Implementation Documentation

**Status**: Design & Implementation Guide
**Version**: 1.0
**Date**: 2025-11-19

---

## Overview

This directory contains comprehensive documentation for implementing **high-precision sparsity-constrained polynomial optimization** in Globtim.

**Core Problem**: When expanding polynomials from orthogonal basis (Chebyshev/Legendre) to monomial basis, many coefficients become large fractions that evaluate to small values. Simple truncation loses accuracy due to ill-conditioning.

**Core Solution**: Re-optimize the least squares problem in high precision (BigFloat) after identifying sparsity pattern, preserving approximation quality while achieving sparsity.

---

## Documentation Structure

### 📘 **[ARCHITECTURE.md](./ARCHITECTURE.md)** - START HERE!

**Purpose**: System design overview

**Contents**:
- Complete architecture layers
- Data flow diagrams
- Key algorithms
- Performance characteristics
- Error analysis

**Read this first** to understand the overall design.

---

### 🚀 **[OPTION_2_IMPLEMENTATION_PLAN.md](./OPTION_2_IMPLEMENTATION_PLAN.md)** - IMPLEMENTATION

**Purpose**: Detailed implementation plan (6-8 hours)

**Contents**:
- Step-by-step implementation guide
- Code structure and file organization
- Deliverables checklist
- Testing requirements
- Time estimates

**Use this** when implementing the core functionality.

**Steps**:
1. Monomial Vandermonde builder (2 hours)
2. Sparse re-optimization (3-4 hours)
3. Testing on examples (1 hour)
4. Integration (30 min)
5. Demo creation (30 min)

---

### 🧬 **[PHASE_A_ABSTRACT_TYPES.md](./PHASE_A_ABSTRACT_TYPES.md)** - FUTURE REFACTORING

**Purpose**: Type system refactoring (8-12 hours)

**Contents**:
- Abstract basis type hierarchy
- Linear solver abstraction
- Precision strategy types
- Migration guide
- Benefits and trade-offs

**Implement after** Option 2 is working, for cleaner architecture.

**Key Benefits**:
- Type safety (compile-time errors)
- Better performance (static dispatch)
- Easier extensibility (add new bases/solvers)

---

### ✅ **[PHASE_C_TESTING.md](./PHASE_C_TESTING.md)** - TESTING (CRITICAL!)

**Purpose**: Comprehensive test suite (6-8 hours)

**Contents**:
- Test suite for sparsity + local refinement
- Unit tests for components
- Benchmark suite
- Validation protocols
- Success criteria

**This was explicitly requested!** Tests verify:
- Re-optimization vs truncation accuracy
- Local refinement integration
- High-precision solver correctness
- Sparsity pattern stability

---

### 🔌 **[PHASE_D_INTEGRATION.md](./PHASE_D_INTEGRATION.md)** - PRODUCTION

**Purpose**: Production integration (4-6 hours)

**Contents**:
- Constructor integration
- Configuration file support
- StandardExperiment integration
- User documentation
- Refining.jl compatibility

**Implement when** ready for production use.

**Makes features accessible**:
```julia
# Simple API
pol = Constructor(TR, 15,
    return_sparse_monomial = true,
    sparsify_reoptimize = true
)
```

---

## Quick Start Guide

### For Implementers

**Goal**: Get core re-optimization working

1. Read `ARCHITECTURE.md` (30 min)
2. Follow `OPTION_2_IMPLEMENTATION_PLAN.md` (6-8 hours)
3. Run tests from `PHASE_C_TESTING.md` (2 hours)
4. Done! Core functionality complete.

### For Refactorers

**Goal**: Clean up codebase with abstract types

1. Complete Option 2 first (above)
2. Read `PHASE_A_ABSTRACT_TYPES.md` (1 hour)
3. Implement type hierarchy (8-12 hours)
4. Update all code to use types
5. Verify no performance regression

### For Testers

**Goal**: Validate implementation

1. Run test suite from `PHASE_C_TESTING.md`
2. Focus on:
   - Truncation vs re-optimization comparison
   - Local refinement integration
   - High-precision accuracy
3. Benchmark performance

### For Users

**Goal**: Use sparsity in research

1. Read user guide (when available in Phase D)
2. Try examples:
   - `Examples/sparse_reoptimization_demo.jl`
   - `Examples/sparsification_demo.jl`
3. Integrate into workflow:
   ```julia
   result = Constructor(TR, degree,
       return_sparse_monomial = true,
       sparsify_reoptimize = true
   )
   ```

---

## Implementation Roadmap

### ✅ Already Implemented

- [x] Sparsification in orthogonal basis
- [x] Simple truncation in monomial basis
- [x] L2-norm computation
- [x] Sparsity analysis tools
- [x] Monomial basis conversion

### 🔴 Critical Gaps (Option 2)

- [ ] **Monomial Vandermonde builder** (high precision)
- [ ] **Sparse re-optimization function** (core innovation)
- [ ] **High-precision linear solver**
- [ ] **Unified sparse interface**
- [ ] **Test suite for sparsity + refinement**

### 🟡 Nice to Have (Later Phases)

- [ ] Abstract type refactoring (Phase A)
- [ ] Constructor integration (Phase D)
- [ ] Configuration file support (Phase D)
- [ ] User documentation (Phase D)

---

## Key Files to Create

### Option 2 Implementation

```
src/
├── monomial_vandermonde.jl              ← NEW (2 hours)
│   ├── build_monomial_vandermonde()
│   ├── build_sparse_monomial_vandermonde()
│   └── analyze_monomial_conditioning()
│
├── sparse_monomial_optimization.jl      ← NEW (3-4 hours)
│   ├── reoptimize_sparse_monomial()          # CORE
│   ├── to_exact_monomial_basis_sparse()      # API
│   ├── solve_high_precision_ls()
│   └── compare_sparse_methods()
│
test/
├── test_monomial_vandermonde.jl         ← NEW
├── test_sparse_monomial_optimization.jl ← NEW
└── test_sparse_refinement.jl            ← NEW (main test suite)
│
Examples/
└── sparse_reoptimization_demo.jl        ← NEW
```

### Phase A (Abstract Types)

```
src/
├── basis_types.jl                       ← NEW
├── solver_types.jl                      ← NEW
└── precision_strategies.jl              ← NEW
```

### Phase D (Integration)

```
src/
├── Main_Gen.jl                          ← UPDATE
├── config.jl                            ← UPDATE
├── StandardExperiment.jl                ← UPDATE
└── refining.jl                          ← UPDATE (compatibility)
│
docs/user_guides/
└── SPARSITY_GUIDE.md                    ← NEW
```

---

## Implementation Priority

### Priority 1: Core Functionality (Option 2)
**Timeline**: 1-2 days
**Impact**: Enables accurate sparse approximations
**Required for**: Your use case!

### Priority 2: Testing (Phase C)
**Timeline**: 1 day
**Impact**: Validates correctness
**Required for**: Production use

### Priority 3: Integration (Phase D)
**Timeline**: 0.5-1 day
**Impact**: Makes features accessible
**Required for**: User adoption

### Priority 4: Refactoring (Phase A)
**Timeline**: 2 days
**Impact**: Cleaner architecture
**Required for**: Long-term maintainability

---

## Success Criteria

### Technical Success

- [x] Can identify sparsity pattern from monomial polynomial
- [ ] Can build monomial Vandermonde in high precision
- [ ] Can re-optimize sparse least squares accurately
- [ ] Re-optimization preserves L2-norm better than truncation
- [ ] High-precision solver handles ill-conditioned problems
- [ ] Sparse polynomials work with local refinement
- [ ] All tests pass

### User Success

- [ ] Simple API for common use cases
- [ ] Clear documentation with examples
- [ ] Reasonable performance (< 10s for degree 20)
- [ ] Easy to integrate into workflows
- [ ] Configuration file support

### Research Success

- [ ] Enables accurate sparse local refinement
- [ ] Improves critical point detection
- [ ] Reduces memory usage significantly
- [ ] Speeds up polynomial evaluation
- [ ] Publishable results

---

## Questions & Answers

### Q: Why high precision for re-optimization?

**A**: Monomial basis is severely ill-conditioned (cond ~ 10⁸). Float64 arithmetic loses accuracy when solving `G*c = b`. BigFloat has enough precision to handle this.

### Q: Why not just use orthogonal basis throughout?

**A**: Critical point solvers (refining.jl) expect monomial form for gradient/Hessian. Also, monomial form is more interpretable.

### Q: Is re-optimization always better than truncation?

**A**: Almost always for L2-norm preservation. However, re-optimization is slower (BigFloat arithmetic). For quick-and-dirty sparsity, truncation is fine.

### Q: What's the computational cost?

**A**: Re-optimization adds ~10x overhead due to BigFloat, but only for the sparse subset of terms. Total: 2-10 seconds for degree 20 in 2D.

### Q: Can I use Float64 re-optimization?

**A**: Yes, but accuracy may suffer for ill-conditioned problems. Try it first; upgrade to BigFloat if needed.

---

## Getting Help

### Implementation Questions

- Check `OPTION_2_IMPLEMENTATION_PLAN.md` for detailed steps
- Look at existing similar functions in `src/advanced_l2_analysis.jl`
- Review test examples for usage patterns

### Design Questions

- Read `ARCHITECTURE.md` for system design
- Check data flow diagrams
- Review key algorithms section

### Testing Questions

- See `PHASE_C_TESTING.md` for test structure
- Look at existing tests in `test/test_*.jl`
- Run `julia --project=. -e 'using Pkg; Pkg.test()'`

### User Questions

- Read `SPARSITY_GUIDE.md` (Phase D)
- Try examples in `Examples/`
- Check configuration file documentation

---

## Contributing

### Adding New Features

1. Update architecture documentation
2. Implement with tests
3. Add examples
4. Update user guide
5. Submit PR

### Reporting Issues

Include:
- What you were trying to do
- What happened vs what you expected
- Minimal reproducible example
- Globtim version

---

## Changelog

### 2025-11-19: Initial Design

- Created documentation structure
- Wrote Option 2 implementation plan
- Documented Phase A (abstract types)
- Documented Phase C (testing)
- Documented Phase D (integration)
- Wrote architecture overview

### Future

- [ ] Implementation of Option 2
- [ ] Test suite completion
- [ ] User guide creation
- [ ] Production integration

---

## License & Citation

Part of Globtim package. See main repository for license.

If this implementation is used in research, please cite:
```
[Citation to be added after publication]
```

---

## Contact

For questions about this implementation:
- Open GitHub issue
- Check documentation first
- Provide minimal reproducible example

---

**Ready to start implementing?**

👉 Go to [OPTION_2_IMPLEMENTATION_PLAN.md](./OPTION_2_IMPLEMENTATION_PLAN.md) and follow Step 1!
