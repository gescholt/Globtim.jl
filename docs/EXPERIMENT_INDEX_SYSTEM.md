# Experiment Index System

**Author:** GlobTim Project
**Date:** October 6, 2025
**Status:** ✅ Implemented and Tested

## Overview

The Experiment Index System provides automated tracking, duplicate detection, and search functionality for HPC experiments. It addresses [Issue #18](https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues/18) by implementing index management integrated into the experiment pipeline.

## Features

### ✅ Implemented

1. **Parameter Hashing**
   - Deterministic SHA256 hashing of experiment parameters
   - Key-order independent
   - Handles nested structures (arrays, dicts)

2. **Computation Index**
   - Master index of all experiments with metadata
   - Fast lookup by computation ID
   - Status tracking (PENDING, RUNNING, SUCCESS, FAILED, etc.)
   - Runtime metrics

3. **Parameter Index**
   - Groups experiments by identical parameters
   - Tracks latest computation for each parameter set
   - Enables quick duplicate detection

4. **Duplicate Detection**
   - Automatic detection of experiments with identical parameters
   - Configurable time window (default: 30 days)
   - Warning messages when duplicates are found

5. **Search Interface**
   - Search by experiment name, status, date range
   - List recent experiments
   - Get detailed experiment information
   - CLI and programmatic interfaces

## Architecture

### Core Modules

```
src/
├── ExperimentIndex.jl              # Core indexing functionality
└── ExperimentIndexIntegration.jl   # Integration with experiment pipeline
```

### Data Structures

#### ComputationEntry
```julia
struct ComputationEntry
    computation_id::String          # Unique 8-character ID
    path::String                    # Path to experiment results
    experiment_name::String         # Name of experiment
    timestamp::DateTime            # When experiment was created
    status::String                 # PENDING, RUNNING, SUCCESS, FAILED, etc.
    parameters_hash::String        # SHA256 hash of parameters
    parameters::Dict{String, Any}  # Indexable parameters
    runtime::Float64               # Execution time in seconds
    metadata::Dict{String, Any}    # Additional metadata
end
```

#### ComputationIndex
```julia
mutable struct ComputationIndex
    computations::Dict{String, ComputationEntry}
    last_updated::DateTime
    total_computations::Int
end
```

#### ParameterIndex
```julia
mutable struct ParameterIndex
    parameter_groups::Dict{String, ParameterGroup}
end
```

### Index Files

Stored in `experiments/indices/`:
- `computation_index.json` - Master index of all computations
- `parameter_index.json` - Parameter-grouped index

## Usage

### Basic Workflow

#### 1. Setup with Index Integration

```julia
include("src/ExperimentIndexIntegration.jl")

# Create experiment config
config = Dict(
    "experiment_id" => 1,
    "domain_range" => 0.4,
    "GN" => 16,
    "degree_min" => 4,
    "degree_max" => 12,
    "basis" => "chebyshev",
    "created_at" => string(now())
)

# Check for duplicates and index
has_dups, comp_id, duplicates = check_and_index_experiment(
    config,
    experiment_name="lotka_volterra_4d",
    experiment_path="experiments/lv4d/exp_1",
    warn_duplicates=true
)

if has_dups
    println("Found $(length(duplicates)) duplicate(s)")
    # Decide whether to proceed or reuse existing results
end
```

#### 2. Update Status During Execution

```julia
# Start execution
update_experiment_status(
    comp_id,
    status="RUNNING",
    runtime=0.0,
    metadata=Dict("worker_id" => "node_42")
)

# ... run experiment ...

# Complete execution
update_experiment_status(
    comp_id,
    status="SUCCESS",
    runtime=1234.56,
    metadata=Dict(
        "degrees_completed" => [4, 5, 6, 7, 8],
        "output_files" => ["results.json", "data.csv"]
    )
)
```

#### 3. Search and Query

```julia
# Search by experiment name
search_experiments_cli(experiment_name="lotka_volterra_4d")

# Search by status
search_experiments_cli(status="SUCCESS")

# Combined search
search_experiments_cli(
    experiment_name="lotka_volterra_4d",
    status="SUCCESS",
    after=now() - Day(7)
)

# List recent experiments
list_recent_experiments_cli(limit=10)

# Get detailed information
get_experiment_details(comp_id)
```

### Example: Enhanced Setup Script

See [experiments/daisy_ex3_4d_study/setup_experiments_with_index.jl](../experiments/daisy_ex3_4d_study/setup_experiments_with_index.jl) for a complete example.

Key features:
- Automatic duplicate detection during setup
- Warns user if identical parameters exist
- Tracks all experiments with computation IDs
- Integrates seamlessly with existing workflow

## API Reference

### Core Functions

#### `compute_parameter_hash(parameters::Dict) -> String`
Compute deterministic SHA256 hash of parameters.

#### `initialize_index(index_file::String) -> ComputationIndex`
Initialize or load existing computation index.

#### `add_computation!(index::ComputationIndex, entry::ComputationEntry)`
Add new computation to index.

#### `update_computation!(index::ComputationIndex, entry::ComputationEntry)`
Update existing computation in index.

#### `find_duplicates(index::ComputationIndex, parameters::Dict; days_threshold=30) -> Vector{ComputationEntry}`
Find computations with identical parameters within time window.

#### `search_computations(index::ComputationIndex; kwargs...) -> Vector{ComputationEntry}`
Search with criteria: `experiment_name`, `status`, `after`, `before`.

### Integration Functions

#### `check_and_index_experiment(config; experiment_name, experiment_path, warn_duplicates=true) -> (Bool, String, Vector)`
Check for duplicates, index experiment, return (has_duplicates, computation_id, duplicates).

#### `update_experiment_status(computation_id; status, runtime=0.0, metadata=Dict())`
Update experiment status with metadata.

#### `search_experiments_cli(; kwargs...)`
CLI interface for searching experiments.

#### `list_recent_experiments_cli(; limit=10)`
List most recent experiments.

#### `get_experiment_details(computation_id::String)`
Get detailed experiment information.

## Testing

### Unit Tests

```bash
julia --project=. test/test_experiment_index.jl
```

Tests:
- Index schema and data structures (10 tests)
- Parameter hashing (4 tests)
- Index creation and updates (6 tests)
- Duplicate detection (3 tests)
- Search/query interface (7 tests)
- Parameter index management (6 tests)
- Integration utilities (12 tests)

**Total: 70 tests, all passing ✅**

### Integration Tests

```bash
julia --project=. test/test_experiment_index_integration.jl
```

Tests:
- Check and index experiment workflow
- Status update lifecycle
- Search CLI functionality
- Full end-to-end workflow simulation

**Total: 32 tests, all passing ✅**

## Benefits

1. **Prevents Duplicate Work**
   - Automatically detects experiments with identical parameters
   - Warns before running redundant computations
   - Saves HPC resources and time

2. **Experiment Tracking**
   - Complete history of all experiments
   - Status tracking throughout lifecycle
   - Performance metrics (runtime, etc.)

3. **Fast Search**
   - Find experiments by multiple criteria
   - No need to search through file system
   - Indexed lookup in O(1) time

4. **Reproducibility**
   - Exact parameter tracking via hashing
   - Reference to previous identical runs
   - Metadata preservation

5. **Workflow Integration**
   - Minimal changes to existing scripts
   - Optional duplicate warnings
   - Automatic index updates

## Future Enhancements (Deferred)

These features were considered but deemed unnecessary for current needs:

- ❌ Elaborate symlink organization (by_date, by_type, by_status)
- ❌ Automatic README generation per experiment
- ❌ Archive strategy for old experiments
- ❌ Complex directory hierarchy (objective_function/dense_or_sparse/date/)

The cleanup script ([tools/hpc/monitoring/auto_cleanup.sh](../tools/hpc/monitoring/auto_cleanup.sh)) handles organization needs.

## Related Issues

- ✅ [Issue #18](https://git.mpi-cbg.de/globaloptim/globtimcore/-/issues/18) - Improve Result File Organization Structure

## Files

### Implementation
- [src/ExperimentIndex.jl](../src/ExperimentIndex.jl) - Core module (506 lines)
- [src/ExperimentIndexIntegration.jl](../src/ExperimentIndexIntegration.jl) - Integration (287 lines)

### Tests
- [test/test_experiment_index.jl](../test/test_experiment_index.jl) - Unit tests (487 lines)
- [test/test_experiment_index_integration.jl](../test/test_experiment_index_integration.jl) - Integration tests (275 lines)

### Examples
- [experiments/daisy_ex3_4d_study/setup_experiments_with_index.jl](../experiments/daisy_ex3_4d_study/setup_experiments_with_index.jl) - Example usage

## Conclusion

The Experiment Index System provides robust tracking and duplicate detection for HPC experiments with minimal workflow disruption. All features are tested and ready for production use.

**Status: ✅ Complete and Ready for Use**
