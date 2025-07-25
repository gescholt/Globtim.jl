# Test Coverage Matrix

This matrix shows which source files are tested by each test file in the Globtim package.

## Source Files to Test Files Mapping

| Source File | Test Files | Coverage Areas |
|-------------|------------|----------------|
| **Main_Gen.jl** | runtests.jl (main test) | Constructor, MainGenerate |
| **scaling_utils.jl** | test_l2_norm_scaling.jl | Scale factor handling, compute_norm |
| **l2_norm.jl** | test_l2_norm_scaling.jl, test_quadrature_vs_riemann.jl | L2 norm computation |
| **anisotropic_grids.jl** | test_anisotropic_grids.jl | Anisotropic grid generation |
| **quadrature_l2_norm.jl** | test_quadrature_l2_norm.jl, test_quadrature_l2_phase1_2.jl | Quadrature-based norms |
| **exact_conversion.jl** | test_exact_conversion.jl | Monomial basis conversion |
| **advanced_l2_analysis.jl** | test_sparsification.jl | Sparsification algorithms |
| **truncation_analysis.jl** | test_truncation.jl | Polynomial truncation |
| **hessian_analysis.jl** | test_hessian_analysis.jl | Phase 2 Hessian computation |
| **enhanced_analysis.jl** | test_enhanced_analysis_integration.jl | Phase 3 integration |
| **data_structures.jl** | test_enhanced_analysis_integration.jl | Enhanced data structures |
| **function_value_analysis.jl** | test_function_value_analysis.jl | Error analysis |
| **ParsingOutputs.jl** | runtests.jl (process_crit_pts) | Critical point processing |
| **hom_solve.jl** | runtests.jl, test_hessian_analysis.jl | Polynomial system solving |
| **statistical_tables.jl** | test_statistical_tables.jl | Statistical analysis |

## Test Files to Source Files Mapping

| Test File | Primary Source Files Tested | Secondary Dependencies |
|-----------|---------------------------|------------------------|
| **runtests.jl** | Main_Gen.jl, hom_solve.jl, ParsingOutputs.jl | Constructor, test_input, process_crit_pts |
| **test_forwarddiff_integration.jl** | ForwardDiff integration | gradient/Hessian computation |
| **test_function_value_analysis.jl** | function_value_analysis.jl | Error metrics, convergence |
| **test_exact_conversion.jl** | exact_conversion.jl | to_exact_monomial_basis |
| **test_sparsification.jl** | advanced_l2_analysis.jl | sparsify_polynomial |
| **test_truncation.jl** | truncation_analysis.jl | truncate_polynomial |
| **test_l2_norm_scaling.jl** | scaling_utils.jl, l2_norm.jl | compute_norm, discrete_l2_norm_riemann |
| **test_anisotropic_grids.jl** | anisotropic_grids.jl | generate_anisotropic_grid |
| **test_quadrature_l2_norm.jl** | quadrature_l2_norm.jl | compute_l2_norm_quadrature |
| **test_quadrature_l2_phase1_2.jl** | quadrature_l2_norm.jl | Phase integration |
| **test_quadrature_vs_riemann.jl** | l2_norm.jl, quadrature_l2_norm.jl | Method comparison |
| **test_hessian_analysis.jl** | hessian_analysis.jl, hom_solve.jl | Phase 2 features |
| **test_enhanced_analysis_integration.jl** | enhanced_analysis.jl, data_structures.jl | Phase 3 pipeline |
| **test_statistical_tables.jl** | statistical_tables.jl | Table generation |

## Coverage Gaps

### Untested Source Files
1. **Visualization extensions** (GLMakie/CairoMakie)
   - No test files for plotting functions
   - Extension modules not covered

2. **msolve_system.jl**
   - Alternative polynomial solver not tested
   - msolve_polynomial_system function

3. **subdomain_management.jl**
   - 4D orthant decomposition
   - Subdomain utilities

4. **multi_tolerance_analysis.jl**
   - Multi-tolerance execution framework
   - Cross-tolerance integration

5. **refine.jl**
   - BFGS refinement routines
   - Basin analysis

### Partially Tested Files
1. **Structures.jl** - Data structures used throughout but not directly tested
2. **LibFunctions.jl** - Test functions used in tests but not comprehensively tested
3. **grid_utils.jl** - Grid utilities used but not all functions tested

## Recommendations

1. **High Priority**: Add tests for visualization extensions if they are user-facing
2. **Medium Priority**: Test alternative solvers (msolve) and refinement methods
3. **Low Priority**: Add comprehensive tests for utility functions and data structures

## Test Organization by Phase

### Phase 1 (Core Functionality)
- Polynomial approximation (runtests.jl)
- Grid generation (test_anisotropic_grids.jl)
- L2 norm computation (test_l2_norm_scaling.jl)
- Exact conversion (test_exact_conversion.jl)

### Phase 2 (Analysis)
- Hessian analysis (test_hessian_analysis.jl)
- Critical point classification
- Function value analysis (test_function_value_analysis.jl)

### Phase 3 (Enhanced Features)
- Statistical tables (test_statistical_tables.jl)
- Enhanced analysis integration (test_enhanced_analysis_integration.jl)
- Multi-tolerance analysis

### Cross-Phase Integration
- Quadrature methods (test_quadrature_l2_phase1_2.jl)
- Performance comparisons (test_quadrature_vs_riemann.jl)