# API Reference

## Main Functions

### Problem Setup

- **`test_input`** - Create test input specification for optimization problems
- **`Constructor`** - Build polynomial approximation of objective function
- **`solve_polynomial_system`** - Find critical points by solving ∇p(x) = 0
- **`process_crit_pts`** - Process and filter critical point solutions

### Analysis Functions

- **`analyze_critical_points`** - Comprehensive critical point analysis with BFGS refinement
- **`analyze_critical_points_with_tables`** - Enhanced analysis with statistical tables

## Polynomial Approximation

- **`chebyshev_extrema`** - Generate Chebyshev extrema points
- **`chebyshev_polys`** - Evaluate Chebyshev polynomials
- **`grid_sample`** - Create sampling grid for polynomial fitting
- **`sample_objective_on_grid`** - Evaluate objective function on grid

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

## Export Functions

- **`write_tables_to_csv`** - Export tables to CSV format
- **`write_tables_to_latex`** - Export tables to LaTeX format
- **`write_tables_to_markdown`** - Export tables to Markdown format

## Types and Structures

- **`test_input`** - Input specification type
- **`BFGSConfig`** - BFGS configuration parameters
- **`BFGSResult`** - BFGS optimization results
- **`ApproxPoly`** - Polynomial approximation type

---

For detailed function documentation with examples, use the Julia help system:
```julia
julia> ?test_input
julia> ?analyze_critical_points
```