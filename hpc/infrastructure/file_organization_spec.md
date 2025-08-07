# HPC Results File Organization Specification

## Overview

This document specifies the hierarchical directory structure for organizing HPC computation results in a way that prevents project bloat while enabling easy search, analysis, and reuse of results.

## Directory Structure

```
hpc/results/
├── by_function/                    # Primary organization by objective function
│   ├── Deuflhard/
│   │   ├── 2025-01/               # Monthly organization
│   │   │   ├── single_tests/      # Individual parameter tests
│   │   │   │   ├── deg8_cheb_20250108_103000_abc12345/
│   │   │   │   │   ├── input_config.json
│   │   │   │   │   ├── output_results.json
│   │   │   │   │   ├── detailed_outputs/
│   │   │   │   │   │   ├── critical_points.csv
│   │   │   │   │   │   ├── minima.csv
│   │   │   │   │   │   ├── polynomial_coeffs.json
│   │   │   │   │   │   ├── hessian_analysis.json
│   │   │   │   │   │   └── timing_breakdown.json
│   │   │   │   │   └── logs/
│   │   │   │   │       ├── stdout.log
│   │   │   │   │       ├── stderr.log
│   │   │   │   │       └── slurm_job.out
│   │   │   │   └── deg8_lege_20250108_104500_def45678/
│   │   │   ├── parameter_sweeps/  # Multi-parameter studies
│   │   │   │   ├── degree_sweep_20250109_090000_ghi78901/
│   │   │   │   │   ├── sweep_config.json
│   │   │   │   │   ├── sweep_results.json
│   │   │   │   │   ├── individual_results/
│   │   │   │   │   │   ├── deg4_abc12345/
│   │   │   │   │   │   ├── deg6_def45678/
│   │   │   │   │   │   └── deg8_ghi78901/
│   │   │   │   │   └── analysis/
│   │   │   │   │       ├── convergence_analysis.json
│   │   │   │   │       ├── scaling_plots.png
│   │   │   │   │       └── summary_report.md
│   │   │   │   └── basis_comparison_20250110_140000_jkl90123/
│   │   │   └── benchmarks/        # Systematic benchmark studies
│   │   │       └── comprehensive_20250115_080000_mno34567/
│   │   ├── 2025-02/
│   │   └── archive/               # Older results (>6 months)
│   ├── HolderTable/
│   ├── Rastringin/
│   └── custom_functions/
├── by_date/                       # Chronological access via symlinks
│   ├── 2025-01-08/
│   │   ├── abc12345 -> ../../by_function/Deuflhard/2025-01/single_tests/deg8_cheb_20250108_103000_abc12345/
│   │   └── def45678 -> ../../by_function/Deuflhard/2025-01/single_tests/deg8_lege_20250108_104500_def45678/
│   └── 2025-01-09/
├── by_tag/                        # Categorical access via symlinks
│   ├── benchmark/
│   │   ├── abc12345 -> ../../by_function/Deuflhard/2025-01/single_tests/deg8_cheb_20250108_103000_abc12345/
│   │   └── def45678 -> ../../by_function/Deuflhard/2025-01/single_tests/deg8_lege_20250108_104500_def45678/
│   ├── 2d/
│   ├── chebyshev/
│   ├── legendre/
│   ├── high_degree/
│   └── adaptive_precision/
├── by_status/                     # Status-based organization
│   ├── success/
│   ├── failed/
│   ├── partial/
│   └── timeout/
├── indices/                       # Search and indexing files
│   ├── computation_index.json    # Master index of all computations
│   ├── function_index.json       # Index by function
│   ├── parameter_index.json      # Index by parameter combinations
│   ├── performance_index.json    # Index by performance metrics
│   └── tag_index.json           # Index by tags
└── templates/                     # Template files for new computations
    ├── input_template.json
    ├── output_template.json
    └── directory_template/
```

## Naming Conventions

### Computation Directory Names
Format: `{description}_{timestamp}_{computation_id}`

- **description**: Brief descriptive name (e.g., `deg8_cheb`, `basis_sweep`, `adaptive_test`)
- **timestamp**: `YYYYMMDD_HHMMSS` format
- **computation_id**: 8-character alphanumeric ID

Examples:
- `deg8_cheb_20250108_103000_abc12345`
- `basis_sweep_20250109_090000_ghi78901`
- `adaptive_4d_20250110_140000_jkl90123`

### File Naming Standards
- **Input config**: `input_config.json`
- **Output results**: `output_results.json`
- **Detailed data**: Use descriptive names in `detailed_outputs/`
- **Logs**: Standard names in `logs/`

## Duplicate Handling Strategy

### 1. Input Parameter Matching
Before creating a new computation:
1. Generate hash of input parameters
2. Check if identical parameters exist in recent computations (last 30 days)
3. If found, prompt user with options:
   - Reuse existing results
   - Create new computation with version suffix
   - Overwrite existing (with confirmation)

### 2. Overwrite Policies
- **Same day, same parameters**: Overwrite with confirmation
- **Different day, same parameters**: Create new computation with reference to previous
- **Parameter variations**: Always create new computation

### 3. Versioning System
For repeated computations with identical parameters:
- Add version suffix: `deg8_cheb_20250108_103000_abc12345_v2`
- Maintain reference chain in metadata
- Keep previous versions unless explicitly deleted

## Index Management

### Computation Index (`computation_index.json`)
```json
{
  "computations": {
    "abc12345": {
      "path": "by_function/Deuflhard/2025-01/single_tests/deg8_cheb_20250108_103000_abc12345",
      "function": "Deuflhard",
      "timestamp": "2025-01-08T15:30:00Z",
      "status": "SUCCESS",
      "tags": ["deuflhard", "2d", "chebyshev", "degree8"],
      "parameters_hash": "sha256:abc123...",
      "runtime": 135.42,
      "quality": "good"
    }
  },
  "last_updated": "2025-01-08T16:00:00Z",
  "total_computations": 1
}
```

### Parameter Index (`parameter_index.json`)
Groups computations by parameter combinations for easy comparison:
```json
{
  "parameter_groups": {
    "deuflhard_2d_deg8_cheb": {
      "parameters": {
        "function": "Deuflhard",
        "dimension": 2,
        "degree": 8,
        "basis": "chebyshev"
      },
      "computations": ["abc12345", "def45678"],
      "latest": "def45678"
    }
  }
}
```

## Storage Management

### Automatic Cleanup
- **Archive old results**: Move results >6 months to `archive/`
- **Compress detailed outputs**: Gzip CSV files and large JSON files
- **Remove failed computations**: Clean up failed runs after 30 days (keep logs)

### Size Monitoring
- Track directory sizes in index files
- Alert when storage exceeds thresholds
- Provide cleanup recommendations

### Backup Strategy
- Daily backup of index files
- Weekly backup of recent results (last 30 days)
- Monthly archive of older results

## Access Patterns

### 1. By Function and Time
Most common access pattern for analyzing specific functions:
```bash
ls hpc/results/by_function/Deuflhard/2025-01/single_tests/
```

### 2. By Date
For reviewing recent work:
```bash
ls hpc/results/by_date/2025-01-08/
```

### 3. By Tags
For thematic analysis:
```bash
ls hpc/results/by_tag/benchmark/
ls hpc/results/by_tag/adaptive_precision/
```

### 4. By Status
For debugging and quality control:
```bash
ls hpc/results/by_status/failed/
ls hpc/results/by_status/timeout/
```

## Search and Query Interface

### Command-Line Tools
- `hpc_search --function Deuflhard --degree 8 --status SUCCESS`
- `hpc_list --recent 7days --tag benchmark`
- `hpc_compare abc12345 def45678`

### Programmatic Interface
```julia
# Find all successful Deuflhard computations with degree 8
results = search_computations(
    function_name="Deuflhard",
    degree=8,
    status="SUCCESS"
)

# Compare parameter sets
comparison = compare_computations(["abc12345", "def45678"])
```

## Benefits of This Structure

1. **Prevents Bloat**: Organized hierarchy with automatic cleanup
2. **Easy Navigation**: Multiple access patterns via symlinks
3. **Fast Search**: Indexed structure enables quick queries
4. **Reproducibility**: Complete parameter tracking with duplicate detection
5. **Analysis Ready**: Structured data enables automated analysis
6. **Scalable**: Handles single tests to large parameter sweeps
7. **Maintainable**: Clear organization with automated management

## Implementation Priority

1. **Phase 1**: Basic directory structure and naming conventions
2. **Phase 2**: Index management and search functionality
3. **Phase 3**: Duplicate detection and versioning
4. **Phase 4**: Automated cleanup and archiving
5. **Phase 5**: Advanced query and comparison tools
