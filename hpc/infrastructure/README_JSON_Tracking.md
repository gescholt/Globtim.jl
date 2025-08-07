# JSON-Based HPC Input/Output Tracking System

## 📚 **Complete Documentation Suite**

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **[QUICK_START.md](QUICK_START.md)** | 5-minute setup guide | **Start here!** First time users |
| **[ZERO_MANUAL_WORKFLOW.md](ZERO_MANUAL_WORKFLOW.md)** | **Zero job ID copying!** | **Ultimate automation** |
| **[WORKFLOW_GUIDE.md](WORKFLOW_GUIDE.md)** | Complete workflow explanation | Understanding the full system |
| **[AUTOMATED_PULL_GUIDE.md](AUTOMATED_PULL_GUIDE.md)** | Automated results retrieval | Getting results from cluster |
| **[BEFORE_AFTER_COMPARISON.md](BEFORE_AFTER_COMPARISON.md)** | Shows transformation impact | Seeing the benefits |
| **[FAQ.md](FAQ.md)** | Common questions & troubleshooting | When you have problems |
| **[README_JSON_Tracking.md](README_JSON_Tracking.md)** | Technical reference | This document - API details |

## 🚀 **New User? Start Here!**

1. **Read**: [QUICK_START.md](QUICK_START.md) (5 minutes)
2. **Test**: `julia hpc/infrastructure/test_package_activation.jl`
3. **Try**: Create your first job with the quick start guide
4. **Explore**: Look at the results and understand the structure
5. **Adopt**: Gradually integrate into your workflow

## Overview

This system provides comprehensive JSON-based tracking of inputs and outputs for HPC computations in the Globtim project. It ensures full reproducibility, systematic result collection, and organized file management while preventing project bloat.

## Key Features

- **Complete Parameter Tracking**: All input parameters captured for exact reproducibility
- **Structured Output Collection**: Systematic collection of computational results and performance metrics
- **Organized File Management**: Hierarchical directory structure with multiple access patterns
- **Duplicate Detection**: Automatic detection and handling of repeated computations
- **Schema Validation**: JSON schemas ensure data consistency and completeness
- **HPC Integration**: Seamless integration with SLURM job submission system

## Quick Start

### 1. Create a JSON-Tracked Job

```bash
# Navigate to the job creation directory
cd hpc/jobs/creation

# Create a standard Deuflhard job with JSON tracking
julia create_json_tracked_job.jl deuflhard standard

# Create a quick test job
julia create_json_tracked_job.jl deuflhard quick --degree 6 --basis legendre

# Create a thorough analysis job
julia create_json_tracked_job.jl deuflhard thorough --degree 10
```

### 2. Submit to HPC Cluster

```bash
# Copy job script to cluster
scp path/to/job_script.slurm scholten@falcon:~/globtim_hpc/

# Submit job
ssh scholten@falcon 'cd ~/globtim_hpc && sbatch job_script.slurm'

# Monitor job
python hpc/monitoring/python/slurm_monitor.py --job [JOB_ID]
```

### 3. Access Results

Results are automatically organized in multiple ways:

```bash
# By function and date
ls hpc/results/by_function/Deuflhard/2025-01/single_tests/

# By computation date
ls hpc/results/by_date/2025-01-08/

# By tags
ls hpc/results/by_tag/benchmark/
ls hpc/results/by_tag/chebyshev/
```

## File Structure

Each computation creates a complete directory structure:

```
computation_directory/
├── input_config.json          # Complete input parameters
├── output_results.json        # Computational results and metrics
├── detailed_outputs/          # Detailed data files
│   ├── critical_points.csv    # All critical points found
│   ├── minima.csv             # Local minima details
│   ├── polynomial_coeffs.json # Polynomial coefficients
│   └── hessian_analysis.json  # Hessian analysis results
└── logs/                      # Job execution logs
    ├── stdout.log
    ├── stderr.log
    └── slurm_job.out
```

## JSON Schemas

### Input Configuration (`input_config.json`)

Captures all parameters needed to reproduce the computation:

```json
{
  "metadata": {
    "computation_id": "abc12345",
    "timestamp": "2025-01-08T15:30:00Z",
    "function_name": "Deuflhard",
    "description": "Standard test with degree 8 Chebyshev",
    "tags": ["deuflhard", "2d", "chebyshev", "degree8"]
  },
  "test_input": {
    "function_name": "Deuflhard",
    "dimension": 2,
    "center": [0.0, 0.0],
    "sample_range": 1.5,
    "GN": 100
  },
  "polynomial_construction": {
    "degree": 8,
    "basis": "chebyshev",
    "precision_type": "RationalPrecision"
  },
  "critical_point_analysis": {
    "tol_dist": 0.001,
    "enable_hessian": true
  }
}
```

### Output Results (`output_results.json`)

Captures all computational results and performance metrics:

```json
{
  "metadata": {
    "computation_id": "abc12345",
    "timestamp_start": "2025-01-08T15:30:00Z",
    "timestamp_end": "2025-01-08T15:32:15Z",
    "total_runtime": 135.42,
    "status": "SUCCESS"
  },
  "polynomial_results": {
    "construction_time": 12.34,
    "l2_error": 1.23e-6,
    "condition_number": 2.45e8,
    "n_coefficients": 45
  },
  "critical_point_results": {
    "n_valid_critical_points": 13,
    "n_local_minima": 3,
    "solving_time": 8.76,
    "analysis_time": 23.45
  },
  "hessian_analysis": {
    "enabled": true,
    "classification_counts": {
      "minimum": 3,
      "maximum": 1,
      "saddle": 9
    }
  }
}
```

## Available Job Types

| Type | Description | Time Limit | Memory | CPUs | Use Case |
|------|-------------|------------|--------|------|----------|
| `quick` | Fast validation | 30 min | 16G | 8 | Quick tests, debugging |
| `standard` | Moderate analysis | 2 hours | 32G | 16 | Regular benchmarking |
| `thorough` | Comprehensive | 4 hours | 64G | 24 | Detailed analysis |
| `long` | Extended runs | 12 hours | 128G | 24 | Complex problems |

## Testing the System

Run the comprehensive test suite to validate the JSON tracking system:

```bash
cd hpc/infrastructure
julia test_json_tracking.jl
```

This will test:
- JSON I/O utilities
- Schema validation
- Complete workflow with a simple function
- File organization and round-trip consistency

## API Reference

### Core Functions

```julia
# Generate unique computation ID
computation_id = generate_computation_id()

# Create input configuration
input_config = create_input_config(TR, degree, basis, precision_type)

# Save input configuration
save_input_config(input_config, "path/to/input_config.json")

# Create output results
output_results = create_output_results(computation_id, start_time, end_time, 
                                     pol, df_critical, df_min, timings)

# Save output results
save_output_results(output_results, "path/to/output_results.json")

# Create organized directory structure
output_dir = create_computation_directory(base_dir, function_name, 
                                        computation_id, description)
```

### Validation Functions

```julia
# Validate input configuration
is_valid = validate_input_config(input_config)

# Compute parameter hash for duplicate detection
hash = compute_parameter_hash(input_config)

# Load saved configurations
input_config = load_input_config("path/to/input_config.json")
output_results = load_output_results("path/to/output_results.json")
```

## Directory Organization

The system creates a hierarchical structure that prevents bloat while enabling easy access:

```
hpc/results/
├── by_function/           # Primary organization by function
│   └── Deuflhard/
│       └── 2025-01/
│           ├── single_tests/
│           ├── parameter_sweeps/
│           └── benchmarks/
├── by_date/              # Chronological access via symlinks
├── by_tag/               # Categorical access via symlinks
├── by_status/            # Status-based organization
└── indices/              # Search and indexing files
```

## Benefits

1. **Reproducibility**: Every computation can be exactly reproduced
2. **Organization**: Systematic file structure prevents project bloat
3. **Analysis Ready**: Structured data enables automated post-processing
4. **Debugging**: Complete parameter and result tracking
5. **Collaboration**: Standardized format for sharing results
6. **Scalability**: Handles single tests to large parameter sweeps

## Integration with Existing Workflow

The JSON tracking system integrates seamlessly with the existing Globtim workflow:

1. **Deuflhard Notebook**: Can be adapted to use JSON tracking for systematic parameter studies
2. **HPC Jobs**: All existing job types can be enhanced with JSON tracking
3. **Monitoring**: Works with existing SLURM monitoring tools
4. **Analysis**: JSON data can be easily imported into analysis notebooks

## Future Enhancements

- **Web Dashboard**: Browser-based interface for exploring results
- **Automated Analysis**: Scripts to generate summary reports from JSON data
- **Parameter Optimization**: Use historical results to suggest optimal parameters
- **Result Comparison**: Tools to compare results across different parameter sets
- **Database Integration**: Optional database backend for large-scale result management

## Support

For questions or issues with the JSON tracking system:

1. Check the test suite: `julia test_json_tracking.jl`
2. Review the schemas in `hpc/infrastructure/schemas/`
3. Examine example files for proper format
4. Consult the design document: `json_tracking_design.md`
