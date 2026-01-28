# Globtim Core Package Memory

## Project Information

**Repository**: `git@git.mpi-cbg.de:globaloptim/globtimcore.git`
**GitLab URL**: https://git.mpi-cbg.de/globaloptim/globtimcore
**Local Path**: `/Users/ghscholt/GlobalOptim/globtimcore`
**Package Name**: `Globtim`

## Package Purpose

**Globtim is the CORE OPTIMIZATION ENGINE** - pure mathematical and algorithmic functionality for global optimization using polynomial approximations. This is the foundation package that all other packages depend on.

## Critical Design Principle: NO PLOTTING DEPENDENCIES

🚨 **NEVER add plotting libraries to this package** 🚨

This package must remain lightweight and suitable for:
- High-Performance Computing (HPC) environments
- Headless servers
- Parallel/distributed computing
- Pure algorithmic research

**Forbidden dependencies:**
- ❌ Makie (CairoMakie, GLMakie, WGLMakie)
- ❌ Plots
- ❌ PyPlot
- ❌ Any visualization library

**If you need plotting, use `globtimplots` package instead.**

## What BELONGS in globtimcore

✅ **Core Algorithms:**
- Polynomial approximation methods
- Critical point solvers (HomotopyContinuation)
- Grid construction (Gauss-Lobatto, Chebyshev)
- Optimization routines (BFGS, gradient descent)
- Vandermonde matrix operations
- Basis function computations (Chebyshev, Legendre, etc.)

✅ **Mathematical Utilities:**
- Linear algebra operations
- Numerical differentiation
- Tolerance/convergence checking
- Distance metrics

✅ **Data Structures:**
- `test_input` - Problem specification
- `Polynomial` - Polynomial representation
- Configuration types
- Result containers (DataFrames with coordinates/values)

✅ **Infrastructure:**
- Configuration management (TOML parsing)
- Experiment framework (StandardExperiment)
- Result export (CSV, JSON, JLD2)
- Logging and diagnostics

✅ **Allowed Dependencies:**
- LinearAlgebra, Statistics - Standard library math
- DifferentialEquations, OrdinaryDiffEq - ODE solving
- HomotopyContinuation, DynamicPolynomials - Polynomial systems
- Optim - Optimization algorithms
- PolyChaos - Polynomial chaos expansion
- ForwardDiff - Automatic differentiation
- DataFrames, CSV, JSON3, JLD2 - Data management
- DrWatson - Scientific project management
- TOML - Configuration parsing

## What DOES NOT belong in globtimcore

❌ **Plotting/Visualization:**
- Plot generation → Use `globtimplots`
- Interactive visualizations → Use `globtimplots`
- Figure composition → Use `globtimplots`

❌ **Heavy Analysis/Post-processing:**
- Campaign aggregation → Use `globtimpostprocessing`
- Statistical analysis across experiments → Use `globtimpostprocessing`
- Report generation → Use `globtimpostprocessing`
- Result loading/management → Use `globtimpostprocessing`

❌ **Application-Specific Code:**
- Domain-specific models → Use Examples/ directory
- Custom objective functions → Use Dynamic_objectives package
- Experiment scripts → Use research/fav_exmpl/ or create separate repo

## Architecture: Separation of Concerns

```
┌─────────────────────────────────────────┐
│         globtimcore                     │
│  (Core algorithms, NO plotting)         │
│  - Polynomial approximation             │
│  - Critical point solving               │
│  - Optimization routines                │
│  - Data export (CSV/JSON)               │
└─────────────────────────────────────────┘
           ▲                    ▲
           │                    │
           │ depends on         │ depends on
           │                    │
┌──────────┴───────────┐  ┌────┴──────────────────┐
│  globtimpostprocessing│  │    globtimplots       │
│  - Load results       │  │  - Visualizations     │
│  - Statistics         │  │  - CairoMakie/GLMakie │
│  - Campaign analysis  │  │  - Interactive plots  │
│  - Reports (text)     │  │  - Publication output │
└───────────────────────┘  └───────────────────────┘
```

## Recent Changes (October 2025)

### Circular Dependency Removal
- Removed `GlobtimPostProcessing` from dependencies
- Removed `GlobtimPlots` from dependencies
- Moved `TOML` from weakdeps to regular deps (required by config.jl)
- Added `using TOML` to src/Globtim.jl

**Rationale**: Circular dependencies prevented precompilation. Core package should never depend on its downstream consumers.

### PostProcessing Stub
- `src/PostProcessing.jl` is a DEPRECATED stub that redirects users to standalone package
- DO NOT add functionality here - it only contains error messages

## Decision Framework

**Before adding ANY new feature, ask:**

1. **Is it a core mathematical/optimization algorithm?**
   - Yes → Add to globtimcore
   - No → Check next question

2. **Does it require plotting libraries (Makie, Plots, etc.)?**
   - Yes → **STOP!** Use globtimplots instead
   - No → Check next question

3. **Is it primarily about analyzing/aggregating results?**
   - Yes → Use globtimpostprocessing
   - No → Probably belongs in globtimcore

4. **Does it need to run on HPC/headless servers?**
   - Yes → Must be in globtimcore (no plotting deps allowed)
   - No → Could be in globtimplots or globtimpostprocessing

## Examples

| Feature | Correct Package | Why |
|---------|----------------|-----|
| Add Legendre polynomial basis | globtimcore | Core algorithm |
| Plot convergence curves | globtimplots | Visualization |
| Parallel grid evaluation | globtimcore | Core infrastructure |
| Interactive parameter slider | globtimplots | Interactive viz |
| Compute parameter recovery stats | globtimpostprocessing | Analysis |
| Adaptive mesh refinement | globtimcore | Core algorithm |
| Export results to HDF5 | globtimcore | Data export |
| Campaign comparison plots | globtimplots | Visualization |
| Cluster critical points | globtimpostprocessing | Analysis |

## Key Files

- `src/Globtim.jl` - Main module, imports all dependencies
- `src/config.jl` - Configuration management (uses TOML)
- `src/Constructor.jl` - Polynomial approximation
- `src/Main_Gen.jl` - Main optimization workflow
- `src/refining.jl` - Critical point refinement
- `src/StandardExperiment.jl` - Experiment framework
- `Project.toml` - Package metadata and dependencies

## Testing

- Run tests: `julia --project=. -e 'using Pkg; Pkg.test()'`
- Check precompilation: `julia --project=. -e 'using Globtim'`
- Verify no plotting deps: `grep -i "makie\|plots" Project.toml` should return empty

## Related Documentation

- See `/Users/ghscholt/GlobalOptim/.claude/CLAUDE.md` for overall package structure
- See `globtimplots/.claude/CLAUDE.md` for visualization guidelines
- See `globtimpostprocessing/.claude/CLAUDE.md` for analysis guidelines
