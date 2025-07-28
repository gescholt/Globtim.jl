# Aqua.jl Integration Guide for Globtim.jl

This guide explains how to use Aqua.jl for automated quality assurance in the Globtim.jl package.

## 🎯 What is Aqua.jl?

Aqua.jl is an automated quality assurance tool for Julia packages that checks for:
- **Method ambiguities** - Conflicting method definitions
- **Undefined exports** - Exported symbols that don't exist
- **Unbound type parameters** - Unused type parameters in function signatures
- **Persistent tasks** - Background tasks that might not be cleaned up
- **Project structure** - Proper Project.toml formatting
- **Dependency hygiene** - Unused or problematic dependencies

## 🚀 Local Testing Setup

### Step 1: Install Dependencies

The Aqua.jl dependency is already included in `test/Project.toml`. To set up your environment:

```bash
# Navigate to your Globtim.jl directory
cd /path/to/globtim

# Activate the test environment
julia --project=test -e "using Pkg; Pkg.instantiate()"
```

### Step 2: Run Aqua Tests Locally

#### Option A: Run via Test Suite
```bash
# Run all tests including Aqua
julia --project=test -e "using Pkg; Pkg.test()"

# Run only Aqua tests
julia --project=test test/test_aqua.jl
```

#### Option B: Use Standalone Script
```bash
# Basic run
julia scripts/run-aqua-tests.jl

# Verbose output with fix suggestions
julia scripts/run-aqua-tests.jl --verbose --fix-issues

# CI mode (exits with error code on failure)
julia scripts/run-aqua-tests.jl --ci
```

#### Option C: Interactive Testing
```julia
# Start Julia in test environment
julia --project=test

# Load the package and run tests
using Globtim
include("test/test_aqua.jl")

# Or run the verbose helper function
run_aqua_tests_verbose()
```

## 📋 Implementation Plan

### Phase 1: Initial Setup ✅
- [x] Add Aqua.jl to test dependencies
- [x] Create comprehensive test file (`test/test_aqua.jl`)
- [x] Add configuration system (`test/aqua_config.jl`)
- [x] Create standalone testing script (`scripts/run-aqua-tests.jl`)
- [x] Integrate with main test suite

### Phase 2: Local Testing & Fixes
1. **Run initial tests** to identify current issues
2. **Fix critical issues** (undefined exports, unbound args)
3. **Address method ambiguities** if any exist
4. **Clean up project structure** issues
5. **Optimize dependency list**

### Phase 3: CI/CD Integration
1. **Add to GitLab CI pipeline**
2. **Configure failure thresholds**
3. **Set up quality gates**
4. **Add performance monitoring**

### Phase 4: Maintenance & Monitoring
1. **Regular quality reviews**
2. **Update exclusion lists as needed**
3. **Monitor for regressions**
4. **Continuous improvement**

## 🔧 Configuration

### Environment Variables
```bash
# Skip Aqua tests entirely
export SKIP_AQUA_TESTS=true

# Enable verbose output
export AQUA_VERBOSE=true

# CI mode (stricter checking)
export CI=true
```

### Configuration File
Edit `test/aqua_config.jl` to customize:

```julia
const AQUA_CONFIG = (
    # Exclude specific method ambiguities
    ambiguity_exclusions = [
        # Base.show  # Example exclusion
    ],
    
    # Skip entire test categories
    skip_tests = [
        # :test_ambiguities  # Example skip
    ],
    
    # Strictness settings
    strict_mode = false,  # Set true for CI
    deps_compat_check = true,
    stale_deps_check = true
)
```

## 🐛 Common Issues & Solutions

### Method Ambiguities
**Problem**: Multiple method definitions conflict
**Solution**: 
- Add more specific type annotations
- Reorder method definitions (most specific first)
- Use `@nospecialize` for performance-critical generic methods

### Undefined Exports
**Problem**: Exported symbol doesn't exist
**Solution**:
- Remove incorrect export statements
- Add missing function/type definitions
- Check for typos in export names

### Unbound Type Parameters
**Problem**: Type parameter not used in function signature
**Solution**:
- Use the type parameter in the signature
- Remove unused type parameters
- Add appropriate type constraints

### Project Structure Issues
**Problem**: Project.toml formatting or dependency issues
**Solution**:
- Run `Pkg.resolve()` to update dependencies
- Remove unused dependencies
- Check version constraints

## 📊 Quality Metrics

The Aqua integration tracks several quality metrics:

- **Export Count**: Number of public API functions
- **Module Structure**: File organization and includes
- **Dependency Health**: Compatibility and staleness
- **Code Organization**: Modularization and complexity

## 🚀 Running Tests Locally

### Quick Start
```bash
# 1. Ensure you're in the Globtim.jl directory
cd /path/to/globtim

# 2. Run Aqua tests with verbose output
julia scripts/run-aqua-tests.jl --verbose

# 3. If issues are found, get fix suggestions
julia scripts/run-aqua-tests.jl --verbose --fix-issues
```

### Expected Output
```
🔍 Globtim.jl Code Quality Analysis with Aqua.jl
=======================================================

📋 Running core quality tests...
🔍 Testing Method Ambiguities... ✅ PASSED
🔍 Testing Undefined Exports... ✅ PASSED
🔍 Testing Unbound Args... ✅ PASSED
🔍 Testing Persistent Tasks... ✅ PASSED
🔍 Testing Project TOML... ✅ PASSED

📋 Running optional tests...
🔍 Testing Dependency Compatibility... ✅ PASSED
🔍 Testing Stale Dependencies... ✅ PASSED

📊 Test Results Summary:
------------------------------
Core tests:     5/5 passed
Optional tests: 2/2 passed

🎉 All core quality tests passed!

📦 Package Information:
  Name: Globtim
  Exports: 89
```

## 🔄 Continuous Integration

### GitLab CI Integration
The Aqua tests are integrated into the GitLab CI pipeline:

```yaml
# In .gitlab-ci.yml
aqua-quality-check:
  stage: test
  script:
    - julia scripts/run-aqua-tests.jl --ci
  allow_failure: false  # Fail pipeline on quality issues
```

### Quality Gates
- **Core tests must pass** for merge requests
- **Optional tests** provide warnings but don't block
- **Trend monitoring** tracks quality over time

## 📈 Next Steps

1. **Run initial assessment**: `julia scripts/run-aqua-tests.jl --verbose`
2. **Fix any critical issues** identified
3. **Add to CI pipeline** once stable
4. **Monitor quality trends** over time
5. **Refine configuration** based on experience

## 🆘 Troubleshooting

### Tests Won't Run
- Check Julia version (requires 1.6+)
- Verify test environment: `julia --project=test -e "using Aqua"`
- Check for missing dependencies

### False Positives
- Add exclusions to `test/aqua_config.jl`
- Use `--fix-issues` flag for suggestions
- Consult Aqua.jl documentation

### Performance Issues
- Run tests on smaller modules first
- Use `--ci` mode for faster execution
- Consider skipping expensive tests in development

For more help, see the [Aqua.jl documentation](https://github.com/JuliaTesting/Aqua.jl) or open an issue.
