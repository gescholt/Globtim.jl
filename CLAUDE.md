# CLAUDE.md - Globtim Development Guide

Structured guidance for AI assistants working with the Globtim Julia package for global optimization via polynomial approximation.

## 🎯 Project Overview

**Globtim.jl** finds all local minima of continuous functions over compact domains using:
- Chebyshev/Legendre polynomial approximation 
- Critical point analysis via HomotopyContinuation.jl or Msolve
- Phase 2: Hessian-based classification with ForwardDiff.jl
- Phase 3: Statistical analysis with publication-quality tables

## 📚 Julia Programming Patterns & Lessons Learned

### 1. **Type Stability & Performance**
```julia
# LEARNED: pol.degree can be Tuple or Int - handle both cases
actual_degree = pol.degree isa Tuple ? pol.degree[2] : pol.degree

# PATTERN: Use concrete types in critical paths
function process_points(points::Vector{Vector{Float64}}, values::Vector{Float64})
    # Not Vector{Vector{T}} where T for performance
end
```

### 2. **Module Activation & Paths**
```julia
# PATTERN: Proper package activation for examples
using Pkg; using Revise
Pkg.activate(joinpath(@__DIR__, "../"))  # Go up from Examples/
using Globtim

# AVOID: Hardcoded paths or assuming working directory
```

### 3. **Tolerance Control & Automatic Adaptation**
```julia
# PATTERN: Let polynomial degree adapt to meet tolerance
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2, tolerance=0.001)
pol = Constructor(TR, 4)  # Starting degree, will auto-increase

# AVOID: Fixed GN parameter that prevents adaptation
```

### 4. **Extension Loading & Visualization**
```julia
# PATTERN: Visualization requires explicit backend loading
using CairoMakie  # or GLMakie - MUST load before plot functions
plot_hessian_norms(df)  # Now available

# PATTERN: Enhanced plotting with window display (default) vs file saving
generate_enhanced_plots(raw_distances, bfgs_distances, point_types, 
                       theoretical_points, theoretical_values)  # Display in windows
                       
generate_enhanced_plots(..., save_plots=true)  # Also save to files

# The package uses weak dependencies for optional features
```

### 5. **Deprecation Handling (Optim.jl)**
```julia
# LEARNED: Optim.jl API changes
# OLD: f_tol, x_tol, Optim.iteration_limit
# NEW: f_abstol, x_abstol, simplified convergence checking
Optim.Options(
    g_tol = 1e-8,
    f_abstol = 1e-20,  # was f_tol
    x_abstol = 1e-12,  # was x_tol
)
```

## 🚀 Essential Commands

```julia
# Development setup
]dev .
using Revise, Pkg; Pkg.activate("."); using Globtim

# Run tests (AI should run small tests, user runs comprehensive)
]test Globtim

# Basic workflow
using Globtim, DynamicPolynomials, DataFrames
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2, tolerance=0.001)
pol = Constructor(TR, 4)
@polyvar x[1:2] 
crit_pts = solve_polynomial_system(x, 2, pol.degree, pol.coeffs)
df = process_crit_pts(crit_pts, f, TR)
```

## 📁 Key Documentation Pointers

### Core Documentation
- **README.md**: Package overview, features, examples
- **CLAUDE.md**: This file - development patterns and AI guidance

### Implementation Details
- **src/hessian_analysis.jl**: Phase 2 implementation with eigenvalue analysis
- **src/Globtim.jl**: Main module with core algorithms
- **ext/**: Extension modules for Makie visualization

### Examples & Tests
- **Examples/ForwardDiff_Certification/**: 
  - `phase2_certification_suite.jl`: Comprehensive Phase 2 validation
  - `step1-5_*.jl`: Enhanced 4D Deuflhard implementations
  - `documentation/`: Detailed implementation summaries
- **Examples/Notebooks/**: Interactive Jupyter demonstrations
- **test/**: Automated test suite

## 🔧 Development Workflow

### For AI Assistants
1. **Small Examples**: Run directly to verify behavior
2. **Large Computations**: Suggest code for user execution
3. **Testing**: Use `]test` for verification, but let user run comprehensive suites
4. **Documentation**: Update CLAUDE.md with new patterns learned

### Key Parameters for High-Accuracy Work
```julia
# 4D Deuflhard with tight tolerance
TR = test_input(deuflhard_4d_composite, dim=4,
               center=[0.0, 0.0, 0.0, 0.0], sample_range=0.5,
               tolerance=0.0007)  # L²-norm constraint
pol = Constructor(TR, 4, basis=:chebyshev, verbose=false)

# BFGS refinement for ultra-precision
config = BFGSConfig(
    standard_tolerance=1e-8,
    high_precision_tolerance=1e-12,
    precision_threshold=1e-6
)
```

## 🐛 Common Issues & Solutions

1. **Scope Warnings in Loops**: Use `local` for loop variables in global scope
2. **Type Instability**: Check with `@code_warntype`, use concrete types
3. **Module Loading**: Always activate correct environment first
4. **Extension Functions**: Load backend (CairoMakie/GLMakie) before use
5. **Polynomial Degree**: Handle both `Int` and `Tuple` types from Constructor 