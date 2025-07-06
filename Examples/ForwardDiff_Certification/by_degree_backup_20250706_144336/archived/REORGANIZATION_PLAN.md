# Reorganization Plan for ForwardDiff Certification Examples

## Objective
Centralize and simplify the Globtim approximant construction process while maintaining clear access to all parameters and hyperparameters.

## Current Issues
1. Multiple example files with repeated functionality
2. Scattered construction logic across different files
3. Lack of centralized parameter control
4. Redundant implementations of similar workflows

## Reorganization Plan

### 1. Archive Legacy Files
Create an `archived/` directory and move outdated example files:
- All numbered examples (01-06) except the most recent
- Test files that duplicate functionality
- Old analysis scripts superseded by newer versions

### 2. Create Centralized Example Structure

#### Main Analysis File: `centralized_degree_analysis.jl`
This will be the single entry point containing:
- **Parameter Section**: All configurable parameters in one place
  - Degrees array (from run_all_examples.jl)
  - GN (grid points) parameter
  - Tolerance settings
  - Domain specifications
  - Subdomain strategy selection
- **Constructor Section**: Single Globtim approximant construction
  - Clear documentation of all Constructor parameters
  - Direct access to L²-norm collection
  - Transparent handling of adaptive vs fixed degree
- **Analysis Pipeline**: Clear workflow implementation
  1. Construct approximants for each degree
  2. Collect L²-norms
  3. Solve for critical points
  4. Compute distances to theoretical points
  5. Generate visualization plots

### 3. Simplified Module Structure
Consolidate shared modules into fewer, more focused files:
- `shared/core_functions.jl`: Deuflhard function and domain setup
- `shared/subdomain_utils.jl`: Subdomain generation and management
- `shared/analysis_pipeline.jl`: Analysis workflow functions
- `shared/visualization.jl`: Plotting utilities

### 4. Parameter Flow from run_all_examples.jl
Modify `run_all_examples.jl` to:
```julia
# Define global parameters
const DEGREES = [2, 3, 4, 5, 6, 7, 8]
const GN = 16  # Grid points per dimension

# Call centralized analysis with parameters
include("examples/centralized_degree_analysis.jl")
run_degree_analysis(degrees=DEGREES, gn=GN)
```

### 5. Documentation Updates
- Add inline documentation for all Constructor parameters
- Create a README in the examples directory explaining the workflow
- Document the relationship between tolerance, degree, and GN

## Implementation Steps

1. **Create archive directory and move legacy files**
2. **Implement centralized_degree_analysis.jl with full Constructor documentation**
3. **Update run_all_examples.jl to pass parameters**
4. **Test the new workflow end-to-end**
5. **Clean up and consolidate shared modules**

## Expected Benefits
- Single source of truth for approximant construction
- Clear parameter visibility and control
- Reduced code duplication
- Easier to modify and extend analyses
- Better documentation of the Globtim workflow