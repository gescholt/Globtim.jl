# Test Running Guide

This guide explains how to run tests for the Globtim package, including different approaches, common issues, and best practices.

## Quick Start

### Run All Tests
```bash
cd /path/to/globtim
julia --project test/runtests.jl
```

### Run Specific Test Suite
```bash
julia --project test/test_anisotropic_grids.jl
```

### Using Package Manager
```julia
using Pkg
Pkg.activate(".")
Pkg.test()
```

## Test Organization

```
test/
# Main test suite
├── runtests.jl                              # Main test runner
├── test_forwarddiff_integration.jl         # ForwardDiff integration tests
├── test_function_value_analysis.jl         # Function value error analysis
├── test_exact_conversion.jl                # Exact conversion tests
├── test_sparsification.jl                  # Sparsification tests
├── test_truncation.jl                      # Truncation tests
├── test_l2_norm_scaling.jl                 # L2 norm scaling tests
├── test_anisotropic_grids.jl               # Anisotropic grid tests
├── test_quadrature_l2_norm.jl              # Quadrature L2 norm tests
├── test_quadrature_l2_phase1_2.jl          # Phase 1/2 quadrature integration
├── test_quadrature_vs_riemann.jl           # Quadrature vs Riemann comparison
├── test_hessian_analysis.jl                # Phase 2 Hessian analysis
├── test_enhanced_analysis_integration.jl   # Phase 3 enhanced analysis
├── test_statistical_tables.jl              # Phase 3 statistical tables
# Debug utilities
├── debug_conversion.jl                     # Debug exact conversion
├── debug_legendre.jl                        # Debug Legendre polynomials
└── run_quadrature_tests.jl                  # Standalone quadrature runner
```

## Running Tests - Detailed Instructions

### Method 1: Command Line (Recommended)

Always use the `--project` flag to ensure correct package environment:

```bash
# From the globtim directory
julia --project test/runtests.jl

# Run specific test
julia --project test/test_anisotropic_grids.jl

# With custom Julia options
julia --project --threads=4 test/runtests.jl
```

### Method 2: Julia REPL

```julia
# Start Julia in project directory
julia> using Pkg
julia> Pkg.activate(".")
julia> Pkg.test()

# Or run specific test
julia> include("test/test_anisotropic_grids.jl")
```

### Method 3: VS Code / IDE

1. Open the project folder
2. Ensure Julia environment is set to project
3. Run test file directly or use test runner

## Common Issues and Solutions

### Issue 1: Package Not Found
```
ERROR: LoadError: ArgumentError: Package Globtim not found in current path
```

**Solution**: Use `--project` flag
```bash
julia --project test/your_test.jl
```

### Issue 2: Missing Dependencies
```
ERROR: LoadError: ArgumentError: Package Test not found in current path
```

**Solution**: Ensure test dependencies are installed
```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()  # Install all dependencies
```

### Issue 3: Module Not Loaded
```
ERROR: UndefVarError: Globtim not defined
```

**Solution**: Add proper using statement
```julia
using Globtim
using Test
```

### Issue 4: Path Issues
```
ERROR: could not open file test/test_file.jl
```

**Solution**: Run from project root directory
```bash
cd /path/to/globtim
julia --project test/test_file.jl
```

## Test Selection Strategies

### By Feature Area

```bash
# Core functionality tests
julia --project test/test_forwarddiff_integration.jl
julia --project test/test_function_value_analysis.jl

# Grid generation tests
julia --project test/test_anisotropic_grids.jl

# L2 norm computation tests
julia --project test/test_quadrature_l2_norm.jl
julia --project test/test_l2_norm_scaling.jl
julia --project test/test_quadrature_vs_riemann.jl

# Polynomial manipulation tests
julia --project test/test_exact_conversion.jl
julia --project test/test_sparsification.jl
julia --project test/test_truncation.jl

# Phase 2 analysis tests
julia --project test/test_hessian_analysis.jl

# Phase 3 analysis tests
julia --project test/test_enhanced_analysis_integration.jl
julia --project test/test_statistical_tables.jl

# Phase integration tests
julia --project test/test_quadrature_l2_phase1_2.jl
```

### By Development Task

**When modifying optimization integration:**
```bash
julia --project test/test_forwarddiff_integration.jl
```

**When modifying grid generation:**
```bash
julia --project test/test_anisotropic_grids.jl
```

**When modifying L2 norm computation:**
```bash
julia --project test/test_quadrature_l2_norm.jl
julia --project test/test_l2_norm_scaling.jl
julia --project test/test_quadrature_vs_riemann.jl
```

**When modifying polynomial methods:**
```bash
julia --project test/test_exact_conversion.jl
julia --project test/test_sparsification.jl
julia --project test/test_truncation.jl
```

**When modifying critical point analysis:**
```bash
julia --project test/test_hessian_analysis.jl
julia --project test/test_function_value_analysis.jl
```

**When modifying Phase 3 features:**
```bash
julia --project test/test_enhanced_analysis_integration.jl
julia --project test/test_statistical_tables.jl
```

### Quick Validation

For rapid validation during development:

```julia
# In REPL with project activated
include("test/test_anisotropic_grids.jl")
# Make changes
include("test/test_anisotropic_grids.jl")  # Re-run
```

## Performance Testing

### Basic Timing

```julia
# Time a specific test suite
@time include("test/test_quadrature_l2_norm.jl")
```

### Detailed Profiling

```julia
using Profile
Profile.clear()
@profile include("test/test_anisotropic_grids.jl")
Profile.print()
```

### Memory Usage

```julia
# Check allocations
@time @allocated include("test/test_anisotropic_grids.jl")
```

## Continuous Integration Setup

### Local Pre-commit Hook

Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
echo "Running tests..."
julia --project test/runtests.jl
if [ $? -ne 0 ]; then
    echo "Tests failed. Commit aborted."
    exit 1
fi
```

### GitHub Actions (Example)

`.github/workflows/test.yml`:
```yaml
name: Run tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: julia-actions/setup-julia@v1
      with:
        version: '1.10'
    - run: julia --project -e 'using Pkg; Pkg.instantiate()'
    - run: julia --project test/runtests.jl
```

## Test Status and Known Issues

### Currently Passing Tests
- Main polynomial system solving
- ForwardDiff integration
- Function value error analysis
- Exact polynomial conversion
- Polynomial sparsification
- Anisotropic grids
- Phase 1/2 quadrature integration
- Phase 2 Hessian analysis

### Tests with Known Issues
1. **test_truncation.jl** - L2 norm verification test failing
2. **test_l2_norm_scaling.jl** - BoundsError with residual function
3. **test_quadrature_l2_norm.jl** - Missing ChebyshevOrthoPoly dependency
4. **test_quadrature_vs_riemann.jl** - Missing BenchmarkTools dependency
5. **test_enhanced_analysis_integration.jl** - Tests expect empty stderr
6. **test_statistical_tables.jl** - String formatting test failure

## Test Coverage Analysis

### Generate Coverage Report

```bash
julia --project --code-coverage test/runtests.jl
```

### View Coverage

```julia
using Coverage
coverage = process_folder()
covered_lines = sum(x -> x.covered, coverage)
total_lines = sum(x -> x.total, coverage)
println("Coverage: $(100 * covered_lines / total_lines)%")
```

## Debugging Test Failures

### Step 1: Isolate the Test

```julia
# Run just the failing test set
@testset "Specific failing test" begin
    # test code
end
```

### Step 2: Add Debugging Output

```julia
# Temporarily add prints
@testset "Debug test" begin
    result = some_function()
    @info "Result" result
    @test result == expected
end
```

### Step 3: Use Debugger

```julia
using Debugger
@enter failing_function(args...)
```

### Step 4: Check Environment

```julia
# Verify package versions
using Pkg
Pkg.status()

# Check Julia version
versioninfo()
```

## Best Practices

### 1. Run Tests Frequently
- Before commits
- After pulling changes
- When switching branches

### 2. Test Incrementally
- Run relevant tests during development
- Run full suite before pushing

### 3. Keep Tests Fast
- Use smaller grids for routine testing
- Save extensive tests for CI

### 4. Document Test Failures
- Note error messages
- Record steps to reproduce
- Check if issue is environment-specific

### 5. Maintain Test Independence
- Tests should not depend on order
- Clean up any generated files
- Reset global state if modified

## Writing New Tests

### Test File Template

```julia
using Test
using Globtim

@testset "Feature Name Tests" begin
    @testset "Basic functionality" begin
        # Test basic usage
    end
    
    @testset "Edge cases" begin
        # Test boundary conditions
    end
    
    @testset "Error handling" begin
        # Test error conditions
    end
end
```

### Adding to Test Suite

1. Create test file: `test/test_new_feature.jl`
2. Add to `runtests.jl`:
   ```julia
   include("test_new_feature.jl")
   ```
3. Document in `test_documentation.md`

## Environment Variables

### Parallel Testing
```bash
JULIA_NUM_THREADS=4 julia --project test/runtests.jl
```

### Verbose Output
```bash
JULIA_DEBUG=all julia --project test/runtests.jl
```

### Custom Test Selection
```julia
# In runtests.jl
if get(ENV, "TEST_ANISOTROPIC", "false") == "true"
    include("test_anisotropic_grids.jl")
end
```

## Troubleshooting Checklist

- [ ] Using `--project` flag?
- [ ] In correct directory?
- [ ] Dependencies installed? (`Pkg.instantiate()`)
- [ ] Julia version compatible?
- [ ] Package versions match Project.toml?
- [ ] No conflicting global packages?
- [ ] Clean git working directory?
- [ ] Test files have correct includes?

## Summary

Running tests effectively requires:
1. Correct environment setup (`--project`)
2. Understanding test organization
3. Knowing when to run which tests
4. Debugging skills for failures
5. Integration with development workflow

Regular testing ensures code quality and catches regressions early.