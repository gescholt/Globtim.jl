# Plotting Infrastructure Usage Guide

## ⚠️ CRITICAL DATA ISSUE (Sept 29, 2025)

**Issue #96**: Discovered critical inconsistency in computation time data:
- **Degree 4**: ~1.6 seconds (higher degree taking MORE time - unexpected)
- **Degree 5**: ~0.5 seconds (lower degree taking LESS time - unexpected)
- **Missing**: L2 approximation error (the most important metric for polynomial convergence)

**Current plots show `computation_time` not L2 error** - see Issue #96 for full analysis.

## 🎯 Current Status

Two plotting scripts are available (both currently showing computation_time data):

### ✅ RECOMMENDED: `test_proper_display.jl`
- **Interactive bar plots only** - no PNG files generated
- **Integer x-axis ticks** - proper bar chart for discrete degree values (4, 5, 6...)
- **Comprehensive analysis** - detailed statistics and optimization insights
- **Direct CairoMakie usage** - no intermediate plotting libraries
- **Bar plots for degrees** - appropriate visualization for integer polynomial degrees

```bash
julia --project=. test_proper_display.jl
```

### ⚠️ LEGACY: `test_graphical_plots.jl`
- Uses `@globtimplots` package via `GlobtimPlots.create_comparison_plots()`
- **⚠️ GENERATES PNG FILES** in `analysis_output/` directory:
  - `degree_comparison.png`
  - `experiment_overview.png`
- **Bar plots for degrees** - updated to use appropriate bar visualization for integer degrees
- More complex dependency chain with @globtimplots integration

## 🔧 PNG Generation Issue

The `"[ Info: GlobtimPlots.jl loaded. Extensions will be available when backend packages are loaded."` message indicates:

1. **GlobtimPlots.jl** loaded successfully
2. **Extensions** (CairoMakie integration) need backend packages
3. **create_comparison_plots()** function saves PNG files by design:
   ```julia
   # From comparison_plots.jl:368-370
   plot_file = joinpath(output_dir, "degree_comparison.png")
   CairoMakie.save(plot_file, fig, px_per_unit=2)
   println("   ✅ Created: degree_comparison.png")
   ```

## 🚀 Solution

**Use `test_proper_display.jl`** for pure interactive display:
- No PNG file generation
- Integer-only x-axis ticks
- Comprehensive statistical analysis
- Direct Cairo figure display

## 🎯 Key Improvements in Both Scripts

1. **Bar Plot Visualization**: Both scripts now use `barplot!()` instead of `lines!()` for integer degree data
2. **Integer X-axis**: Proper integer ticks for discrete polynomial degrees (4, 5, 6...)
3. **Grouped Bar Charts**: Multiple experiments displayed as grouped bars for easy comparison
4. **test_proper_display.jl Features**:
   - **No PNG files**: Only `display(fig)` for interactive viewing
   - Rich analytics with comprehensive statistics
   - Bar chart visualization appropriate for integer degrees
5. **test_graphical_plots.jl Features**:
   - ⚠️ **Creates PNG files** via @globtimplots package
   - Bar chart visualization for degree comparison
   - Full @globtimplots integration testing

**Bottom line**: Run `julia --project=. test_proper_display.jl` for clean interactive bar plots with no PNG generation.