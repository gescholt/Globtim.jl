# CLAUDE.md - AI Assistant Development Guide

This file provides structured guidance for AI assistants (Claude Code) working with the Globtim Julia package.

## 🚀 Quick Start for AI Assistants

### Essential Commands
```julia
# Setup development environment
]dev .
using Revise, Pkg; Pkg.activate("."); using Globtim

# Run tests
]test Globtim

# Basic workflow
# Proper initialization for examples
using Pkg; using Revise 
Pkg.activate(joinpath(@__DIR__, "../"))  # Adjust path as needed
using Globtim; using DynamicPolynomials, DataFrames

f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)  # Can use integer (auto-converts to (:one_d_for_all, 8))
@polyvar x[1:2]
crit_pts = solve_polynomial_system(x, 2, 8, pol.coeffs)
```

### File Locations (AI Quick Reference)
- **Core logic**: `src/Main_Gen.jl` (Constructor), `src/hom_solve.jl` (solving)
- **Data structures**: `src/Structures.jl` (ApproxPoly, test_input)
- **Test functions**: `src/LibFunctions.jl`
- **Phase 2 Hessian**: `src/hessian_analysis.jl`, `src/hessian_visualization.jl`
- **Phase 3 Tables**: `src/statistical_tables.jl`, `src/table_rendering.jl`, `src/enhanced_analysis.jl`
- **Examples**: `Examples/Notebooks/` (Jupyter notebooks), `Examples/ForwardDiff_Certification/` (Phase 2/3 demos)
- **Tests**: `test/runtests.jl`, `test/test_hessian_analysis.jl`

## 📋 Project Overview

**Globtim** = Global optimization via polynomial approximation
- **Input**: Continuous function f: ℝⁿ → ℝ over compact domain
- **Output**: All local minima (not just global minimum)
- **Method**: Chebyshev/Legendre polynomial approximation + critical point solving

### Core Algorithm (3 Steps)
1. **Sample**: Function on tensorized Chebyshev/Legendre grid
2. **Approximate**: Construct polynomial via discrete least squares
3. **Solve**: Find critical points using HomotopyContinuation.jl or Msolve

## 🔧 AI Assistant Workflow

### Common Tasks & File Locations

| Task | Primary Files | Key Functions |
|------|---------------|---------------|
| Add test function | `src/LibFunctions.jl` | Export in `src/Globtim.jl` |
| Fix polynomial construction | `src/Main_Gen.jl` | `Constructor`, `MainGenerate` |
| Debug critical point solving | `src/hom_solve.jl` | `solve_polynomial_system` |
| Improve type stability | `src/Structures.jl` | `ApproxPoly{T,S}` |
| Add visualization | `src/graphs_*.jl` | CairoMakie/GLMakie functions |
| Performance optimization | `src/scaling_utils.jl` | TimerOutputs integration |

### Testing Strategy
```julia
# Always run these after changes
]test Globtim                    # Full test suite
includet("test/runtests.jl")     # With Revise for iteration
using BenchmarkTools; @benchmark func()  # Performance check
```

## 🎯 Critical Code Patterns

### Type-Stable ApproxPoly
```julia
# GOOD: Type-stable scale factors
ApproxPoly{Float64,Float64}(...)      # Scalar scaling
ApproxPoly{Float64,Vector{Float64}}(...) # Per-dimension scaling

# Accessing scale factors
get_scale_factor(pol)  # Type-stable accessor
```

### Function Construction Workflow
```julia
# Proper initialization for examples
using Pkg; using Revise 
Pkg.activate(joinpath(@__DIR__, "../"))  # Adjust path as needed
using Globtim; using DynamicPolynomials, DataFrames

# 1. Create test input (handles domain scaling)
TR = test_input(f; dim=2, center=[0.0, 0.0], sample_range=1.2)

# 2. Build polynomial approximation
pol = Constructor(TR, degree; basis=:chebyshev, verbose=false)

# 3. Solve polynomial system
@polyvar x[1:TR.dim]
solutions = solve_polynomial_system(x, TR.dim, degree, pol.coeffs; basis=pol.basis)

# 4. Process results
df = process_crit_pts(solutions, TR.objective, TR)
```

## 🎯 Degree Format Specification

### Overview
The degree parameter in Globtim uses a tuple format `(format_symbol, value)` to specify how polynomial degrees are handled across dimensions. For backward compatibility, plain integers are automatically converted to `(:one_d_for_all, degree)`.

### Format Options

#### 1. `:one_d_for_all` (Default)
**Usage**: `(:one_d_for_all, degree)` or just `degree`
- Applies the same maximum degree to all dimensions
- Creates a standard total degree polynomial space
- Most commonly used format

```julia
# These are equivalent:
pol = Constructor(TR, 10)                    # Auto-converted
pol = Constructor(TR, (:one_d_for_all, 10)) # Explicit
```

#### 2. `:one_d_per_dim`
**Usage**: `(:one_d_per_dim, [d₁, d₂, ..., dₙ])`
- Specifies different maximum degrees per dimension
- Creates a tensor product polynomial space
- Useful for anisotropic problems

```julia
d = (:one_d_per_dim, [10, 2, 13])  # x₁≤10, x₂≤2, x₃≤13
pol = Constructor(TR, d)
```

#### 3. `:fully_custom`
**Usage**: `(:fully_custom, custom_support)`
- Complete control over monomial support
- User provides exact exponent vectors
- For advanced use cases

```julia
# Using EllipseSupport function
d = (:fully_custom, EllipseSupport([0, 0, 0], [1, 1, 1], 300))
pol = Constructor(TR, d)
```

## 🐛 Common Issues & Solutions

### Issue: Type Instability
**Symptoms**: `@code_warntype` shows `Union` types
**Solution**: Use parameterized `ApproxPoly{T,S}` structure
**Files**: `src/Structures.jl`, `src/scaling_utils.jl`

### Issue: BFGS Non-Convergence
**Status**: ✅ **NORMAL BEHAVIOR** - Not a bug
**Explanation**: Expected when starting points are poorly conditioned
**File**: `src/refine.jl:76` (`analyze_critical_points`)

### Issue: Polynomial System Too Large
**Solution**: Reduce degree or use domain decomposition
**Parameters**: Start with degree 8-12, max ~25 for dim > 3

### Issue: Memory Allocations
**Tools**: `@profile`, `@allocations`, `@benchmark`
**Hotspots**: Grid generation, polynomial construction
**Files**: `src/Samples.jl`, `src/Main_Gen.jl`

### Issue: Visualization Extension Loading
**Symptoms**: `UndefVarError: plot_hessian_norms not defined` or extension precompilation warnings
**Root Cause**: Julia package extension system requires specific function declaration patterns
**Solution**: 
1. **Correct Pattern**: Functions declared with `function name end` in main module (`src/hessian_analysis.jl`)
2. **Extended by**: Extensions using `function ModuleName.function_name(args)` syntax
3. **Load Order**: Import `CairoMakie` or `GLMakie` before calling visualization functions
**Files**: `src/hessian_analysis.jl`, `ext/GlobtimCairoMakieExt.jl`, `ext/GlobtimGLMakieExt.jl`

**Example Usage**:
```julia
using CairoMakie  # Load extension first
fig = plot_hessian_norms(df_enhanced)  # Now available
```

## 📊 Performance Guidelines

### Degree Selection
- **Exploration**: degree 8-12
- **High accuracy**: degree 15-20
- **Limit**: degree > 25 slow for dim > 3

### Dimension Guidelines
- **Small (≤ 4)**: Use StaticArrays (automatic)
- **Medium (5-8)**: Standard arrays, consider parallelization
- **Large (> 8)**: Domain decomposition needed

### Memory Optimization
- Use `@views` for array slicing
- Prefer in-place operations
- Profile with `@allocated` macro

## 🔍 Debugging Toolkit

### Enable Verbose Output
```julia
pol = Constructor(TR, 8, verbose=true)
println("Condition number: ", pol.cond_vandermonde)
println("Basis: ", get_basis(pol))
```

### Performance Profiling
```julia
using Profile, BenchmarkTools, TimerOutputs
@profile Constructor(TR, 8)
@benchmark Constructor(TR, 8)
# TimerOutputs automatically enabled in package
```

### Type Analysis
```julia
@code_warntype Constructor(TR, 8)  # Check type stability
@which method(args...)             # Find method dispatch
```

## 📚 API Quick Reference

### Core Data Structures
```julia
# Proper initialization for examples
using Pkg; using Revise 
Pkg.activate(joinpath(@__DIR__, "../"))  # Adjust path as needed
using Globtim; using DynamicPolynomials, DataFrames

# test_input - Problem specification
TR = test_input(f; dim=2, center=[0,0], sample_range=1.0, degree_max=20)

# ApproxPoly{T,S} - Type-stable polynomial approximation
pol = Constructor(TR, degree; basis=:chebyshev, verbose=false)
```

### Main Functions
```julia
# Polynomial construction
Constructor(TR::test_input, degree; basis=:chebyshev, verbose=false)
# degree can be: Int, (:one_d_for_all, Int), (:one_d_per_dim, Vector), or (:fully_custom, Matrix)

# Critical point solving  
solve_polynomial_system(x, n, d, coeffs; basis=:chebyshev)
# d accepts same formats as Constructor

# Post-processing
process_crit_pts(solutions, f, TR)
analyze_critical_points(f, df, TR; tol_dist=0.025, enable_hessian=true)
```

### Test Functions (src/LibFunctions.jl)
- `Deuflhard`: 2D, multiple critical points
- `HolderTable`: 2D, 4 global minima  
- `tref_3d`: 3D challenging function
- `dejong5`: 2D, 25 local minima

## 🔬 Phase 2: Hessian-Based Critical Point Classification

### Overview
Phase 2 provides advanced critical point analysis using Hessian matrix eigenvalue decomposition. This feature adds rigorous mathematical classification and detailed eigenvalue statistics to the standard workflow.

### Key Features
- **Automatic Classification**: :minimum, :maximum, :saddle, :degenerate, :error
- **Eigenvalue Analysis**: Complete eigenvalue statistics and condition numbers
- **Validation Metrics**: Specialized eigenvalues for minima/maxima verification
- **Visualization**: Dedicated plots for Hessian properties

### Core Workflow
```julia
# Standard Phase 1 + Phase 2 workflow
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Phase 1 + Phase 2 analysis (recommended)
df_enhanced, df_min = analyze_critical_points(f, df, TR, enable_hessian=true)

# Phase 1 only (legacy)
df_phase1, df_min = analyze_critical_points(f, df, TR, enable_hessian=false)
```

### Phase 2 DataFrame Columns
When `enable_hessian=true`, the following columns are added:

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

### Phase 2 Functions
```julia
# Core Hessian analysis
hessians = compute_hessians(f, points_matrix)
classifications = classify_critical_points(hessians)
all_eigenvalues = store_all_eigenvalues(hessians)
smallest_pos, largest_neg = extract_critical_eigenvalues(classifications, all_eigenvalues)
norms = compute_hessian_norms(hessians)
stats = compute_eigenvalue_stats(hessians)

# Visualization
plot_hessian_norms(df_enhanced)
plot_condition_numbers(df_enhanced)  
plot_critical_eigenvalues(df_enhanced)
```

### Classification Rules
- **:minimum**: All eigenvalues > `hessian_tol_zero` (default 1e-8)
- **:maximum**: All eigenvalues < -`hessian_tol_zero`
- **:saddle**: Mixed positive and negative eigenvalues
- **:degenerate**: At least one eigenvalue ≈ 0
- **:error**: Hessian computation failed

### Performance Considerations
- **Computation**: O(n×m²) for Hessians, O(n×m³) for eigenvalues
- **Memory**: Additional O(n×m²) storage for n points in m dimensions
- **Recommendation**: Use for final analysis, not exploratory runs

### Example: Complete Analysis
```julia
# Proper initialization for examples
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../"))  # Adjust path as needed
using Globtim
using DynamicPolynomials, DataFrames

# Comprehensive example with Phase 2
f = Rastringin
TR = test_input(f, dim=3, center=[0.0, 0.0, 0.0], sample_range=1.0)
pol = Constructor(TR, 10)
@polyvar x[1:3]
solutions = solve_polynomial_system(x, 3, 10, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Phase 2 analysis with custom tolerance
df_enhanced, df_min = analyze_critical_points(
    f, df, TR, 
    enable_hessian=true, 
    hessian_tol_zero=1e-10,
    verbose=true
)

# Analyze results
println("Classification summary:")
println(combine(groupby(df_enhanced, :critical_point_type), nrow => :count))

# Check minima validation
minima_mask = df_enhanced.critical_point_type .== :minimum
println("Minima smallest positive eigenvalue range:")
println(extrema(filter(!isnan, df_enhanced.smallest_positive_eigenval[minima_mask])))
```

## 🔬 Phase 3: Enhanced Statistical Tables

### Overview
Phase 3 extends Phase 2 with comprehensive statistical table displays that provide detailed analysis of critical point properties. This enhancement adds publication-quality ASCII tables for console output and comprehensive statistical breakdowns.

### Key Features
- **Type-Specific Analysis**: Separate detailed statistics for minimum, maximum, saddle, and degenerate points
- **Condition Number Quality Assessment**: Classification of numerical stability (excellent/good/fair/poor/critical)
- **Mathematical Validation**: Eigenvalue sign verification and consistency checks
- **Professional Formatting**: Publication-quality ASCII tables with proper borders and alignment
- **Comparative Analysis**: Multi-type summary tables for comprehensive overview
- **Export Capabilities**: Save tables in multiple formats for documentation and reporting

### Core Workflow
```julia
# Enhanced Phase 2 + Phase 3 analysis with statistical tables
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Phase 3 analysis with comprehensive statistical tables
df_enhanced, df_min, tables, stats_objects = analyze_critical_points_with_tables(
    f, df, TR,
    enable_hessian=true,
    show_tables=true,
    table_format=:console,
    table_types=[:minimum, :maximum, :saddle]
)
```

### Phase 3 Functions
```julia
# Enhanced analysis with statistical tables
analyze_critical_points_with_tables(f, df, TR; enable_hessian=true, show_tables=true)

# Individual statistical table generation
stats = compute_type_specific_statistics(df_enhanced, :minimum)
table = render_console_table(stats, width=80)

# Quick preview for exploration
quick_table_preview(f, df, TR, point_types=[:minimum, :maximum])

# Export tables for documentation
export_analysis_tables(tables, "analysis_results", formats=[:console, :markdown])

# Display individual tables
display_statistical_table(stats, width=80)

# Create comparative summary
summary = create_statistical_summary(df_enhanced)
```

### Statistical Table Content

#### Basic Statistics Section
- **Count**: Total number of critical points of the specified type
- **Mean ± Std**: Average Hessian norm with standard deviation
- **Median (IQR)**: Median with interquartile range (Q1-Q3)
- **Range**: Minimum and maximum values [min, max]
- **Outliers**: Count and percentage of statistical outliers (>1.5×IQR)

#### Condition Number Quality Assessment
- **Excellent (< 1e3)**: Well-conditioned points with high numerical reliability
- **Good (1e3-1e6)**: Acceptable numerical quality for most applications
- **Fair (1e6-1e9)**: Marginal numerical quality, may need attention
- **Poor (1e9-1e12)**: Poor conditioning, results may be unreliable
- **Critical (≥ 1e12)**: Numerically unstable, requires careful interpretation
- **Overall Quality**: Aggregate assessment (EXCELLENT/GOOD/FAIR/POOR)

#### Mathematical Validation Section
- **Eigenvalue Sign Verification**: Check that eigenvalue signs match critical point type
- **Positive/Negative Eigenvalue Counts**: Detailed breakdown for validation
- **Determinant Analysis**: Sign consistency and mathematical correctness
- **Mixed Eigenvalue Signs**: Validation for saddle points

### Example Statistical Table Output
```
┌──────────────────────────────────────────────────────────────────────────┐
│                          MINIMUM STATISTICS                              │
├──────────────────────────────────────────────────────────────────────────┤
│ Count                         │                                       3  │
│ Mean ± Std                    │                           2.450 ± 0.850  │
│ Median (IQR)                  │                    2.100 (1.800-3.200)  │
│ Range                         │                          [1.200, 3.800]  │
│ Outliers                      │                               0 (0.0%)  │
├──────────────────────────────────────────────────────────────────────────┤
│                       CONDITION NUMBER QUALITY                          │
├──────────────────────────────────────────────────────────────────────────┤
│ Excellent (< 1e3)             │                               3 (100%)  │
│ Good (1e3-1e6)                │                                 0 (0%)  │
│ Fair (1e6-1e9)                │                                 0 (0%)  │
│ Poor (1e9-1e12)               │                                 0 (0%)  │
│ Critical (≥ 1e12)             │                                 0 (0%)  │
│ Overall Quality               │                              EXCELLENT  │
├──────────────────────────────────────────────────────────────────────────┤
│                        MATHEMATICAL VALIDATION                          │
├──────────────────────────────────────────────────────────────────────────┤
│ All eigenvalues positive      │                                ✓ YES   │
│ Positive eigenvalue count     │                                    3   │
│ Determinant positive          │                                ✓ YES   │
└──────────────────────────────────────────────────────────────────────────┘
```

### Advanced Usage

#### Publication-Ready Analysis
```julia
# Comprehensive analysis with export for publications
df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(
    f, df, TR,
    enable_hessian=true,
    show_tables=true,
    table_format=:console,
    table_types=[:minimum, :maximum, :saddle],
    export_tables=true,
    export_prefix="publication_analysis"
)

# Export in multiple formats
export_analysis_tables(tables, "final_analysis", 
                      formats=[:console, :markdown, :latex])
```

#### Quick Exploration Workflow
```julia
# Fast preview for initial exploration
quick_table_preview(f, df, TR, point_types=[:minimum])

# Full analysis after confirming results are interesting
df_enhanced, df_min, tables, stats = analyze_critical_points_with_tables(
    f, df, TR, enable_hessian=true, show_tables=true
)
```

### Integration with Existing Workflow
Phase 3 maintains full backward compatibility with existing code:
- All existing Phase 1 and Phase 2 functions work unchanged
- `analyze_critical_points` continues to work as before
- Phase 3 functions are optional extensions that enhance the analysis
- Tables can be disabled by setting `show_tables=false`

### File Structure for Phase 3
- **Core Implementation**: `src/statistical_tables.jl`, `src/table_rendering.jl`, `src/enhanced_analysis.jl`
- **Examples**: `Examples/ForwardDiff_Certification/phase3_standalone_demo.jl`
- **Tests**: `test/test_statistical_tables.jl`, `test/test_enhanced_analysis_integration.jl`
- **Documentation**: Phase 3 implementation plan in `docs/phase3/`

## 🧪 ForwardDiff Certification Directory

### Overview
The `Examples/ForwardDiff_Certification/` directory provides a comprehensive testing and validation framework for Phase 2 and Phase 3 features, ensuring ForwardDiff.jl compatibility and numerical reliability.

### Directory Structure
```
Examples/ForwardDiff_Certification/
├── README.md                        # Comprehensive documentation
├── INDEX.md                         # Quick navigation guide
├── phase2_certification_suite.jl    # Main Phase 2 validation suite
├── forward_diff_unit_tests.jl       # ForwardDiff compatibility tests
├── eigenvalue_analysis_demo.jl      # Eigenvalue computation validation
├── hessian_visualization_demo.jl    # Phase 2 visualization examples
├── trefethen_3d_complete_demo.jl    # Complete 3D analysis demo
├── phase3_standalone_demo.jl        # Phase 3 tables demonstration
└── test_phase1_enhanced_stats.jl    # Phase 1 statistics validation
```

### Key Features
- ✅ **Comprehensive Testing**: Validates all Phase 2 and Phase 3 functionality
- ✅ **ForwardDiff Compatibility**: Ensures automatic differentiation works correctly
- ✅ **Mathematical Validation**: Verifies eigenvalue signs and critical point classifications
- ✅ **Statistical Analysis**: Tests robust statistics and table rendering
- ✅ **Visualization Examples**: Demonstrates Phase 2 plotting capabilities
- ✅ **Performance Benchmarks**: Assesses computational efficiency

### Usage Examples
```julia
# Run complete Phase 2/3 certification
include("Examples/ForwardDiff_Certification/phase2_certification_suite.jl")

# Test specific 3D function analysis
include("Examples/ForwardDiff_Certification/trefethen_3d_complete_demo.jl")

# Demonstrate Phase 3 statistical tables
include("Examples/ForwardDiff_Certification/phase3_standalone_demo.jl")
```

### Initialization Pattern
All certification files use the standardized initialization:
```julia
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))  # Correct path to project root
using Globtim
using DynamicPolynomials, DataFrames
```

## 🎨 Visualization

### Backends
- **CairoMakie**: Static plots (prioritized for publication)
- **GLMakie**: Interactive 3D, animations

### Standard Plots
```julia
using CairoMakie
plot_2d_function(f, TR, critical_points=df)
plot_polyapprox_3d(pol, f, TR)  # 3D surface
```

### Phase 2 Visualization
```julia
# Load visualization backend first (required for extensions)
using CairoMakie  # or using GLMakie

# Hessian analysis plots
plot_hessian_norms(df_enhanced)           # Scatter plot of ||H||_F
plot_condition_numbers(df_enhanced)       # Log-scale condition numbers  
plot_critical_eigenvalues(df_enhanced)    # Minima/maxima eigenvalues
```

## 🧪 Testing Patterns

### Test Structure
```julia
@testset "Feature Name" begin
    # Setup
    f = test_function
    TR = test_input(f; dim=2)
    
    # Test
    pol = Constructor(TR, 8)
    @test pol.degree == 8
    @test typeof(pol.coeffs) <: Vector
    
    # Performance check (optional)
    @test (@allocated Constructor(TR, 8)) < 1_000_000  # < 1MB
end
```

### Regression Testing
- Always test that modifications don't break existing functionality
- Check performance hasn't regressed significantly
- Verify type stability is maintained

## ⚡ AI Assistant Best Practices

### Before Making Changes
1. **Read relevant files** using Read tool
2. **Run existing tests** to understand current behavior  
3. **Profile performance** if optimization is the goal
4. **Check type stability** with `@code_warntype`

### When Adding Features
1. **Follow existing patterns** in the codebase
2. **Add tests** for new functionality
3. **Update docstrings** with examples
4. **Check performance impact**

### When Debugging
1. **Use verbose output** to understand execution flow
2. **Add TimerOutputs** to identify bottlenecks
3. **Check intermediate results** at each algorithm step
4. **Verify mathematical correctness** of approximations

## 📦 Package Integration Status

### Core Features (Always Available)
When you load Globtim with `using Globtim`, these features are immediately available:

**Phase 1: Polynomial Approximation**
- `test_input`, `Constructor`, `solve_polynomial_system`
- All test functions (Deuflhard, Rastringin, tref_3d, etc.)
- Chebyshev/Legendre polynomial construction
- Critical point finding and basic analysis

**Phase 2: Hessian Classification** 
- `analyze_critical_points(enable_hessian=true)` - Complete Hessian analysis
- All computation functions: `compute_hessians`, `classify_critical_points`, etc.
- Eigenvalue analysis and critical point type classification
- Statistical analysis of Hessian properties

**Phase 3: Statistical Tables**
- `analyze_critical_points_with_tables()` - Enhanced analysis with tables
- ASCII table rendering with publication-quality formatting
- Export capabilities and comparative analysis
- No external dependencies required

### Optional Features (Require External Loading)

**Visualization (Extension-Based)**
```julia
# Required BEFORE calling visualization functions
using CairoMakie  # for static plots
# OR
using GLMakie     # for interactive plots

# Then these become available:
plot_hessian_norms(df_enhanced)
plot_condition_numbers(df_enhanced) 
plot_critical_eigenvalues(df_enhanced)
```

**Key Points:**
- ✅ **All computational features** are built into Globtim
- ✅ **Statistical analysis** works without any external packages
- ⚠️ **Visualization functions** require Makie backends to be loaded first
- 🔧 **Extensions auto-load** when you import CairoMakie/GLMakie

## 📝 Current Status

### ✅ Fully Integrated in Globtim Package
- **Core Polynomial Approximation**: All tests passing, type-stable ApproxPoly structure
- **Performance Monitoring**: TimerOutputs profiling integrated
- **Solver Integration**: HomotopyContinuation.jl and Msolve systems
- **Orthogonal Polynomials**: Chebyshev and Legendre basis support with unified interface
- **Flexible Degree System**: Full backward compatibility with new format options
- **Phase 2 Hessian Analysis**: Complete ForwardDiff-based critical point classification
  - `compute_hessians`, `classify_critical_points`, `store_all_eigenvalues`
  - `extract_critical_eigenvalues`, `compute_hessian_norms`, `compute_eigenvalue_stats`
  - Integrated into `analyze_critical_points(enable_hessian=true)`
- **Phase 3 Statistical Tables**: Publication-quality ASCII table rendering
  - `analyze_critical_points_with_tables`, `compute_type_specific_statistics`
  - `render_console_table`, `export_analysis_tables`, `quick_table_preview`
- **Enhanced Analysis Pipeline**: Complete critical point workflow with statistical validation
- **Comprehensive Testing**: ForwardDiff certification suite with validation framework

### ✅ Extension-Based Features (Require External Loading)
- **Phase 2 Visualization**: Makie-based plotting functions
  - `plot_hessian_norms`, `plot_condition_numbers`, `plot_critical_eigenvalues`
  - **Required**: `using CairoMakie` or `using GLMakie` before calling functions
  - **Extensions**: `GlobtimCairoMakieExt.jl`, `GlobtimGLMakieExt.jl`
- **Legacy Visualization**: Existing 2D/3D plotting functions
  - Requires Makie backends loaded externally

### 🔄 In Progress  
- Performance optimization for large-scale problems  
- Extended test coverage for edge cases
- Additional export formats for statistical tables (LaTeX, Markdown)

### ⚠️ Known Limitations
- Level set visualization needs optimization for 3D+
- BFGS non-convergence is normal behavior (not a bug)
- Memory usage could be optimized for large problems

## 🏗️ Development Setup

### Environment
```julia
# Development setup
]dev .
using Revise
using Pkg; Pkg.activate(".")
using Globtim

# Required for examples
using DynamicPolynomials, DataFrames, StaticArrays
using CairoMakie  # or GLMakie
```

### Example File Template
**IMPORTANT**: All new example files and code blocks should use this standardized initialization pattern:

```julia
# Proper way to initiate example files when developing new features
using Pkg
using Revise 
Pkg.activate(joinpath(@__DIR__, "../../"))  # Adjust path based on directory depth
using Globtim
using DynamicPolynomials, DataFrames

# Add other required packages as needed
# using StaticArrays, CairoMakie, etc.
```

**Path Configuration by Directory:**
- **Examples/**: Use `joinpath(@__DIR__, "../")` (one level up)
- **Examples/ForwardDiff_Certification/**: Use `joinpath(@__DIR__, "../../")` (two levels up)
- **Examples/Notebooks/**: Use `joinpath(@__DIR__, "../../")` (two levels up)

**Benefits of this standardized initialization:**
- ✅ **Consistent environment setup** across all examples
- ✅ **Revise.jl integration** for interactive development and debugging
- ✅ **Correct relative path handling** for all directory structures
- ✅ **Prevents module loading issues** and UndefVarError problems
- ✅ **Works in both REPL and script execution**

This ensures:
- Proper package activation relative to the project root directory
- Revise.jl is loaded for interactive development
- Core dependencies are available
- Fresh module loading to avoid stale session issues

### Git Workflow
- **Main branch**: `clean-version` (for PRs)
- **Current branch**: `github-release`
- **Remote**: `origin` (git@git.mpi-cbg.de:scholten/globtim.git)

## REPL Testing

### REPL Guidelines
- Let the user run the tests in REPL
- Provide clear instructions for interactive testing
- Support debugging and exploration

This streamlined guide prioritizes information most relevant to AI assistants working on the codebase. For comprehensive details, see the full documentation in individual source files.