# Experiment Input Configuration Schema

## Overview
Standardized JSON schema for Globtim experiment **input configurations**, defining how experiments are set up and executed. This schema enables HPC infrastructure separation by providing a stable contract between core and HPC tools.

## Schema Version
**Current Version:** 1.0.0
**Schema File:** `schemas/experiment_config_schema.json`
**Validation Module:** `src/ConfigValidation.jl`

## Version History

### Version 1.0.0 (2025-10-10)
- Initial formal schema definition
- Support for Lotka-Volterra and FitzHugh-Nagumo models
- Required fields: `model_config`, `numerical_params`, `domain_config`
- Optional tracking configuration for GitLab integration

## Root Structure

```json
{
  "model_config": { ... },
  "numerical_params": { ... },
  "domain_config": { ... },
  "tracking": { ... }  // optional
}
```

## Field Specifications

### Required Fields

#### `model_config` (object)
Defines the dynamical system model to use.

**Required subfields:**
- `name` (string): Model identifier
  - Allowed values: `"lotka_volterra_2d"`, `"lotka_volterra_4d"`, `"fitzhugh_nagumo"`
- `dimension` (integer): System dimensionality
  - Range: 1-10
  - Must match length of `true_parameters`
- `true_parameters` (array): True parameter values for the model
  - Type: Array of numbers
  - Length: Must equal `dimension`

**Example:**
```json
{
  "name": "lotka_volterra_4d",
  "dimension": 4,
  "true_parameters": [0.2, 0.3, 0.5, 0.6]
}
```

#### `numerical_params` (object)
Computational parameters for polynomial approximation.

**Required subfields:**
- `GN` (integer): Grid samples per dimension
  - Range: 4-20
  - Total grid points = GN^dimension
  - **Warning:** Large values can be computationally expensive
- `degree_range` (array): Polynomial degree range [min, max]
  - Type: Array of exactly 2 integers
  - Both values must be ≥ 1
  - min ≤ max

**Optional subfields:**
- `basis` (string): Polynomial basis type
  - Allowed values: `"chebyshev"`, `"monomial"`
  - Default: `"chebyshev"`
  - **Recommendation:** Use Chebyshev for better numerical stability
- `precision` (string): Numerical precision mode
  - Allowed values: `"Float64Precision"`, `"AdaptivePrecision"`
  - Default: `"Float64Precision"`

**Example:**
```json
{
  "GN": 16,
  "degree_range": [4, 12],
  "basis": "chebyshev",
  "precision": "Float64Precision"
}
```

#### `domain_config` (object)
Search domain configuration around equilibrium point.

**Required subfields:**
- `ranges` (array): Domain range values for each dimension
  - Type: Array of positive numbers
  - All values must be > 0
  - Length: Should match model dimension

**Optional subfields:**
- `center_offset_strategy` (string): How to offset domain center
  - Allowed values: `"none"`, `"random_sphere"`, `"fixed"`
  - Default: `"none"`
- `offset_magnitude` (number): Magnitude of center offset
  - Type: Non-negative number
  - Only used if `center_offset_strategy` is not `"none"`

**Example:**
```json
{
  "ranges": [0.4, 0.4, 0.4, 0.4],
  "center_offset_strategy": "random_sphere",
  "offset_magnitude": 0.05
}
```

### Optional Fields

#### `tracking` (object)
GitLab integration for experiment tracking.

**Optional subfields:**
- `gitlab_enabled` (boolean): Enable GitLab integration
- `campaign_name` (string): Name of experiment campaign
- `auto_create_issue` (boolean): Auto-create GitLab issue for this experiment

**Example:**
```json
{
  "gitlab_enabled": true,
  "campaign_name": "4D_LV_Parameter_Recovery",
  "auto_create_issue": true
}
```

## Validation Rules

### Schema Validation
1. All required top-level fields must be present (`model_config`, `numerical_params`, `domain_config`)
2. All required subfields must be present within each section
3. Field types must match schema definitions
4. Enumerated values must be from allowed sets
5. Numeric ranges must be within specified bounds

### Semantic Validation
1. **Dimension consistency**: `model_config.dimension` must equal `length(true_parameters)`
2. **Degree range**: `degree_range[0]` ≤ `degree_range[1]`
3. **Domain ranges**: All values in `ranges` must be positive
4. **Grid size warning**: If GN^dimension > 100,000, a warning is issued

### Validation Function

```julia
using Globtim.ConfigValidation

# Validate configuration dictionary
config = Dict(
    "model_config" => Dict(
        "name" => "lotka_volterra_4d",
        "dimension" => 4,
        "true_parameters" => [0.2, 0.3, 0.5, 0.6]
    ),
    "numerical_params" => Dict(
        "GN" => 16,
        "degree_range" => [4, 12]
    ),
    "domain_config" => Dict(
        "ranges" => [0.4, 0.4, 0.4, 0.4]
    )
)

result = validate_config_dict(config)
if !result.valid
    print_validation_errors(result)
end

# Or validate a JSON file
result = validate_config_file("config.json")
```

## Complete Examples

### Example 1: Minimal 4D Lotka-Volterra Configuration

```json
{
  "model_config": {
    "name": "lotka_volterra_4d",
    "dimension": 4,
    "true_parameters": [0.2, 0.3, 0.5, 0.6]
  },
  "numerical_params": {
    "GN": 16,
    "degree_range": [4, 12]
  },
  "domain_config": {
    "ranges": [0.4, 0.4, 0.4, 0.4]
  }
}
```

### Example 2: 2D Lotka-Volterra with Offset and Tracking

```json
{
  "model_config": {
    "name": "lotka_volterra_2d",
    "dimension": 2,
    "true_parameters": [1.2, 0.8]
  },
  "numerical_params": {
    "GN": 10,
    "degree_range": [3, 8],
    "basis": "chebyshev",
    "precision": "Float64Precision"
  },
  "domain_config": {
    "ranges": [0.5, 0.5],
    "center_offset_strategy": "random_sphere",
    "offset_magnitude": 0.1
  },
  "tracking": {
    "gitlab_enabled": true,
    "campaign_name": "2D_LV_Convergence_Study",
    "auto_create_issue": false
  }
}
```

### Example 3: FitzHugh-Nagumo with Adaptive Precision

```json
{
  "model_config": {
    "name": "fitzhugh_nagumo",
    "dimension": 2,
    "true_parameters": [0.7, 0.8]
  },
  "numerical_params": {
    "GN": 12,
    "degree_range": [5, 10],
    "basis": "chebyshev",
    "precision": "AdaptivePrecision"
  },
  "domain_config": {
    "ranges": [0.3, 0.3]
  }
}
```

## Interface Contract for HPC Separation

The experiment configuration schema defines the contract between core and HPC infrastructure:

### Core Package Exports
```julia
module Globtim

# Configuration validation
using .ConfigValidation
export ValidationError, ValidationResult
export validate_config_dict, validate_config_file
export print_validation_errors

end
```

### HPC Tools Import
```julia
using Globtim.ConfigValidation

# Load and validate configuration
config = JSON3.read(read("experiment_config.json", String))
result = validate_config_dict(Dict(pairs(config)))

if !result.valid
    print_validation_errors(result)
    error("Invalid configuration")
end

# Proceed with experiment setup...
```

## Schema Evolution Policy

### Version Numbering
- **MAJOR**: Breaking changes (remove required fields, change field types, change validation rules)
- **MINOR**: Add new optional fields, add new model types, deprecate fields
- **PATCH**: Documentation updates, clarifications, non-breaking validation improvements

### Backward Compatibility Guarantees
1. **Required fields**: Never remove required fields in minor/patch versions
2. **Field types**: Never change field types in minor/patch versions
3. **Validation**: Can make validation more permissive, but not more restrictive
4. **Optional fields**: Can be added freely in minor versions

### Deprecation Process
1. Mark field as deprecated in documentation (minor version)
2. Maintain support for 2 minor versions (validation warnings only)
3. Remove in next major version

### Adding New Model Types
New model types can be added in minor versions by:
1. Extending `model_config.name` enum in schema
2. Documenting model-specific parameter requirements
3. Adding validation rules for new model type
4. Providing example configurations

## Testing

Tests are located in `test/config_validation/` and cover:

1. **Schema validation**: All required fields, type checking, range validation
2. **Semantic validation**: Dimension consistency, degree ranges, grid size warnings
3. **Error messages**: Clear, actionable error messages
4. **Edge cases**: Empty arrays, negative numbers, out-of-range values
5. **Backward compatibility**: Handling legacy configurations gracefully

Run tests:
```julia
julia> using Pkg
julia> Pkg.test("Globtim", test_args=["config_validation"])
```

## References

- **Output schema documentation**: [EXPERIMENT_SCHEMA.md](EXPERIMENT_SCHEMA.md)
- **JSON Schema file**: [schemas/experiment_config_schema.json](schemas/experiment_config_schema.json)
- **Validation implementation**: [src/ConfigValidation.jl](src/ConfigValidation.jl)
- **Example configurations**: [Examples/configs/](Examples/configs/)
- **Repository separation analysis**: [REPOSITORY_SEPARATION_ANALYSIS.md](REPOSITORY_SEPARATION_ANALYSIS.md)
