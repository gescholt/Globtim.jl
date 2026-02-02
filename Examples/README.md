# GlobTim Examples

This directory contains **essential examples** demonstrating core GlobTim functionality. These examples are actively maintained and serve as the primary reference for package users.

## 🎯 Quick Start Examples

### Basic Workflow
Start here if you're new to GlobTim:

- **[hpc_minimal_2d_example.jl](hpc_minimal_2d_example.jl)** - Minimal 2D workflow
  - Complete workflow: polynomial construction → critical points
  - Lightweight, fast execution
  - No heavy dependencies

### Feature Demonstrations

- **[custom_function_demo.jl](custom_function_demo.jl)** - User-defined objectives
  - Define custom objective functions
  - Vector input, scalar output pattern
  - Complete workflow example

- **[high_dimensional_demo.jl](high_dimensional_demo.jl)** - 3D/4D problems
  - Higher-dimensional optimization
  - Performance tips for large problems
  - Degree selection guidance

- **[domain_sweep_demo.jl](domain_sweep_demo.jl)** - Domain exploration
  - Test different domain sizes
  - Uniform vs non-uniform domains
  - Finding all critical points

- **[scalar_function_demo.jl](scalar_function_demo.jl)** - 1D scalar functions
  - Functions with scalar input (sin, cos, etc.)
  - Runge function example
  - Polynomial approximation limits

- **[polynomial_basis_comparison.jl](polynomial_basis_comparison.jl)** - Chebyshev vs Legendre
  - Compare different polynomial bases
  - Precision handling and conversions
  - Sparsity patterns analysis

- **[sparsification_demo.jl](sparsification_demo.jl)** - Polynomial sparsification
  - Coefficient thresholding strategies
  - Sparsity-accuracy tradeoffs
  - Memory optimization techniques

- **[anisotropic_grid_demo.jl](anisotropic_grid_demo.jl)** - Anisotropic grids
  - Non-uniform grid spacing
  - Dimension-specific scaling
  - Adaptive sampling strategies

### Advanced Features

- **[valley_walking_demo.jl](valley_walking_demo.jl)** - Valley detection and walking
  - Hessian eigenanalysis for valley detection
  - Adaptive step size valley walking
  - Momentum acceleration
  - Interactive visualization (GLMakie + CairoMakie)

- **[advanced_analysis_core_demo.jl](advanced_analysis_core_demo.jl)** - Advanced analysis
  - Algorithm performance tracking
  - Hessian eigenvalue analysis
  - Convergence metrics
  - Multi-algorithm comparison

### Testing & Integration

- **[validation_integration_test.jl](validation_integration_test.jl)** - Integration tests
  - End-to-end validation workflow
  - Error handling verification
  - CI/CD reference

## 📓 Jupyter Notebooks

Interactive examples with visualizations:

- **[Notebooks/](Notebooks/)** - See [Notebooks/README.md](Notebooks/README.md)
  - `Camel_2d.ipynb` - 2D Six-Hump Camel function
  - `Camel_3d.ipynb` - 3D Six-Hump Camel function
  - And more...

### Notebook Utilities

- **[notebook_setup.jl](notebook_setup.jl)** - Jupyter notebook helper
  - Package loading utilities
  - Environment setup for notebooks

## 🗂️ Other Directories

- **[configs/](configs/)** - Configuration files for experiments
- **[production/](production/)** - Production-ready scripts
- **[systems/](systems/)** - System-specific test functions
- **[archive/](archive/)** - Archived research code (see below)

## 📦 Archived Examples

Historical research code and experiments have been moved to `archive/` subdirectories:

- **[archive/research_and_development_2025_10/](archive/research_and_development_2025_10/)** - R&D experiments, HPC tests, utilities
- **[archive/research_4d_lotka_volterra_2025/](archive/research_4d_lotka_volterra_2025/)** - 4D Lotka-Volterra studies
- **[archive/benchmarking_studies_2025/](archive/benchmarking_studies_2025/)** - Benchmarking experiments
- **[archive/high_dimensional_studies_2025/](archive/high_dimensional_studies_2025/)** - High-dimensional research
- **[archive/dagger_experiments_2025/](archive/dagger_experiments_2025/)** - Dagger.jl integration experiments
- **[archive/valley_walking_research_2025/](archive/valley_walking_research_2025/)** - Valley walking algorithm research

These archived files remain accessible for reference but are not actively maintained.

## 🚀 Running Examples

### Prerequisites
```julia
using Pkg
Pkg.activate(".")  # Activate the globtimcore project
```

### Basic Usage
```bash
# From globtimcore root directory
julia --project=. Examples/hpc_minimal_2d_example.jl
```

### With Visualization
Examples that use GLMakie or CairoMakie may require additional setup:
```julia
using Pkg
Pkg.add("GLMakie")  # For interactive 3D plots
Pkg.add("CairoMakie")  # For static publication-quality plots
```

## 📚 Documentation

For more information:
- **Package Documentation:** [docs/](../docs/)
- **Post-Processing Guide:** [POST_PROCESSING_GUIDE.md](POST_PROCESSING_GUIDE.md)
- **Cleanup Plan:** [CLEANUP_PLAN.md](CLEANUP_PLAN.md) (if you're looking for archived code)

## 💡 Contributing

When adding new examples:
1. Keep them focused on a single feature or workflow
2. Include clear documentation at the top of the file
3. Minimize dependencies
4. Add usage instructions
5. Consider whether it belongs in `Examples/` or `test/`

For experimental or research code, consider starting in your own fork and moving to `archive/` when the research is complete.

---

**Last Updated:** 2025-10-10
