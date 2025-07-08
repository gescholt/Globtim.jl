# V4 Plotting Integration Plan

## Overview
This document outlines a careful plan to integrate plotting functionality from the `by_degree` implementation into the v4 architecture without breaking existing Globtim functionality.

## Current Situation

### Existing Infrastructure
1. **Globtim Package Extensions**:
   - Uses Julia's weak dependency system for optional plotting
   - `ext/GlobtimCairoMakieExt.jl` - CairoMakie extension
   - `ext/GlobtimGLMakieExt.jl` - GLMakie extension
   - Core module defines stub functions that extensions implement

2. **by_degree Plotting**:
   - `src/EnhancedVisualization.jl` - Module with subdomain trace plotting
   - `examples/analyze_critical_point_distance_matrix.jl` - Distance evolution plots
   - Direct CairoMakie usage (not using extension pattern)

3. **Desired Plots**:
   - `enhanced_l2_convergence` - L2-norm convergence with subdomain traces
   - `distance_convergence_with_subdomains` - Distance convergence with individual subdomain lines
   - `critical_point_distance_evolution` - Per-critical-point distance evolution

## Integration Strategy

### Option 1: Standalone V4 Plotting Module (RECOMMENDED)
Create a self-contained plotting module within v4 that doesn't interfere with Globtim's extension system.

**Advantages**:
- No risk of breaking existing Globtim functionality
- Complete control over plotting behavior
- Easy to test and modify independently
- Can use either CairoMakie or GLMakie without conflicts

**Implementation**:
```julia
# v4/src/V4Plotting.jl
module V4Plotting

using CairoMakie  # Direct dependency for v4
using DataFrames
using Statistics
using LinearAlgebra

export plot_v4_l2_convergence, plot_v4_distance_convergence, 
       plot_critical_point_distance_evolution

# Plotting functions specific to v4 analysis
end
```

### Option 2: Extend Globtim's Extension System
Add v4-specific plotting functions to Globtim's existing extensions.

**Advantages**:
- Consistent with package architecture
- Automatically handles CairoMakie vs GLMakie choice

**Disadvantages**:
- Risk of conflicts with existing functions
- Requires modifying core Globtim package
- More complex testing and deployment

### Option 3: Hybrid Approach
Create v4 plotting that optionally uses Globtim's plotting when available but provides standalone functionality.

## Recommended Implementation Plan

### Phase 1: Create Standalone V4 Plotting Module
1. Create `v4/src/V4Plotting.jl` with core plotting functions
2. Port the three main plotting functions:
   - `plot_v4_l2_convergence` (from `create_enhanced_l2_plot`)
   - `plot_v4_distance_convergence` (from `plot_distance_with_subdomains`)
   - `plot_critical_point_distance_evolution` (new functionality)
3. Add proper imports and exports

### Phase 2: Integrate with V4 Analysis
1. Update `run_v4_analysis.jl` to include plotting module
2. Add plotting configuration options:
   ```julia
   function run_v4_analysis(degrees, GN; 
                           output_dir=nothing,
                           plot_results=true,
                           plot_backend=:cairo)  # :cairo or :gl
   ```
3. Generate plots after table creation if requested

### Phase 3: Add Critical Point Distance Evolution
1. Implement per-critical-point tracking across degrees
2. Create evolution plot showing all critical points
3. Add subdomain grouping visualization
4. Include in v4 output

## Implementation Details

### 1. Module Structure
```
v4/
├── src/
│   ├── TheoreticalPointTables.jl  (existing)
│   ├── run_analysis_no_plots.jl   (existing)
│   └── V4Plotting.jl              (new)
├── test/
│   └── test_v4_plotting.jl        (new)
└── run_v4_analysis.jl             (update)
```

### 2. Plotting Functions

#### `plot_v4_l2_convergence`
- Shows average L2-norm across subdomains
- Individual subdomain traces as light lines
- Comparison with global domain if available

#### `plot_v4_distance_convergence`
- Average distance to nearest theoretical point
- Individual subdomain traces for subdomains with minimizers
- Recovery threshold line
- Separate legend figure

#### `plot_critical_point_distance_evolution`
- One line per theoretical critical point
- Color by point type (min/saddle)
- Log scale for distances
- Option to filter by subdomain

### 3. Data Flow
```
run_v4_analysis
├── Generate tables (existing)
├── Collect plotting data
│   ├── L2 norms by subdomain
│   ├── Distance matrices
│   └── Critical point assignments
└── Call V4Plotting functions
    ├── plot_v4_l2_convergence
    ├── plot_v4_distance_convergence
    └── plot_critical_point_distance_evolution
```

### 4. Testing Strategy
1. Create test data generators
2. Test each plotting function independently
3. Visual regression tests (save reference plots)
4. Integration tests with full analysis

## Migration Path

### Step 1: Basic Implementation
- Copy and adapt plotting functions from by_degree
- Remove dependencies on by_degree modules
- Test with minimal data

### Step 2: Full Integration
- Wire up to v4 analysis pipeline
- Add all configuration options
- Generate example outputs

### Step 3: Documentation
- Update v4 README with plotting examples
- Add plotting section to documentation
- Create visual guide to interpreting plots

## Potential Issues and Solutions

### Issue 1: Module Loading Conflicts
**Problem**: CairoMakie might conflict with GLMakie if both are loaded
**Solution**: Use only CairoMakie in v4, or implement backend switching

### Issue 2: Large Data Handling
**Problem**: 25 critical points × many degrees = cluttered plots
**Solution**: Add filtering options, alpha blending, subplot layouts

### Issue 3: Consistency with Existing Plots
**Problem**: v4 plots might look different from standard Globtim plots
**Solution**: Extract common styling into shared configuration

## Next Steps

1. **Approval**: Review and approve this plan
2. **Implementation**: Start with Phase 1 basic module creation
3. **Testing**: Create test suite with sample data
4. **Integration**: Connect to v4 analysis pipeline
5. **Documentation**: Update all relevant docs

## Alternative Minimal Approach

If full plotting integration is too complex, consider:
1. Generate only CSV data files
2. Provide separate Julia scripts for plotting
3. User runs plotting scripts manually after analysis
4. No runtime dependencies on Makie packages

This would be simpler but less convenient for users.