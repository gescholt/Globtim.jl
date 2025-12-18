# Phase D: Production Integration

**Goal**: Integrate sparsity features into production workflows and make them easily accessible

**Timeline**: 4-6 hours

**Priority**: 🟡 MEDIUM - Makes features production-ready

**Prerequisite**: Complete Option 2 and Phase C (testing)

---

## Overview

This phase makes sparsity features accessible through:
1. Constructor-level options
2. Configuration file support
3. StandardExperiment integration
4. Documentation and examples
5. User-friendly defaults

---

## Integration Tasks

### Task 1: Constructor Integration (1.5 hours)

**File**: `src/Main_Gen.jl` (Constructor function)

#### 1.1 Add Sparsity Parameters

```julia
function Constructor(
    TR::test_input,
    degree_in::Int;
    basis::Symbol = :chebyshev,
    precision::PrecisionType = RationalPrecision,
    GN::Union{Int, Nothing} = nothing,
    center = nothing,
    grid = nothing,
    scale_factor::Union{Float64, Vector{Float64}, Nothing} = nothing,
    verbose::Int = 0,
    force_anisotropic::Bool = false,
    force_tensorized::Bool = false,

    # NEW: Sparsity options
    sparsify::Bool = false,                    # Enable sparsification
    sparsity_threshold::Float64 = 1e-6,        # Threshold for truncation
    sparsity_mode::Symbol = :relative,         # :relative or :absolute
    sparsify_reoptimize::Bool = false,         # Use re-optimization
    sparsify_precision::Type = BigFloat,       # Precision for re-optimization
    sparsify_solver::Symbol = :qr,             # Solver for re-optimization
    return_sparse_monomial::Bool = false       # Return sparse monomial poly
)
```

#### 1.2 Sparsification Logic

Add after line 314 (after ApproxPoly construction):

```julia
# Apply sparsification if requested
if sparsify || return_sparse_monomial
    @info "  🔪 Applying sparsification..."

    if sparsify
        # Sparsify in orthogonal basis
        sparsify_result = sparsify_polynomial(
            approx_pol,
            sparsity_threshold,
            mode = sparsity_mode
        )
        approx_pol = sparsify_result.polynomial

        if verbose >= 1
            @info "    Sparsified: $(sparsify_result.original_nnz) → $(sparsify_result.new_nnz) coefficients"
            @info "    L2-norm ratio: $(round(sparsify_result.l2_ratio*100, digits=1))%"
        end
    end

    if return_sparse_monomial
        # Convert to sparse monomial basis
        @polyvar x[1:TR.dim]
        sparse_mono = to_exact_monomial_basis_sparse(
            approx_pol,
            threshold = sparsity_threshold,
            mode = sparsity_mode,
            reoptimize = sparsify_reoptimize,
            precision = sparsify_precision,
            solver = sparsify_solver,
            variables = x
        )

        if verbose >= 1
            @info "    Sparse monomial: $(sparse_mono.sparsity_info.new_nnz) non-zero terms"
            @info "    L2-norm preservation: $(round(sparse_mono.l2_ratio*100, digits=1))%"
        end

        # Return both ApproxPoly and sparse monomial
        return (approx_poly = approx_pol, sparse_monomial = sparse_mono)
    end
end

return approx_pol
```

#### 1.3 Usage Examples

```julia
# Example 1: Simple sparsification in orthogonal basis
pol = Constructor(TR, 15, sparsify=true, sparsity_threshold=1e-5)

# Example 2: Sparse monomial with re-optimization
result = Constructor(
    TR, 15,
    return_sparse_monomial = true,
    sparsify_reoptimize = true,
    sparsify_precision = BigFloat,
    verbose = 1
)
sparse_poly = result.sparse_monomial.polynomial

# Example 3: Combined workflow
result = Constructor(
    TR, 15,
    sparsify = true,                    # First: sparsify in orthogonal basis
    return_sparse_monomial = true,      # Then: convert to sparse monomial
    sparsify_reoptimize = true,         # With re-optimization
    sparsity_threshold = 1e-6
)
```

**Deliverables**:
- [ ] Constructor updated with sparsity options
- [ ] Documentation strings updated
- [ ] Examples in docstring
- [ ] Tests for new parameters

---

### Task 2: Configuration File Support (1 hour)

**File**: `src/config.jl`

#### 2.1 Add Sparsity Configuration Section

```julia
# In parse_config() function, add sparsity section

# Sparsity configuration
sparsity_config = Dict{Symbol, Any}(
    :enable => false,
    :threshold => 1e-6,
    :mode => :relative,
    :reoptimize => false,
    :precision => BigFloat,
    :solver => :qr,
    :return_monomial => false
)

if haskey(toml_dict, "sparsity")
    sparsity_section = toml_dict["sparsity"]

    if haskey(sparsity_section, "enable")
        sparsity_config[:enable] = sparsity_section["enable"]
    end

    if haskey(sparsity_section, "threshold")
        sparsity_config[:threshold] = Float64(sparsity_section["threshold"])
    end

    if haskey(sparsity_section, "mode")
        mode_str = sparsity_section["mode"]
        sparsity_config[:mode] = Symbol(mode_str)
    end

    if haskey(sparsity_section, "reoptimize")
        sparsity_config[:reoptimize] = sparsity_section["reoptimize"]
    end

    if haskey(sparsity_section, "precision")
        prec_str = sparsity_section["precision"]
        if prec_str == "BigFloat"
            sparsity_config[:precision] = BigFloat
        elseif prec_str == "Float64"
            sparsity_config[:precision] = Float64
        end
    end

    if haskey(sparsity_section, "solver")
        sparsity_config[:solver] = Symbol(sparsity_section["solver"])
    end

    if haskey(sparsity_section, "return_monomial")
        sparsity_config[:return_monomial] = sparsity_section["return_monomial"]
    end
end

config[:sparsity] = sparsity_config
```

#### 2.2 Example Configuration File

**File**: `Examples/config_sparse_refinement.toml`

```toml
[approximation]
basis = "chebyshev"
degree = 15
precision = "RationalPrecision"

[sparsity]
# Enable sparsification
enable = true

# Sparsity threshold (relative to max coefficient)
threshold = 1e-5
mode = "relative"  # "relative" or "absolute"

# Re-optimization options
reoptimize = true
precision = "BigFloat"  # "BigFloat" or "Float64"
solver = "qr"  # "lu", "qr", or "svd"

# Return sparse monomial polynomial
return_monomial = true

[domain]
dimension = 2
center = [0.0, 0.0]
sample_range = 1.0

[grid]
type = "gauss_lobatto"
points_per_dimension = 30
```

#### 2.3 Use in Workflow

```julia
# Load configuration
config = parse_config("config_sparse_refinement.toml")

# Create test input
TR = test_input(f, dim=config.dim, center=config.center, sample_range=config.sample_range)

# Run Constructor with sparsity config
result = Constructor(
    TR,
    config.degree,
    basis = Symbol(config.basis),
    sparsify = config.sparsity[:enable],
    sparsity_threshold = config.sparsity[:threshold],
    sparsify_reoptimize = config.sparsity[:reoptimize],
    sparsify_precision = config.sparsity[:precision],
    return_sparse_monomial = config.sparsity[:return_monomial]
)
```

**Deliverables**:
- [ ] Config parser updated
- [ ] Example TOML file created
- [ ] Documentation for config options
- [ ] Validation of config values

---

### Task 3: StandardExperiment Integration (1.5 hours)

**File**: `src/StandardExperiment.jl`

#### 3.1 Add Sparsity to Experiment Metadata

```julia
struct StandardExperiment
    # ... existing fields ...

    # NEW: Sparsity configuration
    sparsity_enabled::Bool
    sparsity_threshold::Float64
    sparsity_reoptimized::Bool
    sparse_monomial_saved::Bool
end
```

#### 3.2 Save Sparse Results

```julia
function save_experiment_results(
    exp::StandardExperiment,
    pol::ApproxPoly,
    sparse_result = nothing;  # NEW parameter
    output_dir::String = "results"
)
    # ... existing save logic ...

    # Save sparse monomial polynomial if available
    if !isnothing(sparse_result)
        sparse_file = joinpath(output_dir, "$(exp.name)_sparse_monomial.jld2")

        @save sparse_file Dict(
            "polynomial" => sparse_result.polynomial,
            "sparsity_info" => sparse_result.sparsity_info,
            "optimization_info" => sparse_result.optimization_info,
            "l2_ratio" => sparse_result.l2_ratio
        )

        @info "Saved sparse monomial polynomial to: $sparse_file"

        # Save human-readable version
        sparse_txt = joinpath(output_dir, "$(exp.name)_sparse_polynomial.txt")
        open(sparse_txt, "w") do io
            println(io, "Sparse Polynomial Approximation")
            println(io, "=" ^60)
            println(io, "Experiment: $(exp.name)")
            println(io, "Original coefficients: $(length(pol.coeffs))")
            println(io, "Sparse coefficients: $(sparse_result.sparsity_info.new_nnz)")
            println(io, "Sparsity: $(round((1-sparse_result.sparsity_info.new_nnz/length(pol.coeffs))*100, digits=1))%")
            println(io, "L2-norm ratio: $(round(sparse_result.l2_ratio*100, digits=1))%")
            println(io, "\nPolynomial:")
            println(io, sparse_result.polynomial)
        end
    end
end
```

#### 3.3 Example Experiment with Sparsity

**File**: `Examples/standard_experiment_sparse.jl`

```julia
using Globtim
using DynamicPolynomials

# Define test function
f(x) = 1 / (1 + 25*x[1]^2)

# Create experiment configuration
exp = StandardExperiment(
    name = "runge_sparse_test",
    description = "Runge function with sparsity",
    dimension = 1,
    degree = 20,
    basis = :chebyshev,
    sparsity_enabled = true,
    sparsity_threshold = 1e-5,
    sparsity_reoptimized = true,
    sparse_monomial_saved = true
)

# Create test input
TR = test_input(f, dim=1, center=[0.0], sample_range=1.0)

# Run approximation with sparsity
result = Constructor(
    TR, exp.degree,
    basis = exp.basis,
    sparsify = exp.sparsity_enabled,
    sparsity_threshold = exp.sparsity_threshold,
    sparsify_reoptimize = exp.sparsity_reoptimized,
    return_sparse_monomial = exp.sparse_monomial_saved,
    verbose = 1
)

# Save results
save_experiment_results(
    exp,
    result.approx_poly,
    result.sparse_monomial,
    output_dir = "results/sparse_experiments"
)

println("\n✓ Experiment complete!")
```

**Deliverables**:
- [ ] StandardExperiment updated
- [ ] Save/load functions handle sparse results
- [ ] Example experiment script
- [ ] Documentation

---

### Task 4: User Documentation (1 hour)

**File**: `docs/user_guides/SPARSITY_GUIDE.md`

```markdown
# Sparsity Guide: Reducing Polynomial Complexity

## Overview

Polynomial approximations often have many small coefficients that contribute little to accuracy but increase computational cost. Sparsification removes these small terms while preserving approximation quality.

## Quick Start

### Basic Usage

```julia
using Globtim

# Your test function
f(x) = x[1]^4 + x[2]^2

TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)

# Create sparse approximation
pol = Constructor(TR, 10, sparsify=true, sparsity_threshold=1e-6)
```

### With Re-optimization (Recommended)

```julia
result = Constructor(
    TR, 10,
    return_sparse_monomial = true,
    sparsify_reoptimize = true,
    sparsify_precision = BigFloat
)

sparse_poly = result.sparse_monomial.polynomial
```

## When to Use Sparsity

✅ **Good Use Cases:**
- High-degree approximations (degree > 10)
- Naturally sparse functions (polynomials, piecewise functions)
- Memory-constrained environments
- Repeated polynomial evaluations

❌ **Avoid When:**
- Very low degree (< 5)
- Dense smooth functions (exp, sin, etc.)
- Single-use polynomials
- Accuracy is critical and sparsity minimal

## Threshold Selection

### Relative Mode (Recommended)
```julia
sparsity_threshold = 1e-5  # Remove coeffs < 1e-5 * max(|coeffs|)
sparsity_mode = :relative
```

### Absolute Mode
```julia
sparsity_threshold = 1e-8  # Remove coeffs < 1e-8
sparsity_mode = :absolute
```

### Adaptive Selection
```julia
threshold = find_optimal_sparsity_threshold(
    pol,
    max_l2_degradation = 0.01  # Allow 1% accuracy loss
)
```

## Re-optimization vs Simple Truncation

### Simple Truncation
- **Fast**: Just zeros out small coefficients
- **Less accurate**: Doesn't account for basis change
- **Use when**: Speed > accuracy

```julia
result = to_exact_monomial_basis_sparse(
    pol,
    threshold = 1e-6,
    reoptimize = false
)
```

### Re-optimization
- **Slower**: Solves least squares in high precision
- **More accurate**: Optimizes remaining coefficients
- **Use when**: Accuracy matters

```julia
result = to_exact_monomial_basis_sparse(
    pol,
    threshold = 1e-6,
    reoptimize = true,
    precision = BigFloat
)
```

## Integration with Local Refinement

```julia
# Global sparse approximation
pol_global = Constructor(TR_global, 10, sparsify=true)

# Find critical points
critical_pts = find_critical_points(pol_global, TR_global)

# Local refinement around critical points
for cp in critical_pts
    TR_local = test_input(f, dim=2, center=cp, sample_range=0.2)

    pol_local = Constructor(
        TR_local, 8,
        return_sparse_monomial = true,
        sparsify_reoptimize = true
    )

    # Use local sparse polynomial for accurate evaluation near cp
end
```

## Configuration File Example

```toml
[sparsity]
enable = true
threshold = 1e-5
mode = "relative"
reoptimize = true
precision = "BigFloat"
```

## Troubleshooting

### Warning: High condition number
**Problem**: Monomial basis is ill-conditioned
**Solution**: Use `precision = BigFloat` with re-optimization

### Warning: L2-norm degradation exceeds threshold
**Problem**: Too aggressive sparsification
**Solution**: Reduce threshold or use adaptive selection

### Error: All coefficients below threshold
**Problem**: Threshold too high
**Solution**: Use relative mode or reduce threshold
```

**Deliverables**:
- [ ] User guide written
- [ ] Examples included
- [ ] Troubleshooting section
- [ ] Published to docs/

---

### Task 5: Refining.jl Compatibility (30 min)

**File**: `src/refining.jl`

#### 5.1 Add Sparse Polynomial Support

Ensure `find_critical_points()` works with sparse monomial polynomials:

```julia
"""
Find critical points from sparse monomial polynomial.
"""
function find_critical_points_from_monomial(
    mono_poly::DynamicPolynomials.Polynomial,
    TR::test_input;
    kwargs...
)
    # Create temporary ApproxPoly wrapper
    # (Adapter pattern)

    # Convert monomial polynomial to format expected by refining.jl
    # This may require gradient/Hessian computation from monomial form

    # Call existing critical point solver
    return find_critical_points(adapted_poly, TR; kwargs...)
end
```

#### 5.2 Gradient/Hessian from Monomial Polynomial

```julia
"""
Compute gradient of monomial polynomial.
"""
function compute_gradient_monomial(poly::DynamicPolynomials.Polynomial, x::Vector{Float64})
    vars = variables(poly)
    grad = [differentiate(poly, var) for var in vars]
    return [g(x...) for g in grad]
end

"""
Compute Hessian of monomial polynomial.
"""
function compute_hessian_monomial(poly::DynamicPolynomials.Polynomial, x::Vector{Float64})
    vars = variables(poly)
    n = length(vars)
    H = zeros(n, n)

    for i in 1:n, j in 1:n
        H[i,j] = differentiate(differentiate(poly, vars[i]), vars[j])(x...)
    end

    return H
end
```

**Deliverables**:
- [ ] Sparse polynomial compatibility verified
- [ ] Gradient/Hessian functions for monomial basis
- [ ] Tests with sparse polynomials in refining.jl

---

## Production Checklist

### Code Integration
- [ ] Constructor accepts sparsity parameters
- [ ] Configuration file support added
- [ ] StandardExperiment handles sparse results
- [ ] Refining.jl works with sparse polynomials

### Documentation
- [ ] User guide written
- [ ] API documentation updated
- [ ] Examples provided
- [ ] Troubleshooting guide

### Testing
- [ ] All integration tests pass
- [ ] Examples run without errors
- [ ] Configuration files validated
- [ ] Backward compatibility maintained

### Performance
- [ ] No performance regression in non-sparse case
- [ ] Sparse evaluation faster than dense
- [ ] Memory usage validated

---

## Usage Patterns

### Pattern 1: High-Degree Global Approximation

```julia
# Problem: Degree 20 approximation has 1000+ coefficients
result = Constructor(
    TR, 20,
    sparsify = true,
    sparsity_threshold = 1e-5,
    return_sparse_monomial = true,
    sparsify_reoptimize = true
)
# Result: 200 coefficients, 99% accuracy preserved
```

### Pattern 2: Local Refinement Pipeline

```julia
# Step 1: Global sparse approximation
pol_global = Constructor(TR_global, 12, sparsify=true)

# Step 2: Find critical points
cps = find_critical_points(pol_global, TR_global)

# Step 3: Local sparse refinements
local_polys = []
for cp in cps
    TR_local = test_input(f, center=cp, sample_range=0.1)
    pol_local = Constructor(
        TR_local, 8,
        return_sparse_monomial = true,
        sparsify_reoptimize = true
    )
    push!(local_polys, pol_local)
end
```

### Pattern 3: Experiment Campaign

```julia
# Run experiment with varying sparsity thresholds
thresholds = [1e-3, 1e-4, 1e-5, 1e-6]

for threshold in thresholds
    exp_name = "sparse_$(threshold)"

    result = Constructor(
        TR, 15,
        sparsify = true,
        sparsity_threshold = threshold,
        return_sparse_monomial = true
    )

    save_experiment_results(exp_name, result)
end

# Analyze tradeoffs
analyze_sparsity_campaign("results/sparse_*")
```

---

## Next Steps After Phase D

1. **Production deployment**: Use in actual research problems
2. **User feedback**: Gather usage patterns, pain points
3. **Performance optimization**: Profile and optimize hot paths
4. **Extended features**:
   - Automatic threshold selection
   - Adaptive sparsity (different thresholds per variable)
   - Sparse tensor product grids
   - Compressed storage formats

---

## Maintenance

### Adding New Solver
1. Add to `solver_types.jl`
2. Implement `solve_linear_system()` method
3. Add to config options
4. Update documentation

### Adding New Precision Strategy
1. Add to `precision_strategies.jl`
2. Update config parser
3. Add tests
4. Document performance characteristics

### Updating Examples
- Keep examples in sync with API changes
- Test examples in CI/CD
- Update screenshots/output if needed
