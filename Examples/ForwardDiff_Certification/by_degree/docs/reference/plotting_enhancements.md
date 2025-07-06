# Plotting Enhancements for Subdivision Analysis

## Date: 2025-07-04

## Overview
Enhanced the subdivision analysis examples to include full degree range testing and recovery rate visualizations.

## Changes Made

### 1. Extended Degree Range for Fixed Subdivision Analysis

**File**: `examples/02_subdivided_fixed.jl`
- **Line 39**: Changed `FIXED_DEGREES` from `[2, 3, 4]` to `[2, 3, 4, 5, 6]`
- **Rationale**: Previous configuration was capped at degree 4 for fast testing. Now tests up to degree 6 for balanced analysis.
- **Impact**: Each of the 16 subdomains is analyzed at degrees from 2 to 6, providing sufficient convergence data while maintaining reasonable computation time.

### 2. Added Recovery Rate Plotting Function

**File**: `shared/PlottingUtilities.jl`
- **Added Export**: `plot_subdivision_recovery_rates`
- **New Function**: `plot_subdivision_recovery_rates(all_results; save_path, title)`
  
**Function Details**:
- Creates a two-panel figure (1000x700 pixels)
- Top panel: "All Critical Points" - Shows recovery rates for all theoretical critical points
- Bottom panel: "Min+Min Only" - Shows recovery rates for min+min points specifically
- Both panels display all 16 subdomains combined on one plot
- Uses consistent colors: blue for all points, red for min+min
- Includes 90% reference lines on both panels
- Automatically sets integer x-axis ticks based on degree range

### 3. Integrated Recovery Rate Plots into Fixed Degree Example

**File**: `examples/02_subdivided_fixed.jl`
- **Lines 155-161**: Added recovery rate plot generation after L²-norm convergence plot
- **Output**: Saves as `recovery_rates_all_degrees.png` in the timestamped output directory
- **Shows**: Combined recovery rates for all degrees and all subdomains

### 4. Integrated Recovery Rate Plots into Adaptive Example

**File**: `examples/03_subdivided_adaptive.jl`
- **Lines 156-163**: Added recovery rate plot generation after L²-norm convergence plot
- **Output**: Saves as `adaptive_recovery_rates.png` in the timestamped output directory
- **Shows**: Recovery rates progression as degrees increase adaptively per subdomain

## Technical Implementation Details

### Data Structure
The recovery rate plotting function expects:
```julia
all_results::Dict{String, Vector{DegreeAnalysisResult}}
```
Where:
- Keys are subdomain labels (e.g., "0000", "0001", ..., "1111")
- Values are vectors of `DegreeAnalysisResult` objects containing:
  - `degree::Int`: Polynomial degree
  - `success_rate::Float64`: Overall critical point recovery rate
  - `min_min_success_rate::Float64`: Min+min specific recovery rate (-1 if no min+min points)

### Handling Missing Min+Min Points
- The function checks for `min_min_rates >= 0` to filter out subdomains without min+min points
- Only subdomains containing theoretical min+min points are plotted in the bottom panel
- This prevents misleading -1 values from appearing in the visualization

## Output Files Generated

### Fixed Degree Subdivision (`02_subdivided_fixed.jl`)
1. `l2_convergence_all_degrees.png` - L²-norm convergence for all degrees/subdomains
2. `recovery_rates_all_degrees.png` - Recovery rates for all degrees/subdomains (NEW)
3. `fixed_degree_results.csv` - Detailed numerical results

### Adaptive Subdivision (`03_subdivided_adaptive.jl`)
1. `adaptive_convergence_progression.png` - L²-norm convergence progression
2. `adaptive_recovery_rates.png` - Recovery rates progression (NEW)
3. `adaptive_results.csv` - Detailed numerical results

## Usage Notes

1. **Performance**: With `FIXED_DEGREES` now testing up to degree 12, the fixed degree example will take significantly longer to run (approximately 10-20 minutes depending on system).

2. **Interpretation**: 
   - Higher recovery rates (closer to 100%) indicate better critical point identification
   - The 90% reference line provides a visual benchmark for "good" performance
   - Min+min recovery is typically more challenging than general critical point recovery

3. **Visual Design**: All subdomains use the same color to emphasize overall trends rather than individual subdomain performance.