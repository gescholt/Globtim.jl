# Output Directory Structure

## Date: 2025-07-04

## Overview
All three degree analysis examples now output to a single shared directory with HH-MM timestamp format.

## Output Directory Format
```
Examples/ForwardDiff_Certification/by_degree/outputs/HH-MM/
```
Where HH-MM is the hour and minute when any of the examples is run.

## File Naming Convention

### Example A: Orthant Domain Analysis (`01_full_domain.jl`)
- `orthant_l2_convergence.png` - L²-norm convergence plot
- `orthant_recovery_rates.png` - Critical point recovery rates plot
- `orthant_results.csv` - Detailed analysis results

### Example B: Fixed Degree Subdivisions (`02_subdivided_fixed.jl`)
- `fixed_subdivision_l2_convergence.png` - Combined L²-norm plot for all subdomains
- `fixed_subdivision_recovery_rates.png` - Recovery rates for all subdomains
- `fixed_subdivision_results.csv` - Results for all degrees and subdomains

### Example C: Adaptive Subdivisions (`03_subdivided_adaptive.jl`)
- `adaptive_subdivision_l2_convergence.png` - Adaptive convergence progression
- `adaptive_subdivision_recovery_rates.png` - Adaptive recovery rates
- `adaptive_subdivision_results.csv` - Adaptive analysis history

## Benefits
1. **Unified Results**: All outputs from a single analysis session in one folder
2. **Easy Comparison**: All plots and data files together for direct comparison
3. **Simpler Navigation**: One folder per analysis run instead of three
4. **Clear Naming**: File prefixes indicate which example generated each output

## Example Output Structure
```
outputs/
└── 14-35/
    ├── orthant_l2_convergence.png
    ├── orthant_recovery_rates.png
    ├── orthant_results.csv
    ├── fixed_subdivision_l2_convergence.png
    ├── fixed_subdivision_recovery_rates.png
    ├── fixed_subdivision_results.csv
    ├── adaptive_subdivision_l2_convergence.png
    ├── adaptive_subdivision_recovery_rates.png
    └── adaptive_subdivision_results.csv
```

## Usage Notes
- If examples are run at different times, they will create separate folders
- Running all three examples within the same minute will share the same output folder
- The `mkpath` function ensures the directory is created if it doesn't exist
- Multiple runs in the same minute will overwrite previous results