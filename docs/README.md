# Globtim.jl Documentation

Welcome to the documentation for Globtim.jl — a Julia package for global optimization via polynomial approximation.

The rendered site is built with [Documenter.jl](https://documenter.juliadocs.org/) and published at <https://gescholt.github.io/Globtim.jl/>.

## 🚀 Quick Navigation

- **[Getting Started](src/getting_started.md)** — installation, first steps, and precision parameters
- **[Ecosystem Walkthrough](src/ecosystem_walkthrough.md)** — one objective end-to-end across the package family
- **[Examples](src/examples.md)** — practical usage examples
- **[Core Algorithm](src/core_algorithm.md)** — the mathematical approach
- **[API Reference](src/api_reference.md)** — function and type reference

## 📚 Documentation pages (`src/`)

The user-facing pages, in navigation order:

- **[Getting Started](src/getting_started.md)** — installation, setup, basic usage, precision parameters
- **[Ecosystem Walkthrough](src/ecosystem_walkthrough.md)** — critical-point discovery → refinement → visualization
- **[Examples](src/examples.md)** — practical examples and tutorials
- **[Core Algorithm](src/core_algorithm.md)** — mathematical foundations
- **[Polynomial Approximation](src/polynomial_approximation.md)** — approximation theory details
- **[Solvers](src/solvers.md)** — numerical (HomotopyContinuation) and symbolic (msolve) system solvers
- **[Critical Point Analysis](src/critical_point_analysis.md)** — critical-point finding and classification
- **[Sparsification](src/sparsification.md)** — polynomial complexity reduction
- **[Exact Conversion](src/exact_conversion.md)** — exact monomial-basis conversion
- **[Grid Formats](src/grid_formats.md)** — sampling grid specifications
- **[Precision](src/precision_parameters.md)** — precision types and performance trade-offs
- **[API Reference](src/api_reference.md)** — function and type reference

### User guides (`user_guides/`)

Specialized guides for advanced usage:

- **[Anisotropic Lambda Vandermonde](user_guides/anisotropic_lambda_vandermonde.md)**
- **[Grid-Based MainGen](user_guides/grid_based_maingen.md)**

## 🔧 Building the documentation

```bash
# From the package root (this docs/ environment depends only on Globtim + Documenter)
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl
```

The build runs in draft mode under CI (`CI=true`), which skips `@example` execution while still
validating page structure and cross-references.

### Live preview

```bash
julia --project=docs -e 'using LiveServer; servedocs()'
```
