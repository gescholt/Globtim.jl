# Getting Started

This guide walks you through the basic usage of Globtim.jl for finding all local minima of continuous functions.

## Basic Workflow

The typical Globtim workflow consists of three main steps:

### 1. Define the Problem

```julia
using Globtim, DynamicPolynomials, DataFrames

# Use a built-in test function
f = Deuflhard

# Or define your own function
my_function(x) = x[1]^2 + sin(5*x[1]) + x[2]^2 + sin(5*x[2])

# Create test input specification
TR = test_input(
    f,                    # Objective function
    dim=2,               # Dimension
    center=[0.0, 0.0],   # Domain center
    sample_range=1.2     # Domain radius
)
```

### 2. Find Critical Points

```julia
# Create polynomial approximation
pol = Constructor(TR, 8)  # Degree 8 polynomial
println("L2-norm approximation error: ", pol.nrm)

# Set up polynomial variables
@polyvar x[1:2]

# Solve polynomial system for critical points
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
# Alternative: Use the new convenience method
# solutions = solve_polynomial_system(x, pol)  # Automatically extracts dimension and degree

# Process solutions
df = process_crit_pts(solutions, f, TR)
# Note: For 1D functions with scalar input (like sin, cos), process_crit_pts 
# automatically handles the conversion between scalar and vector formats
println("Found $(nrow(df)) critical points")
```

### 3. Refine and Classify

```julia
# Enhanced analysis with Hessian classification
df_enhanced, df_min = analyze_critical_points(
    f, df, TR,
    enable_hessian=true,      # Enable eigenvalue analysis
    verbose=true,             # Show progress
    tol_dist=0.025           # Clustering tolerance
)

println("Found $(nrow(df_min)) unique local minima")

# Check classifications
println("Critical point types:")
for type in unique(df_enhanced.critical_point_type)
    count = sum(df_enhanced.critical_point_type .== type)
    println("  $type: $count points")
end
```

## Domain Specification

Globtim supports both uniform and non-uniform domain scaling:

### Uniform Scaling
```julia
# Square/cube domain
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)
# Domain: [-1, 1] × [-1, 1]
```

### Non-uniform Scaling
```julia
# Rectangular domain
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=[2.0, 1.0])
# Domain: [-2, 2] × [-1, 1]
```

## Polynomial Degree Selection

Higher polynomial degrees provide better approximation but increase computational cost:

```julia
# Compare different degrees
for degree in [4, 6, 8, 10]
    pol = Constructor(TR, degree)
    println("Degree $degree: L2-norm error = $(pol.nrm)")
end
```

## Precision Parameter Options

Globtim supports multiple precision types for different performance vs accuracy trade-offs. The precision parameter controls how polynomial coefficients are computed and stored.

### Available Precision Types

#### 1. Float64Precision (Default for most cases)
Standard double-precision floating-point arithmetic. Best for general use.

```julia
# Explicit Float64 precision (default)
pol = Constructor(TR, 8, precision=Float64Precision)
println("Coefficient type: $(eltype(pol.coeffs))")  # Float64
```

#### 2. AdaptivePrecision (Recommended for high accuracy)
Uses Float64 for function evaluation (performance) and BigFloat for coefficient manipulation (accuracy). Ideal for extended precision without full performance penalty.

```julia
# AdaptivePrecision for better accuracy
pol = Constructor(TR, 8, precision=AdaptivePrecision)
println("Raw coefficients: $(eltype(pol.coeffs))")  # Float64 (for performance)

# Convert to extended precision monomial basis
@polyvar x[1:2]
mono_poly = to_exact_monomial_basis(pol, variables=x)
coeffs = [coefficient(t) for t in terms(mono_poly)]
println("Monomial coefficients: $(typeof(coeffs[1]))")  # BigFloat (for accuracy)
```

#### 3. RationalPrecision (For exact arithmetic)
Uses rational numbers with arbitrary precision. Best for problems requiring exact representations.

```julia
# Rational precision for exact arithmetic
pol = Constructor(TR, 8, precision=RationalPrecision)
println("Coefficient type: $(eltype(pol.coeffs))")  # Rational{BigInt}
```

#### 4. BigFloatPrecision (For maximum precision)
Uses BigFloat throughout. Highest accuracy but slowest performance.

```julia
# BigFloat precision for maximum accuracy
pol = Constructor(TR, 8, precision=BigFloatPrecision)
println("Coefficient type: $(eltype(pol.coeffs))")  # BigFloat
```

### Choosing the Right Precision

| Precision Type | Performance | Accuracy | Memory Usage | Best For |
|----------------|-------------|----------|--------------|----------|
| Float64Precision | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | General use, fast computation |
| AdaptivePrecision | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | High accuracy with good performance |
| RationalPrecision | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | Exact arithmetic, symbolic computation |
| BigFloatPrecision | ⭐ | ⭐⭐⭐⭐⭐ | ⭐ | Maximum precision requirements |

### Precision Examples

```julia
# Compare precision types on the same problem
f = x -> x[1]^2 + sin(5*x[1]) + x[2]^2 + sin(5*x[2])
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

# Standard precision
pol_std = Constructor(TR, 8, precision=Float64Precision)
println("Float64 L2-norm: $(pol_std.nrm)")

# Adaptive precision (recommended)
pol_adaptive = Constructor(TR, 8, precision=AdaptivePrecision)
println("Adaptive L2-norm: $(pol_adaptive.nrm)")

# Rational precision
pol_rational = Constructor(TR, 8, precision=RationalPrecision)
println("Rational L2-norm: $(pol_rational.nrm)")
```

### Integration with Coefficient Truncation and Sparsity

AdaptivePrecision works seamlessly with Globtim's sparsification features for polynomial complexity reduction:

```julia
# Create polynomial with AdaptivePrecision
pol = Constructor(TR, 10, precision=AdaptivePrecision)

# Convert to monomial basis for analysis
@polyvar x[1:2]
mono_poly = to_exact_monomial_basis(pol, variables=x)

# Analyze coefficient distribution
analysis = analyze_coefficient_distribution(mono_poly)
println("Total terms: $(analysis.n_total)")
println("Dynamic range: $(analysis.dynamic_range)")
println("Suggested thresholds: $(analysis.suggested_thresholds)")

# Apply adaptive truncation
threshold = analysis.suggested_thresholds[1]
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)
println("Kept $(stats.n_kept)/$(stats.n_total) terms ($(round(stats.sparsity_ratio*100, digits=1))% sparse)")
```

### Special Considerations

#### High-Dimensional Problems
For problems with dimension ≥ 4, consider:
- Start with `AdaptivePrecision` for good accuracy/performance balance
- Use coefficient truncation to manage polynomial complexity
- Monitor memory usage with higher degrees

```julia
# High-dimensional example
f_4d = x -> sum(x.^2) + 0.1*prod(sin.(5*π*x))
TR_4d = test_input(f_4d, dim=4, center=zeros(4), sample_range=1.0)

# AdaptivePrecision recommended for 4D+
pol_4d = Constructor(TR_4d, 6, precision=AdaptivePrecision)
println("4D polynomial L2-norm: $(pol_4d.nrm)")
```

#### HPC Cluster Usage
When running on HPC clusters:
- `Float64Precision`: Fastest, lowest memory usage
- `AdaptivePrecision`: Good balance for production runs
- Avoid `RationalPrecision` for large-scale computations (memory intensive)

```julia
# HPC-optimized configuration
pol_hpc = Constructor(TR, 8,
    precision=AdaptivePrecision,  # Good accuracy/performance balance
    basis=:chebyshev,            # Generally more stable
    verbose=0                    # Reduce output for batch jobs
)
```

## Built-in Test Functions

Globtim includes several standard test functions:

- `Deuflhard` - Challenging 2D function with multiple minima
- `Rastringin` - Classic multimodal benchmark
- `HolderTable` - 2D function with 4 global minima
- `tref_3d` - 3D test function
- `Beale`, `Rosenbrock`, `Branin` - Standard optimization benchmarks

Example:
```julia
# Test on Rastringin function
f = Rastringin
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=5.12)
# ... continue with standard workflow
```

## Next Steps

- See [Precision Parameters](precision_parameters.md) for detailed precision type documentation
- See [Core Algorithm](core_algorithm.md) for details on the polynomial approximation method
- See [Critical Point Analysis](critical_point_analysis.md) for advanced refinement options
- See [Sparsification](sparsification.md) for polynomial complexity reduction techniques
- See [Examples](examples.md) for complete working examples
- See [API Reference](api_reference.md) for detailed function documentation