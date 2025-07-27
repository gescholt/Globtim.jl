# Globtim.jl Project Memory

## Project Overview
Globtim.jl is a Julia package for global optimization via polynomial approximation. It finds all local minima of continuous functions using Chebyshev/Legendre polynomial approximation and critical point analysis.

## Repository Structure & Git Workflow

### Dual Repository Setup
- **GitLab (Private)**: `main` branch - Development work, experimental features
- **GitHub (Public)**: `github-release` branch - Clean public release for Julia registry

### Git Push Instructions
```bash
# Private development (GitLab)
git push origin main

# Public release (GitHub) - NEVER push main!
git push github github-release
```

### Branch Management Rules
- `main` branch is for private development only
- `github-release` is the clean public version (set as default on GitHub)
- Files in `main` but not in `github-release` are experimental/private
- Example: `Examples/Notebooks/AnisotropicGridComparison.ipynb` (private only)

## Core Package Architecture

### Main Components
1. **Polynomial Approximation** (`src/ApproxConstruct.jl`)
   - Chebyshev and Legendre basis functions
   - Anisotropic grid support
   - L2-norm error tracking in `pol.nrm`

2. **Critical Point Analysis** (`src/enhanced_analysis.jl`, `src/hessian_analysis.jl`)
   - Hessian-based classification (minimum, maximum, saddle, degenerate)
   - Eigenvalue analysis for numerical validation
   - BFGS refinement with convergence tracking

3. **Polynomial System Solving**
   - HomotopyContinuation.jl integration (`src/hom_solve.jl`)
   - Msolve support for exact arithmetic (`src/msolve_system.jl`)

4. **Sparsification & Exact Conversion** (`src/exact_conversion.jl`, `src/truncation_analysis.jl`)
   - Convert to exact monomial basis
   - Intelligent coefficient removal with L2-norm tracking
   - Multiple L2-norm computation methods

### Key Data Structures
- `TestInput`: Problem specification with function, bounds, sampling
- `OrthogonalConstruct`: Polynomial approximation with coefficients and error
- `BoxDomain`: Integration domain for L2-norm computations

## Recent Features (v1.1.x)

### Polynomial Sparsification (NEW)
- `to_exact_monomial_basis`: Convert from orthogonal to monomial basis
- `sparsify_polynomial`: Remove small coefficients with quality tracking
- `compute_l2_norm_vandermonde`: Efficient L2-norm computation
- `analyze_sparsification_tradeoff`: Systematic sparsity analysis

### Enhanced Critical Point Analysis
- Automatic classification via Hessian eigenvalues
- Comprehensive statistical tables (`src/statistical_tables.jl`)
- Basin of attraction analysis
- Condition number assessment for numerical stability

### Anisotropic Grid Support
- Automatic detection of different nodes per dimension
- Optimized Vandermonde matrix construction
- Special handling in `lambda_vandermonde_anisotropic.jl`

## Testing & Quality Control

### Test Structure
- Core tests: `test/runtests.jl`
- Feature-specific tests: `test/test_*.jl`
- Run all tests: `julia --project=. -e 'using Pkg; Pkg.test()'`

### Critical Test Files
- `test_l2_norm_scaling.jl`: L2-norm computation validation
- `test_anisotropic_grids.jl`: Anisotropic functionality
- `test_enhanced_analysis_integration.jl`: Full pipeline testing
- `test_exact_conversion.jl`: Sparsification accuracy

## Documentation System

### Documentation Generation
- Uses Documenter.jl
- GitHub Actions workflow: `.github/workflows/documentation.yml`
- Deploys to gh-pages branch
- Currently serves from `/dev/` not `/stable/`

### Documentation Structure
- `docs/src/`: Source markdown files
- `docs/make.jl`: Build configuration
- GitHub Pages URL: https://gescholt.github.io/Globtim.jl/

## Working with Jupyter Notebooks

### Notebook Tools
1. Use `NotebookRead` to read notebook contents
2. Use `NotebookRead(cell_id=...)` for specific cell outputs when "too large"
3. Use `NotebookEdit` for modifying notebooks (not regular Edit)
4. Use `mcp__ide__executeCode` for running notebook code
5. Check both code cells AND outputs for complete context

### Important Notebooks
- `Examples/Notebooks/`: Public examples
- Private notebooks in main branch only (e.g., AnisotropicGridComparison.ipynb)

## Code Patterns & Conventions

### Function Naming
- `analyze_*`: Analysis functions returning DataFrames
- `compute_*`: Numerical computation functions
- `plot_*`: Visualization functions (in extensions)
- `test_*`: Test utility functions

### Error Handling
- Use `@warn` for non-critical issues
- Return meaningful error messages with context
- Check domain bounds before optimization

### Performance Patterns
- Preallocate arrays for polynomial evaluation
- Use views for large data structures
- Batch operations when possible

## Known Issues & Workarounds

### Documentation 404 Error
- Documentation deploys to `/dev/` not `/stable/`
- GitHub Pages serves from repository root
- Documentation links have been removed from README

### Msolve Parser
- Fixed regex for negative rational numbers
- Handle both positive and negative rational formats

### L2-Norm Scaling
- Different methods (Vandermonde, grid-based, exact) may have slight variations
- Use appropriate method based on problem size and accuracy needs

## Bug Fixing Guidelines
- Document root cause patterns
- Add tests for fixed bugs
- Update CHANGELOG.md

## Poorly Documented Areas (TODO)
- Magic constants in polynomial degree selection
- Dead parameters in some legacy functions
- Unclear data type conversions in parser functions

## Extension System
- Visualization via CairoMakie/GLMakie extensions
- Extensions load automatically when packages are imported
- Extension files: `ext/GlobtimCairoMakieExt.jl`, `ext/GlobtimGLMakieExt.jl`

## Release Process
1. Update version in `Project.toml`
2. Update CHANGELOG.md
3. Run tests on both main and github-release branches
4. Use `bump_version.jl` for version management
5. Push to github-release for public release

## Security Notes
- Never commit secrets or API keys
- Private development stays on GitLab
- Review files before adding to github-release branch

## Performance Tips
- For large problems, use Msolve for exact solutions
- Adjust polynomial degree based on function smoothness
- Use sparsification for memory-constrained environments