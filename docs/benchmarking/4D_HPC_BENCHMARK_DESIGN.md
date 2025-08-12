# 4D Benchmark Example for HPC Cluster Testing

## 🎯 Objective
Create a comprehensive 4D benchmark test that validates the complete Globtim workflow on the HPC cluster, including:
- Function evaluation and polynomial approximation
- Critical point computation and verification
- Sparsification analysis and convergence tracking
- Performance measurement and result validation

## 📊 Test Configuration

### Selected Benchmark Functions
Based on `Examples/4d_benchmark_tests/benchmark_4d_framework.jl`:

1. **Sphere Function** (Primary Test)
   - Function: `f(x) = sum(x[i]^2 for i in 1:4)`
   - Domain: `[-5.12, 5.12]^4`
   - Global minimum: `[0, 0, 0, 0]` with `f_min = 0.0`
   - Properties: Unimodal, smooth, well-conditioned

2. **Rosenbrock Function** (Secondary Test)
   - Function: `f(x) = sum(100*(x[i+1] - x[i]^2)^2 + (1 - x[i])^2 for i in 1:3)`
   - Domain: `[-2.048, 2.048]^4`
   - Global minimum: `[1, 1, 1, 1]` with `f_min = 0.0`
   - Properties: Multimodal, challenging optimization landscape

### Test Parameters

#### Polynomial Degrees
- **Light Test**: degrees = [4, 6]
- **Medium Test**: degrees = [6, 8, 10]
- **Heavy Test**: degrees = [8, 10, 12]

#### Sample Configuration
- **Center Points**: 
  - Sphere: `[0.0, 0.0, 0.0, 0.0]`
  - Rosenbrock: `[0.5, 0.5, 0.5, 0.5]`
- **Sample Range**: 2.0 (covers significant portion of domain)
- **Tolerance**: `1e-12` (high precision for validation)

#### Computational Parameters
- **Sparsification**: Track coefficient truncation at multiple thresholds
- **Convergence**: Monitor L2 norm convergence with ForwardDiff
- **Critical Points**: Compute and validate using solve_polynomial_system
- **Distance Tracking**: Measure distance to known global minima

## 📁 Results Folder Structure

### HPC Server Structure
```
~/globtim_hpc/results/4d_benchmark_tests/
├── run_<timestamp>/
│   ├── sphere_deg4/
│   │   ├── polynomial_coeffs.csv
│   │   ├── critical_points.csv
│   │   ├── convergence_analysis.csv
│   │   ├── sparsification_data.csv
│   │   └── validation_summary.txt
│   ├── sphere_deg6/
│   │   └── [same structure]
│   ├── rosenbrock_deg4/
│   │   └── [same structure]
│   ├── benchmark_summary.txt
│   ├── performance_metrics.json
│   └── test_configuration.toml
```

### Local Collection Structure
```
collected_results/4d_benchmark_<job_id>_<timestamp>/
├── job_outputs/
│   ├── 4d_benchmark_<job_id>.out
│   ├── 4d_benchmark_<job_id>.err
│   └── 4d_benchmark_test.jl
├── results/
│   └── [mirror of server structure]
├── analysis/
│   ├── combined_results.csv
│   ├── performance_summary.txt
│   └── validation_report.md
└── metadata/
    ├── collection_summary.json
    ├── monitoring_summary.json
    └── test_parameters.json
```

## 🧮 Expected Outputs

### Per Function/Degree Combination
1. **Polynomial Coefficients** (`polynomial_coeffs.csv`)
   - Coefficient values and indices
   - Sparsification statistics
   - Truncation thresholds and retained coefficients

2. **Critical Points** (`critical_points.csv`)
   - Computed critical point locations
   - Function values at critical points
   - Classification (minimum, maximum, saddle)
   - Distance to known global minimum

3. **Convergence Analysis** (`convergence_analysis.csv`)
   - L2 norm values vs polynomial degree
   - Gradient norms at critical points
   - Convergence rates and trends

4. **Validation Summary** (`validation_summary.txt`)
   - Success/failure status for each computation
   - Accuracy metrics (distance to true minimum)
   - Performance timing information
   - Error analysis and diagnostics

### Aggregate Results
1. **Benchmark Summary** (`benchmark_summary.txt`)
   - Overall test results across all functions/degrees
   - Pass/fail statistics
   - Performance comparisons
   - Identified issues or anomalies

2. **Performance Metrics** (`performance_metrics.json`)
   - Execution times per computation stage
   - Memory usage statistics
   - Computational complexity analysis
   - Scaling behavior with polynomial degree

## ⚙️ Test Implementation Strategy

### Phase 1: Basic Function Evaluation
- Test function evaluation at sample points
- Verify numerical accuracy against analytical values
- Measure evaluation performance

### Phase 2: Polynomial Construction
- Build polynomial approximations for each degree
- Track coefficient sparsification
- Validate approximation accuracy

### Phase 3: Critical Point Computation
- Use solve_polynomial_system to find critical points
- Classify critical points (min/max/saddle)
- Measure distance to known global minima

### Phase 4: Convergence Analysis
- Analyze convergence with increasing polynomial degree
- Use ForwardDiff for gradient computations
- Track L2 norm improvements

### Phase 5: Validation and Reporting
- Compare results against known analytical solutions
- Generate comprehensive validation reports
- Identify any computational issues or limitations

## 🎯 Success Criteria

### Functional Requirements
- [ ] All benchmark functions evaluate correctly
- [ ] Polynomial approximations converge with increasing degree
- [ ] Critical points are found within tolerance of known minima
- [ ] Sparsification reduces coefficient count while maintaining accuracy
- [ ] All output files are generated with correct structure

### Performance Requirements
- [ ] Execution time scales reasonably with polynomial degree
- [ ] Memory usage remains within cluster limits
- [ ] No numerical instabilities or convergence failures
- [ ] Results are reproducible across multiple runs

### Validation Requirements
- [ ] Distance to global minimum < 1e-6 for highest degree
- [ ] L2 norm convergence rate > 0.5 per degree increase
- [ ] Critical point classification accuracy > 95%
- [ ] Sparsification maintains approximation quality

## 🔧 Implementation Notes

### HPC-Specific Considerations
- Use `--compiled-modules=no` flag for Julia execution
- Implement robust error handling for quota/network issues
- Include progress reporting for long-running computations
- Save intermediate results to prevent data loss

### Resource Requirements
- **CPU**: 4-8 cores for parallel polynomial construction
- **Memory**: 8-16GB for high-degree polynomials
- **Time**: 30-60 minutes for complete test suite
- **Storage**: ~100MB for all output files

### Integration with Existing Infrastructure
- Use existing automated monitoring system
- Follow established file naming conventions
- Integrate with result collection pipeline
- Maintain compatibility with existing analysis tools

---

**Next Steps**: Implement test parameters, create construction script, plan results structure, and validate consistency across all components.
