![Run Tests](https://github.com/gescholt/globtim.jl/actions/workflows/test.yml/badge.svg)

# Globtim.jl

**Global optimization of continuous functions via polynomial approximation**

Globtim finds **all local minima** of continuous functions over compact domains using Chebyshev/Legendre polynomial approximation and critical point analysis.

## 🚀 Quick Start

```julia
using Globtim, DynamicPolynomials, DataFrames

# Define problem
f = Deuflhard  # Built-in test function
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

# Phase 1: Polynomial approximation
pol = Constructor(TR, 8)  # Degree 8 approximation
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Phase 2: Enhanced analysis with Hessian classification
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# Phase 3: Statistical tables (optional)
df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(
    f, df, TR, enable_hessian=true, show_tables=true
)
```

## ✨ Key Features

### Core Algorithm (3 Steps)
1. **Sample**: Function evaluation on tensorized Chebyshev/Legendre grids
2. **Approximate**: Polynomial construction via discrete least squares
3. **Solve**: Critical point finding using HomotopyContinuation.jl or Msolve

### Phase 2: Hessian-Based Critical Point Classification
- **Automatic Classification**: :minimum, :maximum, :saddle, :degenerate, :error
- **Eigenvalue Analysis**: Complete statistics and numerical validation
- **Mathematical Verification**: Specialized eigenvalues for minima/maxima validation
- **ForwardDiff Integration**: Robust automatic differentiation for Hessian computation

### Phase 3: Enhanced Statistical Analysis
- **Publication-Quality Tables**: ASCII tables with comprehensive statistics
- **Condition Number Analysis**: Numerical stability assessment
- **Export Capabilities**: Multiple formats for documentation and reporting
- **Comparative Analysis**: Multi-type statistical summaries

### Visualization (Extension-Based)
```julia
using CairoMakie  # Load before calling visualization functions
plot_hessian_norms(df_enhanced)           # Scatter plot of ||H||_F
plot_condition_numbers(df_enhanced)       # Log-scale condition numbers
plot_critical_eigenvalues(df_enhanced)    # Minima/maxima eigenvalue validation
```

## 📦 What's Included

### ✅ Core Package (Always Available)
- **All computational features**: polynomial approximation, critical point finding
- **Phase 2 Hessian analysis**: complete eigenvalue-based classification
- **Phase 3 statistical tables**: ASCII rendering with no external dependencies
- **Comprehensive test functions**: Deuflhard, Rastringin, HolderTable, tref_3d, etc.
- **Flexible degree formats**: backward-compatible with enhanced control

### 🔧 Extensions (Require External Loading)
- **Visualization functions**: Require `using CairoMakie` or `using GLMakie`
- **Interactive plotting**: Auto-loads when Makie backends are imported

## 📊 Project Status

### ✅ Stable Features
- Core polynomial approximation with type-stable implementation
- HomotopyContinuation.jl and Msolve integration
- Complete Phase 2 Hessian classification pipeline
- Phase 3 statistical table system with export capabilities
- Comprehensive testing and validation framework

### 🔄 Active Development
- Performance optimization for large-scale problems
- Extended visualization capabilities
- Additional statistical export formats 

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
```

## 📖 Documentation

- **Complete Guide**: [CLAUDE.md](CLAUDE.md) - Comprehensive AI assistant development guide
- **Certification Examples**: [Examples/ForwardDiff_Certification/](Examples/ForwardDiff_Certification/) - Phase 2/3 validation suite
- **Jupyter Notebooks**: [Examples/Notebooks/](Examples/Notebooks/) - Interactive demonstrations

## 🤝 Contributing

This package is in active development. See [CLAUDE.md](CLAUDE.md) for detailed development guidelines and AI assistant instructions.

## 📄 License

See [LICENSE](LICENSE) file for details.
