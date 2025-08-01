# Globtim.jl

[![Run Tests](https://github.com/gescholt/Globtim.jl/actions/workflows/test.yml/badge.svg)](https://github.com/gescholt/Globtim.jl/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://gescholt.github.io/Globtim.jl/stable/)
[![Julia 1.11](https://img.shields.io/badge/julia-1.11+-blue.svg)](https://julialang.org/downloads/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![GitHub release](https://img.shields.io/github/v/release/gescholt/Globtim.jl.svg)](https://github.com/gescholt/Globtim.jl/releases/latest)

**Global optimization of continuous functions via polynomial approximation**

Globtim finds **all local minima** of continuous functions over compact domains using Chebyshev/Legendre polynomial approximation and critical point analysis. Version 1.1.1 introduces comprehensive Hessian-based critical point classification and enhanced statistical analysis capabilities.

## 🚀 Quick Start

```julia
using Globtim, DynamicPolynomials, DataFrames

# Define problem
f = Deuflhard  # Built-in test function
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

# Step 1: Polynomial approximation and critical point finding
pol = Constructor(TR, 8)  # Degree 8 approximation (pol.nrm contains L2-norm error)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Step 2: Enhanced analysis with automatic classification
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# Step 3: Generate statistical reports (optional)
df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(
    f, df, TR, enable_hessian=true, show_tables=true
)
```

## ✨ Key Features

### Core Algorithm
1. **Sample**: Function evaluation on tensorized Chebyshev/Legendre grids
2. **Approximate**: Polynomial construction via discrete least squares (returns L2-norm approximation error)
3. **Solve**: Critical point finding using [HomotopyContinuation.jl](https://www.juliahomotopycontinuation.org/) or [Msolve](https://msolve.lip6.fr/)
4. **Sparsify**: NEW! Reduce polynomial complexity while preserving accuracy

### NEW: Hessian-Based Critical Point Classification
The enhanced `analyze_critical_points` function now provides:
- **Automatic Classification**: Categorizes each critical point as :minimum, :maximum, :saddle, or :degenerate based on Hessian eigenvalues
- **Comprehensive Eigenvalue Analysis**: 
  - Complete eigenvalue spectrum for each critical point
  - Condition number κ(H) = |λ_max|/|λ_min| for numerical stability assessment
  - Determinant and trace of Hessian matrix
  - Specialized eigenvalues: smallest positive (for minima) and largest negative (for maxima)
- **Robust Computation**: Uses ForwardDiff.jl for automatic differentiation, ensuring accurate Hessian matrices
- **Enhanced Refinement**: Improved BFGS optimization with hyperparameter tracking and convergence analysis

### NEW: Statistical Analysis and Reporting
The `analyze_critical_points_with_tables` function provides detailed metrics:

**Key Statistics Computed:**
- **L2-norm of polynomial approximation**: Measures the approximation quality over the domain
- **Distance metrics between critical points**: 
  - `point_improvement`: ||x_refined - x_initial|| (distance from polynomial critical point to refined point)
  - `nearest_neighbor_dist`: Minimum distance to other critical points
  - `distance_to_expected`: Distance to known global minima (when provided)
- **Convergence quality indicators**:
  - `gradient_norm`: ||∇f|| at critical points (should be ≈ 0 for true critical points)
  - `value_improvement`: |f(x_refined) - f(x_initial)| (function value refinement)
  - `converged`: Boolean indicating successful BFGS convergence within domain
- **Numerical stability metrics**:
  - `hessian_condition_number`: κ(H) for assessing numerical reliability
  - Basin statistics: How many initial points converge to each minimum

**Output Formats:**
- ASCII tables with all metrics organized by critical point type
- Export to CSV, LaTeX, or Markdown for publication
- Statistical summaries (mean, std, min/max) for each metric category

### Visualization (Extension-Based)
```julia
using CairoMakie  # Load before calling visualization functions
plot_hessian_norms(df_enhanced)                    # Scatter plot of ||H||_F
plot_condition_numbers(df_enhanced)                # Log-scale condition numbers
plot_critical_eigenvalues(df_enhanced)             # Minima/maxima eigenvalue validation
plot_all_eigenvalues(f, df_enhanced)               # Complete eigenvalue spectrum (NEW!)
```

### NEW: AdaptivePrecision for Extended Precision Polynomial Expansion

Globtim introduces **AdaptivePrecision**, a hybrid precision system that combines Float64 performance with BigFloat accuracy for polynomial coefficient manipulation:

**Key Benefits:**
- **Hybrid Performance**: Float64 for function evaluation (fast), BigFloat for polynomial expansion (accurate)
- **Extended Precision**: BigFloat coefficients enable accurate manipulation of coefficients with extreme magnitude ranges
- **Smart Sparsification**: Enhanced coefficient truncation with extended precision analysis
- **Seamless Integration**: Drop-in replacement for existing workflows

**Basic Usage:**
```julia
using Globtim, DynamicPolynomials

# Standard workflow with AdaptivePrecision
f = shubert_4d  # 4D test function
TR = test_input(f, dim=4, center=[0.0, 0.0, 0.0, 0.0], sample_range=2.0)

# Use AdaptivePrecision for construction
pol = Constructor(TR, 8, precision=AdaptivePrecision)  # BigFloat coefficients

# Convert to monomial basis (where precision conversion happens)
@polyvar x[1:4]
mono_poly = to_exact_monomial_basis(pol, variables=x)  # BigFloat coefficients

# Advanced coefficient analysis
analysis = analyze_coefficient_distribution(mono_poly)
println("Dynamic range: $(analysis.dynamic_range)")
println("Suggested thresholds: $(analysis.suggested_thresholds)")

# Smart truncation with extended precision
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, 1e-12)
println("Achieved $(round(stats.sparsity_ratio*100, digits=1))% sparsity")
```

**Precision Types:**
- `Float64Precision` (default): Standard Float64 arithmetic
- `AdaptivePrecision` (new): Hybrid Float64/BigFloat system

### NEW: Polynomial Sparsification and Exact Arithmetic

Enhanced sparsification tools with extended precision support:

**Key Capabilities:**
- **Exact Conversion**: Transform polynomials from Chebyshev/Legendre basis to exact monomial form
- **Intelligent Sparsification**: Remove small coefficients while tracking approximation quality
- **Extended Precision Analysis**: BigFloat coefficient analysis for extreme dynamic ranges
- **L2-Norm Tracking**: Monitor the error introduced by sparsification at each step
- **Memory Efficiency**: Reduce polynomial complexity for faster evaluation and storage

**Example:**
```julia
using Globtim, DynamicPolynomials

# Create polynomial approximation with AdaptivePrecision
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8, precision=AdaptivePrecision)  # Extended precision

# Convert to exact monomial basis
@polyvar x y
mono_poly = to_exact_monomial_basis(pol, variables=[x, y])

# Advanced coefficient analysis
analysis = analyze_coefficient_distribution(mono_poly)
println("Dynamic range: $(analysis.dynamic_range)")

# Smart truncation with optimal threshold
threshold = analysis.suggested_thresholds[1]
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)

# Results
println("Original terms: $(stats.n_total)")
println("Kept terms: $(stats.n_kept)")
println("Achieved $(round(stats.sparsity_ratio*100, digits=1))% sparsity")
println("Largest removed: $(stats.largest_removed)")
```

## 📦 What's Included

### ✅ Core Package Features
- **Polynomial Approximation Engine**: Chebyshev and Legendre basis functions with adaptive sampling
- **Anisotropic Grid Support**: Automatic detection and optimized handling of grids with different nodes per dimension
- **Critical Point Analysis**: Complete eigenvalue decomposition and classification of all stationary points
- **Enhanced BFGS Refinement**: Adaptive tolerance selection based on function values with comprehensive convergence tracking
- **Statistical Analysis Framework**: Generates publication-quality tables with eigenvalue statistics, condition numbers, and basin analysis
- **Built-in Test Functions**: Deuflhard, Rastringin, HolderTable, tref_3d, and more for benchmarking
- **ForwardDiff Integration**: Automatic differentiation for gradient and Hessian computation
- **Memory-Efficient Implementation**: Optimized data structures for large-scale problems

### 🔧 Optional Extensions
- **Visualization Suite**: Advanced plotting functions that activate when CairoMakie or GLMakie are loaded
- **Interactive Analysis**: Real-time exploration of eigenvalue spectra and critical point distributions

### NEW: 4D Testing Framework and Development Tools

Comprehensive testing infrastructure for high-dimensional AdaptivePrecision development:

**Development Environment:**
- **Interactive Jupyter Notebook**: `Examples/Notebooks/AdaptivePrecision_4D_Development.ipynb`
- **Revise.jl Integration**: Automatic code reloading for seamless development
- **Performance Profiling**: Detailed runtime breakdown and bottleneck identification
- **Systematic Parameter Studies**: Automated testing across degrees and sample sizes
- **High-Quality Plotting**: CairoMakie integration for publication-ready figures

**Testing Framework:**
```julia
# Load the 4D testing framework
include("test/adaptive_precision_4d_framework.jl")

# Quick verification test
results = run_4d_quick_test()

# Comprehensive comparison study
comparison_df = run_4d_precision_comparison()
generate_4d_test_report(comparison_df)

# Sparsity analysis
analysis, mono_f64, mono_adaptive = analyze_4d_sparsity(:sparse)

# Performance benchmarking
benchmark_results = benchmark_4d_construction(:gaussian, degree=6, samples=100)
```

**Available Test Functions:**
- `:gaussian` - Smooth, well-behaved 4D Gaussian
- `:polynomial_exact` - Exact polynomial for accuracy testing
- `:shubert` - Complex 4D Shubert optimization landscape
- `:sparse` - Natural sparsity structure for truncation testing
- `:mixed_frequency` - Multiple scales for sparsity analysis

**Development Script:**
```julia
# Quick command-line testing
julia --project=. Examples/adaptive_precision_4d_dev.jl

# Or in REPL
include("Examples/adaptive_precision_4d_dev.jl")
quick_shubert_test(degree=6, samples=100)
```

## 📊 Project Status

### ✅ Version 1.1.1: Enhanced Critical Point Analysis
After solving the polynomial system to find critical points, version 1.1.1 provides comprehensive tools for refinement and verification:

- **Critical Point Refinement**: BFGS optimization refines the approximate critical points from polynomial solving to machine precision
- **Hessian-Based Verification**: Eigenvalue analysis validates and classifies each critical point (minimum, maximum, saddle, or degenerate)
- **Statistical Quality Assessment**: Generates detailed reports on the numerical quality of critical points, including condition numbers and convergence metrics
- **Robustness Analysis**: Tracks which critical points successfully converge to local minima and identifies numerical issues
- **Comprehensive Testing**: Full test suite validates the refinement and classification pipeline 

## 🔧 Installation

```julia
julia> ]
pkg> add Globtim
```

### Optional Dependencies
- **For visualization**: `add CairoMakie` (static plots) or `add GLMakie` (interactive plots)
- **For exact solving**: Install [Msolve](https://msolve.lip6.fr/) for symbolic polynomial system solving
- **For enhanced benchmarking**: `add BenchmarkTools` (enables detailed performance analysis in 4D framework)
- **For development profiling**: `add ProfileView` (interactive performance profiling in notebooks)

## 📚 Examples

### Basic Usage
```julia
using Globtim, DynamicPolynomials

# 2D Deuflhard function analysis
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Enhanced analysis with classification
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
println("Found $(nrow(df_min)) unique local minima")
```

### Verification with ForwardDiff
```julia
using ForwardDiff

# Verify critical points by checking gradient norms
for row in eachrow(df_enhanced)
    x = collect(row[:, r"x_"])  # Extract coordinates
    grad_norm = norm(ForwardDiff.gradient(f, x))
    println("Point $(row.unique_id): ||∇f|| = $(grad_norm)")
    
    # Check Hessian eigenvalues for classification
    H = ForwardDiff.hessian(f, x)
    eigenvals = eigvals(H)
    if all(eigenvals .> 0)
        println("  → Confirmed minimum (all eigenvalues positive)")
    elseif all(eigenvals .< 0)
        println("  → Confirmed maximum (all eigenvalues negative)")
    else
        println("  → Confirmed saddle point (mixed eigenvalues)")
    end
end
```

### AdaptivePrecision Usage
```julia
using Globtim, DynamicPolynomials

# 4D Shubert function with AdaptivePrecision
f = shubert_4d
TR = test_input(f, dim=4, center=[0.0, 0.0, 0.0, 0.0], sample_range=2.0)

# Construct with extended precision
pol = Constructor(TR, 8, precision=AdaptivePrecision)
println("L2 norm: $(pol.nrm)")
println("Coefficient type: $(eltype(pol.coeffs))")  # Float64 (for performance)

# Convert to monomial basis (BigFloat coefficients)
@polyvar x[1:4]
mono_poly = to_exact_monomial_basis(pol, variables=x)
coeffs = [coefficient(t) for t in terms(mono_poly)]
println("Monomial coefficient type: $(typeof(coeffs[1]))")  # BigFloat (for accuracy)

# Coefficient analysis and smart truncation
analysis = analyze_coefficient_distribution(mono_poly)
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, 1e-12)
println("Sparsity achieved: $(round(stats.sparsity_ratio*100, digits=1))%")
```

### Statistical Analysis
```julia
# Generate comprehensive statistical tables
df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(
    f, df, TR,
    enable_hessian=true,
    show_tables=true,
    table_types=[:minimum, :saddle, :maximum]
)
```

### Visualization
```julia
using CairoMakie  # Enable visualization extension

# Plot Hessian analysis results
fig1 = plot_hessian_norms(df_enhanced)
fig2 = plot_condition_numbers(df_enhanced)
fig3 = plot_critical_eigenvalues(df_enhanced)

# Enhanced eigenvalue visualization (separate subplots, vertically aligned with dotted connections)
fig4 = plot_all_eigenvalues(f, df_enhanced, sort_by=:magnitude)      # Preserves signs
fig5 = plot_all_eigenvalues(f, df_enhanced, sort_by=:abs_magnitude)  # Absolute values
fig6 = plot_all_eigenvalues(f, df_enhanced, sort_by=:spread)         # Ordered by eigenvalue range

# Raw vs refined eigenvalue comparison (NEW!)
fig7 = plot_raw_vs_refined_eigenvalues(f, df_raw, df_enhanced)       # Distance-ordered pairs
fig8 = plot_raw_vs_refined_eigenvalues(f, df_raw, df_enhanced, sort_by=:function_value_diff)
```

## 📖 Documentation

- **Official Documentation**: [https://gescholt.github.io/Globtim.jl/stable/](https://gescholt.github.io/Globtim.jl/stable/)
- **Examples**: See example code in this README and the [Examples/](Examples/) directory
- **API Documentation**: Available via `?` in Julia REPL
- **Source Code**: [GitHub Repository](https://github.com/gescholt/Globtim.jl)

### 🚀 Quick Reference: New Features

**AdaptivePrecision System:**
```julia
# Basic usage
pol = Constructor(TR, degree, precision=AdaptivePrecision)
mono_poly = to_exact_monomial_basis(pol, variables=x)

# Coefficient analysis
analysis = analyze_coefficient_distribution(mono_poly)
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)
```

**4D Testing Framework:**
```julia
# Load framework
include("test/adaptive_precision_4d_framework.jl")

# Quick functions
help_4d()                    # Show all available functions
quick_test()                 # Fast verification test
compare_precisions()         # Full comparison study
sparsity_analysis(:sparse)   # Coefficient truncation analysis
```

**Development Environment:**
- **Notebook**: `Examples/Notebooks/AdaptivePrecision_4D_Development.ipynb`
- **Script**: `Examples/adaptive_precision_4d_dev.jl`
- **Framework**: `test/adaptive_precision_4d_framework.jl`

## 🤝 Contributors

**Authors**
- Georgy Scholten
- Claude (Anthropic) [Hessian analysis, statistical tables, enhanced visualization features, AdaptivePrecision system, 4D testing framework]

**Contributors**
- Alexander Demin 

## 📄 License

See [LICENSE](LICENSE) file for details.
