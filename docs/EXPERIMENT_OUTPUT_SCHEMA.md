# Experiment Output JSON Schema

## Overview
Standardized JSON schema for all Globtim experiment outputs, ensuring consistency across different experiment types and enabling automated validation and visualization.

## Schema Version
**Current Version:** 1.2.0

## Version History

### Version 1.2.0 (2025-10-21)
**Type**: Minor update (adds validation fields, backward compatible)

**Added**:
- `validation_time`: Time spent on ForwardDiff validation
- `validation_stats`: Critical point validation metrics
  - `gradient_tol`: Tolerance used for gradient verification
  - `critical_verified`: Number of verified critical points (||∇f|| < tol)
  - `critical_spurious`: Number of spurious critical points (||∇f|| >= tol)
  - `gradient_norm_mean/max/min`: Gradient norm statistics
  - `classifications`: Counts by Hessian classification (minimum, maximum, saddle, degenerate, error)
  - `distinct_local_minima`: Number of unique local minima found
  - `minima_cluster_sizes`: Points in each minimum cluster
  - `minima_cluster_representatives`: Representative indices for each cluster

**CSV Enhancement**: Added columns `gradient_norm`, `is_spurious`, `classification`, `eigenvalue_min/max`, `hessian_condition_number`, `determinant`

**Backward Compatibility**: v1.1.0 readers can read v1.2.0 experiments (extra fields ignored). v1.2.0 readers can read v1.1.0 experiments (missing validation fields treated as optional).

### Version 1.1.0 (2025-09-30)
**Type**: Minor update (adds optional fields, backward compatible)

**Added**:
- `critical_points_raw`: Number of critical points from HomotopyContinuation (before refinement)
- `critical_points_refined`: Number successfully refined with Optim.jl
- `refinement_stats`: Convergence and quality metrics for Optim.jl refinement
- `precision_type` (optional): Per-degree precision type (Float64, Float32, BigFloat)

**Backward Compatibility**: v1.0.0 readers can read v1.1.0 experiments (extra fields ignored gracefully). v1.1.0 readers can read v1.0.0 experiments (missing fields treated as optional).

### Version 1.0.0 (2025-09-28)
**Type**: Initial standardized schema

**Features**:
- Root structure with `schema_version`, `experiment_id`, `timestamp`
- `system_info` for self-contained system metadata (system type, parameters, domain, equilibrium)
- `results_summary` with per-degree metrics (critical points, L2 error, condition number)
- Backward compatibility with legacy formats (pre-v1.0.0)

## Root Structure

```json
{
  "schema_version": "1.0.0",
  "experiment_id": "string",
  "experiment_type": "string",
  "timestamp": "ISO8601 datetime string",
  "system_info": { ... },
  "params_dict": { ... },
  "results_summary": { ... },
  "total_critical_points": "integer",
  "total_time": "float (seconds)",
  "output_dir": "string (relative path)"
}
```

## Field Specifications

### Required Fields

#### `schema_version` (string)
- Format: Semantic versioning "MAJOR.MINOR.PATCH"
- Example: `"1.0.0"`
- Purpose: Enable schema evolution and backward compatibility

#### `experiment_id` (string)
- Format: Unique identifier, typically `<type>_<params>_<timestamp>`
- Example: `"minimal_4d_lv_test_GN=5_domain_size_param=0.1_max_time=45.0_20250930_102304"`
- Purpose: Unique experiment identification

#### `experiment_type` (string)
- Format: Snake_case string describing experiment type
- Examples:
  - `"4d_lotka_volterra_minimal"`
  - `"otl_circuit_6d"`
  - `"cluster_pipeline_test"`
  - `"extended_parameter_sweep"`
- Purpose: Categorize experiments for filtering and analysis

#### `timestamp` (string)
- Format: ISO8601 or `"yyyymmdd_HHMMSS"`
- Example: `"2025-09-30T10:23:04"` or `"20250930_102304"`
- Purpose: Experiment execution time tracking

#### `system_info` (object)
- **Purpose**: Self-contained system metadata for reproducibility
- **Required subfields**:
  ```json
  {
    "system_type": "string",           // e.g., "lotka_volterra_4d", "otl_circuit_6d"
    "dimension": "integer",            // System dimensionality
    "domain_center": [float, ...],     // Center point of search domain
    "domain_size": "float",            // Half-width of domain
    "objective_function": "string"     // e.g., "squared_system_residual", "circuit_voltage"
  }
  ```
- **System-specific subfields**:

  **For dynamical systems (Lotka-Volterra, etc.):**
  ```json
  {
    "system_params": {
      "α": float,
      "β": float,
      // ... other system parameters
    },
    "known_equilibrium": [float, ...]  // Known equilibrium point (optional)
  }
  ```

  **For circuit systems (OTL, etc.):**
  ```json
  {
    "circuit_params": {
      "bounds": [[min, max], ...],     // Parameter bounds
      "nominal_values": [float, ...]    // Nominal parameter values
    }
  }
  ```

#### `params_dict` (object)
- **Purpose**: Computational parameters for reproducibility
- **Required subfields**:
  ```json
  {
    "GN": "integer",                   // Grid size per dimension
    "degree_range": [int, int, ...],   // Polynomial degrees tested
    "domain_size_param": "float",      // Domain size parameter
    "max_time": "float"                // Maximum time per degree (seconds)
  }
  ```

#### `results_summary` (object)
- **Purpose**: Per-degree computational results
- **Structure**: Dictionary keyed by `"degree_N"`
  ```json
  {
    "degree_3": {
      // V1.0.0 fields
      "critical_points": "integer",     // Number of refined points in domain
      "l2_approx_error": "float",
      "condition_number": "float",
      "computation_time": "float (seconds)",
      "status": "string",              // "success" | "failed" | "timeout"

      // Timing breakdown (optional but recommended)
      "polynomial_construction_time": "float",
      "critical_point_solving_time": "float",
      "critical_point_processing_time": "float",
      "file_io_time": "float",

      // V1.1.0 fields (optional, for refinement support)
      "critical_points_raw": "integer",        // From HomotopyContinuation
      "critical_points_refined": "integer",    // After Optim.jl refinement
      "refinement_stats": {
        "converged": "integer",                // Successfully refined points
        "failed": "integer",                   // Failed refinements
        "mean_improvement": "float",           // Mean |f(refined) - f(raw)|
        "max_improvement": "float",            // Maximum improvement (optional)
        "mean_iterations": "float"             // Mean Optim iterations (optional)
      },
      "precision_type": "string",              // "Float64" | "Float32" | "BigFloat" (optional)

      // V1.2.0 fields (optional, for critical point validation)
      "validation_time": "float",              // Time for ForwardDiff validation
      "validation_stats": {
        "gradient_tol": "float",               // Tolerance for ||∇f|| verification
        "critical_verified": "integer",         // Points with ||∇f|| < tol
        "critical_spurious": "integer",        // Points with ||∇f|| >= tol (spurious)
        "gradient_norm_mean": "float",         // Mean ||∇f|| across all points
        "gradient_norm_max": "float",          // Maximum ||∇f||
        "gradient_norm_min": "float",          // Minimum ||∇f||
        "classifications": {
          "minimum": "integer",                // Hessian positive definite
          "maximum": "integer",                // Hessian negative definite
          "saddle": "integer",                 // Hessian indefinite
          "degenerate": "integer",             // Hessian has zero eigenvalues
          "error": "integer"                   // Hessian computation failed
        },
        "distinct_local_minima": "integer",    // Number of unique minima clusters
        "minima_cluster_sizes": [int, ...],    // Points per cluster
        "minima_cluster_representatives": [int, ...]  // Best point index per cluster
      },

      // Error information (if status != "success")
      "error": "string"                // Error message
    },
    // ... more degrees
  }
  ```

#### `total_critical_points` (integer)
- Total number of critical points found across all degrees
- Example: `147`

#### `total_time` (float)
- Total experiment execution time in seconds
- Example: `1234.56`

#### `output_dir` (string)
- Relative path to output directory
- Example: `"hpc_results/minimal_4d_lv_test_GN=5_domain_size_param=0.1_max_time=45.0_20250930_102304"`

### Optional Fields

#### `degrees_processed` (integer)
- Number of polynomial degrees successfully processed

#### `success_rate` (float)
- Fraction of degrees that completed successfully (0.0 to 1.0)

#### `git_commit` (string)
- Git commit hash for provenance tracking (if using DrWatson)

### V1.1.0 Optional Fields (Refinement Support)

#### `critical_points_raw` (integer, per-degree)
- **Added in**: v1.1.0
- **Purpose**: Number of critical points found by HomotopyContinuation (before Optim.jl refinement)
- **Example**: `13`
- **Note**: May be larger than `critical_points_refined` due to convergence failures

#### `critical_points_refined` (integer, per-degree)
- **Added in**: v1.1.0
- **Purpose**: Number of critical points successfully refined by Optim.jl
- **Example**: `12`
- **Relationship**: `critical_points_refined` ≤ `critical_points_raw`

#### `refinement_stats` (object, per-degree)
- **Added in**: v1.1.0
- **Purpose**: Convergence and quality metrics for Optim.jl refinement
- **Required subfields**:
  ```json
  {
    "converged": integer,        // Number of successful refinements
    "failed": integer,           // Number of failed refinements
    "mean_improvement": float    // Mean |f(refined) - f(raw)|
  }
  ```
- **Optional subfields**:
  ```json
  {
    "max_improvement": float,    // Maximum improvement across all points
    "mean_iterations": float     // Mean Optim.jl iteration count
  }
  ```
- **Consistency**: `converged + failed` should equal `critical_points_raw`
- **Example**:
  ```json
  {
    "converged": 12,
    "failed": 1,
    "mean_improvement": 1.234e-10,
    "max_improvement": 5.678e-09,
    "mean_iterations": 5.2
  }
  ```

#### `precision_type` (string, per-degree)
- **Added in**: v1.1.0
- **Purpose**: Floating-point precision used for this specific degree
- **Allowed values**: `"Float64"`, `"Float32"`, `"BigFloat"`
- **Example**: `"Float64"`
- **Note**: Useful for adaptive precision experiments where different degrees use different precision types

## Validation Rules

### Schema Validation
1. All required fields must be present
2. `schema_version` must match pattern `^\d+\.\d+\.\d+$`
3. `dimension` must match length of `domain_center`
4. `degree_range` must be non-empty array of positive integers
5. All time values must be non-negative floats
6. `status` must be one of: `"success"`, `"failed"`, `"timeout"`

### Data Consistency
1. `total_critical_points` should equal sum of `critical_points` across all degrees
2. `total_time` should be approximately equal to sum of `computation_time` across degrees
3. If `status == "failed"`, `error` field should be present
4. `condition_number` should be present for all successful degree results

### V1.1.0 Validation (Refinement Fields)
1. If `refinement_stats` is present, `critical_points_raw` and `critical_points_refined` must also be present
2. `refinement_stats.converged + refinement_stats.failed` should equal `critical_points_raw`
3. `critical_points_refined` should be ≤ `critical_points_raw`
4. `mean_improvement` should be non-negative
5. If v1.1.0 fields are missing, validation issues warnings but continues (backward compatibility)

### System-Specific Validation

**Lotka-Volterra systems:**
- `system_params` must contain keys matching system definition
- `known_equilibrium` length must equal `dimension`

**Circuit systems:**
- `circuit_params.bounds` length must equal `dimension`
- Each bound must be `[min, max]` with `min < max`

## Example: Complete Minimal 4D Lotka-Volterra Experiment

```json
{
  "schema_version": "1.0.0",
  "experiment_id": "minimal_4d_lv_test_GN=5_domain_size_param=0.1_max_time=45.0_20250930_102304",
  "experiment_type": "4d_lotka_volterra_minimal",
  "timestamp": "20250930_102304",

  "system_info": {
    "system_type": "lotka_volterra_4d",
    "dimension": 4,
    "system_params": {
      "α": 1.2,
      "β": 0.8,
      "γ": 1.5,
      "δ": 0.7
    },
    "domain_center": [1.875, 1.5, 0.1, 0.1],
    "domain_size": 0.1,
    "known_equilibrium": [1.875, 1.5, 0.0, 0.0],
    "objective_function": "squared_system_residual"
  },

  "params_dict": {
    "GN": 5,
    "degree_range": [4, 5, 6, 7, 8],
    "domain_size_param": 0.1,
    "max_time": 45.0
  },

  "results_summary": {
    "degree_4": {
      "critical_points": 0,
      "l2_approx_error": 2.1734e-9,
      "condition_number": 88.94,
      "polynomial_construction_time": 0.123,
      "critical_point_solving_time": 1.456,
      "critical_point_processing_time": 0.002,
      "file_io_time": 0.001,
      "computation_time": 1.582,
      "status": "success"
    },
    "degree_5": {
      "critical_points": 0,
      "l2_approx_error": 1.0234e-11,
      "condition_number": 156.23,
      "polynomial_construction_time": 0.234,
      "critical_point_solving_time": 3.456,
      "critical_point_processing_time": 0.003,
      "file_io_time": 0.001,
      "computation_time": 3.694,
      "status": "success"
    }
  },

  "total_critical_points": 0,
  "total_time": 5.276,
  "output_dir": "hpc_results/minimal_4d_lv_test_GN=5_domain_size_param=0.1_max_time=45.0_20250930_102304",
  "degrees_processed": 2,
  "success_rate": 1.0
}
```

## Backward Compatibility

### Handling Legacy Experiments
Visualization and analysis tools should gracefully handle experiments without:
1. `schema_version` - Assume version 0.0.0 (pre-standardization)
2. `system_info` - Issue warning and skip system-dependent visualizations
3. `condition_number` - Skip condition number plots

### Migration Guide
To migrate legacy experiments:
1. Add `schema_version: "1.0.0"` at root level
2. Extract system parameters into `system_info` object
3. Ensure all required fields are present
4. Add `condition_number` to degree results if available

## Schema Evolution Policy

### Version Numbering
- **MAJOR**: Breaking changes (remove required fields, change field types)
- **MINOR**: Add new optional fields, deprecate fields
- **PATCH**: Documentation updates, validation refinements

### Deprecation Process
1. Mark field as deprecated in schema documentation
2. Maintain backward compatibility for 2 minor versions
3. Remove in next major version

## Validation Implementation

A validation module should be implemented in `globtimcore/src/validation.jl`:

```julia
function validate_experiment_schema(data::Dict)
    # Validate schema version
    # Check required fields
    # Verify data consistency
    # Return (is_valid::Bool, errors::Vector{String})
end
```