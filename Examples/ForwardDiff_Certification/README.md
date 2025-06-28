# ForwardDiff Certification & Phase 2 Hessian Analysis

This directory contains comprehensive demonstrations and certification tests for Globtim's Phase 2 Hessian-based critical point classification using ForwardDiff.jl automatic differentiation.

## Overview

Phase 2 extends the enhanced statistics (Phase 1) by computing Hessian matrices at each critical point and classifying them based on eigenvalue structure. This provides rigorous mathematical classification of critical points beyond simple function value analysis.

## Mathematical Foundation

### Critical Point Classification via Hessian Analysis

For a function f: ℝⁿ → ℝ, at a critical point x* where ∇f(x*) = 0, the Hessian matrix H = ∇²f(x*) determines the local behavior:

- **Local Minimum**: H is positive definite (all eigenvalues > 0)
- **Local Maximum**: H is negative definite (all eigenvalues < 0)  
- **Saddle Point**: H is indefinite (mixed positive/negative eigenvalues)
- **Degenerate**: H is singular (at least one eigenvalue = 0)

### Eigenvalue-Based Classification Algorithm

```julia
eigenvals = eigvals(H)
if all(λ -> λ > tol_pos, eigenvals)
    return :minimum
elseif all(λ -> λ < -tol_neg, eigenvals)
    return :maximum
elseif any(λ -> abs(λ) < tol_zero, eigenvals)
    return :degenerate
else
    return :saddle
end
```

## Implementation Architecture

### Core Components

1. **Hessian Computation** (`compute_hessians`): Uses ForwardDiff.jl for automatic differentiation
2. **Classification Engine** (`classify_critical_points`): Eigenvalue-based critical point typing
3. **Statistical Analysis** (`compute_eigenvalue_stats`): Comprehensive Hessian matrix analysis
4. **Validation Functions** (`extract_critical_eigenvalues`): Specialized eigenvalue tracking
5. **Visualization Suite** (`plot_hessian_*`): Comprehensive plotting functions

### Enhanced DataFrame Columns (Phase 2)

When `analyze_critical_points()` is called with `enable_hessian=true`, the following columns are added:

#### Critical Point Classification
- `critical_point_type`: Mathematical classification (:minimum, :maximum, :saddle, :degenerate, :error)
- `smallest_positive_eigenval`: Smallest positive eigenvalue (for minima validation)
- `largest_negative_eigenval`: Largest negative eigenvalue (for maxima validation)

#### Hessian Matrix Properties
- `hessian_norm`: L2 (Frobenius) norm ||H||_F
- `hessian_eigenvalue_min`: Smallest eigenvalue λ_min
- `hessian_eigenvalue_max`: Largest eigenvalue λ_max  
- `hessian_condition_number`: κ(H) = |λ_max|/|λ_min|
- `hessian_determinant`: det(H)
- `hessian_trace`: tr(H)

## Files in This Directory

### 🚀 Main Production Files

#### `deuflhard_4d_complete.jl` **[NEW - CONSOLIDATED]**
Single definitive file for 4D Deuflhard analysis featuring:
- Complete 16-orthant decomposition (2^4 = 16 sign combinations)
- Automatic polynomial degree adaptation until L²-norm ≤ 0.0007
- BFGS refinement for critical points near minimizers
- Comprehensive validation against expected global minimum
- High-precision tolerances and detailed convergence information
- **Consolidates functionality from 12+ experimental files into one production-ready implementation**

#### `deuflhard_4d_analysis.jl`
Original comprehensive 4D Deuflhard analysis (kept for reference)

#### `deuflhard_4d_analysis_msolve.jl`
Alternative implementation using msolve solver instead of HomotopyContinuation.jl

#### `deuflhard_4d_analysis_high_precision.jl`
High-precision BFGS refinement with ultra-tight tolerances for critical points

### Core Demonstration Files

#### `trefethen_3d_complete_demo.jl`
Comprehensive demonstration using the challenging Trefethen 3D function, featuring:
- Complete Phase 1 + Phase 2 workflow
- Eigenvalue distribution analysis with text-based histograms
- Mathematical validation of critical point classifications
- Statistical breakdown by critical point type
- Enhanced performance metrics and condition number analysis

#### `phase2_certification_suite.jl`
Comprehensive certification test suite covering:
- Multiple test functions (quadratic, Rastringin, Deuflhard, etc.)
- Edge case handling (singular matrices, computation failures)
- Performance benchmarks and memory usage analysis
- Numerical stability validation across different function types

#### `eigenvalue_analysis_demo.jl`
Specialized demonstration of eigenvalue distribution analysis:
- Extraction of all eigenvalues for detailed analysis
- Text-based ASCII histogram visualization
- Statistical validation (minima should have ~100% positive eigenvalues)
- Comparative analysis between different critical point types

### Visualization Demonstration Files

#### `hessian_visualization_demo.jl`
Showcase of Phase 2 visualization capabilities:
- Hessian norm analysis plots
- Condition number quality assessment
- Critical eigenvalue validation plots
- Type-specific scaling and statistical overlays

#### `visualization_enhancement_examples.jl`
Advanced visualization techniques following the Phase 2 Visualization Improvement Plan:
- Separated minima/maxima statistical analysis
- Adaptive scaling for different critical point types
- Statistical overlay systems (quartiles, medians, confidence intervals)
- Comparative analysis dashboards

### Test and Validation Files

#### `forward_diff_unit_tests.jl`
Unit tests for core ForwardDiff integration:
- Simple quadratic functions with known Hessian properties
- Numerical precision and accuracy tests
- Error handling and edge case validation
- Performance benchmarks for different problem sizes

#### `integration_validation.jl`
End-to-end integration tests:
- Complete workflow validation from polynomial construction to classification
- Cross-validation with analytical solutions where available
- Stability tests across different polynomial degrees and dimensions
- Memory usage and computational efficiency analysis

## Usage Examples

### Basic Phase 2 Workflow

```julia
# Proper initialization for examples
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))  # Two levels up to project root
using Globtim
using DynamicPolynomials, DataFrames

# Setup problem
f = Deuflhard  # or any test function
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Phase 1 + Phase 2 analysis
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# View results
println("Classification summary:")
println(combine(groupby(df_enhanced, :critical_point_type), nrow => :count))
```

### Advanced Analysis with Visualization

```julia
# Complete analysis with visualization
df_enhanced, df_min = analyze_critical_points(
    f, df, TR, 
    enable_hessian=true, 
    hessian_tol_zero=1e-8,
    verbose=true
)

# Generate visualizations
using CairoMakie
fig1 = plot_hessian_norms(df_enhanced)
fig2 = plot_condition_numbers(df_enhanced)
fig3 = plot_critical_eigenvalues(df_enhanced)

display(fig1)
display(fig2)
display(fig3)
```

### Eigenvalue Distribution Analysis

```julia
# Extract eigenvalues for each critical point type
minima_eigenvals = extract_all_eigenvalues(df_enhanced, :minimum)
saddle_eigenvals = extract_all_eigenvalues(df_enhanced, :saddle)
maxima_eigenvals = extract_all_eigenvalues(df_enhanced, :maximum)

# Generate histograms
text_histogram(minima_eigenvals, "MINIMA EIGENVALUES")
text_histogram(saddle_eigenvals, "SADDLE EIGENVALUES")
text_histogram(maxima_eigenvals, "MAXIMA EIGENVALUES")
```

## Performance Characteristics

### Computational Complexity
- **Phase 1 Enhanced Statistics**: O(n×m) where n = points, m = dimensions
- **Phase 2 Hessian Computation**: O(n×m²) for Hessian computation
- **Phase 2 Eigenvalue Analysis**: O(n×m³) for eigenvalue decomposition

### Memory Usage
- **Phase 1 columns**: O(n) additional memory for n critical points
- **Phase 2 columns**: O(n) additional memory (Hessian matrices computed but not stored)
- **Eigenvalue storage**: O(n×m) for complete eigenvalue vectors

### Numerical Stability
- Uses `Symmetric(H)` for improved eigenvalue computation stability
- Robust error handling for singular matrices and computation failures
- Configurable tolerance parameters for zero eigenvalue detection

## Certification Criteria

### Mathematical Correctness
- ✅ Minima have all positive eigenvalues (within numerical tolerance)
- ✅ Maxima have all negative eigenvalues (within numerical tolerance)
- ✅ Saddle points have mixed positive/negative eigenvalues
- ✅ Classification consistency across multiple runs

### Numerical Stability
- ✅ Condition number analysis for numerical quality assessment
- ✅ Graceful handling of near-singular matrices
- ✅ Robust performance across different function types and scales

### Performance Validation
- ✅ Acceptable memory usage for typical problem sizes
- ✅ Computational efficiency within reasonable bounds
- ✅ Scaling behavior for increasing problem dimensions

## Dependencies

### Required Packages
- **ForwardDiff.jl**: Automatic differentiation for Hessian computation
- **LinearAlgebra.jl**: Eigenvalue decomposition and matrix operations
- **DataFrames.jl**: Enhanced tabular data management
- **Statistics.jl**: Statistical analysis and validation

### Optional Visualization
- **CairoMakie.jl**: Static publication-quality plots
- **GLMakie.jl**: Interactive 3D visualization and animations

## Future Enhancements

### Phase 3: Advanced Visualization
- Separated minima/maxima statistical graphs with adaptive scaling
- Statistical overlay systems (quartiles, confidence intervals)
- Interactive dashboards for multi-dimensional analysis
- Publication-ready export capabilities

### Advanced Statistical Analysis
- Principal component analysis of Hessian properties
- Clustering analysis of critical point characteristics
- Machine learning classification of critical point quality
- Comparative statistical significance testing

## Contributing

When adding new certification tests or demonstrations:

1. **Follow the standard initialization pattern**:
   ```julia
   using Pkg; using Revise 
   Pkg.activate(joinpath(@__DIR__, "../../"))
   using Globtim; using DynamicPolynomials, DataFrames
   ```

2. **Include comprehensive error handling** for robust certification
3. **Add performance benchmarks** for regression testing
4. **Document mathematical expectations** and validation criteria
5. **Provide clear examples** with expected outputs

## Testing Strategy

### Running All Certification Tests
```julia
# From the Examples/ForwardDiff_Certification directory
include("phase2_certification_suite.jl")
include("forward_diff_unit_tests.jl")
include("integration_validation.jl")
```

### Individual Component Testing
```julia
# Test specific components
include("eigenvalue_analysis_demo.jl")      # Eigenvalue analysis
include("hessian_visualization_demo.jl")   # Visualization functions
```

This certification directory provides comprehensive validation of Phase 2 Hessian analysis capabilities, ensuring mathematical correctness, numerical stability, and computational efficiency across a wide range of optimization problems.

## 📁 Archive Structure

The `archive/` folder contains experimental and legacy files that were consolidated:

- **`archive/experimental/`**: Development versions and orthant decomposition experiments
- **`archive/comparisons/`**: Various comparison scripts between raw and refined critical points
- **`archive/debugging/`**: Minimal debugging and testing tools
- **`documentation/`**: Consolidated documentation files

See `archive/README.md` for detailed information about archived files.

## ✅ Recent Updates & Fixes

### File Consolidation (Latest)
- **Achievement**: Consolidated 12+ redundant deuflhard_4d_* files into single `deuflhard_4d_complete.jl`
- **Structure**: Organized experimental files into clean archive structure
- **Documentation**: Moved all documentation to dedicated `documentation/` folder
- **Status**: ✅ Clean, maintainable structure with single definitive implementation
- **Benefit**: Easy to find and use the best implementation without confusion

### Path Resolution Fixed (Latest)
- **Issue**: Module loading failures due to incorrect `Pkg.activate` paths
- **Fix**: Updated all demo files to use `joinpath(@__DIR__, "../../")` for correct project root activation  
- **Status**: ✅ All demos now run successfully without `UndefVarError` issues
- **Affected Files**: All `.jl` files in this directory now use correct relative paths

### ForwardDiff Compatibility Resolved
- **Issue**: `tref_3d` and other functions had restrictive type signatures causing ForwardDiff failures
- **Fix**: Updated function signatures from `Union{Vector{Float64},SVector{N,Float64}}` to `AbstractVector`
- **Status**: ✅ All critical point classifications now work correctly with automatic differentiation
- **Impact**: Phase 2 analysis now fully functional across all test functions

### Phase 3 Implementation Complete
- **Addition**: Enhanced statistical tables with publication-quality ASCII rendering
- **Files**: `phase3_standalone_demo.jl` demonstrates complete Phase 3 functionality
- **Features**: Robust statistics, condition number quality assessment, mathematical validation
- **Status**: ✅ Production-ready implementation with comprehensive testing

### Verification Commands
```julia
# Test that everything works correctly
include("deuflhard_4d_complete.jl")           # NEW: Complete 4D analysis
include("trefethen_3d_complete_demo.jl")      # Should run without errors
include("phase3_standalone_demo.jl")          # Should display statistical tables
include("phase2_certification_suite.jl")     # Should pass all validations
```

### Quick Start for 4D Deuflhard Analysis
```julia
# Run the consolidated 4D analysis
using Pkg; using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))
using Globtim

# Execute complete analysis
include("deuflhard_4d_complete.jl")
# This will analyze all 16 orthants with automatic tolerance control and BFGS refinement
```

All certification demos are now verified working with the latest fixes.