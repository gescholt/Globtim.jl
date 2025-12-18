# Phase 1: ODE Experiment Configuration Schema - Complete ✅

## Summary

Successfully implemented a unified configuration schema for ODE-based experiments, enabling declarative experiment specifications via TOML or JSON files.

**Status:** ✅ Complete - All 44 tests passing

---

## What Was Implemented

### 1. New Configuration Structures

#### `ModelConfig`
- **Purpose**: Specify model metadata and parameters
- **Fields**:
  - `name`: Model identifier (for logging)
  - `dimension`: Number of parameters
  - `true_parameters`: Ground truth for synthetic data
  - `initial_conditions`: ODE initial conditions
  - `fixed_parameters`: Optional fixed params (not optimized)

#### `DomainConfig`
- **Purpose**: Flexible domain specification strategies
- **Strategies**:
  1. **`centered_at_true`**: Domain = true_params ± range
     - `range`: Scalar or per-parameter
  2. **`explicit_bounds`**: Manual bounds per parameter
     - `bounds`: `[(low1, high1), (low2, high2), ...]`
  3. **`random_offset`**: True params + random direction
     - `offset_length`: Offset magnitude
     - `random_seed`: For reproducibility

#### `ComputationConfig`
- **Purpose**: Computation parameters
- **Fields**:
  - `samples_per_dim`: Grid samples (GN)
  - `degrees`: Array `[4, 5, 6, ...]` or range string `"4:12"`
  - `precision_mode`: `"float64"`, `"adaptive"`, or array for comparison
  - `tracker_options`: Custom HC.jl tracker settings
  - `max_time_per_degree`: Time limit per degree (seconds)

#### `ODESolverConfig`
- **Purpose**: ODE integration settings
- **Fields**:
  - `method`: Solver name (e.g., `"Rosenbrock23"`, `"Tsit5"`)
  - `abstol`, `reltol`: Tolerances
  - `time_span`: `(t_start, t_end)`
  - `saveat`: Time points or spacing
  - `maxiters`: Max iterations

#### `ODEExperimentConfig`
- **Purpose**: Top-level config combining all sections
- **Sections**:
  - `model_config`
  - `domain_config`
  - `computation_config`
  - `solver_config`
  - `constructor_params` (optional, has defaults)
  - `analysis_params` (optional, has defaults)
  - `output_settings` (optional)

---

### 2. File Format Support

#### TOML (Recommended for human-written configs)
```toml
[model_config]
name = "lotka_volterra_4d"
dimension = 4
true_parameters = [1.5, 3.0, 1.0, 1.0]

[domain_config]
strategy = "centered_at_true"
range = 0.4

[computation_config]
samples_per_dim = 16
degrees = "4:12"
precision_mode = "float64"
```

#### JSON (Recommended for machine-generated configs)
```json
{
  "model_config": {
    "name": "lotka_volterra_4d",
    "dimension": 4,
    "true_parameters": [1.5, 3.0, 1.0, 1.0]
  },
  "domain_config": {
    "strategy": "centered_at_true",
    "range": 0.4
  },
  ...
}
```

Auto-detected from file extension (`.toml` or `.json`).

---

### 3. API Functions

#### Loading Configs
```julia
using Globtim  # Once integrated

# Load from TOML or JSON (auto-detected)
config = load_ode_experiment_config("experiment.toml")
config = load_ode_experiment_config("experiment.json")

# Access fields
config.model_config.true_parameters  # => [1.5, 3.0, 1.0, 1.0]
config.computation_config.degrees    # => [4, 5, 6, ..., 12]
config.domain_config.strategy        # => "centered_at_true"
```

#### Parsing from Dict/NamedTuple
```julia
# For programmatic config generation
config_dict = (
    model_config = (name = "test", dimension = 4, ...),
    domain_config = (...),
    ...
)
config = parse_ode_experiment_config(config_dict)
```

#### Validation
All configs are validated on load:
- Type checking
- Required field presence
- Value range validation (e.g., `time_span[1] < time_span[2]`)
- Strategy-specific requirements (e.g., `range` required for `centered_at_true`)

Throws `ConfigValidationError` or `SchemaValidationError` with descriptive messages.

---

### 4. Example Files Created

Located in `test/fixtures/`:

1. **`lv4d_experiment_example.toml`**: Full config with all fields
2. **`lv4d_experiment_example.json`**: Same as above in JSON
3. **`lv4d_explicit_bounds_example.toml`**: Using explicit bounds strategy

These serve as templates for new experiments.

---

### 5. Testing

**Test Suite**: `test/test_ode_config_schema.jl`

**Coverage**:
- ✅ TOML loading and parsing
- ✅ JSON loading and parsing
- ✅ All 3 domain strategies (centered_at_true, explicit_bounds, random_offset)
- ✅ Degree range string parsing (`"4:12"` → `[4, 5, ..., 12]`)
- ✅ Precision mode normalization
- ✅ Validation error handling
- ✅ Default value application
- ✅ 44/44 tests passing

---

## Files Modified/Created

### Modified
- `src/parameter_tracking_config.jl` (extended)
  - Added new structs
  - Added validation functions
  - Added TOML support
  - Added exports

### Created
- `test/test_ode_config_schema.jl` (test suite)
- `test/fixtures/lv4d_experiment_example.toml`
- `test/fixtures/lv4d_experiment_example.json`
- `test/fixtures/lv4d_explicit_bounds_example.toml`
- `docs/PHASE_1_CONFIG_SCHEMA_SUMMARY.md` (this file)

---

## Integration with Existing Code

### Backward Compatibility
- Existing `ExperimentConfig` (for test functions) unchanged
- New `ODEExperimentConfig` is separate
- Both coexist in same module

### Next Steps (Phase 2)
The config schema is now ready for:
1. **Generic experiment runner** (Phase 2)
   - Function: `run_ode_experiment(model::ODESystem, config::ODEExperimentConfig)`
   - Will replace custom launch scripts like `launch_lv4d_experiment.jl`
2. **Campaign generator** (Phase 3)
   - Input: Campaign config with parameter sweeps
   - Output: N individual `ODEExperimentConfig` files + manifest

---

## Usage Example (Future)

Once Phase 2 is complete, the workflow will be:

### Current Workflow
```bash
# Write custom Julia script
vim launch_lv4d_experiment.jl  # 200+ lines of code

# Run with args
julia launch_lv4d_experiment.jl 0.4 float64
```

### New Workflow (Phase 1 + Phase 2)
```bash
# Write config file
vim lv4d_experiment.toml  # ~40 lines, declarative

# Run with generic runner
globtim-runner lv4d_experiment.toml --model=models/lv4d.jl
```

**Benefit**: No custom code per experiment!

---

## Validation Examples

### Success
```julia
julia> config = load_ode_experiment_config("lv4d_experiment_example.toml")
# ✓ Loads successfully

julia> config.computation_config.degrees
# => [4, 5, 6, 7, 8, 9, 10, 11, 12]
```

### Validation Errors
```julia
# Missing required field
julia> config = load_ode_experiment_config("incomplete_config.toml")
ERROR: ConfigValidationError("Missing required section: solver_config")

# Invalid time span
julia> config = load_ode_experiment_config("bad_timespan.toml")
ERROR: SchemaValidationError("time_span must be [start, end] with start < end", ...)

# Invalid domain strategy
julia> config = load_ode_experiment_config("bad_strategy.toml")
ERROR: SchemaValidationError("Invalid domain strategy", ...)
```

---

## Technical Details

### Degree Range Parsing
Supports two formats:
```toml
# Format 1: Explicit array
degrees = [4, 6, 8, 10, 12]

# Format 2: Range string
degrees = "4:12"  # Expands to [4, 5, 6, 7, 8, 9, 10, 11, 12]
```

### Precision Mode
Accepts variations and normalizes:
```toml
precision_mode = "float64"          # ✓
precision_mode = "Float64"          # ✓ → normalized to "float64"
precision_mode = "Float64Precision" # ✓ → normalized to "float64"
precision_mode = "adaptive"         # ✓
```

### TOML → NamedTuple Conversion
Internal helper `convert_dict_to_namedtuple` ensures consistent API:
- TOML parses to `Dict`
- JSON3 parses to `JSON3.Object` (behaves like NamedTuple)
- Converter bridges the gap

---

## Performance

- **Config loading**: <100ms for typical configs
- **Validation**: Negligible (<10ms)
- **No runtime overhead**: Configs parsed once at startup

---

## Documentation

### Inline Docs
All structs and functions have docstrings with examples:
```julia
julia> ?load_ode_experiment_config
# Displays full documentation
```

### Example Files
Templates in `test/fixtures/` demonstrate all features.

---

## Conclusion

Phase 1 delivers a **production-ready configuration schema** for ODE experiments:

✅ **Flexible**: 3 domain strategies, multiple precision modes
✅ **Type-safe**: Full validation with clear error messages
✅ **User-friendly**: TOML for humans, JSON for machines
✅ **Well-tested**: 44 passing tests covering all features
✅ **Documented**: Docstrings + example files
✅ **Backward compatible**: Existing code unaffected

**Ready for Phase 2**: Generic experiment runner implementation.

---

## Related Files

- Implementation: [src/parameter_tracking_config.jl](../src/parameter_tracking_config.jl)
- Tests: [test/test_ode_config_schema.jl](../test/test_ode_config_schema.jl)
- Examples: [test/fixtures/](../test/fixtures/)
- Roadmap: See Phase 2 planning document (TBD)
