# Globtim.jl Dependencies Documentation

This document provides comprehensive documentation for all dependencies used in Globtim.jl, including their purpose, usage patterns, and specific examples within the codebase.

## 📋 Table of Contents

- [Core Mathematical Dependencies](#core-mathematical-dependencies)
- [Data Processing Dependencies](#data-processing-dependencies)
- [Visualization Dependencies](#visualization-dependencies)
- [Development & Testing Dependencies](#development--testing-dependencies)
- [HPC & Infrastructure Dependencies](#hpc--infrastructure-dependencies)
- [Standard Library Dependencies](#standard-library-dependencies)
- [Weak Dependencies & Extensions](#weak-dependencies--extensions)

---

## 🧮 Core Mathematical Dependencies

### DynamicPolynomials.jl
**Version**: `0.6`  
**Purpose**: Multivariate polynomial manipulation and symbolic computation  
**Usage**: Critical for polynomial system construction and solving
```julia
# Used in solve_polynomial_system for defining polynomial variables
@polyvar x[1:n]
solutions = solve_polynomial_system(x, n, d, coeffs)
```
**Key Files**: `src/hom_solve.jl`, `src/Main_Gen.jl`

### HomotopyContinuation.jl
**Version**: `2.15`  
**Purpose**: Numerical algebraic geometry and polynomial system solving  
**Usage**: Core solver for finding critical points of polynomial approximations
```julia
# Primary solver for critical point computation
real_pts = solve_polynomial_system(x, n, d, coeffs; basis=:chebyshev)
```
**Key Files**: `src/hom_solve.jl`, `Examples/`, `test/`

### MultivariatePolynomials.jl
**Version**: `0.5`  
**Purpose**: Abstract interface for multivariate polynomial systems  
**Usage**: Provides common interface for polynomial operations
**Key Files**: `src/Main_Gen.jl`, `src/hom_solve.jl`

### PolyChaos.jl
**Version**: `0.2`  
**Purpose**: Polynomial chaos expansion and uncertainty quantification  
**Usage**: Advanced polynomial approximation techniques
**Key Files**: `src/Main_Gen.jl`, `Examples/uncertainty/`

### ForwardDiff.jl
**Version**: `0.10`  
**Purpose**: Forward-mode automatic differentiation  
**Usage**: Gradient computation and sensitivity analysis
```julia
# Used for gradient-based optimization and validation
gradient = ForwardDiff.gradient(f, x)
```
**Key Files**: `src/optimization/`, `Examples/gradient_analysis/`

### SpecialFunctions.jl
**Version**: `2.4`  
**Purpose**: Mathematical special functions (gamma, beta, etc.)  
**Usage**: Advanced mathematical computations in benchmark functions
**Key Files**: `src/LibFunctions.jl`, `src/BenchmarkFunctions.jl`

### Optim.jl
**Version**: `1.13`  
**Purpose**: Optimization algorithms and solvers  
**Usage**: Local optimization and refinement of critical points
```julia
# Used for local optimization refinement
result = optimize(f, x0, BFGS())
```
**Key Files**: `src/optimization/`, `Examples/optimization/`

---

## 📊 Data Processing Dependencies

### DataFrames.jl
**Version**: `1.6`  
**Purpose**: Tabular data manipulation and analysis  
**Usage**: Processing and organizing critical point results
```julia
# Used extensively in process_crit_pts for result organization
df = process_crit_pts(solutions, f, TR)
```
**Key Files**: `src/ParsingOutputs.jl`, `Examples/`, `test/`

### CSV.jl
**Version**: `0.10`  
**Purpose**: CSV file reading and writing  
**Usage**: Data export for HPC results and analysis
```julia
# Saving critical points for analysis
CSV.write("critical_points.csv", df)
```
**Key Files**: `hpc/jobs/`, `Examples/data_export/`

### DataStructures.jl
**Version**: `0.18`  
**Purpose**: Advanced data structures (heaps, trees, etc.)  
**Usage**: Efficient algorithms and data organization
**Key Files**: `src/algorithms/`, `src/optimization/`

### Clustering.jl
**Version**: `0.15`  
**Purpose**: Data clustering and pattern recognition  
**Usage**: Grouping and analyzing critical point patterns
**Key Files**: `src/analysis/`, `Examples/clustering/`

---

## 🎨 Visualization Dependencies

### Makie.jl
**Version**: `0.20`  
**Purpose**: High-performance plotting and visualization  
**Usage**: Base plotting system with backend extensions
```julia
# Used in visualization examples and notebooks
scatter(df.x1, df.x2, color=df.z)
```
**Key Files**: `Examples/visualization/`, `docs/notebooks/`

### Colors.jl
**Version**: `0.12`  
**Purpose**: Color manipulation and palettes  
**Usage**: Visualization customization and plot aesthetics
**Key Files**: `Examples/visualization/`, extension files

**Note**: Flagged by Aqua.jl as potentially stale, but actively used in visualization extensions and plotting backends.

---

## 🔧 Development & Testing Dependencies

### BenchmarkTools.jl
**Version**: `1.6.0`  
**Purpose**: Performance benchmarking and timing  
**Usage**: HPC performance testing and optimization analysis
```julia
# Used in performance testing infrastructure
@benchmark Constructor(TR, degree)
```
**Key Files**: `hpc/scripts/benchmark_tests/`, `Examples/performance/`

**Note**: Flagged by Aqua.jl as potentially stale, but essential for HPC performance tracking.

### JuliaFormatter.jl
**Version**: `1.0`  
**Purpose**: Code formatting and style enforcement  
**Usage**: CI/CD pipelines, pre-commit hooks, and code quality
**Key Files**: `.JuliaFormatter.toml`, `.github/workflows/`, `scripts/format.jl`

**Note**: Flagged by Aqua.jl as potentially stale, but actively used in development workflows.

### ProfileView.jl
**Version**: `1.10.1`  
**Purpose**: Interactive profiling and performance analysis  
**Usage**: Development profiling and performance optimization
**Key Files**: `Examples/profiling/`, development scripts

**Note**: Used in optional development tools and performance analysis workflows.

---

## 🖥️ HPC & Infrastructure Dependencies

### JSON3.jl
**Version**: `1.14.3`  
**Purpose**: High-performance JSON parsing and generation  
**Usage**: HPC job tracking, configuration, and result serialization
```julia
# Extensively used in HPC infrastructure
JSON3.write("config.json", job_config)
results = JSON3.read("results.json")
```
**Key Files**: `hpc/infrastructure/json_io.jl`, `hpc/jobs/`, `hpc/monitoring/`

**Note**: Flagged by Aqua.jl as potentially stale, but critical for HPC workflows.

### YAML.jl
**Version**: `0.4.14`  
**Purpose**: YAML configuration file processing  
**Usage**: Documentation monitoring system and HPC configuration
**Key Files**: `tools/documentation_monitor/`, `hpc/config/`

**Note**: Flagged by Aqua.jl as potentially stale, but used in configuration management.

### ProgressLogging.jl
**Version**: `0.1`  
**Purpose**: Progress reporting and logging  
**Usage**: HPC job monitoring and long-running computation tracking
**Key Files**: `hpc/monitoring/`, `Examples/long_running/`

**Note**: Flagged by Aqua.jl as potentially stale, but used in monitoring workflows.

### TimerOutputs.jl
**Version**: `0.5`  
**Purpose**: Hierarchical timing and performance profiling  
**Usage**: Detailed performance analysis of computational workflows
```julia
# Used throughout codebase for performance tracking
@timeit "polynomial_construction" Constructor(TR, degree)
```
**Key Files**: `src/Main_Gen.jl`, `src/hom_solve.jl`, performance analysis

---

## 📚 Standard Library Dependencies

### LinearAlgebra
**Purpose**: Linear algebra operations and matrix computations  
**Usage**: Core mathematical operations throughout the package
```julia
# Used extensively for matrix operations
norm(gradient), det(hessian), eigvals(matrix)
```

### Statistics
**Purpose**: Statistical functions and analysis  
**Usage**: Data analysis and statistical computations
```julia
# Used in result analysis
mean(errors), std(residuals), quantile(values, 0.95)
```

### Random
**Purpose**: Random number generation and sampling  
**Usage**: Stochastic algorithms and testing
```julia
# Used in sampling and testing
Random.seed!(1234)
sample_points = rand(n_samples, dimension)
```

### Dates
**Purpose**: Date and time handling  
**Usage**: Timestamping and job tracking
```julia
# Used in HPC job tracking and logging
timestamp = now()
```

### TOML
**Purpose**: TOML configuration file parsing  
**Usage**: Project configuration and metadata
**Key Files**: `Project.toml`, configuration parsing

---

## 🔌 Weak Dependencies & Extensions

### CairoMakie.jl
**Version**: `0.11`  
**Purpose**: Cairo-based plotting backend for publication-quality graphics  
**Usage**: High-quality static plots and publication figures
**Extension**: `GlobtimCairoMakieExt`

### GLMakie.jl
**Version**: `0.9`  
**Purpose**: OpenGL-based plotting backend for interactive graphics  
**Usage**: Interactive 3D visualizations and real-time plotting
**Extension**: `GlobtimGLMakieExt`

---

## 🚨 Aqua.jl Flagged Dependencies

The following dependencies are flagged by Aqua.jl as potentially "stale" but are actually essential for the package's functionality:

1. **JSON3**: Critical for HPC infrastructure and job tracking
2. **BenchmarkTools**: Essential for performance testing and HPC benchmarking
3. **YAML**: Used in documentation monitoring and configuration management
4. **JuliaFormatter**: Required for CI/CD and code quality enforcement
5. **Colors**: Used in visualization extensions and plotting backends
6. **ProgressLogging**: Used in HPC monitoring and progress tracking
7. **Makie**: Base dependency for visualization system extensions

These dependencies are properly configured in `test/aqua_config.jl` to be ignored during stale dependency checks.

---

## 📖 Usage Examples

### Complete Workflow Example
```julia
using Globtim, DataFrames, CSV, JSON3

# Create test input
TR = test_input(Deuflhard, dim=2, center=[0,0], sample_range=1.2)

# Build polynomial approximation
pol = Constructor(TR, 8)

# Find critical points
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)

# Process results
df = process_crit_pts(solutions, Deuflhard, TR)

# Export results
CSV.write("results.csv", df)
JSON3.write("metadata.json", Dict("degree" => 8, "error" => pol.nrm))
```

### HPC Integration Example
```julia
# HPC job configuration with JSON tracking
config = Dict(
    "function" => "Deuflhard",
    "parameters" => Dict("degree" => 10, "samples" => 100),
    "timestamp" => string(now())
)
JSON3.write("job_config.json", config)
```

---

## 🔍 Dependency Analysis

- **Total Dependencies**: 32 packages
- **Core Mathematical**: 7 packages (22%)
- **Data Processing**: 4 packages (12%)
- **Visualization**: 2 packages (6%)
- **Development/Testing**: 3 packages (9%)
- **HPC/Infrastructure**: 4 packages (12%)
- **Standard Library**: 5 packages (16%)
- **Extensions**: 2 packages (6%)
- **Utilities**: 5 packages (16%)

All dependencies serve specific, documented purposes within the Globtim.jl ecosystem and are actively maintained with appropriate version bounds.
