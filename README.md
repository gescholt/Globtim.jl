# Globtim - Global Optimization via Polynomial Approximation

A Julia package for global optimization using polynomial approximation methods.

## What is Globtim?

Globtim finds all local minima of a nonlinear function by:
1. Constructing a polynomial approximation of your function
2. Computing all critical points of the polynomial
3. Filtering and refining to identify local minima

This approach guarantees finding all minima within a bounded domain, unlike gradient-based methods that find only one minimum.

## Installation

```julia
using Pkg
Pkg.add("Globtim")
```

For the latest development version:
```julia
Pkg.add(url="https://github.com/gescholt/Globtim.jl")
```

## Quick Start

```julia
using Globtim, DynamicPolynomials

# Define a test function (or use your own)
f = Deuflhard  # Built-in test function

# Define domain: center and sampling range
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

# Create polynomial approximation (degree 8)
pol = Constructor(TR, 8, precision=AdaptivePrecision)
println("L2-norm approximation error: $(pol.nrm)")

# Find all critical points
@polyvar x[1:2]
solutions = solve_polynomial_system(x, pol)
df = process_crit_pts(solutions, f, TR)

# Identify local minima
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
println("Found $(nrow(df_min)) local minima")
```

## Polynomial Basis Options

Globtim supports two orthogonal polynomial basis types:

- **`:chebyshev`** (default): Chebyshev polynomials - standard choice, well-tested
- **`:legendre`**: Legendre polynomials - often better conditioning (lower condition numbers)

```julia
# Specify basis in Constructor
pol = Constructor(TR, 8, basis=:chebyshev, precision=AdaptivePrecision)  # Default
pol = Constructor(TR, 8, basis=:legendre, precision=AdaptivePrecision)   # Alternative
```

**When to use Legendre?** Recent experiments show Legendre can achieve:
- Lower condition numbers (2-3x better)
- Comparable or better L2 approximation error
- Similar computational performance

## Precision Control

Globtim supports multiple precision types for balancing accuracy and performance:

- **`Float64Precision`**: Standard double precision, fastest
- **`AdaptivePrecision`**: Hybrid (Float64 evaluation, BigFloat coefficients) - **recommended**
- **`RationalPrecision`**: Exact rational arithmetic for symbolic work
- **`BigFloatPrecision`**: Maximum precision for research

```julia
# Specify precision in Constructor
pol = Constructor(TR, 8, precision=AdaptivePrecision)
```

## Workflow: From Setup to Results

### 1. Define Your Problem
```julia
# Use a built-in test function or define your own
f(x) = sum(x.^4) - sum(x.^2)  # Custom function
# OR
f = Deuflhard  # Built-in function
```

### 2. Set Up Domain
```julia
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
```

### 3. Create Polynomial Approximation
```julia
pol = Constructor(TR, degree=8, precision=AdaptivePrecision)
```

### 4. Solve for Critical Points
```julia
@polyvar x[1:2]
solutions = solve_polynomial_system(x, pol)
df = process_crit_pts(solutions, f, TR)
```

### 5. Process Results
```julia
# Filter and analyze critical points
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# Export results
using CSV
CSV.write("local_minima.csv", df_min)
```

Results include:
- `critical_points.csv`: All critical points with function values
- `local_minima.csv`: Filtered local minima with Hessian eigenvalues
- Timing and performance metrics

## Extensions

Globtim provides optional extensions that are automatically loaded when their trigger packages are present:

### GPU Acceleration (GlobtimCUDAExt)
```julia
using Globtim, CUDA  # Automatically loads GPU extension
Globtim.gpu_available()  # Check GPU availability
```

### Analysis Extension (GlobtimAnalysisExt)
```julia
using Globtim, Clustering, Distributions  # Loads analysis extension
cluster_critical_points(points; k=3)  # K-means clustering
statistical_analysis(data)  # Distribution fitting
```

## Related Packages

Globtim produces critical point candidates. For analysis and refinement, use these companion packages:

### GlobtimPostProcessing - Analysis & Refinement

Refines raw critical points from polynomial approximation into verified critical points with high accuracy (~1e-12).

```julia
using GlobtimPostProcessing

# Load experiment results from globtim output
result = load_experiment_results("/path/to/experiment")

# Refine critical points (requires your objective function)
refined = refine_experiment_results(
    "/path/to/experiment",
    my_objective_function
)
```

**Key features:**
- Critical point refinement via local optimization (BFGS/Nelder-Mead)
- Gradient validation (verify ||∇f(x*)|| ≈ 0)
- Parameter recovery analysis
- Quality diagnostics (L2 error, stagnation detection)

Install: `Pkg.add(url="https://github.com/gescholt/GlobtimPostProcessing.jl")`

See [Examples/POST_PROCESSING_GUIDE.md](Examples/POST_PROCESSING_GUIDE.md) for detailed workflow.

### GlobtimPlots - Visualization

Creates publication-quality figures and interactive visualizations from globtim and GlobtimPostProcessing results.

```julia
using GlobtimPlots, CairoMakie

# Backend selection
CairoMakie.activate!()  # Static (PDF/PNG)
# GLMakie.activate!()   # Interactive

# Visualize critical points
fig = plot_critical_points(df_min)
save("minima.pdf", fig)

# Level set visualization
fig = create_level_set_visualization(pol, TR, solutions)
save("levelset.png", fig)

# Convergence analysis
fig = plot_convergence_analysis(degrees, l2_errors)
save("convergence.pdf", fig)
```

**Key features:**
- Level set and polynomial surface visualization (2D/3D)
- Convergence analysis plots (L2 error vs degree)
- Critical point scatter and Hessian eigenvalue plots
- Campaign comparison across experiments
- RL training dashboards and policy evolution
- Subdivision tree visualization
- 1D polynomial approximation plots
- Animation generation (flyover, rotation)
- Publication-ready PDF/PNG export

Install: `Pkg.add(url="https://github.com/gescholt/GlobtimPlots.jl")`

See [GlobtimPlots documentation](https://gescholt.github.io/Globtim.jl/stable/globtimplots/) for detailed workflow.

## Repository Organization

```
Globtim.jl/
├── src/                          # Core package source code
│   ├── Globtim.jl               # Main module
│   ├── ApproxConstruct.jl       # Polynomial construction
│   ├── hom_solve.jl             # Homotopy continuation solver
│   └── ...
│
├── ext/                          # Package extensions
│   ├── GlobtimCUDAExt.jl        # GPU acceleration
│   └── GlobtimAnalysisExt.jl    # Clustering/statistics
│
├── Examples/                     # Usage examples
│   └── Notebooks/               # Jupyter notebooks
│
├── test/                         # Test suite
└── docs/                         # Documentation
```

## License

GPL-3.0
