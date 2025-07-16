# Getting Started

This guide walks you through the basic usage of Globtim.jl for finding all local minima of continuous functions.

## Basic Workflow

The typical Globtim workflow consists of three main steps:

### 1. Define the Problem

```julia
using Globtim, DynamicPolynomials, DataFrames

# Use a built-in test function
f = Deuflhard  

# Or define your own
f(x) = x[1]^2 + sin(5*x[1]) + x[2]^2 + sin(5*x[2])

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

# Process solutions
df = process_crit_pts(solutions, f, TR)
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

- See [Core Algorithm](core_algorithm.md) for details on the polynomial approximation method
- See [Critical Point Analysis](critical_point_analysis.md) for advanced refinement options
- See [Examples](examples.md) for complete working examples
- See [API Reference](api_reference.md) for detailed function documentation