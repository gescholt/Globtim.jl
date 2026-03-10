# Globtim.jl Documentation

Welcome to the comprehensive documentation for Globtim.jl - a Julia package for global optimization via polynomial approximation.

## 🚀 Quick Navigation

### For Users
- **[Getting Started](src/getting_started.md)** - Installation, first steps, and precision parameters
- **[Examples](src/examples.md)** - Practical usage examples with visual gallery
- **[Core Algorithm](src/core_algorithm.md)** - Understanding the mathematical approach
- **[API Reference](src/api_reference.md)** - Complete function reference with precision options
- **[Precision Parameters](src/precision_parameters.md)** - Comprehensive guide to precision types and performance trade-offs

### For Developers
- **[Package Dependencies](development/PACKAGE_DEPENDENCIES.md)** - Dependency architecture and extension system
- **[Development Documentation](development/)** - Implementation guidelines and architecture

## 📚 Documentation Categories

### Core Documentation (`src/`)
The main user-facing documentation built with Documenter.jl:

- **[Getting Started](src/getting_started.md)** - Installation, setup, basic usage, and precision parameters
- **[Precision Parameters](src/precision_parameters.md)** - Detailed guide to precision types, performance trade-offs, and advanced usage
- **[Core Algorithm](src/core_algorithm.md)** - Mathematical foundations and approach
- **[API Reference](src/api_reference.md)** - Complete function and type reference with precision options
- **[Examples](src/examples.md)** - Practical examples and tutorials
- **[Polynomial Approximation](src/polynomial_approximation.md)** - Approximation theory details
- **[Critical Point Analysis](src/critical_point_analysis.md)** - Critical point finding and classification
- **[Solvers](src/solvers.md)** - Polynomial system solvers (numerical and symbolic)
- **[GlobtimPlots](src/globtimplots.md)** - Visualization with Makie
- **[Sparsification](src/sparsification.md)** - Polynomial complexity reduction
- **[Grid Formats](src/grid_formats.md)** - Sampling grid specifications

### Development Documentation (`development/`)
Technical implementation details and development guides:

- **[Package Dependencies](development/PACKAGE_DEPENDENCIES.md)** - Dependency architecture
- **[Package Architecture Guidelines](development/PACKAGE_ARCHITECTURE_GUIDELINES.md)** - Architecture patterns
- **[Conditional Loading](development/CONDITIONAL_LOADING_NO_FALLBACKS.md)** - No-fallback loading rules
- **[Circular Dependency Prevention](development/CIRCULAR_DEPENDENCY_PREVENTION_RULES.md)** - Dependency rules
- **[PolyVar Import Solution](development/POLYVAR_IMPORT_SOLUTION.md)** - DynamicPolynomials import patterns
- **[Warning Catalog](development/WARNING_CATALOG.md)** - Known warnings reference

### User Guides (`user_guides/`)
Specialized guides for advanced usage:

- **[Anisotropic Lambda Vandermonde](user_guides/anisotropic_lambda_vandermonde.md)**
- **[Grid-Based MainGen](user_guides/grid_based_maingen.md)**

## Documentation by Use Case

### I want to...

#### **Use Globtim.jl in my research**
1. Start with [Getting Started](src/getting_started.md)
2. Learn about [Precision Parameters](src/precision_parameters.md) for optimal accuracy/performance
3. Review [Examples](src/examples.md) for your use case
4. Check [API Reference](src/api_reference.md) for specific functions
5. Understand the [Core Algorithm](src/core_algorithm.md)

#### **Contribute to Globtim.jl development**
1. Review [Development Documentation](development/) for guidelines
2. Check [Package Dependencies](development/PACKAGE_DEPENDENCIES.md) for architecture

#### **Understand the mathematical approach**
1. Read [Core Algorithm](src/core_algorithm.md)
2. Study [Polynomial Approximation](src/polynomial_approximation.md)
3. Review [Critical Point Analysis](src/critical_point_analysis.md)
4. Check [Solvers](src/solvers.md) for implementation details

#### **Create visualizations**
1. Review [GlobtimPlots](src/globtimplots.md) guide
2. Study [Examples](src/examples.md) for plotting code

#### **Optimize performance**
1. Learn [Precision Parameters](src/precision_parameters.md) for performance tuning
2. Review [Sparsification](src/sparsification.md) techniques
3. Study performance examples in [Examples](src/examples.md)

## 🔧 Building Documentation

### Local Development
```bash
# Navigate to docs directory
cd docs

# Install dependencies
julia --project=. -e "using Pkg; Pkg.instantiate()"

# Build documentation
julia --project=. make.jl
```

### Live Preview
```bash
# Install LiveServer.jl
julia -e "using Pkg; Pkg.add(\"LiveServer\")"

# Serve documentation locally
julia -e "using LiveServer; serve(dir=\"build\")"
```

## 📊 Documentation Status

| Category | Status | Last Updated |
|----------|--------|--------------|
| Core Documentation | Complete | 2025-01 |
| API Reference | Complete | 2025-01 |
| Examples | In Progress | 2025-01 |
| Development Guides | Complete | 2025-01 |
| User Guides | Partial | 2024-12 |

## 🤝 Contributing to Documentation

### Reporting Issues
- Use GitHub Issues with `documentation` label
- Specify which document and section needs improvement
- Provide suggestions for improvement

### Contributing Changes
1. Create a feature branch for documentation changes
2. Update relevant documentation files
3. Test documentation builds locally
4. Submit a pull request with clear description

### Documentation Standards
- Use clear, concise language
- Include code examples where appropriate
- Follow existing formatting conventions
- Update table of contents when adding sections
- Cross-reference related documentation
