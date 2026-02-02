# Globtim Test Documentation

This document provides a comprehensive overview of all test suites in the Globtim package, their purpose, and when to run them.

## Test Organization

Tests are organized by feature area in the `test/` directory:

```
test/
├── runtests.jl                              # Main test runner
├── test_forwarddiff_integration.jl         # ForwardDiff optimization integration
├── test_function_value_analysis.jl         # Function value error analysis
├── test_exact_conversion.jl                # Exact arithmetic conversion
├── test_sparsification.jl                  # Polynomial sparsification
├── test_truncation.jl                      # Polynomial truncation
├── test_l2_norm_scaling.jl                 # L2 norm scaling tests
├── test_anisotropic_grids.jl               # Anisotropic grid functionality
├── test_quadrature_l2_norm.jl              # Quadrature-based L2 norm computation
├── test_quadrature_l2_phase1_2.jl          # Phase 1/2 quadrature integration
├── test_quadrature_vs_riemann.jl           # Quadrature vs Riemann comparison
├── test_hessian_analysis.jl                # Phase 2 Hessian analysis
├── test_enhanced_analysis_integration.jl   # Phase 3 enhanced analysis
├── test_statistical_tables.jl              # Phase 3 statistical tables
└── Debug utilities (not in main test suite):
    ├── debug_conversion.jl
    ├── debug_legendre.jl
    └── run_quadrature_tests.jl
```

## Running Tests

### Run All Tests
```bash
julia --project test/runtests.jl
```

### Run Specific Test Suite
```bash
julia --project test/test_anisotropic_grids.jl
```

### Run Tests with Package Manager
```julia
using Pkg
Pkg.test("Globtim")
```

## Test Suites

### 1. ForwardDiff Integration Tests (`test_forwarddiff_integration.jl`)

**Purpose**: Tests integration with ForwardDiff.jl for gradient and Hessian computation.

**When to run**:
- After modifying gradient computation methods
- When changing automatic differentiation usage
- After updates to optimization routines

**Key tests**:
- Gradient computation accuracy
- Hessian computation correctness
- Performance of AD operations
- Integration with polynomial approximations

### 2. Function Value Error Analysis (`test_function_value_analysis.jl`)

**Purpose**: Tests the accuracy of function value computations and error metrics.

**When to run**:
- After modifying error analysis methods
- When changing function evaluation procedures
- After updates to error metrics

**Test categories**:
- Error computation methods
- Statistical error analysis
- Error propagation through pipeline
- Convergence analysis

### 3. Anisotropic Grid Tests (`test_anisotropic_grids.jl`)

**Purpose**: Tests the generation and usage of anisotropic grids with different number of points per dimension.

**When to run**: 
- After modifying `anisotropic_grids.jl`
- After changes to `generate_grid` functions
- After modifications to L2 norm computation methods

**Test categories**:
- Basic grid generation (2D, 3D, high-dimensional)
- Grid properties (Chebyshev, Legendre, uniform nodes)
- L2 norm computation on anisotropic grids
- Comparison with isotropic grids
- Performance benefits for multiscale functions
- Backward compatibility

**Key tests**:
- Verifies grid dimensions match specifications
- Tests node distributions for different bases
- Validates L2 norm accuracy on anisotropic grids
- Demonstrates 15x improvement for multiscale functions

### 4. Quadrature L2 Norm Tests (`test_quadrature_l2_norm.jl`)

**Purpose**: Tests the quadrature-based L2 norm computation using orthogonal polynomials.

**When to run**:
- After modifying `quadrature_l2_norm.jl`
- After changes to polynomial quadrature methods
- When updating orthogonal polynomial implementations

**Test categories**:
- Basic functionality for all dimensions (1D-4D)
- Different polynomial bases (Chebyshev, Legendre, uniform)
- Polynomial test functions with known L2 norms
- Gaussian and exponential functions
- Comparison with Riemann sum methods

**Key validations**:
- Exact computation for polynomials up to degree 2n
- Accurate results for smooth functions
- Consistency across different bases

### 5. Exact Conversion Tests (`test_exact_conversion.jl`)

**Purpose**: Tests conversion of polynomial approximations to exact monomial basis.

**When to run**:
- After modifying `exact_conversion.jl`
- When changing polynomial representation
- After updates to basis conversion methods

**Test coverage**:
- Conversion from orthogonal to monomial basis
- Preservation of polynomial identity
- Exact arithmetic operations
- Multi-dimensional polynomial handling

### 6. Sparsification Tests (`test_sparsification.jl`)

**Purpose**: Tests polynomial sparsification based on L2 contributions.

**When to run**:
- After modifying sparsification algorithms
- When updating L2 norm computations
- After changes to polynomial manipulation

**Key features tested**:
- Identification of significant monomials
- Controlled approximation error
- Sparsity vs accuracy tradeoffs
- Performance improvements

### 7. Truncation Tests (`test_truncation.jl`)

**Purpose**: Tests polynomial truncation with L2 error bounds.

**When to run**:
- After modifying truncation methods
- When updating error analysis
- After changes to polynomial degree reduction

**Validates**:
- Truncation error bounds
- Optimal degree selection
- L2 norm preservation

### 8. L2 Norm Scaling Tests (`test_l2_norm_scaling.jl`)

**Purpose**: Tests L2 norm computation with different scaling factors.

**When to run**:
- After modifying scaling utilities
- When updating coordinate transformations
- After changes to norm computation

### 9. Phase 1/2 Quadrature Integration (`test_quadrature_l2_phase1_2.jl`)

**Purpose**: Tests integration of quadrature methods with Phase 1 and 2 features.

**When to run**:
- After modifying quadrature implementations
- When updating Phase 1/2 integration
- After changes to polynomial basis functions

**Key validations**:
- Phase 1 polynomial approximation with quadrature
- Phase 2 critical point analysis with quadrature norms
- Cross-phase consistency

### 10. Quadrature vs Riemann Comparison (`test_quadrature_vs_riemann.jl`)

**Purpose**: Benchmarks and compares quadrature vs Riemann sum methods.

**When to run**:
- When optimizing L2 norm computation
- After implementing new norm methods
- For performance analysis

**Test categories**:
- Accuracy comparison
- Performance benchmarks
- Convergence rates
- Method selection guidance

### 11. Phase 2 Hessian Analysis (`test_hessian_analysis.jl`)

**Purpose**: Tests Hessian-based critical point classification.

**When to run**:
- After modifying Hessian computation
- When updating critical point classification
- After changes to eigenvalue analysis

**Key features tested**:
- Hessian computation accuracy
- Eigenvalue extraction
- Critical point classification (min/max/saddle)
- Condition number analysis

### 12. Phase 3 Enhanced Analysis Integration (`test_enhanced_analysis_integration.jl`)

**Purpose**: Tests the complete Phase 3 analysis pipeline integration.

**When to run**:
- After modifying Phase 3 features
- When updating analysis pipelines
- After changes to data structures

**Test coverage**:
- Multi-tolerance analysis
- Enhanced BFGS refinement
- Orthant decomposition
- Result aggregation

### 13. Phase 3 Statistical Tables (`test_statistical_tables.jl`)

**Purpose**: Tests statistical analysis and table generation features.

**When to run**:
- After modifying statistical computations
- When updating table formatting
- After changes to analysis outputs

**Validates**:
- Statistical metric computation
- Table rendering (console and LaTeX)
- Data aggregation
- Export functionality

## Test Dependencies

### Required Packages
- Test
- LinearAlgebra
- StaticArrays
- PolyChaos (for quadrature tests)
- ForwardDiff (for differentiation tests)
- DataFrames (for analysis tests)
- HomotopyContinuation (for critical point tests)
- BenchmarkTools (for performance comparisons)

### File Dependencies
- All test files depend on the main Globtim module
- Quadrature tests require `quadrature_l2_norm.jl`
- Anisotropic tests require `anisotropic_grids.jl`
- Exact conversion tests require `exact_conversion.jl`
- Phase 2 tests require `hessian_analysis.jl`
- Phase 3 tests require `enhanced_analysis.jl` and `data_structures.jl`
- Statistical tests require `statistical_tables.jl`

## Adding New Tests

When adding new functionality:

1. Create a new test file: `test_<feature_name>.jl`
2. Add to `runtests.jl`
3. Document the test suite here
4. Include:
   - Purpose and scope
   - When to run the tests
   - Dependencies
   - Key validations

## Continuous Integration

Tests should be run:
- Before committing changes
- After merging branches
- When preparing releases
- As part of CI/CD pipeline

## Performance Benchmarks

Some test files include performance comparisons:
- `test_anisotropic_grids.jl`: Demonstrates 15x improvement for multiscale functions
- `test_quadrature_l2_norm.jl`: Compares quadrature vs Riemann methods

## Debugging Failed Tests

1. Run the specific test file in isolation
2. Check for missing dependencies (`--project` flag)
3. Verify file paths are correct
4. Look for version conflicts in Project.toml
5. Check if new exports are added to Globtim.jl

## Test Coverage Goals

- All exported functions should have tests
- Edge cases and error conditions
- Performance regression tests
- Integration tests for combined features
- Documentation examples as tests