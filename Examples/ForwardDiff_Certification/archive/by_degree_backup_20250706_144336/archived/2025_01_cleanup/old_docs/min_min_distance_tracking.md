# Min+Min Distance Tracking Implementation

## Overview
This document describes the implementation of min+min distance tracking functionality in the by-degree analysis framework. The feature tracks distances from theoretical min+min critical points to their closest computed counterparts.

## Changes Made

### 1. Modified `DegreeAnalysisResult` Structure
**File**: `shared/AnalysisUtilities.jl`

Added new field:
- `min_min_distances::Vector{Float64}`: Stores distances from each min+min theoretical point to its closest computed point

### 2. Updated `compute_recovery_metrics` Function
**File**: `shared/AnalysisUtilities.jl`

- Now extracts min+min distances based on theoretical_types filtering
- Returns `min_min_distances` in the result NamedTuple
- Handles cases where no min+min points exist in a subdomain

### 3. New Plotting Functions
**File**: `shared/PlottingUtilities.jl`

#### `plot_min_min_distances`
- Shows distance from min+min points to closest critical point by degree
- Plots individual distances as scatter points
- Overlays average distance as a bold line
- Includes tolerance reference line at 1e-4

#### `plot_subdivision_min_min_distances`
- Handles 16 subdivision curves with transparency
- Shows overall average across all subdomains as a bold red line
- Automatically skips subdomains with no min+min points
- Displays count of subdomains containing min+min points

## Usage Example

```julia
# Single subdomain analysis
results = [analyze_single_degree(f, deg, center, range, theoretical_points, theoretical_types) 
           for deg in degrees]
fig = plot_min_min_distances(results, title="Min+Min Distances")

# Subdivision analysis
all_results = Dict{String, Vector{DegreeAnalysisResult}}()
for subdomain in subdivisions
    # ... analyze each subdomain
end
fig = plot_subdivision_min_min_distances(all_results)
```

## Key Features

1. **Automatic Filtering**: Only processes points classified as "min+min" in theoretical_types
2. **Robust Handling**: Skips subdomains without min+min points
3. **Visual Clarity**: Uses transparency for individual curves, bold line for average
4. **Log Scale**: Y-axis uses log scale to show convergence behavior clearly

## Testing

A test script is provided at `test_min_min_distances.jl` that demonstrates:
- Basic functionality with a single subdomain
- Subdivision plotting with multiple subdomains
- Handling of subdomains without min+min points

## Backward Compatibility

Existing code that creates `DegreeAnalysisResult` objects must be updated to include the new `min_min_distances` field. Use `Float64[]` for empty distances when appropriate.