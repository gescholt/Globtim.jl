# Globtim Test Suite

This directory contains all tests for the Globtim package, organized by test type.

## Directory Structure

### Root Level Files
- `runtests.jl` - Main test runner (used by Julia's test framework)
- `test_*.jl` - The test files `runtests.jl` includes; one file per feature area
- `run_precision_tests.jl` - Specialized precision test runner
- `aqua_config.jl` - Configuration for Aqua.jl quality checks
- `synthetic_generators.jl`, `timeout_utils.jl` - Shared helpers used by several test files

### Subdirectories

Nothing below is run by `Pkg.test()`. These are hand-run scripts and supporting data.

#### `fixtures/`
Test data, mock configurations, and fixture generators used across tests.

#### `benchmarks/`
Performance comparison scripts (test-function benchmarks, 3D/4D sparsification comparison).
Long-running; run explicitly when measuring, not as part of the suite.

#### `debugging/`
Development and investigation utilities — adaptive-precision demos and precision-handling
experiments. Kept for reference when debugging precision behavior.

#### `validation/` and `specialized_tests/validation/`
Standalone end-to-end walkthroughs of the full pipeline (approximation → solve → analyze):
- `validation/deuflhard_4d_minimal.jl`
- `specialized_tests/validation/lotka_volterra_4d_minimal.jl`

Each runs top-to-bottom with `julia --project` and prints its own summary.

## Running Tests

### Run All Tests
```julia
using Pkg
Pkg.activate(".")
Pkg.test()
```

### Run a Single Test File
```julia
using Pkg
Pkg.activate("test")
include("test/test_relative_l2.jl")
```

### Run the Hand-Run Scripts
```bash
julia --project=. test/validation/deuflhard_4d_minimal.jl
julia --project=. test/specialized_tests/validation/lotka_volterra_4d_minimal.jl
julia --project=. test/run_precision_tests.jl
```

### Run Quality Checks
```julia
# Aqua.jl quality tests
include("test/aqua_config.jl")
```

## Test Organization Guidelines

When adding new tests:

1. **Suite tests** → `test/test_<component>.jl`, then add an `include` to `runtests.jl`
   - Test a single function or feature area
   - Keep fast and self-contained — no cluster, no network, no absolute paths

2. **Debug/investigation** → `test/debugging/debug_<issue>.jl`
   - Temporary debugging scripts
   - Remove when the issue is resolved

3. **Test utilities** → `test/fixtures/`
   - Reusable test data
   - Mock configurations
   - Helper functions

## Maintenance

- Regularly review `debugging/` and remove resolved investigations
- Tests must run standalone from a clone of the published package: no references to
  internal cluster tooling, hostnames, or absolute paths outside the package
- Update this README when adding new test categories
