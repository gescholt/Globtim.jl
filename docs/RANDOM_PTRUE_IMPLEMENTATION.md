# Random p_true Generation - Implementation Summary

## Overview

This document summarizes the implementation of random interior point generation for parameter recovery experiments in the globtimcore library.

## What Was Implemented

### Core Function: `generate_random_interior_point`

**Location**: [`src/grid_utils.jl`](src/grid_utils.jl#L124-L203)

Generates random points guaranteed to be in the interior of a domain defined by center and size.

**Signature**:
```julia
generate_random_interior_point(
    center::Vector{Float64},
    domain_size::Union{Float64, Vector{Float64}},
    dim::Int;
    margin::Float64 = 0.1
)::Vector{Float64}
```

**Key Features**:
- ✅ Supports scalar or per-dimension domain sizes
- ✅ Configurable safety margin from boundaries (default 10%)
- ✅ Full input validation with clear error messages
- ✅ Works with Random.seed!() for reproducibility
- ✅ Exported from Globtim module

### Template Integration

**Location**: [`tools/mcp/templates/lv4d_template.jl`](tools/mcp/templates/lv4d_template.jl)

The LV4D experiment template now supports automatic random p_true generation with new parameters:

- `generate_p_true::Bool` - Enable random generation (default: false)
- `p_true_seed::Union{Int, Nothing}` - Seed for reproducibility (default: nothing)
- `p_true_margin::Float64` - Safety margin (default: 0.1)

**Usage Example**:
```julia
params = Dict{Symbol, Any}(
    :domain_range => 0.8,
    :GN => 16,
    :p_center => [1.0, 1.0, 1.0, 1.0],
    :generate_p_true => true,      # Enable random generation
    :p_true_seed => 42,             # Reproducible seed
    :p_true_margin => 0.1           # 10% margin from boundaries
)
```

## Files Created/Modified

### Core Implementation
- ✅ **Modified**: [`src/grid_utils.jl`](src/grid_utils.jl) - Added `generate_random_interior_point` function

### Tests
- ✅ **Created**: [`test/test_random_interior_point.jl`](test/test_random_interior_point.jl) - Comprehensive unit tests (16,243 test cases)
- ✅ **Created**: [`test/test_template_p_true_generation.jl`](test/test_template_p_true_generation.jl) - Template integration tests
- ✅ **Created**: [`test/test_random_p_true_integration.jl`](test/test_random_p_true_integration.jl) - End-to-end integration tests

### Documentation
- ✅ **Created**: [`docs/random_p_true_generation.md`](docs/random_p_true_generation.md) - Complete documentation
- ✅ **Created**: [`examples/random_p_true_example.jl`](examples/random_p_true_example.jl) - Practical examples
- ✅ **Created**: `RANDOM_PTRUE_IMPLEMENTATION.md` - This summary

### Template Updates
- ✅ **Modified**: [`tools/mcp/templates/lv4d_template.jl`](tools/mcp/templates/lv4d_template.jl) - Added p_true generation support

## Test Results

All tests pass successfully:

```bash
# Core function tests
$ julia --project=. test/test_random_interior_point.jl
Test Summary:                        |  Pass  Total  Time
generate_random_interior_point tests | 16243  16243  0.4s

# Template integration tests
$ julia --project=. test/test_template_p_true_generation.jl
Test Summary:                               | Pass  Total  Time
LV4D Template with Random p_true Generation |   26     26  0.2s

# End-to-end integration tests
$ julia --project=. test/test_random_p_true_integration.jl
Test Summary:                        | Pass  Total  Time
End-to-End Random p_true Integration |   10     10  9.7s
Test Summary:        | Pass  Total  Time
Reproducibility Test |    5      5  0.1s
```

## Usage Examples

### Example 1: Basic Usage

```julia
using Globtim
using Random

center = [1.0, 1.0, 1.0, 1.0]
domain_size = 0.8

Random.seed!(42)
p_true = generate_random_interior_point(center, domain_size, 4)
# Result: [1.186..., 0.928..., 0.967..., 1.292...]
```

### Example 2: MCP Template Generation

```julia
# Generate experiment with random p_true
include("tools/mcp/templates/lv4d_template.jl")

params = Dict{Symbol, Any}(
    :domain_range => 0.8,
    :GN => 16,
    :degree_min => 4,
    :degree_max => 18,
    :basis => "chebyshev",
    :p_center => [1.0, 1.0, 1.0, 1.0],
    :generate_p_true => true,
    :p_true_seed => 2024
)

script = generate_lv4d_script(LV4D_TEMPLATE, params)
# Generated script will include:
# Random.seed!(2024)
# const P_TRUE = generate_random_interior_point(P_CENTER, DOMAIN_RANGE, 4, margin=0.1)
```

### Example 3: Batch Experiments

```julia
# Run 10 experiments with different random p_true
for exp_id in 1:10
    Random.seed!(1000 + exp_id)
    p_true = generate_random_interior_point(center, domain_size, 4)

    # Create and run experiment with this p_true
    error_func = make_error_distance(model, outputs, ic, p_true, ...)
    TR = test_input(error_func, dim=4, center=center, sample_range=domain_size)
    # ... continue experiment
end
```

## Mathematical Details

**Domain Definition**: Hypercube centered at `center` with half-width `domain_size`
- Full domain: `[center - domain_size, center + domain_size]` per dimension

**Generation Algorithm**:
1. Generate random point in `[-1, 1]^n`
2. Apply margin: scale by `(1 - margin)`
3. Transform to domain: `p_true = center + domain_size * scaled_random`

**With default margin of 0.1**:
- Generated points stay within 90% of domain extent
- Ensures points are not too close to boundaries
- Good for numerical stability in optimization

## Integration Points

The function is now available in:

1. **Core Library** - Via `using Globtim`
2. **MCP Templates** - Automatic generation in LV4D template
3. **Custom Scripts** - Direct function calls
4. **Experiment Workflows** - Standard parameter recovery pattern

## Benefits

1. **Reproducibility** - Use seeds for exact replication
2. **Safety** - Guaranteed interior points avoid boundary issues
3. **Flexibility** - Scalar or vector domain sizes, custom margins
4. **Automation** - Template integration for batch experiments
5. **Validation** - Comprehensive input checking with clear errors

## Future Enhancements (Optional)

Potential extensions if needed:

- [ ] Support for non-hypercube domains (ellipsoids, polytopes)
- [ ] Stratified sampling (Latin hypercube, etc.)
- [ ] Distance-based constraints (minimum distance from center)
- [ ] Physical constraint validation (e.g., positivity for LV)

## Quick Start

To use in your experiment:

```julia
using Globtim
using Random

# 1. Define your domain
center = [1.0, 1.0, 1.0, 1.0]
domain_size = 0.8

# 2. Generate random p_true
Random.seed!(42)  # Optional, for reproducibility
p_true = generate_random_interior_point(center, domain_size, 4)

# 3. Use in parameter recovery
error_func = make_error_distance(model, outputs, ic, p_true, time_interval, num_points, L2_norm)
TR = test_input(error_func, dim=4, center=center, GN=16, sample_range=domain_size)

# 4. Continue with polynomial approximation...
```

## Documentation Links

- **Full Documentation**: [docs/random_p_true_generation.md](docs/random_p_true_generation.md)
- **Examples**: [examples/random_p_true_example.jl](examples/random_p_true_example.jl)
- **Function Source**: [src/grid_utils.jl](src/grid_utils.jl#L124-L203)
- **Template Integration**: [tools/mcp/templates/lv4d_template.jl](tools/mcp/templates/lv4d_template.jl)

## Testing

Run all tests:
```bash
julia --project=. test/test_random_interior_point.jl
julia --project=. test/test_template_p_true_generation.jl
julia --project=. test/test_random_p_true_integration.jl
```

Run examples:
```bash
julia --project=. examples/random_p_true_example.jl
```

---

**Implementation Date**: October 16, 2025
**Status**: ✅ Complete and Tested
**All Tests**: ✅ Passing (16,284 total test cases)
