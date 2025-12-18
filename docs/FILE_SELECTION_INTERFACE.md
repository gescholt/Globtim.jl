# Interactive File Selection Interface

This document describes the new interactive file selection capabilities integrated into `workflow_integration.jl`.

## Overview

The file selection interface allows users to interactively choose which experiment output files to compare, using Julia's built-in `TerminalMenus` system for a clean terminal-based experience.

## Features

- **Arrow Key Navigation**: Browse files with up/down arrow keys
- **Multiple Selection**: Select multiple files using spacebar
- **File Size Display**: Shows file sizes for easier selection
- **Path Formatting**: Clear display of file locations
- **Automatic Discovery**: Finds CSV files in common output directories
- **Data Integration**: Automatically loads and combines selected files

## Usage

### Quick Start

```julia
# Load the interactive workflow
julia --project=. -e "include(\"workflow_integration.jl\"); interactive_comparison_workflow()"

# Or run the demo
julia --project=. interactive_comparison_demo.jl
```

### Available Functions

#### `interactive_comparison_workflow()`

Main interactive workflow that:
1. Discovers available CSV files in common directories
2. Lets you select directory (if multiple found)
3. Interactive file selection with arrow keys/spacebar
4. Loads and analyzes selected data
5. Saves combined results for further analysis

Example directories searched:
- `simple_comparison_output/`
- Current directory (`.`)
- Today's parameter analysis (e.g., `parameter_analysis_20250925/`)
- Any directory containing `parameter_analysis` with CSV files

#### `FileSelection.interactive_file_selection(path; allow_multiple=true)`

Lower-level function for file selection:

```julia
using .FileSelection

# Select single file
file = FileSelection.interactive_file_selection("simple_comparison_output")

# Select multiple files
files = FileSelection.select_multiple_files("simple_comparison_output")
```

### Menu Controls

**Single Selection (RadioMenu)**:
- ↑/↓ arrows: Navigate options
- Enter: Select file
- q or Ctrl+C: Cancel

**Multiple Selection (MultiSelectMenu)**:
- ↑/↓ arrows: Navigate options
- Spacebar: Toggle selection (✓/☐)
- d: Mark all as done
- a: Select all
- n: Select none
- Enter: Confirm selection
- q or Ctrl+C: Cancel

## File Discovery

The system automatically discovers CSV files in:

1. **Common Output Directories**:
   - `simple_comparison_output/`
   - Current directory
   - Today's parameter analysis directories

2. **Parameter Analysis Directories**:
   - Any directory matching `*parameter_analysis*` pattern
   - Must contain CSV files

3. **File Types Supported**:
   - All `.csv` files
   - Validates files can be read as CSV
   - Shows file size for selection help

## Data Integration

Selected files are automatically:
- Loaded as DataFrames
- Combined with union of all columns
- Tagged with `source_file` column for tracking
- Validated for CSV format

Example combined data structure:
```
│ x1       │ x2      │ z       │ experiment_id │ source_file           │
├──────────┼─────────┼─────────┼───────────────┼───────────────────────┤
│ 1.868199 │ 1.49463 │ 2.39665 │ exp_1        │ comparison_data.csv   │
│ 4.0      │ 2.41019 │ ...     │ ...          │ domain_comparison.csv │
```

## Output Analysis

The workflow provides automatic analysis:

### For Detailed Comparison Data
(Files with `experiment_id`, `degree`, `z` columns)

- **Experiment Count**: Number of unique experiments
- **Degree Range**: Min/max polynomial degrees
- **L2 Performance**: Best/mean/worst L2 norm values
- **Domain Sizes**: Different domain sizes tested

### For Summary Data
(Files with `mean_l2`, `degree` columns)

- **Parameter Combinations**: Total rows
- **Best Performance**: Minimum mean L2 norm

## Example Workflow

1. **Start Interactive Selection**:
   ```bash
   julia --project=. -e "include(\"workflow_integration.jl\"); interactive_comparison_workflow()"
   ```

2. **File Discovery Output**:
   ```
   🔍 Searching for comparison data...
      📁 Found 4 files in: simple_comparison_output
      📁 Found 33 files in: cluster_results_20250924_213617/parameter_analysis
   ```

3. **Directory Selection** (if multiple):
   ```
   📂 Multiple output directories found:
   Select output directory:
   ❯ simple_comparison_output
     cluster_results_20250924_213617/parameter_analysis
   ```

4. **File Selection Menu**:
   ```
   📊 Select files to compare:
   [press: d=done, a=all, n=none]
    ☐ comparison_data.csv [simple_comparison_output] (3.7KB)
   ❯☐ degree_comparison.csv [simple_comparison_output] (1.0KB)
    ☐ domain_comparison.csv [simple_comparison_output] (256B)
    ☐ experiment_summary.csv [simple_comparison_output] (571B)
   ```

5. **Analysis Results**:
   ```
   📊 COMPARISON ANALYSIS:
      Total data points: 25
      Data sources: 2
      Experiment type: Detailed comparison data
      Unique experiments: 4
      Degree range: 4 - 5
      L2 performance: best=2.388755, mean=2.407853, worst=2.431124
   ```

6. **Output File**:
   ```
   💾 Combined data saved to: interactive_comparison_20250925_143022.csv
   ```

## Integration with Existing Workflow

The file selection integrates seamlessly with existing `workflow_integration.jl`:

- **Non-Breaking**: All existing functions remain unchanged
- **Additional Feature**: New `interactive_comparison_workflow()` function
- **Same Dependencies**: Uses existing CSV, DataFrames, Statistics
- **Compatible Output**: Generates CSV files for @globtimplots integration

## Advanced Usage

### Programmatic File Selection

```julia
include("src/FileSelection.jl")
using .FileSelection

# Discover files
files = FileSelection.discover_csv_files("simple_comparison_output")

# Format for display
options = FileSelection.format_menu_options(files)

# Load selected data
selected = files[[1,3]]  # Select specific indices
data = FileSelection.load_selected_data(selected)
```

### Custom File Filtering

```julia
# Get all CSV files
all_files = FileSelection.discover_csv_files(".")

# Filter to comparison files only
comparison_files = filter(f -> contains(basename(f), "comparison"), all_files)

# Load filtered files
data = FileSelection.load_selected_data(comparison_files)
```

## Error Handling

The interface gracefully handles:

- **No Files Found**: Clear message and early exit
- **Selection Cancelled**: User can press 'q' or Ctrl+C
- **Invalid CSV Files**: Skipped with warning message
- **Column Mismatches**: Uses `:union` to combine different schemas
- **File Access Errors**: Individual file failures don't stop workflow

## Next Steps

After file selection and analysis:

1. **Visualization**: Use output CSV with @globtimplots
2. **Statistical Analysis**: Further analysis with Julia Statistics
3. **Custom Processing**: Build on combined DataFrame
4. **Report Generation**: Use existing PostProcessing module

The interactive file selection provides a foundation for flexible experiment comparison workflows.