# V4 Implementation: Theoretical Point-Centric Tables

## Overview
V4 restructures subdomain tables to focus on theoretical critical points, with each row representing a theoretical point and columns showing minimal distances to computed points by degree.

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

### `V4Plotting.jl` (NEW)
- `plot_v4_l2_convergence()`: L2-norm convergence with subdomain traces
- `plot_v4_distance_convergence()`: Distance convergence with subdomain traces
- `plot_critical_point_distance_evolution()`: Per-critical-point distance evolution
- `create_v4_plots()`: Convenience function to create all plots at once

## Usage

### Basic Analysis (Tables Only)
```julia
# Load and run the v4 analysis
include("Examples/ForwardDiff_Certification/v4/run_v4_analysis.jl")
subdomain_tables = run_v4_analysis([3,4], 20)

# View a specific subdomain table
subdomain_tables["0000"]

# View all tables
for (label, table) in sort(collect(subdomain_tables), by=x->x[1])
    println("\n📊 Subdomain $label:")
    show(table, allrows=true, allcols=true)
end

# Save tables to CSV files
subdomain_tables = run_v4_analysis([3,4], 20, output_dir="v4_output")
```

### Analysis with Plotting
```julia
# Run analysis with plotting enabled
subdomain_tables = run_v4_analysis([3,4], 20, 
                                  output_dir="v4_output",
                                  plot_results=true)

# This generates:
# - v4_l2_convergence.png - L2-norm convergence with subdomain traces
# - v4_distance_convergence.png - Distance convergence with subdomain traces
# - v4_distance_convergence_legend.png - Separate legend
# - v4_critical_point_distance_evolution.png - Evolution for all critical points
```

### Plot from Existing Tables
```julia
# If you already have V4 tables saved, you can plot them directly
include("Examples/ForwardDiff_Certification/v4/examples/plot_existing_tables.jl")
plot_from_existing_tables("path/to/v4_output", degrees=[3,4])
```

## Tests

Run individual tests:
```bash
cd v4
julia test/test_table_structure.jl
julia test/test_distance_calculation.jl
julia test/test_summary_row.jl
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

## Known Issues and Solutions

### Module Loading Order
The modules must be loaded in this specific order:
1. `Common4DDeuflhard.jl` (required by TheoreticalPoints)
2. `SubdomainManagement.jl` 
3. `TheoreticalPoints.jl`

### Plotting Dependencies
To avoid plotting-related errors, the v4 implementation uses a minimal analysis function that excludes CairoMakie and other plotting libraries. This allows focus on table generation without dealing with plotting extension issues.
