# API Reference

## Main Functions

```@docs
test_input
Constructor
solve_polynomial_system
process_crit_pts
analyze_critical_points
analyze_critical_points_with_tables
```

## Types and Structures

```@docs
test_input
BFGSConfig
BFGSResult
```

## Polynomial Approximation

```@docs
Constructor
chebyshev_extrema
chebyshev_polys
grid_sample
sample_objective_on_grid
```

## Critical Point Analysis

```@docs
analyze_critical_points
compute_hessians
classify_critical_points
store_all_eigenvalues
extract_critical_eigenvalues
compute_hessian_norms
compute_eigenvalue_stats
```

## BFGS Refinement

```@docs
enhanced_bfgs_refinement
refine_with_enhanced_bfgs
determine_convergence_reason
```

## Statistical Analysis

```@docs
analyze_critical_points_with_tables
create_summary_statistics
create_summary_tables
compute_enhanced_statistics
```

## Utility Functions

```@docs
points_in_hypercube
points_in_range
assign_spatial_regions
cluster_function_values
compute_nearest_neighbors
compute_gradients
analyze_basins
```

## Visualization Functions

The following functions are available when CairoMakie or GLMakie are loaded:

```@docs
plot_hessian_norms
plot_condition_numbers
plot_critical_eigenvalues
plot_all_eigenvalues
plot_raw_vs_refined_eigenvalues
plot_eigenvalue_differences
plot_eigenvalue_movements
```

## Built-in Test Functions

```@docs
Deuflhard
Rastringin
HolderTable
tref_3d
Beale
Rosenbrock
Branin
```

## Export Functions

```@docs
write_tables_to_csv
write_tables_to_latex
write_tables_to_markdown
```