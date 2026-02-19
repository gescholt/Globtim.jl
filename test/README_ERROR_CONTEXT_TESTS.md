# Error Context Tests Documentation

**Schema Version**: v1.3.0
**Created**: 2025-11-16

## Test Files

### 1. `error_context_unit.jl` (Unit Tests)
**Purpose**: Fast unit tests for type safety and JSON serialization

**Test Coverage**:
- ✅ **DegreeResult Type Variants**
  - Tests `error::Union{String, Dict{String,Any}, Nothing}`
  - Verifies success case (error = nothing)
  - Verifies legacy string errors (backward compatibility)
  - Verifies new Dict error context

- ✅ **Error Context Structure**
  - Validates all required fields present
  - Checks field types (String, Int, Vector, etc.)
  - Ensures timestamp format correct

- ✅ **JSON Serialization**
  - Tests string error serialization
  - Tests Dict error serialization
  - Verifies round-trip (serialize → parse → verify)

- ✅ **NaN/Inf Sanitization**
  - Verifies NaN/Inf → null conversion
  - Tests both in metrics and error context
  - Ensures valid JSON output

**Runtime**: ~1 second (no experiments, pure type checking)

### 2. `error_context_integration.jl` (Integration Tests)
**Purpose**: End-to-end testing with actual experiment failures

**Test Coverage**:
- ✅ **Live Error Capture**
  - Runs experiment with deliberately failing objective
  - Verifies error context captured correctly
  - Checks all context fields populated

- ✅ **Stacktrace Capture**
  - Verifies stacktrace is captured
  - Checks stacktrace is serializable
  - Validates stacktrace depth

- ✅ **Experiment Context**
  - Verifies degree, dimension, GN captured
  - Checks basis string conversion
  - Validates timestamp format

- ✅ **results_summary.json Export**
  - Tests full export pipeline
  - Verifies JSON file creation
  - Validates file contents parseable

**Runtime**: ~5-10 seconds (runs small experiments)

## Running Tests

### Run All Tests
```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

### Run Only Error Context Tests
```bash
julia --project=. test/error_context_unit.jl
julia --project=. test/error_context_integration.jl
```

### Quick Syntax Check
```bash
julia --project=. -e 'using Globtim.StandardExperiment; println("✓ Syntax OK")'
```

## Test Requirements

**Dependencies** (all in Project.toml):
- `Test` (stdlib)
- `JSON3`
- `Dates` (stdlib)
- `DataFrames`
- `CSV`

**No additional dependencies required** - tests use existing project deps.

## Expected Test Output

### Success Output (error_context_unit.jl)
```
Test Summary:                          | Pass  Total  Time
Error Context Unit Tests               |   25     25  0.8s
  DegreeResult Type - Error Field Va.. |    8      8  0.2s
  Error Context Structure Validation   |    9      9  0.1s
  JSON Serialization - Error Variants  |    4      4  0.3s
  NaN/Inf Sanitization in Error Cont.. |    4      4  0.1s
  Error Context Round-Trip             |    6      6  0.1s

✅ All error context unit tests passed!
```

### Success Output (error_context_integration.jl)
```
Test Summary:                          | Pass  Total  Time
Enhanced Error Context Capture         |   15     15  7.2s
  Error Context Structure              |    9      9  3.5s
  JSON Serialization of Error Context  |    3      3  2.1s
  Backward Compatibility with String.. |    3      3  1.6s

✅ All enhanced error handling tests passed!
```

## Test Failures and Debugging

### Common Issues

**1. Type mismatch in error field**
```julia
# ERROR: MethodError: no method matching DegreeResult(..., error::Vector)
# FIX: Ensure error is String, Dict{String,Any}, or Nothing
```

**2. Missing required fields in error context**
```julia
# ERROR: KeyError: key "degree" not found
# FIX: Ensure all 9 required fields present in error_context Dict
```

**3. JSON serialization fails**
```julia
# ERROR: JSON3.StructuralError: invalid JSON
# FIX: Check for non-serializable types (functions, complex objects)
```

### Debugging Commands

**Check DegreeResult type**:
```julia
julia> fieldnames(Globtim.StandardExperiment.DegreeResult)
# Should include: degree, status, ..., error
```

**Inspect error field type**:
```julia
julia> fieldtype(Globtim.StandardExperiment.DegreeResult, :error)
# Should be: Union{Nothing, String, Dict{String, Any}}
```

**Test JSON serialization manually**:
```julia
using JSON3
error_ctx = Dict("error_message" => "test", "degree" => 4)
JSON3.write(error_ctx)  # Should succeed
```

## Integration with CI/CD

### GitHub Actions
```yaml
- name: Run Error Context Tests
  run: |
    julia --project=. -e 'using Pkg; Pkg.test()'
```

### Alternative: Run Individual Test Files
```bash
julia --project=. test/error_context_unit.jl
julia --project=. test/error_context_integration.jl
```

## Test Maintenance

**When to update tests**:
1. Adding new fields to error context → Update structure validation
2. Changing error field type → Update type variant tests
3. Modifying JSON export → Update serialization tests
4. Adding new error categories → Update integration tests

**Backward compatibility checks**:
- Always test that String errors still work
- Verify old results_summary.json files still parse
- Ensure gradual migration path exists

## Related Documentation

- **Error Context Spec**: `docs/error_context_format.md`
- **StandardExperiment**: `src/StandardExperiment.jl`
- **Schema History**: `docs/schema_versions.md` (if exists)

## Version History

- **v1.3.0** (2025-11-16): Initial error context tests
  - Unit tests for type safety
  - Integration tests for live capture
  - JSON serialization validation
