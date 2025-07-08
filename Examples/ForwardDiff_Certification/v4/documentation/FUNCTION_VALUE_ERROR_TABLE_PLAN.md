# Function Value Error Table Improvement Plan

## Overview
Improve the display of function value relative errors between theoretical and computed critical points, with separate tables for minima and saddle points.

## Current Issues
1. Function value errors are estimated using random perturbations rather than actual computed points
2. Output contains excessive dictionary dumps and verbose logging
3. Tables are not optimally formatted for paper inclusion

## Proposed Table Format

### Table 1: Relative Errors for Local Minima (9 points)
```
Point ID    Degree 3    Degree 4    Degree 5    Degree 6    Degree 7    Degree 8
TP_001      0.012%      0.008%      0.003%      0.004%      0.005%      0.005%
TP_002      0.015%      0.010%      0.004%      0.005%      0.006%      0.006%
...         ...         ...         ...         ...         ...         ...
TP_009      0.011%      0.007%      0.002%      0.003%      0.004%      0.004%
─────────────────────────────────────────────────────────────────────────────
Avg Rel     0.013%      0.009%      0.003%      0.004%      0.005%      0.005%
Avg Raw     1.3e-4      9.0e-5      3.0e-5      4.0e-5      5.0e-5      5.0e-5
```

### Table 2: Relative Errors for Saddle Points (16 points)
```
Point ID    Degree 3    Degree 4    Degree 5    Degree 6    Degree 7    Degree 8
TP_010      0.045%      0.032%      0.012%      0.018%      0.020%      0.020%
TP_011      0.052%      0.038%      0.015%      0.021%      0.023%      0.023%
...         ...         ...         ...         ...         ...         ...
TP_025      0.041%      0.029%      0.010%      0.016%      0.018%      0.018%
─────────────────────────────────────────────────────────────────────────────
Avg Rel     0.047%      0.034%      0.013%      0.019%      0.021%      0.021%
Avg Raw     4.7e-4      3.4e-4      1.3e-4      1.9e-4      2.1e-4      2.1e-4
```

## Implementation Requirements

### 1. Data Collection
- Match computed points to theoretical points (already done via distance < 0.05)
- For matched points, evaluate f at both theoretical and computed locations
- Calculate relative error: |f(computed) - f(theoretical)| / |f(theoretical)|
- Calculate raw error: |f(computed) - f(theoretical)|

### 2. Table Generation
- Create separate DataFrames for minima and saddle points
- Pivot data to have degrees as columns, points as rows
- Add summary rows for average relative and raw errors
- Format percentages to 3 decimal places
- Format raw errors in scientific notation

### 3. Output Suppression

#### Remove/Reduce:
1. **Dictionary dumps** like `refinement_metrics = Dict{Int64, Any}(...)`
   - Replace with concise summary tables or single-line summaries
   
2. **Verbose DataFrame displays**
   - Use `show(df, allrows=false, allcols=false)` or custom formatting
   
3. **Repetitive status messages**
   - Consolidate multiple "Processing degree X..." into single progress indicator
   
4. **Intermediate calculations**
   - Don't print individual point processing details
   
5. **Full file paths**
   - Use basename() for output directory references

#### Keep:
1. Essential progress indicators (start/end of major steps)
2. Final summary statistics
3. Error/warning messages
4. Table outputs for publication

## Integration Strategy

### Step 1: Modify FunctionValueAnalysis.jl
Add new functions:
- `create_publication_tables()`: Generate formatted tables
- `evaluate_at_matched_points()`: Direct evaluation without perturbation
- `format_error_table()`: Create LaTeX-ready or markdown tables

### Step 2: Update run_v4_analysis.jl
- Replace verbose dictionary printing with table summaries
- Add option for quiet mode: `verbose=false`
- Consolidate progress messages

### Step 3: Create Standalone Script
- `generate_publication_tables.jl`: Read existing CSV output and generate tables
- Can be run after main analysis to produce paper-ready tables

## Example Code Structure

```julia
function create_publication_tables(all_critical_points_with_labels, theoretical_data, f)
    min_table = DataFrame(Point_ID = String[])
    saddle_table = DataFrame(Point_ID = String[])
    
    for degree in degrees
        # Process each degree's data
        # Match points and calculate errors
        # Add column to appropriate table
    end
    
    # Add summary rows
    # Format and return tables
    return min_table, saddle_table
end
```

## Benefits
1. **Clarity**: Clear comparison of performance across degrees
2. **Conciseness**: Reduced output noise, focused on key metrics
3. **Publication-ready**: Tables formatted for direct inclusion in papers
4. **Efficiency**: Less console output, faster execution