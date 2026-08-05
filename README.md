# Globtim.jl — Global Optimization via Polynomial Approximation

[![Documentation (stable)](https://img.shields.io/badge/docs-stable-blue.svg)](https://gescholt.github.io/Globtim.jl/stable/)
[![Documentation (dev)](https://img.shields.io/badge/docs-dev-blue.svg)](https://gescholt.github.io/Globtim.jl/dev/)

Finding all local minima of a continuous function over a bounded domain is fundamentally hard. Standard optimization algorithms (gradient descent, BFGS, etc.) find *one* local minimum from a given starting point — but how do you know there isn't a better one elsewhere?

Globtim solves this by replacing your function with a polynomial approximation. Setting the gradient of the polynomial to zero gives a polynomial system with finitely many solutions (bounded by Bezout's theorem), which can be computed numerically via homotopy continuation or exactly via symbolic methods. Each solution seeds a local refinement on the original function, searching for local minima across the entire domain — not just the nearest one. The procedure is agnostic of what method is used in the refinement step — refinement is a pluggable component that should be adapted to each particular problem.

```
f(x)  -->  Polynomial p(x)  -->  Solve grad(p) = 0  -->  Refine on f(x)    -->  Candidate minima
           (Chebyshev/Legendre)   (HomotopyContinuation.jl)  (any local method)
```

## Citation

If you use Globtim in your research, please cite the underlying algorithm paper:

> Safey El Din, M., Scholten, G., & Trélat, E. (2026). *Probabilistic algorithm for computing all local minimizers of Morse functions on a compact domain*. **Mathematics of Control, Signals, and Systems**. [doi:10.1007/s00498-026-00441-3](https://doi.org/10.1007/s00498-026-00441-3). Free access: [HAL hal-05160251](https://hal.sorbonne-universite.fr/hal-05160251v2).

```bibtex
@article{safeyeldin2026probabilistic,
  author  = {Safey El Din, Mohab and Scholten, Georgy and Tr{\'e}lat, Emmanuel},
  title   = {Probabilistic algorithm for computing all local minimizers of {Morse} functions on a compact domain},
  journal = {Mathematics of Control, Signals, and Systems},
  year    = {2026},
  doi     = {10.1007/s00498-026-00441-3},
  note    = {Free access: HAL hal-05160251, https://hal.sorbonne-universite.fr/hal-05160251v2},
}
```

A canonical BibTeX entry is also kept at [`CITATION.bib`](CITATION.bib).

### Challenging 1D function — multi-frequency oscillations at varying polynomial degrees:

![1D Comparison](docs/src/assets/1D_comparison.png)

### Styblinski-Tang 2D — classic test function with polynomial approximation:

![Styblinski-Tang](docs/src/assets/styblinski_tang_comparison.png)

## Installation

```julia
using Pkg
Pkg.add("Globtim")
```

For the latest development version:
```julia
Pkg.add(url="https://github.com/gescholt/Globtim.jl")
```

## Quick Start

```julia
using Globtim, DynamicPolynomials, HomotopyContinuation  # HC enables the default :hc solver

# Define a test function (or use your own)
f = Deuflhard  # Built-in test function

# Define domain: center and sampling range
TR = TestInput(f, dim=2, center=[0.0, 0.0], sample_range=1.2)

# Create polynomial approximation (degree 8)
pol = Constructor(TR, 8, precision=AdaptivePrecision)
println("L2-norm approximation error: $(pol.nrm)")

# Find all critical points
@polyvar x[1:2]
solutions = solve_polynomial_system(x, pol)
df = process_crit_pts(solutions, f, TR)

# Identify local minima
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)
println("Found $(nrow(df_min)) local minima")
```

> **New here?** The [Ecosystem Walkthrough](docs/src/ecosystem_walkthrough.md) carries
> one objective end-to-end across all three packages — globtim finds the critical
> points, GlobtimPostProcessing refines them, GlobtimPlots draws them.

## Running Experiments with TOML Configs

Experiments can be driven entirely by TOML configuration files, which specify the function, domain, polynomial degree, solver, and refinement settings:

```bash
julia --project=. scripts/run_experiment.jl examples/configs/ackley_3d.toml
```

Example config for a static benchmark:

```toml
[experiment]
name = "ackley_3d"

[domain]
bounds = [[-5.0, 5.0], [-5.0, 5.0], [-5.0, 5.0]]

[polynomial]
GN = 12
degree_range = [4, 2, 10]
basis = "chebyshev"

[refinement]
enabled = true
method = "NelderMead"
```

## Polynomial Basis Options

Two orthogonal polynomial bases are supported:

- **`:chebyshev`** (default): Chebyshev polynomials — standard choice, well-tested
- **`:legendre`**: Legendre polynomials — uniform distribution of nodes along each coordinate axis

```julia
pol = Constructor(TR, 8, basis=:chebyshev, precision=AdaptivePrecision)  # Default
pol = Constructor(TR, 8, basis=:legendre, precision=AdaptivePrecision)   # Alternative
```

## Precision Control

Globtim supports multiple precision types for balancing accuracy and performance:

| Precision | Relative cost | Arithmetic | Best For |
|-----------|---------------|------------|----------|
| `Float64Precision` | 1.0× | ~15 digits | **General use (default)** |
| `AdaptivePrecision` | 1.2× | Float64 + BigFloat coefficients | Coefficient analysis, sparsification |
| `RationalPrecision` | 5-10× | Exact arithmetic | Exact evaluations + symbolic solver (msolve) |
| `BigFloatPrecision` | 3-8× | ~77 digits (256 bits) | Research |

```julia
pol = Constructor(TR, 8, precision=AdaptivePrecision)
```

## Solvers

Two solvers are available for computing critical points:

1. **[HomotopyContinuation.jl](https://www.juliahomotopycontinuation.org/)** (default) — numerical algebraic geometry
2. **[msolve](https://msolve.lip6.fr/)** — symbolic method based on Groebner basis computations

## Ecosystem

Globtim is part of a three-package ecosystem:

Globtim is registered; the companion packages are installed from their public
repositories (`Pkg.add(url=...)`):

| Package | Purpose | Install |
|---------|---------|---------|
| **Globtim** | Polynomial approximation and critical point finding | `Pkg.add("Globtim")` |
| **[GlobtimPostProcessing](https://github.com/gescholt/GlobtimPostProcessing.jl)** | Refinement, validation, parameter recovery | `Pkg.add(url="https://github.com/gescholt/GlobtimPostProcessing.jl")` |
| **[GlobtimPlots](https://github.com/gescholt/GlobtimPlots.jl)** | Visualization (CairoMakie/GLMakie) | `Pkg.add(url="https://github.com/gescholt/GlobtimPlots.jl")` |

```
Globtim (experiments) --> GlobtimPostProcessing (analysis) --> GlobtimPlots (visualization)
```

## Repository Organization

```
Globtim.jl/
├── src/                    # Core package source
│   ├── Globtim.jl          # Main module
│   ├── ApproxConstruct.jl  # Polynomial construction
│   ├── poly_solver.jl      # Critical-point solver (HC via weak-dep extension)
│   └── ...
├── test/                   # Test suite
├── docs/                   # Documenter.jl documentation
├── scripts/                # Experiment runner scripts
└── .github/workflows/      # CI (tests, docs, TagBot, CompatHelper)
```

## License

GPL-3.0
