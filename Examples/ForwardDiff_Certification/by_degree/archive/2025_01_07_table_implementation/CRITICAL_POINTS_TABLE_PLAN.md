# Critical Points Table Implementation Plan

## Table Structure

For each subdomain containing critical points, create a table with:
- **Rows**: One per theoretical critical point in that subdomain
- **Columns**:
  - `point_id`: Unique identifier for the critical point
  - `type`: "min" or "saddle"
  - `coordinates`: x1, x2, x3, x4 values
  - `degree_N`: Distance to closest computed point for degree N (NaN if none found)

Example for Subdomain "0000":
```
| point_id | type   | x1    | x2    | x3    | x4    | degree_2 | degree_3 | degree_4 | ... | degree_10 |
|----------|--------|-------|-------|-------|-------|----------|----------|----------|-----|-----------|
| CP_001   | min    | 0.123 | 0.456 | 0.789 | 0.012 | 0.045    | 0.023    | 0.012    | ... | 0.001     |
| CP_002   | saddle | 0.234 | 0.567 | 0.890 | 0.123 | NaN      | 0.156    | 0.089    | ... | 0.045     |
```

## Implementation Steps

### Step 1: Create Table Generation Function
```julia
function generate_subdomain_critical_point_tables(
    theoretical_points::Vector{Vector{Float64}},
    theoretical_types::Vector{String},
    all_critical_points_with_labels::Dict{Int, DataFrame},
    degrees::Vector{Int},
    subdomains::Vector{Subdomain}
) -> Dict{String, DataFrame}
```

### Step 2: Data Processing Logic
1. Assign theoretical points to subdomains
2. For each subdomain with critical points:
   - Create DataFrame with theoretical point info
   - For each degree:
     - Find computed points in this subdomain
     - Calculate distances to each theoretical point
     - Store minimum distance (or NaN)

### Step 3: Export Functions
- CSV export for each subdomain table
- LaTeX table generation for paper inclusion
- Summary statistics table

### Step 4: Integration Points
1. Call after `run_enhanced_analysis_v2` in `run_all_examples.jl`
2. Save tables to `outputs/critical_point_tables/`
3. Use table data for `subdomain_distance_evolution` plot

### Step 5: Updated Plot Function
Modify `plot_subdomain_distance_evolution` to:
1. Read from generated tables instead of computing on-the-fly
2. Handle NaN values appropriately
3. Show all subdomains with theoretical points (even if all NaN)

## Benefits
1. **Transparency**: Clear view of which points are recovered
2. **Debugging**: Easy to identify problematic subdomains/degrees
3. **Publication**: Tables can be included in paper
4. **Performance**: Pre-computed distances for plotting