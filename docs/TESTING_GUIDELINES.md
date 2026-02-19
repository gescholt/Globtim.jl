# Globtim Testing Guidelines

## Running Tests

### Local Development Testing

**IMPORTANT**: Always use the local development version for testing, not the registered package.

```bash
# Correct way to run tests with local code
julia --project=. test/runtests.jl

# Or using Pkg.test() (after fixes below)
julia --project=.
julia> using Pkg
julia> Pkg.test()
```

### Common Testing Issues and Solutions

#### Issue 1: Pkg.test() Uses Old Registered Version

**Symptom**: Tests fail with errors like "no method matching Constructor" even though the method exists in your local code.

**Cause**: test/Project.toml contains Globtim as a dependency, causing Julia to fetch from registry instead of using local code.

**Solution**:
1. Remove Globtim from test/Project.toml dependencies
2. Delete test/Manifest.toml to force regeneration
3. Clear cached packages:
   ```bash
   rm -rf ~/.julia/packages/Globtim
   rm -rf ~/.julia/compiled/v1.11/Globtim
   ```

#### Issue 2: Conda Environment Interference

**Symptom**: Precompilation errors with LinearSolve, Sparspak, or other packages with binary dependencies.

**Cause**: Conda's binary libraries (BLAS, LAPACK, MKL) conflict with Julia's package binaries.

**Solution**:
```bash
# Use the provided aliases (in .zshrc and .bash_profile)
julia-clean  # Runs Julia without conda
julia-globtim  # Runs Julia with Globtim project, no conda

# Or use the start_julia.sh script
./start_julia.sh
```

#### Issue 3: Test Syntax Errors

**Symptom**: "invalid test macro call" errors.

**Cause**: Julia's @test macro doesn't support inline string messages.

**Wrong**:
```julia
@test condition "This will fail"
```

**Correct**:
```julia
@test condition
# Add comment above if explanation needed
```

## Test Organization

### Main Test Files

- `test/runtests.jl` - Main test entry point
- `test/test_aqua.jl` - Code quality checks using Aqua.jl
- `test/Project.toml` - Test-specific dependencies (DO NOT include Globtim here!)

### Test Categories

1. **Core Functionality Tests**
   - Polynomial system solving
   - ForwardDiff integration
   - Function value analysis
   - Benchmark functions

2. **Code Quality Tests (Aqua.jl)**
   - Method ambiguities
   - Undefined exports
   - Unbound type parameters
   - Persistent tasks
   - Dependency hygiene

3. **HPC-Specific Tests**
   - Located in test/test_hpc_*.jl files
   - Test cluster compatibility
   - Performance benchmarks

## Writing New Tests

### Best Practices

1. **Use @testset for Organization**:
   ```julia
   @testset "Feature Name" begin
       @test function_works()
       @test another_test()
   end
   ```

2. **Avoid Hardcoded Paths**:
   ```julia
   # Bad
   file = "/Users/username/globtim/data.csv"
   
   # Good
   file = joinpath(@__DIR__, "..", "data", "data.csv")
   ```

3. **Handle Optional Dependencies**:
   ```julia
   try
       using OptionalPackage
       @testset "Optional Feature" begin
           # tests using OptionalPackage
       end
   catch
       @warn "OptionalPackage not available, skipping tests"
   end
   ```

4. **Clean Up After Tests**:
   ```julia
   # Create temporary files in temp directory
   mktempdir() do tmpdir
       test_file = joinpath(tmpdir, "test.txt")
       # ... do tests ...
   end  # tmpdir automatically cleaned up
   ```

## Continuous Integration

### CI Configuration

Tests should be run in CI with:
```yaml
- julia --project=. -e "using Pkg; Pkg.instantiate()"
- julia --project=. test/runtests.jl
```

### Known Test Failures

As of September 2, 2025, the following Aqua.jl tests are known to fail (non-critical):

1. **Undefined Exports** - Valley-related functions need implementation
2. **Stale Dependencies** - Aqua should be moved to test dependencies
3. **Export Count** - Consider reducing number of exports (currently 258)

These are code quality issues that don't affect functionality but should be addressed for better maintainability.

## Environment Variables

### Julia-Specific

```bash
export JULIA_PROJECT=@.  # Always use local project
export JULIA_NUM_THREADS=4  # For parallel tests
```

### Avoiding Conflicts

```bash
# Temporarily disable conda
unset CONDA_DEFAULT_ENV
unset CONDA_PREFIX
```