# Critical Point Generation Documentation

## Overview

The `4d_all_critical_points_orthant.csv` file contains all theoretical critical points for the 4D Deuflhard function restricted to the (+,-,+,-) orthant. These points are generated through a tensor product construction from 2D critical points.

## Generation Process

### Code Location

The critical points are generated using the following code structure:

1. **Generation Script**: `/scripts/generate_theoretical_critical_points.jl`
   - Entry point for generating all critical points
   - Calls the `TheoreticalPoints` module functions

2. **Core Module**: `/src/TheoreticalPoints.jl`
   - Contains all logic for generating and classifying critical points
   - Key function: `generate_and_save_all_4d_critical_points()`

### Generation Steps

1. **Load 2D Critical Points**
   - Function: `load_2d_critical_points_orthant()`
   - Source: Pre-computed 2D Deuflhard critical points from CSV
   - Classification: Uses Hessian eigenvalues to classify as min/max/saddle

2. **Generate 4D Tensor Products**
   - Function: `generate_4d_tensor_products_orthant()`
   - Process: Creates all combinations (pt1 × pt2) where:
     - 4D point = [pt1.x, pt1.y, pt2.x, pt2.y]
   - Total: 5×5 = 25 points for orthant-restricted case

3. **Compute Function Values**
   - Uses `deuflhard_4d_composite()` function
   - Evaluates at each 4D critical point

4. **Classify 4D Points**
   - Rules:
     - min + min → min
     - max + max → max
     - all other combinations → saddle

5. **Save to CSV**
   - Output file: `data/4d_all_critical_points_orthant.csv`
   - Columns:
     - `x1, x2, x3, x4`: Coordinates
     - `function_value`: f(x1,x2,x3,x4)
     - `combined_label`: e.g., "min+min", "min+saddle"
     - `type_4d`: Resulting type (min/max/saddle)
     - `label_12`: Type in (x1,x2) subspace
     - `label_34`: Type in (x3,x4) subspace

## Key Functions

### `generate_and_save_all_4d_critical_points()`
Located in `TheoreticalPoints.jl:252-335`

```julia
function generate_and_save_all_4d_critical_points(;
    output_dir::String = joinpath(@__DIR__, "../data"),
    save_full::Bool = true,
    save_orthant::Bool = true)
```

Parameters:
- `output_dir`: Where to save CSV files
- `save_full`: Generate all 225 critical points (15×15)
- `save_orthant`: Generate orthant-restricted points (5×5 = 25)

### Orthant-Specific Generation
The orthant restriction happens in:
1. `load_2d_critical_points_orthant()` - loads only 2D points in the appropriate quadrants
2. Domain is implicitly (+,-,+,-) based on the 2D point selection

## Output Statistics

For the (+,-,+,-) orthant:
- Total critical points: 25
- Minima: 9 (from 3×3 combinations of 2D minima)
- Maxima: 0 (no 2D maxima in the selected quadrants)
- Saddle points: 16 (all other combinations)

## Usage Example

To regenerate the critical points:

```bash
cd Examples/ForwardDiff_Certification/by_degree
julia scripts/generate_theoretical_critical_points.jl
```

This will create/update:
- `data/4d_all_critical_points_full.csv` (all 225 points)
- `data/4d_all_critical_points_orthant.csv` (25 orthant points)