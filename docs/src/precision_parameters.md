# Precision Parameters

Globtim serves as an interface between **numeric** and **symbolic** computation. The polynomial approximation pipeline involves multiple stages - sampling, coefficient computation, basis conversion, and critical point solving - each benefiting from different precision strategies.

## Overview

Globtim allows different precision types at each stage of the algorithm, enabling users to trade off computational cost against numerical accuracy.

Globtim supports multiple precision types through the `precision` parameter in the `Constructor` function:

```julia
# Basic syntax
pol = Constructor(TR, degree, precision=PrecisionType)
```

## Available Precision Types

### Float64Precision

**Standard double-precision floating-point arithmetic**

The default numeric type in Julia. Fast and memory-efficient, suitable for most stages of the pipeline where machine precision is sufficient.

```julia
pol = Constructor(TR, 8, precision=Float64Precision)
println("Coefficient type: $(eltype(pol.coeffs))")  # Float64
```

**Characteristics:**
- Uses IEEE 754 double precision (~15-16 decimal digits)
- Fastest computation and lowest memory usage
- Standard choice for most applications
- May accumulate numerical errors in high-degree polynomials

### AdaptivePrecision

**Hybrid approach: Float64 for evaluation, BigFloat for coefficient manipulation**

Uses numeric precision where speed matters (function sampling) and extended precision where accuracy matters (coefficient computation and basis conversion). This reflects Globtim's role as a numeric/symbolic interface.

```julia
pol = Constructor(TR, 8, precision=AdaptivePrecision)
println("Raw coefficients: $(eltype(pol.coeffs))")  # Float64

# Extended precision in monomial expansion
@polyvar x[1:2]
mono_poly = to_exact_monomial_basis(pol, variables=x)
coeffs = [coefficient(t) for t in terms(mono_poly)]
println("Monomial coefficients: $(typeof(coeffs[1]))")  # BigFloat
```

**Key Features:**
- Function evaluation stays Float64 (fast sampling)
- Coefficient manipulation uses BigFloat (accurate)
- Compatible with sparsification workflow
- Automatic precision selection based on coefficient magnitude
- Recommended for high-dimensional problems where Float64 may be insufficient

### RationalPrecision

**Exact rational arithmetic with arbitrary precision**

Constructs a polynomial approximant with coefficients expressed as fractions of `BigInt`. This is useful when the objective function can be evaluated exactly and exact polynomial coefficients are required as input to a symbolic solver such as msolve, in order to find critical points exactly.

```julia
pol = Constructor(TR, 8, precision=RationalPrecision)
println("Coefficient type: $(eltype(pol.coeffs))")  # Rational{BigInt}
```

**Characteristics:**
- Uses `Rational{BigInt}` for exact representations
- No rounding errors in coefficient computation
- Can represent exact polynomial coefficients
- Memory and computation intensive
- Useful when the function can be evaluated exactly and exact polynomial coefficients are needed as input to a symbolic solver such as msolve

### BigFloatPrecision

**Extended precision floating-point throughout**

Uses BigFloat (configurable precision, default 256 bits) at all stages. Provides maximum numeric precision when needed for validation or ill-conditioned problems.

```julia
pol = Constructor(TR, 8, precision=BigFloatPrecision)
println("Coefficient type: $(eltype(pol.coeffs))")  # BigFloat
```

**Characteristics:**
- Uses BigFloat throughout the computation
- Configurable precision (default: 256 bits)
- Highest numerical accuracy among Globtim's precision types
- Significant performance and memory overhead
- Use only when maximum precision is essential

## Performance Comparison

### Computational Cost

| Precision Type | Constructor Time | Memory Usage | Coefficient Access |
|----------------|------------------|--------------|-------------------|
| Float64Precision | 1.0× (baseline) | 1.0× | Fastest |
| AdaptivePrecision | 1.2× | 1.5× | Fast |
| RationalPrecision | 5-10× | 3-5× | Slow |
| BigFloatPrecision | 3-8× | 2-4× | Moderate |

### Accuracy Comparison

```julia
# Test function with known exact representation
f_exact = x -> x[1]^2 + x[2]^2
TR = TestInput(f_exact, dim=2, center=[0.0, 0.0], sample_range=1.0)

# Compare approximation errors
precisions = [Float64Precision, AdaptivePrecision, RationalPrecision, BigFloatPrecision]
for prec in precisions
    pol = Constructor(TR, 2, precision=prec)
    println("$(prec): L2-norm = $(pol.nrm)")
end
```

Expected output:
```
Float64Precision: L2-norm = 1.2e-15
AdaptivePrecision: L2-norm = 2.3e-16
RationalPrecision: L2-norm = 0.0
BigFloatPrecision: L2-norm = 1.1e-77
```

## Integration with Sparsification

AdaptivePrecision is designed to integrate with Globtim's sparsification features:

### Coefficient Analysis

```julia
# Create polynomial with AdaptivePrecision
pol = Constructor(TR, 10, precision=AdaptivePrecision)

# Convert to monomial basis
@polyvar x[1:2]
mono_poly = to_exact_monomial_basis(pol, variables=x)

# Analyze coefficient distribution
analysis = analyze_coefficient_distribution(mono_poly)
println("Analysis results:")
println("  Total terms: $(analysis.n_total)")
println("  Max coefficient: $(analysis.max_coefficient)")
println("  Min coefficient: $(analysis.min_coefficient)")
println("  Dynamic range: $(analysis.dynamic_range)")
println("  Suggested thresholds: $(analysis.suggested_thresholds)")
```

### Adaptive Truncation

```julia
# Apply smart truncation
threshold = analysis.suggested_thresholds[1]
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)

println("Truncation results:")
println("  Original terms: $(stats.n_total)")
println("  Kept terms: $(stats.n_kept)")
println("  Removed terms: $(stats.n_removed)")
println("  Sparsity ratio: $(round(stats.sparsity_ratio*100, digits=1))%")
```

### Sparsification Workflow

```julia
# Complete sparsification workflow with AdaptivePrecision
function sparsify_with_adaptive_precision(f, TR, degree, threshold_factor=0.1)
    # Step 1: Create polynomial with AdaptivePrecision
    pol = Constructor(TR, degree, precision=AdaptivePrecision)
    
    # Step 2: Convert to monomial basis
    @polyvar x[1:length(TR.center)]
    mono_poly = to_exact_monomial_basis(pol, variables=x)
    
    # Step 3: Analyze coefficients
    analysis = analyze_coefficient_distribution(mono_poly)
    
    # Step 4: Apply adaptive truncation
    threshold = analysis.suggested_thresholds[1] * threshold_factor
    truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)
    
    return (
        original=mono_poly,
        truncated=truncated_poly,
        analysis=analysis,
        stats=stats
    )
end

# Usage example
result = sparsify_with_adaptive_precision(Deuflhard, TR, 8)
println("Achieved $(round(result.stats.sparsity_ratio*100, digits=1))% sparsity")
```

## Use Case Guidelines

### When to Use Each Precision Type

#### Float64Precision
- **General optimization problems**
- **Production workflows requiring speed**
- **Batch processing on HPC clusters**
- **Preliminary analysis and prototyping**

```julia
# Fast batch processing
results = []
for degree in 4:2:12
    pol = Constructor(TR, degree, precision=Float64Precision)
    push!(results, (degree=degree, error=pol.nrm))
end
```

#### AdaptivePrecision
- **High-dimensional problems (dim ≥ 4)**
- **Extended precision requirements**
- **Research applications needing accuracy**
- **Problems with coefficient truncation**

```julia
# High-dimensional optimization
f_6d = x -> sum(x.^2) + 0.1*prod(sin.(π*x))
TR_6d = TestInput(f_6d, dim=6, center=zeros(6), sample_range=1.0)
pol_6d = Constructor(TR_6d, 4, precision=AdaptivePrecision)
```

#### RationalPrecision
- **Exact polynomial representations**
- **Symbolic computation integration**
- **Mathematical research requiring exactness**
- **Small-scale problems where speed is not critical**

```julia
# Exact representation of polynomial functions
f_poly = x -> 2*x[1]^3 - x[1]^2 + 3*x[2]^2 - 1
pol_exact = Constructor(TR, 3, precision=RationalPrecision)
# Should give exactly zero approximation error
```

#### BigFloatPrecision
- **Maximum precision requirements**
- **Ill-conditioned problems**
- **Research requiring extended precision**
- **Validation of other precision types**

```julia
# Maximum precision for validation
pol_reference = Constructor(TR, 12, precision=BigFloatPrecision)
```

## High-Dimensional Considerations

### Memory Scaling

Polynomial coefficient count grows as `C(n+d, d)` where `n` is dimension and `d` is degree:

| Dimension | Degree 4 | Degree 6 | Degree 8 | Degree 10 |
|-----------|----------|----------|----------|-----------|
| 2D | 15 | 28 | 45 | 66 |
| 4D | 70 | 210 | 495 | 1001 |
| 6D | 210 | 924 | 3003 | 8008 |
| 8D | 495 | 3003 | 12870 | 43758 |

### Precision Recommendations by Dimension

```julia
function get_recommended_precision(dim, degree)
    coeff_count = binomial(dim + degree, degree)

    if coeff_count < 100
        return Float64Precision  # Small problems
    elseif coeff_count < 1000
        return AdaptivePrecision  # Medium problems
    elseif coeff_count < 10000
        return AdaptivePrecision  # Large problems (with truncation)
    else
        @warn "Very large problem ($(coeff_count) coefficients). Consider reducing degree."
        return AdaptivePrecision
    end
end

# Usage
recommended = get_recommended_precision(6, 8)
pol = Constructor(TR, 8, precision=recommended)
```

### High-Dimensional Example

```julia
# 8D optimization with precision management
function optimize_8d_with_precision()
    # Define 8D test function
    f_8d = x -> sum(x.^2) + 0.1*sum(sin.(5*π*x)) + 0.01*prod(x[1:4])
    TR_8d = TestInput(f_8d, dim=8, center=zeros(8), sample_range=1.0)

    # Use AdaptivePrecision for accuracy
    println("Creating 8D polynomial with AdaptivePrecision...")
    pol_8d = Constructor(TR_8d, 4, precision=AdaptivePrecision, verbose=1)

    # Apply sparsification to manage complexity
    @polyvar x[1:8]
    mono_poly = to_exact_monomial_basis(pol_8d, variables=x)

    # Analyze and truncate
    analysis = analyze_coefficient_distribution(mono_poly)
    threshold = analysis.suggested_thresholds[2]  # More aggressive truncation
    truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)

    println("8D Results:")
    println("  Original L2-norm: $(pol_8d.nrm)")
    println("  Coefficient count: $(analysis.n_total)")
    println("  After truncation: $(stats.n_kept) terms ($(round(stats.sparsity_ratio*100))% sparse)")

    return truncated_poly
end
```

## HPC Cluster Optimization

### Resource Requirements

Different precision types have different computational and memory requirements on HPC systems:

```julia
# HPC resource estimation
function estimate_hpc_resources(dim, degree, precision_type)
    coeff_count = binomial(dim + degree, degree)

    # Base memory requirements (MB)
    base_memory = if precision_type == Float64Precision
        coeff_count * 8 / 1024^2  # 8 bytes per Float64
    elseif precision_type == AdaptivePrecision
        coeff_count * 16 / 1024^2  # ~16 bytes average
    elseif precision_type == RationalPrecision
        coeff_count * 64 / 1024^2  # ~64 bytes per Rational{BigInt}
    elseif precision_type == BigFloatPrecision
        coeff_count * 32 / 1024^2  # ~32 bytes per BigFloat
    end

    # Add overhead for computation
    total_memory = base_memory * 5  # 5x overhead for computation

    # Estimate computation time multiplier
    time_multiplier = if precision_type == Float64Precision
        1.0
    elseif precision_type == AdaptivePrecision
        1.5
    elseif precision_type == RationalPrecision
        8.0
    elseif precision_type == BigFloatPrecision
        4.0
    end

    return (
        memory_mb = total_memory,
        time_multiplier = time_multiplier,
        coefficient_count = coeff_count
    )
end

# Example usage
resources = estimate_hpc_resources(4, 8, AdaptivePrecision)
println("Estimated resources for 4D degree-8 with AdaptivePrecision:")
println("  Memory: $(round(resources.memory_mb, digits=1)) MB")
println("  Time multiplier: $(resources.time_multiplier)×")
```

### HPC Configuration Examples

```julia
# HPC-optimized configurations for different problem sizes

# Small problems (< 1000 coefficients)
function hpc_small_config(TR, degree)
    return Constructor(TR, degree,
        precision=Float64Precision,  # Fast execution
        basis=:chebyshev,           # Stable basis
        verbose=0                   # Minimal output
    )
end

# Medium problems (1000-10000 coefficients)
function hpc_medium_config(TR, degree)
    return Constructor(TR, degree,
        precision=AdaptivePrecision,  # Good accuracy/speed balance
        basis=:chebyshev,
        verbose=0
    )
end

# Large problems (> 10000 coefficients)
function hpc_large_config(TR, degree)
    pol = Constructor(TR, degree,
        precision=AdaptivePrecision,
        basis=:chebyshev,
        verbose=0
    )

    # Apply aggressive sparsification for large problems
    @polyvar x[1:length(TR.center)]
    mono_poly = to_exact_monomial_basis(pol, variables=x)
    analysis = analyze_coefficient_distribution(mono_poly)

    # Use more aggressive threshold for large problems
    threshold = analysis.suggested_thresholds[3]  # More aggressive
    truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)

    println("Large problem sparsification: $(round(stats.sparsity_ratio*100))% sparse")
    return truncated_poly
end
```

## Advanced Usage Patterns

### Precision Conversion

```julia
# Convert between precision types
function convert_precision(pol_source, target_precision)
    # Extract problem specification
    TR = pol_source.TestInput  # If available
    degree = pol_source.degree  # If available

    # Recreate with target precision
    pol_target = Constructor(TR, degree, precision=target_precision)

    return pol_target
end

# Compare precisions on same problem
function compare_precisions(TR, degree)
    precisions = [Float64Precision, AdaptivePrecision, RationalPrecision]
    results = Dict()

    for prec in precisions
        @time pol = Constructor(TR, degree, precision=prec)
        results[prec] = (
            l2_norm = pol.nrm,
            coeff_type = eltype(pol.coeffs),
            memory_estimate = sizeof(pol.coeffs)
        )
    end

    return results
end
```

### Precision-Aware Workflows

```julia
# Adaptive precision selection based on problem characteristics
function smart_precision_selection(f, dim, degree, sample_range)
    TR = TestInput(f, dim=dim, center=zeros(dim), sample_range=sample_range)

    # Quick Float64 test to assess problem difficulty
    pol_test = Constructor(TR, min(degree, 4), precision=Float64Precision, verbose=0)

    # Decision logic based on approximation quality
    if pol_test.nrm < 1e-12
        # Very good approximation - Float64 sufficient
        precision = Float64Precision
        println("Selected Float64Precision (excellent approximation)")
    elseif pol_test.nrm < 1e-8
        # Good approximation - AdaptivePrecision for safety
        precision = AdaptivePrecision
        println("Selected AdaptivePrecision (good approximation)")
    else
        # Poor approximation - need higher precision
        precision = AdaptivePrecision
        println("Selected AdaptivePrecision (challenging problem)")
    end

    # Create final polynomial with selected precision
    pol_final = Constructor(TR, degree, precision=precision, verbose=0)

    return pol_final
end

# Usage example
pol = smart_precision_selection(Deuflhard, 2, 8, 1.2)
```

## Best Practices

### 1. Start with AdaptivePrecision
For most applications, `Float64Precision` is sufficient:

```julia
# Recommended default approach
pol = Constructor(TR, degree, precision=AdaptivePrecision)
```

### 2. Use Float64Precision for Batch Processing
When processing many problems where speed matters:

```julia
# Batch processing example
function batch_optimize(functions, degrees)
    results = []
    for (f, deg) in zip(functions, degrees)
        TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=1.0)
        pol = Constructor(TR, deg, precision=Float64Precision)  # Fast
        push!(results, pol.nrm)
    end
    return results
end
```

### 3. Apply Sparsification with AdaptivePrecision
Combine precision and sparsification:

```julia
# Best practice workflow
function optimal_workflow(f, dim, degree)
    TR = TestInput(f, dim=dim, center=zeros(dim), sample_range=1.0)

    # Step 1: Create with AdaptivePrecision
    pol = Constructor(TR, degree, precision=AdaptivePrecision)

    # Step 2: Apply sparsification
    @polyvar x[1:dim]
    mono_poly = to_exact_monomial_basis(pol, variables=x)
    analysis = analyze_coefficient_distribution(mono_poly)

    # Step 3: Truncate if beneficial
    if analysis.dynamic_range > 1e6  # Large dynamic range
        threshold = analysis.suggested_thresholds[1]
        truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)
        println("Applied truncation: $(stats.n_kept)/$(stats.n_total) terms kept")
        return truncated_poly
    else
        return mono_poly
    end
end
```

### 4. Monitor Resource Usage
Always be aware of computational costs:

```julia
# Resource-aware construction
function monitored_constructor(TR, degree, precision_type)
    println("Creating polynomial: $(precision_type), degree $(degree)")

    # Estimate resources
    dim = length(TR.center)
    resources = estimate_hpc_resources(dim, degree, precision_type)
    println("Estimated memory: $(round(resources.memory_mb, digits=1)) MB")

    # Time the construction
    @time pol = Constructor(TR, degree, precision=precision_type)

    println("Actual L2-norm: $(pol.nrm)")
    return pol
end
```

## Summary

| Precision Type | Numeric/Symbolic | Use Case |
|----------------|------------------|----------|
| **Float64Precision** | Numeric | Fast batch processing, production workflows |
| **AdaptivePrecision** | Hybrid | High-dimensional problems, coefficient analysis |
| **RationalPrecision** | Symbolic | Exact arithmetic, symbolic computation |
| **BigFloatPrecision** | Extended Numeric | Maximum precision validation |

The precision parameter system reflects Globtim's role as a numeric/symbolic interface, allowing you to choose the right precision strategy for each stage of your computation.
