# 4D Benchmark Results Folder Structure Plan

## 📁 Server-Side Structure (~/globtim_hpc/results/)

### Primary Results Directory
```
~/globtim_hpc/results/4d_benchmark_tests/
├── run_<YYYYMMDD_HHMMSS>/                    # Timestamped run directory
│   ├── metadata/                             # Test configuration and metadata
│   │   ├── test_configuration.toml           # Copy of test parameters
│   │   ├── execution_environment.json        # Julia version, packages, system info
│   │   ├── job_info.json                     # SLURM job details
│   │   └── start_time.txt                    # Test start timestamp
│   │
│   ├── sphere/                               # Results for Sphere function
│   │   ├── degree_4/
│   │   │   ├── polynomial_coeffs.csv         # Polynomial coefficients and indices
│   │   │   ├── critical_points.csv           # Critical points found
│   │   │   ├── convergence_analysis.csv      # L2 norm, gradient convergence
│   │   │   ├── sparsification_data.csv       # Coefficient truncation analysis
│   │   │   ├── function_evaluations.csv      # Sample points and function values
│   │   │   ├── timing_breakdown.json         # Detailed timing for each stage
│   │   │   └── validation_results.txt        # Pass/fail validation summary
│   │   ├── degree_6/
│   │   │   └── [same structure as degree_4]
│   │   ├── degree_8/
│   │   │   └── [same structure as degree_4]
│   │   ├── sphere_summary.txt                # Overall results for Sphere function
│   │   └── sphere_performance.json           # Performance metrics across degrees
│   │
│   ├── rosenbrock/                           # Results for Rosenbrock function
│   │   └── [same structure as sphere/]
│   │
│   ├── combined_analysis/                    # Cross-function analysis
│   │   ├── convergence_comparison.csv        # Compare convergence across functions
│   │   ├── performance_comparison.csv        # Compare timing across functions
│   │   ├── sparsification_comparison.csv     # Compare sparsification effectiveness
│   │   └── accuracy_comparison.csv           # Compare accuracy metrics
│   │
│   ├── benchmark_summary.txt                 # Overall test results
│   ├── performance_metrics.json              # Aggregate performance data
│   ├── validation_report.md                  # Comprehensive validation report
│   └── execution_log.txt                     # Detailed execution log
```

### Naming Conventions

#### Run Directory
- Format: `run_YYYYMMDD_HHMMSS`
- Example: `run_20250809_143000`
- Timezone: UTC for consistency

#### Function Directories
- `sphere/` - Sphere function results
- `rosenbrock/` - Rosenbrock function results
- Additional functions: `griewank/`, `rastringin/`, etc.

#### Degree Subdirectories
- Format: `degree_<N>`
- Examples: `degree_4`, `degree_6`, `degree_8`, `degree_10`

#### File Naming
- CSV files: `<data_type>.csv`
- JSON files: `<data_type>.json`
- Text files: `<data_type>.txt`
- Markdown files: `<data_type>.md`

## 📊 Detailed File Specifications

### 1. polynomial_coeffs.csv
```csv
degree,coefficient_index,coefficient_value,monomial_powers,sparsification_threshold,retained
4,1,1.2345e-03,"[2,0,0,0]",1e-12,true
4,2,5.6789e-08,"[1,1,0,0]",1e-12,false
4,3,9.8765e-05,"[0,2,0,0]",1e-12,true
```

### 2. critical_points.csv
```csv
function_name,degree,point_id,x1,x2,x3,x4,function_value,classification,distance_to_global_min,gradient_norm,hessian_eigenvalues
sphere,4,1,0.0001,-0.0002,0.0003,-0.0001,1.5e-08,minimum,1.2e-04,3.4e-09,"[2.1,2.0,2.0,1.9]"
sphere,4,2,1.2345,0.5678,-0.9876,0.3456,15.678,saddle,2.1,0.0,"[1.2,-0.8,0.5,-1.1]"
```

### 3. convergence_analysis.csv
```csv
function_name,degree,l2_norm,gradient_norm,convergence_rate,approximation_error,sample_points,coefficients
sphere,4,1.234e-05,2.345e-06,0.85,3.456e-07,330,70
sphere,6,2.345e-07,3.456e-08,0.92,4.567e-09,1287,210
```

### 4. sparsification_data.csv
```csv
function_name,degree,threshold,original_coeffs,retained_coeffs,reduction_ratio,approximation_quality,l2_error_increase
sphere,4,1e-06,70,45,0.357,0.999,1.2e-08
sphere,4,1e-08,70,52,0.257,0.9999,3.4e-10
```

### 5. function_evaluations.csv
```csv
point_id,x1,x2,x3,x4,function_value,evaluation_time_ms,numerical_error
1,0.0,0.0,0.0,0.0,0.0,0.123,1e-16
2,0.5,0.5,0.5,0.5,1.0,0.098,2e-16
```

### 6. timing_breakdown.json
```json
{
  "total_time_seconds": 145.67,
  "stages": {
    "function_evaluation": 12.34,
    "polynomial_construction": 89.45,
    "critical_point_computation": 34.56,
    "sparsification_analysis": 7.89,
    "validation": 1.43
  },
  "memory_usage_mb": {
    "peak": 1234.5,
    "average": 876.2
  }
}
```

### 7. validation_results.txt
```
4D Benchmark Validation Results - Sphere Function, Degree 4
===========================================================

ACCURACY VALIDATION:
✓ Distance to global minimum: 1.2e-04 < 1e-06 (PASS)
✓ L2 norm convergence rate: 0.85 > 0.5 (PASS)
✓ Critical point classification: 95.2% > 95% (PASS)
✓ Approximation error: 3.4e-07 < 1e-08 (FAIL - exceeds threshold)

PERFORMANCE VALIDATION:
✓ Execution time: 145.67s < 600s (PASS)
✓ Memory usage: 1.23GB < 8GB (PASS)
✓ Sparsification ratio: 0.357 > 0.1 (PASS)
✓ Numerical stability: 0 instabilities (PASS)

COMPLETENESS VALIDATION:
✓ All required output files generated (PASS)
✓ Critical points found: 3 > 1 (PASS)
✓ Polynomial degrees completed: 1 ≥ 2 (FAIL - incomplete)

OVERALL STATUS: PARTIAL PASS (2/3 validation categories passed)
```

## 📥 Local Collection Structure

### Collected Results Directory
```
collected_results/4d_benchmark_<job_id>_<timestamp>/
├── job_outputs/                              # SLURM job outputs
│   ├── 4d_benchmark_<job_id>.out            # SLURM stdout
│   ├── 4d_benchmark_<job_id>.err            # SLURM stderr
│   └── 4d_benchmark_test.jl                 # Source test script
│
├── server_results/                           # Mirror of server results
│   └── [exact copy of server structure]
│
├── analysis/                                 # Local analysis and summaries
│   ├── combined_results.csv                 # Flattened results across all tests
│   ├── performance_dashboard.html           # Interactive performance visualization
│   ├── validation_dashboard.html            # Interactive validation summary
│   ├── convergence_plots/                   # Generated convergence plots
│   │   ├── sphere_convergence.png
│   │   ├── rosenbrock_convergence.png
│   │   └── comparison_plot.png
│   └── summary_report.md                    # Executive summary
│
└── metadata/                                # Collection metadata
    ├── collection_summary.json              # File collection details
    ├── monitoring_summary.json              # Job monitoring data
    ├── transfer_log.txt                     # File transfer log
    └── integrity_check.json                 # File integrity verification
```

## 🔍 Data Collection Specifications

### Automated Collection Triggers
1. **Job Completion**: Collect all results when SLURM job finishes
2. **Partial Results**: Collect intermediate results every 30 minutes
3. **Error Recovery**: Collect partial results if job fails
4. **Manual Trigger**: Allow manual collection via monitoring script

### File Integrity Checks
- **Checksums**: MD5 hash for each collected file
- **Size Validation**: Verify file sizes match expected ranges
- **Format Validation**: Check CSV headers and JSON structure
- **Completeness**: Verify all expected files are present

### Collection Prioritization
1. **Critical**: validation_results.txt, benchmark_summary.txt
2. **High**: critical_points.csv, convergence_analysis.csv
3. **Medium**: polynomial_coeffs.csv, sparsification_data.csv
4. **Low**: function_evaluations.csv, timing_breakdown.json

## 🎯 Integration with Existing Infrastructure

### Monitoring Integration
- Use existing `automated_job_monitor.py` with 4D-specific patterns
- Add 4D benchmark file patterns to collection logic
- Implement progress tracking based on degree completion

### Result Validation
- Extend existing validation framework for 4D-specific criteria
- Add automated pass/fail determination
- Generate standardized validation reports

### Performance Tracking
- Integrate with existing performance monitoring
- Track resource usage patterns for 4D computations
- Compare against baseline performance metrics

---

**Implementation Priority**: 
1. Core file structure and naming conventions
2. Essential CSV/JSON output formats
3. Validation and integrity checking
4. Integration with existing monitoring system
