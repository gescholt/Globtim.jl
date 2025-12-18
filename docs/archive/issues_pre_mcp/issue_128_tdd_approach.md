# Issue #128: TDD Approach for Enhanced Statistics Collection

## Summary

This document describes the Test-Driven Development (TDD) approach taken for implementing enhanced statistics collection (Issue #128) using the DeJong 2D example as a test case.

## Test File

**Location**: `test/test_enhanced_metrics_dejong2d.jl`

**Status**: ✅ All 47 tests passing

## Test Structure

The test suite is organized into 6 main categories:

### 1. Test Setup - DeJong 2D (6 tests)
Tests the basic setup of a 2D DeJong function approximation:
- Dimensions and parameters verification
- Polynomial approximation construction
- Basis and degree validation

**Example**:
```julia
n, a, b = 2, 50, 1
scale_factor = a / b
f = dejong5
d = 12  # Smaller degree for faster testing
SMPL = 50  # Fewer samples for testing

TR = test_input(f, dim=n, center=[0.0, 0.0], GN=SMPL, sample_range=scale_factor)
pol_cheb = Constructor(TR, d, basis=:chebyshev, precision=RationalPrecision)
```

### 2. Reproducibility Metadata Collection (11 tests)

Tests collection of all metadata needed to reproduce experiments:

#### Git Commit Hash (3 tests)
- Validates git commit extraction
- Ensures valid hash format (40 hex characters) or "unknown"
- Tests error handling when not in git repository

```julia
function get_git_commit_hash()
    try
        return readchomp(`git rev-parse HEAD`)
    catch
        return "unknown"
    end
end
```

#### Julia Version (2 tests)
- Captures Julia version as `VersionNumber`
- Validates version is >= 1.0

#### Hostname (2 tests)
- Captures system hostname
- Validates non-empty string

#### Timestamp (2 tests)
- Captures execution timestamp as `DateTime`
- Validates timestamp is reasonable

#### Manifest Hash (2 tests)
- Computes SHA256 hash of `Manifest.toml`
- Enables detection of dependency changes

```julia
function hash_manifest_file()
    manifest_path = joinpath(dirname(dirname(pathof(Globtim))), "Manifest.toml")
    if isfile(manifest_path)
        return bytes2hex(sha256(read(manifest_path)))
    else
        return "no_manifest"
    end
end
```

### 3. Mathematical Quality Metrics (13 tests)

Tests metrics that assess polynomial approximation quality:

#### Polynomial Sparsity (tests)
Measures percentage of near-zero coefficients:

```julia
function compute_sparsity(coeffs, threshold=1e-12)
    total = length(coeffs)
    near_zero = count(abs(c) < threshold for c in coeffs)
    return 100.0 * near_zero / total
end
```

- Validates sparsity in range [0, 100]%
- Tests default threshold (1e-12)

#### Coefficient Statistics (tests)
Computes min, max, mean, std of coefficient magnitudes:

```julia
function analyze_coefficients(coeffs)
    return Dict(
        "min" => minimum(abs.(coeffs)),
        "max" => maximum(abs.(coeffs)),
        "mean" => mean(abs.(coeffs)),
        "std" => std(abs.(coeffs))
    )
end
```

- Validates all stats are non-negative
- Checks logical relationships (max >= min, etc.)

#### L2 Norm Extraction (tests)
- Tests correct field name (`nrm`, not `L2norm`)
- Validates non-negative norm
- Ensures Float64 type

**Key Finding**: The `ApproxPoly` struct uses field `nrm`, not `L2norm` as initially expected.

### 4. Convergence Analysis (6 tests)

Tests analysis of convergence behavior across multiple polynomial degrees:

#### Test Data Generation
Builds polynomials at degrees [4, 6, 8, 10, 12] and tracks L2 norms:

```julia
degrees = [4, 6, 8, 10, 12]
l2_norms = Float64[]

for d in degrees
    pol_conv = Constructor(TR3, d, basis=:chebyshev, precision=RationalPrecision)
    push!(l2_norms, pol_conv.nrm)
end
```

#### Convergence Rate Estimation
Estimates rate by averaging improvement ratios:

```julia
function estimate_convergence_rate(norms)
    if length(norms) < 3
        return nothing
    end
    improvements = [norms[i-1] / norms[i] for i in 2:length(norms)]
    return mean(improvements)
end
```

#### Stagnation Detection
Detects when improvements fall below threshold:

```julia
function detect_stagnation(norms, threshold=0.01)
    if length(norms) < 3
        return false
    end
    improvements = [(norms[i-1] - norms[i]) / norms[i-1] for i in 2:length(norms)]
    recent = improvements[max(1, end-2):end]
    return all(imp < threshold for imp in recent)
end
```

#### Optimal Degree Estimation
Finds degree where improvement drops below threshold:

```julia
function estimate_optimal_degree(norms, degrees, improvement_threshold=0.05)
    if length(norms) < 2
        return nothing
    end
    improvements = [(norms[i-1] - norms[i]) / norms[i-1] for i in 2:length(norms)]
    for (i, imp) in enumerate(improvements)
        if imp < improvement_threshold
            return degrees[i]
        end
    end
    return degrees[end]
end
```

#### Monotonicity Check
Validates L2 norm generally decreases with degree (with 10% tolerance for noise).

### 5. Resource Utilization Metrics (4 tests)

Tests measurement of computational resources:

#### Memory Measurement
```julia
function measure_memory_gb()
    gc_stats = Base.gc_num()
    return gc_stats.allocd / 1024^3  # Convert to GB
end
```

#### Execution Timing
- Measures elapsed time for polynomial construction
- Validates reasonable execution time (< 60 seconds for test case)

### 6. Integration - Full Enhanced Metrics (7 tests)

Tests complete integration with simplified metrics struct:

```julia
struct EnhancedMetrics
    git_commit::String
    julia_version::VersionNumber
    hostname::String
    timestamp::DateTime
    sparsity::Float64
    l2_norm::Float64
    convergence_rate::Union{Float64, Nothing}
    execution_time::Float64
end
```

Validates:
- All fields correctly populated
- Correct types for all fields
- Non-negative values where appropriate
- Successful end-to-end collection

## Key Insights from TDD

### API Discoveries

1. **Degree Field Structure**: `pol.degree` is a tuple `(:one_d_for_all, degree_value)`, not a simple integer
2. **L2 Norm Field Name**: The field is `nrm`, not `L2norm`
3. **Git Output Type**: `readchomp` returns `SubString{String}`, not `String` → use `isa AbstractString`

### Test Parameters

For fast TDD iteration with DeJong 2D:
- **Dimension**: 2
- **Grid samples**: 50 (instead of 200 in notebook)
- **Polynomial degree**: 6-12 (instead of 24 in notebook)
- **Sample range**: 50.0
- **Function**: `dejong5`

These parameters:
- Complete in ~2-3 seconds total
- Provide sufficient complexity for meaningful tests
- Exercise all code paths

### Test Execution Time

```
Test Summary:                    | Pass  Total  Time
Enhanced Metrics - DeJong 2D TDD |   47     47  2.2s
```

Fast execution enables rapid TDD iteration.

## Next Steps for Full Implementation

Based on this TDD foundation:

1. **Extend Structs**: Implement full structs from Issue #128:
   - `ReproducibilityMetadata`
   - `MathematicalQualityMetrics`
   - `ConvergenceMetrics`
   - `ResourceUtilization`
   - `ComparisonMetrics`

2. **Integrate with Experiment Runner**:
   - Modify `src/experiment_runner.jl` to collect metrics
   - Add metrics to experiment results output

3. **Add Baseline Comparison**:
   - Implement comparison against historical baselines
   - Add percentile ranking

4. **JSON Output Format**:
   - Extend JSON serialization
   - Update GitLab sync scripts

5. **Documentation**:
   - Document all new metrics
   - Update user guide

6. **Performance Testing**:
   - Test with larger experiments (high degree, dimension)
   - Measure overhead of metrics collection

## Test Coverage

### Covered Functionality ✅
- ✅ Git commit hash extraction
- ✅ Julia version capture
- ✅ Hostname capture
- ✅ Timestamp generation
- ✅ Manifest hash computation
- ✅ Polynomial sparsity calculation
- ✅ Coefficient statistics
- ✅ L2 norm extraction
- ✅ Convergence rate estimation
- ✅ Stagnation detection
- ✅ Optimal degree estimation
- ✅ Memory measurement
- ✅ Execution timing
- ✅ End-to-end integration

### Not Yet Covered ⏳
- ⏳ CPU utilization monitoring
- ⏳ Disk I/O measurement
- ⏳ Baseline comparison
- ⏳ Historical trend analysis
- ⏳ GitLab issue integration
- ⏳ Batch/campaign tracking

## Running the Tests

```bash
cd /Users/ghscholt/GlobalOptim/globtimcore
julia --project=. test/test_enhanced_metrics_dejong2d.jl
```

Expected output:
```
Test Summary:                    | Pass  Total  Time
Enhanced Metrics - DeJong 2D TDD |   47     47  2.2s
```

## Benefits of This TDD Approach

1. **Fast Feedback Loop**: Tests complete in ~2 seconds
2. **API Validation**: Discovered correct field names and types early
3. **Concrete Examples**: DeJong 2D provides realistic test case
4. **Regression Prevention**: Tests lock in correct behavior
5. **Documentation**: Tests serve as executable examples
6. **Incremental Development**: Can implement features one at a time
7. **Confidence**: All core functionality proven to work

## References

- Issue #128: Enhanced Statistics Collection for Experiment Reproducibility and Analysis
- DeJong notebook: `Examples/Notebooks/DeJong.ipynb`
- Test file: `test/test_enhanced_metrics_dejong2d.jl`
- Structures: `src/Structures.jl`
