# HPC JSON-Based Input/Output Tracking System Design

## Overview

This document outlines a comprehensive JSON-based system for standardizing and tracking inputs and outputs of HPC computations in the Globtim project. The system addresses the need to systematically collect, organize, and track computational parameters and results when running jobs on the HPC cluster.

## Design Goals

1. **Comprehensive Parameter Tracking**: Capture all input parameters for reproducibility
2. **Structured Output Collection**: Systematically collect all computational results
3. **Organized File Management**: Prevent project bloat while enabling easy search/reuse
4. **Reproducibility**: Enable exact reproduction of any computation
5. **Analysis-Ready Data**: Structure data for easy post-processing and analysis
6. **Scalability**: Handle both single tests and large parameter sweeps

## Core Components

### 1. Input Parameter Schema (`input_config.json`)

Captures all parameters needed to reproduce a computation:

```json
{
  "metadata": {
    "computation_id": "uuid-string",
    "timestamp": "2025-01-08T10:30:00Z",
    "function_name": "Deuflhard",
    "description": "Single degree test with Chebyshev basis",
    "tags": ["2d", "benchmark", "chebyshev"]
  },
  "test_input": {
    "function_name": "Deuflhard",
    "dimension": 2,
    "center": [0.0, 0.0],
    "sample_range": 1.2,
    "GN": 100,
    "tolerance": null,
    "precision_params": null,
    "noise_params": null
  },
  "polynomial_construction": {
    "degree": 8,
    "basis": "chebyshev",
    "precision_type": "RationalPrecision",
    "normalized": false,
    "power_of_two_denom": false
  },
  "critical_point_analysis": {
    "tol_dist": 0.001,
    "enable_hessian": true,
    "max_iters_in_optim": 100,
    "bfgs_g_tol": 1e-8,
    "bfgs_f_abstol": 1e-8,
    "verbose": true
  },
  "computational_environment": {
    "julia_version": "1.11.6",
    "globtim_version": "1.1.0",
    "hostname": "furiosa-node-01",
    "threads": 24,
    "memory_limit": "64G",
    "time_limit": "02:00:00"
  }
}
```

### 2. Output Results Schema (`output_results.json`)

Captures all computational results and performance metrics:

```json
{
  "metadata": {
    "computation_id": "uuid-string",
    "timestamp_start": "2025-01-08T10:30:00Z",
    "timestamp_end": "2025-01-08T10:32:15Z",
    "total_runtime": 135.42,
    "status": "SUCCESS"
  },
  "polynomial_results": {
    "construction_time": 12.34,
    "l2_error": 1.23e-6,
    "condition_number": 2.45e8,
    "n_coefficients": 45,
    "n_samples_used": 100,
    "convergence_achieved": true
  },
  "critical_point_results": {
    "solving_time": 8.76,
    "analysis_time": 23.45,
    "n_raw_solutions": 49,
    "n_real_solutions": 21,
    "n_valid_critical_points": 13,
    "n_local_minima": 3,
    "convergence_statistics": {
      "n_converged": 13,
      "n_failed": 0,
      "average_iterations": 15.2
    }
  },
  "hessian_analysis": {
    "enabled": true,
    "computation_time": 5.67,
    "classification_counts": {
      "minimum": 3,
      "maximum": 1,
      "saddle": 9,
      "degenerate": 0
    },
    "eigenvalue_statistics": {
      "min_positive_eigenval": 0.001234,
      "max_negative_eigenval": -0.005678
    }
  },
  "performance_metrics": {
    "memory_peak_mb": 2048,
    "cpu_utilization": 0.85,
    "disk_io_mb": 15.2
  }
}
```

## File Organization Structure

```
hpc/results/
├── by_function/
│   ├── Deuflhard/
│   │   ├── 2025-01/
│   │   │   ├── single_degree_tests/
│   │   │   │   ├── deg8_cheb_20250108_103000_abc123/
│   │   │   │   │   ├── input_config.json
│   │   │   │   │   ├── output_results.json
│   │   │   │   │   └── detailed_outputs/
│   │   │   │   │       ├── critical_points.csv
│   │   │   │   │       ├── minima.csv
│   │   │   │   │       └── polynomial_coeffs.json
│   │   │   │   └── deg8_lege_20250108_104500_def456/
│   │   │   └── parameter_sweeps/
│   │   └── 2025-02/
│   └── HolderTable/
├── by_date/
│   ├── 2025-01-08/
│   │   ├── abc123 -> ../../by_function/Deuflhard/2025-01/single_degree_tests/deg8_cheb_20250108_103000_abc123/
│   │   └── def456 -> ../../by_function/Deuflhard/2025-01/single_degree_tests/deg8_lege_20250108_104500_def456/
│   └── 2025-01-09/
├── by_tag/
│   ├── benchmark/
│   ├── 2d/
│   ├── chebyshev/
│   └── legendre/
└── indices/
    ├── computation_index.json
    ├── function_index.json
    └── parameter_index.json
```

### Directory Naming Convention

- **Computation ID**: Short UUID (8 chars) for unique identification
- **Timestamp**: YYYYMMDD_HHMMSS format
- **Descriptive**: Include key parameters (degree, basis, function)
- **Format**: `{description}_{timestamp}_{computation_id}`

## Duplicate Handling Strategy

1. **Input Matching**: Check if identical input parameters exist
2. **Overwrite Policy**: 
   - Same day: Overwrite with confirmation
   - Different day: Create new computation with reference to previous
3. **Versioning**: Keep track of computation versions for debugging

## Implementation Components

### 1. JSON Serialization Utilities (`hpc/infrastructure/json_io.jl`)
- Functions to convert Globtim types to/from JSON
- Handle special types (Functions, Enums, Complex numbers)
- Validation and error handling

### 2. Result Collection Framework (`hpc/infrastructure/result_collector.jl`)
- Automatic timing and performance monitoring
- Structured data collection during computation
- Error handling and partial result saving

### 3. File Organization Manager (`hpc/infrastructure/file_manager.jl`)
- Directory creation and management
- Symlink creation for cross-references
- Index maintenance and search functionality

### 4. HPC Job Integration (`hpc/jobs/templates/`)
- Modified SLURM templates with JSON tracking
- Automatic input/output file generation
- Result collection and organization

## Usage Workflow

1. **Job Creation**: Generate input JSON from parameters
2. **Job Execution**: Collect results automatically during computation
3. **Result Storage**: Organize files according to schema
4. **Analysis**: Query and analyze results using JSON structure

## Benefits

- **Reproducibility**: Every computation can be exactly reproduced
- **Organization**: Systematic file structure prevents bloat
- **Analysis**: Structured data enables easy post-processing
- **Debugging**: Complete parameter and result tracking
- **Collaboration**: Standardized format for sharing results
- **Scalability**: Handles single tests to large parameter sweeps

## Next Steps

1. Implement JSON I/O utilities
2. Create result collection framework
3. Modify HPC job templates
4. Test with Deuflhard example
5. Extend to other benchmark functions
