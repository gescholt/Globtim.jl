# V4 Plotting Integration Plan

## ✅ IMPLEMENTATION COMPLETED (2025-01-08)

This plan has been successfully implemented. The V4 implementation now includes all requested plotting functionality.

## Implementation Summary

### What Was Implemented
- ✅ **Standalone V4 Plotting Module** (`src/V4Plotting.jl`)
- ✅ **Enhanced L2 convergence plot** with subdomain traces
- ✅ **Distance convergence plot** with subdomain traces and separate legend
- ✅ **Critical point distance evolution plot** (NEW) - per-point tracking across degrees
- ✅ **Integration with run_v4_analysis.jl** - optional plotting via `plot_results` parameter
- ✅ **Plot from existing tables** functionality (`examples/plot_existing_tables.jl`)

### Key Decisions Made
1. **Chose Option 1**: Standalone V4 Plotting Module
   - Avoids conflicts with Globtim's extension system
   - Uses CairoMakie directly
   - Complete control over plotting behavior

2. **Fixed Issues**:
   - Corrected `hasprop` → `hasproperty` error
   - Handles missing data gracefully
   - Proper subdomain filtering for plots

3. **Enhanced Features**:
   - Added per-critical-point distance evolution (not in original by_degree)
   - Option to plot all points or just averages
   - Subdomain highlighting capability

## Current Usage

### Quick Start
```julia
cd Examples/ForwardDiff_Certification/v4
include("run_v4_analysis.jl")

# Run with plotting
subdomain_tables = run_v4_analysis([3,4], 20, 
                                  output_dir="outputs/my_analysis",
                                  plot_results=true)
```

### Plot from Existing Tables
```julia
include("examples/plot_existing_tables.jl")
plot_from_existing_tables("outputs/my_analysis", degrees=[3,4])
```

## Generated Plots

1. **v4_l2_convergence.png**
   - Global L2 norm (if available) as thick orange line
   - Individual subdomain L2 norms as thin colored lines
   - Log scale showing convergence

2. **v4_distance_convergence.png**
   - Average distance to theoretical points (thick orange)
   - Individual subdomain traces (thin orange)
   - Recovery threshold line (black dotted)
   - Separate legend file for clarity

3. **v4_critical_point_distance_evolution.png**
   - One line per theoretical critical point
   - Blue lines: minima, Red lines: saddle points
   - Shows which specific points are hard to recover

## Testing
- ✅ Tested with degrees [3,4] and GN=10,20,40
- ✅ All plots generate successfully
- ✅ Handles edge cases (missing data, single degree)
- ✅ Works with saved CSV tables

## Future Enhancements (Optional)
1. Add interactive plots using GLMakie
2. Export to other formats (PDF, SVG)
3. Add statistical summary overlays
4. Create animated convergence visualizations

## Conclusion
The plotting integration has been successfully completed following the recommended approach. The v4 implementation now provides comprehensive visualization capabilities while maintaining independence from Globtim's extension system.