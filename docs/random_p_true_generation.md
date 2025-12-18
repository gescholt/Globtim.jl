# Random p_true Generation for Parameter Recovery Experiments

## Overview

The `generate_random_interior_point` function provides a robust way to generate random true parameters (`p_true`) that are guaranteed to be in the interior of your search domain. This is essential for parameter recovery experiments where you want to ensure the true parameters are findable within your optimization domain.

## Function Signature

```julia
generate_random_interior_point(
    center::Vector{Float64},
    domain_size::Union{Float64, Vector{Float64}},
    dim::Int;
    margin::Float64 = 0.1
)::Vector{Float64}
```

## Parameters

- **`center`**: Center point of the domain (n-dimensional vector)
- **`domain_size`**: Half-width of the domain hypercube
  - If `Float64`: Same size used for all dimensions
  - If `Vector{Float64}`: Per-dimension sizes
- **`dim`**: Dimension of the parameter space
- **`margin`**: Safety margin from boundaries (default 0.1)
  - `0.1` means stay within 90% of domain extent
  - Valid range: `[0, 1)`

## Returns

Random point guaranteed to be in the interior of the domain, respecting the safety margin.

## Mathematical Details

The function works in three steps:

1. **Generate random unit point**: Creates a random point in `[-1, 1]^n`
2. **Apply safety margin**: Scales by `(1 - margin)` to stay away from boundaries
3. **Transform to domain**: `p_true = center + domain_size * scaled_random`

### Domain Definition

The domain is a hypercube defined by:
- **Center**: `center`
- **Extent**: `[center - domain_size, center + domain_size]` per dimension

With margin `m`, the generated point will be in:
- `[center - (1-m)*domain_size, center + (1-m)*domain_size]` per dimension

## Usage Examples

### Example 1: Basic 4D Lotka-Volterra

```julia
using Globtim

# Define search domain
center = [1.0, 1.0, 1.0, 1.0]
domain_size = 0.8

# Generate random p_true with default margin (0.1)
p_true = generate_random_interior_point(center, domain_size, 4)

# Result will be in approximately [0.28, 1.72]^4
# (1.0 ± 0.9*0.8 for each dimension)
```

### Example 2: With Custom Margin

```julia
# Tighter margin - stay within 80% of domain
p_true = generate_random_interior_point(center, domain_size, 4, margin=0.2)

# Result will be in approximately [0.36, 1.64]^4
```

### Example 3: With Reproducible Seed

```julia
using Random

# Set seed for reproducibility
Random.seed!(42)
p_true = generate_random_interior_point(center, domain_size, 4)

# Same seed will always produce same p_true
```

### Example 4: Per-Dimension Domain Sizes

```julia
# Different domain extent per dimension
center = [1.0, 1.0, 1.0, 1.0]
sizes = [0.8, 0.6, 0.9, 0.7]

p_true = generate_random_interior_point(center, sizes, 4)

# Each dimension has different bounds:
# dim 1: [1.0 - 0.72, 1.0 + 0.72] = [0.28, 1.72]
# dim 2: [1.0 - 0.54, 1.0 + 0.54] = [0.46, 1.54]
# dim 3: [1.0 - 0.81, 1.0 + 0.81] = [0.19, 1.81]
# dim 4: [1.0 - 0.63, 1.0 + 0.63] = [0.37, 1.63]
```

## Integration with MCP Template System

The LV4D template now supports automatic random `p_true` generation:

### Template Parameters

```julia
params = Dict{Symbol, Any}(
    :domain_range => 0.8,
    :GN => 16,
    :degree_min => 4,
    :degree_max => 18,
    :basis => "chebyshev",
    :p_center => [1.0, 1.0, 1.0, 1.0],

    # Enable random p_true generation
    :generate_p_true => true,
    :p_true_seed => 42,        # Optional: for reproducibility
    :p_true_margin => 0.1      # Optional: safety margin
)
```

### Generated Script Example

When `generate_p_true=true`, the template generates:

```julia
using Random

# Experiment Configuration
const DOMAIN_RANGE = 0.8
const P_CENTER = [1.0, 1.0, 1.0, 1.0]
const BASIS = :chebyshev

# Generate random p_true in domain interior
Random.seed!(42)  # Only if p_true_seed is specified
const P_TRUE = generate_random_interior_point(P_CENTER, DOMAIN_RANGE, 4, margin=0.1)
println("Generated P_TRUE: $P_TRUE")
```

## Best Practices

### 1. **Choose Appropriate Margin**

- **Default (0.1)**: Good for most cases, ensures parameters aren't too close to boundaries
- **Larger (0.2-0.3)**: Use when you want parameters well-separated from domain edges
- **Smaller (0.0-0.05)**: Use when you need to test edge cases or have physical constraints

### 2. **Use Seeds for Reproducibility**

```julia
# For experiments you want to reproduce exactly
params[:p_true_seed] = 12345

# For different random instances in batch experiments
params[:p_true_seed] = experiment_id
```

### 3. **Validate Generated Parameters**

```julia
p_true = generate_random_interior_point(center, domain_size, 4)

# Check they're physically valid (e.g., all positive for LV)
@assert all(p_true .> 0) "LV parameters must be positive"

# Check they're in expected range
@assert all(abs.(p_true .- center) .<= domain_size) "Parameters outside domain"
```

### 4. **Document Your Choice**

When using random `p_true`, always document:
- The seed (if used)
- The margin value
- The rationale for the choice

## Workflow Integration

### Typical Parameter Recovery Workflow

```julia
# Step 1: Define your domain
p_center = [1.0, 1.0, 1.0, 1.0]
domain_size = 0.8

# Step 2: Generate random p_true
Random.seed!(2024)
p_true = generate_random_interior_point(p_center, domain_size, 4)

# Step 3: Create error function with this p_true
error_func = make_error_distance(model, outputs, ic, p_true, time_interval, num_points, L2_norm)

# Step 4: Sample the domain around p_center
TR = test_input(error_func, dim=4, center=p_center, GN=16, sample_range=domain_size)

# Step 5: Polynomial approximation and optimization
pol = Constructor(TR, (:one_d_for_all, degree), basis=:chebyshev)
```

### Batch Experiments with Different p_true

```julia
# Generate multiple experiments with different random p_true
for experiment_id in 1:10
    Random.seed!(1000 + experiment_id)
    p_true = generate_random_interior_point(p_center, domain_size, 4)

    # Run experiment...
    # Save results with experiment_id for tracking
end
```

## Common Pitfalls and Solutions

### Pitfall 1: Forgetting to Set Seed
**Problem**: Can't reproduce results
**Solution**: Always use `Random.seed!()` before generation if reproducibility matters

### Pitfall 2: Margin Too Large
**Problem**: Very restricted parameter space
**Solution**: Keep margin ≤ 0.2 for most applications

### Pitfall 3: Wrong Dimension
**Problem**: `center` dimension doesn't match `dim`
**Solution**: Function validates this and throws error

### Pitfall 4: Domain Too Small
**Problem**: Generated parameters don't match physical constraints
**Solution**: Choose `domain_size` large enough to encompass valid parameter ranges

## Testing

The implementation includes comprehensive tests:

```bash
# Test the core function
julia --project=. test/test_random_interior_point.jl

# Test template integration
julia --project=. test/test_template_p_true_generation.jl

# Test end-to-end integration
julia --project=. test/test_random_p_true_integration.jl
```

## Related Functions

- **`test_input`**: Creates test input with samples around center
- **`make_error_distance`**: Creates error function for parameter recovery
- **`Constructor`**: Builds polynomial approximation from samples

## See Also

- [LV4D Template Documentation](../tools/mcp/templates/README.md)
- [Grid Utils Documentation](../src/grid_utils.jl)
- [4D Lotka-Volterra Examples](../node_experiments/scripts/)
