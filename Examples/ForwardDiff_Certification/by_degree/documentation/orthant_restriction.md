# Orthant Restriction Implementation

## Date: 2025-07-04

## Overview
Modified the 4D Deuflhard analysis examples to work exclusively in the (+,-,+,-) orthant, reducing the problem complexity while maintaining the 16-subdivision structure.

## Domain Change
- **Previous**: Full domain `[-1,1]^4` with 225 critical points (15×15 tensor product)
- **New**: (+,-,+,-) orthant `[0,1] × [-1,0] × [0,1] × [-1,0]` with 25 critical points (5×5 tensor product)

## Key Modifications

### 1. Theoretical Points Module (`shared/TheoreticalPoints.jl`)
Added new functions to handle orthant-specific critical points:
- `load_2d_critical_points_orthant()`: Filters 2D points for (+,-) orthant (5 points)
- `generate_4d_tensor_products_orthant()`: Creates 4D points in (+,-,+,-) pattern
- `load_theoretical_4d_points_orthant()`: Main function for orthant points
- `load_theoretical_points_for_subdomain_orthant()`: Subdomain filtering for orthant

### 2. Subdomain Management (`shared/SubdomainManagement.jl`)
Added orthant-specific subdivision generation:
- `generate_16_subdivisions_orthant()`: Creates 16 subdomains within the orthant
- Each dimension divided at midpoint: [0,0.5,1] × [-1,-0.5,0] × [0,0.5,1] × [-1,-0.5,0]
- Subdomain range reduced from 0.5 to 0.25 (half the orthant dimension)

### 3. Example Updates

#### Example A: `01_full_domain.jl`
- Renamed to "Orthant Analysis"
- Domain center: `[0.5, -0.5, 0.5, -0.5]`
- Domain range: `0.5` (half-width)
- Uses `load_theoretical_4d_points_orthant()`

#### Example B: `02_subdivided_fixed.jl`
- Updated for orthant subdivisions
- Uses `generate_16_subdivisions_orthant()`
- Uses `load_theoretical_points_for_subdomain_orthant()`
- Maintains degree sweep [2,3,4,5,6]

#### Example C: `03_subdivided_adaptive.jl`
- Adaptive analysis within orthant
- Same orthant-specific functions as Example B
- Maintains adaptive degree logic

## Critical Points in (+,-,+,-) Orthant

The 5 critical points in the 2D (+,-) orthant are:
1. (0.256625076922502, -1.01624596361443)
2. (0.507030772828217, -0.917350578608486)
3. (0.74115190368376, -0.741151903683748)
4. (0.917350578608475, -0.50703077282823)
5. (1.01624596361443, -0.256625076922483)

These create 25 4D critical points through tensor product construction.

## Benefits of Orthant Restriction
1. **Reduced Complexity**: 25 vs 225 critical points (89% reduction)
2. **Faster Computation**: Smaller domain and fewer theoretical points
3. **Maintained Structure**: Still uses 16 subdivisions for spatial analysis
4. **Focused Analysis**: Examines behavior in specific sign pattern

## Usage Notes
- All plot titles updated to indicate "(+,-,+,-) Orthant"
- Output directories renamed to include "orthant" prefix
- CSV files renamed to reflect orthant analysis
- Summary tables indicate orthant restriction

## Backward Compatibility
Original full-domain functions remain available:
- `load_theoretical_4d_points()` for full domain
- `generate_16_subdivisions()` for full domain
- `load_theoretical_points_for_subdomain()` for full domain

The orthant-specific functions are additions, not replacements.