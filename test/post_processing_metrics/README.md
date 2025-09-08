# Post-Processing Metrics Test Suite

Comprehensive test suite for issue #64: "Implement lightweight post-processing metrics for standardized examples"

## Overview

This test suite validates all core post-processing metrics functionality implemented in `PostProcessingCore.jl`, ensuring correctness, numerical stability, and integration with real experimental data.

## Test Structure

### Core Test Files

1. **`test_l2_norm_validation.jl`** - L2-norm accuracy and convergence validation
   - Quality classification boundaries (excellent/good/acceptable/poor)
   - Convergence tracking across degree progressions
   - Statistical analysis and outlier detection
   - Real data validation against 4d_results.json
   - Theoretical L2-norm expectation validation

2. **`test_distance_to_minima.jl`** - Distance-to-minima computations using benchmark functions
   - Standard benchmark functions (Sphere, Rosenbrock, Beale)
   - High-dimensional distance calculations
   - Multiple minima scenarios
   - Numerical precision and tolerance testing
   - Real experiment data integration

3. **`test_optim_integration.jl`** - Local minimizer distance analysis with Optim.jl
   - Integration with BFGS, LBFGS, and other optimization algorithms
   - Multi-modal function optimization
   - Constrained optimization testing
   - High-dimensional optimization (4D matching real data)
   - Algorithm comparison and robustness testing

4. **`test_quality_classification.jl`** - Quality metrics classification and scoring
   - L2-norm quality boundaries validation
   - Stability classification via condition numbers
   - Combined quality assessments
   - Score distribution analysis
   - Multi-dimensional quality evaluation

5. **`test_sampling_critical_points.jl`** - Sampling efficiency and critical point analysis
   - Theoretical monomial count calculations
   - Sample-to-monomial ratio classifications
   - Critical point distance statistics
   - Clustering analysis
   - High-dimensional sampling scenarios

6. **`test_edge_cases.jl`** - Edge cases and error handling
   - Missing data scenarios
   - Extreme numerical values (NaN, Inf, zeros)
   - High-dimensional and high-degree cases
   - Memory and performance stress testing
   - Error recovery mechanisms

7. **`test_real_data_validation.jl`** - Real experiment data validation
   - 4d_results.json data loading and parsing
   - Complete metrics pipeline validation
   - Cross-validation of all metric computations
   - Performance and timing validation
   - Mathematical consistency checks

## Key Metrics Tested

### 1. L2-Norm Metrics
- **Quality Classification**: excellent (<1e-10), good (<1e-6), acceptable (<1e-3), poor (≥1e-3)
- **Convergence Tracking**: Percentage improvements across degree progressions
- **Statistical Analysis**: Distribution analysis, outlier detection

### 2. Distance to Minima
- **Known Minima**: Distance calculations to analytical solutions
- **Benchmark Functions**: Sphere, Rosenbrock, Beale, Ackley functions
- **Multiple Minima**: Handling functions with multiple global minima
- **Numerical Precision**: Machine precision tolerance testing

### 3. Local Minimizer Distances (Optim.jl Integration)
- **Optimization Algorithms**: BFGS, LBFGS, Gradient Descent, Conjugate Gradient
- **Convergence Analysis**: Relationship between optimization quality and distances
- **Constraint Handling**: Box constraints and feasible region analysis
- **High-Dimensional**: 4D optimization matching real experimental setup

### 4. Quality Classification System
- **L2-Norm Quality**: 4-level scoring system (1-4 points)
- **Stability Assessment**: Condition number classification (good/moderate/poor)
- **Combined Scoring**: Multi-factor quality assessment
- **Boundary Testing**: Exact threshold validation

### 5. Sampling Efficiency Metrics
- **Theoretical Basis**: Binomial coefficient monomial counting
- **Sample Ratios**: Well-conditioned (≥2.0), marginal (1.0-2.0), underdetermined (<1.0)
- **Dimensional Scaling**: Analysis across dimensions and degrees
- **Critical Point Clustering**: Inter-point distance statistics

### 6. Critical Point Analysis
- **Distance Statistics**: Min/max/mean/std of inter-critical-point distances
- **Clustering Detection**: Identification of clustered vs distributed points
- **High-Dimensional**: Multi-dimensional critical point analysis
- **Precision Testing**: Near-identical point handling

## Real Data Validation

The test suite validates against actual experimental data from `4d_results.json`:
- **L2_norm**: 0.010676438802846829
- **Dimension**: 4, **Degree**: 8  
- **Condition_number**: 16.0
- **Total_samples**: 12, **Theoretical_monomials**: 495
- **Center**: [0.25, 0.25, 0.45, 0.55]

### Expected Results
- **Quality**: "poor" (L2 > 1e-3)
- **Stability**: "good" (condition < 1e8)
- **Sampling**: "underdetermined" (12/495 ≈ 0.024 < 1.0)

## Usage

### Run Complete Test Suite
```bash
julia --project=. test/post_processing_metrics/runtests.jl
```

### Run Individual Test Files
```bash
julia --project=. -e "using Test; include(\"test/post_processing_metrics/test_l2_norm_validation.jl\")"
julia --project=. -e "using Test; include(\"test/post_processing_metrics/test_quality_classification.jl\")"
# ... etc
```

### Expected Performance
- **Total Tests**: ~600+ individual test cases
- **Execution Time**: <10 seconds on modern hardware
- **Memory Usage**: <100MB peak memory
- **Dependencies**: Standard library + Optim.jl + ForwardDiff.jl

## Test Coverage

The test suite provides comprehensive coverage of:
- ✅ All public API functions in PostProcessingCore.jl
- ✅ Mathematical correctness validation
- ✅ Numerical stability across input ranges
- ✅ Integration with optimization libraries
- ✅ Real experimental data consistency
- ✅ Edge cases and error conditions
- ✅ Performance and scalability

## Integration

This test suite integrates with:
- **PostProcessingCore.jl**: Core lightweight metrics (Julia standard library only)
- **PostProcessing.jl**: Full framework with DataFrame/CSV support
- **4d_results.json**: Real experimental validation data
- **Optim.jl**: Optimization algorithm integration
- **ForwardDiff.jl**: Automatic differentiation support

## Quality Standards

All tests must satisfy:
- **Correctness**: Mathematical validation against analytical solutions
- **Precision**: Numerical accuracy within specified tolerances
- **Robustness**: Graceful handling of edge cases and missing data
- **Performance**: Sub-second execution for individual test files
- **Coverage**: >90% code coverage of target functionality

## Contributing

When adding new post-processing metrics:
1. Add corresponding tests following existing patterns
2. Include benchmark validation where possible
3. Test against real experimental data
4. Validate numerical precision and stability
5. Document expected behavior and edge cases