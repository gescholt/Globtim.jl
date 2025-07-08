# Publication Tables Documentation

## Overview

This document describes the implementation of publication-ready function value error tables for the V4 analysis, showing how computed critical points compare to theoretical critical points in terms of function values.

## Key Components

### 1. PublicationTablesSimple Module (`src/PublicationTablesSimple.jl`)

**Purpose**: Generate clean, formatted tables showing relative and raw errors in function values between theoretical and computed critical points.

**Key Features**:
- Separate tables for minima and saddle points
- Shows both relative errors (as percentages) and raw errors (absolute differences)
- Automatic matching of computed to theoretical points (within 0.1 distance threshold)
- Summary rows with averages

**Main Functions**:
```julia
generate_function_value_error_tables_simple(
    all_critical_points_with_labels::Dict{Int, DataFrame},
    theoretical_points::Vector{Vector{Float64}},
    theoretical_types::Vector{String},
    degrees::Vector{Int},
    f::Function
) -> (min_table, saddle_table)
```

### 2. Table Format

The tables follow this structure:

```
Table 1: Relative Errors for Local Minima (9 points)
Point_ID  Degree_3  Degree_4  Degree_5  Degree_6  Degree_7  Degree_8
TP_001    1.035%    0.797%    0.226%    0.304%    0.405%    0.405%
TP_002    1.523%    0.932%    0.412%    0.389%    0.421%    0.420%
...
────────  ────────  ────────  ────────  ────────  ────────  ────────
Avg Rel   1.311%    0.821%    0.519%    0.456%    0.512%    0.511%
Avg Raw   1.3e-04   8.2e-05   5.2e-05   4.6e-05   5.1e-05   5.1e-05
```

Where:
- **Point_ID**: Theoretical point identifier (TP_001-TP_009 for minima, TP_010-TP_025 for saddles)
- **Degree_X**: Relative error percentage for polynomial degree X
- **"-"**: Indicates no matching computed point was found
- **Avg Rel**: Average relative error across all matched points
- **Avg Raw**: Average absolute error |f(computed) - f(theoretical)|

### 3. Error Calculations

For each theoretical point and degree:

1. **Matching**: Find computed points of same type within 0.1 distance
2. **Function Evaluation**: 
   - f_theo = f(theoretical_point)
   - f_comp = f(computed_point)
3. **Error Metrics**:
   - Raw error: |f_comp - f_theo|
   - Relative error: |f_comp - f_theo| / |f_theo| (if |f_theo| > 1e-10)

### 4. Scripts

#### `generate_publication_tables.jl`
Main script to generate tables from V4 analysis results:
- Runs analysis with suppressed output
- Generates both console and file outputs
- Creates LaTeX versions for papers

#### `test_publication_tables_simple.jl`
Test script with synthetic data to verify table generation

## Usage

```bash
# Generate tables for specific degrees
julia generate_publication_tables.jl 3,4,5,6,7,8

# Output files will be in outputs/tables_HH-MM/
# - minima_errors.csv
# - saddle_errors.csv  
# - minima_errors.tex (LaTeX)
# - saddle_errors.tex (LaTeX)
```

## Key Findings from Tables

1. **Error Reduction with Degree**: Function value errors generally decrease as polynomial degree increases
2. **Minima vs Saddle Points**: Saddle points typically have ~2x larger errors than minima
3. **Convergence**: Errors plateau around degree 5-6 for this problem
4. **Magnitude**: Relative errors are typically < 1% for degree 5 and higher

## Integration with V4 Workflow

The function value analysis integrates seamlessly:

```julia
# In run_v4_analysis.jl (conceptual)
results = run_enhanced_analysis_with_refinement(degrees, GN)
min_table, saddle_table = generate_function_value_error_tables_simple(
    results.all_critical_points,
    theoretical_points,
    theoretical_types,
    degrees,
    deuflhard_4d_composite
)
```

## Output Suppression

To reduce verbose output when generating tables:
- Analysis runs with stdout redirected to buffer
- Only essential progress messages shown
- All detailed data still saved to files

## Benefits

1. **Quantitative Validation**: Direct comparison of function values, not just locations
2. **Publication Ready**: Tables formatted for direct inclusion in papers
3. **Clear Insights**: Easy to see performance trends across degrees
4. **Complete Analysis**: Covers both minima and saddle points separately