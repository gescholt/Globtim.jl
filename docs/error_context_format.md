# Enhanced Error Context Format

**Version**: 1.3.0
**Date**: 2025-11-16
**Module**: `StandardExperiment`

---

## Overview

Starting with Schema v1.3.0, globtimcore captures **rich error context** when experiments fail. Instead of simple error messages, failures now include comprehensive diagnostic information for post-processing analysis.

**Key Principle**: globtimcore faithfully captures and exports error data. Analysis and categorization happens in `globtimpostprocessing`.

---

## Error Context Structure

When an experiment fails at degree `d`, the `DegreeResult.error` field contains a `Dict{String, Any}` with the following structure:

```julia
error_context = Dict{String, Any}(
    # Error Information
    "error_message" => "Full error message text",
    "error_type" => "ErrorException",  # Julia exception type
    "stacktrace" => ["frame1", "frame2", ...],  # Stack frames as strings

    # Experiment Context
    "degree" => 8,  # Polynomial degree that failed
    "dimension" => 4,  # Problem dimension
    "GN" => 16,  # Grid sample count
    "basis" => "chebyshev",  # Polynomial basis

    # Timing Information
    "timestamp" => "2025-11-16 12:34:56",  # When error occurred
    "computation_time" => 45.2  # Seconds before failure
)
```

---

## Field Specifications

### Error Information Fields

#### `error_message` (String)
- **Description**: Full text of the Julia exception
- **Example**: `"DimensionMismatch: arrays could not be broadcast to a common size"`
- **Usage**: Primary diagnostic message for debugging

#### `error_type` (String)
- **Description**: Julia exception type name
- **Example**: `"DimensionMismatch"`, `"ErrorException"`, `"SingularException"`
- **Usage**: Categorizing errors by type for pattern analysis

#### `stacktrace` (Vector{String})
- **Description**: Stack trace frames showing call sequence
- **Example**: `["frame 1", "frame 2", "frame 3"]`
- **Usage**: Detailed debugging and root cause analysis
- **Note**: Each frame is converted to string for JSON serialization

### Experiment Context Fields

#### `degree` (Int)
- **Description**: Polynomial degree at which failure occurred
- **Example**: `8`
- **Usage**: Identifying degree-dependent failure patterns

#### `dimension` (Int)
- **Description**: Problem dimension
- **Example**: `4`
- **Usage**: Analyzing dimension-scaling issues

#### `GN` (Int)
- **Description**: Grid sample count (per dimension)
- **Example**: `16`
- **Usage**: Identifying sampling-related failures

#### `basis` (String)
- **Description**: Polynomial basis used
- **Example**: `"chebyshev"`, `"legendre"`
- **Usage**: Basis-specific error analysis

### Timing Fields

#### `timestamp` (String)
- **Description**: Timestamp when error occurred
- **Format**: `"yyyy-mm-dd HH:MM:SS"`
- **Example**: `"2025-11-16 14:23:45"`
- **Usage**: Temporal analysis of failures

#### `computation_time` (Float64)
- **Description**: Computation time before failure (seconds)
- **Example**: `45.2`
- **Usage**: Identifying timeout vs immediate failures

---

## JSON Export Format

Error context is automatically serialized to `results_summary.json`:

```json
{
  "degree_4": {
    "status": "failed",
    "error": {
      "error_message": "HomotopyContinuation failed to converge",
      "error_type": "ConvergenceError",
      "stacktrace": ["...", "..."],
      "degree": 4,
      "dimension": 3,
      "GN": 8,
      "basis": "chebyshev",
      "timestamp": "2025-11-16 12:00:00",
      "computation_time": 120.5
    }
  }
}
```

### NaN/Inf Sanitization

- `NaN` and `Inf` values in numeric fields are automatically converted to `null` in JSON
- This ensures valid JSON output
- Applies to `computation_time` and other numeric fields

---

## Backward Compatibility

The `DegreeResult.error` field supports three types:

1. **`Nothing`**: Success case (no error)
2. **`String`**: Legacy error format (backward compatible)
3. **`Dict{String, Any}`**: New rich context format

Old code expecting `String` errors will continue to work. New code can detect Dict errors and extract rich context.

---

## Usage in globtimpostprocessing

The error context is designed for analysis in `globtimpostprocessing`:

```julia
using Globtim
using JSON3

# Load experiment results
results = JSON3.read("results_summary.json", Dict{String, Any})

# Extract error context
for (degree_key, degree_data) in results
    if degree_data["status"] == "failed"
        error_ctx = degree_data["error"]

        if error_ctx isa Dict
            # Rich error context available
            println("Degree $(error_ctx["degree"]) failed:")
            println("  Type: $(error_ctx["error_type"])")
            println("  Message: $(error_ctx["error_message"])")
            println("  After $(error_ctx["computation_time"])s")

            # Pattern matching for categorization
            if occursin("Convergence", error_ctx["error_type"])
                # Convergence failure - suggest parameter adjustments
            elseif occursin("Dimension", error_ctx["error_message"])
                # Dimension mismatch - configuration error
            end
        else
            # Legacy string error
            println("Error: $error_ctx")
        end
    end
end
```

---

## Error Categorization (globtimpostprocessing)

Error context enables intelligent categorization in `globtimpostprocessing`:

### Pattern Matching Examples

**Interface Bugs:**
```julia
if occursin(r"type.*has no field"i, error_ctx["error_message"])
    category = :INTERFACE_BUG
    severity = :HIGH
end
```

**Mathematical Failures:**
```julia
if occursin(r"HomotopyContinuation.*failed.*converge"i, error_ctx["error_message"])
    category = :MATHEMATICAL_FAILURE
    severity = :MEDIUM
    # Context-aware: high degree → higher severity
    if error_ctx["degree"] > 6
        severity = :HIGH
    end
end
```

**Configuration Errors:**
```julia
if error_ctx["error_type"] == "DimensionMismatch"
    category = :CONFIGURATION_ERROR
    severity = :HIGH
end
```

### Context-Enhanced Analysis

The rich context enables sophisticated analysis:

```julia
# Degree-dependent failures
high_degree_failures = filter(e -> e["degree"] >= 8, all_errors)

# Time-based clustering (fast failures vs slow failures)
immediate_failures = filter(e -> e["computation_time"] < 1.0, all_errors)
timeout_failures = filter(e -> e["computation_time"] > 60.0, all_errors)

# Dimension-scaling analysis
failures_by_dimension = groupby(all_errors, "dimension")
```

---

## Design Rationale

### Why Rich Context?

**Problem**: Simple error messages lack context for systematic analysis
```json
{"error": "DimensionMismatch"}  // Which degree? What dimension?
```

**Solution**: Comprehensive context enables pattern analysis
```json
{
  "error": {
    "error_message": "DimensionMismatch",
    "degree": 8,
    "dimension": 4,
    "GN": 16,
    ...
  }
}
```

### Why NOT Categorization in globtimcore?

**Separation of Concerns:**
- ✅ **globtimcore**: Capture and export raw data
- ✅ **globtimpostprocessing**: Analyze and categorize

**Benefits:**
1. **Lightweight core**: No analysis logic in time-critical experiments
2. **Flexible analysis**: Change categorization without touching core
3. **No coupling**: Core doesn't depend on analysis logic
4. **Easier testing**: Test execution and analysis independently
5. **HPC-friendly**: Core remains minimal for cluster deployments

---

## Migration Guide

### For Experiment Scripts

**No changes required!** Enhanced error capture is automatic.

Existing code:
```julia
result = run_standard_experiment(...)
# Errors automatically capture rich context
```

### For Analysis Scripts

**Update to handle Dict errors:**

```julia
# Old code (still works)
if haskey(result, "error")
    println("Error: $(result["error"])")
end

# New code (use rich context)
if haskey(result, "error") && result["error"] isa Dict
    error_ctx = result["error"]
    println("Error at degree $(error_ctx["degree"]): $(error_ctx["error_message"])")
end
```

---

## Testing

Test file: `test/test_enhanced_error_handling.jl`

**Run tests:**
```bash
julia --project=. test/test_enhanced_error_handling.jl
```

**Test coverage:**
- ✅ Error context structure validation
- ✅ JSON serialization/deserialization
- ✅ NaN/Inf sanitization
- ✅ Backward compatibility with string errors

---

## Future Enhancements

Potential additions to error context (without breaking changes):

```julia
# Additional diagnostic fields (future)
"memory_usage_mb" => 1024.5,  # Memory at failure
"previous_degrees_status" => ["success", "success", "failed"],  # History
"optimization_stage" => "refinement",  # Where in pipeline
"environment" => "HPC_cluster_r04n02"  # Execution environment
```

These can be added incrementally as `Dict{String, Any}` is extensible.

---

## Related Documentation

- **Error Analysis**: See `globtimpostprocessing/docs/error_categorization.md`
- **Schema Spec**: See `docs/schema_v1.3.0.md`
- **StandardExperiment**: See `src/StandardExperiment.jl` docstrings
- **Testing**: See `test/test_enhanced_error_handling.jl`

---

## Contact

For questions about error context:
- Review `StandardExperiment.jl` error capture logic (lines 219-249)
- Check `test_enhanced_error_handling.jl` for examples
- Consult `globtimpostprocessing` for analysis workflows

---

**Version History:**
- **v1.3.0** (2025-11-16): Initial rich error context implementation
