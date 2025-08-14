# API Reference

## Main Functions

### Problem Setup

- **`test_input`** - Create test input specification for optimization problems

#### `Constructor`
Build polynomial approximation with comprehensive precision control and grid support.

**Syntax:**
```julia
Constructor(T::test_input, degree;
           verbose=0, basis=:chebyshev, precision=RationalPrecision,
           normalized=false, power_of_two_denom=false, grid=nothing)
```

**Parameters:**
- `T::test_input`: Problem specification created with `test_input`
- `degree::Int`: Polynomial degree (ignored if `grid` is provided)
- `verbose::Int`: Verbosity level (0=quiet, 1=basic, 2=detailed)
- `basis::Symbol`: Polynomial basis (`:chebyshev` or `:legendre`)
- `precision::PrecisionType`: Numerical precision type (see Precision Parameters below)
- `normalized::Bool`: Whether to use normalized basis functions
- `power_of_two_denom::Bool`: Force power-of-2 denominators for rationals
- `grid::Union{Nothing, Matrix{Float64}}`: Pre-generated sampling grid

**Precision Parameters:**
- `Float64Precision`: Standard double precision (fastest, ~15 digits accuracy)
- `AdaptivePrecision`: Hybrid Float64/BigFloat approach (recommended, excellent accuracy/performance balance)
- `RationalPrecision`: Exact rational arithmetic (exact but slow)
- `BigFloatPrecision`: Extended precision throughout (slowest, maximum accuracy)

**Examples:**
```julia
# Basic usage with AdaptivePrecision (recommended)
TR = test_input(Deuflhard, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8, precision=AdaptivePrecision)

# High-performance batch processing
pol_fast = Constructor(TR, 6, precision=Float64Precision, verbose=0)

# Exact arithmetic for research
pol_exact = Constructor(TR, 4, precision=RationalPrecision)

# Custom grid with precision control
grid = generate_anisotropic_grid([10, 8], basis=:chebyshev)
grid_matrix = convert_to_matrix_grid(vec(grid))
pol_custom = Constructor(TR, 0, grid=grid_matrix, precision=AdaptivePrecision)
```

**Returns:** `ApproxPoly` object with fields:
- `coeffs`: Polynomial coefficients (type depends on precision parameter)
- `nrm`: L²-norm approximation error
- `precision`: Precision type used
- Additional metadata fields
- **`MainGenerate`** - Core polynomial approximation engine
  - Supports degree-based or grid-based input
  - Automatic anisotropic grid detection
  - Returns `ApproxPoly` with L2-norm error
- **`solve_polynomial_system`** - Find critical points by solving ∇p(x) = 0
  - New convenience method: accepts `ApproxPoly` object directly
  - Automatically extracts dimension and degree information
  - Handles both single variables and variable vectors
- **`process_crit_pts`** - Process and filter critical point solutions
  - Enhanced for 1D functions: automatically handles scalar functions like `sin(x)`
  - Intelligently detects whether function expects scalar or vector input

### Analysis Functions

- **`analyze_critical_points`** - Comprehensive critical point analysis with BFGS refinement
- **`analyze_critical_points_with_tables`** - Enhanced analysis with statistical tables

## Polynomial Approximation

### Core Functions
- **`chebyshev_extrema`** - Generate Chebyshev extrema points
- **`chebyshev_polys`** - Evaluate Chebyshev polynomials
- **`grid_sample`** - Create sampling grid for polynomial fitting
- **`sample_objective_on_grid`** - Evaluate objective function on grid

### Vandermonde Matrix Construction
- **`lambda_vandermonde`** - Construct Vandermonde matrix with automatic anisotropic detection
- **`lambda_vandermonde_anisotropic`** - Enhanced Vandermonde for anisotropic grids
- **`is_grid_anisotropic`** - Check if grid has different nodes per dimension
- **`analyze_grid_structure`** - Extract detailed grid structure information

## Critical Point Analysis

### Core Analysis
- **`compute_hessians`** - Compute Hessian matrices at critical points
- **`classify_critical_points`** - Classify points based on eigenvalues
- **`store_all_eigenvalues`** - Store complete eigenvalue information
- **`extract_critical_eigenvalues`** - Extract key eigenvalues for minima/maxima

### Statistical Measures
- **`compute_hessian_norms`** - Calculate Frobenius norms of Hessians
- **`compute_eigenvalue_stats`** - Compute eigenvalue statistics
- **`analyze_basins`** - Analyze basins of attraction

## BFGS Refinement

- **`enhanced_bfgs_refinement`** - Advanced BFGS with hyperparameter tracking
- **`refine_with_enhanced_bfgs`** - Apply BFGS refinement to DataFrame
- **`determine_convergence_reason`** - Analyze optimization convergence

## Precision Control and Extended Arithmetic

### Precision Types
- **`PrecisionType`** - Enum defining available precision types:
  - `Float64Precision`: Standard IEEE 754 double precision
  - `AdaptivePrecision`: Hybrid Float64/BigFloat for optimal balance
  - `RationalPrecision`: Exact rational arithmetic with `Rational{BigInt}`
  - `BigFloatPrecision`: Extended precision with configurable bit count

### Precision-Aware Functions
- **`_convert_value`** - Convert numeric values between precision types
- **`_convert_value_adaptive`** - Adaptive precision conversion with magnitude-based selection

### Extended Precision Analysis
- **`analyze_coefficient_distribution`** - Analyze polynomial coefficient distribution for truncation guidance
- **`truncate_polynomial_adaptive`** - Smart truncation preserving extended precision
- **`precision_from_type`** - Determine appropriate PrecisionType from numeric type

**Example: Precision-aware workflow**
```julia
# Create polynomial with AdaptivePrecision
pol = Constructor(TR, 10, precision=AdaptivePrecision)

# Convert to extended precision monomial basis
@polyvar x[1:2]
mono_poly = to_exact_monomial_basis(pol, variables=x)

# Analyze coefficient distribution
analysis = analyze_coefficient_distribution(mono_poly)
println("Dynamic range: $(analysis.dynamic_range)")
println("Suggested thresholds: $(analysis.suggested_thresholds)")

# Apply adaptive truncation
threshold = analysis.suggested_thresholds[1]
truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)
println("Sparsity achieved: $(round(stats.sparsity_ratio*100, digits=1))%")
```

## Exact Arithmetic and Sparsification

### Exact Conversion
- **`to_exact_monomial_basis`** - Convert polynomial from orthogonal to monomial basis with precision preservation
- **`exact_polynomial_coefficients`** - Get exact monomial coefficients from function

### L²-Norm Analysis
- **`compute_l2_norm_vandermonde`** - Compute L²-norm using Vandermonde matrices
- **`compute_l2_norm_coeffs`** - Compute L²-norm with modified coefficients
- **`compute_l2_norm`** - Compute L²-norm over a domain
- **`verify_truncation_quality`** - Verify L²-norm preservation after truncation
- **`integrate_monomial`** - Analytically integrate monomials

### Sparsification
- **`sparsify_polynomial`** - Zero small coefficients with L²-norm tracking
- **`analyze_sparsification_tradeoff`** - Analyze sparsity vs accuracy
- **`compute_approximation_error`** - Compute error between function and polynomial
- **`analyze_approximation_error_tradeoff`** - Analyze error under sparsification

### Truncation
- **`truncate_polynomial`** - Remove small terms with L²-norm monitoring
- **`monomial_l2_contributions`** - Compute L²-norm contribution per monomial
- **`analyze_truncation_impact`** - Analyze truncation effects

### Domain Types
- **`BoxDomain{T}`** - Box domain [-a,a]ⁿ representation
- **`AbstractDomain`** - Abstract type for integration domains

## Utility Functions

### Domain Handling
- **`points_in_hypercube`** - Check if points lie within domain
- **`points_in_range`** - Filter points by function value range

### Spatial Analysis
- **`assign_spatial_regions`** - Assign region IDs for spatial statistics
- **`cluster_function_values`** - Cluster points by function values
- **`compute_nearest_neighbors`** - Find nearest neighbor distances
- **`compute_gradients`** - Compute gradient norms

## Visualization Functions

Available when CairoMakie or GLMakie are loaded:

### Basic Plots
- **`plot_hessian_norms`** - Scatter plot of Hessian norms
- **`plot_condition_numbers`** - Log-scale condition number visualization
- **`plot_critical_eigenvalues`** - Critical eigenvalue validation plots

### Advanced Visualizations
- **`plot_all_eigenvalues`** - Complete eigenvalue spectrum visualization
- **`plot_raw_vs_refined_eigenvalues`** - Compare eigenvalues before/after refinement

## Built-in Test Functions

### 2D Functions
- **`Deuflhard`** - Challenging function with multiple minima
- **`HolderTable`** - Four symmetric global minima
- **`Ackley`** - Classic multimodal benchmark
- **`camel`** - Six-hump camel function
- **`shubert`** - Highly multimodal function

### 3D Functions
- **`tref_3d`** - Highly oscillatory 3D function

### n-Dimensional Functions
- **`Rastringin`** - Classic multimodal benchmark (scalable)
- **`alpine1`**, **`alpine2`** - Alpine functions
- **`Csendes`** - Smooth function with single minimum

## Grid Generation and L²-Norm Computation

### Grid Generation
- **`generate_grid`** - Generate isotropic grid with same points per dimension
- **`generate_anisotropic_grid`** - Generate grid with different points per dimension
- **`get_grid_dimensions`** - Extract number of points in each dimension
- **`is_anisotropic`** - Check if grid has different points per dimension

### Grid Format Conversion
- **`grid_to_matrix`** - Convert Array{SVector} grid to matrix format
- **`ensure_matrix_format`** - Ensure grid is in matrix format for BLAS operations
- **`matrix_to_grid`** - Convert matrix back to Array{SVector} format
- **`get_grid_info`** - Query grid format and dimensions

### L²-Norm Computation
- **`discrete_l2_norm_riemann`** - Compute L²-norm using Riemann sum on grid
- **`compute_l2_norm_quadrature`** - Compute L²-norm using polynomial quadrature

## Export Functions

- **`write_tables_to_csv`** - Export tables to CSV format
- **`write_tables_to_latex`** - Export tables to LaTeX format
- **`write_tables_to_markdown`** - Export tables to Markdown format

## Types and Structures

### Core Types
- **`test_input`** - Input specification type for optimization problems
- **`ApproxPoly`** - Polynomial approximation type with precision information
  - Fields include `coeffs`, `nrm`, `precision`, and metadata
  - Coefficient type depends on precision parameter used in Constructor

### Precision Types
- **`PrecisionType`** - Enum for numerical precision control
  - Exported values: `Float64Precision`, `AdaptivePrecision`, `RationalPrecision`, `BigFloatPrecision`
  - Used in `Constructor` and related functions

### Analysis Types
- **`BFGSConfig`** - BFGS configuration parameters
- **`BFGSResult`** - BFGS optimization results
- **`BoxDomain{T}`** - Domain specification for L²-norm computation

### Precision-Aware Type Examples
```julia
# Different coefficient types based on precision
pol_f64 = Constructor(TR, 6, precision=Float64Precision)
typeof(pol_f64.coeffs[1])  # Float64

pol_adaptive = Constructor(TR, 6, precision=AdaptivePrecision)
typeof(pol_adaptive.coeffs[1])  # Float64 (raw coefficients)

# Extended precision in monomial expansion
@polyvar x[1:2]
mono_poly = to_exact_monomial_basis(pol_adaptive, variables=x)
coeffs = [coefficient(t) for t in terms(mono_poly)]
typeof(coeffs[1])  # BigFloat (extended precision)

pol_rational = Constructor(TR, 6, precision=RationalPrecision)
typeof(pol_rational.coeffs[1])  # Rational{BigInt}
```

---

For detailed function documentation with examples, use the Julia help system:
```julia
julia> ?test_input
julia> ?analyze_critical_points
```