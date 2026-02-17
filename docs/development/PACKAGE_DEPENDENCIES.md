# GlobTim Package Dependencies

**Last Updated**: August 21, 2025  
**Architecture**: Core + Weak Dependencies with Package Extensions

## Current Dependency Architecture

GlobTim uses Julia's modern weak dependency system (Julia 1.9+) with package extensions for conditional loading of optional features.

### Core Dependencies (Always Loaded)

Core dependencies are always loaded when `using Globtim` is executed. These packages are essential for the fundamental mathematical operations of the package.

#### Mathematical Core
- **DynamicPolynomials** (v0.6): Multivariate polynomial manipulation and symbolic computation
- **ForwardDiff** (v0.10): Automatic differentiation for gradient and Hessian computations
- **HomotopyContinuation** (v2.15): Polynomial system solving for critical point finding
- **LinearAlgebra**: Standard library for matrix operations
- **MultivariatePolynomials** (v0.5): Abstract interface for polynomial systems
- **StaticArrays** (v1.9): Performance-critical array operations
- **Statistics**: Standard library for statistical functions
- **Random**: Standard library for random number generation

#### Computational Utilities
- **SpecialFunctions** (v2.4): Mathematical special functions
- **LinearSolve** (v3.25): Linear system solving
- **PolyChaos** (v0.2.11): Polynomial chaos expansion utilities

#### Essential Data Processing
- **DataFrames** (v1.6): Critical point analysis and result organization
- **DataStructures** (v0.18): Advanced data structures
- **IterTools** (v1.10): Iteration utilities
- **Optim** (v1.13): BFGS optimization for critical point refinement
- **Parameters** (v0.12): Type-safe parameter handling

#### Monitoring and Utilities
- **TimerOutputs** (v0.5): Performance monitoring throughout the package
- **Dates**: Standard library for timestamp handling
- **ProgressLogging** (v0.1): Progress reporting

### Weak Dependencies (Conditional Loading)

Weak dependencies are only loaded when explicitly imported by the user and when the corresponding package is available.

#### Visualization (Optional)
- **CairoMakie** (v0.11): Static plotting backend
- **GLMakie** (v0.9): Interactive 3D plotting backend
- **Makie** (v0.20): Core plotting interface
- **Colors** (v0.12): Color manipulation for plots

#### Data I/O (Optional)
- **CSV** (v0.10): CSV file reading/writing for data import/export

#### Advanced Analysis (Optional)
- **Clustering** (v0.15): K-means clustering for critical point analysis
- **Distributions** (v0.25): Statistical distributions for uncertainty quantification

#### Development Tools (Optional)
- **JuliaFormatter** (v1.0): Code formatting for development
- **SHA** (v0.7.0): Hash functions for utility operations
- **TOML** (v1): Configuration file parsing
- **UUIDs** (v1.11.0): UUID generation utilities

## Package Extensions

Package extensions provide conditional functionality that is only available when the corresponding weak dependencies are loaded.

### Extension Modules

#### GlobtimCairoMakieExt
- **Trigger**: Loading `CairoMakie`
- **Functions**: Static plotting functions for polynomial approximations and level sets

#### GlobtimGLMakieExt  
- **Trigger**: Loading `GLMakie`
- **Functions**: Interactive 3D plotting, animations, and real-time visualization

#### GlobtimDataExt
- **Trigger**: Loading `CSV`
- **Functions**: CSV data import/export utilities

#### GlobtimAnalysisExt
- **Trigger**: Loading both `Clustering` and `Distributions`
- **Functions**: Advanced statistical analysis and clustering methods

#### GlobtimDevExt
- **Trigger**: Loading `JuliaFormatter`
- **Functions**: Development workflow utilities

### Extension Usage Pattern

```julia
# Core functionality always available
using Globtim
TR = TestInput(camel, dim=2)
pol = Constructor(TR, 8)

# Optional plotting - only if CairoMakie is available
using CairoMakie
plot_convergence_analysis(results)  # Now available via extension

# Optional data export - only if CSV is available  
using CSV
export_results_csv(results, "output.csv")  # Now available via extension
```

## Design Rationale

### Why Weak Dependencies?

1. **Reduced Startup Time**: Core mathematical functions load quickly without heavy plotting libraries
2. **HPC Compatibility**: Clusters often lack GUI libraries needed for plotting
3. **Modular Functionality**: Users only load features they need
4. **Dependency Isolation**: Plotting library issues don't affect core computations

### Core vs Weak Dependency Classification

**Core Dependencies** (must remain in [deps]):
- Used directly in included source files
- Required for fundamental mathematical operations
- Called without conditional checks
- Examples: ForwardDiff, DataFrames, Optim

**Weak Dependencies** (moved to [weakdeps]):
- Used only through extensions or optional functions
- Provide supplementary functionality
- Can be conditionally loaded
- Examples: CairoMakie, CSV, Clustering

## Migration History

The package was migrated from a monolithic dependency structure to the current weak dependency system in August 2025:

- **Before**: 33 direct dependencies, all loaded at startup
- **After**: 18 core dependencies + 8 weak dependencies with extensions
- **Benefits**: Faster startup, better HPC compatibility, modular functionality

## Usage Guidelines

### For Users

#### Basic Usage (Core Only)
```julia
using Globtim
# All mathematical functionality available
# No plotting or advanced analysis
```

#### With Plotting
```julia
using Globtim
using CairoMakie  # or GLMakie for 3D
# Plotting functions now available via extensions
```

#### Full Functionality
```julia
using Globtim
using CairoMakie, CSV, Clustering, Distributions
# All functionality available
```

### For Developers

#### Adding New Features
- **Core functionality**: Add to main source files, dependencies to [deps]
- **Optional functionality**: Create extension module, dependencies to [weakdeps]

#### Extension Development
```julia
# In ext/GlobtimNewExt.jl
module GlobtimNewExt

using Globtim
import NewPackage

# Only define functions that require NewPackage
function new_functionality()
    # Implementation using NewPackage
end

end
```

## HPC Deployment Considerations

### Bundle Creation
The weak dependency system is compatible with package bundling for HPC deployment:
- Core dependencies bundled automatically
- Weak dependencies included only if needed
- Extensions work transparently in bundled environments

### Environment-Specific Loading
- **HPC Clusters**: Typically load core only for computational work
- **Local Development**: Load all dependencies for full functionality
- **CI/CD**: Load dependencies as needed per test suite

## Future Development

### Planned Extensions
- **GlobtimBenchmarkExt**: Advanced benchmarking and profiling tools
- **GlobtimParallelExt**: Parallel computing extensions

### Migration Strategy
As new optional functionality is added:
1. Evaluate if it belongs in core or extension
2. Create appropriate extension module if needed
3. Add weak dependency to Project.toml
4. Update this documentation

---

This architecture provides a robust foundation for both lightweight HPC deployment and full-featured local development while maintaining backward compatibility and extensibility.