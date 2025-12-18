# Issue #135: Enhanced Pre-Flight Validation for Column Name Mismatches

**Date**: 2025-10-06
**Related Issues**: #131-134 (all failed with `:val` column error)
**Status**: Planning

## Problem Statement

All experiments in issues #131-134 failed with identical error:
```
ArgumentError("column name :val not found in the data frame")
```

**Root Cause**:
- Experiment scripts reference `df_critical.val` (lines 167-169)
- `process_crit_pts()` returns DataFrame with column `:z` (not `:val`)
- Source: `src/ParsingOutputs.jl:57`

**Impact**:
- 4 experiments × 9 degrees = 36 failed test cases
- ~66 minutes of wasted computation time
- Detection happened post-execution, not pre-flight

## Current Pre-Flight Infrastructure

**File**: `tools/hpc/hooks/experiment_preflight_validator.sh`

**Existing Checks**:
1. ✓ CLI argument validation
2. ✓ Path validation (hardcoded paths, PROJECT_ROOT usage)
3. ✓ JSON config validation
4. ✓ Mathematical configuration (domain, GN values)
5. ✓ Package environment validation
6. ✓ Julia package validation

**Gap**: No DataFrame column name validation

## Proposed Solution

### 1. Add DataFrame Column Validation Check

**Location**: `tools/hpc/hooks/experiment_preflight_validator.sh`

**New Function**: `validate_dataframe_usage()`

**What to check**:
```bash
validate_dataframe_usage() {
    local experiment_script=$1

    # Check for references to df_critical columns
    # Common incorrect patterns:
    - df_critical.val      ❌ (should be .z)
    - df_critical.value    ❌ (should be .z)
    - df_critical.result   ❌ (should be .z)

    # Correct patterns:
    - df_critical.z        ✓
    - df_critical.x1       ✓
    - df_critical.x2       ✓

    # Strategy:
    1. Extract all df_critical.<column> references
    2. Check against known valid columns from process_crit_pts
    3. Flag any unknown columns as errors
}
```

### 2. Create Column Name Reference Documentation

**File**: `docs/reference/dataframe_columns.md`

Document all DataFrames returned by core functions:
- `process_crit_pts()` → columns: `:z`, `:x1`, `:x2`, ..., `:xN`
- Other functions that return DataFrames

### 3. Implement Static Analysis for Common Patterns

**Patterns to detect**:
```julia
# WRONG - Common mistakes
minimum(df_critical.val)      # ❌
maximum(df_critical.val)      # ❌
mean(df_critical.val)         # ❌

# CORRECT
minimum(df_critical.z)        # ✓
maximum(df_critical.z)        # ✓
mean(df_critical.z)           # ✓
```

### 4. Add Julia-Based Syntax Validation

**File**: `tools/hpc/validation/julia_syntax_validator.jl`

```julia
function validate_dataframe_columns(script_path::String)
    content = read(script_path, String)

    # Known valid columns from process_crit_pts
    valid_columns = [:z, :x1, :x2, :x3, :x4, :x5, :x6, :x7, :x8]

    # Pattern: df_critical.<column>
    pattern = r"df_critical\.(\w+)"

    errors = []
    for m in eachmatch(pattern, content)
        col = Symbol(m.captures[1])
        if col ∉ valid_columns
            push!(errors, (
                column = col,
                suggestion = "Did you mean :z?",
                line = find_line_number(content, m.offset)
            ))
        end
    end

    return errors
end
```

## Implementation Plan

### Phase 1: Quick Fix (Immediate)
1. ✅ Identify all scripts with `.val` reference
2. ⏳ Fix experiment scripts: change `.val` → `.z`
3. ⏳ Test fixes on one experiment
4. ⏳ Re-run all 4 experiments

### Phase 2: Enhanced Validation (Next)
1. ⏳ Add `validate_dataframe_usage()` to preflight validator
2. ⏳ Create `julia_syntax_validator.jl`
3. ⏳ Document DataFrame columns reference
4. ⏳ Test validation on existing scripts
5. ⏳ Integrate into HPC deployment workflow

### Phase 3: Prevention (Future)
1. ⏳ Add pre-commit hook for column validation
2. ⏳ Create test suite for common mistakes
3. ⏳ Add linting rules to CI/CD
4. ⏳ Update experiment template generator

## Validation Strategy

### Bash-Based Validation (Fast, No Julia Required)
```bash
# Check 1: Detect .val references
if grep -q "df_critical\.val" "$experiment_script"; then
    log_validation "ERROR" "DATAFRAME" \
        "Script uses df_critical.val - should be df_critical.z"
fi

# Check 2: Verify process_crit_pts usage
if grep -q "process_crit_pts" "$experiment_script"; then
    # Ensure they use .z not .val
    if ! grep -q "df_critical\.z" "$experiment_script"; then
        log_validation "WARNING" "DATAFRAME" \
            "Script calls process_crit_pts but doesn't reference .z column"
    fi
fi
```

### Julia-Based Validation (Comprehensive, Requires Julia)
```julia
# Parse AST and validate DataFrame column access
using JuliaSyntax

function validate_script_dataframes(path)
    # Parse Julia source
    # Extract DataFrame column references
    # Validate against known schemas
    # Return detailed errors with line numbers
end
```

## Test Cases

Create test scripts to verify validation catches errors:

```bash
# Test 1: Should FAIL validation
cat > test_bad.jl << 'EOF'
df = process_crit_pts(pts, f, TR)
min_val = minimum(df.val)  # ❌ Should be .z
EOF

# Test 2: Should PASS validation
cat > test_good.jl << 'EOF'
df = process_crit_pts(pts, f, TR)
min_val = minimum(df.z)    # ✓ Correct
EOF
```

## Expected Outcomes

1. **Pre-Flight Validation**:
   - Catches column name errors BEFORE deployment
   - Saves hours of wasted computation time
   - Provides clear error messages with fixes

2. **Developer Experience**:
   - Clear documentation of DataFrame schemas
   - Immediate feedback on common mistakes
   - Reduced debugging time

3. **Reliability**:
   - Prevents recurrence of this error class
   - Systematic validation of all experiments
   - Confidence in HPC deployments

## Metrics

- **Time Saved**: ~66 minutes per false start prevented
- **Error Detection**: Pre-deployment vs post-execution
- **Coverage**: 100% of experiment scripts validated

## Related Files

- `tools/hpc/hooks/experiment_preflight_validator.sh` - Main validator
- `src/ParsingOutputs.jl:24-58` - `process_crit_pts()` definition
- `experiments/lotka_volterra_4d_study/configs_20251005_105246/*.jl` - Affected scripts

## References

- Analysis output: `scripts/analysis/simple_lv4d_analysis.jl`
- Error pattern: Lines 167-169 in all exp*.jl files
- Column definition: `src/ParsingOutputs.jl:57`
