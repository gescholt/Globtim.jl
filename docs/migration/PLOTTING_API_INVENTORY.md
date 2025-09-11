# Globtim Plotting API Inventory

## Overview
Complete inventory of all plotting functions and their dependencies to support migration to GlobtimPlots.jl.

## Core Plotting Functions by Backend

### CairoMakie Functions (Static Plots)
| Function | Location | Purpose | Key Data Dependencies |
|----------|----------|---------|----------------------|
| `cairo_plot_polyapprox_levelset` | `src/graphs_cairo.jl:243` | Main level set visualization | `ApproxPoly`, `test_input`, `DataFrame` |
| `plot_convergence_analysis` | `src/graphs_cairo.jl:184` | Convergence analysis plots | Analysis results, distance data |
| `plot_discrete_l2` | `src/graphs_cairo.jl:88` | L2 norm visualization | Degree-to-norm mapping |
| `plot_filtered_y_distances` | `src/graphs_cairo.jl:386` | Distance analysis | Critical point distances |
| `plot_distance_statistics` | `src/graphs_cairo.jl:497` | Statistical distance plots | Distance distribution data |
| `plot_convergence_captured` | `src/graphs_cairo.jl:542` | Captured point analysis | Point capture statistics |
| `plot_hessian_norms` | `ext/GlobtimCairoMakieExt.jl:11` | Hessian visualization | Hessian analysis DataFrame |
| `plot_condition_numbers` | `ext/GlobtimCairoMakieExt.jl:40` | Condition number plots | Condition number data |
| `plot_critical_eigenvalues` | `ext/GlobtimCairoMakieExt.jl:82` | Eigenvalue analysis | Eigenvalue DataFrame |
| `plot_all_eigenvalues` | `ext/GlobtimCairoMakieExt.jl:150` | Complete eigenvalue spectrum | Full eigenvalue data |
| `plot_raw_vs_refined_eigenvalues` | `ext/GlobtimCairoMakieExt.jl:335` | Refinement comparison | Raw vs refined datasets |

### GLMakie Functions (Interactive/3D Plots)  
| Function | Location | Purpose | Key Data Dependencies |
|----------|----------|---------|----------------------|
| `plot_polyapprox_3d` | `src/graphs_makie.jl:21` | 3D surface visualization | `ApproxPoly` grid/values |
| `plot_polyapprox_levelset` | `src/LevelSetViz.jl:439` | Interactive level sets | Level set computation |
| `plot_polyapprox_rotate` | `src/LevelSetViz.jl:567` | Rotation animations | 3D surface data |
| `plot_polyapprox_animate` | `src/LevelSetViz.jl:686` | Animation sequences | Time-series data |
| `plot_polyapprox_flyover` | `src/LevelSetViz.jl:774` | Flyover animations | Camera path data |
| `plot_polyapprox_animate2` | `src/LevelSetViz.jl:917` | Advanced animations | Complex animation data |
| `plot_level_set` | `src/LevelSetViz.jl:67` | Core level set plotting | `LevelSetData` |
| `plot_polyapprox_levelset_2D` | `src/LevelSetViz.jl:203` | 2D level set variant | 2D polynomial data |
| `plot_error_function_1D_with_critical_points` | `ext/GlobtimGLMakieExt.jl:19` | 1D error visualization | Error function data |
| `plot_error_function_2D_with_critical_points` | `ext/GlobtimGLMakieExt.jl:177` | 2D error visualization | 2D error surface data |

### Specialized Visualization Components
| Component | Location | Purpose | Dependencies |
|-----------|----------|---------|-------------|
| Interactive Algorithm Tracking | `src/InteractiveVizCore.jl` | Real-time algorithm visualization | Algorithm state data |
| Level Set Computation | `src/LevelSetViz.jl` | Mathematical level set detection | Polynomial evaluation |
| Convergence Analysis | `src/graphs_cairo.jl` | Statistical convergence analysis | Distance/convergence metrics |
| Eigenvalue Visualization | Extensions | Eigenvalue spectrum analysis | Hessian eigenvalue data |

## Key Data Structures Used by Plotting

### Core Types
- `ApproxPoly{T,S}` - Polynomial approximation data
- `test_input` - Problem domain configuration  
- `DataFrame` - Critical points and analysis results
- `LevelSetData{T}` - Level set visualization data
- `VisualizationParameters{T}` - Plot configuration

### Data Flow Patterns
```
ApproxPoly + test_input → Grid Transformation → Plotting Functions
DataFrame (critical points) → Statistical Analysis → Visualization
Hessian Analysis → Eigenvalue Extraction → Specialized Plots
```

## Migration Complexity Assessment

### Low Complexity (Easy to Extract)
- Statistical plotting functions (histograms, scatter plots)
- Basic 2D level set plots
- Convergence analysis plots

### Medium Complexity (Moderate Dependencies)
- 3D surface visualization  
- Interactive level sets
- Eigenvalue analysis plots

### High Complexity (Tight Coupling)
- Animation systems (complex data flows)
- Interactive algorithm tracking
- Real-time convergence monitoring
- Level set computation (mathematical coupling)

## Dependencies Analysis

### External Plotting Dependencies
- CairoMakie.jl - Static high-quality plots
- GLMakie.jl - Interactive and 3D plots  
- DataFrames.jl - Data manipulation
- LinearAlgebra.jl - Mathematical operations
- Statistics.jl - Statistical analysis

### Internal Globtim Dependencies
- Coordinate transformation utilities (`scaling_utils.jl`)
- Polynomial evaluation systems
- Grid generation and management
- Mathematical analysis functions

## Recommended Migration Order

1. **Phase 1**: Statistical and basic 2D plots (low complexity)
2. **Phase 2**: 3D visualization and standard interactive plots  
3. **Phase 3**: Complex animations and real-time systems
4. **Phase 4**: Tightly coupled mathematical visualizations

## Notes for Migration
- Level set computation may need to be extracted as separate mathematical utility
- Animation systems require careful state management extraction
- Interactive features need real-time data update abstractions
- Coordinate transformations should be part of data adapter layer

---
*Generated for GlobtimPlots.jl migration planning*
*Last Updated: September 2025*