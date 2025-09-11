# GlobtimPlots Migration Quick Reference

## Essential Commands

```bash
# List all plotting functions
julia scripts/migration/extract_plotting_functions.jl --list

# Analyze specific function
julia scripts/migration/extract_plotting_functions.jl cairo_plot_polyapprox_levelset

# Check dependencies
julia scripts/migration/analyze_plotting_dependencies.jl
```

## File Locations Quick Map

| Component | Current Location | Lines | Priority |
|-----------|------------------|-------|----------|
| **CairoMakie Functions** | `src/graphs_cairo.jl` | 580 | HIGH |
| **GLMakie Functions** | `src/graphs_makie.jl` | 1000+ | HIGH |
| **Level Set Viz** | `src/LevelSetViz.jl` | 900+ | MEDIUM |
| **Interactive Core** | `src/InteractiveVizCore.jl` | 400+ | MEDIUM |
| **CairoMakie Extension** | `ext/GlobtimCairoMakieExt.jl` | 580 | HIGH |
| **GLMakie Extension** | `ext/GlobtimGLMakieExt.jl` | 1155 | HIGH |

## Data Type Quick Reference

### ApproxPoly → AbstractPolynomialData
```julia
# OLD (in Globtim)
pol.coeffs          → get_coefficients(poly_data)
pol.degree          → get_degree(poly_data)
pol.grid            → get_grid_points(poly_data)  
pol.z               → get_function_values(poly_data)
pol.basis           → get_basis_type(poly_data)
pol.scale_factor    → get_scale_factor(poly_data)
```

### test_input → AbstractProblemData
```julia
# OLD (in Globtim)
TR.dim              → get_dimension(problem_data)
TR.center           → get_center_point(problem_data)
TR.sample_range     → get_sample_range(problem_data)
TR.objective        → get_objective_function(problem_data)
```

### DataFrame → AbstractCriticalPointData
```julia
# OLD (in Globtim) 
df.x1, df.x2, ...  → get_coordinates(crit_data)
df.z                → get_function_values(crit_data)
df.critical_point_type → get_point_types(crit_data)
```

## Migration Strategy Overview

### ✅ Phase 1: Simple Functions (Start Here)
- `plot_discrete_l2`
- `analyze_convergence_distances` 
- `plot_distance_statistics`
- Basic histogram functions

### 🔄 Phase 2: Standard Plots  
- `cairo_plot_polyapprox_levelset`
- `plot_polyapprox_3d`
- `plot_convergence_analysis`
- Basic level set functions

### ⚠️ Phase 3: Advanced Features
- Interactive visualization systems
- Advanced level set functions  
- Eigenvalue analysis plots
- Real-time tracking systems

### 🚨 Phase 4: Complex Systems
- Animation functions
- Error visualization systems
- Complex interactive features
- Multi-algorithm comparisons

## Common Patterns to Update

### Function Signatures
```julia
# OLD
function plot_something(pol::ApproxPoly, TR::test_input, df::DataFrame)

# NEW  
function plot_something(
    poly_data::AbstractPolynomialData, 
    problem_data::AbstractProblemData,
    crit_data::AbstractCriticalPointData
)
```

### Data Access Patterns
```julia
# OLD
coords = [pol.grid[:, 1], pol.grid[:, 2]]
values = pol.z

# NEW
grid = get_grid_points(poly_data)
coords = [grid[:, 1], grid[:, 2]]
values = get_function_values(poly_data)
```

### Coordinate Transformations
```julia
# OLD (coupled to Globtim)
coords = transform_coordinates(pol.scale_factor, pol.grid, TR.center)

# NEW (abstract interface)
scale = get_scale_factor(poly_data)
grid = get_grid_points(poly_data)  
center = get_center_point(problem_data)
coords = transform_coordinates(scale, grid, center)  # Extract this function
```

## Testing Workflow

1. **Extract Function**: Copy from Globtim to GlobtimPlots
2. **Update Signature**: Use abstract interfaces
3. **Update Implementation**: Replace Globtim types with interface calls
4. **Test with Sample Data**: Use generic test data
5. **Validate Output**: Compare with original function
6. **Document Changes**: Note any breaking changes

## Key Dependencies to Extract

### Mathematical Utilities
- Coordinate transformation functions
- Level set computation algorithms  
- Statistical analysis functions
- Grid generation utilities

### Plotting Utilities  
- Color scheme definitions
- Style configuration systems
- Layout management functions
- Animation utilities

## Checklist for Each Function

- [ ] Function copied to GlobtimPlots
- [ ] Signature updated to abstract interfaces  
- [ ] Implementation uses interface methods
- [ ] Tests pass with sample data
- [ ] Visual output matches original
- [ ] Performance acceptable
- [ ] Documentation updated
- [ ] No Globtim dependencies remain

## Migration Safety Rules

1. **Never modify Globtim during migration**
2. **Test each function independently**  
3. **Keep original functions as reference**
4. **Use abstract interfaces consistently**
5. **Validate mathematical accuracy**
6. **Document all breaking changes**

---

*Keep this reference handy during manual migration process*