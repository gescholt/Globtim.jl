# Global Domain Integration Plan for V4 Analysis

## Overview
This document outlines the plan to integrate global domain analysis (without subdivision) into the existing V4 framework that currently only analyzes 16 subdomains.

## Motivation
As noted in A_PLAN.md, we currently subdivide the domain `([0,1]×[-1,0])²` into 16 subdomains to manage computational complexity. However, comparing with global domain results would provide valuable insights into:
- The effect of subdivision on convergence
- Overall L2-norm behavior vs averaged subdomain norms
- Global critical point recovery vs subdomain-based recovery

## Current Infrastructure

### Existing Support
1. **`run_analysis_with_refinement`** already has an `analyze_global` parameter (currently unused)
2. **`plot_v4_l2_convergence`** accepts `global_l2_by_degree` data
3. **Reference implementation** exists in `archived/legacy_examples/deuflhard_4d_full_domain.jl`

### Key Functions to Modify
1. `run_v4_enhanced()` in `run_v4_analysis_function.jl`
2. `run_enhanced_analysis_with_refinement()` in `src/run_analysis_with_refinement.jl`
3. V4 plotting functions to display global data

## Proposed Implementation

### Phase 1: Core Analysis Modification

#### 1.1 Update `run_enhanced_analysis_with_refinement`
```julia
function run_enhanced_analysis_with_refinement(
    degrees::Vector{Int}, 
    GN::Int;
    analyze_global::Bool = false,  # Already exists but unused
    threshold::Float64 = 0.1,
    tol_dist::Float64 = 0.05
)
    # ... existing subdomain code ...
    
    # NEW: Global domain analysis
    global_results = nothing
    if analyze_global
        println("\n📊 Analyzing global domain...")
        global_results = analyze_global_domain(degrees, GN, threshold, tol_dist)
    end
    
    # Return both results
    return (
        subdomain_results = existing_results,
        global_results = global_results
    )
end
```

#### 1.2 Create `analyze_global_domain` function
```julia
function analyze_global_domain(degrees, GN, threshold, tol_dist)
    # Define global domain: ([0,1]×[-1,0])²
    dim = 4
    center = [0.5, -0.5, 0.5, -0.5]
    sample_range = 0.5
    
    # Initialize storage
    l2_by_degree = Dict{Int, Float64}()
    critical_points_by_degree = Dict{Int, DataFrame}()
    min_refined_by_degree = Dict{Int, DataFrame}()
    
    for degree in degrees
        # Run Globtim analysis
        TR = test_input(deuflhard_4d_composite, dim=dim, 
                       center=center, sample_range=sample_range,
                       tolerance=0.001)
        pol = Constructor(TR, degree, GN=GN)
        
        # Get critical points
        # ... (similar to subdomain analysis)
        
        # Store results
        l2_by_degree[degree] = pol.L2_norm
        critical_points_by_degree[degree] = df_all
        min_refined_by_degree[degree] = df_min_refined
    end
    
    return (
        l2_data = l2_by_degree,
        critical_points = critical_points_by_degree,
        min_refined_points = min_refined_by_degree
    )
end
```

### Phase 2: Update Plotting Functions

#### 2.1 Extend existing plots to show global data
- `plot_v4_l2_convergence`: Already supports global_l2_by_degree ✓
- `plot_v4_distance_convergence`: Add global_distance parameter
- `plot_critical_point_distance_evolution`: Add global_tables parameter

#### 2.2 Create comparison visualizations
- Side-by-side subdomain vs global convergence
- Overlay plots with different line styles
- Recovery rate comparison tables

### Phase 3: Update Main Function

#### 3.1 Modify `run_v4_enhanced`
```julia
function run_v4_enhanced(; 
    degrees=[3,4], 
    GN=20, 
    output_dir=nothing,
    include_global=false  # NEW parameter
)
    # ... existing setup ...
    
    # Run analysis with global option
    analysis_results = run_enhanced_analysis_with_refinement(
        degrees, GN,
        analyze_global=include_global,  # Pass through
        threshold=0.1,
        tol_dist=0.05
    )
    
    # Handle both subdomain and global results
    if include_global && analysis_results.global_results !== nothing
        # Process global results
        # Generate combined plots
        # Save global tables
    end
    
    # ... rest of existing code ...
end
```

### Phase 4: Output Structure

#### 4.1 Enhanced directory structure
```
outputs/enhanced_HH-MM/
├── subdomain/              # Existing subdomain results
│   ├── subdomain_0000_v4.csv
│   └── ...
├── global/                 # New global results
│   ├── global_critical_points_d3.csv
│   ├── global_critical_points_d4.csv
│   └── global_refinement_summary.csv
├── comparison/             # Comparison visualizations
│   ├── v4_subdomain_vs_global_l2.png
│   ├── v4_subdomain_vs_global_distances.png
│   └── recovery_comparison_table.csv
└── plots/                  # All plots
    ├── v4_l2_convergence_combined.png
    └── ...
```

## Implementation Steps

1. **Step 1**: Implement `analyze_global_domain` function
2. **Step 2**: Update `run_enhanced_analysis_with_refinement` to call it
3. **Step 3**: Modify data structures to handle global results
4. **Step 4**: Update plotting functions to visualize both datasets
5. **Step 5**: Test with small degree range (e.g., [3,4])
6. **Step 6**: Document usage and add examples

## Usage Examples

```julia
# Standard subdomain-only analysis (current behavior)
results = run_v4_enhanced()

# New: Include global domain analysis
results = run_v4_enhanced(include_global=true)

# High-degree analysis with global comparison
results = run_v4_enhanced(
    degrees=[3,4,5,6],
    GN=30,
    include_global=true,
    output_dir="outputs/global_comparison"
)
```

## Expected Benefits

1. **Validation**: Compare subdomain aggregation vs true global behavior
2. **Insights**: Understand impact of domain subdivision
3. **Completeness**: Full picture of convergence characteristics
4. **Research**: Better understanding of the 4D Deuflhard problem

## Potential Challenges

1. **Computational Cost**: Global domain requires higher polynomial degrees
2. **Memory Usage**: Storing both subdomain and global data
3. **Visualization Complexity**: Displaying multiple datasets clearly
4. **Numerical Stability**: Higher degrees on larger domains

## Alternative Approach: Separate Script

If integration proves too complex, create a standalone `run_v4_global_analysis.jl` that:
1. Runs only global domain analysis
2. Saves results in compatible format
3. Can be called before/after subdomain analysis
4. Results can be manually combined for plotting

## Decision: Integrated Approach

The integrated approach is recommended because:
- Reuses existing infrastructure
- Ensures consistent parameters and methods
- Enables direct comparison in plots
- Maintains backward compatibility
- Single entry point for users