# LevelSetViz Migration Guide

## Summary

`LevelSetViz.jl` has been **removed** from `globtimcore/src/` to eliminate the `GLMakie` dependency from the core package. This file had `using GLMakie` on line 1, which forced Makie compilation on the HPC cluster.

## Rationale

The whole purpose of separating `globtimcore` and `globtimplots` is to keep plotting packages out of the core computational package. Having `GLMakie` as a hard dependency in `src/LevelSetViz.jl` defeated this purpose.

## Status

- ✅ **Removed** `CairoMakie` from `[deps]` in `Project.toml` (moved to `[weakdeps]`)
- ✅ **Archived** `src/LevelSetViz.jl` to `docs/archive/obsolete_files_2025_09_22/`
- ⚠️ **Migration to GlobtimPlots** is incomplete (functions depend on internal Globtim types)

## Affected Files

### Examples/Scripts
- `Examples/systems/example.jl` - Uses `create_level_set_visualization`

### Notebooks (16 total)
- `Examples/Notebooks/Ratstrigin_3.ipynb` - Uses `create_level_set_visualization`, includes LevelSetViz.jl
- `Examples/Notebooks/Ratstrigin_3_msolve.ipynb` - Uses `create_level_set_visualization`
- `Examples/Notebooks/Trefethen_3D.ipynb` - Uses `create_level_set_visualization` (already broken)
- `Examples/Notebooks/Shubert_4d_msolve.ipynb` - Uses `plot_polyapprox_levelset`, `plot_polyapprox_rotate`
- `Examples/Notebooks/Trefethen_msolve.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/HolderTable.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/DeJong_msolve.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/Deuflhard_msolve.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/Camel_2d.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/pos_dim_min.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/Deuflhard.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/DeJong.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/CrossInTray.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/Triple_Graph_dejong.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/Triple_Graph_holder.ipynb` - Uses `cairo_plot_polyapprox_levelset`
- `Examples/Notebooks/Triple_Graph_Gaussians.ipynb` - Uses `cairo_plot_polyapprox_levelset`

## Functions Removed

### 3D Level Set Functions (GLMakie-dependent)
- `prepare_level_set_data()` - Prepares level set data from grid
- `to_makie_format()` - Converts to Makie-compatible format
- `plot_level_set()` - 3D scatter plot of level sets
- `create_level_set_visualization()` - Interactive 3D level set viewer with slider
- `create_level_set_animation()` - Animated level set visualization

### 2D Polynomial Visualization Functions (GLMakie-dependent)
- `plot_polyapprox_levelset_2D()` - 2D level set contour plots
- `plot_polyapprox_levelset()` - 2D contour plots with critical points
- `plot_polyapprox_rotate()` - 3D rotating surface plots
- `plot_polyapprox_animate()` - Simple rotation animation
- `plot_polyapprox_flyover()` - Camera flyover animation
- `plot_polyapprox_animate2()` - Advanced rotation animation

## Temporary Workaround (Until Full Migration)

**Status**: File has been fully removed - no workaround available currently.

**Options**:
1. Wait for proper migration to GlobtimPlots (recommended)
2. Retrieve from git history if absolutely needed: `git show <commit>:src/LevelSetViz.jl`
3. Use alternative visualization approaches with existing GlobtimPlots functions

## Long-term Solution

These functions need to be properly migrated to `GlobtimPlots.jl` with:

1. **Type adapters** to work with generic polynomial/problem data
2. **Proper module structure** that doesn't depend on Globtim internals
3. **Updated notebooks** that use `GlobtimPlots` instead of direct function calls

### Current Blocker

The functions use internal Globtim types:
- `ApproxPoly` (polynomial approximation type)
- `test_input` (problem input type)
- Other internal data structures

**GlobtimPlots** would need either:
- Type adapters that convert Globtim types to generic interfaces
- Re-implementation that works with standard DataFrames/Arrays
- Extension system that loads when Globtim is available

## Verification

After this change:

```julia
# In a fresh Julia session
using Pkg
Pkg.activate("globtimcore")
Pkg.instantiate()

# This should NOT pull in Makie
using Globtim

# Verify no Makie in loaded modules
@assert !any(occursin("Makie", string(m)) for m in keys(Base.loaded_modules))
```

## Related Issues

- Original separation: `globtimcore` (computation) vs `globtimplots` (visualization)
- Migration checklist: `docs/migration/MIGRATION_CHECKLIST.md`
- Plotting inventory: `docs/migration/PLOTTING_API_INVENTORY.md`

## Date

Migration performed: 2025-10-01
