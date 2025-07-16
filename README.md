![Run Tests](https://github.com/gescholt/globtim.jl/actions/workflows/test.yml/badge.svg)

# Globtim.jl

**Global optimization of continuous functions via polynomial approximation**

Globtim finds **all local minima** of continuous functions over compact domains using Chebyshev/Legendre polynomial approximation and critical point analysis. Version 1.1.0 introduces comprehensive Hessian-based critical point classification and enhanced statistical analysis capabilities.

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

## 📦 What's Included

### ✅ Core Package Features
- **Polynomial Approximation Engine**: Chebyshev and Legendre basis functions with adaptive sampling
- **Critical Point Analysis**: Complete eigenvalue decomposition and classification of all stationary points
- **Enhanced BFGS Refinement**: Adaptive tolerance selection based on function values with comprehensive convergence tracking
- **Statistical Analysis Framework**: Generates publication-quality tables with eigenvalue statistics, condition numbers, and basin analysis
- **Built-in Test Functions**: Deuflhard, Rastringin, HolderTable, tref_3d, and more for benchmarking
- **ForwardDiff Integration**: Automatic differentiation for gradient and Hessian computation
- **Memory-Efficient Implementation**: Optimized data structures for large-scale problems

### 🔧 Optional Extensions
- **Visualization Suite**: Advanced plotting functions that activate when CairoMakie or GLMakie are loaded
- **Interactive Analysis**: Real-time exploration of eigenvalue spectra and critical point distributions

## 📊 Project Status

### ✅ Version 1.1.0: Enhanced Critical Point Analysis
After solving the polynomial system to find critical points, version 1.1.0 provides comprehensive tools for refinement and verification:

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
- **For visualization**: `add CairoMakie` or `add GLMakie`
- **For exact solving**: Install [Msolve](https://msolve.lip6.fr/) for symbolic polynomial system solving

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

- **Examples**: [Examples/Notebooks/](Examples/Notebooks/) - Jupyter notebook demonstrations
- **API Documentation**: Available via `?` in Julia REPL
- **Source Code**: [GitHub Repository](https://github.com/gescholt/globtim.jl)

## 🤝 Contributors

**Authors**
- Georgy Scholten 
- Claude (Anthropic) [Hessian analysis, statistical tables, enhanced visualization features]

**Contributors**
- Alexander Demin 

## 📄 License

See [LICENSE](LICENSE) file for details.
