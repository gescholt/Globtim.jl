# Globtim Test Suite

This directory contains all tests for the Globtim package, organized by test type.

## Directory Structure

### Root Level Files
- `runtests.jl` - Main test runner (used by Julia's test framework)
- `run_precision_tests.jl` - Specialized precision test runner
- `run_quadrature_tests.jl` - Specialized quadrature test runner
- `aqua_config.jl` - Configuration for Aqua.jl quality checks
- `dependency_validation.jl` - Package dependency validation

### Test Categories

#### `unit/`
Unit tests for individual functions and modules. These tests should be:
- Fast (< 1 second each)
- Isolated (no external dependencies)
- Focused on single components

**Files**: `test_*.jl` - All unit test files

#### `integration/`
Integration tests that verify interactions between multiple components:
- End-to-end workflows
- HPC infrastructure tests
- Cross-module integration
- Pipeline validation

**Examples**: `test_*_integration.jl`, `test_*_e2e.jl`, `test_hpc_*.jl`

#### `debugging/`
Development and debugging utilities:
- Debug scripts for troubleshooting
- Demo files showing specific behaviors
- Temporary investigation scripts

**Examples**: `debug_*.jl`, `demo_*.jl`, `step_by_step_debug.jl`

#### `fixtures/`
Test data, mock configurations, and test utilities used across tests

#### `specialized_tests/`
Domain-specific test suites:
- Hook tests
- Integration snapshots
- Specific feature test suites

#### `archived_2025_10/`
Historical tests archived in October 2025. Preserved for reference but not actively maintained.

### Other Directories
- `batches/` - Batch job testing
- `cluster/` - Cluster-specific tests
- `validation/` - Validation framework tests
- `path_resolution/` - Path handling tests
- `worker_context/` - Worker context tests
- `test_results/` - Test output directory

## Running Tests

### Run All Tests
```julia
using Pkg
Pkg.activate(".")
Pkg.test()
```

### Run Specific Test Categories
```julia
# Unit tests only
include("test/unit/test_specific_feature.jl")

# Integration tests
include("test/integration/test_hpc_workflow.jl")

# Specialized test suites
include("test/run_precision_tests.jl")
include("test/run_quadrature_tests.jl")
```

### Run Quality Checks
```julia
# Aqua.jl quality tests
include("test/aqua_config.jl")
```

## Test Organization Guidelines

When adding new tests:

1. **Unit tests** → `test/unit/test_<component>.jl`
   - Test a single function or module
   - Keep fast and isolated

2. **Integration tests** → `test/integration/test_<workflow>_integration.jl`
   - Test interactions between components
   - Can be slower and have dependencies

3. **Debug/investigation** → `test/debugging/debug_<issue>.jl`
   - Temporary debugging scripts
   - Archive or remove when issue is resolved

4. **Test utilities** → `test/fixtures/`
   - Reusable test data
   - Mock configurations
   - Helper functions

## Maintenance

- Regularly review `debugging/` and archive or remove resolved investigations
- Keep `archived_2025_10/` for reference but don't actively maintain
- Update this README when adding new test categories
