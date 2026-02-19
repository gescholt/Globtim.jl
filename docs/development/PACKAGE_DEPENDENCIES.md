# Globtim Package Dependencies

**Last Updated**: August 21, 2025  
**Architecture**: Core + Weak Dependencies with Package Extensions

## Current Dependency Architecture

Globtim uses Julia's modern weak dependency system (Julia 1.9+) with package extensions for conditional loading of optional features.

### Core Dependencies (Always Loaded)

Core dependencies are always loaded when `using Globtim` is executed. These packages are essential for the fundamental mathematical operations of the package.

#### Mathematical Core
- **DynamicPolynomials** (v0.6): Multivariate polynomial manipulation and symbolic computation
- **ForwardDiff** (v0.10): Automatic differentiation for gradient and Hessian computations
- **HomotopyContinuation** (v2.15): Polynomial system solving for critical point finding
- **LinearAlgebra**: Standard library for matrix operations
- **LinearSolve** (v3.25): Linear system solving
- **MultivariatePolynomials** (v0.5): Abstract interface for polynomial systems
- **Optim** (v1.13): BFGS optimization for critical point refinement
- **PolyChaos** (v0.2.11): Polynomial chaos expansion utilities
- **StaticArrays** (v1.9): Performance-critical array operations
- **Statistics**: Standard library for statistical functions
- **StatsBase** (v0.34): Statistical utilities
- **Random**: Standard library for random number generation

#### Data Processing & I/O
- **CSV** (v0.10): CSV file reading/writing for data import/export
- **ConstructionBase** (v1): Type construction utilities
- **DataFrames** (v1.6): Critical point analysis and result organization
- **DrWatson** (v2.19): Scientific project management and data handling
- **JLD2** (v0.6): Julia data file format for saving/loading results
- **JSON** (v0.21): JSON parsing and generation
- **JSON3** (v1.14): High-performance JSON handling

#### Monitoring and Utilities
- **Dates**: Standard library for timestamp handling
- **Logging**: Standard library for logging
- **Printf**: Standard library for formatted output
- **TimerOutputs** (v0.5): Performance monitoring throughout the package
- **TOML** (v1): Configuration file parsing

### Weak Dependencies (Conditional Loading)

Weak dependencies are only loaded when explicitly imported by the user and when the corresponding package is available.

#### GPU Acceleration (Optional)
- **CUDA** (v5): GPU acceleration for polynomial evaluation

## Package Extensions

Package extensions provide conditional functionality that is only available when the corresponding weak dependencies are loaded.

### Extension Modules

#### GlobtimCUDAExt
- **Trigger**: Loading `CUDA`
- **Functions**: GPU-accelerated polynomial evaluation and grid operations

### Extension Usage Pattern

```julia
# Core functionality always available
using Globtim
TR = TestInput(camel, dim=2)
pol = Constructor(TR, 8)

# Optional GPU acceleration - only if CUDA is available
using CUDA
Globtim.gpu_available()  # Now available via extension
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
- Examples: CUDA

## Migration History

The package was migrated from a monolithic dependency structure to the current weak dependency system in August 2025:

- **Before**: 33 direct dependencies, all loaded at startup
- **After**: Core dependencies + 1 weak dependency (CUDA) with extension
- **Benefits**: Faster startup, better HPC compatibility, modular functionality

## Usage Guidelines

### For Users

#### Basic Usage (Core Only)
```julia
using Globtim
# All mathematical functionality available
# No plotting or advanced analysis
```

#### With GPU Acceleration
```julia
using Globtim
using CUDA  # GPU extension loaded automatically
Globtim.gpu_available()
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