# Fix Sparsification Test Failures Due to Internal API Changes

## Summary

The sparsification test suite in `test/test_sparsification.jl` was failing with 5 `UndefVarError` exceptions because recently internalized functions were no longer exported from the Globtim module. These functions were made internal as part of API streamlining in commit `8906736` but the test file was not updated accordingly.

**Status:** ✅ **RESOLVED** in commit `5bb6e2f` - All 51 tests now passing  
**Test Status:** 51 passed, 0 failed (previously 16 passed, 5 errored out of 21 total tests)

## Affected Functions

The following functions are causing `UndefVarError` in the test suite:

1. **`analyze_sparsification_tradeoff`** (Line 78)
   - Used in "Sparsification tradeoff analysis" test set
   - Analyzes sparsification performance across multiple threshold values

2. **`compute_l2_norm_vandermonde`** (Line 98, 117)
   - Used in "Vandermonde L2 norm computation" and "L2 norm with modified coefficients" test sets
   - Computes L2 norm using Vandermonde matrix approach

3. **`compute_l2_norm_coeffs`** (Line 116)
   - Used in "L2 norm with modified coefficients" test set
   - Computes L2 norm with custom coefficient vectors

4. **`analyze_approximation_error_tradeoff`** (Line 148)
   - Used in "Approximation error tradeoff" test set
   - Analyzes approximation error across sparsification thresholds

5. **`compute_approximation_error`** (Line 129, 137)
   - Used in "Approximation error analysis" test set
   - Computes approximation error between function and polynomial

## Root Cause

**API Streamlining Changes (Commit 8906736):**
- Functions were moved to internal-only status to clean up the public API
- Export statements were commented out in `/src/Globtim.jl` (lines 148-150):
  ```julia
  # export compute_l2_norm_vandermonde, compute_l2_norm_coeffs
  # export compute_approximation_error,
  #     analyze_sparsification_tradeoff, analyze_approximation_error_tradeoff
  ```
- Functions still exist in `/src/advanced_l2_analysis.jl` but are no longer accessible in test namespace

## Error Details

**Typical Error Pattern:**
```
UndefVarError: `analyze_sparsification_tradeoff` not defined in `Main`
Suggestion: check for spelling errors or missing imports.
```

**Test Execution Output:**
```
Test Summary:                        | Pass  Error  Total  Time
Polynomial Sparsification            |   16      5     21  3.0s
  Basic sparsification               |    8             8  0.3s
  Absolute threshold sparsification  |    5             5  0.1s
  Preserve indices functionality     |    3             3  0.2s
  Sparsification tradeoff analysis   |           1      1  1.9s
  Vandermonde L2 norm computation    |           1      1  0.1s
  L2 norm with modified coefficients |           1      1  0.2s
  Approximation error analysis       |           1      1  0.1s
  Approximation error tradeoff       |           1      1  0.1s
```

## Solution Implemented

### ✅ Option 1: Update Tests to Use Qualified Names
- Changed all function calls from unqualified to qualified names (e.g., `analyze_sparsification_tradeoff(...)` to `Globtim.analyze_sparsification_tradeoff(...)`)
- Maintains internal API status while allowing comprehensive testing
- Preserves current API design decisions
- **Implementation Commit:** `5bb6e2f`

### Option 2: Temporarily Re-export Functions for Testing
- Add test-specific exports or create test utilities module
- More complex implementation but maintains clean public API separation

### Option 3: Create Test-Specific Wrapper Functions
- Create wrapper functions in test utilities that call internal functions
- Allows for test-specific adaptations and parameter handling

## Implementation Tasks

1. **Update Function Calls in Test File**
   - Replace 5 unqualified function calls with `Globtim.` prefix
   - Verify all function signatures and parameters remain compatible

2. **Validate Test Functionality**
   - Ensure all existing test logic remains valid
   - Verify that internal function behavior matches test expectations

3. **Update Test Documentation**
   - Add comments explaining use of internal functions in tests
   - Document rationale for testing internal API components

## Acceptance Criteria

- [x] All sparsification tests pass successfully (51 tests passing)
- [x] No `UndefVarError` exceptions during test execution
- [x] Test suite maintains comprehensive coverage of sparsification functionality
- [x] Internal API functions remain unexported in main module
- [x] Test execution time remains comparable (4.1 seconds < 5 seconds target)
- [x] All existing test assertions and validation logic preserved

## Files Modified

- ✅ `/test/test_sparsification.jl` - Updated function calls to use qualified names (commit `5bb6e2f`)

## Related Issues/Commits

- **Commit 8906736:** "fix: Resolve all Aqua.jl quality check failures" - API streamlining changes
- **Related to:** Aqua.jl quality improvements and export cleanup efforts

## Labels

- `bug` - Test failures preventing successful test suite execution
- `testing` - Test suite maintenance and fixes
- `api` - Related to API design and internal function access
- `medium-priority` - Affects test suite but not end-user functionality

## Estimated Effort

**Low complexity:** ~1-2 hours
- Simple find-and-replace operation for function call prefixes
- Straightforward testing and validation

---

*This issue was generated automatically based on test failure analysis and API change documentation.*