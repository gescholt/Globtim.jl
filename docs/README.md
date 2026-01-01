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
- **[Development Guide](../DEVELOPMENT_GUIDE.md)** - Setup and contribution workflow
- **[Package Dependencies](../PACKAGE_DEPENDENCIES.md)** - Complete dependency architecture and extension system
- **[Project Management](project-management/)** - GitLab workflow and sprint process

### For Contributors
- **[Feature Roadmap](features/roadmap.md)** - Current and planned features
- **[Development Patterns](development/)** - Implementation guidelines
- **[Project Management](project-management/)** - Issue tracking and sprint planning

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

### Feature Documentation (`features/`)
Detailed information about Globtim.jl capabilities:

- **[Feature Roadmap](features/roadmap.md)** - Development status and future plans
- **[Plotting Backends](features/plotting-backends.md)** - CairoMakie vs GLMakie usage

### Development Documentation (`development/`)
Technical implementation details and development guides:

- **[Implementation Roadmap](development/implementation_roadmap.md)**
- **[Anisotropic Grid Integration](development/anisotropic_integration_roadmap.md)**
- **[Extended Precision Implementation](development/extended_precision_implementation_plan.md)**
- **[Test Coverage Matrix](development/test_coverage_matrix.md)**
- **[Type Analysis Plan](development/type_analysis_plan.md)**

### Project Management (`project-management/`)
Workflow, processes, and project organization:

- **[Overview](project-management/README.md)** - Quick reference and daily commands
- **[GitLab Workflow](project-management/gitlab-workflow.md)** - Repository management and CI/CD
- **[Sprint Process](project-management/sprint-process.md)** - Agile development process
- **[Task Management](project-management/task-management.md)** - Issue tracking and epic management

### HPC Documentation (`hpc/`)
High-performance computing specific guides:

- **[HPC Precision Optimization](hpc/precision_optimization_guide.md)** - Precision parameter recommendations for cluster usage

### User Guides (`user_guides/`)
Specialized guides for advanced usage:

- **[Anisotropic Lambda Vandermonde](user_guides/anisotropic_lambda_vandermonde.md)**
- **[Grid-Based MainGen](user_guides/grid_based_maingen.md)**

### Archive (`archive/`)
Historical documentation preserved for reference:

- **[Archive Overview](archive/README.md)** - What's archived and why
- Historical analysis documents and superseded documentation

## 🎯 Documentation by Use Case

### I want to...

#### **Use Globtim.jl in my research**
1. Start with [Getting Started](src/getting_started.md)
2. Learn about [Precision Parameters](src/precision_parameters.md) for optimal accuracy/performance
3. Review [Examples](src/examples.md) for your use case
4. Check [API Reference](src/api_reference.md) for specific functions
5. Understand the [Core Algorithm](src/core_algorithm.md)

#### **Contribute to Globtim.jl development**
1. Read the [Development Guide](../DEVELOPMENT_GUIDE.md)
2. Review [GitLab Workflow](project-management/gitlab-workflow.md)
3. Check [Feature Roadmap](features/roadmap.md) for priorities
4. Follow [Task Management](project-management/task-management.md) process

#### **Understand the mathematical approach**
1. Read [Core Algorithm](src/core_algorithm.md)
2. Study [Polynomial Approximation](src/polynomial_approximation.md)
3. Review [Critical Point Analysis](src/critical_point_analysis.md)
4. Check [Solvers](src/solvers.md) for implementation details

#### **Create visualizations**
1. Review [GlobtimPlots](src/globtimplots.md) guide
2. Check [Plotting Backends](features/plotting-backends.md) for setup
3. Study [Examples](src/examples.md) for plotting code

#### **Optimize performance**
1. Learn [Precision Parameters](src/precision_parameters.md) for performance tuning
2. Review [Sparsification](src/sparsification.md) techniques
3. Check [HPC Precision Optimization](hpc/precision_optimization_guide.md) for cluster usage
4. Study performance examples in [Examples](src/examples.md)

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
| Core Documentation | ✅ Complete | 2025-01 |
| API Reference | ✅ Complete | 2025-01 |
| Examples | ✅ Complete | 2025-01 |
| Development Guides | ✅ Complete | 2025-01 |
| Project Management | ✅ Complete | 2025-01 |
| Feature Documentation | ✅ Complete | 2025-01 |
| User Guides | 🟡 Partial | 2024-12 |
| Advanced Topics | 🔴 Planned | TBD |

## 🤝 Contributing to Documentation

### Reporting Issues
- Use GitLab issues with `Type::Documentation` label
- Specify which document and section needs improvement
- Provide suggestions for improvement

### Contributing Changes
1. Follow [GitLab Workflow](project-management/gitlab-workflow.md)
2. Create feature branch for documentation changes
3. Update relevant documentation files
4. Test documentation builds locally
5. Submit merge request with clear description

### Documentation Standards
- Use clear, concise language
- Include code examples where appropriate
- Follow existing formatting conventions
- Update table of contents when adding sections
- Cross-reference related documentation
