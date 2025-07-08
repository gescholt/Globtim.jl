# V4 Implementation: Theoretical Point-Centric Tables with Enhanced Plotting

## Quick Start

Run the enhanced V4 analysis with BFGS refinement:
```bash
julia run_v4_analysis.jl
```

Or with custom parameters:
```bash
julia run_v4_analysis.jl "3,4,5" 30 "outputs/my_run"
```

Arguments:
1. Degrees (comma-separated, default: "3,4")  
2. Grid resolution GN (default: 20)
3. Output directory (default: "outputs/enhanced_HH-MM")

## Overview
V4 restructures subdomain tables to focus on theoretical critical points, with each row representing a theoretical point and columns showing minimal distances to computed points by degree. This implementation now includes comprehensive plotting capabilities integrated from the by_degree analysis.

### NEW: Enhanced V4 with BFGS Refined Point Analysis
The enhanced version adds collection and analysis of BFGS-refined points (df_min_refined) from `analyze_critical_points`, providing:
- Distances from df_min_refined to df_cheb points
- Distances from theoretical minima to df_min_refined (BFGS convergence quality)
- Refinement effectiveness metrics
- Comparative visualizations with color-coded plots

## Implementation Steps

### Step 1: Basic Table Structure ✅
- [x] Create v4 directory
- [x] Create README.md
- [x] Create `src/` directory
- [x] Create `test/` directory

### Step 2: Core Module ✅
- [x] Create `src/TheoreticalPointTables.jl`
- [x] Implement basic table structure function
- [x] Test: Verify table has correct columns and structure

### Step 3: Distance Calculation ✅
- [x] Implement minimal distance calculation function
- [x] Add distance columns to tables
- [x] Test: Verify distances are computed correctly

### Step 4: Summary Row ✅
- [x] Add AVERAGE row calculation
- [x] Test: Verify summary statistics are correct

### Step 5: Integration ✅
- [x] Create `run_v4_analysis.jl`
- [x] Integrate with existing degree analysis
- [x] Create minimal analysis function without plotting dependencies
- [x] Fix module loading order and project activation

## Table Structure

```
| theoretical_point_id | type   | x1 | x2 | x3 | x4 | d3   | d4   | ... |
|---------------------|--------|----|----|----|----|------|------|-----|
| TP_001              | min    | .5 | .5 | .5 | .5 | 0.05 | 0.03 | ... |
| TP_002              | saddle | .7 | .7 | .0 | .0 | 0.10 | 0.08 | ... |
| AVERAGE             | -      | -  | -  | -  | -  | 0.07 | 0.05 | ... |
```

## Key Functions

### `TheoreticalPointTables.jl`
- `create_theoretical_point_table()`: Creates empty table structure
- `calculate_minimal_distance()`: Computes min distance to computed points
- `populate_distances_for_subdomain()`: Fills distance columns
- `add_summary_row()`: Adds AVERAGE row with statistics
- `generate_theoretical_point_tables()`: Main function generating all tables

### `V4Plotting.jl` and `V4PlottingEnhanced.jl`
Standard plots (all without axis labels):
- `plot_v4_l2_convergence()`: L2-norm convergence with subdomain traces
- `plot_v4_distance_convergence()`: Distance convergence with subdomain traces
- `plot_critical_point_distance_evolution()`: Per-critical-point distance evolution

Enhanced plots (new):
- `plot_refinement_comparison()`: Compares theoretical→df_cheb vs df_min_refined→df_cheb (blue vs green)
- `plot_theoretical_minima_to_refined()`: Shows BFGS convergence to theoretical minima (red)
- `plot_refinement_effectiveness()`: Bar charts of point counts and improvement ratios (purple)
- `plot_refined_to_cheb_distances()`: Statistical view of refinement distances (green)

## Quick Start Guide

### Fastest Way to Start
```bash
cd Examples/ForwardDiff_Certification/v4
julia quick_start.jl
```
This interactive script guides you through common analysis options.

### Manual Setup
1. Navigate to the v4 directory:
```bash
cd Examples/ForwardDiff_Certification/v4
```

2. Ensure Julia is activated in the Globtim project:
```julia
using Pkg
Pkg.activate("../../../")  # Activate Globtim root
```

## Usage Examples

### 1. Basic Analysis (Tables Only - No Plotting)
```julia
# From the v4 directory, run:
include("run_v4_analysis.jl")

# Run with default parameters (degrees 3-4, GN=20)
subdomain_tables = run_v4_analysis()

# Or run enhanced version with BFGS refined point analysis
results = run_v4_analysis([3,4], 20, enhanced=true, plot_results=true)

# Or specify custom parameters
subdomain_tables = run_v4_analysis([3,4,5], 30)  # degrees 3-5, GN=30

# View a specific subdomain table
subdomain_tables["0000"]

# View all tables with summary
for (label, table) in sort(collect(subdomain_tables), by=x->x[1])
    println("\n📊 Subdomain $label:")
    show(table, allrows=true, allcols=true)
end
```

### 2. Analysis with Automatic Plotting
```julia
# Standard analysis with plots
subdomain_tables = run_v4_analysis([3,4], 20, 
                                  output_dir="outputs/my_analysis",
                                  plot_results=true)

# Enhanced analysis with refined point plots
results = run_v4_analysis([3,4], 20,
                         output_dir="outputs/enhanced_analysis",
                         plot_results=true,
                         enhanced=true)

# Standard analysis creates:
# outputs/my_analysis/
#   ├── subdomain_0000_v4.csv          # V4 tables for each subdomain
#   ├── subdomain_0010_v4.csv
#   ├── ...
#   ├── v4_l2_convergence.png          # L2-norm convergence plot
#   ├── v4_distance_convergence.png    # Distance convergence plot
#   ├── v4_distance_convergence_legend.png  # Separate legend
#   └── v4_critical_point_distance_evolution.png  # Per-point evolution

# Enhanced analysis additionally creates:
#   ├── refinement_summary.csv         # Refinement effectiveness metrics
#   ├── v4_refinement_comparison.png   # Blue vs green comparison
#   ├── v4_theoretical_minima_to_refined.png  # BFGS convergence quality
#   ├── v4_refinement_effectiveness.png       # Bar charts
#   └── v4_refined_to_cheb_distances.png      # Statistical distances
```

### 3. Plot from Existing Tables
```julia
# If you already have saved V4 tables, generate plots without re-running analysis

# Method 1: Using the example script
julia examples/plot_existing_tables.jl outputs/my_analysis

# Method 2: From Julia REPL
include("examples/plot_existing_tables.jl")
plot_from_existing_tables("outputs/my_analysis", degrees=[3,4])
```

### 4. Custom Analysis Workflow
```julia
# Step 1: Run analysis without plots (faster)
subdomain_tables = run_v4_analysis([3,4,5,6], 40, 
                                  output_dir="outputs/high_degree")

# Step 2: Examine results
println("Summary of results:")
for (label, table) in subdomain_tables
    avg_row = table[end, :]  # AVERAGE row
    println("$label: d3=$(avg_row.d3), d4=$(avg_row.d4)")
end

# Step 3: Generate plots selectively
include("src/V4Plotting.jl")
using .V4Plotting

# Just the distance evolution plot
fig = plot_critical_point_distance_evolution(
    subdomain_tables, [3,4,5,6],
    output_dir = "outputs/high_degree",
    plot_all_points = false  # Only show averages
)
```

## Understanding the Plots

### 1. **v4_l2_convergence.png**
- Shows L2-norm error convergence as polynomial degree increases
- Orange thick line: Global L2 norm (if available)
- Thin colored lines: Individual subdomain L2 norms
- Y-axis is log scale - downward trend indicates convergence

### 2. **v4_distance_convergence.png**
- Shows distance from theoretical to computed critical points
- Orange thick line: Average distance across all points
- Thin orange lines: Individual subdomain traces
- Black dotted line: Recovery threshold (default 0.1)
- Points below threshold are considered "recovered"

### 3. **v4_critical_point_distance_evolution.png**
- Shows evolution of distance for each individual theoretical point
- Blue lines: Minima
- Red lines: Saddle points
- Each line represents one theoretical critical point
- Useful for identifying which specific points are hard to recover

### Enhanced Plots (when enhanced=true):

### 4. **v4_refinement_comparison.png**
- Blue line: Average distance from theoretical points to df_cheb
- Green line: Average distance from df_min_refined to df_cheb
- Shows how BFGS refinement changes the landscape
- Lower green line indicates successful refinement

### 5. **v4_theoretical_minima_to_refined.png**
- Red lines: Distances from theoretical minima to BFGS-refined points
- Light red traces: Individual subdomain performance
- Dark red: Overall average
- Shows BFGS convergence quality to true minima

### 6. **v4_refinement_effectiveness.png**
- Left panel: Bar chart comparing |df_cheb| vs |df_min_refined|
- Right panel: Improvement ratios with percentage labels
- Purple bars show distance reduction effectiveness

## Tests

Run individual tests:
```bash
# From the v4 directory
julia test/test_table_structure.jl
julia test/test_distance_calculation.jl
julia test/test_summary_row.jl
julia test/test_v4_plotting.jl
```

Run all tests:
```bash
julia test/run_all_tests.jl
```

## Progress Log

### 2025-01-08
- Created v4 directory structure
- Implemented complete table generation pipeline
- Added comprehensive test suite
- Integrated with existing degree analysis
- Tables show clear distance convergence per theoretical point
- Fixed module loading issues (UndefVarError for Common4DDeuflhard)
- Removed plotting dependencies to focus on table generation
- Created minimal analysis function (`run_analysis_no_plots.jl`) without CairoMakie
- Fixed project activation path to correctly point to Globtim root
- Fixed Constructor GN parameter issue (moved to test_input)
- Successfully generated tables showing distance improvement from d3 to d4
- Tables now properly show theoretical points as rows with degree columns
- **Added standalone V4 plotting module** (`V4Plotting.jl`)
- **Integrated three key plots from by_degree**:
  - L2-norm convergence with subdomain traces
  - Distance convergence with subdomain traces  
  - Critical point distance evolution (NEW)
- **Created examples for plotting from existing tables**
- **Plotting is optional** - controlled by `plot_results` parameter
- **Added enhanced mode** with BFGS refined point analysis
- **Removed axis labels** from all plots for cleaner appearance
- **Color-coded plots**: Blue (theoretical→df_cheb), Green (refined distances), Red (minima convergence)

## Troubleshooting

### Common Issues

1. **"UndefVarError: `hasprop` not defined"**
   - **Fixed in latest version** - was a typo, should be `hasproperty`
   - If you see this, pull the latest code: `git pull`

2. **Module Loading Errors**
   - Ensure you're in the correct directory: `cd Examples/ForwardDiff_Certification/v4`
   - Activate Globtim project: `Pkg.activate("../../../")`
   - The modules load in a specific order (handled automatically by run_v4_analysis.jl)

3. **Plotting Backend Issues**
   - V4 uses CairoMakie directly (not through Globtim extensions)
   - If plots don't appear, ensure CairoMakie is installed: `] add CairoMakie`

4. **Memory Issues with High Degrees**
   - Use smaller GN values for testing: `run_v4_analysis([3,4], 10)`
   - Process fewer degrees at once
   - Run without plotting first, then plot from saved tables

### Performance Tips

1. **For Quick Testing**:
   ```julia
   # Small grid, few degrees
   run_v4_analysis([3,4], 10)
   ```

2. **For Production Runs**:
   ```julia
   # Higher accuracy, save results
   run_v4_analysis([3,4,5,6], 40, 
                   output_dir="outputs/production",
                   plot_results=false)
   
   # Plot later from saved tables
   include("examples/plot_existing_tables.jl")
   plot_from_existing_tables("outputs/production", degrees=[3,4,5,6])
   ```

3. **For Debugging**:
   - Run table generation without plots first
   - Check individual subdomain tables
   - Use `plot_all_points=false` for cleaner evolution plots
## Note on Script Organization

Previous versions of run scripts have been archived in `archived_scripts/` directory. The main run file is now `run_v4_analysis.jl` which includes all enhanced features with BFGS refinement.
